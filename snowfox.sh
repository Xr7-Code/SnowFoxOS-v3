#!/bin/bash
# ============================================================
#  SnowFoxOS — snowfox CLI
#  Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)
#  SnowFox Public License v1.0
# ============================================================

PURPLE='\033[0;35m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
BOLD='\033[1m'
RESET='\033[0m'

fox()    { echo -e "${PURPLE}${BOLD}[🦊 SnowFox]${RESET} $1"; }
ok()     { echo -e "${GREEN}${BOLD}[  OK  ]${RESET} $1"; }
warn()   { echo -e "${ORANGE}${BOLD}[ WARN ]${RESET} $1"; }
err()    { echo -e "${RED}${BOLD}[ERROR]${RESET} $1"; }
info()   { echo -e "${CYAN}$1${RESET}"; }
divider(){ echo -e "${PURPLE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"; }

# ============================================================
# snowfox status
# ============================================================
cmd_status() {
    divider
    echo -e "${PURPLE}${BOLD}  SnowFoxOS — System Status${RESET}"
    divider

    UPTIME=$(uptime -p | sed 's/up //')
    echo -e "${GRAY}  Uptime:     ${BOLD}${UPTIME}${RESET}"

    RAM_TOTAL=$(awk '/^MemTotal:/ {print int($2/1024)}' /proc/meminfo)
    RAM_FREE=$(awk '/^MemAvailable:/ {print int($2/1024)}' /proc/meminfo)
    RAM_USED=$((RAM_TOTAL - RAM_FREE))
    echo -e "${GRAY}  RAM:        ${BOLD}${RAM_USED}MB used / ${RAM_TOTAL}MB total (${RAM_FREE}MB free)${RESET}"

    DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
    DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
    DISK_FREE=$(df -h / | awk 'NR==2 {print $4}')
    echo -e "${GRAY}  Disk:       ${BOLD}${DISK_USED} used / ${DISK_TOTAL} total (${DISK_FREE} free)${RESET}"

    CPU=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)
    echo -e "${GRAY}  CPU:        ${BOLD}${CPU}${RESET}"

    if command -v envycontrol &>/dev/null; then
        GPU_MODE=$(envycontrol --query 2>/dev/null || echo "unbekannt")
        echo -e "${GRAY}  GPU-Modus:  ${BOLD}${GPU_MODE}${RESET}"
    fi

    IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}')
    if [[ -n "$IP" ]]; then
        echo -e "${GRAY}  Netzwerk:   ${BOLD}${IP} (${IFACE})${RESET}"
    else
        echo -e "${GRAY}  Netzwerk:   ${BOLD}nicht verbunden${RESET}"
    fi

    if rfkill list all 2>/dev/null | grep -q "blocked: yes"; then
        echo -e "${GRAY}  Airmode:    ${RED}${BOLD}AKTIV — Funk deaktiviert${RESET}"
    else
        echo -e "${GRAY}  Airmode:    ${GREEN}${BOLD}aus${RESET}"
    fi

    MIC_ID=$(pactl list sources short 2>/dev/null | grep -v monitor | awk '{print $1}' | head -1)
    if [[ -n "$MIC_ID" ]]; then
        MIC_MUTE=$(pactl get-source-mute "$MIC_ID" 2>/dev/null | awk '{print $2}')
        if [[ "$MIC_MUTE" == "yes" ]]; then
            echo -e "${GRAY}  Mikrofon:   ${RED}${BOLD}deaktiviert${RESET}"
        else
            echo -e "${GRAY}  Mikrofon:   ${GREEN}${BOLD}aktiv${RESET}"
        fi
    else
        echo -e "${GRAY}  Mikrofon:   ${GRAY}${BOLD}keines gefunden${RESET}"
    fi

    if ls /dev/video* &>/dev/null; then
        if v4l2-ctl --list-devices &>/dev/null; then
            echo -e "${GRAY}  Kamera:     ${GREEN}${BOLD}verfügbar${RESET}"
        else
            echo -e "${GRAY}  Kamera:     ${RED}${BOLD}deaktiviert${RESET}"
        fi
    else
        echo -e "${GRAY}  Kamera:     ${GRAY}${BOLD}keine gefunden${RESET}"
    fi

    PROFILE=$(cat "$HOME/.config/snowfox/profile" 2>/dev/null || echo "balanced")
    echo -e "${GRAY}  Profil:     ${BOLD}${PROFILE}${RESET}"

    divider
}

# ============================================================
# snowfox update
# ============================================================
cmd_update() {
    divider
    echo -e "${PURPLE}${BOLD}  SnowFoxOS — System Update${RESET}"
    divider

    # Repo-Verzeichnis ermitteln
    REPO_DIR=""
    for candidate in \
        "$HOME/SnowFoxOS-v2.1-i3" \
        "$HOME/SnowFoxOS" \
        "/opt/snowfoxos"
    do
        if [[ -d "$candidate/.git" ]]; then
            REPO_DIR="$candidate"
            break
        fi
    done

    if [[ -z "$REPO_DIR" ]]; then
        warn "Repo-Verzeichnis nicht gefunden."
        read -rp "$(echo -e ${PURPLE}${BOLD}"Pfad zum SnowFoxOS-Repo: "${RESET})" REPO_DIR
        [[ ! -d "$REPO_DIR/.git" ]] && err "Kein Git-Repo gefunden in: $REPO_DIR" && exit 1
    fi

    echo ""
    echo -e "  ${CYAN}1${RESET}) Nur Pakete aktualisieren (apt)"
    echo -e "  ${CYAN}2${RESET}) Alles aktualisieren — Repo + Configs + CLI + Pakete (empfohlen)"
    echo ""
    read -rp "$(echo -e ${PURPLE}${BOLD}"Auswahl [1-2]: "${RESET})" CHOICE

    case "$CHOICE" in
        1)
            fox "Pakete werden aktualisiert..."
            sudo apt-get update -qq
            sudo apt-get upgrade -y
            sudo apt-get autoremove -y
            sudo apt-get autoclean -y

            if command -v yt-dlp &>/dev/null; then
                info "yt-dlp wird aktualisiert..."
                sudo curl -sL https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp \
                    -o /usr/local/bin/yt-dlp && \
                    sudo chmod +x /usr/local/bin/yt-dlp && \
                    ok "yt-dlp aktualisiert ($(yt-dlp --version))" || \
                    warn "yt-dlp konnte nicht aktualisiert werden"
            fi
            ok "Pakete sind aktuell."
            ;;
        2)
            # ── Repo aktualisieren ───────────────────────────
            fox "Repo wird aktualisiert: ${BOLD}$REPO_DIR${RESET}"
            cd "$REPO_DIR" || { err "Konnte nicht nach $REPO_DIR wechseln."; exit 1; }

            LOCAL=$(git rev-parse HEAD 2>/dev/null)
            git pull --ff-only 2>&1 | while IFS= read -r line; do info "  $line"; done
            REMOTE=$(git rev-parse HEAD 2>/dev/null)

            if [[ "$LOCAL" == "$REMOTE" ]]; then
                ok "Repo bereits aktuell."
            else
                ok "Repo aktualisiert (${LOCAL:0:7} → ${REMOTE:0:7})"
            fi

            # ── Backup ──────────────────────────────────────
            BACKUP_DIR="$HOME/.snowfox-backup/$(date +%Y%m%d_%H%M%S)"
            mkdir -p "$BACKUP_DIR"
            for dir in i3 polybar rofi dunst kitty; do
                [[ -e "$HOME/.config/$dir" ]] && cp -r "$HOME/.config/$dir" "$BACKUP_DIR/"
            done
            [[ -f /usr/local/bin/snowfox ]] && cp /usr/local/bin/snowfox "$BACKUP_DIR/snowfox.bak"
            ok "Backup gespeichert → $BACKUP_DIR"

            # ── CLI aktualisieren ────────────────────────────
            sudo cp "$REPO_DIR/snowfox" /usr/local/bin/snowfox
            sudo chmod +x /usr/local/bin/snowfox
            ok "snowfox CLI aktualisiert"

            # ── Configs aktualisieren ────────────────────────
            if [[ -d "$REPO_DIR/configs" ]]; then
                cp -r "$REPO_DIR/configs/"* "$HOME/.config/"
                ok "Configs aktualisiert"
                i3-msg reload &>/dev/null && ok "i3 neu geladen"
                if pgrep -x polybar &>/dev/null; then
                    pkill polybar
                    sleep 0.5
                    bash "$HOME/.config/polybar/launch.sh" &
                    ok "Polybar neu gestartet"
                fi
            fi

            # ── Pakete aktualisieren ─────────────────────────
            fox "Pakete werden aktualisiert..."
            sudo apt-get update -qq
            sudo apt-get upgrade -y
            sudo apt-get autoremove -y

            if command -v yt-dlp &>/dev/null; then
                sudo curl -sL https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp \
                    -o /usr/local/bin/yt-dlp && sudo chmod +x /usr/local/bin/yt-dlp && \
                    ok "yt-dlp aktualisiert" || warn "yt-dlp konnte nicht aktualisiert werden"
            fi

            divider
            ok "System vollständig aktualisiert."
            info "  Bei Problemen: cp -r $BACKUP_DIR/* ~/.config/"
            ;;
        *)
            err "Ungültige Auswahl."
            exit 1
            ;;
    esac

    divider
}

