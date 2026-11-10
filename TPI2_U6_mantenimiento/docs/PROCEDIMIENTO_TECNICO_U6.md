# U6 — Procedimiento técnico: respaldo y restauración (Food Store, PostgreSQL)

> **Estado:** preparación de scripts y documentación. **No se han ejecutado pruebas** de backup/restore como parte de esta entrega de archivos; no se afirman resultados. Toda ejecución requiere **autorización explícita** y debe realizarse **sin modificar la base original `food_store_tp3`**.

## 1. Alcance y garantías de seguridad
- **Origen protegido (solo lectura para dump):** `food_store_tp3`. Los scripts de U6 **no** ejecutan DDL/DML de modificación sobre la base origen. `pg_dump` realiza una lectura consistente para exportar.
- **Destino de restauración:** **siempre una base nueva y separada** (p. ej. `food_store_tp3_restore`). El script `restore_foodstore.ps1` **bloquea** explícitamente: (a) usar `food_store_tp3` como destino, (b) bases de sistema (`postgres`, `template0`, `template1`).
- **Sin sobrescritura de trabajos previos:** todo el material de U6 vive en `TPI2_U6_mantenimiento/` (scripts, sql, docs, evidencias, logs). No se reemplazan evidencias anteriores.
- **Sin operaciones destructivas sobre el origen:** no se ejecutan `DROP/ALTER/TRUNCATE/DELETE/UPDATE` contra `food_store_tp3`. La creación de la base destino se hace contra la base de mantenimiento `postgres`, nunca contra la original.

## 2. Requisitos y herramientas disponibles
| Herramienta | Ruta (instalación detectada) | Versión detectada (solo informativo) |
|---|---|---|
| `pg_dump` | `C:\Program Files\PostgreSQL\18\bin\pg_dump.exe` | PostgreSQL 18.4 |
| `pg_restore` | `C:\Program Files\PostgreSQL\18\bin\pg_restore.exe` | PostgreSQL 18.4 |
| `psql` | `C:\Program Files\PostgreSQL\18\bin\psql.exe` | PostgreSQL 18.4 |

- Motor objetivo del proyecto: PostgreSQL 16+ (base de trabajo `food_store_tp3`, según `AGENTS.md`).
- Formato de respaldo elegido: **custom** (`-Fc`, archivo `.dump`), porque es comprimido, permite `pg_restore --list` (verificación de TOC) y restauración selectiva/ordenada por `pg_restore`.

## 3. Conexión (sin credenciales hardcodeadas)
Configurar por **variables de entorno** (o `.pgpass` de PostgreSQL). Los scripts leen:

| Variable | Propósito | Ejemplo / default |
|---|---|---|
| `PGHOST` | host | `127.0.0.1` |
| `PGPORT` | puerto | `5432` |
| `PGUSER` | usuario con permisos de lectura (dump) y de creación/restauración en la instancia (restore, según política local) | `postgres` |
| `PGPASSWORD` | contraseña (o usar `.pgpass`) | *(no versionar)* |
| `PGDATABASE` | origen por defecto del backup | `food_store_tp3` |
| `PG_BIN` | carpeta `bin` de PostgreSQL | `C:\Program Files\PostgreSQL\18\bin` |
| `BACKUP_ROOT` | raíz de evidencias/artefactos | `TPI2_U6_mantenimiento/evidencias` |
| `LOG_ROOT` | raíz de logs | `TPI2_U6_mantenimiento/logs` |
| `RESTORE_DB` | base destino (debe ser nueva, ≠ origen) | `food_store_tp3_restore` |
| `PROTECTED_DB` | base protegida que no puede ser destino | `food_store_tp3` |

> **No** incluir contraseñas en scripts ni en el repositorio. Preferir `.pgpass` (`%APPDATA%\postgresql\pgpass.conf` en Windows) con permisos restringidos.

