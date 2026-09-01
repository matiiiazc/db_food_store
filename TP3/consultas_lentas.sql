-- ============================================================
-- FOOD STORE - TP3 - Parte 2: consultas lentas y EXPLAIN ANALYZE
-- ============================================================
-- Consultas elegidas (variantes propias sobre el modelo) que a
-- esta escala vuelven lentas. Antes de cualquier cambio se guarda
-- el plan completo de cada una.
--
-- Los tres son queries de REPORTING reales sobre el modelo, de las
-- que el optimizador no puede resolver con los indices del esquema
-- base (schema.sql) y por eso producen Seq Scan / agregaciones
-- pesadas sobre las 600.000 lineas de detalle_pedido.
-- ============================================================

-- CONSULTA 1: resumen de ventas por producto (unidades y total).
-- Escanea 600.000 lineas de detalle, JOIN con producto y agrega por
-- producto. No hay indice util para la agregacion; usa HashAggregate
-- con spool a disco.
EXPLAIN ANALYZE
SELECT pr.nombre,
       count(*)         AS lineas,
       sum(dp.cantidad) AS unidades,
       sum(dp.subtotal) AS total_vendido
FROM detalle_pedido dp
JOIN producto pr ON pr.id = dp.producto_id
GROUP BY pr.nombre
ORDER BY total_vendido DESC
LIMIT 20;

-- CONSULTA 2: facturacion por rango de fechas (reporte mensual).
-- Filtra pedidos por fecha y los cruza con su cliente para el
-- listado de facturas. No existe indice sobre pedido.fecha, por lo
-- que se hace Seq Scan sobre las 200.000 filas de pedido.
EXPLAIN ANALYZE
SELECT p.id AS nro_factura, p.fecha, p.forma_pago, c.nombre AS cliente
FROM pedido p
JOIN cliente c ON c.id = p.cliente_id
WHERE p.fecha >= '2025-01-01'
  AND p.fecha <  '2026-01-01'
ORDER BY p.fecha, p.id;

-- CONSULTA 3: total vendido por mes (historicos).
-- Cruza detalle (600.000 filas) con pedido para filtrar por fecha y
-- luego agrega por mes (date_trunc). Agregacion pesada de reporte.
EXPLAIN ANALYZE
SELECT to_char(date_trunc('month', p.fecha), 'YYYY-MM') AS mes,
       sum(dp.subtotal)                                 AS total_mes,
       count(distinct p.id)                             AS pedidos_mes
FROM detalle_pedido dp
JOIN pedido p ON p.id = dp.pedido_id
GROUP BY date_trunc('month', p.fecha)
ORDER BY mes;
