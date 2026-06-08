BEGIN;

-- Añadir tablas a la publicación de realtime si no están ya
ALTER PUBLICATION supabase_realtime ADD TABLE scans;
ALTER PUBLICATION supabase_realtime ADD TABLE rewards;
ALTER PUBLICATION supabase_realtime ADD TABLE loyalty_cards;
ALTER PUBLICATION supabase_realtime ADD TABLE qr_codes;
ALTER PUBLICATION supabase_realtime ADD TABLE reward_transfer_history;

COMMIT;
