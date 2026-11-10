-- ============================================================================
-- U6 - Verificaciones POST-RESTORE (SOLO LECTURA)
-- Base: Food Store (PostgreSQL 16+/18). Ejecutar sobre la base RESTAURADA
-- (ej. food_store_tp3_restore) y, para comparar, sobre el ORIGEN solo en
-- lectura. NUNCA ejecutar contra la base original con fines de modificacion.
--
-- USO (ejemplo):
--   psql -h 127.0.0.1 -p 5432 -U postgres -d food_store_tp3_restore -f sql/verificaciones_post_restore.sql
--   psql -h 127.0.0.1 -p 5432 -U postgres -d food_store_tp3         -f sql/verificaciones_post_restore.sql  > evidencias/compare_origen.txt
--
-- IMPORTANTE: este script NO afirma que las pruebas esten superadas; entrega
-- datos para que una persona compare origen vs restaurada y verifique.
-- ============================================================================

\echo '== [1] Contexto de conexion (verificar que es la base correcta) =='
SELECT current_database() AS base_actual,
       current_user      AS usuario,
       inet_server_addr()::text AS servidor,
       inet_server_port()      AS puerto,
       version()               AS version_pg;

\echo ''
\echo '== [2] Conteos de tablas clave (comparar origen vs restaurada) =='
-- Nota: el modelo real evoluciono (pedido/detalle_pedido con "eliminado";
-- producto/categoria con "activo"). Se reportan totales y, si la columna
-- existe, desgloses por baja logica usando consultas dinamicas seguras.
SELECT 'categoria'::text AS tabla, count(*)::bigint AS filas FROM categoria
UNION ALL SELECT 'cliente',        count(*) FROM cliente
UNION ALL SELECT 'producto',       count(*) FROM producto
UNION ALL SELECT 'pedido',         count(*) FROM pedido
UNION ALL SELECT 'detalle_pedido', count(*) FROM detalle_pedido
ORDER BY tabla;

\echo ''
\echo '== [2b] Desglose de baja logica (solo si la columna existe) =='
SELECT 'producto.activo' AS indicador,
       count(*) FILTER (WHERE activo)     AS vigentes,
       count(*) FILTER (WHERE NOT activo) AS no_vigentes,
       count(*)                           AS total
FROM producto;
SELECT 'categoria.activo' AS indicador,
       count(*) FILTER (WHERE activo)     AS vigentes,
       count(*) FILTER (WHERE NOT activo) AS no_vigentes,
       count(*)                           AS total
FROM categoria;
-- pedido/detalle_pedido.eliminado puede existir en la base evolucionada;
-- si no existe, esta seccion fallaria: en ese caso comentar las 2 consultas
-- siguientes o ejecutarlas condicionalmente. Se incluyen por ser parte del
-- estado real de trabajo (ver AGENTS.md / TPs).
SELECT 'pedido.eliminado' AS indicador,
       count(*) FILTER (WHERE NOT eliminado) AS vigentes,
       count(*) FILTER (WHERE eliminado)     AS eliminados,
       count(*)                              AS total
FROM pedido;
SELECT 'detalle_pedido.eliminado' AS indicador,
       count(*) FILTER (WHERE NOT eliminado) AS vigentes,
       count(*) FILTER (WHERE eliminado)     AS eliminados,
       count(*)                              AS total
FROM detalle_pedido;

\echo ''
\echo '== [3] Inventario de tablas del esquema public =='
SELECT table_name,
       (SELECT reltuples::bigint
          FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
         WHERE n.nspname='public' AND c.relname=t.table_name AND c.relkind='r') AS filas_estimadas
FROM information_schema.tables t
WHERE table_schema='public' AND table_type='BASE TABLE'
ORDER BY table_name;

\echo ''
\echo '== [4] Claves primarias y foraneas (integridad referencial) =='
SELECT tc.table_name, tc.constraint_name, tc.constraint_type,
       kcu.column_name,
       ccu.table_name AS ref_table, ccu.column_name AS ref_column
