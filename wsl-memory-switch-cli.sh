#!/bin/bash
# WSL Memory Switch CLI - Control de perfiles de memoria desde Linux
# Perfiles dinámicos basados en RAM del sistema

# Configuración
# Detectar automáticamente el usuario de Windows
WINDOWS_USER=$(powershell.exe -Command "echo \$env:USERNAME" 2>/dev/null | tr -d '\r')
if [ -z "$WINDOWS_USER" ]; then
    WINDOWS_USER="$USER"
fi

WSLCONFIG="/mnt/c/Users/${WINDOWS_USER}/.wslconfig"
BACKUP="/mnt/c/Users/${WINDOWS_USER}/.wslconfig.backup"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Función para detectar recursos del sistema
get_system_resources() {
    # Obtener RAM total del sistema en GB
    local total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_ram=$((total_ram_kb / 1024 / 1024))

    # Obtener número de CPUs
    local total_cpus=$(nproc)

    # Obtener nombre del CPU
    local cpu_name=$(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs)

    echo "$total_ram:$total_cpus:$cpu_name"
}

# Función para generar perfiles dinámicos
generate_dynamic_profiles() {
    local total_ram=$1
    local total_cpus=$2

    # Perfil 1: GAMING - 12.5% RAM para WSL (mínimo 4GB, máximo 8GB)
    local p1_wsl=$(( total_ram * 125 / 1000 ))
    [ $p1_wsl -lt 4 ] && p1_wsl=4
    [ $p1_wsl -gt 8 ] && p1_wsl=8
    local p1_cpu=$(( total_cpus * 25 / 100 ))
    [ $p1_cpu -lt 2 ] && p1_cpu=2

    # Perfil 2: WINDOWS FOCUS - 25% RAM para WSL
    local p2_wsl=$(( total_ram * 25 / 100 ))
    [ $p2_wsl -lt 8 ] && p2_wsl=8
    local p2_cpu=$(( total_cpus * 33 / 100 ))
    [ $p2_cpu -lt 4 ] && p2_cpu=4

    # Perfil 3: BALANCED - 37.5% RAM para WSL
    local p3_wsl=$(( total_ram * 375 / 1000 ))
    [ $p3_wsl -lt 12 ] && p3_wsl=12
    local p3_cpu=$(( total_cpus * 50 / 100 ))
    [ $p3_cpu -lt 6 ] && p3_cpu=6

    # Perfil 4: WSL DEV - 50% RAM para WSL
    local p4_wsl=$(( total_ram * 50 / 100 ))
    [ $p4_wsl -lt 16 ] && p4_wsl=16
    local p4_cpu=$(( total_cpus * 67 / 100 ))
    [ $p4_cpu -lt 8 ] && p4_cpu=8

    # Perfil 5: WSL FOCUS - 75% RAM para WSL (máximo seguro)
    local p5_wsl=$(( total_ram * 75 / 100 ))
    [ $p5_wsl -lt 24 ] && p5_wsl=24
    local max_wsl=$(( total_ram - 8 ))
    [ $p5_wsl -gt $max_wsl ] && p5_wsl=$max_wsl
    local p5_cpu=$(( total_cpus * 83 / 100 ))
    [ $p5_cpu -lt 12 ] && p5_cpu=12

    # Retornar perfiles separados por pipes
    echo "${p1_wsl}:${p1_cpu}|${p2_wsl}:${p2_cpu}|${p3_wsl}:${p3_cpu}|${p4_wsl}:${p4_cpu}|${p5_wsl}:${p5_cpu}"
}

# Función para obtener perfil actual
get_current_profile() {
    if [ -f "$WSLCONFIG" ]; then
        local memory=$(grep -oP 'memory=\K\d+GB' "$WSLCONFIG" 2>/dev/null)
        local procs=$(grep -oP 'processors=\K\d+' "$WSLCONFIG" 2>/dev/null)
        echo "Memoria: $memory, Procesadores: $procs"
    else
        echo "No configurado"
    fi
}

