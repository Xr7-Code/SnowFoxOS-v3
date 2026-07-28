#!/bin/bash
# ============================================================
#  SnowFoxOS — CLI Modul: Systemdiagnose
#  Wird von /usr/local/bin/snowfox gesourced.
# ============================================================


# ============================================================
# snowfox doctor
# ============================================================
cmd_doctor() {
    local ISSUES=0
    local WARNINGS=0

    _doc_ok()   { echo -e "  ${GREEN}${BOLD}[  OK  ]${RESET} $1"; }
    _doc_warn() { echo -e "  ${ORANGE}${BOLD}[ WARN ]${RESET} $1"; ((WARNINGS++)); }
    _doc_err()  { echo -e "  ${RED}${BOLD}[FEHLER]${RESET} $1"; ((ISSUES++)); }
    _doc_info() { echo -e "  ${CYAN}        ${RESET} $1"; }
    _doc_head() { echo ""; echo -e "${PURPLE}${BOLD}  ▸ $1${RESET}"; echo "  ──────────────────────────────────────────"; }

    divider
    echo -e "${PURPLE}${BOLD}  🦊 SnowFoxOS — Doctor${RESET}"
    echo -e "${GRAY}  Systemdiagnose läuft...${RESET}"
    divider

    # ══════════════════════════════════════════════════════
    # 1. RAM-Analyse
    # ══════════════════════════════════════════════════════
    _doc_head "RAM-Analyse"

    RAM_TOTAL=$(awk '/^MemTotal:/    {print int($2/1024)}' /proc/meminfo)
    RAM_FREE=$(awk  '/^MemAvailable:/{print int($2/1024)}' /proc/meminfo)
    RAM_USED=$((RAM_TOTAL - RAM_FREE))
    RAM_PCT=$(echo "scale=0; $RAM_USED * 100 / $RAM_TOTAL" | bc 2>/dev/null || echo "?")

    if [[ "$RAM_PCT" -ge 90 ]]; then
        _doc_err  "RAM-Auslastung kritisch: ${RAM_USED}MB / ${RAM_TOTAL}MB (${RAM_PCT}%)"
    elif [[ "$RAM_PCT" -ge 70 ]]; then
        _doc_warn "RAM-Auslastung hoch: ${RAM_USED}MB / ${RAM_TOTAL}MB (${RAM_PCT}%)"
    else
        _doc_ok   "RAM: ${RAM_USED}MB / ${RAM_TOTAL}MB (${RAM_PCT}% belegt)"
    fi

    # Swap
    SWAP_TOTAL=$(awk '/^SwapTotal:/{print int($2/1024)}' /proc/meminfo)
    SWAP_FREE=$(awk  '/^SwapFree:/ {print int($2/1024)}' /proc/meminfo)
    SWAP_USED=$((SWAP_TOTAL - SWAP_FREE))
    if [[ "$SWAP_TOTAL" -eq 0 ]]; then
        _doc_warn "Kein Swap aktiv — bei RAM-Engpässen kein Puffer"
    elif [[ "$SWAP_USED" -gt 0 ]]; then
        _doc_warn "Swap in Benutzung: ${SWAP_USED}MB — RAM könnte knapp sein"
    else
        _doc_ok   "Swap: ${SWAP_TOTAL}MB verfügbar, nicht in Benutzung"
    fi

    # ZRAM
    if ls /dev/zram* &>/dev/null 2>&1; then
        _doc_ok   "ZRAM aktiv"
    else
        _doc_warn "ZRAM nicht aktiv — empfohlen für SnowFoxOS (lz4, 50%)"
        _doc_info "Aktivieren: sudo systemctl enable --now systemd-zram-setup@zram0"
    fi

    # Top RAM-Prozesse
    echo ""
    echo -e "  ${GRAY}  Top-5 RAM-Verbraucher:${RESET}"
    ps aux --sort=-%mem 2>/dev/null | awk 'NR>1 && NR<=6 {
        printf "    \033[0;36m%-22s\033[0m %5s%%  %s MB\n", $11, $4, int($6/1024)
    }'

    # ══════════════════════════════════════════════════════
    # 2. Größte installierte Pakete
    # ══════════════════════════════════════════════════════
    _doc_head "Größte installierte Pakete"

    if command -v dpkg-query &>/dev/null; then
        echo -e "  ${GRAY}  Top-10 nach installierter Größe:${RESET}"
        dpkg-query -W --showformat='${Installed-Size}\t${Package}\n' 2>/dev/null \
            | sort -rn | head -10 \
            | awk '{printf "    \033[0;36m%-40s\033[0m %s MB\n", $2, int($1/1024)}'
        _doc_ok "Paketliste analysiert"
    else
        _doc_warn "dpkg-query nicht gefunden"
    fi

    # Waisen-Pakete
    ORPHANS=$(deborphan 2>/dev/null | wc -l)
    if command -v deborphan &>/dev/null && [[ "$ORPHANS" -gt 0 ]]; then
        _doc_warn "${ORPHANS} verwaiste Pakete gefunden — 'sudo deborphan | xargs apt purge -y'"
    elif command -v deborphan &>/dev/null; then
        _doc_ok   "Keine verwaisten Pakete"
    fi

    # apt autoremove
    AUTOREMOVE=$(apt-get --simulate autoremove 2>/dev/null | grep "^Remv" | wc -l)
    if [[ "$AUTOREMOVE" -gt 0 ]]; then
        _doc_warn "${AUTOREMOVE} Pakete können entfernt werden — 'sudo apt autoremove'"
    else
        _doc_ok   "Keine unnötigen Pakete"
    fi

    # ══════════════════════════════════════════════════════
    # 3. Treiber-Check
    # ══════════════════════════════════════════════════════
    _doc_head "Treiber & Hardware"

    # Fehlende Firmware (dmesg)
    MISSING_FW=$(dmesg 2>/dev/null | grep -i "firmware.*failed\|failed to load firmware\|Direct firmware load.*failed" | \
        grep -oP 'for \K[^\s]+' | sort -u)
    if [[ -n "$MISSING_FW" ]]; then
        _doc_err  "Fehlende Firmware erkannt:"
        echo "$MISSING_FW" | while read -r fw; do
            _doc_info "→ $fw"
        done
        _doc_info "Beheben: sudo apt install firmware-linux firmware-linux-nonfree"
    else
        _doc_ok   "Keine fehlende Firmware im dmesg"
    fi

    # Grafiktreiber
    _doc_head "Grafiktreiber"

    GPU_INFO=$(lspci 2>/dev/null | grep -iE "VGA|3D|Display")
    if [[ -z "$GPU_INFO" ]]; then
        _doc_warn "Keine GPU via lspci erkannt"
    else
        echo "$GPU_INFO" | while IFS= read -r line; do
            _doc_info "GPU: $line"
        done
    fi

    # Nvidia
    if lspci 2>/dev/null | grep -qi nvidia; then
        if command -v nvidia-smi &>/dev/null; then
            NV_VER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1)
            _doc_ok   "Nvidia-Treiber installiert (v${NV_VER})"
        else
            _doc_err  "Nvidia GPU erkannt, aber kein Treiber installiert"
            _doc_info "Beheben: sudo apt install nvidia-driver"
        fi
        if command -v envycontrol &>/dev/null; then
            _doc_ok   "envycontrol verfügbar (Hybrid-GPU-Steuerung)"
        else
            _doc_warn "envycontrol nicht installiert"
            _doc_info "Installieren: pip install envycontrol"
        fi
    fi

    # AMD — nur prüfen wenn AMD eine dedizierte/primäre GPU ist
    # Intel Iris Xe hat AMD-ähnliche PCI-IDs auf manchen Systemen → false positive vermeiden
    AMD_GPU=$(lspci 2>/dev/null | grep -iE "AMD|ATI" | grep -iE "VGA|3D|Display" | grep -iv "Intel")
    if [[ -n "$AMD_GPU" ]]; then
        if lsmod 2>/dev/null | grep -qE "amdgpu|radeon"; then
            _doc_ok   "AMD-Treiber (amdgpu/radeon) geladen"
        else
            _doc_warn "AMD GPU erkannt, aber kein Kernelmodul geladen"
            _doc_info "  $AMD_GPU"
        fi
    fi

    # Intel
    if lspci 2>/dev/null | grep -qi "Intel.*Graphics\|Intel.*VGA"; then
        if lsmod 2>/dev/null | grep -q "i915"; then
            _doc_ok   "Intel i915-Treiber geladen"
        else
            _doc_warn "Intel GPU erkannt, aber i915 nicht geladen"
        fi
    fi

    # VA-API / Hardware-Videodekodierung
    if command -v vainfo &>/dev/null; then
        if vainfo &>/dev/null 2>&1; then
            _doc_ok   "VA-API (Hardware-Videodekodierung) verfügbar"
        else
            _doc_warn "VA-API nicht funktionsfähig"
            _doc_info "Pakete: intel-media-va-driver / mesa-va-drivers / nvidia-vaapi-driver"
        fi
    else
        _doc_warn "vainfo nicht installiert — VA-API-Status unbekannt"
        _doc_info "Installieren: sudo apt install vainfo"
    fi

    # ══════════════════════════════════════════════════════
    # 4. i3-Konfiguration
    # ══════════════════════════════════════════════════════
    _doc_head "i3-Konfiguration"

    I3_CFG="$HOME/.config/i3/config"
    if [[ ! -f "$I3_CFG" ]]; then
        _doc_err  "i3-Config nicht gefunden: $I3_CFG"
    else
        # Syntax-Check
        if command -v i3 &>/dev/null; then
            I3_ERR=$(i3 -C -c "$I3_CFG" 2>&1)
            if [[ -z "$I3_ERR" ]]; then
                _doc_ok   "i3-Config Syntax fehlerfrei"
            else
                _doc_err  "Fehler in i3-Config:"
                echo "$I3_ERR" | while IFS= read -r line; do _doc_info "  $line"; done
            fi
        else
            _doc_warn "i3 nicht im PATH — Syntax-Check übersprungen"
        fi

        # Fehlende exec-Binaries im Autostart
        AUTOSTART_MISSING=0
        while IFS= read -r line; do
            # --no-startup-id überspringen, echtes Binary extrahieren
            BIN=$(echo "$line" | sed 's/^exec[[:space:]]*//'                 | sed 's/--no-startup-id[[:space:]]*//'                 | awk '{print $1}')
            [[ -z "$BIN" ]] && continue
            # Tilde expandieren
            BIN="${BIN/#\~/$HOME}"
            BIN_BASE=$(basename "$BIN")
            # Prüfen: im PATH, als absoluter Pfad ausführbar, oder in ~/.config/
            if command -v "$BIN_BASE" &>/dev/null; then
                continue
            elif [[ -x "$BIN" ]]; then
                continue
            elif [[ -x "$HOME/.config/$BIN_BASE" ]]; then
                continue
            else
                _doc_warn "Autostart-Binary nicht gefunden: ${BIN_BASE}"
                AUTOSTART_MISSING=$((AUTOSTART_MISSING+1))
            fi
        done < <(grep "^exec " "$I3_CFG" 2>/dev/null)
        [[ $AUTOSTART_MISSING -eq 0 ]] && _doc_ok "Autostart-Einträge geprüft"
    fi

    # Polybar
    POLY_CFG="$HOME/.config/polybar/config.ini"
    [[ ! -f "$POLY_CFG" ]] && POLY_CFG="$HOME/.config/polybar/config"
    if [[ ! -f "$POLY_CFG" ]]; then
        _doc_warn "Polybar-Config nicht gefunden"
    else
        _doc_ok   "Polybar-Config vorhanden"
        if ! pgrep -x polybar &>/dev/null; then
            _doc_warn "Polybar läuft nicht"
        else
            _doc_ok   "Polybar läuft"
        fi
    fi

    # Rofi
    ROFI_CFG="$HOME/.config/rofi/config.rasi"
    if [[ ! -f "$ROFI_CFG" ]]; then
        _doc_warn "Rofi-Config nicht gefunden: $ROFI_CFG"
    else
        _doc_ok   "Rofi-Config vorhanden"
    fi

    # Dunst
    DUNST_CFG="$HOME/.config/dunst/dunstrc"
    if [[ ! -f "$DUNST_CFG" ]]; then
        _doc_warn "Dunst-Config nicht gefunden: $DUNST_CFG"
    else
        _doc_ok   "Dunst-Config vorhanden"
        if ! pgrep -x dunst &>/dev/null; then
            _doc_warn "Dunst läuft nicht"
        else
            _doc_ok   "Dunst läuft"
        fi
    fi

    # Kitty
    KITTY_CFG="$HOME/.config/kitty/kitty.conf"
    if [[ ! -f "$KITTY_CFG" ]]; then
        _doc_warn "Kitty-Config nicht gefunden"
    else
        _doc_ok   "Kitty-Config vorhanden"
    fi

    # ══════════════════════════════════════════════════════
    # 5. Audio
    # ══════════════════════════════════════════════════════
    _doc_head "Audio (PipeWire)"

    if systemctl --user is-active pipewire &>/dev/null; then
        _doc_ok   "PipeWire läuft"
    else
        _doc_err  "PipeWire läuft nicht"
        _doc_info "Starten: systemctl --user start pipewire pipewire-pulse wireplumber"
    fi

    if systemctl --user is-active wireplumber &>/dev/null; then
        _doc_ok   "WirePlumber läuft"
    else
        _doc_warn "WirePlumber läuft nicht"
    fi

    if command -v pactl &>/dev/null; then
        SINK_COUNT=$(pactl list sinks short 2>/dev/null | wc -l)
        if [[ "$SINK_COUNT" -eq 0 ]]; then
            _doc_warn "Keine Audio-Ausgabegeräte erkannt"
        else
            _doc_ok   "${SINK_COUNT} Audio-Ausgabegerät(e) erkannt"
        fi
    fi

    # ══════════════════════════════════════════════════════
    # 6. Netzwerk & Systemdienste
    # ══════════════════════════════════════════════════════
    _doc_head "Systemdienste"

    # NetworkManager
    if systemctl is-active NetworkManager &>/dev/null; then
        _doc_ok   "NetworkManager läuft"
    else
        _doc_err  "NetworkManager läuft nicht"
        _doc_info "Starten: sudo systemctl start NetworkManager"
    fi

    # Bluetooth
    if systemctl is-active bluetooth &>/dev/null; then
        _doc_ok   "Bluetooth-Dienst läuft"
    else
        _doc_warn "Bluetooth-Dienst läuft nicht"
    fi

    # Fehlgeschlagene Dienste
    FAILED=$(systemctl --failed --no-legend 2>/dev/null | awk '{print $1}' | head -5)
    if [[ -n "$FAILED" ]]; then
        _doc_err  "Fehlgeschlagene Systemdienste:"
        echo "$FAILED" | while read -r svc; do _doc_info "→ $svc"; done
        _doc_info "Details: systemctl status <dienst>"
    else
        _doc_ok   "Keine fehlgeschlagenen Dienste"
    fi

    # ══════════════════════════════════════════════════════
    # 7. Disk & Dateisystem
    # ══════════════════════════════════════════════════════
    _doc_head "Festplatte & Dateisystem"

    DISK_PCT=$(df / | awk 'NR==2 {gsub(/%/,"",$5); print $5}')
    DISK_FREE=$(df -h / | awk 'NR==2 {print $4}')
    if [[ "$DISK_PCT" -ge 90 ]]; then
        _doc_err  "Festplatte fast voll: ${DISK_PCT}% belegt (${DISK_FREE} frei)"
    elif [[ "$DISK_PCT" -ge 75 ]]; then
        _doc_warn "Festplatte: ${DISK_PCT}% belegt (${DISK_FREE} frei)"
    else
        _doc_ok   "Festplatte: ${DISK_PCT}% belegt (${DISK_FREE} frei)"
    fi

    # /tmp
    TMP_SIZE=$(du -sh /tmp 2>/dev/null | awk '{print $1}')
    _doc_info "/tmp belegt: ${TMP_SIZE}"

    # Journald-Größe
    JOURNAL_SIZE=$(journalctl --disk-usage 2>/dev/null | grep -oP '\d+\.\d+[MG]' | head -1)
    if [[ -n "$JOURNAL_SIZE" ]]; then
        _doc_info "Journal-Größe: ${JOURNAL_SIZE} — 'sudo journalctl --vacuum-size=200M' zum Bereinigen"
    fi

    # ══════════════════════════════════════════════════════
    # 8. Sicherheit & Privatsphäre
    # ══════════════════════════════════════════════════════
    _doc_head "Sicherheit & Privatsphäre"

    # Firewall
    if command -v ufw &>/dev/null || dpkg -l ufw &>/dev/null 2>&1; then
        UFW_STATUS=$(sudo ufw status 2>/dev/null | grep "Status:" | awk '{print $2}')
        if [[ "$UFW_STATUS" == "active" ]]; then
            _doc_ok   "UFW Firewall aktiv"
        else
            _doc_warn "UFW Firewall inaktiv — 'sudo ufw enable'"
        fi
    else
        _doc_warn "UFW nicht installiert — 'sudo apt install ufw'"
    fi

    # SSH-Dienst
    if systemctl is-active ssh &>/dev/null || systemctl is-active sshd &>/dev/null; then
        _doc_warn "SSH-Dienst läuft — bei Nichtbenutzung deaktivieren"
        _doc_info "Deaktivieren: sudo systemctl disable --now ssh"
    else
        _doc_ok   "SSH-Dienst nicht aktiv"
    fi

    # Ausstehende Sicherheitsupdates
    SECURITY_UPDATES=$(apt-get --simulate upgrade 2>/dev/null | grep -i "security" | wc -l)
    if [[ "$SECURITY_UPDATES" -gt 0 ]]; then
        _doc_warn "${SECURITY_UPDATES} Sicherheitsupdates verfügbar — 'snowfox update'"
    else
        _doc_ok   "Keine ausstehenden Sicherheitsupdates"
    fi

    # ══════════════════════════════════════════════════════
    # 9. SnowFox-spezifische Checks
    # ══════════════════════════════════════════════════════
    _doc_head "SnowFoxOS-Integrität"

    # CLI selbst
    if [[ -x /usr/local/bin/snowfox ]]; then
        _doc_ok   "snowfox CLI in /usr/local/bin installiert"
    else
        _doc_warn "snowfox CLI nicht in /usr/local/bin — nur lokal ausführbar"
        _doc_info "Installieren: sudo cp ~/snowfox /usr/local/bin/snowfox && sudo chmod +x /usr/local/bin/snowfox"
    fi

    # Profil-Datei
    PROFILE=$(cat "$HOME/.config/snowfox/profile" 2>/dev/null || echo "")
    if [[ -n "$PROFILE" ]]; then
        _doc_ok   "Aktives Profil: ${PROFILE}"
    else
        _doc_warn "Kein Profil gesetzt — Standard 'balanced' wird verwendet"
    fi

    # Wallpaper-Verzeichnis
    if [[ -d "$HOME/wallpapers" ]] ||        [[ -d "$HOME/.config/wallpapers" ]] ||        [[ -d "$HOME/Bilder" ]] ||        [[ -d "$HOME/Pictures" ]] ||        ls "$HOME"/*.{jpg,jpeg,png,webp} &>/dev/null 2>&1; then
        _doc_ok   "Wallpaper-Verzeichnis vorhanden"
    else
        _doc_warn "Wallpaper-Verzeichnis fehlt"
    fi

    # Wichtige Tools
    for tool in git curl gpg pactl rfkill yt-dlp mpv; do
        if command -v "$tool" &>/dev/null; then
            _doc_ok   "$tool verfügbar"
        else
            _doc_warn "$tool nicht installiert"
        fi
    done

    # ══════════════════════════════════════════════════════
    # Zusammenfassung
    # ══════════════════════════════════════════════════════
    echo ""
    divider
    section "Diagnose abgeschlossen"
    if [[ "$ISSUES" -eq 0 && "$WARNINGS" -eq 0 ]]; then
        echo -e "  ${GREEN}${BOLD}✓ System ist in einwandfreiem Zustand.${RESET}"
    else
        [[ "$ISSUES"   -gt 0 ]] && echo -e "  ${RED}${BOLD}✗ Fehler:    ${ISSUES}${RESET}"
        [[ "$WARNINGS" -gt 0 ]] && echo -e "  ${ORANGE}${BOLD}⚠ Warnungen: ${WARNINGS}${RESET}"
    fi
    divider
}
