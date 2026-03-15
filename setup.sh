#!/usr/bin/env bash
# =============================================================================
# LibreTime Multi-Station - Script de Configuración
# EstacionKusMedios Digital
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# =============================================================================
# Verificar prerequisitos
# =============================================================================
check_prerequisites() {
    log_info "Verificando prerequisitos..."

    if ! command -v docker &> /dev/null; then
        log_error "Docker no está instalado. Instálalo desde https://docs.docker.com/get-docker/"
        exit 1
    fi
    log_ok "Docker encontrado: $(docker --version)"

    if docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
        log_ok "Docker Compose (plugin) encontrado: $(docker compose version --short)"
    elif command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
        log_ok "Docker Compose (standalone) encontrado: $(docker-compose --version)"
    else
        log_error "Docker Compose no está instalado."
        exit 1
    fi

    if ! command -v envsubst &> /dev/null; then
        log_error "envsubst no está instalado. Instálalo con: sudo apt-get install gettext-base"
        exit 1
    fi
    log_ok "envsubst encontrado"

    echo ""
}

# =============================================================================
# Generar contraseña aleatoria
# =============================================================================
generate_password() {
    local length="${1:-32}"
    head -c 256 /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | head -c "$length"
}

# =============================================================================
# Generar archivo .env
# =============================================================================
generate_env() {
    if [ -f .env ]; then
        log_warn "El archivo .env ya existe."
        read -rp "¿Deseas sobrescribirlo? (s/N): " overwrite
        if [[ ! "$overwrite" =~ ^[sS]$ ]]; then
            log_info "Usando .env existente."
            return
        fi
    fi

    log_info "Generando contraseñas aleatorias..."

    cat > .env << EOF
# =============================================================================
# LibreTime Multi-Station - EstacionKusMedios Digital
# Generado automáticamente por setup.sh el $(date '+%Y-%m-%d %H:%M:%S')
# =============================================================================

# Versión de LibreTime
LIBRETIME_VERSION=4.5.0

# =============================================================================
# Estación 1: Runaradio
# =============================================================================
RUNARADIO_POSTGRES_PASSWORD=$(generate_password)
RUNARADIO_RABBITMQ_PASS=$(generate_password)
RUNARADIO_ICECAST_SOURCE_PASSWORD=$(generate_password 16)
RUNARADIO_ICECAST_ADMIN_PASSWORD=$(generate_password 16)
RUNARADIO_ICECAST_RELAY_PASSWORD=$(generate_password 16)
RUNARADIO_API_KEY=$(generate_password 32)
RUNARADIO_SECRET_KEY=$(generate_password 48)
RUNARADIO_PUBLIC_URL=http://localhost:8081

# =============================================================================
# Estación 2: EstacionKusFM
# =============================================================================
ESTACIONKUSFM_POSTGRES_PASSWORD=$(generate_password)
ESTACIONKUSFM_RABBITMQ_PASS=$(generate_password)
ESTACIONKUSFM_ICECAST_SOURCE_PASSWORD=$(generate_password 16)
ESTACIONKUSFM_ICECAST_ADMIN_PASSWORD=$(generate_password 16)
ESTACIONKUSFM_ICECAST_RELAY_PASSWORD=$(generate_password 16)
ESTACIONKUSFM_API_KEY=$(generate_password 32)
ESTACIONKUSFM_SECRET_KEY=$(generate_password 48)
ESTACIONKUSFM_PUBLIC_URL=http://localhost:8082

# =============================================================================
# Estación 3: RadioAventuraMX
# =============================================================================
RADIOAVENTURAMX_POSTGRES_PASSWORD=$(generate_password)
RADIOAVENTURAMX_RABBITMQ_PASS=$(generate_password)
RADIOAVENTURAMX_ICECAST_SOURCE_PASSWORD=$(generate_password 16)
RADIOAVENTURAMX_ICECAST_ADMIN_PASSWORD=$(generate_password 16)
RADIOAVENTURAMX_ICECAST_RELAY_PASSWORD=$(generate_password 16)
RADIOAVENTURAMX_API_KEY=$(generate_password 32)
RADIOAVENTURAMX_SECRET_KEY=$(generate_password 48)
RADIOAVENTURAMX_PUBLIC_URL=http://localhost:8083
EOF

    log_ok "Archivo .env generado con contraseñas aleatorias."
    echo ""
}