# Verificar si el daemon está corriendo
check_daemon() {
    if command -v wsl-memory-daemon &> /dev/null; then
        if wsl-memory-daemon status 2>&1 | grep -q "RUNNING"; then
            return 0  # Daemon corriendo
        fi
    fi
    return 1  # Daemon no disponible
}

# Aplicar cambios dinámicamente usando el daemon
apply_dynamic() {
    local memory=$1
    local processors=$2
    local profile_name=$3

    echo -e "${CYAN}Aplicando cambios dinámicamente (sin reiniciar WSL)...${NC}"

    # Extraer número de GB
    local mem_gb=$(echo "$memory" | sed 's/GB//')

    # Aplicar a través del daemon
    if wsl-memory-daemon set "$mem_gb" "$processors"; then
        echo -e "${GREEN}✓ Cambios aplicados dinámicamente!${NC}"
        echo "  Memoria: $memory"
        echo "  CPUs: $processors"
        echo ""
        echo -e "${YELLOW}Nota: Los cambios de memoria son inmediatos.${NC}"
        echo -e "${YELLOW}      Los cambios de CPU requieren reiniciar WSL.${NC}"

        # Actualizar también .wslconfig para persistencia
        update_wslconfig "$memory" "$processors" "$profile_name"

        return 0
    else
        echo -e "${RED}✗ Error al aplicar cambios dinámicos${NC}"
        return 1
    fi
}

# Actualizar .wslconfig sin aplicar inmediatamente
update_wslconfig() {
    local memory=$1
    local processors=$2
    local profile_name=$3

    # Backup
    if [ -f "$WSLCONFIG" ]; then
        cp "$WSLCONFIG" "$BACKUP"
    fi

    # Crear nueva configuración
    cat > "$WSLCONFIG" << EOF
[wsl2]
# Perfil: $profile_name - $(date "+%Y-%m-%d %H:%M")
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
EOF
}

# Función para aplicar perfil
apply_profile() {
    local memory=$1
    local processors=$2
    local profile_name=$3

    echo -e "${YELLOW}Aplicando perfil $profile_name...${NC}"

    # Verificar si el daemon está disponible
    if check_daemon; then
        echo ""
        echo -e "${GREEN}✓ Daemon de memoria dinámica detectado!${NC}"
        echo ""
        echo "¿Deseas aplicar los cambios dinámicamente (sin reiniciar)? (S/n): "
        read -r response

        if [ -z "$response" ] || [ "$response" = "s" ] || [ "$response" = "S" ]; then
            # Aplicar dinámicamente
            if apply_dynamic "$memory" "$processors" "$profile_name"; then
                return 0
            fi
            echo -e "${YELLOW}Aplicando método tradicional...${NC}"
        fi
    fi

    # Método tradicional: actualizar config
    update_wslconfig "$memory" "$processors" "$profile_name"

    echo -e "${GREEN}✓ Configuración actualizada${NC}"
    echo -e "${YELLOW}⚠️  Necesitas reiniciar WSL para aplicar los cambios${NC}"
    echo "   Usa: wsl-memory-switch restart"
}

# Función para reiniciar WSL desde Windows
restart_wsl() {
    echo -e "${YELLOW}Reiniciando WSL...${NC}"
    echo "Ejecutando shutdown desde PowerShell..."
    
    # Crear script temporal de PowerShell
    local ps_script="/tmp/restart-wsl.ps1"
    cat > "$ps_script" << 'EOF'
Write-Host "Cerrando WSL..." -ForegroundColor Yellow
wsl --shutdown
Start-Sleep -Seconds 3

Write-Host "Reiniciando servicio..." -ForegroundColor Yellow
Stop-Service LxssManager -Force -ErrorAction SilentlyContinue
Start-Service LxssManager
Start-Sleep -Seconds 2

Write-Host "WSL reiniciado!" -ForegroundColor Green
EOF
    
    # Ejecutar desde PowerShell con permisos elevados
    powershell.exe -ExecutionPolicy Bypass -File "$(wslpath -w "$ps_script")"
    rm -f "$ps_script"
    
    echo -e "${GREEN}✓ WSL reiniciado${NC}"
    echo "Nota: Esta terminal se cerrará. Vuelve a abrir WSL."
}

