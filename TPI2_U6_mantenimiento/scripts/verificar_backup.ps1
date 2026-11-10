<#
.SYNOPSIS
  Verificaciones de integridad de un respaldo .dump (sin modificar ninguna base).
.DESCRIPTION
  Comprueba existencia/tamaño, hash SHA256 (si hay sidecar) y legibilidad del TOC con
  pg_restore --list. No se conecta para escribir en ninguna base de datos.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$DumpPath,
  [string]$PgBin = $(if($env:PG_BIN){$env:PG_BIN}else{("C:\Program Files\PostgreSQL\18\bin")})
)
$ErrorActionPreference = "Continue" # PS5.1: stderr de herramientas nativas + EAP Stop causa NativeCommandError; errores criticos se controlan con throw y exit codes
$pgRestore = Join-Path $PgBin "pg_restore.exe"
if(!(Test-Path $pgRestore)){ throw "No se encontro pg_restore: $pgRestore" }
if(!(Test-Path $DumpPath)){ throw "No existe el dump: $DumpPath" }

$dump = (Resolve-Path $DumpPath).Path
$ok = $true
# NOTA (hallazgo real de ejecucion PS5.1): una funcion llamada "R" colisiona con el
# alias built-in "r" (Invoke-History), que tiene PRECEDENCIA sobre las funciones:
# los chequeos no se ejecutaban y el resultado era un falso "SUPERADAS". Se renombro
# a un nombre con guion (Invoke-Check), que nunca colisiona con alias.
function Invoke-Check($label,$pass,$detail){ $script:ok = $script:ok -and $pass; $mark = if($pass){"OK"}else{"FALLO"}; Write-Host "[$mark] $label - $detail" }

Invoke-Check "Archivo existe y no vacio" ((Get-Item $dump).Length -gt 0) ("bytes=" + (Get-Item $dump).Length)

$sidecar = [IO.Path]::ChangeExtension($dump, $null).TrimEnd('.') + ".sha256"
# tolerar el patron <base>.sha256 generado por nuestro backup
if(!(Test-Path $sidecar)){ $sidecar = ($dump -replace '\.dump$','.sha256') }
if(Test-Path $sidecar){
  $expected = (Get-Content $sidecar | Select-Object -First 1).Split(' ')[0].Trim().ToLower()
  $actual = (Get-FileHash -Algorithm SHA256 $dump).Hash.ToLower()
  Invoke-Check "Hash SHA256 coincide con sidecar" ($expected -eq $actual) $(if($expected -eq $actual){"coincide"}else{"esperado=$expected actual=$actual"})
} else {
  Write-Warning "[SKIP] Hash SHA256: no hay sidecar .sha256 junto al dump (generarlo en el backup o con Get-FileHash)."
}

$tmp = [IO.Path]::GetTempFileName()
try {
  & $pgRestore --list $dump > $tmp 2>&1
  $rc = $LASTEXITCODE
  $lines = (Get-Content $tmp | Measure-Object -Line).Lines
  Invoke-Check "pg_restore --list (TOC legible)" ($rc -eq 0 -and $lines -gt 0) "exit=$rc lineas_toc=$lines"
} finally { Remove-Item $tmp -ErrorAction SilentlyContinue }

if($ok){ Write-Host "RESULTADO: verificaciones de integridad del respaldo SUPERADAS (sin acceso de escritura a BD)." -ForegroundColor Green }
else { Write-Host "RESULTADO: verificaciones con FALLOS. No usar este dump para restore." -ForegroundColor Red; exit 1 }
