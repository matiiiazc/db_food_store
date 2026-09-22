-- ============================================================
-- TPI Food Store - Objetivo 9: demo de borrado logico (R7)
-- Corre sobre food_store_tp3. Concluye con ROLLBACK.
-- ============================================================

\echo '--- 1. Estado inicial ---'
SELECT count(*) AS total_productos FROM producto;

\echo '--- 2. INTENTO de DELETE fisico (debe FALLAR por trigger) ---'
BEGIN;
DELETE FROM producto WHERE id = 1;
--  ERROR: No esta permitido eliminar registros fisicamente.
ROLLBACK;

\echo '--- 3. Baja logica correcta: UPDATE activo = FALSE ---'
BEGIN;
UPDATE producto SET activo = FALSE WHERE id = 1;
SELECT p.nombre, p.activo FROM producto p WHERE p.id = 1;
COMMIT;

\echo '--- 4. Impacto en vista de catalogo (desaparece de la vigencia) ---'
SELECT count(*) AS productos_vigentes_view FROM vista_productos_vigentes;

\echo '--- 5. El historial de ventas del producto sigue intacto ---'
SELECT count(*) AS lineas_vendidas_del_producto
FROM detalle_pedido dp
WHERE dp.producto_id = 1;

\echo '--- 6. Vuelve a activo (deja la base como estaba) ---'
UPDATE producto SET activo = TRUE WHERE id = 1;
SELECT count(*) AS productos_vigentes_final FROM vista_productos_vigentes;