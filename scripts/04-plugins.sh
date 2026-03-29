#!/usr/bin/env bash
# ==============================================================================
# Jenkins-Plugins installieren (via jenkins-plugin-manager)
# ==============================================================================

# Plugin-Liste zusammenstellen
ALL_PLUGINS=("${DEFAULT_PLUGINS[@]}")

if [[ -n "${INSTALL_PLUGINS}" ]]; then
    IFS=',' read -ra EXTRA_PLUGINS <<< "${INSTALL_PLUGINS}"
    for plugin in "${EXTRA_PLUGINS[@]}"; do
        plugin=$(echo "$plugin" | xargs)
        ALL_PLUGINS+=("$plugin")
    done
fi

log_info "Installiere ${#ALL_PLUGINS[@]} Plugins..."

# Plugin-Liste als Space-separierter String
PLUGIN_LIST="${ALL_PLUGINS[*]}"

remote_exec "
    # Jenkins Plugin Manager CLI herunterladen (offizielles Tool)
    PLUGIN_MGR='/tmp/jenkins-plugin-manager.jar'
    if [[ ! -f \"\${PLUGIN_MGR}\" ]]; then
        curl -fsSL -o \"\${PLUGIN_MGR}\" \
            https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/2.14.0/jenkins-plugin-manager-2.14.0.jar
    fi

    # Jenkins WAR Pfad ermitteln
    JENKINS_WAR=\$(find /usr/share/java /usr/share/jenkins -name 'jenkins.war' 2>/dev/null | head -1)
    if [[ -z \"\${JENKINS_WAR}\" ]]; then
        JENKINS_WAR='/usr/share/java/jenkins.war'
    fi

    # Plugins installieren
    java -jar \"\${PLUGIN_MGR}\" \
        --war \"\${JENKINS_WAR}\" \
        --plugin-download-directory /var/lib/jenkins/plugins \
        --plugins ${PLUGIN_LIST}

    # Berechtigungen setzen
    sudo chown -R jenkins:jenkins /var/lib/jenkins/plugins
"
log_success "Plugins installiert"

log_info "Starte Jenkins neu (fuer Plugin-Aktivierung)..."
remote_exec "sudo systemctl restart jenkins"
wait_for_service "${TARGET_HOST}" "${JENKINS_PORT}" 120
log_success "Jenkins mit Plugins neugestartet"
