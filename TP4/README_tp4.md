# TP4 — Semana 4: Reportes analíticos asistidos por IA (joins, subconsultas, agregación y ventana)

Base de Datos II · Unidad 2 · Optimización de Consultas · Proyecto integrador Food Store.

## Estructura

| Archivo | Contenido |
|---|---|
| `parte1_consultas.sql` | Consultas analíticas (≥3 tablas) medidas ANTES con EXPLAIN ANALYZE (ejercicios 1 y 2) |
| `parte1_optimizacion.sql` | Reescritura (ej. 3), índice de cobertura (ej. 4) y medición DESPUÉS de la consulta 2 (ej. 5) |
| `informe_parte1.md` | Tabla comparativa antes/después con algoritmo de join identificado |
| `informe_parte2.md` | Lectura crítica del plan de join interpretado por IA (3 imprecisiones reales) |
| `parte3_ranking.sql` | Spec ranking con ventana: versión 1 (RANK) y versión 2 (subconsulta correlacionada) + EXCEPT (0 filas) |
| `parte3_subconsulta_correlacionada.sql` | Spec subconsulta correlacionada con join+agregación alternativo + EXCEPT (0 filas) |
| `informe_parte3.md` | Specs, SQL generado y verificación de equivalencia |
| `parte4_competencia.md` | Registro de la competencia (4387 → 2052 ms, 2,14×) y propuestas descartadas |
| `DUIA_tp4.md` | Declaración de Uso de IA completa |
| `defensa_oral.md` | Guion de defensa oral del TP4 |

## Cómo reproducir

1. `parte1_consultas.sql` → mide 4387 ms (C1) y 754 ms (C2), 3 Hash Joins / Parallel Hash Join.
2. `parte1_optimizacion.sql` → reescritura (2052 ms) e índice de cobertura.
3. `parte3_ranking.sql` y `parte3_subconsulta_correlacionada.sql` → verificaciones EXCEPT (0 filas en las 4 direcciones).

## Resultados clave

- **C1 facturación por categoría y mes**: 4387 → **2052 ms (2,1×)**, Hash Join en los 3 cruces antes y después.
- **C2 ranking clientes por gasto**: 754 → 751 ms (sin mejora, propuesta de índice descartada).
- **Parte 2**: 3 imprecisiones reales de la IA sobre el plan (Hash Join≠Nested Loop, build/probe mal identificado, estimated cost 38088≠4387 ms).
- **Parte 3**: 4 verificaciones EXCEPT = 0 filas → equivalencia formal de rankings (empates compartidos, sin colapso de filas) y de subconsulta correlacionada vs join+agregación.
- **Parte 4**: competencia ganada con mejora **2,14×** documentada.