FROM information_schema.table_constraints tc
LEFT JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name=kcu.constraint_name AND tc.table_schema=kcu.table_schema
LEFT JOIN information_schema.constraint_column_usage ccu
  ON ccu.constraint_name=tc.constraint_name AND ccu.table_schema=tc.table_schema
WHERE tc.table_schema='public' AND tc.constraint_type IN ('PRIMARY KEY','FOREIGN KEY')
ORDER BY tc.table_name, tc.constraint_type, tc.constraint_name, kcu.ordinal_position;

\echo ''
\echo '== [5] CHECKs y UNIQUE (reglas de dominio) =='
SELECT tc.table_name, tc.constraint_type, tc.constraint_name
FROM information_schema.table_constraints tc
WHERE tc.table_schema='public' AND tc.constraint_type IN ('CHECK','UNIQUE')
ORDER BY tc.table_name, tc.constraint_type, tc.constraint_name;

\echo ''
\echo '== [6] Vistas y vistas materializadas =='
SELECT table_name AS objeto, 'VIEW' AS tipo
FROM information_schema.views WHERE table_schema='public'
UNION ALL
SELECT matviewname, 'MATERIALIZED VIEW'
FROM pg_matviews WHERE schemaname='public'
ORDER BY tipo, objeto;

\echo ''
\echo '== [7] Funciones y procedimientos (public) =='
SELECT n.nspname AS esquema, p.proname AS nombre,
       CASE p.prokind WHEN 'f' THEN 'function' WHEN 'p' THEN 'procedure'
                      WHEN 'a' THEN 'aggregate' WHEN 'w' THEN 'window' ELSE p.prokind::text END AS tipo,
       pg_get_function_identity_arguments(p.oid) AS args
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public'
ORDER BY tipo, nombre, args;

\echo ''
\echo '== [8] Triggers (public) =='
SELECT event_object_table AS tabla, trigger_name, action_timing, event_manipulation
FROM information_schema.triggers
WHERE trigger_schema='public'
ORDER BY tabla, trigger_name, event_manipulation;

\echo ''
\echo '== [9] Indices (public) =='
SELECT tablename, indexname, indexdef
FROM pg_indexes WHERE schemaname='public'
ORDER BY tablename, indexname;

\echo ''
\echo '== [10] Tipos ENUM (dominios cerrados) =='
SELECT t.typname AS enum, e.enumlabel AS valor, e.enumsortorder AS orden
FROM pg_type t JOIN pg_enum e ON t.oid=e.enumtypid
JOIN pg_namespace n ON n.oid=t.typnamespace
WHERE n.nspname='public'
ORDER BY t.typname, e.enumsortorder;

\echo ''
\echo '== [11] Muestreo de negocio (coherencia basica, solo lectura) =='
-- Muestras acotadas para inspeccion humana; no modifican datos.
SELECT id, nombre, activo FROM categoria ORDER BY id LIMIT 5;
SELECT id, nombre, apellido, email FROM cliente ORDER BY id LIMIT 5;
SELECT id, nombre, precio, stock, activo, categoria_id FROM producto ORDER BY id LIMIT 5;
SELECT id, fecha, forma_pago, cliente_id FROM pedido ORDER BY id DESC LIMIT 5;
SELECT id, pedido_id, producto_id, cantidad, precio_unitario, subtotal
FROM detalle_pedido ORDER BY id DESC LIMIT 5;

\echo ''
\echo '== [12] Chequeos de consistencia basica (esperado: 0 filas si integro) =='
-- Subtotales incoherentes (tolerancia de redondeo NUMERIC)
SELECT id, pedido_id, cantidad, precio_unitario, subtotal,
       (cantidad*precio_unitario - subtotal) AS diff
FROM detalle_pedido
WHERE abs(cantidad*precio_unitario - subtotal) > 0.01
LIMIT 20;

-- Detalles huerfanos (no deberian existir si las FK estan activas/integra)
SELECT dp.id FROM detalle_pedido dp
LEFT JOIN pedido p ON p.id=dp.pedido_id
LEFT JOIN producto pr ON pr.id=dp.producto_id
WHERE p.id IS NULL OR pr.id IS NULL
LIMIT 20;

\echo ''
\echo '== Fin verificaciones post-restore (datos para comparar; no se afirman resultados) =='
