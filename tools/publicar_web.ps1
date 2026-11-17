<#
.SYNOPSIS
  Exporta ECOS a la web y publica el resultado en la rama "web" (para Vercel).

.DESCRIPTION
  1. Exporta con Godot en modo release (preset "Web") a build/web/index.html.
  2. Crea build/web/vercel.json con las cabeceras de caché (sin COOP/COEP: el build no usa hilos).
  3. Publica el contenido de build/web en la rama "web" (rama huérfana, solo con los archivos exportados) usando
     un git worktree temporal: no toca tu rama actual ni tus cambios sin commit. Un commit por publicación
     ("Publicación <versión> <fecha>") y push de esa rama.
  4. Muestra el tamaño total y los pasos para el despliegue.

.PARAMETER Godot
  Ruta al ejecutable de Godot. Si no se pasa, usa la variable de entorno GODOT o la ruta habitual de este equipo.
.PARAMETER SoloExportar
  Exporta y prepara build/web, pero no publica en la rama "web".
.PARAMETER SinPush
  Hace el commit en la rama "web" pero no lo sube (git push).
.PARAMETER ConVercelJson
  Incluye también build/web/vercel.json (cabeceras de caché). Por defecto NO se incluye: si ya lo borraste de la rama "web"
  en GitHub, no se vuelve a añadir.
.PARAMETER ForzarPush
  Si el push normal es rechazado, permite un push forzado (--force-with-lease), pidiendo confirmación.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\publicar_web.ps1
#>
param(
    [string]$Godot = "",
    [switch]$SoloExportar,
    [switch]$SinPush,
    [switch]$ConVercelJson,
    [switch]$ForzarPush
)

$ErrorActionPreference = "Stop"
$raiz = Split-Path -Parent $PSScriptRoot
Set-Location $raiz

# --- Godot ---
if ($Godot -eq "") { $Godot = $env:GODOT }
if ($Godot -eq "" -or -not $Godot) {
    $Godot = "C:\Users\Usuario\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
}
if (-not (Test-Path $Godot)) { throw "No encuentro Godot en '$Godot'. Pásalo con -Godot RUTA o define la variable GODOT." }

# --- Versión (de project.godot) ---
$version = "0"
$linea = Select-String -Path (Join-Path $raiz "project.godot") -Pattern '^config/version="(.+)"' | Select-Object -First 1
if ($linea) { $version = $linea.Matches[0].Groups[1].Value }
$fecha = Get-Date -Format "yyyy-MM-dd HH:mm"

# --- 1. Exportar ---
$salida = Join-Path $raiz "build\web"
if (Test-Path $salida) { Remove-Item -Recurse -Force $salida }
New-Item -ItemType Directory -Force $salida | Out-Null
Write-Host "Exportando ECOS $version a build/web ..." -ForegroundColor Cyan
& $Godot --headless --path $raiz --export-release "Web" "build/web/index.html"
if ($LASTEXITCODE -ne 0) { throw "La exportación falló (código $LASTEXITCODE). ¿Están instaladas las plantillas de exportación de Godot 4.7.2 (Editor > Administrar plantillas de exportación)?" }
foreach ($archivo in @("index.html", "index.wasm", "index.pck", "index.js")) {
    if (-not (Test-Path (Join-Path $salida $archivo))) { throw "Falta $archivo en build/web: la exportación no terminó bien." }
}

# --- 2. vercel.json (cabeceras de caché; sin COOP ni COEP porque no hay hilos) ---
$vercel = @'
{
  "headers": [
    {
      "source": "/(.*)\.wasm",
      "headers": [{ "key": "Cache-Control", "value": "public, max-age=31536000, immutable" }]
    },
    {
      "source": "/(.*)\.pck",
      "headers": [{ "key": "Cache-Control", "value": "public, max-age=31536000, immutable" }]
    },
    {
      "source": "/(.*)\.png",
      "headers": [{ "key": "Cache-Control", "value": "public, max-age=31536000, immutable" }]
    },
    {
      "source": "/index.html",
      "headers": [{ "key": "Cache-Control", "value": "max-age=0, must-revalidate" }]
    },
    {
      "source": "/",
      "headers": [{ "key": "Cache-Control", "value": "max-age=0, must-revalidate" }]
    }
  ]
}
'@
if ($ConVercelJson) {
    [System.IO.File]::WriteAllText((Join-Path $salida "vercel.json"), $vercel, (New-Object System.Text.UTF8Encoding($false)))
}

