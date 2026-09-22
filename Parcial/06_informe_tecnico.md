# Informe técnico — Primera entrega TPI Food Store

Resumen de lo actuado en las **Unidades 1, 2 y 3**, cómo se probó cada cosa, qué resultados se obtuvieron y qué se optimizó.

---

## Unidad 1 — Modelo de datos e integridad (Semana 1)

**Qué se implementó:**
- Modelo ER completo del dominio Food Store desde el enunciado (5 entidades: categoria, cliente, producto, pedido, detalle_pedido) con reglas R1–R7 → `01_mer_relacional.md`.
- Paso a modelo relacional (1:N por FK, N:M por entidad asociativa con clave sustituta + UNIQUE `(pedido_id, producto_id)`) → `01_mer_relacional.md`.
- Normalización de la planilla real del negocio hasta 3FN/BCNF con dependencias funcionales explícitas → `02_normalizacion.md`.
- DDL completo en `schema.sql` / `ddl.sql`: ENUM, IDENTITY, PK/FK con `ON DELETE RESTRICT`, CHECK, UNIQUE, índices, `TIMESTAMPTZ`, `NUMERIC`.

**Cómo se probó:** el `schema.sql` se ejecutó de punta a punta sin errores sobre PostgreSQL 18 (creación de las 5 tablas + tipos + restricciones).

**Resultados:** esquema operativo; la cardinalidad parcial (cliente sin pedidos, categoría sin productos) es verificable por consulta (objetivo 5, consulta 3).

## Unidad 1/2 — Integridad, transacciones y concurrencia (Semanas 1-2)

**Qué se implementó:**
- Triggers y funciones `plpgsql` de integridad: baja lógica anti-DELETE, descuento de stock, verificación de subtotal → `triggers_restricciones.sql`.
- Laboratorio de concurrencia con 2 sesiones: lecturas no repetibles (READ COMMITTED vs REPEATABLE READ), lecturas fantasma (READ COMMITTED vs SERIALIZABLE), bloqueo `FOR UPDATE`, deadlock → `informe_concurrencia.md`, `04_transacciones.md`.

**Cómo se probó:** salidas reales con dos consolas `psql` concurrentes; cronómetro para medir el bloqueo. Todo cerrado con ROLLBACK.

**Resultados:** anomalías reproducidas y coincidentes con la teoría; la sesión B de `FOR UPDATE` quedó bloqueada **~3,4 s** hasta el ROLLBACK de A. Protocolo de la cátedra respetado (copia → transacción → respaldo).

## Unidad 2 — Optimización de consultas (Semanas 3-4)

**Qué se implementó:** consultas de reporting reales (4 tablas), medición con `EXPLAIN ANALYZE`, rechazo de propuestas que no mejoran, reescritura con agregación anticipada e índice de cobertura → `TP3/`, `TP4/`, objetivo 5 (`consultas.sql`).

**Cómo se probó:** antes/después sobre la base masiva (50.000 productos, 200.000 pedidos, 600.000 líneas), verificando cambio de plan y tiempos.

**Ajuste detectado en la revisión final:** la consulta 6 (subconsulta correlacionada del objetivo 5) ordenaba por la columna calculada, obligando a PostgreSQL a re-evaluar la subconsulta para las 50.000 filas (plan de costo ~22M, se colgaba). Se acotó el outer a top 5 por precio: idéntica técnica, ahora ejecuta en ~53 ms (verificado con `EXPLAIN (ANALYZE, BUFFERS)`).

**Resultados (antes → después):**
| Consulta | Antes | Después | Ganancia |
|---|---|---|---|
| C1 facturación por categoría/mes | 4387 ms | 2052 ms | **2,1×** |
| C2 ranking de clientes por gasto | 754 ms | 751 ms | sin mejora (descartado el índice) |

Equivalencias de SQL verificadas con `EXCEPT` = 0 filas (RANK vs. subconsulta correlacionada; correlacionada vs. GROUP BY).

## Unidad 3 — Índices, vistas y objetos programables (Semana 5)

