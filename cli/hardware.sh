#!/bin/bash
# ============================================================
#  SnowFoxOS — CLI Modul: GPU, Hardware-Kill, Airmode
#  Wird von /usr/local/bin/snowfox gesourced.
# ============================================================


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
