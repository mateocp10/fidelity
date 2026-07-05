-- ============================================================================
-- FIDELITY — Hardening de seguridad (backend)
-- Verificado contra el uso real de la app + revisión adversarial (3 revisores).
-- NO rompe flujos legítimos. Todo en una transacción: si algo falla, no se aplica nada.
-- Aplicar en el SQL Editor de Supabase.
--
-- NOTA DE SEGURIDAD APARTE (manual): el archivo backup_supabase/schema.sql contiene
-- un JWT de service_role hardcodeado. Está sin trackear en git, pero conviene:
--   (a) agregar backup_supabase/ al .gitignore, y
--   (b) rotar la service_role key en el panel (API -> Rotate).
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. delete_user_data: cada usuario SOLO puede borrar SU propia cuenta.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.delete_user_data(user_id_param uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
BEGIN
  -- Permitido si: (a) borrás tu propia cuenta (auth.uid()), o (b) lo llama el
  -- backend con service_role (la Edge Function hyper-action, que YA verificó al
  -- usuario). Un cliente autenticado NO puede borrar la cuenta de otro; un anon
  -- (auth.uid() NULL, sin service_role) tampoco.
  IF NOT (
    user_id_param = auth.uid()
    OR coalesce((current_setting('request.jwt.claims', true))::jsonb ->> 'role', '') = 'service_role'
  ) THEN
    RAISE EXCEPTION 'FORBIDDEN: solo podés eliminar tu propia cuenta.';
  END IF;

  DELETE FROM public.scan_attempts   WHERE user_id = user_id_param OR business_id IN (SELECT id FROM public.businesses WHERE owner_id = user_id_param);
  DELETE FROM public.scans           WHERE user_id = user_id_param OR business_id IN (SELECT id FROM public.businesses WHERE owner_id = user_id_param);
  DELETE FROM public.rewards         WHERE user_id = user_id_param OR business_id IN (SELECT id FROM public.businesses WHERE owner_id = user_id_param);
  DELETE FROM public.loyalty_cards   WHERE user_id = user_id_param OR business_id IN (SELECT id FROM public.businesses WHERE owner_id = user_id_param);
  DELETE FROM public.support_tickets WHERE user_id = user_id_param OR business_id IN (SELECT id FROM public.businesses WHERE owner_id = user_id_param);
  DELETE FROM public.qr_codes        WHERE business_id IN (SELECT id FROM public.businesses WHERE owner_id = user_id_param);
  DELETE FROM public.business_stats  WHERE business_id IN (SELECT id FROM public.businesses WHERE owner_id = user_id_param);
  DELETE FROM public.businesses      WHERE owner_id = user_id_param;
  DELETE FROM public.profiles        WHERE id = user_id_param;
END;
$function$;

-- ----------------------------------------------------------------------------
-- 2. add_manual_points: SOLO el dueño del negocio puede asignar puntos.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.add_manual_points(p_user_id uuid, p_business_id uuid, p_points integer)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
    v_loyalty_card_id UUID;
    v_is_demo BOOLEAN;
    v_current_points INT;
    v_total_points_lifetime INT;
    v_rewards_claimed INT;
    v_points_required INT;
    v_new_rewards INT;
    v_has_pending_reward BOOLEAN;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.businesses WHERE id = p_business_id AND owner_id = auth.uid()) THEN
        RAISE EXCEPTION 'FORBIDDEN: solo el dueño del negocio puede asignar puntos.';
    END IF;
    IF p_points IS NULL OR p_points <= 0 THEN
        RAISE EXCEPTION 'INVALID_POINTS: los puntos deben ser mayores a cero.';
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM public.rewards
        WHERE user_id = p_user_id AND business_id = p_business_id AND status = 'pending'
    ) INTO v_has_pending_reward;
    IF v_has_pending_reward THEN
        RAISE EXCEPTION 'PENDING_REWARD: El usuario tiene un premio pendiente. No se pueden otorgar más puntos hasta que se apruebe.';
    END IF;

    SELECT is_demo INTO v_is_demo FROM public.profiles WHERE id = p_user_id;

    SELECT points_required INTO v_points_required FROM public.businesses WHERE id = p_business_id;
    IF v_points_required IS NULL OR v_points_required <= 0 THEN
        v_points_required := 10;
    END IF;

    SELECT id, current_points, total_points_lifetime, rewards_claimed
    INTO v_loyalty_card_id, v_current_points, v_total_points_lifetime, v_rewards_claimed
    FROM public.loyalty_cards
    WHERE user_id = p_user_id AND business_id = p_business_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Loyalty card not found for user % and business %', p_user_id, p_business_id;
    END IF;

    v_current_points := v_current_points + p_points;
    v_new_rewards := FLOOR(v_current_points / v_points_required);
    v_current_points := v_current_points % v_points_required;

    UPDATE public.loyalty_cards
    SET current_points = v_current_points,
        total_points_lifetime = v_total_points_lifetime + p_points,
        rewards_claimed = v_rewards_claimed + v_new_rewards,
        updated_at = NOW()
    WHERE id = v_loyalty_card_id;

    FOR i IN 1..p_points LOOP
        INSERT INTO public.scans (user_id, business_id, loyalty_card_id, qr_code_id, scanned_at, is_demo, status)
        VALUES (p_user_id, p_business_id, v_loyalty_card_id, null, NOW(), v_is_demo, 'approved');
    END LOOP;

    IF v_new_rewards > 0 THEN
        FOR i IN 1..v_new_rewards LOOP
            INSERT INTO public.rewards (user_id, business_id, loyalty_card_id, points_used, description, earned_at, status, is_demo)
            VALUES (p_user_id, p_business_id, v_loyalty_card_id, v_points_required, 'Premio por puntos manuales', NOW(), 'pending', v_is_demo);
        END LOOP;
    END IF;