# Función para mostrar estado
show_status() {
    # Detectar recursos
    local resources=$(get_system_resources)
    local total_ram=$(echo "$resources" | cut -d':' -f1)
    local total_cpus=$(echo "$resources" | cut -d':' -f2)
    local cpu_name=$(echo "$resources" | cut -d':' -f3-)

    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    ESTADO DE WSL                          ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${YELLOW}Sistema:${NC}"
    echo "  CPU:  $cpu_name"
    echo "  RAM:  ${total_ram}GB total"
    echo "  CPUs: ${total_cpus} cores"
    echo
    echo -e "${YELLOW}Configuración actual (.wslconfig):${NC}"
    get_current_profile
    echo
    echo -e "${YELLOW}Estado actual de WSL:${NC}"
    free -h | grep -E "Mem:|Swap:"
    echo "Procesadores disponibles: $(nproc)"
    echo "Uptime: $(uptime -p)"
    echo
    echo -e "${YELLOW}Uso de memoria (top 5):${NC}"
    ps aux --sort=-%mem | head -6 | tail -5
    echo
}

# Función para mostrar perfiles dinámicos
list_profiles() {
    # Detectar recursos
    local resources=$(get_system_resources)
    local total_ram=$(echo "$resources" | cut -d':' -f1)
    local total_cpus=$(echo "$resources" | cut -d':' -f2)

    # Generar perfiles
    local profiles=$(generate_dynamic_profiles "$total_ram" "$total_cpus")

    # Parsear perfiles
    local p1=$(echo "$profiles" | cut -d'|' -f1)
    local p2=$(echo "$profiles" | cut -d'|' -f2)
    local p3=$(echo "$profiles" | cut -d'|' -f3)
    local p4=$(echo "$profiles" | cut -d'|' -f4)
    local p5=$(echo "$profiles" | cut -d'|' -f5)

    local p1_wsl=$(echo "$p1" | cut -d':' -f1)
    local p1_cpu=$(echo "$p1" | cut -d':' -f2)
    local p2_wsl=$(echo "$p2" | cut -d':' -f1)
    local p2_cpu=$(echo "$p2" | cut -d':' -f2)
    local p3_wsl=$(echo "$p3" | cut -d':' -f1)
    local p3_cpu=$(echo "$p3" | cut -d':' -f2)
    local p4_wsl=$(echo "$p4" | cut -d':' -f1)
    local p4_cpu=$(echo "$p4" | cut -d':' -f2)
    local p5_wsl=$(echo "$p5" | cut -d':' -f1)
    local p5_cpu=$(echo "$p5" | cut -d':' -f2)

    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║         PERFILES DISPONIBLES (para tu sistema)           ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${YELLOW}Sistema: ${total_ram}GB RAM | ${total_cpus} CPUs${NC}"
    echo
    echo -e "${RED}[gaming]${NC} - Gaming Mode"
    echo "  ├─ WSL:     ${p1_wsl}GB RAM + ${p1_cpu} CPUs"
    echo "  ├─ Windows: $((total_ram - p1_wsl))GB RAM + $((total_cpus - p1_cpu)) CPUs"
    echo "  └─ Uso: Juegos AAA, streaming, máximo rendimiento Windows"
    echo
    echo -e "${BLUE}[windows-focus]${NC} - Windows Focus"
    echo "  ├─ WSL:     ${p2_wsl}GB RAM + ${p2_cpu} CPUs"
    echo "  ├─ Windows: $((total_ram - p2_wsl))GB RAM + $((total_cpus - p2_cpu)) CPUs"
    echo "  └─ Uso: Edición video, diseño, VMs Windows"
    echo
    echo -e "${YELLOW}[balanced]${NC} - Modo Equilibrado"
    echo "  ├─ WSL:     ${p3_wsl}GB RAM + ${p3_cpu} CPUs"
    echo "  ├─ Windows: $((total_ram - p3_wsl))GB RAM + $((total_cpus - p3_cpu)) CPUs"
    echo "  └─ Uso: Uso mixto, desarrollo + apps Windows"
    echo
    echo -e "${GREEN}[wsl-dev]${NC} - WSL Development"
    echo "  ├─ WSL:     ${p4_wsl}GB RAM + ${p4_cpu} CPUs"
    echo "  ├─ Windows: $((total_ram - p4_wsl))GB RAM + $((total_cpus - p4_cpu)) CPUs"
    echo "  └─ Uso: Desarrollo, Docker, builds medianos"
    echo
    echo -e "${CYAN}[wsl-focus]${NC} - WSL Prioritario"
    echo "  ├─ WSL:     ${p5_wsl}GB RAM + ${p5_cpu} CPUs"
    echo "  ├─ Windows: $((total_ram - p5_wsl))GB RAM + $((total_cpus - p5_cpu)) CPUs"
    echo "  └─ Uso: Desarrollo intensivo, Docker pesado, compilación"
    echo
    echo -e "${MAGENTA}[custom]${NC} - Configuración manual"
    echo "  └─ Especifica valores personalizados"
    echo
}

