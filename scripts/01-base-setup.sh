#!/usr/bin/env bash
# ==============================================================================
# Basis-Setup: System-Updates und grundlegende Pakete
# ==============================================================================

log_info "Aktualisiere Paketlisten..."
remote_exec "sudo apt-get update -qq"
log_success "Paketlisten aktualisiert"

log_info "Installiere Basispakete..."
remote_exec "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    unzip \
    wget \
    jq \
    fontconfig \
    > /dev/null 2>&1"
log_success "Basispakete installiert"

log_info "Konfiguriere Firewall (ufw)..."
remote_exec "
    if command -v ufw >/dev/null 2>&1; then
        sudo ufw allow ${SSH_PORT}/tcp comment 'SSH' 2>/dev/null || true
        sudo ufw allow ${JENKINS_PORT}/tcp comment 'Jenkins' 2>/dev/null || true
        if [[ '${NGINX_REVERSE_PROXY}' == 'true' ]]; then
            sudo ufw allow 80/tcp comment 'HTTP' 2>/dev/null || true
            sudo ufw allow 443/tcp comment 'HTTPS' 2>/dev/null || true
        fi
        echo 'y' | sudo ufw enable 2>/dev/null || true
    fi
"
log_success "Firewall konfiguriert"
