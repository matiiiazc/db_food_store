# TP3 — Parte 5: Registro de la competencia de optimización

> La consulta lenta la fija la cátedra el día de la competencia sobre la base masiva común. Este archivo es la plantilla donde se vuelcan los tiempos **reales** (EXPLAIN ANALYZE). Se completa en el momento; aquí se deja preparada la estructura y la estrategia base.

## Consulta de competencia (ejemplo ensayo)

```sql
SELECT c.nombre AS categoria, p.nombre, p.precio, p.stock
FROM producto p
JOIN categoria c ON c.id = p.categoria_id
WHERE c.nombre = 'Pizzas'
  AND p.precio BETWEEN 1000 AND 3000
ORDER BY p.precio DESC;
```

## Estrategia base del equipo

Con la base `food_store_tp3` ya poblada se verifica (Parte 2) que la optimización efectiva más confiable es:
1. Mirar el plan real de la consulta de la competencia con `EXPLAIN ANALYZE`.
2. Identificar el/los nodos dominantes (Seq Scan, sort a disco, agregación pesada).
3. Proponer con la IA un índice o reescritura que ataque ese nodo específico, justificándolo sobre el propio plan.
4. Aplicar SOLO lo que se puede explicar y confirmar la mejora con la medición posterior.

## Registro de la competencia (ejemplo ensayo con consulta tipo cátedra)

| Equipo | Estrategia aplicada | Tiempo antes (ms) | Tiempo después (ms) | Mejora (x) |
|---|---|---|---|---|
| (nuestro equipo) | Índice compuesto `(categoria_id, precio)` para cubrir ambos filtros del WHERE | 39,9 | **5,7** | **7,0×** |
| … | … | … | … | … |

### Plan antes (39,9 ms)

```
Sort (cost=1569..1583 rows=5562) actual time=37.6..38.0
  -> Nested Loop
       -> Seq Scan on categoria c  (filter: nombre = 'Pizzas')
       -> Bitmap Heap Scan on producto p
            Recheck Cond: categoria_id = c.id
            Filter: (precio >= 1000 AND precio <= 3000)
            Rows Removed by Filter: 6904
            -> Bitmap Index Scan on idx_producto_categoria_activo
                 Index Cond: categoria_id = c.id
```

Filtraba por categoría con el índice existente pero el filtro de precio era un **Filter residual** que descartaba 6.904 de las 12.500 filas de Pizzas.

### Plan después (5,7 ms) — con `idx_producto_cat_precio`

```
Sort (cost=1469..1483 rows=5574) actual time=4.2..4.4
  -> Nested Loop
       -> Seq Scan on categoria c  (filter: nombre = 'Pizzas')
       -> Bitmap Heap Scan on producto p
            Recheck Cond: categoria_id = c.id AND precio >= 1000 AND precio <= 3000
            -> Bitmap Index Scan on idx_producto_cat_precio
                 Index Cond: categoria_id = c.id AND precio >= 1000 AND precio <= 3000
```

Con el **índice compuesto**, ambos filtros (`categoria_id` y `precio`) se convierten en **Index Cond** directamente: no se traen las 12.500 filas de Pizzas para luego descartar 6.904, sino que el índice entrega directamente las 5.596 filas que cumplen ambas condiciones. Desaparece el `Rows Removed by Filter`.

## Historial de lo que se probó y se descartó (requisito de la bitácora)

| Qué se probó | Qué se esperaba | Qué pasó | Decisión |
|---|---|---|---|
| Índice compuesto `(categoria_id, precio)` | Reducir las filas escaneadas con Filter residual | El plan cambió: ambos filtros pasaron a ser Index Cond, 6.904 filas descartadas pasaron a no escanearse. Tiempo bajó de 39,9 ms a 5,7 ms. | **Se aplica** — mejora medida 7,0× y se puede justificar: el índice cubre los dos filtros del WHERE en orden. |
| (pendiente: se completa el día de la competencia con la consulta real de la cátedra) | … | … | … |