# --- 3. Tamaños ---
Write-Host ""
Write-Host "Tamaño de los archivos:" -ForegroundColor Cyan
$total = 0
$demasiado = $false
Get-ChildItem $salida -File | Sort-Object Length -Descending | ForEach-Object {
    $mb = [math]::Round($_.Length / 1MB, 2)
    $total += $_.Length
    $marca = ""
    if ($_.Length -gt 80MB) { $marca = "  <-- SUPERA 80 MB"; $demasiado = $true }
    Write-Host ("  {0,-22} {1,8} MB{2}" -f $_.Name, $mb, $marca)
}
Write-Host ("  {0,-22} {1,8} MB" -f "TOTAL", [math]::Round($total / 1MB, 2)) -ForegroundColor Green
if ($demasiado) { Write-Warning "Algún archivo pasa de 80 MB (el límite gratuito de Vercel es 100 MB). Optimiza antes de publicar." }

if ($SoloExportar) {
    Write-Host "`nListo (solo exportar). Prueba local: cd build\web ; python -m http.server 8000 ; abre http://localhost:8000" -ForegroundColor Yellow
    return
}

# --- 4. Publicar en la rama "web" con un worktree temporal ---
$tmp = Join-Path $env:TEMP "ecos_web_worktree"
if (Test-Path $tmp) {
    git worktree remove --force $tmp 2>$null
    if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
}
git worktree prune

$existeLocal = [bool](git branch --list web)
$existeRemota = [bool](git ls-remote --heads origin web 2>$null)
if ($existeRemota) {
    # Se parte SIEMPRE de lo que hay en GitHub (por si alguien cambió la rama allí, por ejemplo borrando un archivo)
    git fetch origin web | Out-Null
    if ($existeLocal) { git branch -f web origin/web | Out-Null }
}
if ($existeLocal) {
    git worktree add $tmp web | Out-Null
} elseif ($existeRemota) {
    git fetch origin web | Out-Null
    git worktree add -b web $tmp origin/web | Out-Null
} else {
    # Primera publicación: rama huérfana (sin historia del juego)
    git worktree add --detach $tmp | Out-Null
    Push-Location $tmp
    git checkout --orphan web | Out-Null
    Pop-Location
}

try {
    Push-Location $tmp
    # Se vacía el contenido anterior y se copia el nuevo
    git rm -rf --quiet --ignore-unmatch . | Out-Null
    Get-ChildItem -Force -Exclude ".git" | Where-Object { $_.Name -ne ".git" } | Remove-Item -Recurse -Force
    Copy-Item -Path (Join-Path $salida "*") -Destination $tmp -Recurse -Force
    git -c core.autocrlf=false add -A
    git diff --cached --quiet
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`nNo hay cambios respecto a la última publicación: no se crea otro commit." -ForegroundColor Yellow
    } else {
        git commit --quiet -m "Publicación $version $fecha"
        Write-Host "`nCommit creado en la rama 'web': Publicación $version $fecha" -ForegroundColor Green
        if (-not $SinPush) {
            git push -u origin web
            if ($LASTEXITCODE -ne 0) {
                if ($ForzarPush) {
                    $r = Read-Host "El push normal fue rechazado. ¿Confirmas un push FORZADO (--force-with-lease) a la rama 'web'? (s/n)"
                    if ($r -eq "s") { git push --force-with-lease -u origin web }
                } else {
                    Write-Warning "El push fue rechazado. Si estás seguro, vuelve a ejecutar con -ForzarPush (pedirá confirmación)."
                }
            }
        }
    }
} finally {
    Pop-Location
    git worktree remove --force $tmp 2>$null
    git worktree prune
}

Write-Host ""
Write-Host ("Tamaño total publicado: {0} MB" -f [math]::Round($total / 1MB, 2)) -ForegroundColor Green
Write-Host @"

Siguientes pasos (detalle en docs/DESPLIEGUE_VERCEL.md):
  1. En Vercel: Add New > Project > importa el repositorio de GitHub.
  2. Framework Preset: Other. Build Command: vacío. Output Directory: .
  3. Settings > Git > Production Branch = web.
  4. Cada vez que publiques (este script), Vercel despliega solo la rama 'web'.
"@
