# LibreTime Multi-Station - EstacionKusMedios Digital

Plataforma de radio digital multi-estacion basada en [LibreTime](https://libretime.org/) 4.5.0, ejecutando **3 estaciones de radio independientes** en un solo servidor mediante Docker.

**Propietario:** Luis Martinez Sandoval

## Estaciones

| Estacion | Web | Icecast | Liquidsoap Main | Liquidsoap Show |
|---|---|---|---|---|
| Runaradio | `:8081` | `:8010` | `:8101` | `:8102` |
| EstacionKusFM | `:8082` | `:8020` | `:8201` | `:8202` |
| RadioAventuraMX | `:8083` | `:8030` | `:8301` | `:8302` |

**Proxy reverso:** Puerto `80` con pagina de inicio y rutas `/runaradio/`, `/estacionkusfm/`, `/radioaventuramx/`

## Arquitectura

```
                            ┌─────────────────┐
                            │   Puerto 80     │
                            │  Nginx Proxy    │
                            │  (Landing Page) │
                            └────────┬────────┘
                                     │
                    ┌────────────────┼────────────────┐
                    │                │                 │
           ┌───────▼──────┐ ┌──────▼───────┐ ┌──────▼────────┐
           │  Runaradio   │ │EstacionKusFM │ │RadioAventuraMX│
           │  :8081       │ │  :8082       │ │  :8083        │
           └───────┬──────┘ └──────┬───────┘ └──────┬────────┘
                   │               │                 │
    Cada estacion tiene su propio stack completo:
    ┌──────────────────────────────────────────────┐
    │                                              │
    │  ┌──────────┐  ┌──────────┐  ┌───────────┐  │
    │  │ postgres │  │ rabbitmq │  │  icecast  │  │
    │  └──────────┘  └──────────┘  └───────────┘  │
    │                                              │
    │  ┌──────────┐  ┌──────────┐  ┌───────────┐  │
    │  │   api    │  │  legacy  │  │   nginx   │  │
    │  └──────────┘  └──────────┘  └───────────┘  │
    │                                              │
    │  ┌──────────┐  ┌──────────┐  ┌───────────┐  │
    │  │ playout  │  │liquidsoap│  │  analyzer  │  │
    │  └──────────┘  └──────────┘  └───────────┘  │
    │                                              │
    │  ┌──────────┐                                │
    │  │  worker  │   Red aislada por estacion     │
    │  └──────────┘                                │
    └──────────────────────────────────────────────┘
```

Cada estacion opera en su propia red Docker aislada. El proxy reverso se conecta a todas las estaciones a traves de una red compartida (`proxy_net`).

## Prerequisitos

- **Docker** 20.10+ ([Instalar Docker](https://docs.docker.com/get-docker/))
- **Docker Compose** v2+ (incluido con Docker Desktop)
- **envsubst** (parte del paquete `gettext-base`)
  ```bash
  # Ubuntu/Debian
  sudo apt-get install gettext-base

  # macOS (con Homebrew)
  brew install gettext
  ```
- Minimo **4 GB de RAM** disponible para Docker
- Minimo **10 GB de espacio en disco**

## Inicio Rapido

### 1. Clonar el repositorio

```bash
git clone https://github.com/luisitoys12/libretime-multi-station.git
cd libretime-multi-station
```

### 2. Ejecutar el script de configuracion

```bash
chmod +x setup.sh
./setup.sh
```

El script automaticamente:
1. Verifica que Docker, Docker Compose y envsubst esten instalados
2. Genera contrasenas aleatorias para todas las estaciones
3. Crea el archivo `.env` con las contrasenas generadas
4. Genera los archivos `config.yml` para cada estacion usando `envsubst`
5. Ejecuta las migraciones de base de datos para cada estacion
6. Inicia todos los servicios con `docker compose up -d`
7. Muestra las URLs y el estado de los servicios

### 3. Acceder a las estaciones

- **Pagina principal:** http://localhost
- **Runaradio:** http://localhost:8081
- **EstacionKusFM:** http://localhost:8082
- **RadioAventuraMX:** http://localhost:8083

**Credenciales por defecto de LibreTime:**
- Usuario: `admin`
- Contrasena: `admin`

> **IMPORTANTE:** Cambia la contrasena del administrador despues del primer inicio de sesion.

## Gestion de Estaciones Individuales

Docker Compose profiles permite iniciar/detener estaciones de forma independiente.

### Iniciar solo una estacion

```bash
docker compose --profile runaradio up -d
```

### Iniciar dos estaciones

```bash
docker compose --profile runaradio --profile estacionkusfm up -d
```

### Iniciar todas las estaciones

```bash
docker compose --profile runaradio --profile estacionkusfm --profile radioaventuramx up -d
```

### Detener una estacion

```bash
docker compose --profile runaradio down
```

### Ver logs de una estacion

```bash
docker compose --profile runaradio logs -f
```

### Ver logs de un servicio especifico

```bash
docker compose --profile runaradio logs -f runaradio-api
```

### Reiniciar un servicio

```bash
docker compose --profile runaradio restart runaradio-api
```

## Tabla de Puertos

| Servicio | Runaradio | EstacionKusFM | RadioAventuraMX |
|---|---|---|---|
| Web (nginx) | 8081 | 8082 | 8083 |
| Icecast | 8010 | 8020 | 8030 |
| Liquidsoap Main | 8101 | 8201 | 8301 |
| Liquidsoap Show | 8102 | 8202 | 8302 |
| Proxy reverso | 80 (compartido) | 80 (compartido) | 80 (compartido) |

## Respaldo y Restauracion

### Crear respaldo de todas las estaciones

```bash
./scripts/backup.sh
```

Los respaldos se guardan en `backups/YYYYMMDD_HHMMSS/`.

### Respaldar solo una estacion

```bash
./scripts/backup.sh runaradio
```

### Restaurar una base de datos

```bash
gunzip -c backups/20260315_120000/runaradio_db.sql.gz | \
  docker compose --profile runaradio exec -T runaradio-postgres psql -U libretime libretime
```

## Scripts de Utilidad

| Script | Descripcion |
|---|---|
| `setup.sh` | Configuracion inicial completa |
| `scripts/migrate-all.sh` | Ejecutar migraciones de BD para todas las estaciones |
| `scripts/migrate-all.sh runaradio` | Ejecutar migraciones solo para una estacion |
| `scripts/backup.sh` | Respaldar todas las bases de datos |
| `scripts/backup.sh runaradio` | Respaldar solo una estacion |
| `scripts/status.sh` | Ver estado de todos los servicios |

## Como Agregar una Nueva Estacion

Para agregar una cuarta estacion (por ejemplo, `nuevaradio`):

### 1. Crear la plantilla de configuracion

```bash
mkdir -p stations/nuevaradio
cp stations/runaradio/config.yml.tmpl stations/nuevaradio/config.yml.tmpl
```

Edita `stations/nuevaradio/config.yml.tmpl` y reemplaza:
- Todos los `runaradio` por `nuevaradio`
- Todos los `RUNARADIO_` por `NUEVARADIO_`
- El nombre de la estacion y descripcion

### 2. Agregar variables al .env.example

```bash
# Estación 4: NuevaRadio
NUEVARADIO_POSTGRES_PASSWORD=CHANGE_ME
NUEVARADIO_RABBITMQ_PASS=CHANGE_ME
NUEVARADIO_ICECAST_SOURCE_PASSWORD=CHANGE_ME
NUEVARADIO_ICECAST_ADMIN_PASSWORD=CHANGE_ME
NUEVARADIO_ICECAST_RELAY_PASSWORD=CHANGE_ME
NUEVARADIO_API_KEY=CHANGE_ME
NUEVARADIO_SECRET_KEY=CHANGE_ME
NUEVARADIO_PUBLIC_URL=http://localhost:8084
```

### 3. Agregar servicios al docker-compose.yml

Copia el bloque completo de una estacion existente (por ejemplo, Runaradio) y reemplaza:
- Todos los `runaradio` por `nuevaradio`
- Todos los `RUNARADIO_` por `NUEVARADIO_`
- Los puertos: web=8084, icecast=8040, liquidsoap=8401/8402
- Agrega el profile `["nuevaradio"]`
- Agrega los volumenes y la red `nuevaradio_net`

### 4. Actualizar el proxy

Edita `nginx/proxy.conf` para agregar los bloques upstream y location para la nueva estacion.

### 5. Generar configuracion y migrar

```bash
# Regenerar .env con nuevas contraseñas (o agregar manualmente)
# Generar config.yml
source .env && envsubst < stations/nuevaradio/config.yml.tmpl > stations/nuevaradio/config.yml

# Migrar base de datos
./scripts/migrate-all.sh nuevaradio

# Iniciar
docker compose --profile nuevaradio up -d
```

## Solucion de Problemas

### Los servicios no inician

```bash
# Ver estado detallado
./scripts/status.sh

# Ver logs de un servicio especifico
docker compose --profile runaradio logs runaradio-api

# Reiniciar todos los servicios de una estacion
docker compose --profile runaradio restart
```

### Error de conexion a la base de datos

```bash
# Verificar que postgres esta corriendo
docker compose --profile runaradio ps runaradio-postgres

# Verificar la salud del contenedor
docker inspect --format='{{.State.Health.Status}}' libretime-multi-station-runaradio-postgres-1

# Ejecutar migraciones nuevamente
./scripts/migrate-all.sh runaradio
```

### Puerto en uso

Si un puerto ya esta en uso, edita el archivo `.env` para cambiar la URL publica, y modifica los puertos en `docker-compose.yml`.

### Icecast no reproduce audio

1. Verifica que liquidsoap esta corriendo:
   ```bash
   docker compose --profile runaradio logs runaradio-liquidsoap
   ```
2. Verifica que icecast esta accesible:
   ```bash
   curl http://localhost:8010/status-json.xsl
   ```
3. Verifica la configuracion del stream en `stations/runaradio/config.yml`

### Restablecer una estacion desde cero

```bash
# Detener la estacion
docker compose --profile runaradio down

# Eliminar volumenes (ESTO BORRA TODOS LOS DATOS)
docker volume rm libretime-multi-station_runaradio_postgres_data
docker volume rm libretime-multi-station_runaradio_storage
docker volume rm libretime-multi-station_runaradio_playout

# Regenerar config y migrar
source .env && envsubst < stations/runaradio/config.yml.tmpl > stations/runaradio/config.yml
./scripts/migrate-all.sh runaradio

# Iniciar
docker compose --profile runaradio up -d
```

### Revisar uso de recursos

```bash
docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" | grep -E "(runaradio|estacionkusfm|radioaventuramx|proxy)"
```

## Estructura del Proyecto

```
libretime-multi-station/
├── docker-compose.yml              # Compose principal con las 3 estaciones + proxy
├── .env.example                    # Plantilla de variables de entorno
├── .env                            # Variables con contraseñas (generado, no en git)
├── setup.sh                        # Script de configuracion automatica
├── nginx/
│   └── proxy.conf                  # Configuracion del proxy reverso
├── stations/
│   ├── runaradio/
│   │   ├── config.yml.tmpl         # Plantilla de configuracion
│   │   └── config.yml              # Configuracion generada (no en git)
│   ├── estacionkusfm/
│   │   ├── config.yml.tmpl
│   │   └── config.yml
│   └── radioaventuramx/
│       ├── config.yml.tmpl
│       └── config.yml
├── scripts/
│   ├── migrate-all.sh              # Migraciones de BD
│   ├── backup.sh                   # Respaldos de BD
│   └── status.sh                   # Estado de servicios
├── .github/
│   └── workflows/
│       └── validate.yml            # CI para validar docker-compose
├── .gitignore
└── README.md
```

## Licencia

Este proyecto es una configuracion de despliegue para [LibreTime](https://libretime.org/), que es software libre bajo la licencia [AGPL-3.0](https://www.gnu.org/licenses/agpl-3.0.html).
