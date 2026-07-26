#!/bin/bash
# ============================================================
#  SnowFoxOS — CLI Modul: Update, Profil, Node-Modus, System-Reset
#  Wird von /usr/local/bin/snowfox gesourced.
# ============================================================


# ============================================================
# snowfox profile
# ============================================================
PROFILE_FILE="$HOME/.config/snowfox/profile"



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
        "$HOME/SnowFoxOS-v3" \
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
            [[ -d /usr/local/lib/snowfox/cli ]] && cp -r /usr/local/lib/snowfox/cli "$BACKUP_DIR/cli.bak"
            [[ -f "$HOME/.config/snowfox-mesh.sh" ]] && cp "$HOME/.config/snowfox-mesh.sh" "$BACKUP_DIR/snowfox-mesh.bak"
            ok "Backup gespeichert → $BACKUP_DIR"

            # ── CLI aktualisieren ────────────────────────────
            sudo cp "$REPO_DIR/snowfox" /usr/local/bin/snowfox
            sudo chmod +x /usr/local/bin/snowfox
            # cli/-Module nach /usr/local/lib/snowfox/cli/ kopieren
            if [[ -d "$REPO_DIR/cli" ]]; then
                sudo mkdir -p /usr/local/lib/snowfox/cli
                sudo cp "$REPO_DIR/cli/"*.sh /usr/local/lib/snowfox/cli/
                sudo chmod 644 /usr/local/lib/snowfox/cli/*.sh
                ok "snowfox CLI + Module aktualisiert"
            else
                warn "cli/-Verzeichnis nicht im Repo gefunden: $REPO_DIR/cli/"
                ok "snowfox CLI aktualisiert (Module unverändert)"
            fi

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

            # ── Mesh-Modul aktualisieren ─────────────────────
            MESH_SCRIPT_SRC="$REPO_DIR/configs/snowfox-mesh.sh"
            MESH_SCRIPT_DST="$HOME/.config/snowfox-mesh.sh"
            
            if [[ -f "$MESH_SCRIPT_SRC" ]]; then
                cp "$MESH_SCRIPT_SRC" "$MESH_SCRIPT_DST"
                chmod +x "$MESH_SCRIPT_DST"
                ok "Mesh-Modul aktualisiert"
            else
                warn "Mesh-Skript nicht im Repo gefunden: $MESH_SCRIPT_SRC"
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

            # ── Reticulum via pipx aktualisieren ─────────────
            if command -v pipx &>/dev/null && pipx list 2>/dev/null | grep -q rns; then
                info "Reticulum wird aktualisiert..."
                pipx upgrade rns 2>/dev/null && ok "Reticulum aktualisiert" || warn "Reticulum konnte nicht aktualisiert werden"
            elif command -v pip3 &>/dev/null; then
                info "Reticulum wird aktualisiert (pip3)..."
                pip3 install --upgrade rns --break-system-packages 2>/dev/null && ok "Reticulum aktualisiert" || warn "Reticulum konnte nicht aktualisiert werden"
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
# snowfox node
# ============================================================
cmd_node() {
    case "$1" in
        desktop)
            fox "Wechsle zu Desktop-Modus..."
            if grep -q "snowfox_launcher\|SNOWFOX_NODE_CONSOLE" "$HOME/.config/i3/config" 2>/dev/null; then
                sed -i 's|^exec.*snowfox_launcher.*|#&|' "$HOME/.config/i3/config"
                sed -i 's|^exec.*SNOWFOX_NODE_CONSOLE.*|#&|' "$HOME/.config/i3/config"
                ok "Launcher aus i3-Autostart entfernt"
            fi
            ok "Desktop-Modus — i3 wird neu geladen"
            i3-msg restart
            ;;
        server)
            fox "Wechsle zu Server-Modus (kein X11)..."
            ok "Wechsle zu multi-user.target..."
            sudo systemctl isolate multi-user.target
            ;;
        console)
            fox "Starte SnowFox Console Launcher..."
            LAUNCHER="$HOME/Dokumente/SNOWFOX_NODE_CONSOLE/start.sh"
            if [[ ! -f "$LAUNCHER" ]]; then
                err "Launcher nicht gefunden: $LAUNCHER"
                exit 1
            fi
            bash "$LAUNCHER" &
            ok "Console Launcher gestartet"
            ;;
        help|"")
            divider
            echo -e "${PURPLE}${BOLD}  snowfox node — Modus-Wechsel${RESET}"
            divider
            echo -e "  ${CYAN}snowfox node desktop${RESET}   — normaler i3-Desktop, kein Launcher"
            echo -e "  ${CYAN}snowfox node server${RESET}    — Server-Modus, kein X11"
            echo -e "  ${CYAN}snowfox node console${RESET}   — Console Launcher starten"
            divider
            ;;
        *)
            err "Unbekannter Befehl: node $1"
            echo -e "  Hilfe: ${CYAN}snowfox node help${RESET}"
            exit 1
            ;;
    esac
}



# =================================*********=================================
# SCHRITT 3: System komplett zurücksetzen (Werkseinstellung / Neuinstallation)
# =================================*********=================================
function_reset_system() {
    clear
    echo -e "\e[31m######################################################################\e[0m"
    echo -e "\e[31m   WARNUNG: DIESE AKTION LÖSCHT ALLE DEINE PERSÖNLICHEN DATEIEN!      \e[0m"
    echo -e "\e[31m######################################################################\e[0m"
    echo ""
    echo "Das System wird komplett auf die Debian-Basis zurückgesetzt."
    echo "- Alle Dokumente, Bilder, Downloads und persönliche Daten werden GELÖSCHT."
    echo "- Alle installierten Zusatzpakete werden entfernt."
    echo "- Die SnowFoxOS-Konfigurationen werden in den Werkszustand versetzt."
    echo ""
    echo -e "\e[33mBist du dir absolut sicher? Dieser Vorgang kann NICHT rückgängig gemacht werden!\e[0m"
    echo ""
    
    # Sicherheitsabfrage
    read -p "Bitte tippe 'JA' in Großbuchstaben ein, um fortzufahren: " confirm
    
    if [ "$confirm" = "JA" ]; then
        echo ""
        echo -e "\e[32m[+]\e[0m Reset-Vorgang gestartet..."
        sleep 2

        # 1. Entferne alle dotfiles und persönlichen Ordner im Home-Verzeichnis (außer das Skript selbst falls nötig)
        echo -e "\e[34m[*]\e[0m Lösche persönliche Daten und Konfigurationen aus $HOME..."
        # Löscht versteckte Configs und normale Verzeichnisse, behält aber die Umgebung temporär aktiv
        find "$HOME" -mindepth 1 -maxdepth 1 ! -name ".bash_history" -exec rm -rf {} + 2>/dev/null

        # 2. Erstelle die Standard-Debian-Verzeichnisse neu, damit das System stabil bleibt
        echo -e "\e[34m[*]\e[0m Erstelle saubere Standard-Ordnerstruktur..."
        mkdir -p "$HOME/Desktop" "$HOME/Downloads" "$HOME/Dokumente" "$HOME/Bilder" "$HOME/Musik" "$HOME/Videos"

        # 3. Paketmanager aufräumen (Zusatzpakete, die nicht zum Basis-System gehören, entfernen)
        # Löscht ungenutzte Abhängigkeiten und leert den Cache
        echo -e "\e[34m[*]\e[0m Bereinige System-Pakete (apt autoremove & clean)..."
        sudo apt-get autoremove --purge -y
        sudo apt-get clean

        # 4. SnowFoxOS-Originalkonfigurationen frisch aus dem Repository klonen
        echo -e "\e[34m[*]\e[0m Lade originale SnowFoxOS-Konfigurationen neu..."
        REPO_URL="https://github.com/Xr7-Code/SnowFoxOS-v3.git"
        TMP_DIR=$(mktemp -d)
        
        if git clone --depth=1 "$REPO_URL" "$TMP_DIR" 2>/dev/null; then
            # Kopiere die sauberen Configs (i3, polybar, rofi, etc.) ins frische Home-Verzeichnis
            cp -r "$TMP_DIR"/.config "$HOME/" 2>/dev/null
            cp -r "$TMP_DIR"/wallpapers "$HOME/" 2>/dev/null 2>/dev/null
            # Falls das Haupt-Skript wieder im Home-Verzeichnis liegen soll:
            cp "$TMP_DIR"/snowfox "$HOME/" 2>/dev/null
            chmod +x "$HOME/snowfox"
            # CLI-Module systemweit wiederherstellen
            if [[ -d "$TMP_DIR/cli" ]]; then
                sudo mkdir -p /usr/local/lib/snowfox/cli
                sudo cp "$TMP_DIR/cli/"*.sh /usr/local/lib/snowfox/cli/
                sudo chmod 644 /usr/local/lib/snowfox/cli/*.sh
                sudo cp "$TMP_DIR/snowfox" /usr/local/bin/snowfox
                sudo chmod +x /usr/local/bin/snowfox
            fi
            rm -rf "$TMP_DIR"
            echo -e "\e[32m[+]\e[0m Werks-Konfigurationen erfolgreich wiederhergestellt."
        else
            echo -e "\e[31m[!]\e[0m Fehler: Konnte Repository für den Reset nicht klonen. Internetverbindung prüfen.\e[0m"
        fi

        echo ""
        echo -e "\e[32m######################################################################\e[0m"
        echo -e "\e[32m   RESET ABGESCHLOSSEN! Das System ist im Auslieferungszustand.      \e[0m"
        echo -e "\e[32m   Das System wird in 5 Sekunden neu gestartet...                    \e[0m"
        echo -e "\e[32m######################################################################\e[0m"
        sleep 5
        sudo reboot
    else
        echo ""
        echo -e "\e[31m[-] Zurücksetzen abgebrochen. Es wurden keine Änderungen vorgenommen.\e[0m"
        exit 1
    fi
}
