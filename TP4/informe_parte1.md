# TP4 — Parte 1: Laboratorio — consultas analíticas lentas

Base: `food_store_tp3` (masiva: 4 categorías, 50.000 productos, 20.000 clientes, 200.000 pedidos, 600.000 detalles de pedido).
Índices previos de la Semana 3 ya creados: `idx_detalle_producto_cover`, `idx_pedido_fecha`, `idx_producto_cat_precio`, `idx_producto_categoria_activo`.

## Consultas analíticas elegidas (≥ 3 tablas)

### Consulta 1 — Facturación por categoría y mes (4 tablas)

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

Antes (4387 ms): 3 Hash Joins encadenados.

### Consulta 2 — Ranking de clientes por gasto total (3 tablas)

```sql
SELECT cl.nombre || ' ' || cl.apellido AS cliente, count(p.id) AS cantidad_pedidos,
       sum(dp.subtotal) AS total_gastado
FROM cliente cl
JOIN pedido p          ON p.cliente_id = cl.id
JOIN detalle_pedido dp ON dp.pedido_id = p.id
GROUP BY cl.id, cl.nombre, cl.apellido
ORDER BY total_gastado DESC
LIMIT 20;
```

Antes (754 ms): Hash Join + Parallel Hash Join, HashAggregate con spill a disco (Batches 5).

## Diagnóstico sobre el plan real (antes)

**Consulta 1** — el nodo dominante no es un join sino el `Sort` externo a disco (20 MB) para el `GROUP BY mes, nombre` sobre 600.000 filas, más 3 Hash Joins encadenados que arrastran 600.000 filas por nodo. El optimizador elige **Hash Join** en cada cruce.

**Consulta 2** — el optimizador elige **Parallel Hash Join** (dp×pedido, ambos leídos en paralelo) y luego **Hash Join** (pedido×cliente). El cuello de botella es el `HashAggregate` que revienta a disco (Batches 5, Disk Usage) al agrupar 20.000 clientes.

## Propuestas de la IA

| # | Propuesta | Justificación sobre el nodo del plan real | Se aceptó |
|---|-----------|--------------------------------------------|-----------|
| 1 | Reescritura Q1: agrupar por `(mes, categoria_id)` en la subconsulta y unir luego con `categoria` | El plan real muestra el `Sort` externo a disco (20 MB) sobre 600.000 filas agrupando por `c.nombre`; agrupando por el número `categoria_id` se reduce el sort (más chico) y la unión con el nombre (4 filas) se hace al final | Sí |
| 2 | Índice de cobertura `idx_detalle_cover_pedido_prod` en `detalle_pedido (pedido_id, producto_id) INCLUDE (subtotal)` | El plan real muestra `Seq Scan` sobre `detalle_pedido` con 5.606 buffers; un índice de cobertura permite `Index Only Scan` y reduce trabajo en los joins | Sí (no cambió el algoritmo, ver tabla) |
| 3 | Índice `idx_pedido_cliente_fecha` en `pedido (cliente_id, fecha)` | Q2 agrupa por `cliente_id`; el índice evita reescanear el heap al particionar el HashAggregate | Probado: sin efecto medible, se documentó y se descartó para el registro |

## Tabla 1.2 — Resultados

| Consulta | Algoritmo de join (antes) | Cambio aplicado | Algoritmo de join (después) | Mejora |
|---|---|---|---|---|
| C1 — Facturación por categoría y mes | Hash Join ×3 (600k filas por nodo) | Reescritura: agregación anticipada por `categoria_id` + join final con `categoria` | Hash Join ×3 (agregación → sort sobre 60 filas) | **4387 → 2052 ms (2,1×)** |
| C2 — Ranking clientes por gasto | Parallel Hash Join (dp×pedido) + Hash Join (pedido×cliente) | Índice `idx_pedido_cliente_fecha` (sin efecto) | Igual: Parallel Hash Join + Hash Join | **754 → 751 ms (~1,0×, sin mejora)** |

## Análisis del cambio de algoritmo / justificación

- **C1**: el optimizador mantiene **Hash Join** en los tres cruces tanto antes como después (no hay cambio de algoritmo, lo que era esperable: ninguno de los joins filtra por índice, todos recorren 600.000 filas). La mejora real (2,1×) viene de la **reescritura**: la agregación por `categoria_id` reemplaza el `Sort` externo a disco de 20 MB (GroupAggregate sobre 600k filas) por un `HashAggregate` + sort final de 60 filas. El índice de cobertura redujo los buffers de lectura (8.082 → 4.410) pero no fue el factor decisivo.
- **C2**: el cuello de botella es el `HashAggregate` que spillea a disco (Batches 5), no los joins. El nuevo índice no cambió ni el plan ni el tiempo; se documenta como propuesta descartada (no se aplicaron cambios por miedo a un regreso).
- Análisis en términos del nodo concreto (no en generalidades): el nodo que concentra el tiempo en C1 es el `Sort` (cost=114130 → tiempo ~3,8 s de los 4,4 s totales) y en C2 el `HashAggregate` (spill batches), por eso el índice sobre los joins no rindió y la reescritura / el ajuste de agregación sí.

## Verificación con los planes reales

- Plan antes C1: `Execution Time: 4387.557 ms`, `Sort ... external merge Disk: 20160kB`, `Hash Join` ×3.
- Plan después C1 (reescritura): `Execution Time: 2052.146 ms`, `HashAggregate ... Group Key: to_char(month), pr.categoria_id`, `Sort (quicksort 27kB)` sobre 60 filas.
- Plan antes C2: `Execution Time: 753.714 ms`, `Finalize HashAggregate ... Batches: 5 Disk Usage`, Parallel Hash Join.
- Plan después C2: `Execution Time: 751.275 ms`, mismo algoritmo de join.