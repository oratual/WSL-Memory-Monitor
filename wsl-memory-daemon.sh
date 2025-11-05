#!/bin/bash
# WSL Memory Daemon - Ajuste dinámico de memoria sin reiniciar WSL
# Este daemon monitorea cambios en la configuración y aplica límites de memoria
# usando cgroups v2 en tiempo real

DAEMON_NAME="wsl-memory-daemon"
PID_FILE="/tmp/${DAEMON_NAME}.pid"
CONFIG_FILE="/tmp/wsl-memory-dynamic.conf"
LOG_FILE="/tmp/${DAEMON_NAME}.log"
LOCK_FILE="/tmp/${DAEMON_NAME}.lock"

# Colores para logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función de logging
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[${timestamp}] [${level}] ${message}" | tee -a "$LOG_FILE"
}

log_info() {
    log "INFO" "${GREEN}$@${NC}"
}

log_warn() {
    log "WARN" "${YELLOW}$@${NC}"
}

log_error() {
    log "ERROR" "${RED}$@${NC}"
}

# Verificar si el daemon ya está corriendo
check_running() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            return 0  # Ya está corriendo
        else
            # PID file obsoleto, eliminarlo
            rm -f "$PID_FILE"
        fi
    fi
    return 1  # No está corriendo
}

# Detener el daemon
stop_daemon() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        log_info "Deteniendo daemon (PID: $pid)..."
        kill "$pid" 2>/dev/null

        # Esperar a que termine
        local count=0
        while kill -0 "$pid" 2>/dev/null && [ $count -lt 10 ]; do
            sleep 0.5
            count=$((count + 1))
        done

        if kill -0 "$pid" 2>/dev/null; then
            log_warn "Daemon no responde, forzando cierre..."
            kill -9 "$pid" 2>/dev/null
        fi

        rm -f "$PID_FILE" "$LOCK_FILE"
        log_info "Daemon detenido"
        return 0
    else
        log_warn "Daemon no está corriendo"
        return 1
    fi
}

# Obtener total de memoria del sistema en bytes
get_total_memory() {
    local mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    echo $((mem_kb * 1024))
}

# Obtener número de CPUs
get_total_cpus() {
    nproc
}

# Convertir GB a bytes
gb_to_bytes() {
    local gb=$1
    echo $(( gb * 1024 * 1024 * 1024 ))
}

# Aplicar límite de memoria usando cgroups v2
apply_memory_limit() {
    local limit_bytes=$1

    log_info "Aplicando límite de memoria: $(( limit_bytes / 1024 / 1024 / 1024 )) GB"

    # Verificar si cgroups v2 está disponible
    if [ ! -d "/sys/fs/cgroup/memory" ] && [ ! -f "/sys/fs/cgroup/cgroup.controllers" ]; then
        log_warn "cgroups no está disponible en este sistema"
        return 1
    fi

    # Intentar usar cgroups v2
    if [ -f "/sys/fs/cgroup/cgroup.controllers" ]; then
        # cgroups v2
        local cgroup_path="/sys/fs/cgroup/user.slice"

        if [ -w "${cgroup_path}/memory.max" ]; then
            echo "$limit_bytes" > "${cgroup_path}/memory.max" 2>/dev/null
            if [ $? -eq 0 ]; then
                log_info "✓ Límite de memoria aplicado exitosamente (cgroups v2)"
                return 0
            fi
        fi
    fi

    # Intentar cgroups v1 como fallback
    if [ -d "/sys/fs/cgroup/memory" ]; then
        local cgroup_path="/sys/fs/cgroup/memory"

        if [ -w "${cgroup_path}/memory.limit_in_bytes" ]; then
            echo "$limit_bytes" > "${cgroup_path}/memory.limit_in_bytes" 2>/dev/null
            if [ $? -eq 0 ]; then
                log_info "✓ Límite de memoria aplicado exitosamente (cgroups v1)"
                return 0
            fi
        fi
    fi

    log_warn "No se pudo aplicar límite de memoria. Se requieren permisos especiales."
    log_info "Nota: Los límites dinámicos funcionan mejor con systemd-run o permisos root"
    return 1
}

