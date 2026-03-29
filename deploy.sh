#!/usr/bin/env bash
# ==============================================================================
# Jenkins Training Environment - Haupt-Deploymentskript
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# --- Hilfe --------------------------------------------------------------------
usage() {
    cat <<EOF
Verwendung: $0 [OPTIONEN]

Jenkins Training Environment auf einer entfernten Ubuntu-VM installieren.

Optionen:
  --config FILE       Konfigurationsdatei (Standard: config.env)
  --step STEP         Nur einen bestimmten Schritt ausfuehren (z.B. 03-jenkins)
  --preflight-only    Nur Verbindungs- und Systemcheck durchfuehren
  --skip STEP         Schritt ueberspringen (mehrfach verwendbar)
  --dry-run           Nur anzeigen, was ausgefuehrt wuerde
  -h, --help          Diese Hilfe anzeigen

Beispiele:
  $0                              # Vollstaendiges Deployment
  $0 --config prod.env            # Mit alternativer Konfiguration
  $0 --step 03-jenkins            # Nur Jenkins installieren
  $0 --preflight-only             # Nur Verbindungstest
  $0 --skip 05-docker --skip 06-nginx  # Ohne Docker und Nginx

EOF
    exit 0
}

# --- Argument-Parsing ---------------------------------------------------------
CONFIG_FILE="${SCRIPT_DIR}/config.env"
SINGLE_STEP=""
PREFLIGHT_ONLY=false
DRY_RUN=false
declare -a SKIP_STEPS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)   CONFIG_FILE="$2"; shift 2 ;;
        --step)     SINGLE_STEP="$2"; shift 2 ;;
        --preflight-only) PREFLIGHT_ONLY=true; shift ;;
        --skip)     SKIP_STEPS+=("$2"); shift 2 ;;
        --dry-run)  DRY_RUN=true; shift ;;
        -h|--help)  usage ;;
        *)          log_error "Unbekannte Option: $1"; usage ;;
    esac
done

# --- Konfiguration laden -----------------------------------------------------
load_config "$CONFIG_FILE"

log_step "Jenkins Training Environment - Deployment"
log_info "Zielhost:        ${TARGET_HOST}"
log_info "SSH-User:        ${SSH_USER}"
log_info "SSH-Port:        ${SSH_PORT}"
log_info "Jenkins-Port:    ${JENKINS_PORT}"
log_info "Jenkins-Version: ${JENKINS_VERSION}"
log_info "Java-Version:    ${JAVA_VERSION}"
log_info "Docker:          ${INSTALL_DOCKER}"
log_info "Nginx Proxy:     ${NGINX_REVERSE_PROXY}"
log_info "Agenten:         ${AGENT_COUNT}"
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
    log_warn "Dry-Run-Modus - es werden keine Aenderungen durchgefuehrt"
fi

# --- Schritt-Ausfuehrung -----------------------------------------------------
should_run_step() {
    local step_name="$1"

    # Einzelschritt-Modus
    if [[ -n "$SINGLE_STEP" ]]; then
        [[ "$step_name" == *"$SINGLE_STEP"* ]]
        return $?
    fi

    # Skip-Pruefung
    for skip in "${SKIP_STEPS[@]:-}"; do
        if [[ -n "$skip" && "$step_name" == *"$skip"* ]]; then
            log_warn "Ueberspringe: $step_name"
            return 1
        fi
    done

    return 0
}

run_step() {
    local script="$1"
    local step_name
    step_name="$(basename "$script" .sh)"

    if ! should_run_step "$step_name"; then
        return 0
    fi

    log_step "Schritt: $step_name"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Wuerde ausfuehren: $script"
        return 0
    fi

    # shellcheck disable=SC1090
    source "$script"
}

# --- Deployment ausfuehren ---------------------------------------------------

# Preflight immer ausfuehren
run_step "${SCRIPT_DIR}/scripts/00-preflight.sh"

if [[ "$PREFLIGHT_ONLY" == "true" ]]; then
    log_success "Preflight-Check abgeschlossen"
    exit 0
fi

# Installations-Schritte
run_step "${SCRIPT_DIR}/scripts/01-base-setup.sh"
run_step "${SCRIPT_DIR}/scripts/02-java.sh"
run_step "${SCRIPT_DIR}/scripts/03-jenkins.sh"
run_step "${SCRIPT_DIR}/scripts/04-plugins.sh"

# Optionale Schritte
if [[ "$INSTALL_DOCKER" == "true" ]]; then
    run_step "${SCRIPT_DIR}/scripts/05-docker.sh"
fi

if [[ "$NGINX_REVERSE_PROXY" == "true" ]]; then
    run_step "${SCRIPT_DIR}/scripts/06-nginx.sh"
fi

if [[ "$AGENT_COUNT" -gt 0 ]]; then
    run_step "${SCRIPT_DIR}/scripts/07-agents.sh"
fi

# Abschluss
run_step "${SCRIPT_DIR}/scripts/08-finalize.sh"
