# TP3 — Parte 2: Consultas lentas, EXPLAIN y optimización medida

> Laboratorio de optimización sobre `food_store_tp3` (copia de trabajo).
> Base poblada: 4 categorías · 50.000 productos · 20.000 clientes · 200.000 pedidos · 600.000 líneas de `detalle_pedido`.

## Consultas seleccionadas

Se eligieron tres consultas de **reporting** reales sobre el modelo (variantes propias permitidas por la consigna). Ninguna puede resolverse con los índices del esquema base, por eso producen escaneos y agregaciones pesadas.

1. **Resumen de ventas por producto** (unidades y total vendido) — agrega sobre las 600.000 líneas.
2. **Facturación por rango de fechas** (listado de facturas de un año, con cliente) — filtra `pedido` por fecha; no existía índice por fecha.
3. **Total vendido por mes** (reporte histórico) — cruza detalle con pedido por fecha y agrega por mes.

## Propuestas de la IA (justificadas sobre el plan real)

| # | Cambio propuesto | Qué nodo ataca | Justificación sobre el plan |
|---|---|---|---|
| 1 | Reescritura: agrupar por `producto_id` (usar índice de cobertura) y **después** unir con `producto`. + índice `idx_detalle_producto_cover (producto_id) INCLUDE (cantidad, subtotal)` | `Parallel Seq Scan on detalle_pedido` + `HashAggregate` con spool a disco (`Batches: 5`, `Disk Usage ~7MB`) | El `GROUP BY pr.nombre` fuerza el Hash Join (con producto) **antes** de agregar, rompiendo el index-only scan. Agrupando por `producto_id` el índice de cobertura responde la agregación sin leer el heap y solo después se une con producto para traer el nombre. |
| 2 | Índice `CREATE INDEX ON pedido (fecha)` | `Seq Scan on pedido` con `Rows Removed by Filter: 122160` | El Seq Scan recorre las 200.000 filas para quedarse con 78.840 de un año. El índice permite `Bitmap Index Scan` y reduce el acceso a las filas del rango. |
| 3 | Reutiliza el mismo índice en `pedido(fecha)` | sort a disco `external merge Disk: 27136kB` sobre 600.000 filas | Se esperaba que ordenar por fecha permitiera agrupar por mes sin el sort gigante; en la práctica el join es por `pedido_id`, no por fecha, así que el índice no alimenta el orden de la agregación. |

## Tabla comparativa de resultados

| # | Consulta | Plan antes | Cambio | Plan después | Tiempo antes | Tiempo después | Mejora |
|---|---|---|---|---|---|---|---|
| 1 | Resumen ventas por producto | Parallel Seq Scan + HashAggregate spool (cost 60128) | Reescritura + índice de cobertura | **Index Only Scan** (Heap Fetches 0) + GroupAggregate (cost 29894) | **994 ms** | **290 ms** | **3,4× (‑71%)** ✅ |
| 2 | Facturación rango de fechas | Seq Scan pedido 200k (cost 13805) | Índice `pedido(fecha)` | **Bitmap Index Scan** `idx_pedido_fecha` (cost 13656) | **114 ms** | **124 ms** | Plan mejoró (nodo cambiado), tiempo similar ⚠️ |
| 3 | Total vendido por mes | Seq Scan detalle + sort 27MB (cost 137102) | Índice `pedido(fecha)` | Igual (sort 27MB persistió) (cost 137102) | **1734 ms** | **1552 ms** | Marginal (~10%, ruido) ❌ |

## Hallazgos — qué se aceptó, qué se descartó y por qué (criterio de aceptación)

### Consulta 1 — propuesta ACEPTADA (mejora real y grande)
- **Antes**: `Parallel Seq Scan on detalle_pedido` + HashAggregate que revienta a disco (**Batches: 5, ~7MB**), después `Gather Merge` con otra pasada a disco. 994 ms.
- **Después**: reescritura que agrupa por `producto_id` → **Index Only Scan on `idx_detalle_producto_cover`** con `Heap Fetches: 0`, GroupAggregate **sin** spool a disco. 290 ms.
- **Por qué funciona**: el `GROUP BY pr.nombre` original obligaba al plan a hacer el join con `producto` primero y perder la cobertura del índice. Al agregar por la columna indexada (`producto_id`) el índice entrega las 600.000 filas sin tocar el heap, y el join con `producto` (50.000 filas, barato) se hace al final para traer el nombre.
- **Decisión**: se mantiene la reescritura + el índice. Es la mejora estrella del informe.

### Consulta 2 — propuesta PARCIALMENTE exitosa (cambió el plan, no el tiempo)
- **Antes**: `Seq Scan on pedido` con `Rows Removed by Filter: 122160`, cost 13805, 114 ms.
- **Después**: `Bitmap Index Scan on idx_pedido_fecha` + `Bitmap Heap Scan`, cost 13656 (mejor), pero 124 ms.
- **Por qué no cambió el tiempo**: el rango `2025-01-01..2026-01-01` devuelve el **40%** de la tabla (78.840 de 200.000). El índice evita leer las 200.000 filas del log pero el heap de 78.840 bloques cuesta lo que ahorra. El índice **sí** es correcto y demostró que cambió el plan (exactamente el nodo predicho); con rangos pequeños (un mes, un día) la ganancia sería clara. No se desecha: se documenta que el índice es bueno pero el rango de este test no lo luce.
- **Decisión**: el índice se mantiene (mejora el plan; es el acceso correcto para consultas puntuales). La limitación es del rango de test, no del índice.

### Consulta 3 — propuesta DESCARTADA a nivel de plan (documentado, no en silencio)
- **Antes** y **después**: el plan quedó esencialmente igual — `Seq Scan on detalle_pedido` + Hash Join por `pedido_id` + **sort a disco de 27.136 kB**.
- **Por qué no funcionó**: el `Group Key` es `date_trunc('month', fecha)` y el join entre `detalle_pedido` y `pedido` es por `pedido_id`, **no** por `fecha`. El índice en `pedido(fecha)` no participa del orden de la agregación. El sort gigante viene de ordenar 600.000 filas por mes, y ningún índice del esquema evita ordenar por `date_trunc(month)`.
- **Decisión**: no hay índice que mejore esta consulta con `count(distinct p.id)` + `sum` por mes. Se documenta qué se esperaba, qué pasó y por qué. La propuesta de la IA **no se aplica a ciegas**: se probó, se midió y se deja registro de que el índice de fecha no la ayuda.

## Conclusión

Tres decisiones sustentadas en medición, no en confianza a la IA:
1. Reescritura + índice de cobertura → 3,4× más rápido (medido, el plan cambió de Seq Scan a Index Only Scan).
2. Índice por fecha → mejoró el plan de la consulta 2 pero el rango de test es poco selectivo; se documenta.
3. Índice por fecha → no mejoró la consulta 3 (el sort está causado por el Group Key de mes, no por falta de índice); se descarta con registro.

La conclusión pedagógica: **el código generado por IA se valida con EXPLAIN ANALYZE real**. Dos de las tres propuestas de la IA no mejoraron el tiempo real (una por rango poco selectivo, otra por causa equivocada), y solo la reescritura medida confirmó la mejora. Sin medir, se habría creído que el índice de fecha "optimiza" la consulta 3 cuando en realidad no hace nada.
