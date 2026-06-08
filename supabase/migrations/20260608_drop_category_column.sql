-- Migración para eliminar la columna de texto 'category' obsoleta
-- Se mantiene un intento de UPDATE para resguardar data nula si es posible, aunque al ser pruebas no importa mucho.

-- Asignar un ID base (por ejemplo 1) a los negocios que tienen NULL en category_id por seguridad
UPDATE public.businesses
SET category_id = 1
WHERE category_id IS NULL;

-- Finalmente, eliminar la columna de texto vieja y cualquier vista que dependa de ella (como business_stats)
ALTER TABLE public.businesses DROP COLUMN category CASCADE;
