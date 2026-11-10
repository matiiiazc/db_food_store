<#
.SYNOPSIS
  Registra una tarea programada (Windows Task Scheduler) para ejecutar el backup U6.
.DESCRIPTION
  Crea/actualiza una tarea que invoca backup_foodstore.ps1 con PowerShell. El respaldo
  es de SOLO LECTURA sobre la base origen (pg_dump). No modifica la base.
  Requiere autorizacion y un usuario con permisos para registrar tareas y acceder a PG
  (credenciales via entorno del usuario/servicio o .pgpass; NO hardcodear secretos).
.NOTES
  Ajustar -At (hora), -Days (frecuencia) y el usuario/principal segun la politica local.
  Para cuentas de servicio, configurar variables PG* en el entorno de la tarea o .pgpass.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
  [string]$TaskName = "FoodStore_U6_Backup_Diario",
  [string]$At = "02:30",                 # hora local
  [string]$PgBin = $(if($env:PG_BIN){$env:PG_BIN}else{("C:\Program Files\PostgreSQL\18\bin")}),
  [string]$SourceDb = $(if($env:PGDATABASE){$env:PGDATABASE}else{("food_store_tp3")}),
  [string]$PgHost = $(if($env:PGHOST){$env:PGHOST}else{("127.0.0.1")}),
  [string]$PgPort = $(if($env:PGPORT){$env:PGPORT}else{("5432")}),
  [string]$PgUser = $(if($env:PGUSER){$env:PGUSER}else{("postgres")}),
  [switch]$Once                          # ejecutar una vez (prueba) en vez de diario
)
$ErrorActionPreference = "Continue" # PS5.1: stderr de herramientas nativas + EAP Stop causa NativeCommandError; errores criticos se controlan con throw y exit codes
$backup = (Resolve-Path (Join-Path $PSScriptRoot "backup_foodstore.ps1")).Path
$arg = "-NoProfile -ExecutionPolicy Bypass -File `"$backup`" -PgBin `"$PgBin`" -SourceDb `"$SourceDb`" -PgHost `"$PgHost`" -PgPort `"$PgPort`" -PgUser `"$PgUser`" -NoOwnerNoPrivileges"
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $arg -WorkingDirectory (Split-Path $backup)
$trigger = if($Once){ New-ScheduledTaskTrigger -Once -At (Get-Date).Date.Add([TimeSpan]::Parse($At)) }
           else { New-ScheduledTaskTrigger -Daily -At $At }
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

if($PSCmdlet.ShouldProcess($TaskName, "Registrar tarea programada de backup ($SourceDb, lectura)")){
  Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null
  Write-Host "Tarea registrada: $TaskName (hora $At, $(if($Once){'una vez'}else{'diario'}))." -ForegroundColor Green
  Write-Host "IMPORTANTE: configurar autenticacion PG (PGPASSWORD/.pgpass) en el contexto de ejecucion de la tarea. Verificar con una corrida controlada." -ForegroundColor Yellow
}
