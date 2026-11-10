# DUIA GLOBAL — 2ª Entrega TPI Food Store (Unidades 4 a 8)

- **Asignatura:** Bases de Datos II · **Proyecto:** Food Store · **Ciclo:** 2026.
- **Alcance:** consolidación del uso de IA de toda la 2ª entrega (U4–U8) más el proceso de cierre, según exige la condición oficial («Todo uso de IA se declara mediante la Declaración de Uso de IA (DUIA): herramienta utilizada, finalidad y prompts o specs empleados»). El detalle completo por unidad vive en las DUIA/bitácoras referenciadas; este documento es el índice consolidado y no reemplaza a las fuentes.

## 1. Declaración global

| Campo | Declaración |
|---|---|
| **Herramienta** | OpenCode (asistente de IA en terminal; modelo `Big Pickle` / proveedor `opencode`). Única herramienta de IA usada en la cursada. |
| **Kiro** | No instalado en el entorno: las especificaciones (`requirements.md` en notación EARS, `design.md`, `tasks.md`) se redactaron con su plantilla, y los scripts se generaron con OpenCode a partir de esas specs (mismo criterio declarado en U5 y U8). |
| **Versionado** | Git, repo `https://github.com/matiiiazc/db_food_store.git` (rama `main`), commits por unidad/parte (ver `CHECKLIST_TRAZABILIDAD_ENTREGA2.md`). |
| **Finalidad** | Apoyo en: redacción de specs Kiro; generación/esquematización de scripts SQL (PostgreSQL/PLpgSQL, SQLite), PowerShell, JS/Python; lectura crítica de planes y resultados; reconstrucción de incidentes desde logs anonimizados; **code review** de los scripts de la cursada; y redacción de informes técnicos. |
| **Regla transversal** | Ningún artefacto generado por IA se ejecutó sin lectura línea por línea, comprensión y prueba controlada (copia nueva, transacción con `ROLLBACK`, o respaldo previo). La decisión final fue siempre humana y quedó documentada. |

## 2. Uso declarado y decisiones por unidad

### Unidad 4 — TP6 (FNBC + desnormalización) — specs Kiro nuevas de esta entrega
- **Specs/prompts empleados:** consigna del TP6 y objetivo oficial de la 2ª entrega («migración de datos sin pérdida, ejecutada dentro de transacciones reversibles y especificada en Kiro, con plan de reversión obligatorio») → spec `TP6/specs/kiro_fnbc/requirements.md` (EARS, REQ-01…REQ-06) y `design.md` (§2 estrategia transaccional, §6 plan de reversión).
- **Generado con IA:** `TP6/04_migracion_transaccional_reversible.sql` (guarda anti-`food_store_tp3`/bases de sistema, Corrida A COMMIT verificado con `EXCEPT=0` dentro de la transacción, Corrida B inyección de fallo DF violada → `ROLLBACK` con restauración exacta) y sección g) del informe.
- **Aceptado (tras verificación):** el envoltorio transaccional completo; la verificación de equivalencia **dentro** de la transacción antes del `COMMIT`; la prueba de reversibilidad con fila anómala `(501,31,801)` sobre copia temporal.
- **Descartado:** ninguna propuesta en esta unidad — todo se validó con corridas reales (evidencia `TP6/evidencia/04_migracion_transaccional_20261109_235808.txt`, 0,68 s, sobre copia restaurada `food_store_tp3_u4_fnbc_20261109_235630`).
- **DUIA/bitácora de detalle:** `TP6/specs/kiro_fnbc/` + `TP6/03_informe_tp6.md` §g.

### Unidad 5 — Administración y seguridad
- **Specs/prompts:** spec Kiro `docs/kiro_roles_spec/` y prompts por parte (A roles, B auditoría, C simulacro/reconstrucción, D anonimización) — transcripción completa en `U5_admin_seguridad/BITACORA.md` (tabla prompt → respuesta → validación humana).
- **Aceptado:** `SECURITY DEFINER` en `fn_autenticar`/`fn_resetear_password`; auditoría nativa `log_connections`/`log_disconnections`/`log_statement=mod`; comprobaciones con `has_table_privilege`/`has_column_privilege` (agregadas al detectar que `role_table_grants` **no lista MVs ni grants por columna** — corrección al criterio de verificación propuesto por la IA); `usuario_anon` determinista con equivalencia `EXCEPT=0` en ambos sentidos.
- **Descartado (con fundamento):** `GRANT ALL ON ALL TABLES` a `rol_app_escritura` (violaba mínimo privilegio y la baja lógica; reemplazado por permisos puntuales y por columna); la afirmación de **exfiltración de hashes** en la Parte C (**refutada contra el log**: `ERROR: permiso denegado a la tabla usuario` constaba antes de la `SENTENCIA` del SELECT; fue el caso más significativo de la cursada); la propuesta de **restaurar backup** como contención (innecesaria y riesgosa → se aplicó rotación de credencial).
- **Corrección de esta entrega (code review CR-03):** la IA detectó en `roles.sql` que `ALTER DEFAULT PRIVILEGES` otorgaba `DELETE` a `rol_app_escritura` en tablas futuras (contradecía la política R7); decisión humana: corregir script + aplicar `REVOKE` en la base (metadata-only, verificado `awd`→`aw`; evidencia `TPI2_entrega2_cierre/evidencias/cr03_default_privileges_20261110.txt`).
- **DUIA/bitácora de detalle:** `U5_admin_seguridad/BITACORA.md` + `docs/reconstruccion_ia.md`.

