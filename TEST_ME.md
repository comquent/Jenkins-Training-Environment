# Testanleitung

Diese Anleitung beschreibt, was zum Testen des Jenkins Training Environment benoetig wird und wie man es Schritt fuer Schritt validiert.

## Voraussetzungen

### 1. Eine Ubuntu-VM

| Option | Aufwand | Kosten |
|---|---|---|
| **Multipass** (lokal) | 2 Min. | kostenlos |
| **Vagrant + VirtualBox** (lokal) | 5 Min. | kostenlos |
| **Hetzner Cloud** (CX22) | 2 Min. | ~0,01 EUR/h |
| **AWS EC2** (t3.medium) | 5 Min. | ~0,04 EUR/h |
| **DigitalOcean** Droplet | 2 Min. | ~0,03 EUR/h |

**Mindestausstattung:** Ubuntu 22.04 oder 24.04 LTS, 2 vCPUs, 4 GB RAM, 20 GB Disk

### 2. SSH-Zugang

- Ein SSH-Keypair. Falls nicht vorhanden:
  ```bash
  ssh-keygen -t ed25519 -f ~/.ssh/jenkins-training
  ```
- Der Public Key muss auf der VM in `~/.ssh/authorized_keys` hinterlegt sein
- Der VM-Benutzer braucht passwortloses sudo:
  ```bash
  echo 'ubuntu ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/ubuntu
  ```

### 3. Netzwerk

- **Port 22** -- SSH-Zugang
- **Port 8080** -- Jenkins (direkt, ohne Nginx)
- **Port 80 + 443** -- nur wenn `DOMAIN_NAME` mit Let's Encrypt getestet werden soll

### 4. Fuer Let's Encrypt SSL (optional)

- Eine echte Domain (z.B. `jenkins.deinedomain.de`)
- Ein DNS-A-Record, der auf die oeffentliche IP der VM zeigt
- Port 80 von aussen erreichbar (Firewall / Security Group)

Ohne Domain kann alles ausser SSL getestet werden.

### 5. Hinweis zu Passwoertern mit Sonderzeichen

Passwoerter mit `$`-Zeichen muessen in `config.env` in **einfachen** Anfuehrungszeichen stehen, damit die Shell das `$` nicht expandiert:

```bash
# Richtig:
ADMIN_PASSWORD='mein$passwort'

# Falsch ($ wird von der Shell interpretiert):
ADMIN_PASSWORD="mein$passwort"
```

---

## Variante A: Lokal mit Multipass (kostenlos, ohne SSL)

```bash
# 1. VM erstellen
multipass launch --name jenkins-test --cpus 2 --memory 4G --disk 20G 22.04

# 2. IP herausfinden
multipass info jenkins-test | grep IPv4

# 3. SSH-Key hinterlegen
multipass exec jenkins-test -- bash -c \
  "echo '$(cat ~/.ssh/jenkins-training.pub)' >> ~/.ssh/authorized_keys"

# 4. config.env anlegen
cat > config.env <<'EOF'
TARGET_HOST="<IP aus Schritt 2>"
SSH_KEY_PATH="~/.ssh/jenkins-training"
SSH_USER="ubuntu"
EOF

# 5. Deployen
./deploy.sh
```

**Aufraeumen:**
```bash
multipass delete jenkins-test && multipass purge
```

---

## Variante B: Hetzner Cloud (mit Let's Encrypt SSL)

```bash
# 1. VM erstellen (CLI oder Web-Console)
hcloud server create \
  --name jenkins-test \
  --type cx22 \
  --image ubuntu-24.04 \
  --ssh-key <dein-key-name>

# 2. DNS-Record setzen (bei deinem Domain-Provider)
#    jenkins-test.deinedomain.de  ->  <Server-IP>

# 3. config.env anlegen
cat > config.env <<'EOF'
TARGET_HOST="<Server-IP>"
SSH_KEY_PATH="~/.ssh/jenkins-training"
SSH_USER="root"
DOMAIN_NAME="jenkins-test.deinedomain.de"
LETSENCRYPT_EMAIL="deine@email.de"
EOF

# 4. Deployen
./deploy.sh
```

**Aufraeumen:**
```bash
hcloud server delete jenkins-test
```

---

## Variante C: AWS EC2

```bash
# 1. VM erstellen
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \
  --instance-type t3.medium \
  --key-name <dein-key-name> \
  --security-group-ids <sg-id> \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=jenkins-test}]'

# 2. Security Group: Ports 22, 80, 443, 8080 freigeben

# 3. config.env anlegen
cat > config.env <<'EOF'
TARGET_HOST="<Public-IP>"
SSH_KEY_PATH="~/.ssh/<dein-key>.pem"
SSH_USER="ubuntu"
DOMAIN_NAME="jenkins-test.deinedomain.de"
LETSENCRYPT_EMAIL="deine@email.de"
EOF

# 4. Deployen
./deploy.sh
```

