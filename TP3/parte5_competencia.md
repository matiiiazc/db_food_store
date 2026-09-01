# TP3 — Parte 5: Registro de la competencia de optimización

> La consulta lenta la fija la cátedra el día de la competencia sobre la base masiva común. Este archivo es la plantilla donde se vuelcan los tiempos **reales** (EXPLAIN ANALYZE). Se completa en el momento; aquí se deja preparada la estructura y la estrategia base.

## Estrategia base del equipo

Con la base `food_store_tp3` ya poblada se verifica (Parte 2) que la optimización efectiva más confiable es:
1. Mirar el plan real de la consulta de la competencia con `EXPLAIN ANALYZE`.
2. Identificar el/los nodos dominantes (Seq Scan, sort a disco, agregación pesada).
3. Proponer con la IA un índice o reescritura que ataque ese nodo específico, justificándolo sobre el propio plan.
4. Aplicar SOLO lo que se puede explicar y confirmar la mejora con la medición posterior.

Lección de la Parte 2 aplicable a la competencia:
- Un índice o reescritura **puede cambiar el plan sin mejorar el tiempo** (consulta 2 del informe). Se decide por el **tiempo real**, no por el costo estimado ni por el aspecto del plan.
- Un `GROUP BY` por columna indexada (o un index-only scan de cobertura) puede dar la mayor ganancia, como en el caso estrella de la Parte 2 (3,4×).

## Registro

| Equipo | Estrategia aplicada | Tiempo antes (ms) | Tiempo después (ms) | Mejora (x) |
|---|---|---|---|---|
| (nuestro equipo) | *(a completar el día de la competencia)* | — | — | — |
| … | … | … | … | … |

## Historial de lo que se probó y se descartó (requisito de la bitácora)

| Qué se probó | Qué se esperaba | Qué pasó | Decisión |
|---|---|---|---|
| (a completar el día de la competencia) | … | … | … |
