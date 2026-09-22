# TPI Food Store — Primera entrega (Parcial)
## Checklist de cobertura de objetivos

Base: **food_store_tp3** (PostgreSQL 18) · Motor exigido: PostgreSQL 16+ con PL/pgSQL.
Esquema base: `schema.sql` (los `*_prueba` referencian archivos de esta carpeta `Parcial/`).

| # | Objetivo del TPI | Evidencia en la entrega | ✓ |
|---|---|---|---|
| 1 | Modelo ER (entes, atributos, claves, cardinalidad, participación) | `01_mer_relacional.md` (sección ER + mapa de participación R1–R7) | ☐ |
| 2 | Paso de ER → relacional (1:N con FK, N:M con tabla intermedia) | `01_mer_relacional.md` (sección "De ER a relacional") | ☐ |
| 3 | Normalización hasta 3FN/BCNF con justificación de dependencias funcionales | `02_normalizacion.md` (DF explícitas + pasos 1FN→2FN→3FN→BCNF) | ☐ |
| 4 | DDL completo (tipos, PK/FK, restricciones, índices) | `ddl.sql` (copia de `schema.sql`) — ENUM, IDENTITY, CHECK, UNIQUE, 2 índices | ☐ |
| 5 | DML y consultas (JOIN, agregación, subconsultas, GROUP BY/HAVING, ventanas) | `03_dml_consultas.md` + `consultas.sql` (x24 consultas que cubren todo) | ☐ |
| 6 | Vistas, funciones y **procedimientos** PL/pgSQL | Vistas `objetos.sql` + funciones `triggers_restricciones.sql` + **procedimiento `CALL`** | ☐ |
| 7 | Reglas de negocio con CHECK, UNIQUE y triggers | `schema.sql` (CHECK/UNIQUE) + `triggers_restricciones.sql` (3 triggers) | ☐ |
| 8 | Transacciones: atomicidad, COMMIT/ROLLBACK, aislamientos, concurrencia | `04_transacciones.md` + `transacciones_prueba.sql` (3 aislamientos + deadlock simulado) | ☐ |
| 9 | Borrado lógico (soft delete) e impacto en consultas e índices | `05_borrado_logico.md` + `borrado_logico_prueba.sql` + índice parcial `WHERE activo` | ☐ |

**Requisitos técnicos del motor (PostgreSQL 16+):**
- ✅ ENUM (`forma_pago_enum`) · TIMESTAMPTZ · IDENTITY · CHECK · UNIQUE → `ddl.sql`
- ✅ Tablas de transición en trigger (`REFERENCING OLD/NEW TABLE`, `FOR EACH STATEMENT`) → `objetos_avanzados.sql` (demo: 1 disparo para 12.500 filas, verificado)
- ✅ JSONB con operadores `->>`, `->`, `@>`, cast booleano → `objetos_avanzados.sql` (demo verificado)
- ✅ Procedimiento PL/pgSQL con `CALL` → `objetos.sql`

**Informe técnico (obligatorio por la cátedra):** `06_informe_tecnico.md`.
**Defensa oral:** `07_defensa_oral.md` (resumen de 1 página para defender el proyecto).

## Cómo verificar cada objetivo en una demostración en vivo

1. Mostrar `01_mer_relacional.md` (DER) y derivar las tablas en pizarra.
2. Mostrar `02_normalizacion.md`: la DF clave `(pedido_id, producto_id) → precio_unitario` y por qué la planilla NO está en 2FN hasta separar `precio_unitario`.
3. Ejecutar `ddl.sql` sobre una base limpia → crea el esquema sin errores.
4. Ejecutar `consultas.sql` → cada grupo de consulta comentado según lo que demuestra (JOIN / agregación / subconsulta / HAVING / ventana).
5. Ejecutar `objetos.sql` → crea 3 vistas, 3 funciones, 1 procedimiento; luego `CALL sp_registrar_pedido(...)`.
6. Ejecutar `transacciones_prueba.sql` → anomalías de aislamiento reproducidas.
7. Ejecutar `borrado_logico_prueba.sql` → `DELETE` rechazado por trigger, `UPDATE activo` funciona, consultas filtran `activo`.