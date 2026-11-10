<# 
.SYNOPSIS
  Simulacro de desastre U6: restaurar desde el ÚLTIMO respaldo verificado, contra reloj,
  sobre base NUEVA, con verificacion post-restore y generacion de informe post-incidente.
.DESCRIPTION
  - Selecciona el ultimo directorio/backup_verificado (debe tener .dump + .list.txt).
  - Crea/restaura a una base NUEVA (nunca food_store_tp3) usando restore_foodstore.ps1.
  - Mide tiempos con cronometro (inicio/fin/restauracion) para registrar "tiempo de restauracion".
  - Ejecuta sql/verificaciones_post_restore.sql sobre la restaurada y, opcionalmente,
    sobre el origen SOLO LECTURA para comparar.
  - Genera un informe post-incidente con datos medidos + secciones para observaciones humanas.
  NO ejecuta sobre la base original. NO inventa resultados.
.NOTES
  Requiere autorizacion explicita. Usar solo respaldo verificado (pasar por verificar_backup.ps1).
#>
[CmdletBinding()]
param(
  [string]$BackupRoot, # opcional; se resuelve en el cuerpo (PS5.1 -File: $PSScriptRoot vacio en defaults)
  [string]$RestoreDb   = $(if($env:RESTORE_DB){$env:RESTORE_DB}else{(("food_store_tp3_restore_sim_" + (Get-Date -Format "yyyyMMdd_HHmmss")))}),
  [string]$ProtectedDb = $(if($env:PROTECTED_DB){$env:PROTECTED_DB}else{("food_store_tp3")}),
  [string]$PgBin       = $(if($env:PG_BIN){$env:PG_BIN}else{("C:\Program Files\PostgreSQL\18\bin")}),
  [string]$PgHost      = $(if($env:PGHOST){$env:PGHOST}else{("127.0.0.1")}),
  [string]$PgPort      = $(if($env:PGPORT){$env:PGPORT}else{("5432")}),
  [string]$PgUser      = $(if($env:PGUSER){$env:PGUSER}else{("postgres")}),
  [string]$LogRoot,    # opcional; se resuelve en el cuerpo
  [switch]$CompareOrigin,  # capturar estado del origen en SOLO LECTURA para comparar
  [switch]$NoOwnerNoPrivileges
)
$ErrorActionPreference = "Continue" # PS5.1: stderr de herramientas nativas + EAP Stop causa NativeCommandError; errores criticos se controlan con throw y exit codes
# HALLAZGO PS5.1 (corregido): bajo powershell.exe -File, $PSScriptRoot esta VACIO al evaluar defaults
# de parametros en scripts avanzados ([CmdletBinding()]) y Join-Path fallaba con "cadena vacia" (exit 1).
# Se resuelven las rutas en el cuerpo, donde $PSScriptRoot siempre esta seteado.
if([string]::IsNullOrWhiteSpace($BackupRoot)){ if($env:BACKUP_ROOT){ $BackupRoot = $env:BACKUP_ROOT } else { $BackupRoot = Join-Path $PSScriptRoot "..\evidencias" } }
if([string]::IsNullOrWhiteSpace($LogRoot)){ if($env:LOG_ROOT){ $LogRoot = $env:LOG_ROOT } else { $LogRoot = Join-Path $PSScriptRoot "..\logs" } }
$psql = Join-Path $PgBin "psql.exe"
$restoreScript = Join-Path $PSScriptRoot "restore_foodstore.ps1"
$verifSql = Join-Path $PSScriptRoot "..\sql\verificaciones_post_restore.sql"
$plantillaInf = Join-Path $PSScriptRoot "..\docs\INFORME_POST_INCIDENTE_PLANTILLA.md"
foreach($t in @($psql,$restoreScript,$verifSql)){ if(!(Test-Path $t)){ throw "Falta: $t" } }

New-Item -ItemType Directory -Force -Path $BackupRoot,$LogRoot | Out-Null

# Seleccionar ultimo respaldo
$cands = Get-ChildItem -Path $BackupRoot -Directory -Filter "backup_*" | Sort-Object LastWriteTime -Descending
if($cands.Count -eq 0){ throw "No hay directorios backup_* en $BackupRoot. Ejecutar backup_foodstore.ps1 primero." }
$lastDir = $cands[0].FullName
$dump = Get-ChildItem -Path $lastDir -Filter "*.dump" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if(!$dump){ throw "No se encontro .dump en $lastDir" }
$dumpPath = $dump.FullName

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$runLog = Join-Path (Resolve-Path $LogRoot) "simulacro_desastre_${ts}.log"
$evidDir = Join-Path (Resolve-Path $BackupRoot) "simulacro_desastre_${ts}"
New-Item -ItemType Directory -Force -Path $evidDir | Out-Null