### Unidad 6 — Mantenimiento
- **Prompts:** diagnóstico read-only del proyecto; preparación de U6 sin modificar `food_store_tp3`, sin sobrescribir evidencias, sin operaciones destructivas y sin inventar resultados; alineación con las condiciones oficiales U6. Resumen en `TPI2_U6_mantenimiento/docs/DUIA_BITACORA_U6.md`.
- **Aceptado (tras revisión línea por línea):** los 6 scripts PowerShell 5.1 (`backup_foodstore.ps1` `pg_dump -Fc` con TOC/SHA256/meta, `verificar_backup.ps1`, `restore_foodstore.ps1` con guardas anti-original/anti-sistema, `mantenimiento_rutinario.ps1` con `ANALYZE` y `VACUUM FULL` bloqueado, `programar_backup.ps1`, `simulacro_desastre.ps1` + plantilla de informe post-incidente) y los 2 SQL de verificación.
- **Corregido con corrida real (F1–F5):** operador `??` inexistente en PS 5.1; `NativeCommandError` por stderr+EAP Stop; colisión de función con el alias `r` que producía un **falso "SUPERADAS"**; `$PSScriptRoot` vacío en defaults bajo `powershell.exe -File` (rompía la tarea programada, confirmado con repro mínimo); bug de un comando comparativo ad-hoc.
- **No ejecutado por decisión humana:** `VACUUM` (solo `ANALYZE`) por diseño; tarea diaria productiva dejada como comando documentado (`programar_backup.ps1 -At 02:30`) tras probarla de forma controlada; `.pgpass` eliminado al terminar la corrida.
- **DUIA/bitácora de detalle:** `TPI2_U6_mantenimiento/docs/DUIA_BITACORA_U6.md` + `evidencias/RESUMEN_CORRIDA_U6_20261109.md`.

### Unidad 7 — NoSQL (MongoDB)
- **Prompts:** modelado del subdominio pedidos como documento, migración de datos reales desde PostgreSQL, consultas (a)–(d) y equivalentes relacionales; comparación de motores pedida a la IA y **contrastada contra el esquema real**.
- **Aceptado:** modelo de agregado con `cliente` embebido y `lineas` como arreglo (patrón de acceso "pedido completo" sin `$lookup`); precios/cantidades **históricos inmutables** copiados de `detalle_pedido`; trazabilidad con `id_origen`; ejecución real sobre MongoDB 9.0.4 con evidencia.
- **Contraste IA:** afirmación 1 (lectura de agregados sin JOIN en documental) — **confirmada**; afirmación 2 (integridad referencial/de dominio superior en el relacional) — **confirmada** contra `schema.sql` (FK/CHECK/UNIQUE/ACID). Ninguna corrección de modelo fue necesaria (verificado con la comparación 5/5, 1/1 y 3 pedidos coincidentes).
- **DUIA de detalle:** uso de IA documentado dentro de `U7_nosql_mongodb/INFORME_U7.md` (no existe archivo DUIA separado en la unidad).

### Unidad 8 — Bases de datos móviles e integración
- **Specs/prompts:** spec Kiro `U8_tablet_cierre/docs/kiro/{requirements,design,tasks}.md` (EARS) redactada a partir de la consigna; generación de `schema_sqlite.sql`, `pruebas_sqlite.sql`, `semaforo.sql` y guiones de simulación; code review de la consigna 3.c.
- **Aceptado:** tablas `STRICT` con FK y CHECKs; **centavos enteros** para importes; cola de sincronización `cola_sync` con semáforo (PENDIENTE → RECHAZADO/CONFLICTO/SIMULADO_APROBADO) que no toca PostgreSQL.
- **Descartado (con fundamento y evidencia):** propuesta inicial de `precio REAL` en SQLite (riesgo de punto flotante → `precio_centavos INTEGER`, verificado con C7); recarga de caché por `DELETE` con FKs activas y por `ON CONFLICT DO UPDATE` directo (ambos fallaron y quedaron documentados → se adoptó `PRAGMA foreign_keys=OFF` fuera de transacción, preservando referencias).
- **DUIA/bitácora de detalle:** `U8_tablet_cierre/docs/DUIA.md` + `docs/bitacora_ia.md` (entrada 4: review 3.c).

## 3. Proceso de cierre de la 2ª entrega (esta carpeta)