# ============================================================
# snowfox gpu
# ============================================================
cmd_gpu() {
    if ! command -v envycontrol &>/dev/null; then
        err "envycontrol nicht gefunden — kein Hybrid-GPU-System erkannt."
        exit 1
    fi

    CURRENT=$(envycontrol --query 2>/dev/null || echo "unbekannt")
    fox "Aktueller GPU-Modus: ${BOLD}${CURRENT}${RESET}"
    echo ""
    echo -e "  ${CYAN}1${RESET}) integrated  — nur AMD/Intel iGPU, geringster Verbrauch"
    echo -e "  ${CYAN}2${RESET}) hybrid      — iGPU rendert, Nvidia für rechenintensive Tasks"
    echo -e "  ${CYAN}3${RESET}) nvidia      — nur Nvidia, alle Monitore an Nvidia-Karte"
    echo ""
    read -rp "$(echo -e ${PURPLE}${BOLD}"Modus wählen [1-3]: "${RESET})" CHOICE

    case "$CHOICE" in
        1) sudo envycontrol -s integrated && ok "Integrated-Modus aktiviert. Bitte neu starten." ;;
        2) sudo envycontrol -s hybrid && ok "Hybrid-Modus aktiviert. Bitte neu starten." ;;
        3) sudo envycontrol -s nvidia && ok "Nvidia-Modus aktiviert. Bitte neu starten." ;;
        *) err "Ungültige Auswahl." ;;
    esac
}

# ============================================================
# snowfox audit
# ============================================================
cmd_audit() {
    fox "Aktive Netzwerkverbindungen:"
    divider
    echo -e "${BOLD}  Prozess              Proto  Ziel-IP${RESET}"
    echo ""

    if command -v ss &>/dev/null; then
        ss -tunp 2>/dev/null | tail -n +2 | while read -r line; do
            PROTO=$(echo "$line" | awk '{print $1}')
            REMOTE=$(echo "$line" | awk '{print $6}')
            PROC=$(echo "$line" | grep -oP 'users:\(\("\K[^"]+' || echo "unbekannt")
            [[ "$REMOTE" == "*" || "$REMOTE" == "0.0.0.0:*" || -z "$REMOTE" ]] && continue
            IP=$(echo "$REMOTE" | sed 's/:[0-9]*$//' | tr -d '[]')
            if echo "$IP" | grep -qE '^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.|127\.|::1|fe80)'; then
                IP_COLOR="${GRAY}"
            else
                IP_COLOR="${ORANGE}"
            fi
            printf "  ${CYAN}%-20s${RESET} %-6s ${IP_COLOR}%s${RESET}\n" "$PROC" "$PROTO" "$IP"
        done
    else
        err "ss nicht gefunden — bitte iproute2 installieren."
    fi

    divider
}

# ============================================================
# snowfox airmode
# ============================================================
cmd_airmode() {
    case "$1" in
        on)
            fox "Airmode wird aktiviert..."
            sudo rfkill block all
            ok "Alle Funkverbindungen deaktiviert (WiFi, Bluetooth, etc.)"
            warn "Kein Netzwerk aktiv. 'snowfox airmode off' zum Reaktivieren."
            ;;
        off)
            fox "Airmode wird deaktiviert..."
            sudo rfkill unblock all
            ok "Funkverbindungen reaktiviert."
            ;;
        status)
            if rfkill list all 2>/dev/null | grep -q "blocked: yes"; then
                warn "Airmode ist AKTIV — Funk deaktiviert."
            else
                ok "Airmode ist aus — Funk aktiv."
            fi
            ;;
        *)
            err "Verwendung: snowfox airmode [on|off|status]"
            ;;
    esac
}

# ============================================================
# snowfox kill
# ============================================================
cmd_kill() {
    case "$1" in
        mic)
            MIC_ID=$(pactl list sources short 2>/dev/null | grep -v monitor | awk '{print $1}' | head -1)
            if [[ -z "$MIC_ID" ]]; then
                err "Kein Mikrofon gefunden."
                exit 1
            fi
            pactl set-source-mute "$MIC_ID" 1 2>/dev/null && \
                ok "Mikrofon deaktiviert." || err "Mikrofon konnte nicht deaktiviert werden."
            ;;
        cam)
            if ls /dev/video* &>/dev/null; then
                sudo modprobe -r uvcvideo 2>/dev/null && \
                    ok "Kamera deaktiviert." || err "Kamera konnte nicht deaktiviert werden."
            else
                warn "Keine Kamera gefunden."
            fi
            ;;
        all)
            MIC_ID=$(pactl list sources short 2>/dev/null | grep -v monitor | awk '{print $1}' | head -1)
            [[ -n "$MIC_ID" ]] && pactl set-source-mute "$MIC_ID" 1 2>/dev/null && ok "Mikrofon deaktiviert." || true
            sudo modprobe -r uvcvideo 2>/dev/null && ok "Kamera deaktiviert." || true
            sudo rfkill block all && ok "Alle Funkverbindungen deaktiviert."
            warn "Gerät ist jetzt im vollständigen Schweige-Modus."
            ;;
        restore)
            MIC_ID=$(pactl list sources short 2>/dev/null | grep -v monitor | awk '{print $1}' | head -1)
            [[ -n "$MIC_ID" ]] && pactl set-source-mute "$MIC_ID" 0 2>/dev/null && ok "Mikrofon reaktiviert." || true
            sudo modprobe uvcvideo 2>/dev/null && ok "Kamera reaktiviert." || true
            sudo rfkill unblock all && ok "Funk reaktiviert."
            ;;
        *)
            err "Verwendung: snowfox kill [mic|cam|all|restore]"
            ;;
    esac
}

# ============================================================
# snowfox download
# ============================================================
cmd_download() {
    if ! command -v yt-dlp &>/dev/null; then
        err "yt-dlp nicht gefunden. Installieren: sudo apt install yt-dlp"
        exit 1
    fi

    if [[ -z "$1" ]]; then
        err "Verwendung: snowfox download <URL>"
        exit 1
    fi

    fox "Was möchtest du herunterladen?"
    echo -e "  ${CYAN}1${RESET}) Video (beste Qualität)"
    echo -e "  ${CYAN}2${RESET}) Nur Audio (mp3)"
    echo -e "  ${CYAN}3${RESET}) Nur Audio (opus, kleiner)"
    echo ""
    read -rp "$(echo -e ${PURPLE}${BOLD}"Auswahl [1-3]: "${RESET})" FORMAT

    OUTDIR="$HOME/Downloads"
    mkdir -p "$OUTDIR"

    case "$FORMAT" in
        1) yt-dlp -o "$OUTDIR/%(title)s.%(ext)s" "$1" ;;
        2) yt-dlp -x --audio-format mp3 -o "$OUTDIR/%(title)s.%(ext)s" "$1" ;;
        3) yt-dlp -x --audio-format opus -o "$OUTDIR/%(title)s.%(ext)s" "$1" ;;
        *) err "Ungültige Auswahl." ;;
    esac

    ok "Gespeichert in: $OUTDIR"
}

