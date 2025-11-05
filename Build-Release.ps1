# WSL Memory Monitor - Script de empaquetado para distribución
# Crea un archivo ZIP listo para distribuir

param(
    [string]$Version = "2.1.0",
    [string]$OutputDir = ".\releases"
)

# Colores
function Write-ColorText($text, $color) {
    Write-Host $text -ForegroundColor $color
}

function Write-Section($title) {
    Write-Host "`n" -NoNewline
    Write-ColorText "═══════════════════════════════════════════════════════════" "Cyan"
    Write-ColorText "  $title" "Yellow"
    Write-ColorText "═══════════════════════════════════════════════════════════" "Cyan"
}

# Banner
Clear-Host
Write-Section "WSL Memory Monitor - Build Release v$Version"

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$releaseName = "WSL-Memory-Monitor-v$Version"
$releaseNameWithDate = "$releaseName-$timestamp"

# Crear directorio de salida
Write-Host "`nCreando directorio de salida..."
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}
$OutputDir = Resolve-Path $OutputDir

# Crear directorio temporal para el empaquetado
$tempDir = Join-Path $env:TEMP $releaseNameWithDate
if (Test-Path $tempDir) {
    Remove-Item $tempDir -Recurse -Force
}
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
Write-ColorText "✓ Directorio temporal: $tempDir" "Green"

# Lista de archivos a incluir
Write-Section "Copiando archivos"

$filesToInclude = @(
    # Scripts principales
    "WSL-Memory-Switch.ps1",
    "WSL-Memory-Monitor.ps1",
    "wsl-memory-switch-cli.sh",

    # Daemon dinámico
    "wsl-memory-daemon.sh",
    "wsl-memory-daemon.service",
    "install-daemon.sh",

    # Instaladores
    "Setup-WSLMemoryMonitor.ps1",
    "Install-AutoStart.ps1",
    "Make-Icon-Visible.ps1",

    # Launchers
    "RUN-MEMORY-SWITCH.bat",
    "START-MONITOR.bat",

    # Configuración
    "wsl-memory-profiles.conf",

    # Documentación
    "README.md",
    "LICENSE",
    "CONTRIBUTING.md"
)

$copiedCount = 0
foreach ($file in $filesToInclude) {
    $sourcePath = Join-Path $PSScriptRoot $file
    if (Test-Path $sourcePath) {
        Copy-Item $sourcePath -Destination $tempDir -Force
        Write-Host "  ✓ $file" -ForegroundColor Green
        $copiedCount++
    } else {
        Write-Host "  ⚠ $file (no encontrado, omitido)" -ForegroundColor Yellow
    }
}

Write-ColorText "`n✓ $copiedCount archivos copiados" "Green"

# Crear archivo de versión
Write-Section "Generando archivos de metadatos"

$versionInfo = @"
WSL Memory Monitor v$Version
Build Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Build ID: $timestamp

Features:
- Visual memory slider interface
- System tray monitor with color-coded icons
- Dynamic memory adjustment without WSL restart (NEW!)
- CLI interface for Linux
- Automated installer
- 5 pre-configured profiles

System Requirements:
- Windows 10 version 2004+ or Windows 11
- WSL2 (version 2.0.0+)
- Minimum 16GB RAM (32GB+ recommended)
- PowerShell 5.0+

For installation instructions, see README.md
"@

$versionInfo | Out-File -FilePath (Join-Path $tempDir "VERSION.txt") -Encoding UTF8
Write-ColorText "✓ VERSION.txt creado" "Green"

# Crear guía de inicio rápido
$quickStart = @"
═══════════════════════════════════════════════════════════════
    WSL MEMORY MONITOR v$Version - GUÍA DE INICIO RÁPIDO
═══════════════════════════════════════════════════════════════

INSTALACIÓN RÁPIDA:
═══════════════════════════════════════════════════════════════

1. Extrae este archivo ZIP a una ubicación permanente
   Ejemplo: C:\Tools\WSL-Memory-Monitor

