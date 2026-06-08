BEGIN;

-- 1. SOLUCIÓN A QUE NO SE CARGUEN LOS ESCANEOS (Problema de RLS)
-- Permitir a los dueños de negocios ver los escaneos de su propio negocio.
-- Primero borramos la política si existe para no tener errores de duplicidad.
DROP POLICY IF EXISTS "Dueños pueden ver escaneos de sus negocios" ON scans;
CREATE POLICY "Dueños pueden ver escaneos de sus negocios" ON scans
  FOR SELECT
  USING (
    business_id IN (
      SELECT id FROM businesses WHERE owner_id = auth.uid()
    )
  );

-- 2. SOLUCIÓN AL TIEMPO REAL (Realtime no notifica al instante)
-- Habilitar tiempo real en la tabla de escaneos y demás tablas importantes.
ALTER PUBLICATION supabase_realtime ADD TABLE scans;
ALTER PUBLICATION supabase_realtime ADD TABLE rewards;
ALTER PUBLICATION supabase_realtime ADD TABLE loyalty_cards;
ALTER PUBLICATION supabase_realtime ADD TABLE qr_codes;
ALTER PUBLICATION supabase_realtime ADD TABLE reward_transfer_history;

COMMIT;