**Aufraeumen:**
```bash
aws ec2 terminate-instances --instance-ids <instance-id>
```

---

## Testplan

### Stufe 1: Preflight-Check

Prueft ob die VM erreichbar und geeignet ist, ohne etwas zu installieren:

```bash
./deploy.sh --preflight-only
```

Erwartetes Ergebnis:
- SSH-Verbindung erfolgreich
- Ubuntu erkannt
- sudo-Rechte vorhanden
- Systemressourcen ausreichend
- Internetzugang vorhanden
- (bei DOMAIN_NAME) DNS-Aufloesung erfolgreich

### Stufe 2: Dry-Run

Zeigt an, welche Schritte ausgefuehrt wuerden:

```bash
./deploy.sh --dry-run
```

### Stufe 3: Vollstaendiges Deployment

```bash
./deploy.sh
```

Erwartetes Ergebnis:
- Alle Schritte laufen ohne Fehler durch
- Am Ende wird eine Zusammenfassung mit URL, Admin-User und Passwort angezeigt
- Zugangsdaten liegen in `.jenkins-credentials`

### Stufe 4: Funktionstest im Browser

1. Jenkins-URL im Browser oeffnen (aus der Zusammenfassung)
2. Mit Admin-User und Passwort einloggen
3. Pruefen:
   - Dashboard wird angezeigt
   - Ordner `smoke-tests` mit 7 Pipeline-Jobs ist sichtbar
   - Plugins sind installiert (unter *Jenkins verwalten > Plugins*)
   - (bei SSL) Zertifikat ist gueltig (Schloss-Symbol im Browser)

### Stufe 5: Smoke-Test Pipeline Jobs

Nach dem Deployment werden automatisch 7 Pipeline-Jobs im Ordner `smoke-tests` angelegt. Diese validieren die gesamte Jenkins-Konfiguration:

| Job | Was wird geprueft | Erwartetes Ergebnis |
|---|---|---|
| `01 - System Info` | Host-Info, Java, Jenkins-Umgebung, Netzwerk | System- und Jenkins-Variablen werden ausgegeben |
| `02 - Docker Test` | Docker CLI, `docker run`, `docker build` | hello-world laeuft, Image wird gebaut |
| `03 - Docker Agent` | Pipeline-Stages in Docker-Containern (Alpine, Ubuntu) | Beide Container starten und fuehren Befehle aus |
| `04 - Credentials Test` | Credential-Store erreichbar | HTTP 200 vom Credentials-Endpoint |
| `05 - Pipeline Features` | Parallele Stages, Stash/Unstash, Artefakte | Parallele Ausfuehrung, Artefakt wird archiviert |
| `06 - Git Test` | Git-Installation, Repository klonen | Repo wird geklont, git log zeigt Commits |
| `07 - SSL & Nginx Check` | Nginx-Status, Zertifikat, HTTPS | Nginx laeuft, HTTPS antwortet mit 200 |

**Jobs im Browser ausfuehren:**

1. Im Jenkins-Dashboard den Ordner `smoke-tests` oeffnen
2. Jeden Job einzeln starten (Play-Button)
3. Build-Ergebnis pruefen: gruener Haken = SUCCESS

**Jobs per CLI ausfuehren (auf der VM):**

```bash
# Auf der VM einloggen
ssh -i <key> <user>@<host>

# Alle Smoke-Tests nacheinander ausfuehren
JENKINS="http://localhost:8080"
PASS='<admin-passwort>'  # Single Quotes bei $-Zeichen!
AUTH="admin:${PASS}"

CRUMB=$(curl -s -u "$AUTH" "$JENKINS/crumbIssuer/api/json" \
  | python3 -c "import sys,json;d=json.load(sys.stdin);print(d['crumbRequestField']+':'+d['crumb'])")

for job in 01-system-info 02-docker-test 03-docker-agent \
           04-credentials-test 05-pipeline-features \
           06-git-test 07-ssl-check; do

  echo -n "Starte $job... "
  curl -s -X POST -u "$AUTH" -H "$CRUMB" \
    "$JENKINS/job/smoke-tests/job/$job/build"

  # Warten bis fertig
  sleep 5
  while true; do
    RESULT=$(curl -s -u "$AUTH" \
      "$JENKINS/job/smoke-tests/job/$job/lastBuild/api/json" \
      | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('result') or 'RUNNING')" 2>/dev/null)
    [ "$RESULT" != "RUNNING" ] && break
    sleep 3
  done
  echo "$RESULT"
done
```

**Erwartete Ausgabe:**

```
Starte 01-system-info... SUCCESS
Starte 02-docker-test... SUCCESS
Starte 03-docker-agent... SUCCESS
Starte 04-credentials-test... SUCCESS
Starte 05-pipeline-features... SUCCESS
Starte 06-git-test... SUCCESS
Starte 07-ssl-check... SUCCESS
```

