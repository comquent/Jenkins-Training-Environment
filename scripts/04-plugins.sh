#!/usr/bin/env bash
# ==============================================================================
# Jenkins-Plugins installieren
# ==============================================================================

log_info "Lade Jenkins CLI herunter..."
remote_exec "
    JENKINS_URL='http://localhost:${JENKINS_PORT}'
    CLI_JAR='/tmp/jenkins-cli.jar'

    # Warte bis CLI verfuegbar
    for i in {1..30}; do
        if curl -sf \"\${JENKINS_URL}/jnlpJars/jenkins-cli.jar\" -o \"\${CLI_JAR}\" 2>/dev/null; then
            break
        fi
        sleep 5
    done

    if [[ ! -f \"\${CLI_JAR}\" ]]; then
        echo 'FEHLER: Jenkins CLI konnte nicht heruntergeladen werden'
        exit 1
    fi
"
log_success "Jenkins CLI bereit"

# Plugin-Liste zusammenstellen
ALL_PLUGINS=("${DEFAULT_PLUGINS[@]}")

if [[ -n "${INSTALL_PLUGINS}" ]]; then
    IFS=',' read -ra EXTRA_PLUGINS <<< "${INSTALL_PLUGINS}"
    for plugin in "${EXTRA_PLUGINS[@]}"; do
        plugin=$(echo "$plugin" | xargs) # Whitespace trimmen
        ALL_PLUGINS+=("$plugin")
    done
fi

log_info "Installiere ${#ALL_PLUGINS[@]} Plugins..."

# Initial-Admin-Passwort fuer CLI-Authentifizierung holen
INIT_PASS=$(remote_exec "sudo cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null || echo ''")

PLUGIN_LIST="${ALL_PLUGINS[*]}"
remote_exec "
    JENKINS_URL='http://localhost:${JENKINS_PORT}'
    CLI_JAR='/tmp/jenkins-cli.jar'
    AUTH_ARGS=''

    # Falls initiales Passwort vorhanden, damit authentifizieren
    if [[ -n '${INIT_PASS}' ]]; then
        AUTH_ARGS='-auth admin:${INIT_PASS}'
    fi

    # Plugins installieren
    for plugin in ${PLUGIN_LIST}; do
        echo \"  Installiere Plugin: \${plugin}\"
        java -jar \"\${CLI_JAR}\" -s \"\${JENKINS_URL}\" \${AUTH_ARGS} \
            install-plugin \"\${plugin}\" -deploy 2>/dev/null || \
        echo \"  WARNUNG: Plugin \${plugin} konnte nicht installiert werden\"
    done
"
log_success "Plugins installiert"

log_info "Starte Jenkins neu (fuer Plugin-Aktivierung)..."
remote_exec "sudo systemctl restart jenkins"
wait_for_service "${TARGET_HOST}" "${JENKINS_PORT}" 120
log_success "Jenkins mit Plugins neugestartet"