- **Prompts/specs:** condiciones oficiales de la 2ª entrega pegadas textualmente → mapeo objetivo oficial → evidencia existente (diagnóstico de cobertura), detección de gaps y plan de cierre aprobado por el equipo; luego code review final, informe global, DUIA global y checklist.
- **Generado con IA:** `TPI2_entrega2_cierre/docs/CODE_REVIEW_FINAL_IA.md` (revisión línea por línea de los **41 scripts** de la cursada: Parcial, TP2–TP6, U5, U6, U7, U8), `INFORME_TECNICO_GLOBAL_ENTREGA2.md`, este documento y el checklist.
- **Verificación aplicada a cada hallazgo del review:** conteos contra la base real (`533.524` subtotales incoherentes), demostraciones en copia con `ROLLBACK` (trigger de stock INSERT-only: `cantidad=999999` con `stock=192`), catálogo (`pg_default_acl`, `pg_indexes`, `pg_trigger`, `to_regclass`) y análisis explícitamente marcado como teórico/latente cuando no era reproducible hoy (CR-05, CR-07, CR-08).
- **Decisiones humanas sobre los hallazgos (2026-11-10):**
  - **CR-01** (bug del seed de subtotales, `carga_masiva.sql:105`) y **CR-02** (trigger de stock solo en INSERT): **documentar + versionar el fix** sin recargar la base ni aplicar el trigger corregido, para preservar las evidencias de planes de ejecución medidos de TP3–TP6.
  - **CR-03** (DELETE en default privileges): **corregir script + base** (aplicado y verificado).
  - **CR-04** (índices redundantes por evolución): **mantener** en la base de la cursada (los planes medidos son evidencia); limpieza como acción de mantenimiento futuro.
  - **CR-05 a CR-08**: aceptados como notas de limitación/mejora futura documentadas.
  - **CR-09/CR-10**: ya cerrados en U6 (F1–F5) y en el review 3.c del TP8; referenciados.
- **Caso más significativo del cierre:** CR-01 le encontró **causa raíz en el script** (`random()` independiente para `subtotal`) al hallazgo de calidad de datos que U6 había detectado honestamente en el informe post-incidente, y explicó por qué la red de seguridad no lo vio (el `DISABLE TRIGGER ALL` del bulk insert).

## 4. Balance global de propuestas de IA (aceptadas / descartadas)

| Unidad / proceso | Propuestas aceptadas (verificadas) | Propuestas descartadas o corregidas (con fundamento) |
|---|---|---|
| U4 (TP6) | Descomposición FNBC; migración transaccional reversible; MV top-5 | — (todas las propuestas se validaron con corridas) |
| U5 | SECURITY DEFINER; auditoría nativa; `has_*_privilege`; anonimización determinista | `GRANT ALL` (mínimo privilegio); «exfiltración de hashes» (refutada contra el log); «restaurar backup» (innecesaria) |
| U6 | 6 scripts PS + 2 SQL (tras revisión); guardas de restore | 5 fallos F1–F5 detectados en corrida real y corregidos; `VACUUM` diferido por diseño |
| U7 | Modelo de agregado con precios históricos | — (2 afirmaciones contrastadas, ambas confirmadas) |
| U8 | STRICT/FK/centavos; semáforo | `precio REAL`; recarga por `DELETE` con FKs / `ON CONFLICT DO UPDATE` (fallaron con evidencia) |
| Cierre 2ª entrega | 8 hallazgos verificados; CR-03 corregido; CR-01/CR-02 fixes versionados | «recargar la base» ante CR-01/CR-02 (descartado: preservaría los datos pero destruiría las evidencias de planes medidos de la cursada) |

## 5. Protocolo obligatorio de IA sobre datos — cumplimiento

- [x] **Ningún script generado por IA se ejecutó sin ser leído línea por línea, comprendido y probado** sobre copia o transacción reversible, con respaldo previo cuando correspondió. Evidencia end-to-end: U6 (corrida P0–PF con baseline y `ORIGEN_SIN_CAMBIOS=TRUE`), U4 (Corrida A/B con `COMMIT` verificado y `ROLLBACK` demostrado sobre copia), U8 (C1–C7 con PostgreSQL sin cambios verificado), code review (verificaciones en copia/catálogo con `ROLLBACK`).
- [x] **No se enviaron a la IA datos personales ni sensibles de la base:** el log del simulacro U5 se **anonimizó antes** de compartirlo (`log_simulacro_anonimizado.txt`); los datos de prueba son sintéticos (`usuario_anon`, semillas del TP8); el `.pgpass` usado en U6 se eliminó al terminar; las verificaciones del review usan copias y valores de negocio no identificables.
- [x] **Todo uso de IA está declarado** (DUIA/bitácora por unidad + esta consolidación global) con herramienta, finalidad y prompts/specs, y con la decisión aceptar/descartar justificada en cada caso.
- [x] **Capacidad de defensa:** cada artefacto tiene su informe técnico y su evidencia de ejecución; las decisiones tomadas sobre cada hallazgo del code review están documentadas con fundamento verificable en `CODE_REVIEW_FINAL_IA.md`.

*El equipo asume la responsabilidad por el contenido entregado y puede explicarlo en la defensa oral.*
