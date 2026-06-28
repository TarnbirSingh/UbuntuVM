# Ubuntu VM

Blanke Ubuntu 22.04 VM mit Multi-User-Zugang für Lehrkontexte. Optional: Node.js-Toolchain und Git-Repo-Klon.

## Konzept

Eine VM, mehrere Linux-Accounts: ein Dozent (Admin mit Sudo) und beliebig viele Studierende, die sich denselben Server teilen. Ressourcenschonend gegenüber "eine VM pro Studi".

Unterstützte Deployment-Strategien (über den CloudStore-Wizard):

- **`one-instance`** — eine VM für den ganzen Kurs, alle Studierenden als Linux-Accounts auf derselben Maschine
- **`one-per-group`** — eine VM pro Projektgruppe, Mitglieder der Gruppe als Accounts auf der jeweiligen VM

`one-per-user` ist bewusst nicht aktiviert (würde das Dozenten-Kontingent von 10 VMs schnell sprengen).

## Parameter

### Allgemein (gilt für alle Instanzen)

| Parameter | Typ | Pflicht | Beschreibung |
|---|---|---|---|
| `app_name` | string | ja | Projektname; wird Hostname und Name des Shared-Folders (`/opt/<app_name>`) |
| `admin_username` | email (user-picker) | ja | Dozent, erhält Sudo-Rechte |
| `students` | list(email) (user-picker, multi) | bei `one-instance` | Alle Studierenden des Kurses |
| `student_groups` | groups (group-builder) | bei `one-per-group` | Projektgruppen |

### Spezifisch (pro Instanz)

| Parameter | Typ | Default | Beschreibung |
|---|---|---|---|
| `flavor_name` | selection | `gp1.small` | VM-Größe |
| `install_nodejs` | bool | `false` | Optional: Node.js + NPM + PM2 + Nodemon + TypeScript + NVM installieren |
| `node_version` | selection | `20` | Node.js Version, nur relevant wenn `install_nodejs` aktiv |
| `git_repo_url` | string | `""` | Optional: Git-Repository in den Shared-Folder klonen |

## Outputs

| Output | Sichtbar | Sensitive | Beschreibung |
|---|---|---|---|
| `instance_id` | nein | nein | VM-ID (intern) |
| `app_name` | ja | nein | Projektname |
| `ssh_command` | ja | nein | SSH-Vorlage (Username einsetzen) |
| `shared_folder_path` | ja | nein | Pfad zum Shared Workspace |
| `admin_credentials` | nein | ja | Dozenten-Login (User/Passwort/SSH) |
| `student_credentials` | nein | ja | Studierenden-Logins (Map email → {user, password, ssh, shared_folder}) |
| `ssh_private_key` | nein | ja | SSH Private Key (RSA 4096) |

## Cloud-Init Ablauf

1. System-Update + Basispakete (`curl`, `git`, `build-essential`, `htop`, `net-tools`, `ufw`, `acl`)
2. SSH-Passwort-Login aktivieren
3. Shared-Folder `/opt/<app_name>` mit Gruppe `workspace`, SetGID-Bit
4. Admin-User mit Sudo + Symlink `~/project` → Shared-Folder
5. Studierenden-Accounts mit Symlink `~/project` → Shared-Folder
6. *Optional* Node.js-Toolchain (wenn `install_nodejs: true`)
7. *Optional* Git-Repo in Shared-Folder klonen (wenn `git_repo_url` gesetzt)
8. UFW: Ports 22, 3000, 8080

## Username-Konvention

E-Mails werden zu Unix-Usernames konvertiert:

| Email | Username |
|---|---|
| `s2327001@student.dhbw-mannheim.de` | `s2327001_student_dhbw-mannheim_de` |
| `prof1@dhbw-mannheim.de` | `prof1_dhbw-mannheim_de` |

Regel: `@` und `.` → `_`, alles lowercase.

## Zugriff

Nach dem Deployment findet der Dozent in der Deployment-Detailansicht des CloudStores die Zugangsdaten. `student_credentials` und `admin_credentials` sind sensitiv und werden nur dort (oder per E-Mail-Versand-Schritt) sichtbar.

### Studierende

Jeder Studierende bekommt einen eigenen Linux-Account auf der VM und teilt sich den Shared-Folder mit den anderen.

1. **SSH-Login mit Passwort:**
   ```bash
   ssh <username>@<floating-ip>
   ```
   Username und Passwort kommen aus `student_credentials[<eigene-email>]`.

2. **Shared-Folder:** `/opt/<app_name>` — gleichzeitig erreichbar über den Symlink `~/project` im Home-Verzeichnis.
   - Gruppe `workspace` mit SetGID-Bit: neue Dateien gehören automatisch der Gruppe, alle Mitglieder können lesen/schreiben.
   - Permissions: `2775` (rwx für Owner und Gruppe, rx für andere).

3. **Eigene Files:** Das Home-Verzeichnis `~` gehört dem User selbst — kein Zugriff durch andere Studierende.

4. **Falls Node installiert ist** (`install_nodejs: true`):
   - `node`, `npm`, `pm2`, `nodemon`, `tsc` global verfügbar
   - NVM unter `/usr/local/nvm` (von Gruppe `workspace` les-/schreibbar)
   - Ports `3000` und `8080` sind offen → eigener Webserver erreichbar unter `http://<floating-ip>:3000`

### Dozent (Admin)

Der Dozent hat zwei Zugriffswege:

1. **Per Passwort wie ein Studierender**, zusätzlich mit `sudo`-Rechten:
   ```bash
   ssh <admin-username>@<floating-ip>
   sudo -i
   ```
   Username und Passwort aus `admin_credentials`.

2. **Per SSH-Key** (für Automation, Diagnose ohne Passwort):
   - `ssh_private_key` aus den Outputs lokal als Datei speichern, `chmod 600`
   - Login als OpenStack-Default-User `ubuntu` (kein Linux-Account aus dem Wizard):
     ```bash
     ssh -i ./key.pem ubuntu@<floating-ip>
     ```

### Typische Admin-Aufgaben

```bash
# User-Übersicht
ls -la /home/

# Passwort eines Studis zurücksetzen
sudo passwd <username>

# Wer ist gerade eingeloggt
who

# Festplatte / RAM-Auslastung
df -h && free -h
```

### Ports

| Port | Zweck | Standardmäßig offen |
|---|---|---|
| 22 | SSH | ja |
| 3000 | Anwendungen (z.B. Node, Python-Webserver) | ja |
| 8080 | Alternative für zweite App | ja |

Weitere Ports muss der Dozent via `sudo ufw allow <port>` öffnen.

## Mock-Modus

Für lokale Tests ohne OpenStack:

```bash
cd terraform
terraform init
terraform apply \
  -var="use_mock_provider=true" \
  -var="deployment_id=test-123" \
  -var="app_name=test-vm" \
  -var='admin_username=prof@dhbw-mannheim.de' \
  -var='students=["s1@dhbw.de","s2@dhbw.de"]'
```

Generiert echte Passwörter und SSH-Keys, erstellt aber keine OpenStack-Ressourcen.