# Aplicar límite de CPUs usando cpuset
apply_cpu_limit() {
    local num_cpus=$1
    local total_cpus=$(get_total_cpus)

    if [ $num_cpus -gt $total_cpus ]; then
        num_cpus=$total_cpus
    fi

    log_info "Configurando límite de CPUs: $num_cpus de $total_cpus"

    # Crear lista de CPUs (0 a num_cpus-1)
    local cpu_list="0-$((num_cpus - 1))"

    # Intentar aplicar usando taskset a procesos existentes
    # Esto es una simulación ya que el límite real viene de .wslconfig
    # Pero podemos ajustar la afinidad de CPU de procesos pesados

    log_info "CPUs configuradas: $cpu_list"
    log_info "Nota: Los límites de CPU se aplican mejor vía .wslconfig"

    return 0
}

# Leer configuración del archivo
read_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        return 1
    fi

    # Leer valores del archivo de configuración
    # Formato: MEMORY_GB=32\nCPUS=16
    source "$CONFIG_FILE" 2>/dev/null

    if [ -n "$MEMORY_GB" ] && [ -n "$CPUS" ]; then
        return 0
    fi

    return 1
}

# Aplicar configuración actual
apply_current_config() {
    if read_config; then
        log_info "Aplicando configuración: ${MEMORY_GB}GB RAM, ${CPUS} CPUs"

        local mem_bytes=$(gb_to_bytes $MEMORY_GB)
        apply_memory_limit $mem_bytes
        apply_cpu_limit $CPUS

        return 0
    else
        log_warn "No hay configuración para aplicar"
        return 1
    fi
}

# Monitorear cambios en la configuración
monitor_config() {
    local last_config=""
    local check_interval=5  # Segundos entre chequeos

    log_info "Iniciando monitoreo de configuración..."
    log_info "Intervalo de chequeo: ${check_interval}s"

    while true; do
        # Verificar si se debe detener el daemon
        if [ ! -f "$PID_FILE" ]; then
            log_info "PID file eliminado, deteniendo daemon..."
            break
        fi

        # Leer configuración actual
        if [ -f "$CONFIG_FILE" ]; then
            local current_config=$(cat "$CONFIG_FILE")

            # Si la configuración cambió, aplicarla
            if [ "$current_config" != "$last_config" ]; then
                log_info "Detectado cambio en la configuración"
                apply_current_config
                last_config="$current_config"
            fi
        fi

        sleep $check_interval
    done
}

# Función principal del daemon
start_daemon() {
    # Verificar si ya está corriendo
    if check_running; then
        log_error "El daemon ya está corriendo (PID: $(cat $PID_FILE))"
        exit 1
    fi

    # Crear archivo de log
    touch "$LOG_FILE"

    log_info "=========================================="
    log_info "Iniciando $DAEMON_NAME"
    log_info "=========================================="

    # Verificar capacidades del sistema
    log_info "Verificando sistema..."
    log_info "Memoria total: $(( $(get_total_memory) / 1024 / 1024 / 1024 )) GB"
    log_info "CPUs totales: $(get_total_cpus)"

    # Verificar cgroups
    if [ -f "/sys/fs/cgroup/cgroup.controllers" ]; then
        log_info "✓ cgroups v2 detectado"
    elif [ -d "/sys/fs/cgroup/memory" ]; then
        log_info "✓ cgroups v1 detectado"
    else
        log_warn "⚠ cgroups no detectado - funcionalidad limitada"
    fi

    # Crear archivo PID
    echo $$ > "$PID_FILE"
    log_info "Daemon iniciado con PID: $$"

    # Configuración inicial si existe
    if [ -f "$CONFIG_FILE" ]; then
        log_info "Aplicando configuración inicial..."
        apply_current_config
    else
        log_info "No hay configuración inicial, esperando comandos..."
    fi

    # Iniciar monitoreo
    monitor_config

    # Limpieza al salir
    rm -f "$PID_FILE" "$LOCK_FILE"
    log_info "Daemon detenido"
}

