# WSL Memory Switch - Cambiar perfiles de memoria para WSL2
# Perfiles dinámicos basados en RAM del sistema

$ConfigPath = "$env:USERPROFILE\.wslconfig"
$BackupPath = "$env:USERPROFILE\.wslconfig.backup"

# Colores
function Write-ColorText($text, $color) {
    Write-Host $text -ForegroundColor $color
}

# Función para detectar recursos del sistema
function Get-SystemResources {
    try {
        # Obtener RAM total en GB
        $totalRAM = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)

        # Obtener número de CPUs lógicos
        $totalCPUs = (Get-CimInstance Win32_Processor).NumberOfLogicalProcessors

        # Obtener nombre del procesador
        $cpuName = (Get-CimInstance Win32_Processor).Name -replace '\s+', ' '

        return @{
            TotalRAM = $totalRAM
            TotalCPUs = $totalCPUs
            CPUName = $cpuName
        }
    } catch {
        Write-ColorText "Error detectando recursos del sistema: $_" "Red"
        # Valores por defecto si hay error
        return @{
            TotalRAM = 16
            TotalCPUs = 8
            CPUName = "Unknown CPU"
        }
    }
}

# Función para generar perfiles dinámicos basados en RAM disponible
function Get-DynamicProfiles {
    param($systemResources)

    $totalRAM = $systemResources.TotalRAM
    $totalCPUs = $systemResources.TotalCPUs

    # Calcular perfiles basados en porcentajes de RAM
    # Perfil 1: GAMING - 12.5% RAM para WSL (mínimo 4GB, máximo 8GB)
    $p1_wsl = [math]::Max(4, [math]::Min(8, [math]::Floor($totalRAM * 0.125)))
    $p1_cpu = [math]::Max(2, [math]::Floor($totalCPUs * 0.25))

    # Perfil 2: WINDOWS FOCUS - 25% RAM para WSL
    $p2_wsl = [math]::Max(8, [math]::Floor($totalRAM * 0.25))
    $p2_cpu = [math]::Max(4, [math]::Floor($totalCPUs * 0.33))

    # Perfil 3: BALANCED - 37.5% RAM para WSL
    $p3_wsl = [math]::Max(12, [math]::Floor($totalRAM * 0.375))
    $p3_cpu = [math]::Max(6, [math]::Floor($totalCPUs * 0.50))

    # Perfil 4: WSL DEV - 50% RAM para WSL
    $p4_wsl = [math]::Max(16, [math]::Floor($totalRAM * 0.50))
    $p4_cpu = [math]::Max(8, [math]::Floor($totalCPUs * 0.67))

    # Perfil 5: WSL FOCUS - 75% RAM para WSL (máximo seguro)
    $p5_wsl = [math]::Max(24, [math]::Min($totalRAM - 8, [math]::Floor($totalRAM * 0.75)))
    $p5_cpu = [math]::Max(12, [math]::Floor($totalCPUs * 0.83))

    return @(
        @{
            Name = "GAMING"
            Level = 1
            WSL_RAM = $p1_wsl
            WSL_CPU = $p1_cpu
            WIN_RAM = $totalRAM - $p1_wsl
            WIN_CPU = $totalCPUs - $p1_cpu
            Color = "Red"
            Description = "Juegos AAA, streaming, máximo rendimiento Windows"
        },
        @{
            Name = "WINDOWS FOCUS"
            Level = 2
            WSL_RAM = $p2_wsl
            WSL_CPU = $p2_cpu
            WIN_RAM = $totalRAM - $p2_wsl
            WIN_CPU = $totalCPUs - $p2_cpu
            Color = "Blue"
            Description = "Edición video, diseño, VMs Windows"
        },
        @{
            Name = "BALANCED"
            Level = 3
            WSL_RAM = $p3_wsl
            WSL_CPU = $p3_cpu
            WIN_RAM = $totalRAM - $p3_wsl
            WIN_CPU = $totalCPUs - $p3_cpu
            Color = "Yellow"
            Description = "Uso mixto, desarrollo + apps Windows"
        },
        @{
            Name = "WSL DEV"
            Level = 4
            WSL_RAM = $p4_wsl
            WSL_CPU = $p4_cpu
            WIN_RAM = $totalRAM - $p4_wsl
            WIN_CPU = $totalCPUs - $p4_cpu
            Color = "Green"
            Description = "Desarrollo, Docker, builds medianos"
        },
        @{
            Name = "WSL FOCUS"
            Level = 5
            WSL_RAM = $p5_wsl
            WSL_CPU = $p5_cpu
            WIN_RAM = $totalRAM - $p5_wsl
            WIN_CPU = $totalCPUs - $p5_cpu
            Color = "Cyan"
            Description = "Desarrollo intensivo, Docker pesado, compilación"
        }
    )
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

# Función para mostrar menú con perfiles dinámicos
function Show-Menu {
    param($systemResources, $profiles)

    Clear-Host
    Write-ColorText "═══════════════════════════════════════════════════════════" "Cyan"
    Write-ColorText "          WSL MEMORY SWITCH - CONTROL PANEL                " "Yellow"
    Write-ColorText "═══════════════════════════════════════════════════════════" "Cyan"
    Write-ColorText "Sistema: $($systemResources.CPUName)" "Gray"
    Write-ColorText "RAM Total: $($systemResources.TotalRAM) GB | CPUs: $($systemResources.TotalCPUs) cores" "Gray"
    Write-ColorText "═══════════════════════════════════════════════════════════" "Cyan"

    # Mostrar estado actual
    $current = Get-CurrentProfile
    if ($current) {
        Write-ColorText "`nEstado Actual:" "Green"
        Write-ColorText "  Memoria: $($current.Memory)" "White"
        Write-ColorText "  Procesadores: $($current.Processors)" "White"

        # Verificar si el daemon está activo
        if (Test-DaemonRunning) {
            Write-ColorText "  Modo dinámico: ACTIVO ⚡" "Green"
        }
    }

    Write-ColorText "`n═══════════════════════════════════════════════════════════" "Cyan"
    Write-ColorText "PERFILES DISPONIBLES (calculados para tu sistema):" "Yellow"
    Write-ColorText "═══════════════════════════════════════════════════════════" "Cyan"

    # Mostrar cada perfil dinámicamente
    $index = 1
    foreach ($profile in $profiles) {
        Write-Host ""
        Write-ColorText "[$index] $($profile.Name)" $profile.Color
        Write-Host "    ├─ WSL:     $($profile.WSL_RAM) GB RAM + $($profile.WSL_CPU) CPUs"
        Write-Host "    ├─ Windows: $($profile.WIN_RAM) GB RAM + $($profile.WIN_CPU) CPUs disponibles"
        Write-Host "    └─ Uso: $($profile.Description)"
        $index++
    }

    Write-Host ""
    Write-ColorText "[C] CUSTOM MODE" "Magenta"
    Write-Host "    └─ Configurar valores personalizados a mano"

    Write-Host ""
    Write-ColorText "[R] RESTART WSL" "Cyan"
    Write-Host "    └─ Reiniciar WSL para aplicar cambios"

    Write-Host ""
    Write-ColorText "[S] STATUS" "White"
    Write-Host "    └─ Ver estado detallado de WSL"

    Write-Host ""
    Write-ColorText "[Q] SALIR" "DarkGray"

    Write-ColorText "`n═══════════════════════════════════════════════════════════" "Cyan"
}

# Función para verificar si el daemon está corriendo
function Test-DaemonRunning {
    try {
        $daemonStatus = wsl -e bash -c "wsl-memory-daemon status 2>&1 | grep -q 'RUNNING' && echo 'true' || echo 'false'"
        return ($daemonStatus -eq 'true')
    } catch {
        return $false
    }
}

# Función para aplicar cambios dinámicamente (sin reiniciar WSL)
function Apply-Dynamic($memory, $processors, $profileName) {
    Write-ColorText "`nAplicando cambios dinámicamente (sin reiniciar)..." "Cyan"

    # Extraer número de GB
    $memGB = $memory -replace 'GB', ''

    # Aplicar a través del daemon
    try {
        $result = wsl -e bash -c "wsl-memory-daemon set $memGB $processors 2>&1"

        if ($LASTEXITCODE -eq 0) {
            Write-ColorText "✓ Cambios aplicados dinámicamente!" "Green"
            Write-Host "  Memoria: $memory"
            Write-Host "  CPUs: $processors"
            Write-Host ""
            Write-ColorText "Nota: Los cambios de memoria son inmediatos." "Yellow"
            Write-ColorText "      Los cambios de CPU requieren reiniciar WSL." "Yellow"

            # Actualizar también .wslconfig para persistencia
            Update-WslConfig $memory $processors $profileName

            return $true
        } else {
            Write-ColorText "✗ Error al aplicar cambios dinámicos" "Red"
            Write-Host $result
            return $false
        }
    } catch {
        Write-ColorText "✗ Error: $_" "Red"
        return $false
    }
}

# Función para actualizar .wslconfig sin aplicar
function Update-WslConfig($memory, $processors, $profileName) {
    # Backup actual
    if (Test-Path $ConfigPath) {
        Copy-Item $ConfigPath $BackupPath -Force
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
}

# Función para aplicar perfil
function Apply-Profile($memory, $processors, $profileName) {
    Write-ColorText "`nAplicando perfil $profileName..." "Yellow"

    # Verificar si el daemon está disponible
    $daemonAvailable = Test-DaemonRunning

    if ($daemonAvailable) {
        Write-Host ""
        Write-ColorText "El daemon de memoria dinámica está activo!" "Green"
        Write-Host ""
        Write-Host "Opciones:"
        Write-Host "  [D] Aplicar DINÁMICAMENTE (sin reiniciar WSL) - Recomendado"
        Write-Host "  [R] Aplicar y REINICIAR WSL (método tradicional)"
        Write-Host "  [C] Solo actualizar configuración (aplicar después)"
        Write-Host ""

        $choice = Read-Host "¿Cómo deseas aplicar los cambios? (D/R/C)"

        switch ($choice.ToUpper()) {
            'D' {
                # Aplicar dinámicamente
                $success = Apply-Dynamic $memory $processors $profileName
                if ($success) {
                    Write-Host ""
                    Pause
                    return
                }
                # Si falla, continuar con método tradicional
                Write-ColorText "`nUsando método tradicional..." "Yellow"
            }
            'C' {
                # Solo actualizar config
                Update-WslConfig $memory $processors $profileName
                Write-ColorText "`nConfiguración actualizada!" "Green"
                Write-Host "Los cambios se aplicarán al reiniciar WSL"
                Write-Host ""
                Pause
                return
            }
            # 'R' o default: continuar con reinicio
        }
    }

    # Método tradicional: actualizar config y preguntar por reinicio
    Update-WslConfig $memory $processors $profileName
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

# Función para modo personalizado con límites dinámicos
function Custom-Mode {
    param($systemResources)

    Clear-Host
    Write-ColorText "═══════════════════════════════════════════════════════════" "Magenta"
    Write-ColorText "              MODO PERSONALIZADO - CONFIGURACIÓN MANUAL     " "Yellow"
    Write-ColorText "═══════════════════════════════════════════════════════════" "Magenta"
    Write-Host ""
    Write-Host "Sistema detectado:"
    Write-Host "  • RAM Total:  $($systemResources.TotalRAM) GB"
    Write-Host "  • CPUs Total: $($systemResources.TotalCPUs) cores"
    Write-Host ""
    Write-ColorText "Recomendaciones:" "Cyan"
    Write-Host "  • RAM para WSL:  mínimo 4GB, máximo $($systemResources.TotalRAM - 4)GB"
    Write-Host "  • Deja al menos 4GB para Windows"
    Write-Host "  • CPUs para WSL: mínimo 2, máximo $($systemResources.TotalCPUs - 1)"
    Write-Host ""
    Write-ColorText "═══════════════════════════════════════════════════════════" "Magenta"

    # Calcular límites seguros
    $maxSafeRAM = $systemResources.TotalRAM - 4  # Dejar mínimo 4GB para Windows
    $maxSafeCPU = $systemResources.TotalCPUs - 1  # Dejar al menos 1 CPU para Windows

    # Solicitar memoria
    Write-Host ""
    do {
        $memInput = Read-Host "¿Cuánta memoria asignar a WSL? (en GB, ej: 32)"
        $memValue = 0
        if ([int]::TryParse($memInput, [ref]$memValue)) {
            if ($memValue -lt 1) {
                Write-ColorText "⚠ La memoria debe ser al menos 1GB" "Red"
            }
            elseif ($memValue -gt $maxSafeRAM) {
                Write-ColorText "⚠ Advertencia: Dejarías solo $($systemResources.TotalRAM - $memValue)GB para Windows" "Yellow"
                $confirm = Read-Host "¿Estás seguro? Esto podría causar problemas de rendimiento (S/N)"
                if ($confirm -eq 'S' -or $confirm -eq 's') {
                    $memory = "${memValue}GB"
                    break
                }
            }
            else {
                $memory = "${memValue}GB"
                break
            }
        }
        else {
            Write-ColorText "Por favor ingresa un número válido" "Red"
        }
    } while ($true)

    # Solicitar procesadores
    Write-Host ""
    do {
        $procInput = Read-Host "¿Cuántos procesadores asignar? (ej: 16)"
        $procValue = 0
        if ([int]::TryParse($procInput, [ref]$procValue)) {
            if ($procValue -lt 1) {
                Write-ColorText "⚠ Los procesadores deben ser al menos 1" "Red"
            }
            elseif ($procValue -gt $maxSafeCPU) {
                Write-ColorText "⚠ Advertencia: Dejarías solo $($systemResources.TotalCPUs - $procValue) CPU(s) para Windows" "Yellow"
                $confirm = Read-Host "¿Estás seguro? (S/N)"
                if ($confirm -eq 'S' -or $confirm -eq 's') {
                    $processors = $procValue
                    break
                }
            }
            else {
                $processors = $procValue
                break
            }
        }
        else {
            Write-ColorText "Por favor ingresa un número válido" "Red"
        }
    } while ($true)

    # Calcular recursos restantes para Windows
    $winRAM = $systemResources.TotalRAM - $memValue
    $winCPUs = $systemResources.TotalCPUs - $procValue

    # Mostrar resumen
    Write-Host ""
    Write-ColorText "═══════════════════════════════════════════════════════════" "Cyan"
    Write-ColorText "              RESUMEN DE CONFIGURACIÓN                      " "Yellow"
    Write-ColorText "═══════════════════════════════════════════════════════════" "Cyan"
    Write-Host ""
    Write-Host "WSL recibirá:"
    Write-ColorText "  • Memoria:      $memory ($memValue GB)" "Green"
    Write-ColorText "  • Procesadores: $processors cores" "Green"
    Write-Host ""
    Write-Host "Windows tendrá disponible:"
    Write-ColorText "  • Memoria:      $winRAM GB" $(if ($winRAM -lt 8) { "Red" } elseif ($winRAM -lt 16) { "Yellow" } else { "Green" })
    Write-ColorText "  • Procesadores: $winCPUs cores" $(if ($winCPUs -lt 2) { "Red" } elseif ($winCPUs -lt 4) { "Yellow" } else { "Green" })
    Write-Host ""

    # Advertencias si la configuración es extrema
    if ($winRAM -lt 8) {
        Write-ColorText "⚠ ADVERTENCIA: Windows tendrá menos de 8GB, puede haber problemas de rendimiento!" "Red"
    }
    if ($winCPUs -lt 2) {
        Write-ColorText "⚠ ADVERTENCIA: Windows tendrá menos de 2 CPUs, puede haber lentitud!" "Red"
    }

    Write-ColorText "═══════════════════════════════════════════════════════════" "Cyan"
    Write-Host ""

    $confirm = Read-Host "¿Aplicar esta configuración? (S/N)"
    if ($confirm -eq 'S' -or $confirm -eq 's') {
        Apply-Profile $memory $processors "CUSTOM"
    }
}

# ═══════════════════════════════════════════════════════════
# PROGRAMA PRINCIPAL
# ═══════════════════════════════════════════════════════════

# Detectar recursos del sistema al inicio
Write-Host "Detectando configuración del sistema..." -ForegroundColor Cyan
$systemResources = Get-SystemResources
$profiles = Get-DynamicProfiles -systemResources $systemResources

Write-Host "Sistema detectado: $($systemResources.TotalRAM)GB RAM, $($systemResources.TotalCPUs) CPUs" -ForegroundColor Green
Start-Sleep -Seconds 1

# Bucle principal
do {
    Show-Menu -systemResources $systemResources -profiles $profiles
    $choice = Read-Host "`nSelecciona una opción"

    switch ($choice) {
        '1' {
            # Perfil 1 - GAMING
            $profile = $profiles[0]
            Apply-Profile "$($profile.WSL_RAM)GB" $profile.WSL_CPU $profile.Name
        }
        '2' {
            # Perfil 2 - WINDOWS FOCUS
            $profile = $profiles[1]
            Apply-Profile "$($profile.WSL_RAM)GB" $profile.WSL_CPU $profile.Name
        }
        '3' {
            # Perfil 3 - BALANCED
            $profile = $profiles[2]
            Apply-Profile "$($profile.WSL_RAM)GB" $profile.WSL_CPU $profile.Name
        }
        '4' {
            # Perfil 4 - WSL DEV
            $profile = $profiles[3]
            Apply-Profile "$($profile.WSL_RAM)GB" $profile.WSL_CPU $profile.Name
        }
        '5' {
            # Perfil 5 - WSL FOCUS
            $profile = $profiles[4]
            Apply-Profile "$($profile.WSL_RAM)GB" $profile.WSL_CPU $profile.Name
        }
        'C' {
            # Modo personalizado
            Custom-Mode -systemResources $systemResources
        }
        'c' {
            # Modo personalizado
            Custom-Mode -systemResources $systemResources
        }
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

Write-Host ""
Write-ColorText "═══════════════════════════════════════════════════════════" "Cyan"
Write-ColorText "    ¡Gracias por usar WSL Memory Switch!" "Green"
Write-ColorText "═══════════════════════════════════════════════════════════" "Cyan"
Write-Host ""