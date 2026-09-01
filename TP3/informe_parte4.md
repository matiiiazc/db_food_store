# TP3 — Parte 4: Consultas resumen y subconsultas bajo especificación precisa

> Se practica el flujo de especificar con precisión (spec) y verificar la **equivalencia** de dos versiones que responden la misma pregunta con distinta estructura, usando `EXCEPT` (0 filas en ambas direcciones).

## Spec 1 — Agregación / resumen

> «Genera una consulta SQL sobre el esquema Food Store que devuelva, para cada categoría **vigente** (`categoria.activo = FALSE` son las dadas de baja y NO deben aparecer), el nombre de la categoría y la cantidad de productos **vigentes** (`producto.activo = TRUE`) que tiene, incluyendo las categorías sin productos vigentes con cantidad 0. Ordená de mayor a menor cantidad (y por nombre como desempate asc). No uses `SELECT *`. Usá LEFT JOIN.»

### Versión A (generada por la IA) — LEFT JOIN con condición en el ON

```sql
SELECT c.nombre, count(p.id) AS cantidad_productos
FROM categoria c
LEFT JOIN producto p ON p.categoria_id = c.id AND p.activo = TRUE
WHERE c.activo = TRUE
GROUP BY c.id, c.nombre
ORDER BY cantidad_productos DESC, c.nombre ASC;
```

### Versión B (escrita de forma independiente, distinta estructura) — subconsulta escalar

```sql
SELECT c.nombre,
       (SELECT count(*) FROM producto p
        WHERE p.categoria_id = c.id AND p.activo = TRUE) AS cantidad_productos
FROM categoria c
WHERE c.activo = TRUE
ORDER BY cantidad_productos DESC, c.nombre ASC;
```

### Verificación de equivalencia

```sql
(A) EXCEPT (B);  -- 0 filas
(B) EXCEPT (A);  -- 0 filas
```

**Resultado: ambas devuelven 0 filas en los dos EXCEPT → equivalentes.** ✅

Nota técnica: la condición `p.activo = TRUE` va **en el JOIN** (no en el WHERE) en la versión A; de ir en el WHERE un LEFT JOIN se convertiría en INNER JOIN y perdería las categorías con 0 productos vigentes. La versión B logra lo mismo con una subconsulta correlacionada, que cuenta solo los productos vigentes de cada categoría.

---

## Spec 2 — Con subconsulta

> «Genera una consulta SQL sobre el esquema Food Store que liste los productos **vigentes** (`producto.activo = TRUE`) cuyo **total vendido** (suma de `subtotal` en `detalle_pedido`) sea **MAYOR que el promedio** del total vendido de TODOS los productos vigentes. Devolvé el nombre del producto y su total vendido con dos decimales, ordenado de mayor a menor total. No uses `SELECT *`.»

### Versión A (generada por la IA) — subconsulta escalar en el HAVING

```sql
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
```

### Versión B (escrita de forma independiente, distinta estructura) — CTE + join

```sql
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
```

### Verificación de equivalencia

```sql
(A) EXCEPT (B);  -- 0 filas
(B) EXCEPT (A);  -- 0 filas
```

**Resultado: ambas devuelven 0 filas en los dos EXCEPT → equivalentes.** ✅

Nota: con datos distribuidos casi uniformemente (carga masiva), el total vendido por producto varía poco alrededor del promedio, por lo que la consulta devuelve una cantidad grande de filas (≈24.000 de 50.000). La equivalencia se verifica de forma formal con EXCEPT, no por "corre sin error".

---

## Conclusión

En ambos casos se partió de una **spec precisa** (tablas, filtro de borrado lógico con `activo`, columnas de salida, orden, corte) y se generaron **dos versiones de distinta estructura** (LEFT JOIN vs. subconsulta escalar; HAVING-subconsulta vs. CTE+join). La verificación con `EXCEPT` en las dos direcciones devolvió **0 filas**, lo que demuestra formalmente la **equivalencia** de cada par. Esto cumple el flujo que la cátedra pide: verificar que lo que generó la IA responde la pregunta, no solo que "corre sin error".
