# TP3 — Optimización de Consultas (Unidad 2, Semana 3)

Entrega del trabajo práctico completo sobre **Food Store**, con la base `food_store_tp3` poblada masivamente y optimización medida con `EXPLAIN ANALYZE` real (la IA propone, el estudiante verifica).

## Entregables

| Entregable | Archivo |
|---|---|
| Script de carga masiva (leído, probado, ejecutado bajo protocolo) | `carga_masiva.sql` |
| Consultas lentas + EXPLAIN ANALYZE (planes antes) | `consultas_lentas.sql` |
| Índices / reescritura aplicados | `optimizaciones.sql` |
| Informe Parte 2 + tabla comparativa + hallazgos | `informe_parte2.md` |
| Lectura crítica de un plan explicado por IA | `informe_parte3.md` |
| Consultas bajo spec + verificación de equivalencia | `parte4_equivalencia.sql` → `informe_parte4.md` |
| Registro de la competencia (Parte 5) | `parte5_competencia.md` |
| Declaración de Uso de IA (DUIA) | `DUIA_tp3.md` |
| Guía de defensa oral | `defensa_tp3.md` |

## Resultado central (Parte 2) — medido, no estimado

| Consulta | Antes | Después | Mejora |
|---|---|---|---|
| Resumen de ventas por producto | 994 ms (Seq Scan + HashAggregate a disco) | **290 ms** (Index Only Scan de cobertura) | **3,4×** |
| Facturación por rango de fechas | 114 ms (Seq Scan 200k) | 124 ms (Bitmap Index Scan; plan mejorado, rango poco selectivo) | plan sí, tiempo marginal |
| Total vendido por mes | 1734 ms (sort a disco 27MB) | 1552 ms | marginal (no mejoró el sort) |

## Protocolo de seguridad aplicado

- Copia de trabajo `food_store_tp3` creada desde el esquema (NUNCA sobre `plantilla_base`).
- Respaldo previo (`pg_dump -Fc food_store_tp3_respaldo.dump`).
- Carga masiva dentro de `BEGIN...COMMIT` con triggers desactivados durante el seed y reactivados al final (decisión documentada y reversible).
- `ANALYZE` tras la carga para refrescar estadísticas antes de medir.
