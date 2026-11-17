<#
.SYNOPSIS
  Procesa los resultados de ECOS con un clic (llama a tools/procesar_resultados.py).

.DESCRIPTION
  Haz clic derecho sobre este archivo > "Ejecutar con PowerShell", o ejecútalo desde PowerShell:
      powershell -ExecutionPolicy Bypass -File tools\procesar_resultados.ps1
  Funciona aunque estés en otra carpeta. Al terminar espera a que presiones Enter para que puedas leer el resultado.

.PARAMETER Prueba
  Usa los datos de prueba (NO reales) en vez de tus respuestas del formulario.
#>
param([switch]$Prueba)

$ErrorActionPreference = "Continue"
$raiz = Split-Path -Parent $PSScriptRoot
$script = Join-Path $PSScriptRoot "procesar_resultados.py"

# Busca un Python que funcione (el "python" de la Microsoft Store a veces no sirve)
$python = $null
foreach ($candidato in @("py", "python", "python3", "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe")) {
    try {
        $version = & $candidato --version 2>&1
        if ($LASTEXITCODE -eq 0 -and "$version" -match "Python 3") { $python = $candidato; break }
    } catch { }
}
if (-not $python) {
    Write-Host "No encontré Python 3. Instálalo desde https://www.python.org/downloads/ (marca 'Add Python to PATH') y vuelve a intentarlo." -ForegroundColor Red
    Read-Host "Presiona Enter para cerrar"
    exit 1
}

Set-Location $raiz
$argumentos = @($script)
if ($Prueba) { $argumentos += "--prueba" }
& $python @argumentos
$codigo = $LASTEXITCODE

Write-Host ""
if ($codigo -ne 0) { Write-Host "El proceso terminó con un aviso o un error (mira los mensajes de arriba)." -ForegroundColor Yellow }
Read-Host "Presiona Enter para cerrar"
exit $codigo
