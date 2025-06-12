# WSL Memory Switch - Cambiar perfiles de memoria para WSL2
# Sistema: Ryzen 9 5900X (24 threads) + 64GB RAM

$ConfigPath = "C:\Users\lauta\.wslconfig"
$BackupPath = "C:\Users\lauta\.wslconfig.backup"
$ProfilesPath = "\\wsl.localhost\Ubuntu\home\lauta\glados\scripts\wsl-memory-switch\wsl-memory-profiles.conf"

# Colores
function Write-ColorText($text, $color) {
    Write-Host $text -ForegroundColor $color
}

# Función para obtener estado actual
function Get-CurrentProfile {
    if (Test-Path $ConfigPath) {
        $content = Get-Content $ConfigPath -Raw
        if ($content -match 'memory=(\d+GB)') {
            $memory = $matches[1]
            if ($content -match 'processors=(\d+)') {
                $procs = $matches[1]
                return @{Memory=$memory; Processors=$procs}
            }
        }
    }
    return $null
}

# Función para mostrar menú
function Show-Menu {
    Clear-Host
    Write-ColorText "================================================" "Cyan"
    Write-ColorText "       WSL MEMORY SWITCH - CONTROL PANEL        " "Yellow"
    Write-ColorText "================================================" "Cyan"
    Write-ColorText "Sistema: Ryzen 9 5900X (24 cores) + 64GB RAM" "Gray"
    Write-ColorText "================================================" "Cyan"
    
    # Mostrar estado actual
    $current = Get-CurrentProfile
    if ($current) {
        Write-ColorText "`nEstado Actual:" "Green"
        Write-ColorText "  Memoria: $($current.Memory)" "White"
        Write-ColorText "  Procesadores: $($current.Processors)" "White"
    }
    
    Write-ColorText "`n================================================" "Cyan"
    Write-ColorText "PERFILES DISPONIBLES:" "Yellow"
    Write-ColorText "================================================" "Cyan"
    
    Write-Host ""
    Write-ColorText "[1] GAMING MODE" "Red"
    Write-Host "    └─ WSL: 8GB RAM + 4 CPUs"
    Write-Host "    └─ Windows: 56GB RAM + 20 CPUs disponibles"
    Write-Host "    └─ Ideal para: Juegos AAA, streaming"
    
    Write-Host ""
    Write-ColorText "[2] BALANCED MODE" "Yellow"
    Write-Host "    └─ WSL: 24GB RAM + 12 CPUs"
    Write-Host "    └─ Windows: 40GB RAM + 12 CPUs disponibles"
    Write-Host "    └─ Ideal para: Uso mixto, desarrollo + apps Windows"
    
    Write-Host ""
    Write-ColorText "[3] WSL FOCUS MODE" "Green"
    Write-Host "    └─ WSL: 48GB RAM + 20 CPUs"
    Write-Host "    └─ Windows: 16GB RAM + 4 CPUs disponibles"
    Write-Host "    └─ Ideal para: Desarrollo intensivo, Docker, compilación"
    
    Write-Host ""
    Write-ColorText "[4] WINDOWS FOCUS MODE" "Blue"
    Write-Host "    └─ WSL: 16GB RAM + 8 CPUs"
    Write-Host "    └─ Windows: 48GB RAM + 16 CPUs disponibles"
    Write-Host "    └─ Ideal para: Edición video, diseño, VMs Windows"
    
    Write-Host ""
    Write-ColorText "[5] CUSTOM MODE" "Magenta"
    Write-Host "    └─ Configurar valores personalizados"
    
    Write-Host ""
    Write-ColorText "[R] RESTART WSL" "Cyan"
    Write-Host "    └─ Reiniciar WSL para aplicar cambios"
    
    Write-Host ""
    Write-ColorText "[S] STATUS" "White"
    Write-Host "    └─ Ver estado detallado de WSL"
    
    Write-Host ""
    Write-ColorText "[Q] SALIR" "DarkGray"
    
    Write-ColorText "`n================================================" "Cyan"
}

# Función para aplicar perfil
function Apply-Profile($memory, $processors, $profileName) {
    Write-ColorText "`nAplicando perfil $profileName..." "Yellow"
    
    # Backup actual
    if (Test-Path $ConfigPath) {
        Copy-Item $ConfigPath $BackupPath -Force
        Write-Host "Backup creado en: $BackupPath"
    }
    
    # Crear nueva configuración
    $newConfig = @"
[wsl2]
# Perfil: $profileName - $(Get-Date -Format "yyyy-MM-dd HH:mm")
memory=$memory
processors=$processors
swap=0
guiApplications=false
networkingMode=mirrored
dnsTunneling=true
firewall=true

[experimental]
autoMemoryReclaim=gradual
sparseVhd=true
"@
    
    # Guardar configuración
    $newConfig | Out-File -FilePath $ConfigPath -Encoding UTF8
    Write-ColorText "Configuración actualizada exitosamente!" "Green"
    
    # Preguntar si reiniciar WSL
    Write-Host ""
    $restart = Read-Host "Deseas reiniciar WSL ahora para aplicar los cambios? (S/N)"
    if ($restart -eq 'S' -or $restart -eq 's') {
        Restart-WSL
    }
}

