# Objetivo 5 — DML y consultas

Script evidencia: `consultas.sql` (10 consultas) + los scripts históricos de TP3 (`consultas_lentas.sql`, `optimizaciones.sql`) y TP4 (`parte1_consultas.sql`, `parte3_ranking.sql`, `parte3_subconsulta_correlacionada.sql`).

## Consultas del `consultas.sql` y qué demuestra cada una

| # | Técnica | Consulta (resumen) |
|---|---|---|
| 1 | JOIN de 4 tablas | Facturación por categoría y mes (detalle→pedido→producto→categoria) |
| 2 | JOIN de 3 tablas + agregación | Top clientes por total gastado |
| 3 | **LEFT JOIN** (participación parcial) | Clientes SIN pedidos (muestran la cardinalidad parcial) |
| 4 | **Agregación** (count, sum) | Resumen de ventas por producto |
| 5 | **Agregación + DISTINCT** | Pedidos y clientes distintos por forma de pago |
| 6 | **Subconsulta correlacionada** | Producto vs. promedio de su categoría |
| 7 | **Subconsulta en FROM** | Total por cliente a partir de una subconsulta agregada |
| 8 | **GROUP BY + HAVING** | Meses con facturación superior a un umbral |
| 9 | **Función de ventana RANK()** | Ranking de clientes por gasto (TP4) |
| 10 | **Ventana PARTITION BY** | Ranking de precios dentro de cada categoría |

## Verificación (motor real, food_store_tp3)

- Consultas 3, 5, 6, 7, 10 verificadas por ejecución directa en PostgreSQL 18 (resultados correctos arriba).
- Consultas 1, 2, 4, 8, 9 verificadas en TP4 con `EXPLAIN ANALYZE` (planes y tiempos documentados en `TP4/informe_parte1.md`):
  - C1 (equivalente a la #1): 4387 → 2052 ms tras reescritura con agregación anticipada (**2,1×**).
  - C2 (equivalente a la #2): 754 ms, sin mejora con índice (spill del HashAggregate).
- **Equivalencias de ventanas/CTE (TP4, parte 3):** `RANK()` vs. subconsulta correlacionada replicando RANK → `EXCEPT` = 0 filas en ambas direcciones. Subconsulta correlacionada vs. JOIN+GROUP BY → 0 filas de diferencia.

## Muestra de salidas reales

- **Forma de pago (consulta 5):** EFECTIVO 66.620 / TARJETA 66.612 / TRANSFERENCIA 66.768 pedidos (clientes distintos ≈ 19.2-19.3k cada uno).
- **Cliente sin pedidos (consulta 3):** existe al menos «Nombre14494 Apellido14494» con 0 pedidos → demuestra la participación parcial de la relación R2 en datos.
- **Ranking productos por categoría (consulta 10):** el producto más caro de Bebidas es «Producto 22366» con 4999.97.
- Ranking de clientes por gasto (consulta 9): tope ~1.109.688,80 (cliente Nombre2813).