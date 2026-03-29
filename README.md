<p align="center">
  <a href="https://comquent.academy/jenkins-expert-training-schulung/">
    <img src="https://comquent.academy/wp-content/uploads/comquent-academy-logo.png" alt="Comquent Academy" width="400">
  </a>
</p>

# Jenkins Training Environment

Ein Projekt der **[Comquent Academy](https://comquent.academy/jenkins-expert-training-schulung/)** -- begleitend zum [Jenkins Expert Training](https://comquent.academy/jenkins-expert-training-schulung/).

Automatisierte Installation und Konfiguration einer Jenkins-Umgebung auf einer entfernten Ubuntu-VM. Das Deployment erfolgt komplett per SSH -- es werden keine Agenten oder zusaetzliche Tools auf dem Zielsystem vorausgesetzt.

## Voraussetzungen

### Lokal (Steuerungsrechner)

- Bash 4+ (macOS / Linux)
- `ssh` und `scp`

### Zielsystem (Remote-VM)

- Ubuntu 22.04 oder 24.04 LTS
- SSH-Zugang mit Key-Authentifizierung
- Benutzer mit passwortlosem `sudo`
- Internetzugang
- Mindestens 2 CPUs, 4 GB RAM, 20 GB Disk
- Ports 22 (SSH) und 8080 (Jenkins) erreichbar

## Schnellstart

```bash
# 1. Repository klonen
git clone <repo-url>
cd Jenkins-Training-Enviroment

# 2. Konfiguration erstellen
cp config.env.example config.env

# 3. Pflichtparameter anpassen
#    TARGET_HOST  - IP-Adresse der VM
#    SSH_KEY_PATH - Pfad zum privaten SSH-Key
#    SSH_USER     - Benutzername auf der VM
vi config.env

# 4. Deployment starten
./deploy.sh
```

Nach Abschluss werden die Zugangsdaten (URL, Admin-User, Passwort) in der Konsole angezeigt und in `.jenkins-credentials` gespeichert.

## Konfiguration

Alle Parameter werden in `config.env` gesetzt. Eine kommentierte Vorlage liegt in `config.env.example`.

### Pflichtparameter

| Parameter | Beschreibung |
|---|---|
| `TARGET_HOST` | IP-Adresse oder Hostname der Ziel-VM |
| `SSH_KEY_PATH` | Pfad zum privaten SSH-Key |
| `SSH_USER` | SSH-Benutzer auf der VM |

### Optionale Parameter

| Parameter | Default | Beschreibung |
|---|---|---|
| `SSH_PORT` | `22` | SSH-Port |
| `JENKINS_PORT` | `8080` | Port fuer die Jenkins Web-UI |
| `JENKINS_VERSION` | `lts` | `lts`, `latest` oder eine spezifische Version (z.B. `2.462.1`) |
| `JAVA_VERSION` | `17` | OpenJDK-Version (`17` oder `21`) |
| `INSTALL_DOCKER` | `true` | Docker CE auf dem Host installieren |
| `INSTALL_PLUGINS` | *(leer)* | Zusaetzliche Plugins, kommasepariert (z.B. `ansible,terraform`) |
| `ADMIN_USER` | `admin` | Jenkins-Admin-Benutzername |
| `ADMIN_PASSWORD` | *(generiert)* | Admin-Passwort (wird automatisch erzeugt, wenn leer) |
| `AGENT_COUNT` | `0` | Anzahl lokaler Jenkins-Agenten (0--5) |
| `NGINX_REVERSE_PROXY` | `false` | Nginx als Reverse Proxy vor Jenkins |
| `ENABLE_SSL` | `false` | Selbstsigniertes SSL-Zertifikat (nur mit Nginx) |

### Beispielkonfigurationen

**Minimale Installation** -- nur Jenkins mit Docker:

```bash
TARGET_HOST="10.0.1.50"
SSH_KEY_PATH="~/.ssh/training_key"
SSH_USER="ubuntu"
```

**Produktionsaehnliches Setup** -- mit Nginx, SSL und zusaetzlichen Plugins:

```bash
TARGET_HOST="10.0.1.50"
SSH_KEY_PATH="~/.ssh/training_key"
SSH_USER="ubuntu"
JENKINS_PORT="8080"
JAVA_VERSION="21"
NGINX_REVERSE_PROXY="true"
ENABLE_SSL="true"
INSTALL_PLUGINS="ansible,terraform,kubernetes"
AGENT_COUNT="2"
ADMIN_PASSWORD="MeinSicheresPasswort123"
```

## Deployment-Optionen

```bash
# Vollstaendiges Deployment
./deploy.sh

# Alternative Konfigurationsdatei verwenden
./deploy.sh --config prod.env

# Nur Verbindungs- und Systemcheck
./deploy.sh --preflight-only

# Einzelnen Schritt ausfuehren
./deploy.sh --step 03-jenkins

# Schritte ueberspringen
./deploy.sh --skip 05-docker --skip 06-nginx

# Trockenlauf (zeigt an, was passieren wuerde)
./deploy.sh --dry-run
```

## Installationsschritte

Das Deployment laeuft in folgenden Schritten ab:

| Schritt | Skript | Beschreibung |
|---|---|---|
| 0 | `00-preflight.sh` | SSH-Verbindung, OS-Check, Ressourcen, Internetzugang |
| 1 | `01-base-setup.sh` | System-Update, Basispakete, Firewall (ufw) |
| 2 | `02-java.sh` | OpenJDK Installation |
| 3 | `03-jenkins.sh` | Jenkins Repository, Installation, Port-Konfiguration |
| 4 | `04-plugins.sh` | Plugin-Installation ueber Jenkins CLI |
| 5 | `05-docker.sh` | Docker CE Installation *(optional)* |
| 6 | `06-nginx.sh` | Nginx Reverse Proxy + SSL *(optional)* |
| 7 | `07-agents.sh` | Jenkins-Agenten vorbereiten *(optional)* |
| 8 | `08-finalize.sh` | JCasC anwenden, Admin-User, Health-Check, Zusammenfassung |

Jeder Schritt ist idempotent und kann einzeln mit `--step` ausgefuehrt werden.

## Vorinstallierte Plugins

Folgende Plugins werden standardmaessig installiert:

- **git** -- Git-Integration
- **workflow-aggregator** -- Pipeline-Support
- **docker-workflow** -- Docker in Pipelines
- **blueocean** -- Moderne Jenkins-UI
- **credentials** / **credentials-binding** -- Credential-Management
- **ssh-agent** -- SSH-Agent fuer Pipelines
- **matrix-auth** -- Berechtigungsmatrix
- **configuration-as-code** -- Jenkins Configuration as Code (JCasC)
- **locale** -- Spracheinstellungen
- **antisamy-markup-formatter** -- Sichere HTML-Formatierung

Weitere Plugins koennen ueber den Parameter `INSTALL_PLUGINS` hinzugefuegt werden.

## Projektstruktur

```
.
├── CLAUDE.md              # Technische Anforderungsdokumentation
├── README.md              # Diese Datei
├── config.env.example     # Konfigurationsvorlage
├── deploy.sh              # Haupt-Einstiegspunkt
├── lib/
│   └── common.sh          # Hilfsfunktionen (SSH, Logging, Templates)
├── scripts/
│   ├── 00-preflight.sh    # Verbindungs- und Systemcheck
│   ├── 01-base-setup.sh   # Basispakete und Firewall
│   ├── 02-java.sh         # Java-Installation
│   ├── 03-jenkins.sh      # Jenkins-Installation
│   ├── 04-plugins.sh      # Plugin-Installation
│   ├── 05-docker.sh       # Docker (optional)
│   ├── 06-nginx.sh        # Nginx Reverse Proxy (optional)
│   ├── 07-agents.sh       # Jenkins-Agenten (optional)
│   └── 08-finalize.sh     # Abschluss und Health-Check
└── templates/
    ├── jenkins-casc.yaml  # JCasC-Template
    └── nginx-jenkins.conf # Nginx-Konfiguration
```

## Sicherheitshinweise

- `config.env` und `.jenkins-credentials` sind in `.gitignore` eingetragen und werden nicht versioniert.
- Das Admin-Passwort wird automatisch generiert, wenn keines gesetzt ist.
- Der Setup-Wizard wird deaktiviert -- die Konfiguration erfolgt vollstaendig ueber JCasC.
- Bei Verwendung von `ENABLE_SSL=true` wird ein selbstsigniertes Zertifikat erstellt. Fuer Produktionsumgebungen sollte ein echtes Zertifikat (z.B. via Let's Encrypt) verwendet werden.

## Fehlerbehebung

**SSH-Verbindung schlaegt fehl:**
```bash
# Verbindung manuell testen
ssh -i ~/.ssh/training_key -p 22 ubuntu@10.0.1.50
```

**Jenkins startet nicht:**
```bash
# Logs auf dem Zielsystem pruefen
ssh -i ~/.ssh/training_key ubuntu@10.0.1.50 "sudo journalctl -u jenkins -n 50"
```

**Preflight-Check isoliert ausfuehren:**
```bash
./deploy.sh --preflight-only
```

**Einzelnen Schritt wiederholen:**
```bash
./deploy.sh --step 04-plugins
```

## Weiterbildung

Dieses Projekt ist Teil des Schulungsangebots der Comquent Academy. Weitere Informationen zum Jenkins Expert Training:

**[Jenkins Expert Training -- Comquent Academy](https://comquent.academy/jenkins-expert-training-schulung/)**

## Lizenz

Intern -- Comquent Academy, fuer Trainingszwecke.
