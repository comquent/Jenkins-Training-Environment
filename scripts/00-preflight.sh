#!/usr/bin/env bash
# ==============================================================================
# Preflight-Check: Verbindungstest und Systemanforderungen pruefen
# ==============================================================================

log_info "Pruefe SSH-Key: ${SSH_KEY_PATH}"
if [[ ! -f "${SSH_KEY_PATH}" ]]; then
    log_error "SSH-Key nicht gefunden: ${SSH_KEY_PATH}"
    exit 1
fi
log_success "SSH-Key vorhanden"

log_info "Teste SSH-Verbindung zu ${SSH_USER}@${TARGET_HOST}:${SSH_PORT}..."
if ! remote_exec "echo 'SSH-Verbindung erfolgreich'" 2>/dev/null; then
    log_error "SSH-Verbindung fehlgeschlagen"
    log_info "Pruefe: IP-Adresse, SSH-Key, Benutzer, Port, Firewall"
    exit 1
fi
log_success "SSH-Verbindung hergestellt"

log_info "Pruefe Betriebssystem..."
OS_INFO=$(remote_exec "cat /etc/os-release 2>/dev/null | grep -E '^(ID|VERSION_ID)='")
if ! echo "$OS_INFO" | grep -qi "ubuntu"; then
    log_error "Kein Ubuntu-System erkannt. Gefunden: ${OS_INFO}"
    exit 1
fi
OS_VERSION=$(echo "$OS_INFO" | grep VERSION_ID | cut -d'"' -f2)
log_success "Ubuntu ${OS_VERSION} erkannt"

log_info "Pruefe sudo-Rechte..."
if ! remote_exec "sudo -n true" 2>/dev/null; then
    log_error "Benutzer '${SSH_USER}' hat keine passwortlosen sudo-Rechte"
    log_info "Fuege folgendes auf dem Zielhost hinzu:"
    log_info "  echo '${SSH_USER} ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/${SSH_USER}"
    exit 1
fi
log_success "sudo-Rechte vorhanden"

log_info "Pruefe Systemressourcen..."
CPU_CORES=$(remote_exec "nproc")
MEMORY_MB=$(remote_exec "free -m | awk '/^Mem:/{print \$2}'")
DISK_GB=$(remote_exec "df -BG / | awk 'NR==2{print \$4}' | tr -d 'G'")

log_info "  CPUs:      ${CPU_CORES}"
log_info "  RAM:       ${MEMORY_MB} MB"
log_info "  Disk frei: ${DISK_GB} GB"

WARNINGS=0
if [[ "$CPU_CORES" -lt 2 ]]; then
    log_warn "Weniger als 2 CPU-Kerne (${CPU_CORES}) - Jenkins kann langsam sein"
    WARNINGS=$((WARNINGS + 1))
fi
if [[ "$MEMORY_MB" -lt 3500 ]]; then
    log_warn "Weniger als 4 GB RAM (${MEMORY_MB} MB) - Jenkins kann instabil sein"
    WARNINGS=$((WARNINGS + 1))
fi
if [[ "$DISK_GB" -lt 15 ]]; then
    log_warn "Weniger als 15 GB freier Speicher (${DISK_GB} GB)"
    WARNINGS=$((WARNINGS + 1))
fi

if [[ "$WARNINGS" -eq 0 ]]; then
    log_success "Systemressourcen ausreichend"
else
    log_warn "${WARNINGS} Warnung(en) - Deployment wird fortgesetzt"
fi

log_info "Pruefe Internetzugang des Zielsystems..."
if ! remote_exec "curl -s --connect-timeout 5 https://pkg.jenkins.io >/dev/null 2>&1"; then
    log_error "Zielsystem hat keinen Internetzugang (pkg.jenkins.io nicht erreichbar)"
    exit 1
fi
log_success "Internetzugang vorhanden"

if [[ -n "${DOMAIN_NAME}" ]]; then
    log_info "Pruefe DNS-Aufloesung fuer ${DOMAIN_NAME}..."
    RESOLVED_IP=$(remote_exec "dig +short ${DOMAIN_NAME} 2>/dev/null | head -1")
    if [[ -z "$RESOLVED_IP" ]]; then
        log_error "Domain ${DOMAIN_NAME} kann nicht aufgeloest werden"
        log_info "Stelle sicher, dass ein DNS-A-Record fuer ${DOMAIN_NAME} auf ${TARGET_HOST} zeigt"
        exit 1
    fi
    log_success "Domain ${DOMAIN_NAME} loest auf zu ${RESOLVED_IP}"

    log_info "Pruefe ob Port 80 von aussen erreichbar ist (noetig fuer Let's Encrypt)..."
    if ! remote_exec "sudo ufw status 2>/dev/null | grep -q '80/tcp.*ALLOW'" 2>/dev/null; then
        log_warn "Port 80 ist moeglicherweise nicht in der Firewall freigegeben -- wird in 01-base-setup.sh konfiguriert"
    fi
fi

log_success "Alle Preflight-Checks bestanden"