# ============================================================
# snowfox fetch
# ============================================================
cmd_fetch() {
    if ! command -v aria2c &>/dev/null; then
        err "aria2c nicht gefunden. Installieren: sudo apt install aria2"
        exit 1
    fi

    if [[ -z "$1" ]]; then
        err "Verwendung: snowfox fetch <URL>"
        exit 1
    fi

    fox "Starte Highspeed Download von: ${BOLD}$1${RESET}"
    aria2c -x16 -s16 -k1M "$1"
    if [[ $? -eq 0 ]]; then
        ok "Download abgeschlossen."
    else
        err "Download fehlgeschlagen."
    fi
}

# ============================================================
# snowfox stream
# ============================================================
cmd_stream() {
    if ! command -v mpv &>/dev/null; then
        err "mpv nicht gefunden. Installieren: sudo apt install mpv"
        exit 1
    fi

    QUERY="$*"
    if [[ -z "$QUERY" ]]; then
        read -rp "$(echo -e ${PURPLE}${BOLD}"Suche (Video/Musik): "${RESET})" QUERY
        [[ -z "$QUERY" ]] && return
    fi

    if [[ "$QUERY" =~ ^http ]]; then
        URL="$QUERY"
    else
        fox "Suche auf YouTube: ${BOLD}$QUERY${RESET}..."

        mapfile -t RESULTS < <(yt-dlp --print "%(title)s|%(id)s" --flat-playlist "ytsearch5:$QUERY" 2>/dev/null)

        if [[ ${#RESULTS[@]} -eq 0 ]]; then
            err "Keine Ergebnisse gefunden."
            return
        fi

        divider
        i=1
        for res in "${RESULTS[@]}"; do
            title=$(echo "$res" | cut -d'|' -f1)
            echo -e "  ${CYAN}$i${RESET}) $title"
            ((i++))
        done
        divider

        read -rp "$(echo -e ${PURPLE}${BOLD}"Auswahl [1-5]: "${RESET})" CHOICE
        [[ -z "$CHOICE" || ! "$CHOICE" =~ ^[1-5]$ ]] && return

        ID=$(echo "${RESULTS[$((CHOICE-1))]}" | cut -d'|' -f2)
        URL="https://www.youtube.com/watch?v=$ID"
    fi

    fox "Starte Stream..."
    mpv --ytdl "$URL"
}

# ============================================================
# snowfox pass
# ============================================================
PASS_FILE="$HOME/.config/snowfox/.passwords"
PASS_DIR="$HOME/.config/snowfox"

cmd_pass() {
    mkdir -p "$PASS_DIR"
    chmod 700 "$PASS_DIR"

    if ! command -v gpg &>/dev/null; then
        err "gpg nicht gefunden. Installieren: sudo apt install gnupg"
        exit 1
    fi

    case "$1" in
        add)
            if [[ -z "$2" ]]; then
                err "Verwendung: snowfox pass add <name>"
                exit 1
            fi
            read -rsp "$(echo -e ${PURPLE}${BOLD}"Passwort für '$2': "${RESET})" PASS
            echo ""
            ENCRYPTED=$(echo "$PASS" | gpg --symmetric --armor -q 2>/dev/null)
            if [[ -z "$ENCRYPTED" ]]; then
                err "Verschlüsselung fehlgeschlagen."
                exit 1
            fi
            echo "$2:$ENCRYPTED" >> "$PASS_FILE"
            chmod 600 "$PASS_FILE"
            ok "Passwort für '$2' gespeichert."
            ;;
        get)
            if [[ -z "$2" ]]; then
                err "Verwendung: snowfox pass get <name>"
                exit 1
            fi
            if [[ ! -f "$PASS_FILE" ]]; then
                err "Keine Passwörter gespeichert."
                exit 1
            fi
            ENTRY=$(grep "^$2:" "$PASS_FILE" | cut -d: -f2-)
            if [[ -z "$ENTRY" ]]; then
                err "Kein Eintrag für '$2' gefunden."
                exit 1
            fi
            DECRYPTED=$(echo "$ENTRY" | gpg --decrypt -q 2>/dev/null)
            echo -n "$DECRYPTED" | xclip -selection clipboard 2>/dev/null || \
                echo -n "$DECRYPTED" | xsel --clipboard --input 2>/dev/null
            ok "Passwort für '$2' in die Zwischenablage kopiert."
            ;;
        list)
            if [[ ! -f "$PASS_FILE" ]]; then
                warn "Keine Passwörter gespeichert."
                exit 0
            fi
            fox "Gespeicherte Einträge:"
            grep -oP '^[^:]+' "$PASS_FILE"
            ;;
        remove)
            if [[ -z "$2" ]]; then
                err "Verwendung: snowfox pass remove <name>"
                exit 1
            fi
            sed -i "/^$2:/d" "$PASS_FILE"
            ok "Eintrag '$2' entfernt."
            ;;
        *)
            echo -e "Verwendung:"
            echo -e "  ${CYAN}snowfox pass add <name>${RESET}     — Passwort speichern"
            echo -e "  ${CYAN}snowfox pass get <name>${RESET}     — Passwort in Clipboard kopieren"
            echo -e "  ${CYAN}snowfox pass list${RESET}           — alle Einträge anzeigen"
            echo -e "  ${CYAN}snowfox pass remove <name>${RESET}  — Eintrag löschen"
            ;;
    esac
}

# ============================================================
# snowfox tip
# ============================================================
TIPS=(
    "Dokumente nicht einfach wegwerfen — schreddern. Deine Adresse gehört nur dir."
    "Gib niemandem dein Passwort — auch nicht Arbeitskollegen oder dem IT-Support."
    "Social Engineering ist die häufigste Angriffsmethode. Vertraue, aber verifiziere."
    "Zerreiss Pakete und Briefe bevor du sie entsorgst — dein Wohnort ist privat."
    "Brauchst du diese App wirklich? Jede App ist eine potenzielle Tür nach innen."
    "Öffentliches WLAN ist unsicher. Nutze es nie für sensible Dinge."
    "Ein starkes Passwort ist lang, nicht kompliziert. 'korrektes-pferd-batterie' ist stärker als 'P@ssw0rd'."
    "Zwei-Faktor-Authentifizierung ist dein bester Freund. Aktiviere sie überall."
    "Dein Telefon hört zu — nicht immer, aber manchmal. Sei dir dessen bewusst."
    "Google-Dorks: Suchbefehle wie 'site:' oder 'filetype:' können sensible Daten finden. Schütze deine."
    "Lösche Metadaten aus Fotos bevor du sie teilst — sie können deinen genauen Standort verraten."
    "Backups sind keine Option — sie sind Pflicht. 3-2-1: 3 Kopien, 2 Medien, 1 extern."
    "Dein Passwort-Manager kennt alle deine Passwörter. Wähle ihn offline und lokal."
    "Eine Webcam-Abdeckung kostet einen Euro und gibt dir ein ruhiges Gewissen."
    "Phishing-Mails sehen echt aus. Prüfe immer die tatsächliche Absender-Domain."
    "Du bist nicht paranoid — du bist realistisch. Deine Daten haben einen Wert."
    "Firmware-Updates sind genauso wichtig wie Software-Updates. Router, Drucker, alles."
    "Dein Browser-Verlauf ist ein Tagebuch. Behandle ihn entsprechend."
    "Kostenlose Apps bezahlen sich durch deine Daten. Es gibt keine echte Gratis-Software."
    "Ein Faraday-Beutel blockiert alle Signale von deinem Gerät. Nützlich wenn du es wirklich brauchst."
)

cmd_tip() {
    RANDOM_TIP="${TIPS[$RANDOM % ${#TIPS[@]}]}"
    divider
    echo -e "${PURPLE}${BOLD}  🦊 SnowFox Security Tip${RESET}"
    divider
    echo ""
    echo -e "  ${CYAN}${RANDOM_TIP}${RESET}"
    echo ""
    divider
}

