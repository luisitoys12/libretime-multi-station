#!/usr/bin/env bash
# =============================================================================
# LibreTime Multi-Station - Ejecutar Migraciones
# EstacionKusMedios Digital
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Detectar Docker Compose
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
else
    log_error "Docker Compose no encontrado."
    exit 1
fi

STATIONS=("runaradio" "estacionkusfm" "radioaventuramx")

# Si se pasa un argumento, solo migrar esa estación
if [ $# -gt 0 ]; then
    STATIONS=("$1")
fi

for station in "${STATIONS[@]}"; do
    log_info "Ejecutando migraciones para ${station}..."

    # Asegurar que postgres está corriendo
    $COMPOSE_CMD --profile "$station" up -d "${station}-postgres"

    # Esperar a que esté listo
    log_info "Esperando a que PostgreSQL de ${station} esté listo..."
    for i in $(seq 1 30); do
        if $COMPOSE_CMD --profile "$station" exec "${station}-postgres" pg_isready -U libretime &> /dev/null; then
            break
        fi
        sleep 1
    done

    # Ejecutar migraciones
    $COMPOSE_CMD --profile "$station" run --rm "${station}-api" libretime-api migrate

    log_ok "Migraciones completadas para ${station}"
done

log_ok "Todas las migraciones completadas."
