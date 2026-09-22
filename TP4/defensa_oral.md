# TP4 — Defensa oral

## Consulta 1 (facturación por categoría y mes)

- **Algoritmo de join antes**: 3 Hash Joins encadenados (detalle×pedido, ×producto, ×categoria); el optimizador no usó Nested Loop ni Merge Join porque da igual cómo se lean los 600.000 detalles, un Hash Join balancea los dos lados.
- **Qué medía el plan**: el plan real mostraba `Sort` externo a disco de 20 MB para agrupar por `c.nombre` sobre 600.000 filas; ese era el nodo dominante (≈3,8 s de 4,4 s).
- **Qué propuso la IA y qué acepté**: (1) reescritura agrupando por `categoria_id` numérico antes de unir el nombre — aceptada porque el plan mostró que el sort se disparaba por la clave larga; (2) índice de cobertura en detalle_pedido — aceptado, redujo buffers pero no cambió el join; (3) índice en pedido(cliente_id,fecha) — descartado porque el plan de la consulta 2 no lo usaba (el cuello era el spill del HashAggregate).
- **Resultado**: Hash Join se mantiene después (no cambia el algoritmo en este caso); la mejora 4387→2052 ms viene de atacar el nodo del sort, no los joins.

## Consulta 2 (ranking de clientes por gasto)

- El optimizador usó Parallel Hash Join (dp×pedido) + Hash Join (pedido×cliente) + HashAggregate con spill (Batches 5). El índice propuesto no lo usó → 754→751 ms (sin mejora), se descartó y quedó en la bitácora.

## Parte 2 (lectura crítica)

- La IA dijo que el plan usaba Nested Loop con búsqueda por índice: falso, son Hash Joins.
- La IA dijo que `categoria` (build de 4 filas) era el nodo más caro y que su costo 38088 "era el tiempo total": falso, 38088 son unidades de costo estimado y el tiempo real es 4387 ms.

## Parte 3 (equivalencia)

- Ranking v1 con `RANK()` y v2 con `count(*)+1` de totales mayores son equivalentes: 4 EXCEPT = 0 filas. Los empates comparten puesto y no se colapsan filas.
- Subconsulta correlacionada (diff vs promedio de su categoría) = join+agregación: 2 EXCEPT = 0 filas.

## Parte 4 (competencia)

- Consulta común resuelta con reescritura de agregación anticipada + índice de cobertura: 4387 → 2052 ms = **2,14×**, justificada nodo a nodo.