# Establecer configuración desde línea de comandos
set_config() {
    local memory_gb=$1
    local cpus=$2

    if [ -z "$memory_gb" ] || [ -z "$cpus" ]; then
        echo "Uso: $0 set <memory_gb> <cpus>"
        return 1
    fi

    # Validar valores
    if ! [[ "$memory_gb" =~ ^[0-9]+$ ]] || [ "$memory_gb" -lt 1 ]; then
        echo "Error: Memoria debe ser un número positivo"
        return 1
    fi

    if ! [[ "$cpus" =~ ^[0-9]+$ ]] || [ "$cpus" -lt 1 ]; then
        echo "Error: CPUs debe ser un número positivo"
        return 1
    fi

    # Escribir configuración
    cat > "$CONFIG_FILE" << EOF
MEMORY_GB=$memory_gb
CPUS=$cpus
EOF

    echo -e "${GREEN}✓ Configuración actualizada: ${memory_gb}GB RAM, ${cpus} CPUs${NC}"

    # Si el daemon está corriendo, los cambios se aplicarán automáticamente
    if check_running; then
        echo "El daemon aplicará los cambios en los próximos segundos..."
    else
        echo -e "${YELLOW}⚠ El daemon no está corriendo. Inícialo con: $0 start${NC}"
    fi

    return 0
}

# Mostrar estado
show_status() {
    echo "=========================================="
    echo "Estado de WSL Memory Daemon"
    echo "=========================================="

    if check_running; then
        local pid=$(cat "$PID_FILE")
        echo -e "${GREEN}Estado: RUNNING${NC}"
        echo "PID: $pid"
    else
        echo -e "${RED}Estado: STOPPED${NC}"
    fi

    echo ""

    if [ -f "$CONFIG_FILE" ]; then
        echo "Configuración actual:"
        source "$CONFIG_FILE"
        echo "  Memoria: ${MEMORY_GB:-N/A} GB"
        echo "  CPUs: ${CPUS:-N/A}"
    else
        echo "Sin configuración"
    fi

    echo ""
    echo "Sistema:"
    echo "  Memoria total: $(( $(get_total_memory) / 1024 / 1024 / 1024 )) GB"
    echo "  CPUs totales: $(get_total_cpus)"
    echo "  Memoria en uso: $(free -h | grep Mem | awk '{print $3 " / " $2}')"

    if [ -f "$LOG_FILE" ]; then
        echo ""
        echo "Últimas líneas del log:"
        tail -n 5 "$LOG_FILE"
    fi
}

# Mostrar ayuda
show_help() {
    cat << EOF
WSL Memory Daemon - Control dinámico de memoria sin reiniciar WSL

Uso: $0 [comando] [opciones]

Comandos:
  start               Iniciar el daemon
  stop                Detener el daemon
  restart             Reiniciar el daemon
  status              Mostrar estado del daemon
  set <gb> <cpus>     Configurar memoria y CPUs
  logs                Mostrar logs del daemon
  help                Mostrar esta ayuda

Ejemplos:
  $0 start                  # Iniciar daemon
  $0 set 32 16              # Configurar 32GB RAM y 16 CPUs
  $0 status                 # Ver estado
  $0 logs                   # Ver logs
  $0 stop                   # Detener daemon

Notas:
  - El daemon aplica cambios de memoria sin reiniciar WSL
  - Los cambios se aplican usando cgroups v2
  - Requiere permisos especiales para límites estrictos
  - Los límites de CPU son informativos (el límite real viene de .wslconfig)

EOF
}

# Programa principal
case "${1:-help}" in
    start)
        start_daemon
        ;;
    stop)
        stop_daemon
        ;;
    restart)
        stop_daemon
        sleep 1
        start_daemon
        ;;
    status)
        show_status
        ;;
    set)
        set_config "$2" "$3"
        ;;
    logs)
        if [ -f "$LOG_FILE" ]; then
            tail -f "$LOG_FILE"
        else
            echo "No hay logs disponibles"
        fi
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "Comando no reconocido: $1"
        show_help
        exit 1
        ;;
esac
