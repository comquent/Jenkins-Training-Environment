# Jenkins Training Environment - Automatisierte Installation

## Projektbeschreibung

Dieses Projekt automatisiert die Installation und Konfiguration einer Jenkins-Umgebung auf einer entfernten Ubuntu-VM per SSH. Alle Schritte sind idempotent und parametrisierbar.

## Anforderungen

### Zielsystem
- **OS:** Ubuntu 22.04 / 24.04 LTS
- **Zugang:** SSH mit Key-Authentifizierung
- **Mindestanforderungen:** 2 CPU, 4 GB RAM, 20 GB Disk
- **Netzwerk:** Port 8080 (Jenkins UI), Port 22 (SSH) und Port 80/443 (bei SSL) muessen erreichbar sein

### Voraussetzungen lokal
- `ssh` Client installiert
- `scp` verfuegbar
- Bash 4+ (macOS/Linux)

### Voraussetzungen Zielsystem
- Ubuntu mit `apt` Paketmanager
- Benutzer mit sudo-Rechten
- Internetzugang (fuer Paket-Downloads)

## Konfiguration

Alle Parameter werden in `config.env` definiert. Folgende Parameter stehen zur Verfuegung:

| Parameter | Beschreibung | Pflicht | Default |
|-----------|-------------|---------|---------|
| `TARGET_HOST` | IP-Adresse oder Hostname der VM | Ja | - |
| `SSH_KEY_PATH` | Pfad zum privaten SSH-Key | Ja | - |
| `SSH_USER` | SSH-Benutzer auf der VM | Ja | `ubuntu` |
| `SSH_PORT` | SSH-Port | Nein | `22` |
| `JENKINS_PORT` | Port fuer Jenkins Web-UI | Nein | `8080` |
| `JENKINS_VERSION` | Jenkins-Version (lts/latest/spezifisch) | Nein | `lts` |
| `JAVA_VERSION` | Java-Version (17/21) | Nein | `17` |
| `INSTALL_DOCKER` | Docker auf dem Jenkins-Host installieren | Nein | `true` |
| `INSTALL_PLUGINS` | Kommaseparierte Liste zusaetzlicher Plugins | Nein | siehe Default-Plugins |
| `ADMIN_USER` | Jenkins Admin-Benutzername | Nein | `admin` |
| `ADMIN_PASSWORD` | Jenkins Admin-Passwort | Nein | (wird generiert) |
| `AGENT_COUNT` | Anzahl zusaetzlicher Jenkins-Agenten (0-5) | Nein | `0` |
| `DOMAIN_NAME` | Domain fuer Jenkins (aktiviert Nginx + Let's Encrypt SSL) | Nein | *(leer)* |
| `LETSENCRYPT_EMAIL` | E-Mail fuer Let's Encrypt Benachrichtigungen | Nein | *(leer)* |
| `NGINX_REVERSE_PROXY` | Nginx als Reverse Proxy (automatisch bei DOMAIN_NAME) | Nein | `false` |

## Projektstruktur

```
.
├── CLAUDE.md              # Diese Datei - Projektdokumentation
├── config.env             # Konfigurationsdatei (Parameter)
├── config.env.example     # Beispiel-Konfiguration
├── deploy.sh              # Haupt-Deploymentskript
├── scripts/
│   ├── 00-preflight.sh    # Verbindungstest und Systemcheck
│   ├── 01-base-setup.sh   # System-Updates und Basispakete
│   ├── 02-java.sh         # Java-Installation
│   ├── 03-jenkins.sh      # Jenkins-Installation und Konfiguration
│   ├── 04-plugins.sh      # Plugin-Installation
│   ├── 05-docker.sh       # Docker-Installation (optional)
│   ├── 06-nginx.sh        # Nginx Reverse Proxy (optional)
│   ├── 07-agents.sh       # Jenkins-Agenten einrichten (optional)
│   └── 08-finalize.sh     # Abschluss, Passwort-Ausgabe, Health-Check
├── templates/
│   ├── jenkins-casc.yaml  # Jenkins Configuration as Code Template
│   ├── nginx-jenkins.conf      # Nginx-Konfiguration mit SSL (Let's Encrypt)
│   └── nginx-jenkins-nossl.conf # Nginx-Konfiguration ohne SSL
└── lib/
    └── common.sh          # Gemeinsame Funktionen (SSH, Logging, etc.)
```

## Verwendung

```bash
# 1. Konfiguration erstellen
cp config.env.example config.env
# config.env anpassen (mindestens TARGET_HOST, SSH_KEY_PATH, SSH_USER)

# 2. Deployment starten
./deploy.sh

# 3. Einzelne Schritte ausfuehren (optional)
./deploy.sh --step 03-jenkins

# 4. Nur Preflight-Check
./deploy.sh --preflight-only
```

## Default-Plugins

Folgende Plugins werden standardmaessig installiert:
- `git` - Git-Integration
- `pipeline` (workflow-aggregator) - Pipeline-Support
- `docker-workflow` - Docker in Pipelines
- `credentials` / `credentials-binding` - Credential-Management
- `ssh-agent` - SSH-Agent fuer Pipelines
- `matrix-auth` - Autorisierung
- `configuration-as-code` - JCasC Support
- `pipeline-stage-view` - Pipeline Stage Visualisierung
- `timestamper` - Zeitstempel in Build-Logs

## Konventionen

- Alle Skripte sind idempotent (mehrfache Ausfuehrung sicher)
- Logging nach stdout mit Zeitstempel und Farbcodierung
- Fehler brechen die Ausfuehrung ab (set -euo pipefail)
- Remote-Befehle werden per SSH ausgefuehrt, keine Agenten noetig
- Alle Templates verwenden Platzhalter im Format `{{VARIABLE}}`