Falls ein Job fehlschlaegt, kann der Konsolen-Output im Browser oder per CLI eingesehen werden:

```bash
curl -s -u "$AUTH" "$JENKINS/job/smoke-tests/job/<job-name>/lastBuild/consoleText"
```

### Stufe 6: Einzelschritte testen

Jeden Deployment-Schritt einzeln ausfuehren, um gezielte Fehler zu finden:

```bash
./deploy.sh --step 00-preflight
./deploy.sh --step 01-base-setup
./deploy.sh --step 02-java
./deploy.sh --step 03-jenkins
./deploy.sh --step 04-plugins
./deploy.sh --step 05-docker
./deploy.sh --step 06-nginx
./deploy.sh --step 08-finalize
```

### Stufe 7: Idempotenz-Test

Das Deployment ein zweites Mal ausfuehren -- es darf keine Fehler geben:

```bash
./deploy.sh
```

Danach die Smoke-Tests erneut ausfuehren und pruefen, dass alle weiterhin SUCCESS sind.

### Stufe 8: Skip-Test

Optionale Schritte ueberspringen:

```bash
./deploy.sh --skip 05-docker --skip 06-nginx
```

**Hinweis:** Wenn Docker uebersprungen wird, schlagen die Smoke-Tests `02 - Docker Test` und `03 - Docker Agent` fehl. Das ist erwartetes Verhalten.

---

## Zusammenfassung: Gesamttest-Checkliste

```
[ ] Stufe 1: Preflight-Check bestanden
[ ] Stufe 2: Dry-Run zeigt alle Schritte
[ ] Stufe 3: Deployment laeuft fehlerfrei durch
[ ] Stufe 4: Jenkins im Browser erreichbar, Login funktioniert
[ ] Stufe 5: Smoke-Tests
    [ ] 01 - System Info:       SUCCESS
    [ ] 02 - Docker Test:       SUCCESS
    [ ] 03 - Docker Agent:      SUCCESS
    [ ] 04 - Credentials Test:  SUCCESS
    [ ] 05 - Pipeline Features: SUCCESS
    [ ] 06 - Git Test:          SUCCESS
    [ ] 07 - SSL & Nginx Check: SUCCESS
[ ] Stufe 6: Einzelschritte funktionieren
[ ] Stufe 7: Idempotenz-Test bestanden
[ ] Stufe 8: Skip-Test funktioniert
```

---

## Fehlerdiagnose auf der VM

```bash
# SSH auf die VM
ssh -i ~/.ssh/jenkins-training <user>@<ip>

# Jenkins-Status
sudo systemctl status jenkins

# Jenkins-Logs (letzte 100 Zeilen)
sudo journalctl -u jenkins -n 100

# Jenkins-Logs filtern nach Fehlern
sudo journalctl -u jenkins | grep -i 'SEVERE\|ERROR'

# Nginx-Status (falls installiert)
sudo systemctl status nginx
sudo nginx -t

# Let's Encrypt Zertifikat pruefen (falls konfiguriert)
sudo certbot certificates

# Docker-Status (falls installiert)
docker info
docker ps -a

# Offene Ports pruefen
sudo ss -tlnp

# Jenkins Configuration as Code pruefen
cat /var/lib/jenkins/casc_configs/jenkins.yaml

# Installierte Plugins auflisten
ls /var/lib/jenkins/plugins/*.jpi | sed 's|.*/||;s|\.jpi||' | sort

# Smoke-Test Ergebnisse per API abfragen
PASS='<admin-passwort>'
for job in 01-system-info 02-docker-test 03-docker-agent \
           04-credentials-test 05-pipeline-features \
           06-git-test 07-ssl-check; do
  R=$(curl -s -u "admin:${PASS}" \
    "http://localhost:8080/job/smoke-tests/job/$job/lastBuild/api/json" \
    | python3 -c "import sys,json;print(json.load(sys.stdin)['result'])" 2>/dev/null)
  printf "%-25s %s\n" "$job" "${R:-NOT_RUN}"
done
```

## Bekannte Hinweise

- **Jenkins GPG-Key:** Der offizielle Download-Key (`jenkins.io-2023.key`) ist seit 26.03.2026 abgelaufen. Das Skript holt den aktuellen Key (`7198F4B714ABFC68`) vom Ubuntu-Keyserver.
- **Passwoerter mit Sonderzeichen:** In `config.env` muessen Werte mit `$`, `` ` `` oder `\` in einfache Anfuehrungszeichen gesetzt werden.
- **JCasC und Plugins:** Die Smoke-Test-Jobs werden beim Jenkins-Start automatisch ueber JCasC + Job DSL angelegt. Bei einem Neustart werden sie ggf. neu erstellt.
