#!/usr/bin/env bash
# ==============================================================================
# Nginx Reverse Proxy (optional)
# ==============================================================================

log_info "Installiere Nginx..."
remote_exec "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq nginx > /dev/null 2>&1"
log_success "Nginx installiert"

log_info "Konfiguriere Nginx als Reverse Proxy fuer Jenkins..."

# Template verarbeiten und hochladen
TEMP_CONF=$(mktemp)
process_template "${SCRIPT_DIR}/templates/nginx-jenkins.conf" "$TEMP_CONF"
remote_copy "$TEMP_CONF" "/tmp/jenkins-nginx.conf"
rm -f "$TEMP_CONF"

remote_exec "
    sudo mv /tmp/jenkins-nginx.conf /etc/nginx/sites-available/jenkins
    sudo ln -sf /etc/nginx/sites-available/jenkins /etc/nginx/sites-enabled/jenkins
    sudo rm -f /etc/nginx/sites-enabled/default

    # SSL-Zertifikat generieren falls gewuenscht
    if [[ '${ENABLE_SSL}' == 'true' ]]; then
        sudo mkdir -p /etc/nginx/ssl
        sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout /etc/nginx/ssl/jenkins.key \
            -out /etc/nginx/ssl/jenkins.crt \
            -subj '/CN=${TARGET_HOST}/O=Jenkins Training/C=DE' \
            2>/dev/null
    fi

    # Konfiguration pruefen
    sudo nginx -t

    sudo systemctl enable nginx
    sudo systemctl restart nginx
"
log_success "Nginx Reverse Proxy konfiguriert"

if [[ "$ENABLE_SSL" == "true" ]]; then
    log_info "Jenkins erreichbar unter: https://${TARGET_HOST}"
else
    log_info "Jenkins erreichbar unter: http://${TARGET_HOST}"
fi