## 4. Estructura de carpetas (U6)
```
TPI2_U6_mantenimiento/
  scripts/
    backup_foodstore.ps1        # genera dump -Fc (lectura origen) + TOC + SHA256 + meta + log
    verificar_backup.ps1        # integridad del .dump sin tocar ninguna BD
    restore_foodstore.ps1       # crea DB destino nueva y restaura (bloquea la original)
  sql/
    verificaciones_post_restore.sql  # consultas SOLO LECTURA (conteos, objetos, FK/CHECK, muestreo)
  docs/
    PROCEDIMIENTO_TECNICO_U6.md
    PROCEDIMIENTO_MANTENIMIENTO_PERIODICO.md
  evidencias/   # artefactos por corrida (dump, .list.txt, .sha256, .meta.txt, salida de verificaciones)
  logs/         # logs de backup/restore/verificacion
```
Convención: cada corrida crea una subcarpeta/archivos con marca de tiempo `yyyyMMdd_HHmmss` para no sobrescribir evidencias previas.

## 5. Comandos a ejecutar (en orden) y qué verificar

> Ejecutar desde PowerShell. **No ejecutar** hasta contar con autorización. Reemplazar valores entre `<...>` si se usan parámetros explícitos.

### Paso 0 — Preparación (verificación previa, sin tocar datos)
```powershell
# (opcional) definir entorno de conexion - NO poner secretos en historial compartido
$env:PGHOST="127.0.0.1"; $env:PGPORT="5432"; $env:PGUSER="postgres"
# $env:PGPASSWORD="..."  # o usar .pgpass

# comprobar herramientas
& "C:\Program Files\PostgreSQL\18\bin\pg_dump.exe" --version
& "C:\Program Files\PostgreSQL\18\bin\pg_restore.exe" --version
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" --version
```
**Qué verificar:**
- Las tres herramientas responden con versión (coherente con el clúster, idealmente misma major).
- `PGHOST/PGPORT/PGUSER` apuntan a la instancia correcta. **No** se realizarán escrituras sobre `food_store_tp3`.

### Paso 1 — Respaldo (lectura del origen `food_store_tp3`)
```powershell
cd "C:\Users\PC\Desktop\Uni\Bases de datos II\food_store\TPI2_U6_mantenimiento"
.\scripts\backup_foodstore.ps1 -SourceDb food_store_tp3 -PgUser postgres -PgHost 127.0.0.1 -PgPort 5432 -NoOwnerNoPrivileges
# (opcional, para registrar huella del origen en el momento del backup, SOLO LECTURA)
# & "C:\Program Files\PostgreSQL\18\bin\psql.exe" -h 127.0.0.1 -p 5432 -U postgres -d food_store_tp3 -f .\sql\verificaciones_post_restore.sql > .\evidencias\compare_origen_<TS>.txt
```
**Qué verificar (éxito esperado, a confirmar al ejecutar):**
- El script termina indicando `OK` y crea en `evidencias/backup_food_store_tp3_<TS>/`: `<db>_<TS>.dump`, `<db>_<TS>.list.txt` (TOC), `<db>_<TS>.sha256`, `<db>_<TS>.meta.txt`; y un log en `logs/backup_...log`.
- `dump_bytes > 0`. El log no muestra `pg_dump fallo`.
- **No se modificó** `food_store_tp3` (el dump es lectura). Si se generó `compare_origen_<TS>.txt`, conservarlo para la comparación del paso 4.

### Paso 2 — Verificación de integridad del respaldo (sin tocar BD)
```powershell
# reemplazar <DUMP> por la ruta real generada en el paso 1
.\scripts\verificar_backup.ps1 -DumpPath ".\evidencias\backup_food_store_tp3_<TS>\food_store_tp3_<TS>.dump"
```
**Qué verificar:**
- `[OK] Archivo existe y no vacio` (bytes > 0).
- `[OK] Hash SHA256 coincide con sidecar` (si existe `.sha256`): el hash del archivo coincide con el registrado en el backup → integridad del archivo.
- `[OK] pg_restore --list (TOC legible)` con `exit=0` y `lineas_toc > 0` → el contenedor del dump es legible (no prueba aún la restauración lógica completa; eso se valida en el paso 3+4).
- Resultado final: `SUPERADAS`. Si hay fallos, **no** usar el dump para restaurar.

