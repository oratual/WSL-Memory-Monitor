#!/bin/bash
# Instalador del daemon de memoria dinámica para WSL

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                                                            ║${NC}"
echo -e "${CYAN}║      WSL MEMORY DAEMON - INSTALADOR                        ║${NC}"
echo -e "${CYAN}║      Gestión dinámica de memoria sin reiniciar WSL        ║${NC}"
echo -e "${CYAN}║                                                            ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Verificar si estamos en WSL
if [ ! -f /proc/sys/fs/binfmt_misc/WSLInterop ]; then
    echo -e "${RED}✗ Este script debe ejecutarse dentro de WSL${NC}"
    exit 1
fi

echo -e "${YELLOW}[1/6]${NC} Verificando permisos..."

# Verificar si somos root o tenemos sudo
if [ "$EUID" -ne 0 ]; then
    if ! command -v sudo &> /dev/null; then
        echo -e "${RED}✗ Se requieren permisos de root o sudo${NC}"
        exit 1
    fi
    SUDO="sudo"
    echo -e "${GREEN}✓ sudo disponible${NC}"
else
    SUDO=""
    echo -e "${GREEN}✓ Ejecutando como root${NC}"
fi

# Obtener directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo -e "${GREEN}✓ Directorio de instalación: $SCRIPT_DIR${NC}"

echo ""
echo -e "${YELLOW}[2/6]${NC} Verificando dependencias..."

# Verificar bash
if ! command -v bash &> /dev/null; then
    echo -e "${RED}✗ bash no encontrado${NC}"
    exit 1
fi
echo -e "${GREEN}✓ bash disponible${NC}"

# Verificar herramientas necesarias
MISSING_TOOLS=""
for tool in grep awk free nproc; do
    if ! command -v $tool &> /dev/null; then
        MISSING_TOOLS="$MISSING_TOOLS $tool"
    fi
done

if [ -n "$MISSING_TOOLS" ]; then
    echo -e "${YELLOW}⚠ Herramientas faltantes:$MISSING_TOOLS${NC}"
    echo "Instalando..."
    $SUDO apt-get update -qq
    $SUDO apt-get install -y -qq procps coreutils grep gawk
fi
echo -e "${GREEN}✓ Todas las dependencias satisfechas${NC}"

echo ""
echo -e "${YELLOW}[3/6]${NC} Verificando systemd..."

# Verificar si systemd está disponible
if command -v systemctl &> /dev/null && systemctl is-system-running &>/dev/null; then
    HAS_SYSTEMD=true
    echo -e "${GREEN}✓ systemd detectado${NC}"
else
    HAS_SYSTEMD=false
    echo -e "${YELLOW}⚠ systemd no disponible${NC}"
    echo "  El daemon se instalará en modo manual"
fi

echo ""
echo -e "${YELLOW}[4/6]${NC} Instalando daemon..."

# Hacer ejecutable el daemon
chmod +x "$SCRIPT_DIR/wsl-memory-daemon.sh"
echo -e "${GREEN}✓ Daemon marcado como ejecutable${NC}"

# Copiar daemon a /usr/local/bin
$SUDO cp "$SCRIPT_DIR/wsl-memory-daemon.sh" /usr/local/bin/wsl-memory-daemon
$SUDO chmod +x /usr/local/bin/wsl-memory-daemon
echo -e "${GREEN}✓ Daemon instalado en /usr/local/bin/wsl-memory-daemon${NC}"

echo ""
echo -e "${YELLOW}[5/6]${NC} Configurando servicio..."

if [ "$HAS_SYSTEMD" = true ]; then
    # Instalar servicio systemd
    $SUDO cp "$SCRIPT_DIR/wsl-memory-daemon.service" /etc/systemd/system/
    $SUDO systemctl daemon-reload
    echo -e "${GREEN}✓ Servicio systemd instalado${NC}"

    # Preguntar si habilitar auto-inicio
    echo ""
    read -p "¿Deseas habilitar el daemon para que inicie automáticamente? (S/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]] || [[ -z $REPLY ]]; then
        $SUDO systemctl enable wsl-memory-daemon.service
        echo -e "${GREEN}✓ Servicio habilitado para inicio automático${NC}"
    fi

    # Preguntar si iniciar ahora
    echo ""
    read -p "¿Deseas iniciar el daemon ahora? (S/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]] || [[ -z $REPLY ]]; then
        $SUDO systemctl start wsl-memory-daemon.service
        sleep 1

        if $SUDO systemctl is-active --quiet wsl-memory-daemon.service; then
            echo -e "${GREEN}✓ Daemon iniciado exitosamente${NC}"
        else
            echo -e "${YELLOW}⚠ Error al iniciar el daemon${NC}"
            echo "Ver logs con: sudo journalctl -u wsl-memory-daemon -n 50"
        fi
    fi
