-- 3e
EXPLAIN ANALYZE
SELECT p.id, p.nombre AS producto,
       p.precio,
       round(p.precio - (SELECT avg(p2.precio)
                         FROM producto p2
                         WHERE p2.categoria_id = p.categoria_id), 2) AS dif_vs_categoria
FROM producto p
ORDER BY p.id
LIMIT 50;

-- 3f
EXPLAIN ANALYZE
SELECT p.id, p.nombre AS producto,
       p.precio,
       round(p.precio - c.promedio, 2) AS dif_vs_categoria
FROM producto p
JOIN (SELECT categoria_id, avg(precio) AS promedio
      FROM producto GROUP BY categoria_id) c
  ON c.categoria_id = p.categoria_id
ORDER BY p.id
LIMIT 50;

-- 3g
(SELECT p.id,
        p.precio,
        round(p.precio - (SELECT avg(p2.precio) FROM producto p2 WHERE p2.categoria_id = p.categoria_id), 2) AS dif_vs_categoria
 FROM producto p)
EXCEPT
(SELECT p.id,
        p.precio,
        round(p.precio - c.promedio, 2) AS dif_vs_categoria
 FROM producto p
 JOIN (SELECT categoria_id, avg(precio) AS promedio FROM producto GROUP BY categoria_id) c
   ON c.categoria_id = p.categoria_id);

-- 3h
(SELECT p.id,
        p.precio,
        round(p.precio - c.promedio, 2) AS dif_vs_categoria
 FROM producto p
 JOIN (SELECT categoria_id, avg(precio) AS promedio FROM producto GROUP BY categoria_id) c
   ON c.categoria_id = p.categoria_id)
EXCEPT
(SELECT p.id,
        p.precio,
        round(p.precio - (SELECT avg(p2.precio) FROM producto p2 WHERE p2.categoria_id = p.categoria_id), 2) AS dif_vs_categoria
 FROM producto p);