#!/usr/bin/env bash
# ==============================================================================
# Java-Installation
# ==============================================================================

log_info "Pruefe ob Java ${JAVA_VERSION} bereits installiert ist..."
if remote_exec "java -version 2>&1 | grep -q 'openjdk version \"${JAVA_VERSION}'"; then
    log_success "Java ${JAVA_VERSION} ist bereits installiert"
else
    log_info "Installiere OpenJDK ${JAVA_VERSION}..."
    remote_exec "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        openjdk-${JAVA_VERSION}-jdk-headless > /dev/null 2>&1"

    # Als Default setzen falls mehrere Versionen vorhanden
    remote_exec "sudo update-alternatives --set java \
        /usr/lib/jvm/java-${JAVA_VERSION}-openjdk-amd64/bin/java 2>/dev/null || true"

    log_success "Java ${JAVA_VERSION} installiert"
fi

JAVA_INSTALLED=$(remote_exec "java -version 2>&1 | head -1")
log_info "Java-Version: ${JAVA_INSTALLED}"
