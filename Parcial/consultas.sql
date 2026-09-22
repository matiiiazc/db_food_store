-- ============================================================
-- TPI Food Store - Objetivo 5: DML y consultas
-- JOIN, funciones de agregacion, subconsultas, GROUP BY/HAVING
-- y funciones de ventana sobre food_store_tp3.
-- Cada consulta esta comentada segun lo que demuestra.
-- ============================================================

-- ------------------------------------------------------------
-- A) JOIN (inner explicitos, 3 y 4 tablas)
-- ------------------------------------------------------------

-- 1. JOIN de 4 tablas: detalle -> pedido -> producto -> categoria
SELECT to_char(date_trunc('month', p.fecha), 'YYYY-MM') AS mes,
       c.nombre                                        AS categoria,
       sum(dp.subtotal)                                AS facturado
FROM detalle_pedido dp
JOIN pedido     p  ON p.id  = dp.pedido_id
JOIN producto   pr ON pr.id = dp.producto_id
JOIN categoria  c  ON c.id  = pr.categoria_id
GROUP BY mes, c.nombre
ORDER BY mes, facturado DESC
LIMIT 10;

-- 2. JOIN de 3 tablas: cliente -> pedido -> detalle (top gasto)
SELECT cl.nombre || ' ' || cl.apellido AS cliente,
       count(p.id)                     AS cantidad_pedidos,
       sum(dp.subtotal)                AS total_gastado
FROM cliente cl
JOIN pedido p          ON p.cliente_id = cl.id
JOIN detalle_pedido dp ON dp.pedido_id = p.id
GROUP BY cl.id, cl.nombre, cl.apellido
ORDER BY total_gastado DESC
LIMIT 10;

-- 3. JOIN con LEFT (cliente sin pedidos: participacion parcial)
SELECT c.nombre || ' ' || c.apellido AS cliente,
       count(p.id)                   AS pedidos
FROM cliente c
LEFT JOIN pedido p ON p.cliente_id = c.id
GROUP BY c.id, c.nombre, c.apellido
HAVING count(p.id) = 0
LIMIT 5;

-- ------------------------------------------------------------
-- B) Funciones de agregacion (count, sum, avg, min, max)
-- ------------------------------------------------------------

-- 4. Resumen de ventas por producto (unidades y total)
SELECT pr.nombre,
       count(*)         AS lineas,
       sum(dp.cantidad) AS unidades,
       sum(dp.subtotal) AS total_vendido
FROM detalle_pedido dp
JOIN producto pr ON pr.id = dp.producto_id
GROUP BY pr.nombre
ORDER BY total_vendido DESC
LIMIT 10;

-- 5. Facturado por forma de pago (agregacion simple)
SELECT p.forma_pago,
       count(*)  AS pedidos,
       count(distinct p.cliente_id) AS clientes_distintos
FROM pedido p
GROUP BY p.forma_pago;

-- ------------------------------------------------------------
-- C) Subconsultas (correlacionada y en SELECT/FROM)
-- ------------------------------------------------------------

-- 6. Producto con precio por encima del promedio de su categoria
--    (subconsulta correlacionada)
SELECT pr.nombre, pr.precio,
       pr.precio - (SELECT avg(p2.precio)
                    FROM producto p2
                    WHERE p2.categoria_id = pr.categoria_id) AS dif_vs_promedio
FROM producto pr
WHERE pr.activo
ORDER BY dif_vs_promedio DESC
LIMIT 10;

-- 7. Subconsulta en FROM: total por cliente sobre bases agregadas
SELECT cl.nombre || ' ' || cl.apellido AS cliente, g.total
FROM (SELECT p.cliente_id, sum(dp.subtotal) AS total
      FROM pedido p
      JOIN detalle_pedido dp ON dp.pedido_id = p.id
      GROUP BY p.cliente_id) g
JOIN cliente cl ON cl.id = g.cliente_id
ORDER BY g.total DESC
LIMIT 10;

-- ------------------------------------------------------------
-- D) GROUP BY / HAVING
-- ------------------------------------------------------------

-- 8. Meses con facturacion por encima de un umbral (HAVING)
SELECT to_char(date_trunc('month', p.fecha), 'YYYY-MM') AS mes,
       sum(dp.subtotal)                                 AS total_mes
FROM detalle_pedido dp
JOIN pedido p ON p.id = dp.pedido_id
GROUP BY date_trunc('month', p.fecha)
HAVING sum(dp.subtotal) > 5000000
ORDER BY mes;

-- ------------------------------------------------------------
-- E) Funciones de ventana (RANK, OVER, PARTITION BY)
-- ------------------------------------------------------------

-- 9. Ranking de clientes por gasto (RANK con ventana) - TP4
WITH g AS (
    SELECT p.cliente_id, sum(dp.subtotal) AS total
    FROM pedido p
    JOIN detalle_pedido dp ON dp.pedido_id = p.id
    GROUP BY p.cliente_id
)
SELECT cl.nombre || ' ' || cl.apellido AS cliente, g.total,
       RANK() OVER (ORDER BY g.total DESC) AS puesto
FROM g
JOIN cliente cl ON cl.id = g.cliente_id
ORDER BY puesto
LIMIT 10;

-- 10. Ranking de productos dentro de cada categoria (PARTITION BY)
SELECT c.nombre AS categoria, pr.nombre, pr.precio,
       rank() OVER (PARTITION BY pr.categoria_id
                    ORDER BY pr.precio DESC) AS pos_precio
FROM producto pr
JOIN categoria c ON c.id = pr.categoria_id
WHERE pr.activo
ORDER BY c.nombre, pos_precio
LIMIT 20;