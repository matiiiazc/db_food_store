# TP4 — Parte 3: Consultas resumen, rankings y subconsultas bajo especificación precisa

## Spec (a) — Ranking con función de ventana

> «Genera una consulta SQL sobre el esquema de Food Store que devuelva, para cada cliente vigente con al menos un pedido, su nombre completo, el total gastado (suma de `detalle_pedido.subtotal` en pedidos no eliminados) y su puesto en un ranking de mayor a menor gasto, **sin colapsar filas** (una fila por cliente, aunque compartan gasto). En caso de empate de gastos, **deben compartir el mismo puesto**. No uses SELECT *.»

*Nota de adaptación al esquema:* en Food Store la entidad es `cliente` (no `usuario`), el total de cada pedido está en `detalle_pedido.subtotal` (no hay columna `total` en `pedido`), y no existe campo de borrado lógico en `pedido` (la baja lógica `activo` sólo existe en `categoria` y `producto`). Se especifica "cliente vigente" sobre la base de que `cliente` no tiene baja lógica en el esquema.

### Versión 1 — función de ventana `RANK()`

```sql
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
```

### Versión 2 — estructura distinta (subconsulta correlacionada que replica RANK, sin ventana)

```sql
WITH g AS (
    SELECT p.cliente_id, sum(dp.subtotal) AS total
    FROM pedido p
    JOIN detalle_pedido dp ON dp.pedido_id = p.id
    GROUP BY p.cliente_id
)
SELECT cl.id, cl.nombre, cl.apellido, g.total,
       (SELECT count(*) + 1 FROM g h WHERE h.total > g.total)::bigint AS puesto
FROM g
JOIN cliente cl ON cl.id = g.cliente_id
ORDER BY (SELECT count(*) + 1 FROM g h WHERE h.total > g.total), cl.id;
```

### Verificación de equivalencia

```sql
(v1) EXCEPT (v2);   -- 0 filas
(v2) EXCEPT (v1);   -- 0 filas
```

Ambas dieron **0 filas** en las dos direcciones → **equivalencia formal verificada**. El puesto de cada cliente, incluidos los empates (mismo gabillado), coincide exactamente.

## Spec (b) — Subconsulta correlacionada

> «Genera una consulta SQL sobre el esquema de Food Store que devuelva, para cada producto, su nombre, su precio y la **diferencia entre ese precio y el precio promedio de los productos de su misma categoría** (cálculo con subconsulta correlacionada). Incluye todos los productos. No uses SELECT *.»

### Versión 1 — subconsulta correlacionada

```sql
SELECT p.id, p.nombre AS producto, p.precio,
       round(p.precio - (SELECT avg(p2.precio)
                         FROM producto p2
                         WHERE p2.categoria_id = p.categoria_id), 2) AS dif_vs_categoria
FROM producto p
ORDER BY p.id
LIMIT 50;
```

### Versión 2 — estructura distinta (join + agregación)

```sql
SELECT p.id, p.nombre AS producto, p.precio,
       round(p.precio - c.promedio, 2) AS dif_vs_categoria
FROM producto p
JOIN (SELECT categoria_id, avg(precio) AS promedio
      FROM producto GROUP BY categoria_id) c
  ON c.categoria_id = p.categoria_id
ORDER BY p.id
LIMIT 50;
```

### Verificación de equivalencia

```sql
SELECT count(*) FROM ( (v1) EXCEPT (v2) ) t;  -- 0
SELECT count(*) FROM ( (v2) EXCEPT (v1) ) t;  -- 0
-- y comprobación de filas totales:
SELECT count(*) FROM producto;                -- 50000
```

Ambas dieron **0 filas** en las dos direcciones (la verificación por EXCEPT se hizo sobre las versiones sin `LIMIT` para no truncar el comparador) → **equivalencia formal verificada**.

## Verificación de equivalencia sobre el ranking — detalle

Se ejecutaron los cuatro `EXCEPT`:
- `(consulta_ranking_v1) EXCEPT (consulta_ranking_v2)` → **0 filas**
- `(consulta_ranking_v2) EXCEPT (consulta_ranking_v1)` → **0 filas**
- `(consulta_correlacionada_v1) EXCEPT (consulta_correlacionada_v2)` → **0 filas**
- `(consulta_correlacionada_v2) EXCEPT (consulta_correlacionada_v1)` → **0 filas**

Resultado: las versiones alternativas de ambas consultas son equivalentes, incluyendo el tratamiento de **empates en el ranking** (comparten el mismo puesto en ambas versiones) y el **no colapso de filas**.