# Función para reiniciar WSL
function Restart-WSL {
    Write-ColorText "`nReiniciando WSL..." "Yellow"
    
    # Verificar si WSL está corriendo
    $wslStatus = wsl --list --running
    if ($wslStatus -match "Ubuntu") {
        Write-Host "Cerrando WSL..."
        wsl --shutdown
        Start-Sleep -Seconds 3
    }
    
    # Reiniciar servicio
    Write-Host "Reiniciando servicio LxssManager..."
    Stop-Service LxssManager -Force -ErrorAction SilentlyContinue
    Start-Service LxssManager
    Start-Sleep -Seconds 2
    
    Write-ColorText "WSL reiniciado exitosamente!" "Green"
    Write-Host "Puedes iniciar WSL con: wsl"
    Write-Host ""
    Pause
}

# Función para mostrar estado
function Show-Status {
    Clear-Host
    Write-ColorText "=== ESTADO DE WSL ===" "Cyan"
    
    # Estado actual de configuración
    $current = Get-CurrentProfile
    if ($current) {
        Write-ColorText "`nConfiguración Actual:" "Yellow"
        Write-Host "  Memoria asignada: $($current.Memory)"
        Write-Host "  Procesadores asignados: $($current.Processors)"
    }
    
    # Estado de ejecución
    Write-ColorText "`nEstado de WSL:" "Yellow"
    wsl --list --verbose
    
    # Verificar si está corriendo
    $running = wsl --list --running
    if ($running -match "Ubuntu") {
        Write-ColorText "`nWSL está ACTIVO" "Green"
        
        # Mostrar uso de memoria desde WSL
        Write-ColorText "`nUso de Memoria en WSL:" "Yellow"
        wsl -e bash -c "free -h | grep -E 'Mem:|Swap:'"
        
        Write-ColorText "`nCarga del Sistema:" "Yellow"
        wsl -e bash -c "uptime"
    } else {
        Write-ColorText "`nWSL está DETENIDO" "Red"
    }
    
    Write-Host ""
    Pause
}

# Función para modo personalizado
function Custom-Mode {
    Clear-Host
    Write-ColorText "=== MODO PERSONALIZADO ===" "Magenta"
    Write-Host "Sistema: 64GB RAM total, 24 CPUs disponibles"
    Write-Host ""
    
    # Solicitar memoria
    do {
        $memInput = Read-Host "Cuánta memoria asignar a WSL? (ej: 32)"
        $memValue = 0
        if ([int]::TryParse($memInput, [ref]$memValue) -and $memValue -gt 0 -and $memValue -le 60) {
            $memory = "${memValue}GB"
            break
        }
        Write-ColorText "Por favor ingresa un valor entre 1 y 60 GB" "Red"
    } while ($true)
    
    # Solicitar procesadores
    do {
        $procInput = Read-Host "Cuántos procesadores asignar? (ej: 16)"
        $procValue = 0
        if ([int]::TryParse($procInput, [ref]$procValue) -and $procValue -gt 0 -and $procValue -le 24) {
            $processors = $procValue
            break
        }
        Write-ColorText "Por favor ingresa un valor entre 1 y 24" "Red"
    } while ($true)
    
    # Mostrar resumen
    Write-Host ""
    Write-ColorText "Configuración personalizada:" "Yellow"
    Write-Host "  WSL: $memory RAM + $processors CPUs"
    Write-Host "  Windows: $([Math]::Max(4, 64 - $memValue))GB RAM + $([Math]::Max(1, 24 - $procValue)) CPUs disponibles"
    
    Write-Host ""
    $confirm = Read-Host "Aplicar esta configuración? (S/N)"
    if ($confirm -eq 'S' -or $confirm -eq 's') {
        Apply-Profile $memory $processors "CUSTOM"
    }
}

# Bucle principal
do {
    Show-Menu
    $choice = Read-Host "`nSelecciona una opción"
    
    switch ($choice) {
        '1' { Apply-Profile "8GB" 4 "GAMING" }
        '2' { Apply-Profile "24GB" 12 "BALANCED" }
        '3' { Apply-Profile "48GB" 20 "WSL_FOCUS" }
        '4' { Apply-Profile "16GB" 8 "WINDOWS_FOCUS" }
        '5' { Custom-Mode }
        'R' { Restart-WSL }
        'r' { Restart-WSL }
        'S' { Show-Status }
        's' { Show-Status }
        'Q' { break }
        'q' { break }
        default { 
            Write-ColorText "Opción no válida!" "Red"
            Start-Sleep -Seconds 1
        }
    }
} while ($choice -ne 'Q' -and $choice -ne 'q')

Write-ColorText "`nHasta luego!" "Green"