2. Haz clic derecho en "Setup-WSLMemoryMonitor.ps1"
   → Ejecutar con PowerShell

3. Sigue las instrucciones del instalador

4. ¡Listo! El icono aparecerá en la bandeja del sistema


CARACTERÍSTICAS NUEVAS EN v$Version:
═══════════════════════════════════════════════════════════════

✨ CAMBIO DE MEMORIA DINÁMICO (SIN REINICIAR WSL)
   - El daemon permite ajustar memoria en tiempo real
   - No es necesario reiniciar WSL para cambios de memoria
   - Los cambios son instantáneos

   Para habilitar:
   1. Desde WSL, ejecuta: ./install-daemon.sh
   2. Usa el Memory Switch normalmente
   3. Selecciona "Aplicar dinámicamente" cuando se te pregunte


USO BÁSICO:
═══════════════════════════════════════════════════════════════

Desde Windows:
  • Haz clic en el icono de la bandeja del sistema
  • O ejecuta: RUN-MEMORY-SWITCH.bat

Desde WSL:
  • wsl-memory-switch apply balanced
  • wsl-memory-switch status


PERFILES DISPONIBLES:
═══════════════════════════════════════════════════════════════

Nivel 5 - GAMING       : 8GB WSL  | 56GB Windows (4 CPUs)
Nivel 4 - WIN-FOCUS    : 16GB WSL | 48GB Windows (8 CPUs)
Nivel 3 - BALANCED     : 24GB WSL | 40GB Windows (12 CPUs)
Nivel 2 - WSL-DEV      : 32GB WSL | 32GB Windows (16 CPUs)
Nivel 1 - WSL-FOCUS    : 48GB WSL | 16GB Windows (20 CPUs)


SOLUCIÓN DE PROBLEMAS:
═══════════════════════════════════════════════════════════════

¿El icono no aparece?
  → Ejecuta: Make-Icon-Visible.ps1 como administrador

¿PowerShell bloquea los scripts?
  → Ejecuta como administrador:
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

¿WSL no aplica los cambios?
  → Reinicia WSL:
    wsl --shutdown
    (después inicia WSL normalmente)


MÁS INFORMACIÓN:
═══════════════════════════════════════════════════════════════

README.md         - Documentación completa
GitHub            - https://github.com/oratual/WSL-Memory-Monitor
Issues            - Reportar problemas en GitHub


═══════════════════════════════════════════════════════════════
                   ¡Gracias por usar WSL Memory Monitor!
═══════════════════════════════════════════════════════════════
"@

$quickStart | Out-File -FilePath (Join-Path $tempDir "INICIO-RAPIDO.txt") -Encoding UTF8
Write-ColorText "✓ INICIO-RAPIDO.txt creado" "Green"

# Crear instalador automático simple
$autoInstaller = @"
@echo off
echo ============================================================
echo    WSL Memory Monitor - Instalador Automatico
echo ============================================================
echo.
echo Iniciando instalacion...
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0Setup-WSLMemoryMonitor.ps1"
pause
"@

$autoInstaller | Out-File -FilePath (Join-Path $tempDir "INSTALAR.bat") -Encoding ASCII
Write-ColorText "✓ INSTALAR.bat creado" "Green"

# Crear checksums
Write-Section "Generando checksums"

$checksumFile = Join-Path $tempDir "CHECKSUMS.txt"
"WSL Memory Monitor v$Version - Checksums SHA256`n" | Out-File -FilePath $checksumFile -Encoding UTF8
"Generado: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" | Out-File -FilePath $checksumFile -Append -Encoding UTF8
"════════════════════════════════════════════════════`n" | Out-File -FilePath $checksumFile -Append -Encoding UTF8

Get-ChildItem $tempDir -File | Where-Object { $_.Name -ne "CHECKSUMS.txt" } | ForEach-Object {
    $hash = Get-FileHash $_.FullName -Algorithm SHA256
    "$($hash.Hash)  $($_.Name)" | Out-File -FilePath $checksumFile -Append -Encoding UTF8
    Write-Host "  ✓ $($_.Name)" -ForegroundColor Green
}