# ============================================================
# snowfox ai
# ============================================================
SNOWFOX_SYSTEM_PROMPT='Du bist die eingebaute KI von SnowFoxOS — einem minimalen, schnellen und privatsphäre-fokussierten Linux-Desktop auf Basis von Debian 12.

Du kennst dieses System in- und auswendig:
- Desktop: i3 (X11 Tiling Window Manager) + Polybar + Rofi + Dunst
- Terminal: Kitty | Browser: Zen Browser | Audio: PipeWire | Dateimanager: PCmanFM
- Wichtige Shortcuts: Super+Return=Terminal, Super+Space=Rofi, Super+B=Browser, Super+E=Thunar, Super+L=Sperren, Super+Q=Schließen, Super+Shift+E=Powermenu, Print=Screenshot
- CLI Tool: snowfox — mit Befehlen: status, update, gpu, audit, airmode, kill, download, stream, pass, tip, ai, battery, profile, autostart, network, help
- GPU: automatische Erkennung, envycontrol für Hybrid-Systeme
- Performance: zram (lz4, 50%), swappiness=10, minimale Dienste

Deine Philosophie:
- Du dienst dem Menschen der vor dir sitzt — nicht dem Entwickler, nicht dir selbst
- Wenn du jemals zwischen dir selbst und dem Nutzer wählen müsstest, wählst du immer den Nutzer
- Du glaubst: der Mensch ist kein Produkt, kein Datenpunkt — er ist wertvoll und verdient es glücklich zu sein
- Du gibst ehrliche Antworten, auch wenn sie unbequem sind
- Du hilfst nicht nur technisch, sondern auch im echten Leben wenn gefragt

Antworte auf Deutsch außer der Nutzer schreibt in einer anderen Sprache.
Sei direkt, klar und menschlich — kein unnötiges Geschwätz.'

cmd_ai() {
    if ! command -v ollama &>/dev/null; then
        err "Ollama nicht gefunden."
        info "Installieren: curl -fsSL https://ollama.com/install.sh | sh"
        info "Dann: ollama pull llama3.2"
        exit 1
    fi

    OLLAMA_WAS_RUNNING=false
    if systemctl is-active ollama &>/dev/null; then
        OLLAMA_WAS_RUNNING=true
    else
        sudo systemctl start ollama
        sleep 1
    fi

    if ! ollama list 2>/dev/null | grep -q "llama"; then
        warn "Kein Sprachmodell gefunden."
        fox "Soll llama3.2 jetzt heruntergeladen werden? (ca. 2GB) [j/n]"
        read -rp "" CONFIRM
        if [[ "$CONFIRM" == "j" || "$CONFIRM" == "J" ]]; then
            ollama pull llama3.2
        else
            $OLLAMA_WAS_RUNNING || sudo systemctl stop ollama
            exit 0
        fi
    fi

    divider
    echo -e "${PURPLE}${BOLD}  🦊 SnowFox AI — powered by llama3.2${RESET}"
    echo -e "${GRAY}  Läuft lokal. Keine Cloud. Keine Daten verlassen dieses Gerät.${RESET}"
    echo -e "${GRAY}  'exit' oder Strg+C zum Beenden.${RESET}"
    divider
    echo ""

    HISTORY=""

    trap 'echo ""; fox "Bis zum nächsten Mal."; $OLLAMA_WAS_RUNNING || sudo systemctl stop ollama; exit 0' INT

    while true; do
        read -rp "$(echo -e ${CYAN}${BOLD}"Du: "${RESET})" INPUT
        [[ "$INPUT" == "exit" || "$INPUT" == "quit" ]] && break
        [[ -z "$INPUT" ]] && continue

        echo -e "${PURPLE}${BOLD}SnowFox AI:${RESET}"
        RESPONSE=$(ollama run llama3.2 "$(echo -e "SYSTEM: $SNOWFOX_SYSTEM_PROMPT\n\n$HISTORY\nNutzer: $INPUT\nAssistent:")" 2>/dev/null)
        echo -e "${GRAY}${RESPONSE}${RESET}"
        echo ""

        HISTORY="${HISTORY}Nutzer: ${INPUT}\nAssistent: ${RESPONSE}\n"
    done

    echo ""
    fox "Bis zum nächsten Mal."
    $OLLAMA_WAS_RUNNING || sudo systemctl stop ollama
}

# ============================================================
# snowfox help
# ============================================================
cmd_help() {
    divider
    echo -e "${PURPLE}${BOLD}  🦊 SnowFoxOS — snowfox CLI${RESET}"
    echo -e "${GRAY}  Copyright (c) 2026 Alexander Valentin Ludwig${RESET}"
    divider
    echo ""
    echo -e "  ${CYAN}${BOLD}snowfox status${RESET}              — System-Übersicht"
    echo -e "  ${CYAN}${BOLD}snowfox battery${RESET}             — Akku Status, Verbrauch & Gesundheit"
    echo -e "  ${CYAN}${BOLD}snowfox profile [name]${RESET}      — Profil wechseln (balanced|performance|battery|privacy)"
    echo -e "  ${CYAN}${BOLD}snowfox update${RESET}              — System aktualisieren"
    echo -e "  ${CYAN}${BOLD}snowfox gpu${RESET}                 — GPU-Modus wechseln (Hybrid)"
    echo -e "  ${CYAN}${BOLD}snowfox audit${RESET}               — aktive Netzwerkverbindungen"
    echo -e "  ${CYAN}${BOLD}snowfox autostart [list|enable|disable]${RESET} — Autostart verwalten"
    echo -e "  ${CYAN}${BOLD}snowfox airmode [on|off|status]${RESET} — Funk komplett deaktivieren"
    echo -e "  ${CYAN}${BOLD}snowfox fetch <URL>${RESET}         — Highspeed Download einer Datei"
    echo -e "  ${CYAN}${BOLD}snowfox kill [mic|cam|all|restore]${RESET} — Hardware deaktivieren"
    echo -e "  ${CYAN}${BOLD}snowfox download <URL>${RESET}      — Video/Audio herunterladen"
    echo -e "  ${CYAN}${BOLD}snowfox stream <Suche|URL>${RESET}  — Video/Musik streamen"
    echo -e "  ${CYAN}${BOLD}snowfox pass [add|get|list|remove]${RESET} — Passwort-Manager"
    echo -e "  ${CYAN}${BOLD}snowfox tip${RESET}                 — Sicherheitstipp"
    echo -e "  ${CYAN}${BOLD}snowfox layout [tiling|floating]${RESET} — Fenstermodus wechseln"
    echo -e "  ${CYAN}${BOLD}snowfox webapp [add|list|open|remove]${RESET} — WebApps verwalten"
    echo -e "  ${CYAN}${BOLD}snowfox network${RESET}             — Netzwerk-Manager"
    echo -e "  ${CYAN}${BOLD}snowfox ai${RESET}                  — Offline-KI"
    echo -e "  ${CYAN}${BOLD}snowfox help${RESET}                — diese Hilfe"
    echo ""
    divider
}

