#!/usr/bin/env bash
# ==============================================================================
# Gemeinsame Funktionen fuer alle Skripte
# ==============================================================================

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] [OK]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] [WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR]${NC} $*" >&2
}

log_step() {
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN} $*${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# SSH-Befehl auf dem Remote-Host ausfuehren
remote_exec() {
    ssh -o StrictHostKeyChecking=accept-new \
        -o ConnectTimeout=10 \
        -o BatchMode=yes \
        -i "${SSH_KEY_PATH}" \
        -p "${SSH_PORT}" \
        "${SSH_USER}@${TARGET_HOST}" \
        "$@"
}

# Datei zum Remote-Host kopieren
remote_copy() {
    local src="$1"
    local dest="$2"
    scp -o StrictHostKeyChecking=accept-new \
        -o ConnectTimeout=10 \
        -i "${SSH_KEY_PATH}" \
        -P "${SSH_PORT}" \
        "$src" "${SSH_USER}@${TARGET_HOST}:${dest}"
}

# Template verarbeiten - Platzhalter ersetzen
process_template() {
    local template_file="$1"
    local output_file="$2"

    cp "$template_file" "$output_file"

    # Alle bekannten Variablen ersetzen
    local vars=(
        TARGET_HOST SSH_USER SSH_PORT
        JENKINS_PORT JENKINS_VERSION JAVA_VERSION
        ADMIN_USER ADMIN_PASSWORD
        DOMAIN_NAME LETSENCRYPT_EMAIL JENKINS_CASC_URL
        NGINX_REVERSE_PROXY
    )

    for var in "${vars[@]}"; do
        local value="${!var:-}"
        if [[ -n "$value" ]]; then
            sed -i.bak "s|{{${var}}}|${value}|g" "$output_file"
        fi
    done
    rm -f "${output_file}.bak"
}

# Warten bis ein Service erreichbar ist
wait_for_service() {
    local host="$1"
    local port="$2"
    local timeout="${3:-60}"
    local elapsed=0

    log_info "Warte auf Service $host:$port (Timeout: ${timeout}s)..."
    while ! remote_exec "curl -s -o /dev/null -w '%{http_code}' http://localhost:${port} 2>/dev/null | grep -q '200\|403'" 2>/dev/null; do
        sleep 5
        elapsed=$((elapsed + 5))
        if [[ $elapsed -ge $timeout ]]; then
            log_error "Timeout: Service $host:$port nicht erreichbar nach ${timeout}s"
            return 1
        fi
        echo -n "."
    done
    echo ""
    log_success "Service $host:$port erreichbar"
}

# Passwort generieren
generate_password() {
    openssl rand -base64 16 | tr -d '/+=' | head -c 20
}

# Pruefen ob ein Remote-Paket installiert ist
remote_package_installed() {
    remote_exec "dpkg -l '$1' 2>/dev/null | grep -q '^ii'"
}

# Pruefen ob ein Remote-Service laeuft
remote_service_running() {
    remote_exec "systemctl is-active --quiet '$1'"
}

# Konfiguration laden und Defaults setzen
load_config() {
    local config_file="$1"

    if [[ ! -f "$config_file" ]]; then
        log_error "Konfigurationsdatei nicht gefunden: $config_file"
        log_info "Erstelle eine config.env basierend auf config.env.example:"
        log_info "  cp config.env.example config.env"
        exit 1
    fi

    # shellcheck disable=SC1090
    source "$config_file"

    # Pflichtparameter pruefen
    if [[ -z "${TARGET_HOST:-}" ]]; then
        log_error "TARGET_HOST ist nicht gesetzt"
        exit 1
    fi
    if [[ -z "${SSH_KEY_PATH:-}" ]]; then
        log_error "SSH_KEY_PATH ist nicht gesetzt"
        exit 1
    fi
    if [[ -z "${SSH_USER:-}" ]]; then
        log_error "SSH_USER ist nicht gesetzt"
        exit 1
    fi

    # SSH_KEY_PATH expandieren (~ aufloesen)
    SSH_KEY_PATH="${SSH_KEY_PATH/#\~/$HOME}"

    # Defaults setzen
    SSH_PORT="${SSH_PORT:-22}"
    JENKINS_PORT="${JENKINS_PORT:-8080}"
    JENKINS_VERSION="${JENKINS_VERSION:-lts}"
    JAVA_VERSION="${JAVA_VERSION:-17}"
    INSTALL_DOCKER="${INSTALL_DOCKER:-true}"
    INSTALL_PLUGINS="${INSTALL_PLUGINS:-}"
    ADMIN_USER="${ADMIN_USER:-admin}"
    ADMIN_PASSWORD="${ADMIN_PASSWORD:-$(generate_password)}"
    AGENT_COUNT="${AGENT_COUNT:-0}"
    DOMAIN_NAME="${DOMAIN_NAME:-}"
    LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL:-}"

    # Wenn DOMAIN_NAME gesetzt ist, Nginx automatisch aktivieren
    if [[ -n "$DOMAIN_NAME" ]]; then
        NGINX_REVERSE_PROXY="true"
        JENKINS_CASC_URL="https://${DOMAIN_NAME}/"
    else
        NGINX_REVERSE_PROXY="${NGINX_REVERSE_PROXY:-false}"
        if [[ "$NGINX_REVERSE_PROXY" == "true" ]]; then
            JENKINS_CASC_URL="http://${TARGET_HOST}/"
        else
            JENKINS_CASC_URL="http://${TARGET_HOST}:${JENKINS_PORT}/"
        fi
    fi

    # Exportieren
    export TARGET_HOST SSH_KEY_PATH SSH_USER SSH_PORT
    export JENKINS_PORT JENKINS_VERSION JAVA_VERSION
    export INSTALL_DOCKER INSTALL_PLUGINS
    export ADMIN_USER ADMIN_PASSWORD
    export AGENT_COUNT DOMAIN_NAME LETSENCRYPT_EMAIL JENKINS_CASC_URL NGINX_REVERSE_PROXY
}

# Default-Plugins
DEFAULT_PLUGINS=(
    "git"
    "workflow-aggregator"
    "docker-workflow"
    "blueocean"
    "credentials"
    "credentials-binding"
    "ssh-agent"
    "matrix-auth"
    "configuration-as-code"
    "locale"
    "antisamy-markup-formatter"
)
