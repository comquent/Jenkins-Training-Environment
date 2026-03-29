#!/usr/bin/env bash
# ==============================================================================
# Jenkins-Agenten einrichten (SSH-basiert auf demselben Host)
# ==============================================================================

log_info "Richte ${AGENT_COUNT} Jenkins-Agent(en) ein..."

remote_exec "
    JENKINS_URL='http://localhost:${JENKINS_PORT}'

    # Agent-Benutzer und Verzeichnisse erstellen
    for i in \$(seq 1 ${AGENT_COUNT}); do
        AGENT_NAME=\"agent-\${i}\"
        AGENT_HOME=\"/var/lib/jenkins-agents/\${AGENT_NAME}\"

        echo \"Erstelle Agent: \${AGENT_NAME}\"

        # Verzeichnis erstellen
        sudo mkdir -p \"\${AGENT_HOME}\"
        sudo chown jenkins:jenkins \"\${AGENT_HOME}\"

        # Agent-Konfiguration als XML erstellen
        cat <<AGENTXML > /tmp/\${AGENT_NAME}.xml
<?xml version='1.0' encoding='UTF-8'?>
<slave>
  <name>\${AGENT_NAME}</name>
  <description>Training Agent \${i}</description>
  <remoteFS>\${AGENT_HOME}</remoteFS>
  <numExecutors>2</numExecutors>
  <mode>NORMAL</mode>
  <retentionStrategy class=\"hudson.slaves.RetentionStrategy\\\$Always\"/>
  <launcher class=\"hudson.slaves.JNLPLauncher\">
    <workDirSettings>
      <disabled>false</disabled>
      <internalDir>remoting</internalDir>
      <failIfWorkDirIsMissing>false</failIfWorkDirIsMissing>
    </workDirSettings>
  </launcher>
  <label>training linux</label>
  <nodeProperties/>
</slave>
AGENTXML
    done
"

log_success "${AGENT_COUNT} Agent-Verzeichnis(se) erstellt"
log_info "Agenten koennen ueber die Jenkins-UI oder JCasC verbunden werden"
