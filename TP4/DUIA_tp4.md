# TP4 — Declaración de Uso de IA (DUIA)

Herramienta: OpenCode.

| # | Parte | Para qué se usó | Prompt / spec (resumen) | Se aceptó / se descartó — por qué |
|---|---|---|---|---|
| 1 | P1 | Elegir consultas analíticas con ≥3 tablas de `queries.sql`/esquema | "Elige consultas analíticas de Food Store que crucen al menos tres tablas (ej. facturación por categoría y mes, ranking por gasto)" | **Aceptado**: se eligieron facturación por categoría y mes (4 tablas) y ranking de clientes por gasto (3 tablas) |
| 2 | P1 | Interpretar plan real y proponer índice de cobertura | "El plan muestra Seq Scan sobre detalle_pedido (5606 buffers); propón un índice" | **Aceptado** (parcial): `idx_detalle_cover_pedido_prod` redujo buffers pero no cambió el algoritmo de join (Hash Join). Documentado. |
| 3 | P1 | Proponer reescritura de agregación anticipada | "El nodo dominante es el Sort a disco de 20MB agrupando por nombre; ¿cómo reducirlo?" | **Aceptado**: reescritura agrupando por `categoria_id` → tiempo 4387→2052 ms (2,1×). Es el cambio determinante. |
| 4 | P1 | Proponer índice para consulta de ranking | "¿Un índice en pedido(cliente_id, fecha) mejora el HashAggregate con spill?" | **Descartado**: sin efecto medible (754→751 ms); el cuello de botella era el spill del HashAggregate, no el join. Registrado en bitácora. |
| 5 | P1 | Verificar plan antes/después | "Compara los planes y los algoritmos de join" | **Aceptado**: se extrajeron los planes con EXPLAIN ANALYZE y se verificó Hash Join en los 3 cruces antes y después. |
| 6 | P2 | Explicar plan de join sin contexto | "Explica este plan nodo por nodo, identificando tabla externa/interna y el costo de cada nodo" (se pasó solo el texto del plan) | **Se contrastó**: la explicación de la IA tenía 3 imprecisiones (Hash Join≠Nested Loop, build/probe mal identificado, estimated cost 38088≠tiempo total 4387ms). Documentadas en informe_parte2. |
| 7 | P3 | Generar SQL desde spec (ranking con ventana) | «Para cada cliente vigente con al menos un pedido, nombre, total gastado y puesto en ranking de mayor a menor gasto, sin colapsar filas, empates comparten puesto. No uses SELECT *.» | **Aceptado**: versión 1 con `RANK() OVER`. |
| 8 | P3 | Generar segunda versión con estructura distinta | "Resuelve la misma spec con otra estructura (subconsulta correlacionada)" | **Aceptado**: versión 2 replica RANK con `count(*)+1` de totales mayores. Equivalencia verificada por EXCEPT (0 filas, ambas direcciones). |
| 9 | P3 | Generar SQL desde spec (subconsulta correlacionada) | «Para cada producto, nombre, precio y diferencia contra el promedio de su categoría» | **Aceptado**: versión con subconsulta correlacionada. |
| 10 | P3 | Segunda versión de la subconsulta | "Resuelve con join + agregación" | **Aceptado**: versión con join a subconsulta `GROUP BY categoria_id`. Equivalencia por EXCEPT (0 filas, ambas direcciones). |
| 11 | P4 | Estrategia de competencia | "¿Qué reescritura/índice gana en la consulta común de facturación?" | **Aceptado**: reescritura de agregación anticipada (2,14×). Se descartaron índice `pedido(cliente_id,fecha)` y el índice de cobertura "solo" (sin reescritura). |

**Resultado de Uso de IA:** se aceptaron las propuestas que se validaron contra el plan real; se descartaron 2 propuestas de índices y se corrigieron 3 imprecisiones de interpretación de planes en la Parte 2.