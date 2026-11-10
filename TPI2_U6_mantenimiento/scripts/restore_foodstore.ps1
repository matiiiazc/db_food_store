<#
.SYNOPSIS
  Restaura un respaldo .dump en una base de datos NUEVA y separada (nunca la original).
.DESCRIPTION
  Crea la base destino (si no existe) y ejecuta pg_restore contra ella. Incluye guardas
  para impedir restaurar/modificar la base original protegida (por defecto food_store_tp3).
.NOTES
  NO usa ni modifica la base original. Requiere autorizacion explicita antes de ejecutar.
  Credenciales por variables de entorno (PGHOST/PGPORT/PGUSER/PGPASSWORD o .pgpass).
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$DumpPath,
  [string]$RestoreDb = $(if($env:RESTORE_DB){$env:RESTORE_DB}else{("food_store_tp3_restore")}),
  [string]$ProtectedDb = $(if($env:PROTECTED_DB){$env:PROTECTED_DB}else{("food_store_tp3")}),
  [string]$PgBin  = $(if($env:PG_BIN){$env:PG_BIN}else{("C:\Program Files\PostgreSQL\18\bin")}),
  [string]$PgHost = $(if($env:PGHOST){$env:PGHOST}else{("127.0.0.1")}),
  [string]$PgPort = $(if($env:PGPORT){$env:PGPORT}else{("5432")}),
  [string]$PgUser = $(if($env:PGUSER){$env:PGUSER}else{("postgres")}),
  [string]$MaintDb = "postgres",   # base de mantenimiento para CREATE DATABASE
  [string]$LogRoot,   # opcional; se resuelve en el cuerpo (PS5.1 -File: $PSScriptRoot vacio en defaults)
  [string]$EvidRoot,  # opcional; se resuelve en el cuerpo
  [switch]$NoOwnerNoPrivileges
)
$ErrorActionPreference = "Continue" # PS5.1: stderr de herramientas nativas + EAP Stop causa NativeCommandError; errores criticos se controlan con throw y exit codes
# HALLAZGO PS5.1 (corregido): bajo powershell.exe -File, $PSScriptRoot esta VACIO al evaluar defaults
# de parametros en scripts avanzados ([CmdletBinding()]) y Join-Path fallaba con "cadena vacia" (exit 1).
# Se resuelven las rutas en el cuerpo, donde $PSScriptRoot siempre esta seteado.
if([string]::IsNullOrWhiteSpace($LogRoot)){ if($env:LOG_ROOT){ $LogRoot = $env:LOG_ROOT } else { $LogRoot = Join-Path $PSScriptRoot "..\logs" } }
if([string]::IsNullOrWhiteSpace($EvidRoot)){ if($env:BACKUP_ROOT){ $EvidRoot = $env:BACKUP_ROOT } else { $EvidRoot = Join-Path $PSScriptRoot "..\evidencias" } }
$pgRestore = Join-Path $PgBin "pg_restore.exe"
$psql      = Join-Path $PgBin "psql.exe"
foreach($t in @($pgRestore,$psql)){ if(!(Test-Path $t)){ throw "No se encontro: $t" } }
if(!(Test-Path $DumpPath)){ throw "No existe el dump: $DumpPath" }
$dump = (Resolve-Path $DumpPath).Path

# Guardas de seguridad: NUNCA tocar la base original protegida
if($RestoreDb -ieq $ProtectedDb){ throw "BLOQUEADO: RestoreDb ('$RestoreDb') es la base original protegida. Usar una base NUEVA y separada (ej. ${ProtectedDb}_restore)." }
if($RestoreDb -ieq "postgres" -or $RestoreDb -ieq "template0" -or $RestoreDb -ieq "template1"){ throw "BLOQUEADO: RestoreDb no puede ser una base del sistema." }

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
New-Item -ItemType Directory -Force -Path $LogRoot,$EvidRoot | Out-Null
$log = Join-Path (Resolve-Path $LogRoot) "restore_${RestoreDb}_$ts.log"
$evi = Join-Path (Resolve-Path $EvidRoot) "restore_${RestoreDb}_$ts.txt"
"== restore inicio: $(Get-Date -Format o) ==" | Tee-Object -FilePath $log
"dump=$dump destino=$RestoreDb (protegida/NO TOCAR: $ProtectedDb) host=$PgHost port=$PgPort user=$PgUser" | Tee-Object -FilePath $log -Append
if([string]::IsNullOrWhiteSpace($env:PGPASSWORD)){ Write-Warning "PGPASSWORD no definida." }

# Crear base destino si no existe (contra la base de mantenimiento, NO contra la original)
$exists = & $psql -h $PgHost -p $PgPort -U $PgUser -d $MaintDb -tAc "SELECT 1 FROM pg_database WHERE datname='$RestoreDb';" 2>&1
if($LASTEXITCODE -ne 0){ throw "No se pudo consultar pg_database (exit $LASTEXITCODE): $exists" }
if(($exists | Out-String).Trim() -ne '1'){
  "Creando base destino '$RestoreDb'..." | Tee-Object -FilePath $log -Append
  & $psql -h $PgHost -p $PgPort -U $PgUser -d $MaintDb -v ON_ERROR_STOP=1 -c "CREATE DATABASE `"$RestoreDb`";" 2>&1 | Tee-Object -FilePath $log -Append
  if($LASTEXITCODE -ne 0){ throw "Fallo CREATE DATABASE $RestoreDb (exit $LASTEXITCODE)." }
} else {
  "La base destino '$RestoreDb' ya existe: se restaurara sobre ella. (Si se requiere limpieza, usar una base nueva o una recreacion controlada FUERA de la original)." | Tee-Object -FilePath $log -Append
}

$extra = @()
if($NoOwnerNoPrivileges){ $extra += @("--no-owner","--no-privileges") }
& $pgRestore -h $PgHost -p $PgPort -U $PgUser -d $RestoreDb @extra $dump 2>&1 | Tee-Object -FilePath $log -Append
$rc = $LASTEXITCODE
"pg_restore exit=$rc" | Tee-Object -FilePath $log -Append
if($rc -ne 0){ Write-Warning "pg_restore retorno exit $rc (puede haber warnings no fatales, p.ej. objetos existentes o comentarios de rol con --no-owner). Revisar el log antes de dar por valida la restauracion." }

@(
  "== evidencia restore =="
  "timestamp=$ts"; "dump=$dump"; "restore_db=$RestoreDb"; "protected_db_no_tocada=$ProtectedDb"
  "pg_restore_exit=$rc"
  "NOTA: no se afirman pruebas superadas automaticamente. Ejecutar sql/verificaciones_post_restore.sql sobre $RestoreDb y comparar con el origen (ver procedimiento tecnico)."
) | Tee-Object -FilePath $evi
"== restore fin: $(Get-Date -Format o) ==" | Tee-Object -FilePath $log -Append
Write-Host "Restore ejecutado hacia '$RestoreDb' (la original '$ProtectedDb' NO fue usada como destino). Revisar: $log" -ForegroundColor Yellow
Write-Host "Siguiente: correr verificaciones post-restore sobre $RestoreDb y compararlas con el origen (solo lectura)." -ForegroundColor Yellow