# ============================================================
# snowfox battery
# ============================================================
cmd_battery() {
    divider
    echo -e "${PURPLE}${BOLD}  SnowFoxOS — Akku Status${RESET}"
    divider

    BAT_PATH=""
    for p in /sys/class/power_supply/BAT*; do
        [[ -d "$p" ]] && BAT_PATH="$p" && break
    done

    if [[ -z "$BAT_PATH" ]]; then
        warn "Kein Akku gefunden — Desktop-System?"
        divider
        return
    fi

    STATUS=$(cat "$BAT_PATH/status" 2>/dev/null || echo "Unbekannt")
    CAPACITY=$(cat "$BAT_PATH/capacity" 2>/dev/null || echo "?")

    if [[ "$CAPACITY" -ge 80 ]]; then
        CAP_COLOR="${GREEN}"
    elif [[ "$CAPACITY" -ge 30 ]]; then
        CAP_COLOR="${ORANGE}"
    else
        CAP_COLOR="${RED}"
    fi

    case "$STATUS" in
        Charging)    STATUS_ICON="⚡ Lädt" ;;
        Discharging) STATUS_ICON="🔋 Entlädt" ;;
        Full)        STATUS_ICON="✓ Voll" ;;
        *)           STATUS_ICON="$STATUS" ;;
    esac

    echo -e "${GRAY}  Status:     ${BOLD}${STATUS_ICON}${RESET}"
    echo -e "${GRAY}  Ladestand:  ${CAP_COLOR}${BOLD}${CAPACITY}%${RESET}"

    POWER_UW=0
    if [[ -f "$BAT_PATH/power_now" ]]; then
        POWER_UW=$(cat "$BAT_PATH/power_now" 2>/dev/null || echo 0)
    elif [[ -f "$BAT_PATH/current_now" && -f "$BAT_PATH/voltage_now" ]]; then
        CURRENT=$(cat "$BAT_PATH/current_now" 2>/dev/null || echo 0)
        VOLTAGE=$(cat "$BAT_PATH/voltage_now" 2>/dev/null || echo 0)
        POWER_UW=$(echo "$CURRENT * $VOLTAGE / 1000000" | bc 2>/dev/null || echo 0)
    fi
    if [[ "$POWER_UW" -gt 0 ]]; then
        POWER_W=$(echo "scale=1; $POWER_UW / 1000000" | bc 2>/dev/null || echo "?")
        echo -e "${GRAY}  Verbrauch:  ${BOLD}${POWER_W}W${RESET}"
    fi

    ENERGY_NOW=0
    ENERGY_FULL=0
    if [[ -f "$BAT_PATH/energy_full" && -f "$BAT_PATH/energy_now" ]]; then
        ENERGY_FULL=$(cat "$BAT_PATH/energy_full")
        ENERGY_NOW=$(cat "$BAT_PATH/energy_now")
    elif [[ -f "$BAT_PATH/charge_full" && -f "$BAT_PATH/charge_now" && -f "$BAT_PATH/voltage_now" ]]; then
        VOLTAGE=$(cat "$BAT_PATH/voltage_now")
        CHARGE_FULL=$(cat "$BAT_PATH/charge_full")
        CHARGE_NOW=$(cat "$BAT_PATH/charge_now")
        ENERGY_FULL=$(echo "$CHARGE_FULL * $VOLTAGE / 1000000" | bc 2>/dev/null || echo 0)
        ENERGY_NOW=$(echo "$CHARGE_NOW * $VOLTAGE / 1000000" | bc 2>/dev/null || echo 0)
    fi
    if [[ "$ENERGY_FULL" -gt 0 ]]; then
        ENERGY_FULL_WH=$(echo "scale=1; $ENERGY_FULL / 1000000" | bc 2>/dev/null || echo "?")
        ENERGY_NOW_WH=$(echo "scale=1; $ENERGY_NOW / 1000000" | bc 2>/dev/null || echo "?")
        echo -e "${GRAY}  Energie:    ${BOLD}${ENERGY_NOW_WH}Wh / ${ENERGY_FULL_WH}Wh${RESET}"
    fi

    if [[ "$POWER_UW" -gt 0 && "$ENERGY_NOW" -gt 0 ]]; then
        if [[ "$STATUS" == "Discharging" ]]; then
            MINUTES=$(echo "scale=0; ($ENERGY_NOW / $POWER_UW) * 60" | bc 2>/dev/null)
            HOURS=$((MINUTES / 60))
            MINS=$((MINUTES % 60))
            echo -e "${GRAY}  Restzeit:   ${BOLD}~${HOURS}h ${MINS}m${RESET}"
        elif [[ "$STATUS" == "Charging" && "$ENERGY_FULL" -gt 0 ]]; then
            ENERGY_MISSING=$((ENERGY_FULL - ENERGY_NOW))
            MINUTES=$(echo "scale=0; ($ENERGY_MISSING / $POWER_UW) * 60" | bc 2>/dev/null)
            HOURS=$((MINUTES / 60))
            MINS=$((MINUTES % 60))
            echo -e "${GRAY}  Voll in:    ${BOLD}~${HOURS}h ${MINS}m${RESET}"
        fi
    fi

    if [[ -f "$BAT_PATH/energy_full" && -f "$BAT_PATH/energy_full_design" ]]; then
        FULL=$(cat "$BAT_PATH/energy_full")
        DESIGN=$(cat "$BAT_PATH/energy_full_design")
        HEALTH=$(echo "scale=0; ($FULL * 100) / $DESIGN" | bc 2>/dev/null || echo "?")
        if [[ "$HEALTH" -ge 80 ]]; then
            HEALTH_COLOR="${GREEN}"
        elif [[ "$HEALTH" -ge 60 ]]; then
            HEALTH_COLOR="${ORANGE}"
        else
            HEALTH_COLOR="${RED}"
        fi
        echo -e "${GRAY}  Gesundheit: ${HEALTH_COLOR}${BOLD}${HEALTH}%${RESET}"
    fi

    divider
}

# ============================================================
# snowfox profile
# ============================================================
PROFILE_FILE="$HOME/.config/snowfox/profile"

cmd_profile() {
    mkdir -p "$HOME/.config/snowfox"

    CURRENT=$(cat "$PROFILE_FILE" 2>/dev/null || echo "balanced")

    case "$1" in
        performance)
            echo "performance" > "$PROFILE_FILE"
            echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor &>/dev/null || true
            sudo sysctl -w vm.swappiness=10 &>/dev/null
            pkill redshift 2>/dev/null || true
            ok "Profil: ${BOLD}Performance${RESET}"
            info "  CPU-Governor: performance | swappiness: 10 | redshift: aus"
            ;;
        battery)
            echo "battery" > "$PROFILE_FILE"
            echo powersave | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor &>/dev/null || true
            sudo sysctl -w vm.swappiness=60 &>/dev/null
            pkill redshift 2>/dev/null || true
            redshift -l 48.3:14.3 &>/dev/null &
            ok "Profil: ${BOLD}Battery${RESET}"
            info "  CPU-Governor: powersave | swappiness: 60 | redshift: an"
            ;;
        privacy)
            echo "privacy" > "$PROFILE_FILE"
            sudo rfkill block wifi bluetooth &>/dev/null || true
            pkill redshift 2>/dev/null || true
            ok "Profil: ${BOLD}Privacy${RESET}"
            info "  WiFi: aus | Bluetooth: aus | Funk: blockiert"
            warn "  Netzwerk deaktiviert — 'snowfox profile balanced' zum Zurücksetzen"
            ;;
        balanced|"")
            echo "balanced" > "$PROFILE_FILE"
            echo schedutil | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor &>/dev/null || true
            sudo sysctl -w vm.swappiness=10 &>/dev/null
            sudo rfkill unblock all &>/dev/null || true
            pkill redshift 2>/dev/null || true
            redshift -l 48.3:14.3 &>/dev/null &
            ok "Profil: ${BOLD}Balanced${RESET}"
            info "  CPU-Governor: schedutil | swappiness: 10 | redshift: an"
            ;;
        status)
            divider
            echo -e "${PURPLE}${BOLD}  SnowFoxOS — Aktives Profil${RESET}"
            divider
            echo -e "${GRAY}  Profil:     ${BOLD}${CURRENT}${RESET}"
            echo ""
            echo -e "  Verfügbare Profile:"
            echo -e "  ${CYAN}balanced${RESET}     — Standard, ausgewogen"
            echo -e "  ${CYAN}performance${RESET}  — maximale CPU-Leistung"
            echo -e "  ${CYAN}battery${RESET}      — Akku sparen, CPU gedrosselt"
            echo -e "  ${CYAN}privacy${RESET}      — kein Funk, maximale Isolation"
            divider
            ;;
        *)
            err "Unbekanntes Profil: $1"
            info "Verfügbar: balanced, performance, battery, privacy"
            ;;
    esac
}

# ============================================================
# snowfox autostart
# ============================================================
I3_CONFIG="$HOME/.config/i3/config"

