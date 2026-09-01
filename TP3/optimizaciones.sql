-- ============================================================
-- FOOD STORE - TP3 - Parte 2: cambios propuestos por la IA
-- ============================================================
-- Cada cambio justificado en terminos del plan REAL obtenido con
-- consultas_lentas.sql. Se aplica sobre la copia de trabajo y se
-- vuelve a medir con EXPLAIN ANALYZE.
--
-- CONSULTA 1 - resumen de ventas por producto:
--   El plan hace "Parallel Seq Scan on detalle_pedido dp"
--   (600.000 filas) + HashAggregate con spool a disco
--   (Batches: 5, Disk Usage ~7MB). El Query Scan de detalle lee
--   toda la tabla y despues agrega.
--   PROPUESTA: indice de cobertura que responda la agregacion con
--   Index Only Scan, evitando leer las filas del heap.
--   CREATE INDEX idx_detalle_producto_cover
--       ON detalle_pedido (producto_id) INCLUDE (cantidad, subtotal);
--   Ataca el nodo "Seq Scan on detalle_pedido".
--
-- CONSULTA 2 - facturacion por rango de fechas:
--   El plan hace "Seq Scan on pedido p" con
--   "Filter: (fecha >= ... AND fecha < ...)"
--   y "Rows Removed by Filter: 122160" (escanea 200.000 filas
--   para quedarse con 78.840). Actualmente NO hay indice por fecha.
--   PROPUESTA: CREATE INDEX ON pedido (fecha);
--   Ataca el nodo "Seq Scan on pedido" -> Bitmap Index Scan.
--
-- CONSULTA 3 - total vendido por mes:
--   Lo mas caro es el "Sort Method: external merge Disk: 27136kB"
--   sobre las 600.000 filas y el "Hash Join" con
--   "Seq Scan on detalle_pedido dp". La Group Key es
--   date_trunc('month', fecha): si el pedido viene ordenado por
--   fecha (indice), el GroupAggregate puede leer en orden y parte
--   del sort desaparece.
--   PROPUESTA: se agrega (INDEX en pedido(fecha)) que tambien
--   alimenta a la consulta 3 ordenando por fecha.
-- ============================================================

BEGIN;

CREATE INDEX idx_detalle_producto_cover
    ON detalle_pedido (producto_id) INCLUDE (cantidad, subtotal);

CREATE INDEX idx_pedido_fecha
    ON pedido (fecha);

ANALYZE detalle_pedido;
ANALYZE pedido;

COMMIT;

SELECT 'indices creados' AS estado;
