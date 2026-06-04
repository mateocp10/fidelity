-- Crear tabla de transferencias de premios
CREATE TABLE IF NOT EXISTS public.reward_transfers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reward_id UUID REFERENCES public.rewards(id) ON DELETE CASCADE,
    from_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    to_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    business_id UUID REFERENCES public.businesses(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Habilitar RLS
ALTER TABLE public.reward_transfers ENABLE ROW LEVEL SECURITY;

-- Políticas de seguridad
CREATE POLICY "Users can view their own transfers" ON public.reward_transfers
    FOR SELECT USING (auth.uid() = from_user_id OR auth.uid() = to_user_id);

CREATE POLICY "Business owners can view transfers for their business" ON public.reward_transfers
    FOR SELECT USING (auth.uid() IN (SELECT owner_id FROM public.businesses WHERE id = business_id));

CREATE POLICY "Admins can view all transfers" ON public.reward_transfers
    FOR SELECT USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'));

-- Reemplazar la función de transferencia de premios
CREATE OR REPLACE FUNCTION public.transfer_reward(
    p_reward_id UUID,
    p_user_id UUID,
    p_loyalty_card_id UUID
) RETURNS void AS 
DECLARE
    v_old_user_id UUID;
    v_business_id UUID;
    v_status TEXT;
BEGIN
    SELECT user_id, business_id, status INTO v_old_user_id, v_business_id, v_status
    FROM public.rewards
    WHERE id = p_reward_id;

    IF v_status != 'pending' THEN
        RAISE EXCEPTION 'Solo se pueden transferir premios en estado pendiente';
    END IF;

    UPDATE public.rewards
    SET user_id = p_user_id,
        loyalty_card_id = p_loyalty_card_id,
        updated_at = NOW()
    WHERE id = p_reward_id;

    INSERT INTO public.reward_transfers (reward_id, from_user_id, to_user_id, business_id)
    VALUES (p_reward_id, v_old_user_id, p_user_id, v_business_id);
END;
 LANGUAGE plpgsql SECURITY DEFINER;