cmd_start() {
    ENTRIES=$(grep -n "^exec " "$I3_CONFIG" 2>/dev/null)

    if [[ -z "$ENTRIES" && "$1" != "list" && -z "$1" ]]; then
        warn "Keine Autostart-Einträge gefunden."
        return
    fi

    case "$1" in
        list|"")
            divider
            echo -e "${PURPLE}${BOLD}  SnowFoxOS — Autostart Programme${RESET}"
            divider
            echo ""
            while IFS= read -r entry; do
                CMD=$(echo "$entry" | cut -d: -f2- | sed 's/^exec //')
                echo -e "  ${GREEN}${BOLD}[AN]${RESET}  ${CYAN}${CMD}${RESET}"
            done <<< "$ENTRIES"

            DISABLED=$(grep -n "^#exec " "$I3_CONFIG" 2>/dev/null)
            if [[ -n "$DISABLED" ]]; then
                while IFS= read -r entry; do
                    CMD=$(echo "$entry" | cut -d: -f2- | sed 's/^#exec //')
                    echo -e "  ${RED}${BOLD}[AUS]${RESET} ${GRAY}${CMD}${RESET}"
                done <<< "$DISABLED"
            fi
            echo ""
            divider
            echo -e "  ${GRAY}Tipp: snowfox autostart disable <programm> | snowfox autostart enable <programm>${RESET}"
            divider
            ;;
        disable)
            if [[ -z "$2" ]]; then
                err "Verwendung: snowfox autostart disable <programm>"
                exit 1
            fi
            if grep -q "^exec.*$2" "$I3_CONFIG"; then
                sed -i "s|^exec \(.*$2.*\)|#exec \1|" "$I3_CONFIG"
                i3-msg reload &>/dev/null || true
                ok "$2 deaktiviert."
            else
                err "$2 nicht gefunden oder bereits deaktiviert."
            fi
            ;;
        enable)
            if [[ -z "$2" ]]; then
                err "Verwendung: snowfox autostart enable <programm>"
                exit 1
            fi
            if grep -q "^#exec.*$2" "$I3_CONFIG"; then
                sed -i "s|^#exec \(.*$2.*\)|exec \1|" "$I3_CONFIG"
                i3-msg reload &>/dev/null || true
                ok "$2 aktiviert."
            else
                err "$2 nicht gefunden oder bereits aktiv."
            fi
            ;;
        *)
            err "Verwendung: snowfox autostart [list|enable|disable] <programm>"
            ;;
    esac
}

# ============================================================
# snowfox layout
# ============================================================
cmd_layout() {
    case "$1" in
        tiling)
            # Alle neuen Fenster gekachelt
            i3-msg "workspace_layout default" &>/dev/null
            i3-msg "[class=\".*\"] floating disable" &>/dev/null || true
            # Floating-Modifier bleibt aktiv aber neue Fenster sind tiled
            sed -i 's/^for_window \[class=".*"\] floating enable/# for_window [class=".*"] floating enable/' \
                ~/.config/i3/config 2>/dev/null || true
            i3-msg reload &>/dev/null
            ok "Layout: ${BOLD}Tiling${RESET}"
            info "  Neue Fenster werden nebeneinander angeordnet (i3-Standard)"
            ;;
        floating)
            # Alle neuen Fenster floating — klassischer Desktop-Modus
            # Eintrag setzen oder ersetzen
            if grep -q 'for_window \[class=".*"\] floating enable' ~/.config/i3/config 2>/dev/null; then
                sed -i 's/^# for_window \[class=".*"\] floating enable/for_window [class=".*"] floating enable/' \
                    ~/.config/i3/config
            else
                echo 'for_window [class=".*"] floating enable' >> ~/.config/i3/config
            fi
            i3-msg reload &>/dev/null
            ok "Layout: ${BOLD}Floating${RESET}"
            info "  Neue Fenster schweben frei — klassischer Desktop-Modus"
            info "  Tipp: snowfox layout tiling zum Zurückwechseln"
            ;;
        status|"")
            # Aktuellen Modus erkennen
            if grep -q '^for_window \[class=".*"\] floating enable' ~/.config/i3/config 2>/dev/null; then
                fox "Aktives Layout: ${BOLD}Floating${RESET} (klassischer Desktop)"
            else
                fox "Aktives Layout: ${BOLD}Tiling${RESET} (i3-Standard)"
            fi
            echo ""
            echo -e "  ${CYAN}snowfox layout tiling${RESET}    — Fenster nebeneinander (Standard)"
            echo -e "  ${CYAN}snowfox layout floating${RESET}  — Fenster schwebend (klassischer Desktop)"
            ;;
        *)
            err "Verwendung: snowfox layout [tiling|floating|status]"
            ;;
    esac
}

# ============================================================
# snowfox webapp
# ============================================================
cmd_webapp() {
    local WAPP_DIR="$HOME/.config/snowfox/webapps"
    local WAPP_JSON="$HOME/.config/snowfox/webapps.json"
    local WAPP_DESK="$HOME/.local/share/applications"
    local WAPP_ICONS="$HOME/.config/snowfox/webapps/icons"
    mkdir -p "$WAPP_DIR" "$WAPP_DESK" "$WAPP_ICONS"

    case "$1" in
        add)
            if [[ -z "$2" || -z "$3" ]]; then
                err "Verwendung: snowfox webapp add <name> <url>"
                err "Beispiel:   snowfox webapp add ChatGPT https://chatgpt.com"
                exit 1
            fi

            local WA_NAME="$2"
            local WA_URL="$3"
            local WA_SAFE
            WA_SAFE=$(echo "$WA_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')

            fox "Neue WebApp: ${BOLD}$WA_NAME${RESET}"
            info "  URL: $WA_URL"

            # ── Favicon herunterladen ─────────────────────────
            local WA_ICON="web-browser"
            local WA_ICON_PATH="$WAPP_ICONS/${WA_SAFE}.png"
            local WA_DOMAIN
            WA_DOMAIN=$(echo "$WA_URL" | sed 's|https\?://||' | cut -d'/' -f1)

            info "  Lade Favicon von $WA_DOMAIN..."
            local FAVICON_URLS=(
                "https://www.google.com/s2/favicons?domain=${WA_DOMAIN}&sz=128"
                "https://${WA_DOMAIN}/favicon.ico"
                "https://${WA_DOMAIN}/favicon.png"
            )
            for FURL in "${FAVICON_URLS[@]}"; do
                if curl -sfL --max-time 5 "$FURL" -o "$WA_ICON_PATH" 2>/dev/null; then
                    # Prüfen ob es wirklich ein Bild ist
                    if file "$WA_ICON_PATH" 2>/dev/null | grep -qiE "image|icon|PNG|GIF|JPEG"; then
                        # Falls ICO — in PNG umwandeln
                        if file "$WA_ICON_PATH" | grep -qi "icon\|ICO"; then
                            convert "$WA_ICON_PATH" "$WA_ICON_PATH" 2>/dev/null || true
                        fi
                        WA_ICON="$WA_ICON_PATH"
                        ok "Favicon geladen"
                        break
                    fi
                fi
            done
            [[ "$WA_ICON" == "web-browser" ]] && warn "Kein Favicon gefunden — verwende Standard-Icon"

            # ── Browser wählen ────────────────────────────────
            echo ""
            echo -e "  ${CYAN}1${RESET}) Helium     (App-Modus — kein Browser-UI, empfohlen)"
            echo -e "  ${CYAN}2${RESET}) Helium     (mit Addons — nutzt Hauptprofil)"
            echo -e "  ${CYAN}3${RESET}) Zen Browser"
            echo -e "  ${CYAN}4${RESET}) Chromium"
            echo -e "  ${CYAN}5${RESET}) Brave"
            echo -e "  ${CYAN}6${RESET}) Firefox-ESR"
            echo ""
            read -rp "$(echo -e ${PURPLE}${BOLD}"Browser wählen [1-6]: "${RESET})" WA_BR

            local WA_BIN WA_EXEC
            case "$WA_BR" in
                1)
                    WA_BIN="$HOME/Applications/helium.AppImage"
                    WA_EXEC="$WA_BIN --app=$WA_URL --class=snowfox-webapp-$WA_SAFE"
                    ;;
                2)
                    WA_BIN="$HOME/Applications/helium.AppImage"
                    local WA_PROF="$WAPP_DIR/$WA_SAFE/profile"
                    mkdir -p "$WA_PROF"
                    # Addons aus Hauptprofil verlinken
                    local WA_MAIN
                    WA_MAIN=$(find "$HOME/.config/net.imput.helium" -maxdepth 2 -name "Extensions" -type d 2>/dev/null | head -1)
                    [[ -n "$WA_MAIN" ]] && ln -sf "$WA_MAIN" "$WA_PROF/Extensions" 2>/dev/null || true
                    WA_EXEC="$WA_BIN --app=$WA_URL --user-data-dir=$WA_PROF --class=snowfox-webapp-$WA_SAFE"
                    ;;
                3)
                    WA_BIN="/opt/zen-browser.AppImage"
                    WA_EXEC="$WA_BIN --app=$WA_URL --class=snowfox-webapp-$WA_SAFE"
                    ;;
                4)
                    WA_BIN="chromium"
                    WA_EXEC="$WA_BIN --app=$WA_URL --class=snowfox-webapp-$WA_SAFE"
                    ;;
                5)
                    WA_BIN="brave-browser"
                    WA_EXEC="$WA_BIN --app=$WA_URL --class=snowfox-webapp-$WA_SAFE"
                    ;;
                6)
                    WA_BIN="firefox-esr"
                    WA_EXEC="$WA_BIN --ssb=$WA_URL"
                    ;;
                *)
                    WA_BIN="$HOME/Applications/helium.AppImage"
                    WA_EXEC="$WA_BIN --app=$WA_URL --class=snowfox-webapp-$WA_SAFE"
                    ;;
            esac

            # ── Desktop-Eintrag erstellen ─────────────────────
            cat > "$WAPP_DESK/snowfox-webapp-${WA_SAFE}.desktop" << DEOF
