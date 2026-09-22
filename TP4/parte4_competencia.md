# TP4 — Parte 4: Competencia de optimización entre equipos

## Consulta común de la competencia (igual para todos los equipos)

> Consulta analítica lenta con al menos dos JOIN y una agregación: **facturación por categoría y mes** sobre la base masiva compartida.

```sql
SELECT to_char(date_trunc('month', p.fecha), 'YYYY-MM') AS mes,
       c.nombre AS categoria, sum(dp.subtotal) AS facturado
FROM detalle_pedido dp
JOIN pedido    p  ON p.id  = dp.pedido_id
JOIN producto  pr ON pr.id = dp.producto_id
JOIN categoria c  ON c.id  = pr.categoria_id
GROUP BY mes, c.nombre
ORDER BY mes, facturado DESC;
```

## Estrategia aplicada

1. Medición inicial con `EXPLAIN ANALYZE` (antes): **4387 ms**, 3 Hash Joins encadenados, `Sort` externo a disco de 20 MB.
2. Análisis del plan real: el cuello de botella es el sort/agregación sobre 600.000 filas agrupando por `c.nombre`, más los tres Hash Joins que arrastran las 600.000 filas.
3. Propuestas de la IA documentadas en la bitácora:
   - **Reescritura**: agregar por `(mes, categoria_id)` en una subconsulta y unir luego con `categoria` (el sort pasa a 60 filas y el join final con el nombre de 4 categorías se hace sobre el resultado agregado). → **SE APLICÓ**.
   - **Índice de cobertura** en `detalle_pedido (pedido_id, producto_id) INCLUDE (subtotal)`: reduce buffers pero no cambia la complejidad del sort. → **SE APLICÓ** (efecto parcial, documentado).
   - **Índice en `pedido (cliente_id, fecha)`**: propuesto para la consulta de ranking; sin efecto medible. → **SE DESCARTÓ** y quedó registrado.
4. Medición final con `EXPLAIN ANALYZE` (después): **2052 ms** con la reescritura.

## Registro de la competencia

| Equipo | Estrategia aplicada | Tiempo antes (ms) | Tiempo después (ms) | Mejora (x) |
|---|---|---|---|---|
| Nuestro equipo | Reescritura (agregación anticipada por `categoria_id` + join final) + índice de cobertura en `detalle_pedido` | 4387 | 2052 | **2,14×** |
| (otros equipos) | — | — | — | — |

## Propuestas de la IA que no funcionaron (registro exigido)

| Propuesta de la IA | Por qué se descartó |
|---|---|
| Índice `idx_pedido_cliente_fecha` en `pedido (cliente_id, fecha)` | No cambió el plan ni el tiempo real de la consulta 2 (754 → 751 ms). El cuello de botella era el `HashAggregate` con spill a disco (Batches 5), que el índice no resuelve. |
| Índice de cobertura en `detalle_pedido` solo | Mejoró buffers de lectura (8082 → 4786) pero no fue decisivo: sin la reescritura el tiempo solo bajaba a ~3530 ms. El cambio determinante fue la reescritura. |

## Resultado

La competencia se cierra con una mejora real de **2,14×** (4387 → 2052 ms) sobre la consulta común, documentando en la bitácora tanto lo que funcionó como lo que no. El optimizador mantuvo `Hash Join` en los tres cruces; la mejora provino de atacar el nodo dominante (el sorteado/agregación) mediante reescritura, validada en el plan real antes y después.