-- 1
EXPLAIN ANALYZE
SELECT to_char(date_trunc('month', p.fecha), 'YYYY-MM') AS mes,
       c.nombre                                  AS categoria,
       sum(dp.subtotal)                          AS facturado
FROM detalle_pedido dp
JOIN pedido     p  ON p.id  = dp.pedido_id
JOIN producto   pr ON pr.id = dp.producto_id
JOIN categoria  c  ON c.id  = pr.categoria_id
GROUP BY mes, c.nombre
ORDER BY mes, facturado DESC;

-- 2
EXPLAIN ANALYZE
SELECT cl.nombre || ' ' || cl.apellido      AS cliente,
       count(p.id)                          AS cantidad_pedidos,
       sum(dp.subtotal)                     AS total_gastado
FROM cliente cl
JOIN pedido p          ON p.cliente_id = cl.id
JOIN detalle_pedido dp ON dp.pedido_id = p.id
GROUP BY cl.id, cl.nombre, cl.apellido
ORDER BY total_gastado DESC
LIMIT 20;