$swTotal = [System.Diagnostics.Stopwatch]::StartNew()
"== SIMULACRO DE DESASTRE U6 (contra reloj) inicio: $(Get-Date -Format o) ==" | Tee-Object -FilePath $runLog
"ultimo_backup_dir=$lastDir" | Tee-Object -FilePath $runLog -Append
"dump=$dumpPath" | Tee-Object -FilePath $runLog -Append
"restaurar_hacia (NUEVA)=$RestoreDb (protegida NO TOCAR=$ProtectedDb)" | Tee-Object -FilePath $runLog -Append

if($CompareOrigin){
  "capturando origen en SOLO LECTURA..." | Tee-Object -FilePath $runLog -Append
  & $psql -h $PgHost -p $PgPort -U $PgUser -d $ProtectedDb -f $verifSql > (Join-Path $evidDir "compare_origen_sim_$ts.txt") 2>&1 | Tee-Object -FilePath $runLog -Append
}

$swRest = [System.Diagnostics.Stopwatch]::StartNew()
$restoreArgs = @{ DumpPath=$dumpPath; RestoreDb=$RestoreDb; ProtectedDb=$ProtectedDb; PgBin=$PgBin; PgHost=$PgHost; PgPort=$PgPort; PgUser=$PgUser; LogRoot=$LogRoot; EvidRoot=$BackupRoot }
if($NoOwnerNoPrivileges){ $restoreArgs['NoOwnerNoPrivileges'] = $true }
& $restoreScript @restoreArgs
$rcRest = $LASTEXITCODE
$swRest.Stop()
$swTotal.Stop()

"restore_exit=$rcRest restauracion_tiempo_ms=$($swRest.ElapsedMilliseconds) restauracion_tiempo_s=$([math]::Round($swRest.Elapsed.TotalSeconds,3))" | Tee-Object -FilePath $runLog -Append
if($rcRest -ne 0){ Write-Warning "restore_foodstore.ps1 retorno exit $rcRest. Revisar log antes de concluir el simulacro." }

# Verificacion post-restore sobre base restaurada
$verifOut = Join-Path $evidDir "verif_post_restore_sim_$ts.txt"
& $psql -h $PgHost -p $PgPort -U $PgUser -d $RestoreDb -f $verifSql > $verifOut 2>&1
$rcVerif = $LASTEXITCODE
"verif_post_restore_exit=$rcVerif salida=$verifOut" | Tee-Object -FilePath $runLog -Append

# Generar informe post-incidente con datos medidos
$inf = Join-Path $evidDir "INFORME_POST_INCIDENTE_${ts}.md"
@(
  "# INFORME POST-INCIDENTE - Simulacro de desastre U6 (datos medidos)"
  ""
  "## Identificacion"
  "- Fecha/hora inicio simulacro: $(Get-Date -Format o)"
  "- Ultimo backup utilizado: $dumpPath (dir: $lastDir)"
  "- Base restaurada (NUEVA): $RestoreDb (NO se toco $ProtectedDb)"
  "- Host/puerto/usuario: $PgHost/$PgPort/$PgUser"
  ""
  "## Tiempos (contra reloj)"
  "- Tiempo total simulacro (ms/s): $($swTotal.ElapsedMilliseconds) ms / $([math]::Round($swTotal.Elapsed.TotalSeconds,3)) s"
  "- Tiempo de restauracion (pg_restore/flujo script) (ms/s): $($swRest.ElapsedMilliseconds) ms / $([math]::Round($swRest.Elapsed.TotalSeconds,3)) s"
  ""
  "## Resultados de ejecucion (medidos)"
  "- restore_foodstore.ps1 exit: $rcRest (ver log del restore)"
  "- verificacion post-restore exit: $rcVerif"
  "- Salidas: ver '$verifOut' y logs asociados"
  ""
  "## Verificaciones a completar (HUMANAS, sin inventar)"
  "- [ ] Conteos origen vs restaurada coinciden (tabla [2])"
  "- [ ] PK/FK/CHECK/UNIQUE/vistas/MV/funciones/triggers/indices coherentes"
  "- [ ] ENUM forma_pago_enum correcto"
  "- [ ] Chequeos integridad ([12]) devuelven 0 filas (o justificar desvios)"
  "- [ ] Origen $ProtectedDb sin modificaciones (verificar)"
  ""
  "## Lecciones/aprendizajes, contencion, acciones correctivas"
  "- Observaciones: [COMPLETAR]"
  "- Desvios detectados: [COMPLETAR / NINGUNO]"
  "- Acciones correctivas: [COMPLETAR]"
  ""
  "---"
  "Generado por simulacro_desastre.ps1. No se han inventado 'superado/fallado' automaticos: completar la seccion humana con evidencias."
) | Set-Content $inf

"== SIMULACRO FIN: $(Get-Date -Format o) == total_s=$([math]::Round($swTotal.Elapsed.TotalSeconds,3)) rest_s=$([math]::Round($swRest.Elapsed.TotalSeconds,3)) ==" | Tee-Object -FilePath $runLog -Append
Write-Host "Simulacro terminado. Restaurada: $RestoreDb | Tiempos en log/informe. Evidencias: $evidDir" -ForegroundColor Green
Write-Host "Completar la seccion humana del informe post-incidente con las comparaciones reales." -ForegroundColor Yellow