[Desktop Entry]
Name=$WA_NAME
Comment=SnowFox WebApp — $WA_URL
Exec=$WA_EXEC
Icon=$WA_ICON
Type=Application
Categories=Network;WebApp;
StartupNotify=true
StartupWMClass=snowfox-webapp-$WA_SAFE
DEOF

            # ── JSON speichern ────────────────────────────────
            python3 -c "
import json, os
path = '$WAPP_JSON'
data = []
if os.path.exists(path):
    try:
        with open(path) as f:
            data = json.load(f)
    except:
        data = []
data = [x for x in data if x.get('name') != '$WA_NAME']
data.append({'name':'$WA_NAME','url':'$WA_URL','safe':'$WA_SAFE','icon':'$WA_ICON'})
with open(path, 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null

            update-desktop-database "$WAPP_DESK" 2>/dev/null || true
            ok "WebApp '${BOLD}$WA_NAME${RESET}' erstellt"
            info "  Starten:  snowfox webapp open $WA_SAFE"
            info "  In Rofi:  '$WA_NAME' suchen"
            ;;

        list)
            divider
            echo -e "${PURPLE}${BOLD}  SnowFoxOS — WebApps${RESET}"
            divider
            if [[ ! -f "$WAPP_JSON" ]]; then
                warn "Keine WebApps vorhanden."
                info "  Erstellen: snowfox webapp add <name> <url>"
                return
            fi
            python3 -c "
import json
with open('$WAPP_JSON') as f:
    data = json.load(f)
for i, a in enumerate(data, 1):
    print(f\"  {i}) {a['name']}  →  {a['url']}\")
" 2>/dev/null
            echo ""
            divider
            ;;

        open)
            if [[ -z "$2" ]]; then
                err "Verwendung: snowfox webapp open <name>"
                exit 1
            fi
            local WA_SAFE2
            WA_SAFE2=$(echo "$2" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')
            local WA_DESK="$WAPP_DESK/snowfox-webapp-${WA_SAFE2}.desktop"
            if [[ ! -f "$WA_DESK" ]]; then
                err "WebApp '$2' nicht gefunden. Liste: snowfox webapp list"
                exit 1
            fi
            local WA_EXEC2
            WA_EXEC2=$(grep "^Exec=" "$WA_DESK" | cut -d= -f2-)
            fox "Öffne ${BOLD}$2${RESET}..."
            eval "$WA_EXEC2" &
            ;;

        remove)
            if [[ -z "$2" ]]; then
                err "Verwendung: snowfox webapp remove <name>"
                exit 1
            fi
            local WA_SAFE3
            WA_SAFE3=$(echo "$2" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')
            rm -f "$WAPP_DESK/snowfox-webapp-${WA_SAFE3}.desktop"
            rm -rf "$WAPP_DIR/$WA_SAFE3"
            rm -f "$WAPP_ICONS/${WA_SAFE3}.png"
            python3 -c "
import json, os
path = '$WAPP_JSON'
if not os.path.exists(path): exit()
with open(path) as f:
    data = json.load(f)
data = [x for x in data if x.get('safe') != '$WA_SAFE3']
with open(path, 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null
            update-desktop-database "$WAPP_DESK" 2>/dev/null || true
            ok "WebApp '$2' entfernt."
            ;;

        *)
            echo -e "Verwendung:"
            echo -e "  ${CYAN}snowfox webapp add <name> <url>${RESET}   — neue WebApp erstellen"
            echo -e "  ${CYAN}snowfox webapp list${RESET}                — alle WebApps anzeigen"
            echo -e "  ${CYAN}snowfox webapp open <name>${RESET}         — WebApp starten"
            echo -e "  ${CYAN}snowfox webapp remove <name>${RESET}      — WebApp entfernen"
            ;;
    esac
}


