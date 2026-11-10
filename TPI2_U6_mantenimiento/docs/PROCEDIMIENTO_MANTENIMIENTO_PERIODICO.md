# U6 — Procedimiento de mantenimiento periódico (Food Store)

> Documento de **procedimiento**. No afirma tareas ejecutadas ni resultados obtenidos. Toda acción sobre el entorno real requiere autorización y debe respetar la protección de `food_store_tp3` (no modificar la base original; restauraciones solo a bases nuevas y separadas).

## 1. Objetivo
Garantizar continuidad operativa y recuperabilidad del sistema Food Store mediante respaldos periódicos verificables, pruebas de restauración controladas y revisiones básicas de salud, con trazabilidad en `logs/` y `evidencias/`.

## 2. Alcance
- **Motor:** PostgreSQL 16+/18, base de trabajo `food_store_tp3` (origen, **solo lectura** para respaldo).
- **Artefactos U6:** `TPI2_U6_mantenimiento/{scripts,sql,docs,evidencias,logs}`.
- **Fuera de alcance de este documento:** cambios de esquema/datos de negocio, tuning de producción no autorizado, acceso/modificación de tablets/SQLite o de MongoDB (cubiertos en U7/U8).

## 3. Frecuencia y tipo de respaldo (recomendada)
| Tipo | Frecuencia sugerida | Herramienta / método | Objetivo RPO orientativo | Nota |
|---|---:|---|---|---|
| Lógico completo | diario (fuera de pico) + antes de cambios relevantes | `scripts/backup_foodstore.ps1` → `pg_dump -Fc` | hasta 24 h (entre backups) | Reproducible, portable entre versiones compatibles; ver §5. |
| Verificación de integridad | cada backup | `scripts/verificar_backup.ps1` (`--list` + SHA256) | n/a (control de calidad) | Detecta corrupción del archivo. |
| Prueba de restauración | semanal o por hito (y tras cambios mayores) | `scripts/restore_foodstore.ps1` a base nueva + `sql/verificaciones_post_restore.sql` | validar RTO/procedimiento | **Nunca** sobre `food_store_tp3`. |
| Continuidad avanzada (PITR/WAL) | continuo (archiving) + base backup | `pg_basebackup` + archivado WAL (config. del servidor) | minutos (según WAL) | Requiere acceso/config de servidor; no implementado por los scripts lógicos de U6. Documentar si se habilita. |

> Los valores de RPO/RTO son **orientativos** y deben ajustarse a la criticidad acordada con la cátedra/operación.

## 4. Roles y responsabilidades (mínimo privilegio)
- **Operador de backup:** permiso de lectura sobre la base origen (rol de backup). No requiere permisos de escritura de negocio.
- **Operador de restore (entorno controlado):** permiso para `CREATE DATABASE`/restore en instancia de prueba; **sin** capacidad de restaurar sobre la base protegida de producción/origen.
- **Revisor:** compara evidencias (conteos/objetos/logs) y registra conformidad o desvíos.
- Credenciales gestionadas por variables de entorno/`.pgpass`; **nunca** en el repositorio.

## 5. Procedimiento periódico
1. **Ejecutar backup lógico** (paso 1 del procedimiento técnico) con marca de tiempo. Conservar `dump + .list.txt + .sha256 + .meta.txt + log`.
2. **Verificar integridad del archivo** (paso 2): TOC legible y hash coincidente. Si falla, repetir backup y **no** rotar/eliminar el último respaldo válido.
3. **Retención y rotación (sugerida):** conservar, por ejemplo, 7 diarios + 4 semanales + 3 mensuales (ajustar a espacio/política). Rotar moviendo/archivando; no sobrescribir nombres (ya son fechados). Mantener al menos un respaldo verificado fuera del mismo disco/host cuando sea posible.
4. **Prueba de restauración periódica (paso 3+4, con autorización):** restaurar el respaldo más reciente a una base **nueva** (`food_store_tp3_restore_YYYYMMDD` o nombre único), ejecutar `sql/verificaciones_post_restore.sql` en restaurada y en origen (**solo lectura**), comparar conteos/objetos/consistencia y registrar resultado en `evidencias/`.
5. **Revisión de logs:** ante `pg_dump/pg_restore` exit distinto de 0 o warnings relevantes, abrir el `logs/*.log`, documentar la causa y la acción tomada. No dar por válido un restore sin la comparación del paso 4.
6. **Limpieza controlada de bases de prueba:** eliminar **solo** las bases de restauración de prueba (nombres fechados), nunca `food_store_tp3` ni bases de sistema. Ejemplo (solo bajo autorización, sobre una base creada para prueba): `DROP DATABASE <restore_db_prueba>;` ejecutado contra `postgres`.

## 6. Comportamiento ante restauración desfasada (tablets/offline, alineado a U8)
Si se restaurara el servidor a un punto anterior (escenario de recuperación), las tablets pueden traer operaciones capturadas **después** de ese punto. Política coherente con U8 (semáforo):
- Las operaciones **no se aplican automáticamente** al servidor restaurado.
- Se revalidan contra el estado restaurado: precio/stock/existencia vuelven a evaluarse; resultados posibles `RECHAZADO`/`CONFLICTO` o re-procesamiento controlado; `SIMULADO_APROBADO` **no es venta** ni modifica el servidor.
- Decisión operativa (reprocesar, marcar conflictivo, descartar) debe quedar registrada con evidencia. Esta validación es funcional del flujo U8; U6 garantiza la recuperabilidad del servidor.

## 7. Registro de evidencias
Para cada ejecución periódica conservar en `evidencias/` y `logs/`:
- identificador/fecha-hora, tipo de tarea (backup/verificación/restore de prueba), operador,
- base origen (lectura) y base destino (si aplica, ≠ origen),
- rutas de artefactos (`.dump`, `.sha256`, `.list.txt`, salidas `.txt`), exit codes y observaciones,
- conclusión: conforme / con desvíos (detalle).

## 8. Revisión y mejora
- Revisar el procedimiento tras cambios de versión de PostgreSQL, cambios de esquema relevantes o incidentes.
- Verificar periódicamente que el espacio de `evidencias/`/destino de backups soporte la retención.
- Si se implementa PITR/WAL, anexar la configuración efectiva y una prueba de recuperación a un punto en el tiempo (en base nueva), con evidencia fechada.