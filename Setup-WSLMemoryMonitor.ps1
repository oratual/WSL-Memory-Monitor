# WSL Memory Monitor - Instalador Automatizado
# Versión 2.0

param(
    [switch]$Uninstall,
    [switch]$Silent
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

# Verificar permisos de administrador
function Test-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Función para desinstalar
function Uninstall-WSLMemoryMonitor {
    Write-Section "Desinstalando WSL Memory Monitor"

    # Detener monitor si está corriendo
    Write-Host "Deteniendo monitor..." -ForegroundColor Yellow
    Get-Process | Where-Object {$_.ProcessName -like "*powershell*" -and $_.CommandLine -like "*WSL-Memory-Monitor*"} | Stop-Process -Force -ErrorAction SilentlyContinue

    # Eliminar de inicio automático
    $startupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
    $shortcutPath = "$startupPath\WSL-Memory-Monitor.lnk"
    if (Test-Path $shortcutPath) {
        Remove-Item $shortcutPath -Force
        Write-ColorText "✓ Eliminado del inicio automático" "Green"
    }

    # Eliminar acceso directo del escritorio
    $desktopShortcut = "$env:USERPROFILE\Desktop\WSL Memory Switch.lnk"
    if (Test-Path $desktopShortcut) {
        Remove-Item $desktopShortcut -Force
        Write-ColorText "✓ Eliminado acceso directo del escritorio" "Green"
    }

    # Preguntar si eliminar configuración
    if (-not $Silent) {
        $removeConfig = Read-Host "`n¿Deseas eliminar también la configuración de WSL? (s/N)"
        if ($removeConfig -eq 's' -or $removeConfig -eq 'S') {
            $wslConfig = "$env:USERPROFILE\.wslconfig"
            if (Test-Path $wslConfig) {
                Remove-Item $wslConfig -Force
                Write-ColorText "✓ Configuración de WSL eliminada" "Green"
            }
        }
    }

    Write-ColorText "`n✓ Desinstalación completada" "Green"
    Write-Host "Los archivos del programa permanecen en: $PSScriptRoot"
    Write-Host "Puedes eliminar la carpeta manualmente si lo deseas."
}

# Función principal de instalación
function Install-WSLMemoryMonitor {
    Write-Section "Instalador de WSL Memory Monitor v2.0"

    # Información del sistema
    Write-Host "`nDetectando configuración del sistema..." -ForegroundColor Cyan
    $totalRAM = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
    $cpuCores = (Get-CimInstance Win32_Processor).NumberOfLogicalProcessors

    Write-Host "  RAM Total: $totalRAM GB"
    Write-Host "  CPUs: $cpuCores cores"

    if ($totalRAM -lt 16) {
        Write-ColorText "`n⚠️  ADVERTENCIA: Se recomienda mínimo 16GB de RAM" "Yellow"
        if (-not $Silent) {
            $continue = Read-Host "¿Deseas continuar de todos modos? (s/N)"
            if ($continue -ne 's' -and $continue -ne 'S') {
                Write-Host "Instalación cancelada."
                return
            }
        }
    }

    # Verificar WSL2
    Write-Section "Verificando WSL2"
    try {
        $wslVersion = wsl --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ColorText "✓ WSL detectado" "Green"

            # Verificar distribuciones instaladas
            $distros = wsl --list --quiet
            if ($distros) {
                Write-Host "Distribuciones encontradas:"
                wsl --list --verbose
            } else {
                Write-ColorText "⚠️  No se encontraron distribuciones de WSL instaladas" "Yellow"
            }
        }
    } catch {
        Write-ColorText "✗ WSL no detectado o no instalado" "Red"
        Write-Host "Por favor instala WSL2 primero: wsl --install"
        return
    }

    # Configurar rutas
    Write-Section "Configurando instalación"
    $installDir = $PSScriptRoot
    $userName = $env:USERNAME
    $userProfile = $env:USERPROFILE
    $wslConfigPath = "$userProfile\.wslconfig"

    Write-Host "Directorio de instalación: $installDir"
    Write-Host "Usuario: $userName"

    # Actualizar rutas en los scripts
    Write-Host "`nActualizando rutas en los scripts..." -ForegroundColor Cyan

    # Actualizar WSL-Memory-Switch.ps1
    $switchScript = "$installDir\WSL-Memory-Switch.ps1"
    if (Test-Path $switchScript) {
        $content = Get-Content $switchScript -Raw
        $content = $content -replace '\$ConfigPath = ".*"', "`$ConfigPath = `"$wslConfigPath`""
        $content = $content -replace '\$BackupPath = ".*"', "`$BackupPath = `"$wslConfigPath.backup`""
        $content | Set-Content $switchScript -Encoding UTF8
        Write-ColorText "  ✓ WSL-Memory-Switch.ps1 actualizado" "Green"
    }

    # Actualizar WSL-Memory-Monitor.ps1
    $monitorScript = "$installDir\WSL-Memory-Monitor.ps1"
    if (Test-Path $monitorScript) {
        $content = Get-Content $monitorScript -Raw
        $content = $content -replace '\$ConfigPath = ".*"', "`$ConfigPath = `"$wslConfigPath`""
        $content | Set-Content $monitorScript -Encoding UTF8
        Write-ColorText "  ✓ WSL-Memory-Monitor.ps1 actualizado" "Green"
    }

    # Actualizar CLI script dentro de WSL (si está accesible)
    $cliScript = "$installDir\wsl-memory-switch-cli.sh"
    if (Test-Path $cliScript) {
        # Convertir ruta de Windows a ruta de WSL
        $wslPath = "/mnt/c" + $wslConfigPath.Substring(2).Replace('\', '/')
        $content = Get-Content $cliScript -Raw
        $content = $content -replace 'WSLCONFIG=".*"', "WSLCONFIG=`"$wslPath`""
        $content = $content -replace 'BACKUP=".*"', "BACKUP=`"$wslPath.backup`""
        $content | Set-Content $cliScript -Encoding UTF8
        Write-ColorText "  ✓ wsl-memory-switch-cli.sh actualizado" "Green"
    }

    # Crear acceso directo en el escritorio
    Write-Section "Creando accesos directos"

    $WshShell = New-Object -ComObject WScript.Shell
    $desktopShortcut = "$userProfile\Desktop\WSL Memory Switch.lnk"
    $Shortcut = $WshShell.CreateShortcut($desktopShortcut)
    $Shortcut.TargetPath = "powershell.exe"
    $Shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$installDir\WSL-Memory-Switch.ps1`""
    $Shortcut.WorkingDirectory = $installDir
    $Shortcut.IconLocation = "shell32.dll,238"
    $Shortcut.Description = "WSL Memory Switch - Cambiar perfiles de memoria"
    $Shortcut.Save()
    Write-ColorText "✓ Acceso directo creado en el escritorio" "Green"

    # Configurar inicio automático del monitor
    if (-not $Silent) {
        Write-Host "`n"
        $autoStart = Read-Host "¿Deseas iniciar el monitor automáticamente con Windows? (S/n)"
    } else {
        $autoStart = "s"
    }

    if ($autoStart -eq '' -or $autoStart -eq 's' -or $autoStart -eq 'S') {
        Write-Host "Configurando inicio automático..." -ForegroundColor Cyan

        $startupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
        $startupShortcut = "$startupPath\WSL-Memory-Monitor.lnk"

        $Shortcut = $WshShell.CreateShortcut($startupShortcut)
        $Shortcut.TargetPath = "powershell.exe"
        $Shortcut.Arguments = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$installDir\START-MONITOR.bat`""
        $Shortcut.WorkingDirectory = $installDir
        $Shortcut.IconLocation = "shell32.dll,238"
        $Shortcut.Description = "WSL Memory Monitor - Monitor de bandeja del sistema"
        $Shortcut.Save()

        Write-ColorText "✓ Monitor configurado para inicio automático" "Green"
    }

    # Configurar CLI en WSL
    Write-Section "Configurando herramientas CLI en WSL"

    $hasWSL = $false
    try {
        $wslTest = wsl -e bash -c "echo 'ok'" 2>&1
        if ($wslTest -eq 'ok') {
            $hasWSL = $true
        }
    } catch {
        $hasWSL = $false
    }

    if ($hasWSL) {
        Write-Host "Instalando comando CLI en WSL..." -ForegroundColor Cyan

        # Hacer ejecutable el script
        wsl -e bash -c "chmod +x '$installDir/wsl-memory-switch-cli.sh'" 2>&1 | Out-Null

        # Intentar crear symlink en ~/.local/bin
        $linkCreated = wsl -e bash -c @"
            mkdir -p ~/.local/bin
            ln -sf '$installDir/wsl-memory-switch-cli.sh' ~/.local/bin/wsl-memory-switch 2>/dev/null
            echo `$?
"@

        if ($linkCreated -eq '0') {
            Write-ColorText "✓ Comando 'wsl-memory-switch' instalado" "Green"
            Write-Host "  Asegúrate de que ~/.local/bin esté en tu PATH"
            Write-Host "  Agrega a ~/.bashrc: export PATH=`"`$HOME/.local/bin:`$PATH`""
        } else {
            Write-ColorText "⚠️  No se pudo crear el symlink automáticamente" "Yellow"
            Write-Host "  Crea el link manualmente desde WSL:"
            Write-Host "  ln -s '$installDir/wsl-memory-switch-cli.sh' ~/.local/bin/wsl-memory-switch"
        }
    } else {
        Write-ColorText "⚠️  WSL no está en ejecución" "Yellow"
        Write-Host "  Inicia WSL y ejecuta:"
        Write-Host "  chmod +x '$installDir/wsl-memory-switch-cli.sh'"
        Write-Host "  ln -s '$installDir/wsl-memory-switch-cli.sh' ~/.local/bin/wsl-memory-switch"
    }

    # Crear configuración inicial
    Write-Section "Configuración inicial"

    if (-not (Test-Path $wslConfigPath)) {
        Write-Host "Creando configuración inicial de WSL..." -ForegroundColor Cyan

        # Calcular perfil balanceado basado en RAM disponible
        $wslMemory = [math]::Min(48, [math]::Floor($totalRAM * 0.5))
        $wslCPUs = [math]::Min(20, [math]::Floor($cpuCores * 0.75))

        $initialConfig = @"
[wsl2]
# Perfil inicial: BALANCED - $(Get-Date -Format "yyyy-MM-dd HH:mm")
memory=${wslMemory}GB
processors=$wslCPUs
swap=0
guiApplications=false
networkingMode=mirrored
dnsTunneling=true
firewall=true

[experimental]
autoMemoryReclaim=gradual
sparseVhd=true
"@

        $initialConfig | Out-File -FilePath $wslConfigPath -Encoding UTF8
        Write-ColorText "✓ Configuración inicial creada" "Green"
        Write-Host "  Perfil: BALANCED ($wslMemory GB RAM, $wslCPUs CPUs)"
    } else {
        Write-ColorText "✓ Configuración de WSL ya existe" "Green"
    }

    # Configurar política de ejecución
    Write-Section "Configurando permisos"

    $executionPolicy = Get-ExecutionPolicy -Scope CurrentUser
    if ($executionPolicy -eq 'Restricted' -or $executionPolicy -eq 'Undefined') {
        Write-Host "Configurando política de ejecución de PowerShell..." -ForegroundColor Cyan
        try {
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
            Write-ColorText "✓ Política de ejecución configurada" "Green"
        } catch {
            Write-ColorText "⚠️  No se pudo cambiar la política de ejecución" "Yellow"
            Write-Host "  Ejecuta manualmente: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser"
        }
    } else {
        Write-ColorText "✓ Política de ejecución ya configurada" "Green"
    }

    # Configurar visibilidad del icono de bandeja
    Write-Section "Configurando icono de bandeja"

    if (Test-Admin) {
        Write-Host "Configurando visibilidad del icono..." -ForegroundColor Cyan
        try {
            & "$installDir\Make-Icon-Visible.ps1" -ErrorAction Stop
            Write-ColorText "✓ Icono configurado" "Green"
        } catch {
            Write-ColorText "⚠️  No se pudo configurar automáticamente" "Yellow"
            Write-Host "  Ejecuta Make-Icon-Visible.ps1 manualmente después"
        }
    } else {
        Write-ColorText "⚠️  Se necesitan permisos de administrador para configurar el icono" "Yellow"
        Write-Host "  Ejecuta Make-Icon-Visible.ps1 como administrador después"
    }

    # Iniciar monitor
    if (-not $Silent) {
        Write-Host "`n"
        $startNow = Read-Host "¿Deseas iniciar el monitor ahora? (S/n)"
    } else {
        $startNow = "s"
    }

    if ($startNow -eq '' -or $startNow -eq 's' -or $startNow -eq 'S') {
        Write-Host "Iniciando WSL Memory Monitor..." -ForegroundColor Cyan
        Start-Process powershell -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$installDir\START-MONITOR.bat`""
        Start-Sleep -Seconds 2
        Write-ColorText "✓ Monitor iniciado" "Green"
    }

    # Resumen final
    Write-Section "Instalación Completada"

    Write-ColorText "`n✓ WSL Memory Monitor instalado exitosamente!" "Green"
    Write-Host "`nPara usar el programa:"
    Write-Host "  • Haz doble clic en el acceso directo del escritorio"
    Write-Host "  • O haz click en el icono de la bandeja del sistema"
    Write-Host "  • Desde WSL: wsl-memory-switch --help"
    Write-Host "`nArchivos instalados en: $installDir"
    Write-Host "Configuración en: $wslConfigPath"

    if ($hasWSL) {
        Write-Host "`nPróximos pasos:"
        Write-Host "  1. Abre WSL Memory Switch desde el escritorio"
        Write-Host "  2. Selecciona tu perfil de memoria preferido"
        Write-Host "  3. El monitor se iniciará automáticamente con Windows"
    } else {
        Write-ColorText "`n⚠️  Recuerda reiniciar WSL para aplicar los cambios:" "Yellow"
        Write-Host "  wsl --shutdown"
    }

    Write-Host "`nPara desinstalar: .\Setup-WSLMemoryMonitor.ps1 -Uninstall"
    Write-Host ""
}

# Programa principal
try {
    # Banner
    Clear-Host
    Write-Host ""
    Write-ColorText "╔════════════════════════════════════════════════════════════╗" "Cyan"
    Write-ColorText "║                                                            ║" "Cyan"
    Write-ColorText "║           WSL MEMORY MONITOR - INSTALADOR v2.0             ║" "Yellow"
    Write-ColorText "║                                                            ║" "Cyan"
    Write-ColorText "╚════════════════════════════════════════════════════════════╝" "Cyan"
    Write-Host ""

    if ($Uninstall) {
        Uninstall-WSLMemoryMonitor
    } else {
        Install-WSLMemoryMonitor
    }

    if (-not $Silent) {
        Write-Host ""
        Pause
    }
}
catch {
    Write-Host ""
    Write-ColorText "✗ Error durante la instalación: $_" "Red"
    Write-Host ""
    Write-Host "Stack trace:" -ForegroundColor Yellow
    Write-Host $_.ScriptStackTrace
    exit 1
}
