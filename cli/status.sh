#!/bin/bash
# SnowFoxOS — CLI Modul: System-Status & Akku

cmd_status() {
    header "System Status"

    # ── Uptime ───────────────────────────────────────────────
    UPTIME=$(uptime -p | sed 's/up //')
    row "Uptime" "$UPTIME"

    # ── RAM ──────────────────────────────────────────────────
    RAM_TOTAL=$(awk '/^MemTotal:/     {print int($2/1024)}' /proc/meminfo)
    RAM_FREE=$(awk  '/^MemAvailable:/ {print int($2/1024)}' /proc/meminfo)
    RAM_USED=$((RAM_TOTAL - RAM_FREE))
    RAM_PCT=$(( RAM_USED * 100 / RAM_TOTAL ))
    row "RAM" "${RAM_USED} MB / ${RAM_TOTAL} MB"
    bar "$RAM_PCT" 100

    # ── Disk ─────────────────────────────────────────────────
    DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
    DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
    DISK_PCT=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
    row "Disk" "${DISK_USED} / ${DISK_TOTAL}"
    bar "$DISK_PCT" 100

    divider

    # ── CPU ──────────────────────────────────────────────────
    CPU=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)
    row "CPU" "$CPU"

    # ── GPU ──────────────────────────────────────────────────
    if command -v envycontrol &>/dev/null; then
        GPU_MODE=$(envycontrol --query 2>/dev/null || echo "unbekannt")
        row "GPU-Modus" "$GPU_MODE"
    fi

    # ── Netzwerk ─────────────────────────────────────────────
    IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}')
    if [[ -n "$IP" ]]; then
        row "Netzwerk" "${IP}  (${IFACE})" "$GREEN"
    else
        row "Netzwerk" "nicht verbunden" "$RED"
    fi

    divider

    # ── Airmode ──────────────────────────────────────────────
    if rfkill list all 2>/dev/null | grep -q "blocked: yes"; then
        row "Airmode" "AKTIV — Funk aus" "$RED"
    else
        row "Airmode" "aus" "$GREEN"
    fi

    # ── Mikrofon ─────────────────────────────────────────────
    MIC_ID=$(pactl list sources short 2>/dev/null | grep -v monitor | awk '{print $1}' | head -1)
    if [[ -n "$MIC_ID" ]]; then
        MIC_MUTE=$(pactl get-source-mute "$MIC_ID" 2>/dev/null | awk '{print $2}')
        [[ "$MIC_MUTE" == "yes" ]] \
            && row "Mikrofon" "deaktiviert" "$RED" \
            || row "Mikrofon" "aktiv" "$GREEN"
    else
        row "Mikrofon" "keines gefunden" "$DGRAY"
    fi

    # ── Kamera ───────────────────────────────────────────────
    if ls /dev/video* &>/dev/null; then
        v4l2-ctl --list-devices &>/dev/null \
            && row "Kamera" "verfügbar" "$GREEN" \
            || row "Kamera" "deaktiviert" "$RED"
    else
        row "Kamera" "keine gefunden" "$DGRAY"
    fi

    divider

    # ── Profil ───────────────────────────────────────────────
    PROFILE=$(cat "$HOME/.config/snowfox/profile" 2>/dev/null || echo "balanced")
    row "Profil" "$PROFILE" "$CYAN"

    echo ""
}

