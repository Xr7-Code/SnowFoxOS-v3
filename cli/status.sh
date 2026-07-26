#!/bin/bash
# ============================================================
#  SnowFoxOS — CLI Modul: System-Status & Akku
#  Wird von /usr/local/bin/snowfox gesourced.
# ============================================================


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
