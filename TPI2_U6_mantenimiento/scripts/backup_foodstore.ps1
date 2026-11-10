<#
.SYNOPSIS
  Respaldo reproducible (solo lectura) de una base PostgreSQL Food Store.
.DESCRIPTION
  Genera un dump en formato personalizado (-Fc) con pg_dump. NO modifica la base origen.
  Por defecto toma como origen food_store_tp3 (lectura). Guarda el dump, un listado de
  contenido (toc) y un hash SHA256 en carpetas con marca de tiempo.
.NOTES
  Requiere: pg_dump, pg_restore (PostgreSQL 16+/18). Configurar conexion por variables de
  entorno: PGHOST, PGPORT, PGUSER, PGPASSWORD (o .pgpass). No hardcodear credenciales.
#>
[CmdletBinding()]
param(
  [string]$PgBin      = $(if($env:PG_BIN){$env:PG_BIN}else{("C:\Program Files\PostgreSQL\18\bin")}),
  [string]$SourceDb   = $(if($env:PGDATABASE){$env:PGDATABASE}else{("food_store_tp3")}),
  [string]$PgHost     = $(if($env:PGHOST){$env:PGHOST}else{("127.0.0.1")}),
  [string]$PgPort     = $(if($env:PGPORT){$env:PGPORT}else{("5432")}),
  [string]$PgUser     = $(if($env:PGUSER){$env:PGUSER}else{("postgres")}),
  [string]$OutRoot,   # opcional; se resuelve en el cuerpo (ver nota de compatibilidad PS5.1 -File)
  [string]$LogRoot,   # opcional; se resuelve en el cuerpo
  [switch]$NoOwnerNoPrivileges  # recomendado para restaurar en otro entorno/usuario
)
$ErrorActionPreference = "Continue" # PS5.1: stderr de herramientas nativas + EAP Stop causa NativeCommandError; errores criticos se controlan con throw y exit codes
# HALLAZGO PS5.1 (corregido): ejecutado con powershell.exe -File (tarea programada), $PSScriptRoot
# esta VACIO al evaluar defaults de parametros en scripts avanzados ([CmdletBinding()]) y
# Join-Path $PSScriptRoot fallaba con "cadena vacia" (exit 1). En el CUERPO siempre esta seteado.
if([string]::IsNullOrWhiteSpace($OutRoot)){ if($env:BACKUP_ROOT){ $OutRoot = $env:BACKUP_ROOT } else { $OutRoot = Join-Path $PSScriptRoot "..\evidencias" } }
if([string]::IsNullOrWhiteSpace($LogRoot)){ if($env:LOG_ROOT){ $LogRoot = $env:LOG_ROOT } else { $LogRoot = Join-Path $PSScriptRoot "..\logs" } }
$pgDump    = Join-Path $PgBin "pg_dump.exe"
$pgRestore = Join-Path $PgBin "pg_restore.exe"
foreach($t in @($pgDump,$pgRestore)){ if(!(Test-Path $t)){ throw "No se encontro herramienta: $t (ajustar -PgBin / PG_BIN)" } }
if([string]::IsNullOrWhiteSpace($env:PGPASSWORD)){ Write-Warning "PGPASSWORD no esta definida (se usara .pgpass o pedira password segun configuracion)." }

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$runDir = Join-Path (Resolve-Path (New-Item -ItemType Directory -Force -Path $OutRoot).FullName) "backup_${SourceDb}_$ts"
New-Item -ItemType Directory -Force -Path $runDir,$LogRoot | Out-Null
$dump = Join-Path $runDir "${SourceDb}_${ts}.dump"
$list = Join-Path $runDir "${SourceDb}_${ts}.list.txt"
$sha  = Join-Path $runDir "${SourceDb}_${ts}.sha256"
$meta = Join-Path $runDir "${SourceDb}_${ts}.meta.txt"
$log  = Join-Path (Resolve-Path $LogRoot) "backup_${SourceDb}_$ts.log"

$extra = @()
if($NoOwnerNoPrivileges){ $extra += @("--no-owner","--no-privileges") }

"== backup inicio: $(Get-Date -Format o) ==" | Tee-Object -FilePath $log
"origen=$SourceDb host=$PgHost port=$PgPort user=$PgUser formato=custom(-Fc) flags=$($extra -join ' ')" | Tee-Object -FilePath $log -Append

# Dump (operacion de LECTURA sobre la base origen; no ejecuta DDL/DML de modificacion)
& $pgDump -h $PgHost -p $PgPort -U $PgUser -d $SourceDb -Fc @extra -f $dump 2>&1 | Tee-Object -FilePath $log -Append
if($LASTEXITCODE -ne 0){ throw "pg_dump fallo (exit $LASTEXITCODE). Ver log: $log" }

# Verificacion de integridad basica del archivo de respaldo (no toca ninguna base)
if(!(Test-Path $dump) -or (Get-Item $dump).Length -le 0){ throw "Dump inexistente o vacio: $dump" }
& $pgRestore --list $dump > $list 2>> $log
if($LASTEXITCODE -ne 0){ throw "pg_restore --list fallo (dump posiblemente corrupto). Ver log: $log" }
(Get-FileHash -Algorithm SHA256 $dump | ForEach-Object { "$($_.Hash)  $(Split-Path $dump -Leaf)" }) | Set-Content $sha

@(
  "timestamp=$ts"
  "source_db=$SourceDb"
  "host=$PgHost"; "port=$PgPort"; "user=$PgUser"
  "pg_dump_version=$(& $pgDump --version)"
  "dump_file=$(Split-Path $dump -Leaf)"
  "dump_bytes=$((Get-Item $dump).Length)"
  "sha256_file=$(Split-Path $sha -Leaf)"
  "list_file=$(Split-Path $list -Leaf)"
  "nota=pg_dump es lectura del origen; no modifica $SourceDb. Pruebas de restore NO ejecutadas por este script."
) | Set-Content $meta

"== backup fin OK: $(Get-Date -Format o) ==" | Tee-Object -FilePath $log -Append
"Artefactos: $runDir" | Tee-Object -FilePath $log -Append
Write-Host "OK. Dump: $dump" -ForegroundColor Green
Write-Host "Siguiente (bajo autorizacion): verificar_backup.ps1 y restore a una base NUEVA (nunca $SourceDb)." -ForegroundColor Yellow
