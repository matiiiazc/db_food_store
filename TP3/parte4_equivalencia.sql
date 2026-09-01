-- ============================================================
-- FOOD STORE - TP3 - Parte 4: consultas bajo spec + equivalencia
-- ============================================================
-- Se redacta una spec precisa, la IA genera el SQL a partir de la
-- spec (sin solucion previa), y se escribe una SEGUNDA version de
-- distinta estructura que responda la misma pregunta. Luego se
-- verifica equivalencia con EXCEPT en ambas direcciones (debe dar
-- 0 filas). Sobre food_store_tp3.
-- ============================================================

-- ============================================================
-- SPEC 1 (agregacion / resumen)
-- «Genera una consulta SQL sobre el esquema Food Store que devuelva,
--   para cada categoria VIGENTE (categoria.activo = FALSE son las
--   dadas de baja y NO deben aparecer), el nombre de la categoria y
--   la cantidad de productos VIGENTES (producto.activo = TRUE) que
--   tiene, incluyendo las categorias sin productos vigentes con
--   cantidad 0. Ordena de mayor a menor cantidad (y por nombre como
--   desempate asc). No uses SELECT *. Usa LEFT JOIN.»
-- ============================================================

-- VERSION A (generada por la IA a partir de la spec)
SELECT c.nombre, count(p.id) AS cantidad_productos
FROM categoria c
LEFT JOIN producto p ON p.categoria_id = c.id AND p.activo = TRUE
WHERE c.activo = TRUE
GROUP BY c.id, c.nombre
ORDER BY cantidad_productos DESC, c.nombre ASC;

-- VERSION B (alternativa de distinta estructura: subconsulta en vez
-- de LEFT JOIN con condicion en el ON)
SELECT c.nombre,
       (SELECT count(*) FROM producto p
        WHERE p.categoria_id = c.id AND p.activo = TRUE) AS cantidad_productos
FROM categoria c
WHERE c.activo = TRUE
ORDER BY cantidad_productos DESC, c.nombre ASC;

-- VERIFICACION DE EQUIVALENCIA SPEC 1 (ambas deben dar 0 filas)
(
  SELECT c.nombre, count(p.id) AS cantidad_productos
  FROM categoria c
  LEFT JOIN producto p ON p.categoria_id = c.id AND p.activo = TRUE
  WHERE c.activo = TRUE
  GROUP BY c.id, c.nombre
) EXCEPT (
  SELECT c.nombre,
         (SELECT count(*) FROM producto p
          WHERE p.categoria_id = c.id AND p.activo = TRUE) AS cantidad_productos
  FROM categoria c
  WHERE c.activo = TRUE
);

(
  SELECT c.nombre,
         (SELECT count(*) FROM producto p
          WHERE p.categoria_id = c.id AND p.activo = TRUE) AS cantidad_productos
  FROM categoria c
  WHERE c.activo = TRUE
) EXCEPT (
  SELECT c.nombre, count(p.id) AS cantidad_productos
  FROM categoria c
  LEFT JOIN producto p ON p.categoria_id = c.id AND p.activo = TRUE
  WHERE c.activo = TRUE
  GROUP BY c.id, c.nombre
);

-- ============================================================
-- SPEC 2 (subconsulta)
-- «Genera una consulta SQL sobre el esquema Food Store que liste los
--   productos VIGENTES (producto.activo = TRUE) cuyo total vendido
--   (suma de subtotal en detalle_pedido) sea MAYOR que el promedio
--   del total vendido de TODOS los productos vigentes. Devuelve el
--   nombre del producto y su total vendido con dos decimales,
--   ordenado de mayor a menor total. No uses SELECT *.»
-- ============================================================

