# DUIA — Declaración de Uso de Inteligencia Artificial

**Asignatura:** Base de Datos II — Tecnicatura Universitaria en Programación (UTN)
**Trabajo:** TP N.º 8 — «Food Store en la feria: la base de la tablet y el cierre de la capa de datos» (Unidades 8, cierre de cursada)
**Ciclo:** 2026

## Herramientas utilizadas
- **OpenCode** (asistente de IA): apoyo para redactar la spec (Kiro) a partir de la consigna, generar/esquematizar scripts SQL (SQLite/PostgreSQL) y realizar una revisión crítica (code review) de scripts de la cursada.
- **Kiro (formato de spec):** se elaboraron `requirements.md` (EARS), `design.md` y `tasks.md` como especificación previa; el código se generó/ajustó a partir de esas tareas.

## Uso declarado
1. Generación asistida de borradores de `schema_sqlite.sql`, `pruebas_sqlite.sql`, `semaforo.sql` y guiones de simulación, **siempre revisados, probados y corregidos** por el equipo antes de su ejecución/entrega.
2. Apoyo en la comparación/explicación de resultados (C2–C6, semáforo) y en la redacción del informe, contrastado con evidencias reales (ejecuciones en SQLite/PostgreSQL).
3. Revisión crítica (code review) de scripts de la cursada: los hallazgos se verificaron contra el código/base real y se registró para cada uno la decisión (aceptado/corregido/descartado) con fundamento (ver informe 3.c y `bitacora_ia.md`).

## Delimitación y verificación
- No se incorporaron contraseñas, correos ni datos personales reales en SQLite ni en los prompts (datos inventados). Se trabajó sobre copia/instantánea y la simulación **no modificó** stock, precios ni pedidos en PostgreSQL (verificado).
- Todo lo sugerido por la IA fue leído, comprendido y probado; las sugerencias incorrectas o no aplicables fueron **descartadas o corregidas** (documentadas en la bitácora). El equipo asume responsabilidad por el contenido entregado y puede defenderlo.