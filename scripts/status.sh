#!/usr/bin/env bash
# =============================================================================
# LibreTime Multi-Station - Estado de los Servicios
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

# Detectar Docker Compose
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
else
    echo -e "${RED}[ERROR]${NC} Docker Compose no encontrado."
    exit 1
fi

echo ""
echo -e "${BLUE}=============================================================================${NC}"
echo -e "${BLUE} EstacionKusMedios Digital - Estado de Servicios${NC}"
echo -e "${BLUE}=============================================================================${NC}"
echo ""

STATIONS=("runaradio" "estacionkusfm" "radioaventuramx")
STATION_NAMES=("Runaradio" "EstacionKusFM" "RadioAventuraMX")
WEB_PORTS=("8081" "8082" "8083")
ICECAST_PORTS=("8010" "8020" "8030")

for i in "${!STATIONS[@]}"; do
    station="${STATIONS[$i]}"
    name="${STATION_NAMES[$i]}"
    web_port="${WEB_PORTS[$i]}"
    icecast_port="${ICECAST_PORTS[$i]}"

    echo -e "${YELLOW}--- ${name} ---${NC}"

    SERVICES=("postgres" "rabbitmq" "playout" "liquidsoap" "analyzer" "worker" "api" "legacy" "nginx" "icecast")

    for service in "${SERVICES[@]}"; do
        container="${station}-${service}"
        status=$($COMPOSE_CMD --profile "$station" ps --format '{{.State}}' "$container" 2>/dev/null || echo "not found")

        if [ "$status" = "running" ]; then
            echo -e "  ${GREEN}●${NC} ${container}: ${GREEN}running${NC}"
        elif [ "$status" = "not found" ]; then
            echo -e "  ${RED}○${NC} ${container}: ${RED}not running${NC}"
        else
            echo -e "  ${YELLOW}◐${NC} ${container}: ${YELLOW}${status}${NC}"
        fi
    done

    echo ""
    echo "  Web:     http://localhost:${web_port}"
    echo "  Icecast: http://localhost:${icecast_port}"
    echo ""
done

echo -e "${BLUE}--- Proxy Reverso ---${NC}"
proxy_status=$($COMPOSE_CMD ps --format '{{.State}}' proxy 2>/dev/null || echo "not found")
if [ "$proxy_status" = "running" ]; then
    echo -e "  ${GREEN}●${NC} proxy: ${GREEN}running${NC}"
else
    echo -e "  ${RED}○${NC} proxy: ${RED}not running${NC}"
fi
echo "  Landing: http://localhost:80"
echo ""