-- VERSION A (generada por la IA a partir de la spec)
SELECT pr.nombre, round(sum(dp.subtotal), 2) AS total_vendido
FROM producto pr
JOIN detalle_pedido dp ON dp.producto_id = pr.id
WHERE pr.activo = TRUE
GROUP BY pr.id, pr.nombre
HAVING sum(dp.subtotal) > (
    SELECT avg(vendido)
    FROM (
        SELECT sum(dp2.subtotal) AS vendido
        FROM producto pr2
        JOIN detalle_pedido dp2 ON dp2.producto_id = pr2.id
        WHERE pr2.activo = TRUE
        GROUP BY pr2.id
    ) t
)
ORDER BY total_vendido DESC;

-- VERSION B (alternativa de distinta estructura: CTE + join en vez
-- de subconsulta en el HAVING)
WITH ventas AS (
    SELECT dp.producto_id, sum(dp.subtotal) AS total_vendido
    FROM detalle_pedido dp
    GROUP BY dp.producto_id
),
promedios AS (
    SELECT avg(total_vendido) AS promedio
    FROM ventas v
    JOIN producto pr ON pr.id = v.producto_id
    WHERE pr.activo = TRUE
)
SELECT pr.nombre, round(v.total_vendido, 2) AS total_vendido
FROM ventas v
JOIN producto pr ON pr.id = v.producto_id
CROSS JOIN promedios
WHERE pr.activo = TRUE
  AND v.total_vendido > promedios.promedio
ORDER BY v.total_vendido DESC;

-- VERIFICACION DE EQUIVALENCIA SPEC 2 (ambas deben dar 0 filas)
(
  SELECT pr.nombre, round(sum(dp.subtotal), 2) AS total_vendido
  FROM producto pr
  JOIN detalle_pedido dp ON dp.producto_id = pr.id
  WHERE pr.activo = TRUE
  GROUP BY pr.id, pr.nombre
  HAVING sum(dp.subtotal) > (
      SELECT avg(vendido)
      FROM (
          SELECT sum(dp2.subtotal) AS vendido
          FROM producto pr2
          JOIN detalle_pedido dp2 ON dp2.producto_id = pr2.id
          WHERE pr2.activo = TRUE
          GROUP BY pr2.id
      ) t
  )
) EXCEPT (
  WITH ventas AS (
      SELECT dp.producto_id, sum(dp.subtotal) AS total_vendido
      FROM detalle_pedido dp
      GROUP BY dp.producto_id
  ),
  promedios AS (
      SELECT avg(total_vendido) AS promedio
      FROM ventas v
      JOIN producto pr ON pr.id = v.producto_id
      WHERE pr.activo = TRUE
  )
  SELECT pr.nombre, round(v.total_vendido, 2) AS total_vendido
  FROM ventas v
  JOIN producto pr ON pr.id = v.producto_id
  CROSS JOIN promedios
  WHERE pr.activo = TRUE
    AND v.total_vendido > promedios.promedio
);

(
  WITH ventas AS (
      SELECT dp.producto_id, sum(dp.subtotal) AS total_vendido
      FROM detalle_pedido dp
      GROUP BY dp.producto_id
  ),
  promedios AS (
      SELECT avg(total_vendido) AS promedio
      FROM ventas v
      JOIN producto pr ON pr.id = v.producto_id
      WHERE pr.activo = TRUE
  )
  SELECT pr.nombre, round(v.total_vendido, 2) AS total_vendido
  FROM ventas v
  JOIN producto pr ON pr.id = v.producto_id
  CROSS JOIN promedios
  WHERE pr.activo = TRUE
    AND v.total_vendido > promedios.promedio
) EXCEPT (
  SELECT pr.nombre, round(sum(dp.subtotal), 2) AS total_vendido
  FROM producto pr
  JOIN detalle_pedido dp ON dp.producto_id = pr.id
  WHERE pr.activo = TRUE
  GROUP BY pr.id, pr.nombre
  HAVING sum(dp.subtotal) > (
      SELECT avg(vendido)
      FROM (
          SELECT sum(dp2.subtotal) AS vendido
          FROM producto pr2
          JOIN detalle_pedido dp2 ON dp2.producto_id = pr2.id
          WHERE pr2.activo = TRUE
          GROUP BY pr2.id
      ) t
  )
);
