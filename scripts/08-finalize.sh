#!/usr/bin/env bash
# ==============================================================================
# Abschluss: Admin-User einrichten, JCasC anwenden, Health-Check
# ==============================================================================

log_info "Konfiguriere Jenkins via Configuration as Code..."

# JCasC Template verarbeiten und hochladen
TEMP_CASC=$(mktemp)
process_template "${SCRIPT_DIR}/templates/jenkins-casc.yaml" "$TEMP_CASC"
remote_copy "$TEMP_CASC" "/tmp/jenkins-casc.yaml"
rm -f "$TEMP_CASC"

remote_exec "
    CASC_DIR='/var/lib/jenkins/casc_configs'
    sudo mkdir -p \"\${CASC_DIR}\"
    sudo mv /tmp/jenkins-casc.yaml \"\${CASC_DIR}/jenkins.yaml\"
    sudo chown -R jenkins:jenkins \"\${CASC_DIR}\"

    # CASC-Pfad in Jenkins setzen
    sudo mkdir -p /etc/systemd/system/jenkins.service.d
    # Bestehenden Override erweitern
    if [[ -f /etc/systemd/system/jenkins.service.d/override.conf ]]; then
        if ! grep -q 'CASC_JENKINS_CONFIG' /etc/systemd/system/jenkins.service.d/override.conf; then
            echo 'Environment=\"CASC_JENKINS_CONFIG=/var/lib/jenkins/casc_configs\"' \
                | sudo tee -a /etc/systemd/system/jenkins.service.d/override.conf > /dev/null
        fi
    fi

    sudo systemctl daemon-reload
    sudo systemctl restart jenkins
"

wait_for_service "${TARGET_HOST}" "${JENKINS_PORT}" 120

# --- Health-Check ---
log_info "Fuehre Health-Check durch..."

JENKINS_STATUS=$(remote_exec "curl -s -o /dev/null -w '%{http_code}' http://localhost:${JENKINS_PORT}/login 2>/dev/null")
if [[ "$JENKINS_STATUS" == "200" ]]; then
    log_success "Jenkins antwortet mit HTTP 200"
else
    log_warn "Jenkins antwortet mit HTTP ${JENKINS_STATUS}"
fi

JENKINS_VERSION_HEADER=$(remote_exec "curl -sI http://localhost:${JENKINS_PORT} 2>/dev/null | grep -i 'X-Jenkins:' | awk '{print \$2}' | tr -d '\r'")

# --- Zusammenfassung ---
log_step "Installation abgeschlossen!"

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              Jenkins Training Environment                    ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"

if [[ -n "${DOMAIN_NAME}" ]]; then
    JENKINS_URL="https://${DOMAIN_NAME}"
    echo -e "${GREEN}║${NC}  URL:       ${JENKINS_URL}"
elif [[ "$NGINX_REVERSE_PROXY" == "true" ]]; then
    JENKINS_URL="http://${TARGET_HOST}"
    echo -e "${GREEN}║${NC}  URL:       ${JENKINS_URL}"
else
    JENKINS_URL="http://${TARGET_HOST}:${JENKINS_PORT}"
    echo -e "${GREEN}║${NC}  URL:       ${JENKINS_URL}"
fi

echo -e "${GREEN}║${NC}  Version:   ${JENKINS_VERSION_HEADER:-unbekannt}"
echo -e "${GREEN}║${NC}  Admin:     ${ADMIN_USER}"
echo -e "${GREEN}║${NC}  Passwort:  ${ADMIN_PASSWORD}"
echo -e "${GREEN}║${NC}"

if [[ "$INSTALL_DOCKER" == "true" ]]; then
    echo -e "${GREEN}║${NC}  Docker:    installiert"
fi
if [[ "$NGINX_REVERSE_PROXY" == "true" ]]; then
    if [[ -n "${DOMAIN_NAME}" ]]; then
        echo -e "${GREEN}║${NC}  Nginx:     aktiv (Reverse Proxy + Let's Encrypt SSL)"
    else
        echo -e "${GREEN}║${NC}  Nginx:     aktiv (Reverse Proxy)"
    fi
fi
if [[ "$AGENT_COUNT" -gt 0 ]]; then
    echo -e "${GREEN}║${NC}  Agenten:   ${AGENT_COUNT} vorbereitet"
fi

echo -e "${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  SSH:       ssh -i ${SSH_KEY_PATH} ${SSH_USER}@${TARGET_HOST}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Passwort in lokale Datei speichern
CREDS_FILE="${SCRIPT_DIR}/.jenkins-credentials"
cat > "$CREDS_FILE" <<EOF
# Jenkins Credentials - $(date '+%Y-%m-%d %H:%M:%S')
JENKINS_URL=${JENKINS_URL}
ADMIN_USER=${ADMIN_USER}
ADMIN_PASSWORD=${ADMIN_PASSWORD}
EOF
chmod 600 "$CREDS_FILE"
log_info "Zugangsdaten gespeichert in: ${CREDS_FILE}"

log_success "Deployment erfolgreich abgeschlossen!"