# =============================================================================
# Generar archivos config.yml para cada estación
# =============================================================================
generate_configs() {
    log_info "Generando archivos config.yml para cada estación..."

    # Cargar variables de entorno
    set -a
    # shellcheck disable=SC1091
    source .env
    set +a

    local stations=("runaradio" "estacionkusfm" "radioaventuramx")

    for station in "${stations[@]}"; do
        local tmpl="stations/${station}/config.yml.tmpl"
        local out="stations/${station}/config.yml"

        if [ ! -f "$tmpl" ]; then
            log_error "Plantilla no encontrada: $tmpl"
            exit 1
        fi

        envsubst < "$tmpl" > "$out"
        log_ok "Generado: $out"
    done

    echo ""
}

# =============================================================================
# Ejecutar migraciones de base de datos
# =============================================================================
run_migrations() {
    log_info "Iniciando bases de datos para migraciones..."

    local stations=("runaradio" "estacionkusfm" "radioaventuramx")

    # Iniciar solo los servicios de postgres
    for station in "${stations[@]}"; do
        $COMPOSE_CMD --profile "$station" up -d "${station}-postgres"
    done

    log_info "Esperando a que PostgreSQL esté listo..."
    sleep 10

    for station in "${stations[@]}"; do
        log_info "Ejecutando migraciones para ${station}..."
        $COMPOSE_CMD --profile "$station" run --rm "${station}-api" libretime-api migrate
        log_ok "Migraciones completadas para ${station}"
    done

    echo ""
}

# =============================================================================
# Iniciar todos los servicios
# =============================================================================
start_services() {
    log_info "Iniciando todos los servicios..."
    $COMPOSE_CMD --profile runaradio --profile estacionkusfm --profile radioaventuramx up -d
    log_ok "Todos los servicios iniciados."
    echo ""
}

# =============================================================================
# Mostrar estado y URLs
# =============================================================================
show_status() {
    echo ""
    echo -e "${GREEN}=============================================================================${NC}"
    echo -e "${GREEN} EstacionKusMedios Digital - Configuración Completada${NC}"
    echo -e "${GREEN}=============================================================================${NC}"
    echo ""
    echo -e "${BLUE}Página principal:${NC}"
    echo "  http://localhost:80"
    echo ""
    echo -e "${BLUE}Estaciones:${NC}"
    echo ""
    echo "  Runaradio:"
    echo "    Web:     http://localhost:8081"
    echo "    Icecast: http://localhost:8010"
    echo "    Stream:  http://localhost:8010/main"
    echo ""
    echo "  EstacionKusFM:"
    echo "    Web:     http://localhost:8082"
    echo "    Icecast: http://localhost:8020"
    echo "    Stream:  http://localhost:8020/main"
    echo ""
    echo "  RadioAventuraMX:"
    echo "    Web:     http://localhost:8083"
    echo "    Icecast: http://localhost:8030"
    echo "    Stream:  http://localhost:8030/main"
    echo ""
    echo -e "${BLUE}Vía proxy reverso:${NC}"
    echo "  http://localhost/runaradio/"
    echo "  http://localhost/estacionkusfm/"
    echo "  http://localhost/radioaventuramx/"
    echo ""
    echo -e "${YELLOW}Credenciales por defecto de LibreTime:${NC}"
    echo "  Usuario: admin"
    echo "  Contraseña: admin"
    echo ""
    echo -e "${YELLOW}IMPORTANTE: Cambia la contraseña de admin después del primer inicio de sesión.${NC}"
    echo ""
    echo -e "${BLUE}Comandos útiles:${NC}"
    echo "  Ver estado:           ./scripts/status.sh"
    echo "  Respaldo:             ./scripts/backup.sh"
    echo "  Detener todo:         docker compose --profile runaradio --profile estacionkusfm --profile radioaventuramx down"
    echo "  Solo una estación:    docker compose --profile runaradio up -d"
    echo ""
}

# =============================================================================
# Ejecución principal
# =============================================================================
main() {
    echo ""
    echo -e "${GREEN}=============================================================================${NC}"
    echo -e "${GREEN} LibreTime Multi-Station - Setup${NC}"
    echo -e "${GREEN} EstacionKusMedios Digital${NC}"
    echo -e "${GREEN}=============================================================================${NC}"
    echo ""

    check_prerequisites
    generate_env
    generate_configs
    run_migrations
    start_services
    show_status
}

main "$@"
