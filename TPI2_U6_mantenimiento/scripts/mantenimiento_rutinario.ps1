<# 
.SYNOPSIS
  Tareas rutinarias de mantenimiento (estadisticas, verificacion de integridad) - U6.
.DESCRIPTION
  Ejecuta, sobre una base objetivo: (1) verificacion de integridad (solo lectura, SQL),
  (2) ANALYZE para actualizar estadisticas del planificador. Opcionalmente VACUUM (sin FULL)
  solo si se pasa -RunVacuum y con autorizacion explicita.
  Por defecto apunta a la base de trabajo; para pruebas usar una copia/restaurada.
  NO restaura ni modifica la base original como destino de operaciones destructivas.
.NOTES
  VACUUM (sin FULL) es una operacion de mantenimiento normal en PostgreSQL (no reescribe
  tablas de forma exclusiva como FULL). ANALYZE solo actualiza estadisticas. Requiere
  autorizacion y comprender el impacto antes de ejecutar en entornos compartidos.
#>
[CmdletBinding()]
param(
  [string]$TargetDb = $(if($env:PGDATABASE){$env:PGDATABASE}else{("food_store_tp3")}),
  [string]$PgBin  = $(if($env:PG_BIN){$env:PG_BIN}else{("C:\Program Files\PostgreSQL\18\bin")}),
  [string]$PgHost = $(if($env:PGHOST){$env:PGHOST}else{("127.0.0.1")}),
  [string]$PgPort = $(if($env:PGPORT){$env:PGPORT}else{("5432")}),
  [string]$PgUser = $(if($env:PGUSER){$env:PGUSER}else{("postgres")}),
  [string]$LogRoot,   # opcional; se resuelve en el cuerpo (PS5.1 -File: $PSScriptRoot vacio en defaults)
  [string]$EvidRoot,  # opcional; se resuelve en el cuerpo
  [switch]$RunVacuum,          # VACUUM (sin FULL) sobre tablas public; requiere autorizacion
  [switch]$VacuumFull          # PELIGROSO/bloqueante: NO recomendado; solo si se entiende el impacto
)
$ErrorActionPreference = "Continue" # PS5.1: stderr de herramientas nativas + EAP Stop causa NativeCommandError; errores criticos se controlan con throw y exit codes
# HALLAZGO PS5.1 (corregido): bajo powershell.exe -File, $PSScriptRoot esta VACIO al evaluar defaults
# de parametros en scripts avanzados ([CmdletBinding()]) y Join-Path fallaba con "cadena vacia" (exit 1).
# Se resuelven las rutas en el cuerpo, donde $PSScriptRoot siempre esta seteado.
if([string]::IsNullOrWhiteSpace($LogRoot)){ if($env:LOG_ROOT){ $LogRoot = $env:LOG_ROOT } else { $LogRoot = Join-Path $PSScriptRoot "..\logs" } }
if([string]::IsNullOrWhiteSpace($EvidRoot)){ if($env:BACKUP_ROOT){ $EvidRoot = $env:BACKUP_ROOT } else { $EvidRoot = Join-Path $PSScriptRoot "..\evidencias" } }
$psql = Join-Path $PgBin "psql.exe"
if(!(Test-Path $psql)){ throw "No se encontro psql: $psql" }
if($VacuumFull){ throw "VACUUM FULL bloqueado por seguridad en este script. Usar -RunVacuum (sin FULL) solo con autorizacion, o ejecutar manualmente bajo ventana controlada." }

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
New-Item -ItemType Directory -Force -Path $LogRoot,$EvidRoot | Out-Null
$log = Join-Path (Resolve-Path $LogRoot) "mantenimiento_${TargetDb}_$ts.log"
$evi = Join-Path (Resolve-Path $EvidRoot) "mantenimiento_${TargetDb}_$ts.txt"
$sqlInt = Join-Path $PSScriptRoot "..\sql\verificacion_integridad.sql"

"== mantenimiento rutinario inicio: $(Get-Date -Format o) ==" | Tee-Object -FilePath $log
"base=$TargetDb host=$PgHost port=$PgPort user=$PgUser vacuum=$RunVacuum" | Tee-Object -FilePath $log -Append

# (1) Verificacion de integridad (SOLO LECTURA)
"--- verificacion de integridad ---" | Tee-Object -FilePath $log -Append
& $psql -h $PgHost -p $PgPort -U $PgUser -d $TargetDb -v ON_ERROR_STOP=1 -f $sqlInt 2>&1 | Tee-Object -FilePath $log -Append
if($LASTEXITCODE -ne 0){ throw "Fallo verificacion_integridad (exit $LASTEXITCODE). Ver $log" }

# (2) Actualizacion de estadisticas (ANALYZE) - recomendado periodico
"--- ANALYZE (estadisticas) ---" | Tee-Object -FilePath $log -Append
& $psql -h $PgHost -p $PgPort -U $PgUser -d $TargetDb -v ON_ERROR_STOP=1 -c "ANALYZE;" 2>&1 | Tee-Object -FilePath $log -Append
if($LASTEXITCODE -ne 0){ throw "Fallo ANALYZE (exit $LASTEXITCODE). Ver $log" }

# (3) VACUUM opcional (sin FULL) - solo con autorizacion explicita
if($RunVacuum){
  "--- VACUUM (sin FULL) ---" | Tee-Object -FilePath $log -Append
  & $psql -h $PgHost -p $PgPort -U $PgUser -d $TargetDb -v ON_ERROR_STOP=1 -c "VACUUM (ANALYZE);" 2>&1 | Tee-Object -FilePath $log -Append
  if($LASTEXITCODE -ne 0){ throw "Fallo VACUUM (exit $LASTEXITCODE). Ver $log" }
}

@(
  "timestamp=$ts"; "base=$TargetDb"; "integridad=ejecutada(ver log)"; "analyze=ejecutado"; "vacuum=$RunVacuum"
  "NOTA: revisar el log/evidencia; no se afirman resultados correctos sin inspeccion humana."
) | Set-Content $evi
"== mantenimiento fin: $(Get-Date -Format o) ==" | Tee-Object -FilePath $log -Append
Write-Host "Listo. Log: $log | Evidencia: $evi" -ForegroundColor Green
