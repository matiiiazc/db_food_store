-- 3
EXPLAIN ANALYZE
SELECT v.mes, c.nombre AS categoria, v.facturado
FROM (
    SELECT to_char(date_trunc('month', p.fecha), 'YYYY-MM') AS mes,
           pr.categoria_id,
           sum(dp.subtotal) AS facturado
    FROM detalle_pedido dp
    JOIN pedido     p  ON p.id  = dp.pedido_id
    JOIN producto   pr ON pr.id = dp.producto_id
    GROUP BY mes, pr.categoria_id
) v
JOIN categoria c ON c.id = v.categoria_id
ORDER BY v.mes, v.facturado DESC;

-- 4
CREATE INDEX idx_detalle_cover_pedido_prod
    ON detalle_pedido (pedido_id, producto_id) INCLUDE (subtotal);

-- 5
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