# Función para mostrar ayuda
show_help() {
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║            WSL Memory Switch CLI - Ayuda                  ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${YELLOW}Control de perfiles de memoria para WSL2 con detección automática${NC}"
    echo
    echo "Uso:"
    echo "  wsl-memory-switch [comando] [opciones]"
    echo
    echo "Comandos:"
    echo "  ${GREEN}apply <perfil>${NC}     Aplicar un perfil predefinido"
    echo "  ${GREEN}custom <mem> <cpu>${NC} Aplicar configuración personalizada"
    echo "  ${GREEN}status${NC}             Mostrar estado actual del sistema"
    echo "  ${GREEN}list${NC}               Listar perfiles disponibles (dinámicos)"
    echo "  ${GREEN}restart${NC}            Reiniciar WSL"
    echo "  ${GREEN}current${NC}            Mostrar configuración actual"
    echo "  ${GREEN}help${NC}               Mostrar esta ayuda"
    echo
    echo "Perfiles disponibles (se calculan según tu RAM):"
    echo "  ${RED}gaming${NC}         Mínimo para WSL, máximo para Windows/juegos"
    echo "  ${BLUE}windows-focus${NC}  Prioridad para Windows (edición, diseño)"
    echo "  ${YELLOW}balanced${NC}       Equilibrado entre Windows y WSL"
    echo "  ${GREEN}wsl-dev${NC}        Prioridad para desarrollo WSL"
    echo "  ${CYAN}wsl-focus${NC}      Máximo para WSL, desarrollo intensivo"
    echo
    echo "Ejemplos:"
    echo "  wsl-memory-switch list            # Ver perfiles para tu sistema"
    echo "  wsl-memory-switch apply balanced  # Aplicar perfil equilibrado"
    echo "  wsl-memory-switch custom 32 16    # 32GB RAM, 16 CPUs personalizados"
    echo "  wsl-memory-switch status          # Ver estado completo"
    echo
    echo "Nota: Los perfiles se calculan automáticamente según tu RAM total"
    echo "      Usa 'list' para ver los valores exactos para tu sistema"
    echo
}

