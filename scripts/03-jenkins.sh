#!/usr/bin/env bash
# ==============================================================================
# Jenkins-Installation und Grundkonfiguration
# ==============================================================================

log_info "Fuege Jenkins APT-Repository hinzu..."
remote_exec "
    # GPG-Key hinzufuegen
    sudo mkdir -p /usr/share/keyrings
    curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key \
        | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null

    # Repository hinzufuegen
    echo 'deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/' \
        | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

    sudo apt-get update -qq
"
log_success "Jenkins-Repository hinzugefuegt"

log_info "Installiere Jenkins..."
if [[ "$JENKINS_VERSION" == "lts" || "$JENKINS_VERSION" == "latest" ]]; then
    remote_exec "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq jenkins > /dev/null 2>&1"
else
    remote_exec "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq jenkins=${JENKINS_VERSION} > /dev/null 2>&1"
fi
log_success "Jenkins installiert"

log_info "Konfiguriere Jenkins-Port (${JENKINS_PORT})..."
remote_exec "
    # Systemd-Override fuer Jenkins-Port und Java-Optionen
    sudo mkdir -p /etc/systemd/system/jenkins.service.d
    cat <<OVERRIDE | sudo tee /etc/systemd/system/jenkins.service.d/override.conf > /dev/null
[Service]
Environment=\"JENKINS_PORT=${JENKINS_PORT}\"
Environment=\"JAVA_OPTS=-Djava.awt.headless=true -Djenkins.install.runSetupWizard=false\"
OVERRIDE
    sudo systemctl daemon-reload
"
log_success "Jenkins-Port auf ${JENKINS_PORT} konfiguriert"

log_info "Starte Jenkins..."
remote_exec "sudo systemctl enable jenkins && sudo systemctl restart jenkins"
log_success "Jenkins gestartet"

log_info "Warte auf Jenkins-Start..."
wait_for_service "${TARGET_HOST}" "${JENKINS_PORT}" 120

JENKINS_INSTALLED=$(remote_exec "jenkins --version 2>/dev/null || echo 'unbekannt'")
log_success "Jenkins ${JENKINS_INSTALLED} laeuft auf Port ${JENKINS_PORT}"
