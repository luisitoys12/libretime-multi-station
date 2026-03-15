#!/usr/bin/env bash
# =============================================================================
# LibreTime Multi-Station - Respaldo de Bases de Datos
# EstacionKusMedios Digital
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
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

# Directorio de respaldos
BACKUP_DIR="${PROJECT_DIR}/backups"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
BACKUP_PATH="${BACKUP_DIR}/${TIMESTAMP}"

mkdir -p "$BACKUP_PATH"

STATIONS=("runaradio" "estacionkusfm" "radioaventuramx")

# Si se pasa un argumento, solo respaldar esa estación
if [ $# -gt 0 ]; then
    STATIONS=("$1")
fi

log_info "Iniciando respaldo en: ${BACKUP_PATH}"
echo ""

for station in "${STATIONS[@]}"; do
    log_info "Respaldando base de datos de ${station}..."

    BACKUP_FILE="${BACKUP_PATH}/${station}_db.sql.gz"

    if $COMPOSE_CMD --profile "$station" exec -T "${station}-postgres" \
        pg_dump -U libretime libretime 2>/dev/null | gzip > "$BACKUP_FILE"; then
        local_size=$(du -h "$BACKUP_FILE" | cut -f1)
        log_ok "Respaldo de ${station}: ${BACKUP_FILE} (${local_size})"
    else
        log_error "Error al respaldar ${station}. ¿Está corriendo el contenedor?"
    fi
done

echo ""
log_ok "Respaldo completado en: ${BACKUP_PATH}"
echo ""
echo -e "${YELLOW}Para restaurar una base de datos:${NC}"
echo "  gunzip -c backups/${TIMESTAMP}/<estacion>_db.sql.gz | \\"
echo "    docker compose --profile <estacion> exec -T <estacion>-postgres psql -U libretime libretime"