else
    echo -e "${YELLOW}⚠ Sin systemd, configuración manual${NC}"
    echo ""
    echo "Para iniciar el daemon manualmente:"
    echo "  wsl-memory-daemon start"
    echo ""
    echo "Para auto-inicio, agrega a tu ~/.bashrc:"
    echo "  # Iniciar WSL Memory Daemon"
    echo "  if [ ! -f /tmp/wsl-memory-daemon.pid ]; then"
    echo "      wsl-memory-daemon start &>/dev/null &"
    echo "  fi"
fi

echo ""
echo -e "${YELLOW}[6/6]${NC} Verificando cgroups..."

# Verificar soporte de cgroups
if [ -f "/sys/fs/cgroup/cgroup.controllers" ]; then
    echo -e "${GREEN}✓ cgroups v2 disponible${NC}"
    CGROUPS_VERSION=2
elif [ -d "/sys/fs/cgroup/memory" ]; then
    echo -e "${GREEN}✓ cgroups v1 disponible${NC}"
    CGROUPS_VERSION=1
else
    echo -e "${YELLOW}⚠ cgroups no detectado${NC}"
    echo "  La funcionalidad puede estar limitada"
    CGROUPS_VERSION=0
fi

# Verificar permisos de escritura en cgroups
if [ $CGROUPS_VERSION -gt 0 ]; then
    CGROUP_WRITABLE=false

    if [ $CGROUPS_VERSION -eq 2 ]; then
        if [ -w "/sys/fs/cgroup/user.slice/memory.max" ] 2>/dev/null; then
            CGROUP_WRITABLE=true
        fi
    elif [ $CGROUPS_VERSION -eq 1 ]; then
        if [ -w "/sys/fs/cgroup/memory/memory.limit_in_bytes" ] 2>/dev/null; then
            CGROUP_WRITABLE=true
        fi
    fi

    if [ "$CGROUP_WRITABLE" = true ]; then
        echo -e "${GREEN}✓ Permisos de escritura en cgroups OK${NC}"
    else
        echo -e "${YELLOW}⚠ Sin permisos de escritura en cgroups${NC}"
        echo "  Para límites estrictos, ejecuta el daemon con sudo"
    fi
fi

# Resumen final
echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Instalación completada exitosamente!${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Comandos disponibles:"
echo ""
echo -e "  ${BLUE}wsl-memory-daemon status${NC}      Ver estado del daemon"
echo -e "  ${BLUE}wsl-memory-daemon set 32 16${NC}   Configurar 32GB RAM, 16 CPUs"
echo -e "  ${BLUE}wsl-memory-daemon logs${NC}        Ver logs en tiempo real"

if [ "$HAS_SYSTEMD" = true ]; then
    echo ""
    echo "Comandos systemd:"
    echo -e "  ${BLUE}sudo systemctl start wsl-memory-daemon${NC}     Iniciar servicio"
    echo -e "  ${BLUE}sudo systemctl stop wsl-memory-daemon${NC}      Detener servicio"
    echo -e "  ${BLUE}sudo systemctl status wsl-memory-daemon${NC}    Ver estado"
    echo -e "  ${BLUE}sudo journalctl -u wsl-memory-daemon -f${NC}    Ver logs"
fi

echo ""
echo "Integración con Windows:"
echo "  El daemon permite cambiar la memoria sin reiniciar WSL"
echo "  Usa los scripts de PowerShell como siempre"
echo "  Los cambios se aplicarán inmediatamente (sin reinicio)"
echo ""
echo -e "${YELLOW}Nota:${NC} Los límites de CPU siguen requiriendo .wslconfig"
echo "      pero la memoria se puede ajustar dinámicamente"
echo ""
