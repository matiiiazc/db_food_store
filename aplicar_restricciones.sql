-- ============================================================
-- FOOD STORE — aplicar_restricciones.sql
-- Aplica las restricciones sobre copia_trabajo dentro de una transacción
-- ============================================================
-- Ejecutar desde la terminal:
--   psql -d copia_trabajo -f aplicar_restricciones.sql
-- ============================================================


BEGIN;

-- Aplicar las restricciones
\echo 'Aplicando restricciones.sql...'
\i restricciones.sql

-- Verificar que los triggers se crearon
\echo 'Triggers creados:'
SELECT trigger_name, event_manipulation, event_object_table
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;

-- Verificar que las funciones se crearon
\echo 'Funciones creadas:'
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name LIKE 'fn_%'
ORDER BY routine_name;

-- Inspeccionar: todo parece bien, pero no confirmamos aún
\echo 'Listo. Revisá los resultados y decidí: COMMIT o ROLLBACK.'

-- Si todo está bien, descomentá la siguiente línea:
-- COMMIT;

-- Si algo falló, descomentá la siguiente línea:
-- ROLLBACK;
