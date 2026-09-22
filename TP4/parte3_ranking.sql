-- 3a
EXPLAIN ANALYZE
WITH g AS (
    SELECT p.cliente_id, sum(dp.subtotal) AS total
    FROM pedido p
    JOIN detalle_pedido dp ON dp.pedido_id = p.id
    GROUP BY p.cliente_id
)
SELECT cl.id, cl.nombre, cl.apellido, g.total,
       RANK() OVER (ORDER BY g.total DESC) AS puesto
FROM g
JOIN cliente cl ON cl.id = g.cliente_id
ORDER BY puesto, cl.id;

-- 3b
EXPLAIN ANALYZE
WITH g AS (
    SELECT p.cliente_id, sum(dp.subtotal) AS total
    FROM pedido p
    JOIN detalle_pedido dp ON dp.pedido_id = p.id
    GROUP BY p.cliente_id
)
SELECT cl.id, cl.nombre, cl.apellido, g.total,
       (SELECT count(*) + 1
        FROM g h
        WHERE h.total > g.total)::bigint AS puesto
FROM g
JOIN cliente cl ON cl.id = g.cliente_id
ORDER BY (SELECT count(*) + 1 FROM g h WHERE h.total > g.total), cl.id;

-- 3c
(SELECT cl.id, RANK() OVER (ORDER BY g.total DESC) AS puesto
 FROM (SELECT p.cliente_id, sum(dp.subtotal) AS total
       FROM pedido p JOIN detalle_pedido dp ON dp.pedido_id = p.id
       GROUP BY p.cliente_id) g
 JOIN cliente cl ON cl.id = g.cliente_id)
EXCEPT
(SELECT cl.id, (SELECT count(*) + 1
                FROM (SELECT p2.cliente_id, sum(dp2.subtotal) AS total
                      FROM pedido p2 JOIN detalle_pedido dp2 ON dp2.pedido_id = p2.id
                      GROUP BY p2.cliente_id) h
                WHERE h.total > g.total)::bigint AS puesto
 FROM (SELECT p.cliente_id, sum(dp.subtotal) AS total
       FROM pedido p JOIN detalle_pedido dp ON dp.pedido_id = p.id
       GROUP BY p.cliente_id) g
 JOIN cliente cl ON cl.id = g.cliente_id);

-- 3d
(SELECT cl.id, (SELECT count(*) + 1
                FROM (SELECT p2.cliente_id, sum(dp2.subtotal) AS total
                      FROM pedido p2 JOIN detalle_pedido dp2 ON dp2.pedido_id = p2.id
                      GROUP BY p2.cliente_id) h
                WHERE h.total > g.total)::bigint AS puesto
 FROM (SELECT p.cliente_id, sum(dp.subtotal) AS total
       FROM pedido p JOIN detalle_pedido dp ON dp.pedido_id = p.id
       GROUP BY p.cliente_id) g
 JOIN cliente cl ON cl.id = g.cliente_id)
EXCEPT
(SELECT cl.id, RANK() OVER (ORDER BY g.total DESC) AS puesto
 FROM (SELECT p.cliente_id, sum(dp.subtotal) AS total
       FROM pedido p JOIN detalle_pedido dp ON dp.pedido_id = p.id
       GROUP BY p.cliente_id) g
 JOIN cliente cl ON cl.id = g.cliente_id);