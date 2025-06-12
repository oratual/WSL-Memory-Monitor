#!/bin/bash
# WSL Memory Switch CLI - Control de perfiles de memoria desde Linux

# Configuración
WSLCONFIG="/mnt/c/Users/lauta/.wslconfig"
BACKUP="/mnt/c/Users/lauta/.wslconfig.backup"
PROFILES_FILE="$(dirname "$0")/wsl-memory-profiles.conf"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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

# Función para aplicar perfil
apply_profile() {
    local memory=$1
    local processors=$2
    local profile_name=$3
    
    echo -e "${YELLOW}Aplicando perfil $profile_name...${NC}"
    
    # Backup
    if [ -f "$WSLCONFIG" ]; then
        cp "$WSLCONFIG" "$BACKUP"
        echo "Backup creado en: $BACKUP"
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
    
    echo -e "${GREEN}✓ Configuración actualizada${NC}"
    echo -e "${YELLOW}⚠️  Necesitas reiniciar WSL para aplicar los cambios${NC}"
    echo "   Usa: wsl-memory-switch --restart"
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
    echo -e "${CYAN}=== ESTADO DE WSL ===${NC}"
    echo
    echo -e "${YELLOW}Configuración actual:${NC}"
    get_current_profile
    echo
    echo -e "${YELLOW}Recursos del sistema:${NC}"
    echo "RAM Total del sistema: 64GB"
    echo "CPUs totales: 24 (Ryzen 9 5900X)"
    echo
    echo -e "${YELLOW}Estado actual de WSL:${NC}"
    free -h | grep -E "Mem:|Swap:"
    echo "Procesadores disponibles: $(nproc)"
    echo "Uptime: $(uptime -p)"
    echo
    echo -e "${YELLOW}Uso de memoria:${NC}"
    ps aux --sort=-%mem | head -5
}

# Función para mostrar perfiles
list_profiles() {
    echo -e "${CYAN}=== PERFILES DISPONIBLES ===${NC}"
    echo
    echo -e "${RED}[gaming]${NC} - Gaming Mode"
    echo "  └─ WSL: 8GB RAM + 4 CPUs"
    echo "  └─ Windows: 56GB RAM + 20 CPUs disponibles"
    echo
    echo -e "${YELLOW}[balanced]${NC} - Modo Equilibrado"
    echo "  └─ WSL: 24GB RAM + 12 CPUs"
    echo "  └─ Windows: 40GB RAM + 12 CPUs disponibles"
    echo
    echo -e "${GREEN}[wsl-focus]${NC} - WSL Prioritario"
    echo "  └─ WSL: 48GB RAM + 20 CPUs"
    echo "  └─ Windows: 16GB RAM + 4 CPUs disponibles"
    echo
    echo -e "${BLUE}[windows-focus]${NC} - Windows Prioritario"
    echo "  └─ WSL: 16GB RAM + 8 CPUs"
    echo "  └─ Windows: 48GB RAM + 16 CPUs disponibles"
}

# Función para mostrar ayuda
show_help() {
    echo -e "${CYAN}WSL Memory Switch CLI${NC}"
    echo "Control de perfiles de memoria para WSL2"
    echo
    echo "Uso:"
    echo "  wsl-memory-switch [comando] [opciones]"
    echo
    echo "Comandos:"
    echo "  apply <perfil>     Aplicar un perfil predefinido"
    echo "  custom <mem> <cpu> Aplicar configuración personalizada"
    echo "  status             Mostrar estado actual"
    echo "  list               Listar perfiles disponibles"
    echo "  restart            Reiniciar WSL"
    echo "  current            Mostrar configuración actual"
    echo "  help               Mostrar esta ayuda"
    echo
    echo "Perfiles disponibles:"
    echo "  gaming         8GB RAM, 4 CPUs"
    echo "  balanced       24GB RAM, 12 CPUs"
    echo "  wsl-focus      48GB RAM, 20 CPUs"
    echo "  windows-focus  16GB RAM, 8 CPUs"
    echo
    echo "Ejemplos:"
    echo "  wsl-memory-switch apply gaming"
    echo "  wsl-memory-switch custom 32 16"
    echo "  wsl-memory-switch status"
}

# Función principal
main() {
    case "${1:-help}" in
        apply)
            case "$2" in
                gaming)
                    apply_profile "8GB" 4 "GAMING"
                    ;;
                balanced)
                    apply_profile "24GB" 12 "BALANCED"
                    ;;
                wsl-focus)
                    apply_profile "48GB" 20 "WSL_FOCUS"
                    ;;
                windows-focus)
                    apply_profile "16GB" 8 "WINDOWS_FOCUS"
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
                exit 1
            fi
            # Validar valores
            if ! [[ "$2" =~ ^[0-9]+$ ]] || [ "$2" -lt 1 ] || [ "$2" -gt 60 ]; then
                echo -e "${RED}Error: Memoria debe ser entre 1 y 60 GB${NC}"
                exit 1
            fi
            if ! [[ "$3" =~ ^[0-9]+$ ]] || [ "$3" -lt 1 ] || [ "$3" -gt 24 ]; then
                echo -e "${RED}Error: CPUs debe ser entre 1 y 24${NC}"
                exit 1
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
            show_help
            exit 1
            ;;
    esac
}

# Ejecutar función principal
main "$@"