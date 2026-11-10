# RESUMEN DE CORRIDA U6 — Pruebas ejecutadas con cronometraje (evidencia real)

- **Fecha/hora:** 2026-11-09, 23:12–23:31 (ART) · Windows PowerShell 5.1 · PostgreSQL 18.4 (`127.0.0.1:5432`, usuario `postgres`, auth vía `.pgpass`).
- **Origen protegido:** `food_store_tp3` (213 MB; conteos: categoria=4, cliente=20000, producto=50000, pedido=200401, detalle_pedido=601205). **NO fue modificado** (verificado contra línea base 23:12:11 → `ORIGEN_SIN_CAMBIOS=TRUE`).
- Todas las operaciones de restore se hicieron hacia bases **nuevas y separadas**; la guarda bloqueó los intentos contra la original y bases de sistema.

| # | Prueba | Resultado | Tiempo | Evidencia |
|---|---|---|---|---|
| P0 | Conexión + versiones (`pg_dump/pg_restore/psql` 18.4) | OK | 0,31 s | salida de consola |
| P0b | Línea base del origen (solo lectura) | OK | 2,45 s | `evidencias/baseline_origen_20261109_231211.txt` |
| P1 | Backup `pg_dump -Fc` (lectura) | OK (exit 0; dump 14.485.062 B + TOC 114 líneas + SHA256 + meta) | **11,61 s** | `evidencias/backup_food_store_tp3_20261109_231219/`, `logs/backup_*_231219.log` |
| P2 | Verificación de integridad del dump | OK (3/3: tamaño, SHA256 coincide, TOC legible) | 0,72 s | salida de consola; re-verificado sobre el backup de tarea: OK 1,24 s |
| P3 | Restore a base nueva `food_store_tp3_restore_20261109_231444` | OK (`pg_restore` exit 0) | **20,06 s** | `evidencias/restore_*_231444.txt`, `logs/restore_*_231444.log` |
| P4 | Verificaciones post-restore + comparación origen↔restaurada | OK (**0 diferencias**: conteos + 13 tablas, 5 vistas, 2 MV, 44 funciones, 5 triggers, 29 índices) | 3,65 s + 0,89 s | `evidencias/verif_post_restore_20261109_231515.txt`, `compare_origen_20261109_231515.txt` |
| P5 | Mantenimiento rutinario (integridad + `ANALYZE`, sin VACUUM) sobre la restaurada | OK (FK/CHECK validadas; huérfanos=0; dominios=0) | **4,18 s** | `logs/mantenimiento_*_231756.log`, `evidencias/mantenimiento_*_231756.txt` |
| P6 | Respaldo programado (Task Scheduler, tarea `-Once` 23:27) | **Fallo primero → corregido → OK** (ver fallos) | registro 0,3 s + espera; corrida de tarea OK | tarea `FoodStore_U6_Backup_TestOnce` ejecutó backup real: `evidencias/backup_food_store_tp3_20261109_232703/` (dump idéntico: 14.485.062 B; `LastTaskResult=0`) |
| P7 | **Simulacro de desastre contra reloj** (último respaldo → base nueva `food_store_tp3_restore_sim_20261109_232906` + verificaciones + comparación origen) | OK (restore exit 0; verif exit 0; conteos 100% iguales) | **total 22,93 s · restauración 21,62 s** (medición externa: 24,63 s) | `evidencias/simulacro_desastre_20261109_232906/`, `logs/simulacro_desastre_20261109_232906.log` |
| P8 | Guardas/fallos: restore→original (bloquea), restore→`postgres` (bloquea), dump corrupto (FALLO exit 1), dump inexistente (excepción) | OK (4/4 comportamientos esperados) | 0,34 / 0,02 / 0,58 / 0,02 s | salida de consola (documentada abajo) |
| PF | Origen sin cambios (conteos finales vs baseline) | OK (`ORIGEN_SIN_CAMBIOS=TRUE`) | 1,35 s | salida de consola |

## Fallos reales encontrados durante la corrida (y su resolución)
| Fallo | Síntoma / causa raíz | Corrección | Re-prueba |
|---|---|---|---|
| F1 — PS 5.1 y operador `??` | Los 6 scripts usaban `??` (solo PowerShell 7) → error de parseo en PS 5.1 | Defaults reescritos con `$(if($env:X){...}else{...})` | Parseo 6/6 OK |
| F2 — `NativeCommandError` latente | Con `$ErrorActionPreference="Stop"` + stderr de herramientas nativas (`2>&1`), PS 5.1 aborta el script | Cambiado a `Continue` (errores críticos ya controlados con `throw`/exit codes) | Todas las corridas posteriores OK |
| F3 — Función `R` colisionaba con alias `r` (`Invoke-History`) | En `verificar_backup.ps1` los 3 chequeos no se ejecutaban y reportaba un **falso "SUPERADAS"** (exit 0) — hallazgo crítico de falsos positivos | Renombrada a `Invoke-Check` (nombre con guion no colisiona con alias) | P2 re-ejecutada: 3/3 OK reales (0,72 s) |
| F4 — `$PSScriptRoot` vacío en defaults bajo `powershell.exe -File` | La tarea programada (23:20) disparó pero falló (`LastTaskResult=1`, sin backup): en PS 5.1, scripts avanzados (`[CmdletBinding()]`) ejecutados con `-File` tienen `$PSScriptRoot` VACÍO al evaluar defaults → `Join-Path` falla con "cadena vacía". Confirmado con repro mínimo (vía `&` funciona; vía `-File` no) | Resolución de rutas (`$OutRoot/$LogRoot/$EvidRoot/$BackupRoot`) movida al CUERPO de los 4 scripts afectados | Repro exacto del comando de tarea: exit 0 (8,5 s); tarea re-registrada disparó a las 23:27 con `LastTaskResult=0` y generó backup completo |
| F5 — Error propio de un comando comparativo ad-hoc | Mi consulta de comparación P4 usaba `-like "tabla|"` sin comodín → array vacío → "System.Object[]" (no afectó a los scripts del proyecto ni a las evidencias generadas) | Re-hecha con `StartsWith` | Comparación 0 diferencias |

## Notas
- `VACUUM` no se ejecutó (solo `ANALYZE`), por diseño: requiere autorización explícita (`-RunVacuum`). `VACUUM FULL` bloqueado por seguridad.
- La tarea de prueba `-Once` fue **eliminada** tras verificar (`Unregister-ScheduledTask`). Para el respaldo diario productivo: `.\scripts\programar_backup.ps1 -TaskName FoodStore_U6_Backup_Diario -At 02:30` (documentado en `docs/`).
- Autenticación: `.pgpass` creado para la prueba (`%APPDATA%\postgresql\pgpass.conf`). Puede eliminarse; los scripts también aceptan `PGPASSWORD` de sesión.
- Bases de prueba quedaron en el cluster como evidencia (pueden eliminarse con autorización): `food_store_tp3_restore_20261109_231444`, `food_store_tp3_restore_sim_20261109_232906`. **La original `food_store_tp3` no fue tocada.**
- Tiempos de restauración medidos sobre disco local; incluyen creación de base + `pg_restore` completo con índices/constraints.