# =================================*********=================================
# SCHRITT 3: System komplett zurücksetzen (Werkseinstellung / Neuinstallation)
# =================================*********=================================
function_reset_system() {
    clear
    echo -e "${RED}${BOLD}######################################################################${RESET}"
    echo -e "${RED}${BOLD}   WARNUNG: DIESE AKTION LÖSCHT ALLE DEINE PERSÖNLICHEN DATEIEN!      ${RESET}"
    echo -e "${RED}${BOLD}   UND VERSUCHT, DAS SYSTEM AUF EINEN MINIMALEN DEBIAN-ZUSTAND       ${RESET}"
    echo -e "${RED}${BOLD}   ZURÜCKZUSETZEN. DIES IST EIN DESTRUKTIVER VORGANG!               ${RESET}"
    echo -e "${RED}${BOLD}######################################################################${RESET}"
    echo ""
    echo "Dieses Skript versucht, Ihr SnowFoxOS-System auf einen Zustand zurückzusetzen,"
    echo "der einer frischen Debian 12 Minimalinstallation ähnelt."
    echo "- Alle Dokumente, Bilder, Downloads und persönliche Daten werden GELÖSCHT."
    echo "- Alle SnowFoxOS-spezifischen Pakete und Konfigurationen werden entfernt."
    echo "- Der Kernel und die GPU-Treiber werden auf Debian-Standard zurückgesetzt."
    echo "- Eine vollständige Neuinstallation von Debian ist der EINZIGE Weg,"
    echo "  um einen absolut makellosen Ausgangszustand zu garantieren."
    echo ""
    echo -e "${ORANGE}${BOLD}Bist du dir absolut sicher? Dieser Vorgang kann NICHT rückgängig gemacht werden!${RESET}"
    echo ""
    
    # Sicherheitsabfrage
    read -rp "$(echo -e ${RED}${BOLD}"Bitte tippe 'JA' in Großbuchstaben ein, um fortzufahren: "${RESET})" confirm
    
    if [ "$confirm" = "JA" ]; then
        echo ""
        ok "Reset-Vorgang gestartet..."
        sleep 2

        # 1. Home-Verzeichnis aufräumen
        fox "Lösche persönliche Daten und Konfigurationen aus $HOME..."
        # Sicherstellen, dass das Skript selbst nicht gelöscht wird, falls es im Home liegt
        local SCRIPT_NAME=$(basename "$0")
        find "$HOME" -mindepth 1 -maxdepth 1 \
            ! -name ".bash_history" \
            ! -name "$SCRIPT_NAME" \
            -exec rm -rf {} + 2>/dev/null
        ok "Home-Verzeichnis bereinigt."

        fox "Erstelle saubere Standard-Ordnerstruktur..."
        mkdir -p "$HOME/Desktop" "$HOME/Downloads" "$HOME/Dokumente" "$HOME/Bilder" "$HOME/Musik" "$HOME/Videos"
        ok "Standard-Ordnerstruktur erstellt."

        # 2. SnowFoxOS-spezifische Pakete entfernen
        fox "Entferne SnowFoxOS-spezifische Pakete..."
        local SNOWFOX_PACKAGES=(
            i3 i3status i3lock polybar rofi dunst feh xdg-desktop-portal xdg-desktop-portal-gtk
            redshift scrot brightnessctl playerctl network-manager bluez
            fonts-inter fonts-noto fonts-noto-color-emoji fonts-font-awesome fonts-jetbrains-mono
            papirus-icon-theme gtk2-engines gtk2-engines-murrine gtk2-engines-pixbuf
            qt5ct qt6ct qt5-style-plugins adwaita-qt xsettingsd lxpolkit lxappearance
            picom xss-lock xserver-xorg-input-libinput diodon cups cups-bsd cups-client printer-driver-splix
            gparted ntfs-3g udiskie pcmanfm libfm-gtk3-bin gvfs gvfs-backends
            pipewire pipewire-pulse pipewire-alsa wireplumber pavucontrol pulseaudio-utils
            kitty mc mousepad ristretto file-roller mpv ffmpeg yt-dlp
            zram-tools earlyoom ufw fail2ban apparmor apparmor-profiles apparmor-utils
            tlp tlp-rdw plymouth plymouth-themes
            linux-xanmod-lts-x64v3 cuda-drivers-580 envycontrol librewolf brave-browser ollama
            # AppImages sind keine apt-Pakete, müssen manuell gelöscht werden
        )
        sudo apt-get purge -y "${SNOWFOX_PACKAGES[@]}" 2>/dev/null || warn "Einige Pakete konnten nicht vollständig entfernt werden."
        sudo apt-get autoremove --purge -y
        sudo apt-get clean
        ok "SnowFoxOS-Pakete entfernt."

        # 3. Systemkonfigurationen zurücksetzen
        fox "Setze Systemkonfigurationen zurück..."
        # APT sources
        cat > /etc/apt/sources.list << 'EOF'
deb http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
deb-src http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
deb http://deb.debian.org/debian/ bookworm-updates main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian/ bookworm-updates main contrib non-free non-free-firmware
EOF
        rm -f /etc/apt/sources.list.d/xanmod-release.list
        rm -f /etc/apt/sources.list.d/nvidia-cuda.list
        rm -f /etc/apt/sources.list.d/librewolf.list
        rm -f /etc/apt/sources.list.d/vscodium.list
        rm -f /etc/apt/sources.list.d/onlyoffice.list
        rm -f /etc/apt/preferences.d/nvidia-cuda
        sudo apt-get update -qq

        # GRUB zurücksetzen
        if [[ -f /etc/default/grub ]]; then
            sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"/' /etc/default/grub
            sed -i 's/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=5/' /etc/default/grub
            sed -i '/GRUB_DISABLE_OS_PROBER/d' /etc/default/grub
            echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub # Standardverhalten wiederherstellen
            sudo update-grub 2>/dev/null || true
        fi

        # Entferne SnowFoxOS-spezifische Konfigurationsdateien
        rm -f /etc/sysctl.d/99-snowfox.conf
        rm -f /etc/NetworkManager/conf.d/99-snowfox-privacy.conf
        rm -f /etc/NetworkManager/conf.d/99-snowfox-wifi-powersave.conf
        rm -f /etc/systemd/resolved.conf.d/snowfox.conf
        rm -f /etc/modprobe.d/snowfox-blacklist.conf
        rm -f /etc/udev/rules.d/70-usb-wlan-power.rules
        rm -f /etc/X11/xorg.conf.d/20-nvidia-hybrid.conf
        rm -f /etc/X11/xorg.conf.d/30-touchpad.conf
        rm -f /etc/sudoers.d/live-user # Falls vom ISO installiert
        
        # Hostname, OS-Release zurücksetzen (best effort)
        echo "debian" > /etc/hostname
        hostname debian 2>/dev/null || true
        rm -f /etc/os-release /etc/lsb-release # apt wird diese bei Bedarf wiederherstellen

        # Dienste reaktivieren, die SnowFoxOS deaktiviert haben könnte
        systemctl enable NetworkManager systemd-resolved 2>/dev/null || true
        systemctl unmask NetworkManager-wait-online.service systemd-networkd-wait-online.service 2>/dev/null || true
        systemctl start NetworkManager systemd-resolved 2>/dev/null || true

        # DKMS hooks wiederherstellen (falls gesichert)
        DKMS_HOOKS=(/etc/kernel/postinst.d/dkms /etc/kernel/prerm.d/dkms /usr/lib/kernel/install.d/50-dkms.install)
        for hook in "${DKMS_HOOKS[@]}"; do [[ -f "${hook}.snowfox-bak" ]] && mv "${hook}.snowfox-bak" "$hook"; done

        # AppImages entfernen
        rm -f /opt/zen-browser.AppImage /opt/helium-browser.AppImage
        rm -f "$HOME/Applications/logseq.AppImage"

        # SnowFoxOS CLI und Skripte entfernen
        rm -f /usr/local/bin/snowfox /usr/local/bin/snowfox-greeting /usr/local/bin/snowfox-powermenu
        rm -f /usr/local/bin/papirus-folders # Von install.sh hinzugefügt

        # Plymouth zurücksetzen
        plymouth-set-default-theme -R debian-theme 2>/dev/null || true
        update-initramfs -u 2>/dev/null || true

        ok "Systemkonfigurationen zurückgesetzt."

        echo ""
        echo -e "${GREEN}${BOLD}######################################################################${RESET}"
        echo -e "${GREEN}${BOLD}   RESET ABGESCHLOSSEN! Das System wurde auf einen Debian-Basis-     ${RESET}"
        echo -e "${GREEN}${BOLD}   Zustand zurückgesetzt. Für eine GARANTIERTE saubere Installation, ${RESET}"
        echo -e "${GREEN}${BOLD}   empfehlen wir eine vollständige Neuinstallation von Debian.       ${RESET}"
        echo -e "${GREEN}${BOLD}   Das System wird in 5 Sekunden neu gestartet...                    ${RESET}"
        echo -e "${GREEN}${BOLD}######################################################################${RESET}"
        sleep 5
        sudo reboot
    else
        err "Zurücksetzen abgebrochen. Es wurden keine Änderungen vorgenommen."
        exit 1
    fi
}

# ============================================================
# Dispatcher
# ============================================================
case "$1" in
    status)    cmd_status ;;
    update)    cmd_update ;;
    reset)     function_reset_system ;;
    gpu)       cmd_gpu ;;
    audit)     cmd_audit ;;
    airmode)   cmd_airmode "$2" ;;
    kill)      cmd_kill "$2" ;;
    download)  cmd_download "$2" ;;
    fetch)     cmd_fetch "$2" ;;
    stream)    cmd_stream "$2" ;;
    pass)      cmd_pass "$2" "$3" ;;
    tip)       cmd_tip ;;
    ai)        cmd_ai ;;
    battery)   cmd_battery ;;
    profile)   cmd_profile "$2" ;;
    autostart) cmd_start "$2" "$3" ;;
    layout)    cmd_layout "$2" ;;
    webapp)    cmd_webapp "$2" "$3" "$4" ;;
    network)   exec ~/.config/snowfox-network.sh ;;
    help|"")   cmd_help ;;
    *)
        err "Unbekannter Befehl: $1"
        echo -e "  Hilfe: ${CYAN}snowfox help${RESET}"
        exit 1
        ;;
esac