# Función principal
main() {
    # Detectar recursos del sistema
    local resources=$(get_system_resources)
    local total_ram=$(echo "$resources" | cut -d':' -f1)
    local total_cpus=$(echo "$resources" | cut -d':' -f2)

    # Generar perfiles dinámicos
    local profiles=$(generate_dynamic_profiles "$total_ram" "$total_cpus")

    # Parsear perfiles
    local p1=$(echo "$profiles" | cut -d'|' -f1)  # gaming
    local p2=$(echo "$profiles" | cut -d'|' -f2)  # windows-focus
    local p3=$(echo "$profiles" | cut -d'|' -f3)  # balanced
    local p4=$(echo "$profiles" | cut -d'|' -f4)  # wsl-dev
    local p5=$(echo "$profiles" | cut -d'|' -f5)  # wsl-focus

    case "${1:-help}" in
        apply)
            case "$2" in
                gaming)
                    local wsl_ram=$(echo "$p1" | cut -d':' -f1)
                    local wsl_cpu=$(echo "$p1" | cut -d':' -f2)
                    apply_profile "${wsl_ram}GB" "$wsl_cpu" "GAMING"
                    ;;
                windows-focus)
                    local wsl_ram=$(echo "$p2" | cut -d':' -f1)
                    local wsl_cpu=$(echo "$p2" | cut -d':' -f2)
                    apply_profile "${wsl_ram}GB" "$wsl_cpu" "WINDOWS_FOCUS"
                    ;;
                balanced)
                    local wsl_ram=$(echo "$p3" | cut -d':' -f1)
                    local wsl_cpu=$(echo "$p3" | cut -d':' -f2)
                    apply_profile "${wsl_ram}GB" "$wsl_cpu" "BALANCED"
                    ;;
                wsl-dev)
                    local wsl_ram=$(echo "$p4" | cut -d':' -f1)
                    local wsl_cpu=$(echo "$p4" | cut -d':' -f2)
                    apply_profile "${wsl_ram}GB" "$wsl_cpu" "WSL_DEV"
                    ;;
                wsl-focus)
                    local wsl_ram=$(echo "$p5" | cut -d':' -f1)
                    local wsl_cpu=$(echo "$p5" | cut -d':' -f2)
                    apply_profile "${wsl_ram}GB" "$wsl_cpu" "WSL_FOCUS"
                    ;;
                *)
                    echo -e "${RED}Error: Perfil '$2' no reconocido${NC}"
                    echo "Usa 'wsl-memory-switch list' para ver perfiles disponibles"
                    exit 1
                    ;;
            esac
            ;;
        custom)
            if [ -z "$2" ] || [ -z "$3" ]; then
                echo -e "${RED}Error: Debes especificar memoria y CPUs${NC}"
                echo "Ejemplo: wsl-memory-switch custom 32 16"
                echo ""
                echo "Sistema detectado: ${total_ram}GB RAM, ${total_cpus} CPUs"
                echo "Recomendación: Deja al menos 4GB para Windows"
                exit 1
            fi

            # Validar valores con límites dinámicos
            local max_safe_ram=$((total_ram - 4))
            local max_safe_cpu=$((total_cpus - 1))

            if ! [[ "$2" =~ ^[0-9]+$ ]] || [ "$2" -lt 1 ]; then
                echo -e "${RED}Error: Memoria debe ser al menos 1 GB${NC}"
                exit 1
            fi

            if [ "$2" -gt "$total_ram" ]; then
                echo -e "${RED}Error: Memoria solicitada ($2GB) excede RAM total (${total_ram}GB)${NC}"
                exit 1
            fi

            if [ "$2" -gt "$max_safe_ram" ]; then
                echo -e "${YELLOW}⚠ Advertencia: Asignas $2GB a WSL, dejando solo $((total_ram - $2))GB para Windows${NC}"
                echo -e "${YELLOW}  Se recomienda dejar al menos 4GB para Windows${NC}"
                read -p "¿Continuar de todos modos? (s/N): " -r confirm
                if [[ ! $confirm =~ ^[Ss]$ ]]; then
                    echo "Cancelado"
                    exit 0
                fi
            fi

            if ! [[ "$3" =~ ^[0-9]+$ ]] || [ "$3" -lt 1 ]; then
                echo -e "${RED}Error: CPUs debe ser al menos 1${NC}"
                exit 1
            fi

            if [ "$3" -gt "$total_cpus" ]; then
                echo -e "${RED}Error: CPUs solicitados ($3) excede CPUs totales (${total_cpus})${NC}"
                exit 1
            fi

            if [ "$3" -gt "$max_safe_cpu" ]; then
                echo -e "${YELLOW}⚠ Advertencia: Asignas $3 CPUs a WSL, dejando solo $((total_cpus - $3)) para Windows${NC}"
            fi

            apply_profile "${2}GB" "$3" "CUSTOM"
            ;;
        status)
            show_status
            ;;
        list)
            list_profiles
            ;;
        restart)
            restart_wsl
            ;;
        current)
            echo -e "${CYAN}Configuración actual:${NC}"
            get_current_profile
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}Comando no reconocido: $1${NC}"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Ejecutar función principal
main "$@"