### Paso 3 — Restauración en base **nueva y separada** (requiere autorización)
```powershell
# DESTINO NUEVO (nunca food_store_tp3). El script bloquea el origen protegido.
.\scripts\restore_foodstore.ps1 `
  -DumpPath ".\evidencias\backup_food_store_tp3_<TS>\food_store_tp3_<TS>.dump" `
  -RestoreDb "food_store_tp3_restore" `
  -ProtectedDb "food_store_tp3" `
  -NoOwnerNoPrivileges
```
**Qué verificar:**
- El script se niega a ejecutarse si `RestoreDb` es la base protegida o una base de sistema (guarda).
- Crea `food_store_tp3_restore` (si no existía) **vía la base `postgres`** y restaura sobre ella (nunca sobre `food_store_tp3`).
- Revisar `logs/restore_food_store_tp3_restore_<TS>.log`: `pg_restore exit=...`. Un exit `0` es el caso ideal; `pg_restore` puede emitir *warnings* no fatales (p. ej. comentarios de rol con `--no-owner`). **No asumir éxito solo por el exit**: validar con el paso 4.
- Existe `evidencias/restore_food_store_tp3_restore_<TS>.txt`. Confirmar que **`food_store_tp3` no fue usada como destino**.

### Paso 4 — Verificaciones post-restore y comparación con el origen (**solo lectura**)
```powershell
$psql = "C:\Program Files\PostgreSQL\18\bin\psql.exe"
# 4a. Verificar la base RESTAURADA
& $psql -h 127.0.0.1 -p 5432 -U postgres -d food_store_tp3_restore -f .\sql\verificaciones_post_restore.sql `
  > .\evidencias\verif_post_restore_<TS>.txt 2> .\logs\verif_post_restore_<TS>.err.log

# 4b. (opcional, si no se hizo en paso 1) Capturar estado del ORIGEN en SOLO LECTURA para comparar
& $psql -h 127.0.0.1 -p 5432 -U postgres -d food_store_tp3 -f .\sql\verificaciones_post_restore.sql `
  > .\evidencias\compare_origen_<TS>.txt 2> .\logs\compare_origen_<TS>.err.log
```
**Qué verificar (comparar `verif_post_restore` vs `compare_origen`):**
- **[1] Contexto:** `base_actual` es `food_store_tp3_restore` en 4a y `food_store_tp3` en 4b.
- **[2]/[2b] Conteos:** filas por tabla clave (`categoria, cliente, producto, pedido, detalle_pedido`) y desgloses de baja lógica (`activo/eliminado`) **coinciden** entre origen y restaurada.
- **[3-9] Objetos:** tablas, PK/FK, CHECK/UNIQUE, vistas y vistas materializadas, funciones/procedimientos, triggers e índices presentes de forma coherente (dado que el modelo evolucionó por TPs, comparar inventarios; no asumir un subconjunto fijo).
- **[10] ENUM:** `forma_pago_enum` contiene los valores esperados (EFECTIVO, TARJETA, TRANSFERENCIA) según el dominio.
- **[11] Muestreo:** registros de ejemplo coherentes (inspección humana).
- **[12] Consistencia básica:** las consultas de incoherencia/orfandad devuelven **0 filas** (a confirmar con la ejecución real); cualquier diferencia respecto del origen debe analizarse.
- Registrar la conclusión (coincide / difiere, con detalle) en un archivo de evidencia fechado. **No afirmar “restauración exitosa” sin esta comparación y revisión del log.**

## 6. Evidencias a conservar
- `evidencias/backup_*/` → `.dump`, `.list.txt`, `.sha256`, `.meta.txt`.
- `evidencias/compare_origen_<TS>.txt` y `verif_post_restore_<TS>.txt`.
- `evidencias/restore_*_<TS>.txt` y `logs/restore_* / backup_* / verif_* .log`.
- Ninguna de estas rutas sobrescribe evidencia previa (usan timestamp).

## 7. Notas y limitaciones (declaradas)
- Los scripts **no** se han ejecutado en esta preparación: no hay resultados reales que reportar.
- `pg_dump -Fc` captura el estado lógico de la base; no implementa por sí solo PITR (Point-In-Time Recovery con WAL). La política de continuidad ampliada (WAL/PITR) se describe en el procedimiento de mantenimiento periódico.
- `verificaciones_post_restore.sql` asume columnas `pedido.eliminado` y `detalle_pedido.eliminado` (estado evolucionado del proyecto). Si el esquema objetivo difiriera, comentar esas consultas puntuales; el resto (conteos base, catálogo de objetos/FK/CHECK) sigue siendo válido.
- Restaurar sobre una base destino ya existente puede generar conflictos según el contenido previo; ante duda, usar un nombre de base destino **nuevo**. Cualquier recreación/limpieza de bases **nunca** debe apuntar a `food_store_tp3`.