**Qué se implementó:**
- 3 índices justificados en spec + medición antes/después; 1 propuesta de IA descartada por sobreindexación → `Parcial/` + `TP5/`.
- 3 vistas (catálogo vigente, pedidos-cliente sin datos sensibles, detalle facturado), 3 funciones `plpgsql` y **procedimiento `sp_registrar_pedido` invocado con `CALL`** → `objetos.sql`.
- Vista materializada de facturación por categoría/mes con índice único y `REFRESH CONCURRENTLY` → `TP5/views.sql`.

**Cómo se probó:** `EXPLAIN ANALYZE` antes/después; equivalencia de vistas con `EXCEPT` (0 filas en las 3); `CALL` real en transacción con ROLLBACK.

**Resultados:**
| Objeto | Antes | Después | Ganancia |
|---|---|---|---|
| Búsqueda catálogo por nombre | Seq 20 ms | Bitmap **8,4 ms** | Seq→Bitmap |
| Cliente por apellido | Seq 15,9 ms | Index **0,9 ms** | ~18× |
| Pedidos tarjeta por mes | 78,4 ms | **6,8 ms** | sin remoción del 33% |
| MV facturación c/mes | 2447 ms | ~15 ms | **~163×** |

Costo de escritura medido: 300 INSERT → 47,5 ms sin los índices nuevos vs 151,6 ms con ellos (+3,2×, aceptado).

## Unidad 3 — Borrado lógico

`activo` en `categoria`/`producto`, trigger anti-DELETE y su impacto en consultas e índices (vista vigente, índice parcial `WHERE activo`) → `05_borrado_logico.md` (demo ejecutada: 50.000 → 49.999 en catálogo, histórico intacto).

## Requisitos técnicos del motor (PostgreSQL 16+)

**Quién los acredita:**
- ENUM (`forma_pago_enum`), `TIMESTAMPTZ`, `IDENTITY`, CHECK y UNIQUE → `ddl.sql`.
- **Tablas de transición** en triggers (`REFERENCING OLD TABLE AS ... NEW TABLE AS ...`, `FOR EACH STATEMENT`) → `objetos_avanzados.sql`. Se auditó un ajuste de precio sobre toda la categoría 1 (12.500 filas) y el trigger statement hizo **un solo disparo** (1 fila en `auditoria_precios`, diff promedio +275,63). Probado y revertido con ROLLBACK.
- **JSONB** (datos semiestructurados de producto: origen, vegano, etiquetas, info nutricional) → `objetos_avanzados.sql`. Se demostraron los operadores `->>`, `->`, `@>` (filtro por etiqueta) y el acceso a valores anidados con cast booleano.
- **Procedimiento PL/pgSQL invocado con `CALL`** → `objetos.sql`.

## Uso de IA

**Herramientas:** OpenCode (IA primaria) y Kiro (requerido por cátedra, **no instalado en la máquina**: los specs se redactaron manualmente con la plantilla de Kiro y se aclara en cada DUIA).

**Para qué se usó (y decisiones aceptadas/descartadas):**
- Generación de SQL de consultas, vistas, índices, triggers y procedimientos → aceptado tras verificación en motor real.
- Interpretación de planes de ejecución (TP4 Parte 2) → la IA cometió **3 imprecisiones reales** que se corrigieron con el plan real (Hash Join ≠ Nested Loop, build/probe, cost estimado ≠ tiempo).
- Propuesta de índice `idx_producto_categoria` → **descartada** por redundancia con `idx_producto_categoria_activo`.
- Propuesta de índice `pedido(cliente_id, fecha)` → **descartada** (no cambió el plan en la competencia).
- Derechos de acceso y seguridad de vistas (no exponer `telefono`) → aceptado.

Los prompts/specs de cada entrega están en los DUIA de `TP3`/`TP4`/`TP5` y en `Parcial/specs/`.

## Ubicación de la evidencia

```
Parcial/
  checklist_tpi.md                 <- mapa objetivo -> evidencia (usar como checklist final)
  01_mer_relacional.md  (obj 1-2)
  02_normalizacion.md   (obj 3)
  ddl.sql               (obj 4)
  consultas.sql + 03_dml_consultas.md   (obj 5)
  objetos.sql           (obj 6)
  triggers_restricciones.sql       (obj 7)
  transacciones_prueba.sql + 04_transacciones.md  (obj 8)
  borrado_logico_prueba.sql + 05_borrado_logico.md  (obj 9)
  06_informe_tecnico.md            (este documento)
  07_defensa_oral.md               (guía de defensa)
```