-- ============================================================================
-- U6 - Verificación de integridad y tareas de control (SOLO LECTURA / SEGURO)
-- Base: Food Store PostgreSQL. Ejecutar sobre la base objetivo (copia/restaurada
-- o el origen SOLO en lectura). No modifica datos.
-- USO: psql -h <host> -p <port> -U <user> -d <db> -f sql/verificacion_integridad.sql
-- ============================================================================

\echo '== Contexto =='
SELECT current_database() AS base, current_user AS usuario, now() AS ejecutado_en;

\echo ''
\echo '== Integridad: FKs/CHECKs en catalogo (definidas) =='
SELECT conrelid::regclass AS tabla, conname AS restriccion,
       CASE contype WHEN 'f' THEN 'FK' WHEN 'c' THEN 'CHECK' WHEN 'p' THEN 'PK' WHEN 'u' THEN 'UNIQUE' ELSE contype::text END AS tipo,
       convalidated AS validada
FROM pg_constraint c JOIN pg_namespace n ON n.oid=c.connamespace
WHERE n.nspname='public' AND contype IN ('f','c')
ORDER BY tabla, tipo, restriccion;

\echo ''
\echo '== Integridad: huerfanos (esperado 0 filas, a confirmar) =='
SELECT 'detalle_pedido sin pedido' AS caso, count(*) FROM detalle_pedido dp LEFT JOIN pedido p ON p.id=dp.pedido_id WHERE p.id IS NULL
UNION ALL
SELECT 'detalle_pedido sin producto', count(*) FROM detalle_pedido dp LEFT JOIN producto pr ON pr.id=dp.producto_id WHERE pr.id IS NULL
UNION ALL
SELECT 'pedido sin cliente', count(*) FROM pedido pe LEFT JOIN cliente c ON c.id=pe.cliente_id WHERE c.id IS NULL
UNION ALL
SELECT 'producto sin categoria', count(*) FROM producto pr LEFT JOIN categoria ca ON ca.id=pr.categoria_id WHERE ca.id IS NULL;

\echo ''
\echo '== Integridad: valores de dominio (esperado 0 filas, a confirmar) =='
SELECT 'detalle cantidad <= 0' AS caso, count(*) FROM detalle_pedido WHERE cantidad <= 0
UNION ALL SELECT 'detalle precio_unitario < 0', count(*) FROM detalle_pedido WHERE precio_unitario < 0
UNION ALL SELECT 'detalle subtotal < 0', count(*) FROM detalle_pedido WHERE subtotal < 0
UNION ALL SELECT 'producto precio < 0', count(*) FROM producto WHERE precio < 0
UNION ALL SELECT 'producto stock < 0', count(*) FROM producto WHERE stock < 0;

\echo ''
\echo '== Salud basica: tablas (tamano aprox y bloat no medido aqui) =='
SELECT relname AS tabla, n_live_tup AS filas_vivas_est, n_dead_tup AS filas_muertas_est,
       last_vacuum, last_autovacuum, last_analyze, last_autoanalyze
FROM pg_stat_user_tables WHERE schemaname='public' ORDER BY relname;

\echo ''
\echo '== Indices: uso basico =='
SELECT relname AS tabla, indexrelname AS indice, idx_scan AS escaneos
FROM pg_stat_user_indexes WHERE schemaname='public' ORDER BY relname, indexrelname;

\echo '== Fin verificacion integridad =='
