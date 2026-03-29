#!/usr/bin/env bash
# ==============================================================================
# Nginx Reverse Proxy mit optionalem Let's Encrypt SSL
# ==============================================================================

log_info "Installiere Nginx..."
remote_exec "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq nginx > /dev/null 2>&1"
log_success "Nginx installiert"

# --- Fall 1: Mit Domain und Let's Encrypt SSL ---
if [[ -n "${DOMAIN_NAME}" ]]; then
    log_info "Domain erkannt: ${DOMAIN_NAME} -- konfiguriere Let's Encrypt SSL"

    # Certbot installieren
    log_info "Installiere Certbot..."
    remote_exec "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq certbot python3-certbot-nginx > /dev/null 2>&1"
    log_success "Certbot installiert"

    # Verzeichnis fuer ACME Challenge erstellen
    remote_exec "sudo mkdir -p /var/www/letsencrypt"

    # Zuerst eine temporaere Nginx-Config ohne SSL, damit Certbot den HTTP-Challenge machen kann
    log_info "Erstelle temporaere Nginx-Konfiguration fuer Zertifikatsanforderung..."
    remote_exec "
        cat <<'TMPCONF' | sudo tee /etc/nginx/sites-available/jenkins > /dev/null
server {
    listen 80;
    server_name ${DOMAIN_NAME};

    location /.well-known/acme-challenge/ {
        root /var/www/letsencrypt;
    }

    location / {
        proxy_pass http://127.0.0.1:${JENKINS_PORT};
    }
}
TMPCONF
        sudo ln -sf /etc/nginx/sites-available/jenkins /etc/nginx/sites-enabled/jenkins
        sudo rm -f /etc/nginx/sites-enabled/default
        sudo nginx -t && sudo systemctl restart nginx
    "

    # Let's Encrypt Zertifikat anfordern
    log_info "Fordere Let's Encrypt Zertifikat an fuer ${DOMAIN_NAME}..."
    CERTBOT_EMAIL_ARG=""
    if [[ -n "${LETSENCRYPT_EMAIL}" ]]; then
        CERTBOT_EMAIL_ARG="--email ${LETSENCRYPT_EMAIL}"
    else
        CERTBOT_EMAIL_ARG="--register-unsafely-without-email"
    fi

    remote_exec "
        sudo certbot certonly \
            --webroot \
            --webroot-path /var/www/letsencrypt \
            --domain ${DOMAIN_NAME} \
            ${CERTBOT_EMAIL_ARG} \
            --agree-tos \
            --non-interactive
    "
    log_success "Let's Encrypt Zertifikat erfolgreich ausgestellt"

    # Endgueltige Nginx-Konfiguration mit SSL deployen
    log_info "Deploye finale Nginx-SSL-Konfiguration..."
    TEMP_CONF=$(mktemp)
    process_template "${SCRIPT_DIR}/templates/nginx-jenkins.conf" "$TEMP_CONF"
    remote_copy "$TEMP_CONF" "/tmp/jenkins-nginx.conf"
    rm -f "$TEMP_CONF"

    remote_exec "
        sudo mv /tmp/jenkins-nginx.conf /etc/nginx/sites-available/jenkins
        sudo nginx -t && sudo systemctl reload nginx
    "
    log_success "Nginx SSL Reverse Proxy konfiguriert"

    # Certbot Auto-Renewal pruefen
    log_info "Pruefe Certbot Auto-Renewal..."
    remote_exec "sudo certbot renew --dry-run" 2>/dev/null && \
        log_success "Auto-Renewal funktioniert" || \
        log_warn "Auto-Renewal Dry-Run fehlgeschlagen -- bitte manuell pruefen"

    # Renewal-Hook: Nginx nach Zertifikatserneuerung neu laden
    remote_exec "
        cat <<'HOOK' | sudo tee /etc/letsencrypt/renewal-hooks/post/reload-nginx.sh > /dev/null
#!/bin/bash
systemctl reload nginx
HOOK
        sudo chmod +x /etc/letsencrypt/renewal-hooks/post/reload-nginx.sh
    "
    log_success "Renewal-Hook fuer Nginx eingerichtet"

    log_info "Jenkins erreichbar unter: https://${DOMAIN_NAME}"

# --- Fall 2: Ohne Domain -- einfacher Reverse Proxy ohne SSL ---
else
    log_info "Kein DOMAIN_NAME gesetzt -- konfiguriere Nginx ohne SSL"

    TEMP_CONF=$(mktemp)
    process_template "${SCRIPT_DIR}/templates/nginx-jenkins-nossl.conf" "$TEMP_CONF"
    remote_copy "$TEMP_CONF" "/tmp/jenkins-nginx.conf"
    rm -f "$TEMP_CONF"

    remote_exec "
        sudo mv /tmp/jenkins-nginx.conf /etc/nginx/sites-available/jenkins
        sudo ln -sf /etc/nginx/sites-available/jenkins /etc/nginx/sites-enabled/jenkins
        sudo rm -f /etc/nginx/sites-enabled/default
        sudo nginx -t && sudo systemctl restart nginx
    "
    log_success "Nginx Reverse Proxy konfiguriert (ohne SSL)"
    log_info "Jenkins erreichbar unter: http://${TARGET_HOST}"
fi

remote_exec "sudo systemctl enable nginx"
log_success "Nginx aktiviert"