cmd_battery() {
    header "Akku Status"

    BAT_PATH=""
    for p in /sys/class/power_supply/BAT*; do
        [[ -d "$p" ]] && BAT_PATH="$p" && break
    done

    if [[ -z "$BAT_PATH" ]]; then
        warn "Kein Akku gefunden — Desktop-System?"
        echo ""
        return
    fi

    STATUS=$(cat "$BAT_PATH/status" 2>/dev/null || echo "Unbekannt")
    CAPACITY=$(cat "$BAT_PATH/capacity" 2>/dev/null || echo "0")

    # Status-Icon
    case "$STATUS" in
        Charging)    STATUS_LABEL="⚡  Lädt"    ; STATUS_COLOR="$GREEN"  ;;
        Discharging) STATUS_LABEL="🔋  Entlädt"  ; STATUS_COLOR="$ORANGE" ;;
        Full)        STATUS_LABEL="✓  Voll"     ; STATUS_COLOR="$GREEN"  ;;
        *)           STATUS_LABEL="$STATUS"      ; STATUS_COLOR="$DGRAY"  ;;
    esac

    # Ladestand-Farbe
    if   [[ "$CAPACITY" -ge 60 ]]; then CAP_COLOR="$GREEN"
    elif [[ "$CAPACITY" -ge 30 ]]; then CAP_COLOR="$ORANGE"
    else                                CAP_COLOR="$RED"
    fi

    row "Status" "$STATUS_LABEL" "$STATUS_COLOR"
    row "Ladestand" "${CAPACITY}%" "$CAP_COLOR"
    bar "$CAPACITY" 100

    divider

    # Verbrauch
    POWER_UW=0
    if [[ -f "$BAT_PATH/power_now" ]]; then
        POWER_UW=$(cat "$BAT_PATH/power_now" 2>/dev/null || echo 0)
    elif [[ -f "$BAT_PATH/current_now" && -f "$BAT_PATH/voltage_now" ]]; then
        CURRENT=$(cat "$BAT_PATH/current_now")
        VOLTAGE=$(cat "$BAT_PATH/voltage_now")
        POWER_UW=$(echo "$CURRENT * $VOLTAGE / 1000000" | bc 2>/dev/null || echo 0)
    fi
    if [[ "$POWER_UW" -gt 0 ]]; then
        POWER_W=$(echo "scale=1; $POWER_UW / 1000000" | bc 2>/dev/null || echo "?")
        row "Verbrauch" "${POWER_W} W"
    fi

    # Energie
    ENERGY_FULL=0; ENERGY_NOW=0
    if [[ -f "$BAT_PATH/energy_full" && -f "$BAT_PATH/energy_now" ]]; then
        ENERGY_FULL=$(cat "$BAT_PATH/energy_full")
        ENERGY_NOW=$(cat "$BAT_PATH/energy_now")
    elif [[ -f "$BAT_PATH/charge_full" && -f "$BAT_PATH/charge_now" && -f "$BAT_PATH/voltage_now" ]]; then
        VOLTAGE=$(cat "$BAT_PATH/voltage_now")
        ENERGY_FULL=$(echo "$(cat "$BAT_PATH/charge_full") * $VOLTAGE / 1000000" | bc 2>/dev/null || echo 0)
        ENERGY_NOW=$(echo "$(cat "$BAT_PATH/charge_now") * $VOLTAGE / 1000000" | bc 2>/dev/null || echo 0)
    fi
    if [[ "$ENERGY_FULL" -gt 0 ]]; then
        EF=$(echo "scale=1; $ENERGY_FULL / 1000000" | bc)
        EN=$(echo "scale=1; $ENERGY_NOW  / 1000000" | bc)
        row "Energie" "${EN} Wh / ${EF} Wh"
    fi

    # Restzeit
    if [[ "$POWER_UW" -gt 0 && "$ENERGY_NOW" -gt 0 ]]; then
        if [[ "$STATUS" == "Discharging" ]]; then
            MINS=$(echo "scale=0; ($ENERGY_NOW * 60) / $POWER_UW" | bc 2>/dev/null || echo 0)
            row "Restzeit" "~$((MINS/60))h $((MINS%60))m" "$ORANGE"
        elif [[ "$STATUS" == "Charging" && "$ENERGY_FULL" -gt 0 ]]; then
            MISSING=$((ENERGY_FULL - ENERGY_NOW))
            MINS=$(echo "scale=0; ($MISSING * 60) / $POWER_UW" | bc 2>/dev/null || echo 0)
            row "Voll in" "~$((MINS/60))h $((MINS%60))m" "$GREEN"
        fi
    fi

    divider

    # Gesundheit
    if [[ -f "$BAT_PATH/energy_full" && -f "$BAT_PATH/energy_full_design" ]]; then
        FULL=$(cat "$BAT_PATH/energy_full")
        DESIGN=$(cat "$BAT_PATH/energy_full_design")
        HEALTH=$(echo "scale=0; ($FULL * 100) / $DESIGN" | bc 2>/dev/null || echo "?")
        if   [[ "$HEALTH" -ge 80 ]]; then H_COLOR="$GREEN"
        elif [[ "$HEALTH" -ge 60 ]]; then H_COLOR="$ORANGE"
        else                              H_COLOR="$RED"
        fi
        row "Gesundheit" "${HEALTH}%" "$H_COLOR"
        bar "$HEALTH" 100
    fi

    echo ""
}