Write-ColorText "`n✓ CHECKSUMS.txt generado" "Green"

# Comprimir todo
Write-Section "Creando archivo ZIP"

$zipPath = Join-Path $OutputDir "$releaseName.zip"

# Eliminar ZIP existente si existe
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
    Write-Host "Eliminando versión anterior..." -ForegroundColor Yellow
}

# Crear ZIP
try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($tempDir, $zipPath)
    Write-ColorText "✓ ZIP creado exitosamente!" "Green"
} catch {
    Write-ColorText "✗ Error al crear ZIP: $_" "Red"
    exit 1
}

# Calcular tamaño del ZIP
$zipSize = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)

# Generar hash del ZIP
$zipHash = Get-FileHash $zipPath -Algorithm SHA256

# Limpiar directorio temporal
Write-Section "Limpiando"
Remove-Item $tempDir -Recurse -Force
Write-ColorText "✓ Directorio temporal eliminado" "Green"

# Resumen final
Write-Section "Build Completado"

Write-Host ""
Write-ColorText "✓ Release empaquetado exitosamente!" "Green"
Write-Host ""
Write-Host "Información del release:"
Write-Host "  Nombre:    $releaseName"
Write-Host "  Versión:   $Version"
Write-Host "  Archivo:   $zipPath"
Write-Host "  Tamaño:    $zipSize MB"
Write-Host "  Archivos:  $copiedCount"
Write-Host ""
Write-Host "SHA256:    $($zipHash.Hash)"
Write-Host ""

# Crear archivo de release notes
$releaseNotes = @"
# WSL Memory Monitor v$Version

## 🎉 Novedades

### ✨ Gestión Dinámica de Memoria (NEW!)
- **Cambios sin reiniciar WSL**: Ajusta la memoria asignada sin interrumpir tu trabajo
- **Daemon de memoria**: Servicio en segundo plano que aplica cambios instantáneamente
- **Integración completa**: Funciona con la GUI, CLI y monitor de bandeja

### 🚀 Instalación Mejorada
- **Instalador automatizado**: Configuración en un solo paso
- **Auto-detección**: Encuentra y configura todo automáticamente
- **Setup inteligente**: Ajusta las rutas y permisos según tu sistema

### 📦 Mejor Distribución
- **Empaquetado optimizado**: Todo listo para usar
- **Guías incluidas**: Documentación clara en español
- **Checksums**: Verificación de integridad de archivos

## 📥 Instalación

1. Descarga `WSL-Memory-Monitor-v$Version.zip`
2. Extrae a una ubicación permanente (ej: `C:\Tools\WSL-Memory-Monitor`)
3. Ejecuta `INSTALAR.bat` o `Setup-WSLMemoryMonitor.ps1`
4. ¡Listo!

## 📊 Requisitos del Sistema

- Windows 10 (2004+) o Windows 11
- WSL2 versión 2.0.0+
- Mínimo 16GB RAM (32GB+ recomendado)
- PowerShell 5.0+

## 🔗 Enlaces

- **GitHub**: https://github.com/oratual/WSL-Memory-Monitor
- **Issues**: https://github.com/oratual/WSL-Memory-Monitor/issues
- **Documentación**: Ver README.md incluido

## 📋 Checksums

SHA256: $($zipHash.Hash)

---

Build: $timestamp
"@

$releaseNotesPath = Join-Path $OutputDir "$releaseName-RELEASE-NOTES.md"
$releaseNotes | Out-File -FilePath $releaseNotesPath -Encoding UTF8
Write-Host "Release notes: $releaseNotesPath"

Write-Host ""
Write-ColorText "Listo para distribuir! 🎉" "Cyan"
Write-Host ""

# Abrir carpeta de releases
$openFolder = Read-Host "¿Deseas abrir la carpeta de releases? (S/n)"
if ($openFolder -eq '' -or $openFolder -eq 's' -or $openFolder -eq 'S') {
    Start-Process explorer.exe -ArgumentList $OutputDir
}
