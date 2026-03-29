#!/usr/bin/env bash
# ==============================================================================
# Docker-Installation
# ==============================================================================

log_info "Pruefe ob Docker bereits installiert ist..."
if remote_exec "docker --version" 2>/dev/null; then
    log_success "Docker ist bereits installiert"
else
    log_info "Installiere Docker..."
    remote_exec "
        # Docker GPG-Key
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
            | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null
        sudo chmod a+r /etc/apt/keyrings/docker.gpg

        # Docker Repository
        echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
            https://download.docker.com/linux/ubuntu \
            \$(. /etc/os-release && echo \$VERSION_CODENAME) stable\" \
            | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

        sudo apt-get update -qq
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
            docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
            > /dev/null 2>&1
    "
    log_success "Docker installiert"
fi

log_info "Fuege Jenkins-Benutzer zur Docker-Gruppe hinzu..."
remote_exec "
    sudo usermod -aG docker jenkins
    sudo usermod -aG docker ${SSH_USER}
"
log_success "Docker-Gruppenberechtigungen gesetzt"

log_info "Starte Docker-Service..."
remote_exec "sudo systemctl enable docker && sudo systemctl restart docker"
log_success "Docker laeuft"

# Jenkins muss neu gestartet werden damit die Gruppenrechte greifen
log_info "Starte Jenkins neu (Docker-Gruppenrechte)..."
remote_exec "sudo systemctl restart jenkins"
wait_for_service "${TARGET_HOST}" "${JENKINS_PORT}" 120
log_success "Jenkins mit Docker-Zugriff neugestartet"

DOCKER_VERSION=$(remote_exec "docker --version")
log_info "Docker-Version: ${DOCKER_VERSION}"