END;
$function$;

-- ----------------------------------------------------------------------------
-- 3. Impedir escalada a 'admin' — en INSERT **y** UPDATE.
--    (el red team encontró el bypass: borrar el perfil propio y re-insertarlo
--     con role='admin'. Por eso el trigger ahora cubre también el INSERT.)
--    - Un usuario autenticado NO admin que intente quedar 'admin' -> se degrada.
--    - Contexto servidor (SQL Editor / service_role, auth.uid() NULL) -> permitido,
--      para poder seguir creando/promoviendo admins a mano.
--    - El cambio client<->business del registro NO se toca (nunca es 'admin').
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.prevent_role_escalation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
BEGIN
  IF NEW.role = 'admin' THEN
    -- Ya era admin (solo aplica en UPDATE): no hay escalada.
    IF TG_OP = 'UPDATE' AND OLD.role = 'admin' THEN
      RETURN NEW;
    END IF;
    -- Usuario autenticado que NO es admin intentando quedar admin -> bloquear.
    IF auth.uid() IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
    ) THEN
      IF TG_OP = 'INSERT' THEN
        NEW.role := 'client';
      ELSE
        NEW.role := OLD.role;
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_prevent_role_change ON public.profiles;
DROP TRIGGER IF EXISTS trg_prevent_role_escalation ON public.profiles;
CREATE TRIGGER trg_prevent_role_escalation
  BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_role_escalation();

-- ----------------------------------------------------------------------------
-- 4. is_admin(): leer el rol desde profiles (server-side), NO desde user_metadata.
--    (el red team confirmó que user_metadata es editable por el cliente:
--     auth.updateUser({data:{role:'admin'}}) -> is_admin() daba true -> leía
--     TODA la data. Ahora se basa en profiles.role, que ya está protegido por
--     el trigger de arriba.)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
BEGIN
  RETURN EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin');
END;
$function$;

-- ----------------------------------------------------------------------------
-- 5. loyalty_cards: el cliente NO edita puntos; solo crea su tarjeta en CERO.
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Users can update their own loyalty card" ON public.loyalty_cards;

DROP POLICY IF EXISTS "Users can create their own loyalty card" ON public.loyalty_cards;
CREATE POLICY "Users can create their own loyalty card" ON public.loyalty_cards
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND current_points = 0
    AND total_points_lifetime = 0
    AND rewards_claimed = 0
  );

-- ----------------------------------------------------------------------------
-- 6. get_or_create / create_loyalty_card: siempre crean en CERO puntos.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_or_create_loyalty_card(p_user_id uuid, p_business_id uuid, p_points integer DEFAULT 0)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_card_id uuid;
BEGIN
  SELECT id INTO v_card_id FROM loyalty_cards WHERE user_id = p_user_id AND business_id = p_business_id;
  IF v_card_id IS NOT NULL THEN
    RETURN v_card_id;
  END IF;
  INSERT INTO loyalty_cards (user_id, business_id, current_points, total_points_lifetime, rewards_claimed)
  VALUES (p_user_id, p_business_id, 0, 0, 0)
  RETURNING id INTO v_card_id;
  RETURN v_card_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.create_loyalty_card(p_user_id uuid, p_business_id uuid, p_points integer DEFAULT 0)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_card_id uuid;
BEGIN
  INSERT INTO loyalty_cards (user_id, business_id, current_points, total_points_lifetime, rewards_claimed)
  VALUES (p_user_id, p_business_id, 0, 0, 0)
  RETURNING id INTO v_card_id;
  RETURN v_card_id;
END;
$function$;

-- ----------------------------------------------------------------------------
-- 7. scans: el cliente solo puede insertar escaneos 'pending'.
--    (add_manual_points es SECURITY DEFINER y no pasa por RLS, sigue OK.)
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Users can insert their own scans" ON public.scans;
CREATE POLICY "Users can insert their own scans" ON public.scans
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND status = 'pending'
  );

-- ----------------------------------------------------------------------------
-- 8. reward_transfer_history: cerrar el INSERT abierto.
--    (transfer_reward es SECURITY DEFINER y saltea RLS -> sigue insertando.
--     La app solo LEE esta tabla, nunca inserta directo.)
--    Además revocamos log_reward_transfer (sin auth, sin uso) a clientes.
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Insertar historial" ON public.reward_transfer_history;
DROP POLICY IF EXISTS "Service role can insert transfer history" ON public.reward_transfer_history;

REVOKE EXECUTE ON FUNCTION public.log_reward_transfer(uuid, uuid, uuid) FROM anon, authenticated;

-- ----------------------------------------------------------------------------
-- 9. admin_toggle_business_status: ya validaba admin; fijamos search_path.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_toggle_business_status(target_business_id uuid, new_status boolean)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
    caller_role TEXT;
BEGIN
    SELECT role INTO caller_role FROM profiles WHERE id = auth.uid();
    IF caller_role != 'admin' THEN
        RAISE EXCEPTION 'Acceso denegado: Solo los administradores pueden cambiar el estado de los negocios.';
    END IF;
    UPDATE businesses SET is_active = new_status WHERE id = target_business_id;
END;
$function$;

COMMIT;
