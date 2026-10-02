#!/bin/bash
# ============================================================
#  SnowFoxOS — CLI Module: System Status & Battery
#  Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)
# ============================================================

cmd_status() {
    header "System Status"

    # ── Uptime ───────────────────────────────────────────────
    local UPTIME
    UPTIME=$(uptime -p | sed 's/up //')
    row "Uptime" "$UPTIME"

    # ── RAM ──────────────────────────────────────────────────
    local RAM_TOTAL RAM_FREE RAM_USED RAM_PCT
    RAM_TOTAL=$(awk '/^MemTotal:/     {print int($2/1024)}' /proc/meminfo)
    RAM_FREE=$(awk  '/^MemAvailable:/ {print int($2/1024)}' /proc/meminfo)
    RAM_USED=$((RAM_TOTAL - RAM_FREE))
    RAM_PCT=$(( RAM_USED * 100 / RAM_TOTAL ))
    row "RAM" "${RAM_USED} MB / ${RAM_TOTAL} MB"
    bar "$RAM_PCT" 100

    # ── Disk ─────────────────────────────────────────────────
    local DISK_USED DISK_TOTAL DISK_PCT
    DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
    DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
    DISK_PCT=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
    row "Disk" "${DISK_USED} / ${DISK_TOTAL}"
    bar "$DISK_PCT" 100

    divider

    # ── CPU ──────────────────────────────────────────────────
    local CPU
    CPU=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)
    row "CPU" "$CPU"

    # ── GPU ──────────────────────────────────────────────────
    local GPU_NAMES
    GPU_NAMES=$(lspci 2>/dev/null | grep -iE "VGA|3D|Display" | sed 's/^[0-9a-f:.]* [^:]*: //' | paste -sd ", " -)
    [[ -n "$GPU_NAMES" ]] && row "GPU" "$GPU_NAMES"

    # ── Network ──────────────────────────────────────────────
    local IP IFACE
    IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}')
    if [[ -n "$IP" ]]; then
        row "Network" "${IP}  (${IFACE})" "$GREEN"
    else
        row "Network" "not connected" "$RED"
    fi

    divider

    # ── Air mode ─────────────────────────────────────────────
    if rfkill list all 2>/dev/null | grep -q "blocked: yes"; then
        row "Air mode" "ACTIVE — wireless off" "$RED"
    else
        row "Air mode" "off" "$GREEN"
    fi

    # ── Microphone ───────────────────────────────────────────
    local MIC_ID
    MIC_ID=$(pactl list sources short 2>/dev/null | grep -v monitor | awk '{print $1}' | head -1)
    if [[ -n "$MIC_ID" ]]; then
        local MIC_MUTE
        MIC_MUTE=$(pactl get-source-mute "$MIC_ID" 2>/dev/null | awk '{print $2}')
        if [[ "$MIC_MUTE" == "yes" ]]; then
            row "Microphone" "disabled" "$RED"
        else
            row "Microphone" "active" "$GREEN"
        fi
    else
        row "Microphone" "none found" "$DGRAY"
    fi

    # ── Camera ───────────────────────────────────────────────
    if ls /dev/video* &>/dev/null; then
        if v4l2-ctl --list-devices &>/dev/null; then
            row "Camera" "available" "$GREEN"
        else
            row "Camera" "disabled" "$RED"
        fi
    else
        row "Camera" "none found" "$DGRAY"
    fi

    divider

    # ── Profile ──────────────────────────────────────────────
    local PROFILE
    PROFILE=$(cat "$HOME/.config/snowfox/profile" 2>/dev/null || echo "balanced")
    row "Profile" "$PROFILE" "$CYAN"

    # ── Node mode ────────────────────────────────────────────
    local NODE_MODE
    NODE_MODE=$(cat "$HOME/.config/snowfox/node-mode" 2>/dev/null || echo "desktop")
    row "Mode" "$NODE_MODE" "$CYAN"

    echo ""
}

cmd_battery() {
    header "Battery Status"

    local BAT_PATH=""
    for p in /sys/class/power_supply/BAT*; do
        [[ -d "$p" ]] && BAT_PATH="$p" && break
    done

    if [[ -z "$BAT_PATH" ]]; then
        warn "No battery found — desktop system?"
        echo ""
        return
    fi

    local STATUS CAPACITY
    STATUS=$(cat "$BAT_PATH/status" 2>/dev/null || echo "Unknown")
    CAPACITY=$(cat "$BAT_PATH/capacity" 2>/dev/null || echo "0")

    # Status label & color
    local STATUS_LABEL STATUS_COLOR
    case "$STATUS" in
        Charging)    STATUS_LABEL="⚡  Charging"  ; STATUS_COLOR="$GREEN"  ;;
        Discharging) STATUS_LABEL="🔋  Discharging" ; STATUS_COLOR="$ORANGE" ;;
        Full)        STATUS_LABEL="✓  Full"       ; STATUS_COLOR="$GREEN"  ;;
        *)           STATUS_LABEL="$STATUS"       ; STATUS_COLOR="$DGRAY"  ;;
    esac

    # Capacity color
    local CAP_COLOR
    if   [[ "$CAPACITY" -ge 60 ]]; then CAP_COLOR="$GREEN"
    elif [[ "$CAPACITY" -ge 30 ]]; then CAP_COLOR="$ORANGE"
    else                                CAP_COLOR="$RED"
    fi

    row "Status" "$STATUS_LABEL" "$STATUS_COLOR"
    row "Charge" "${CAPACITY}%" "$CAP_COLOR"
    bar "$CAPACITY" 100

    divider

    # Power draw
    local POWER_UW=0
    if [[ -f "$BAT_PATH/power_now" ]]; then
        POWER_UW=$(cat "$BAT_PATH/power_now" 2>/dev/null || echo 0)
    elif [[ -f "$BAT_PATH/current_now" && -f "$BAT_PATH/voltage_now" ]]; then
        local CURRENT VOLTAGE
        CURRENT=$(cat "$BAT_PATH/current_now")
        VOLTAGE=$(cat "$BAT_PATH/voltage_now")
        POWER_UW=$(echo "$CURRENT * $VOLTAGE / 1000000" | bc 2>/dev/null || echo 0)
    fi
    if [[ "$POWER_UW" -gt 0 ]]; then
        local POWER_W
        POWER_W=$(echo "scale=1; $POWER_UW / 1000000" | bc 2>/dev/null || echo "?")
        row "Power draw" "${POWER_W} W"
    fi

    # Energy
    local ENERGY_FULL=0 ENERGY_NOW=0
    if [[ -f "$BAT_PATH/energy_full" && -f "$BAT_PATH/energy_now" ]]; then
        ENERGY_FULL=$(cat "$BAT_PATH/energy_full")
        ENERGY_NOW=$(cat "$BAT_PATH/energy_now")
    elif [[ -f "$BAT_PATH/charge_full" && -f "$BAT_PATH/charge_now" && -f "$BAT_PATH/voltage_now" ]]; then
        local VOLTAGE
        VOLTAGE=$(cat "$BAT_PATH/voltage_now")
        ENERGY_FULL=$(echo "$(cat "$BAT_PATH/charge_full") * $VOLTAGE / 1000000" | bc 2>/dev/null || echo 0)
        ENERGY_NOW=$(echo "$(cat "$BAT_PATH/charge_now") * $VOLTAGE / 1000000" | bc 2>/dev/null || echo 0)
    fi
    if [[ "$ENERGY_FULL" -gt 0 ]]; then
        local EF EN
        EF=$(echo "scale=1; $ENERGY_FULL / 1000000" | bc)
        EN=$(echo "scale=1; $ENERGY_NOW  / 1000000" | bc)
        row "Energy" "${EN} Wh / ${EF} Wh"
    fi

    # Remaining time
    if [[ "$POWER_UW" -gt 0 && "$ENERGY_NOW" -gt 0 ]]; then
        if [[ "$STATUS" == "Discharging" ]]; then
            local MINS
            MINS=$(echo "scale=0; ($ENERGY_NOW * 60) / $POWER_UW" | bc 2>/dev/null || echo 0)
            row "Remaining" "~$((MINS/60))h $((MINS%60))m" "$ORANGE"
        elif [[ "$STATUS" == "Charging" && "$ENERGY_FULL" -gt 0 ]]; then
            local MISSING MINS
            MISSING=$((ENERGY_FULL - ENERGY_NOW))
            MINS=$(echo "scale=0; ($MISSING * 60) / $POWER_UW" | bc 2>/dev/null || echo 0)
            row "Full in" "~$((MINS/60))h $((MINS%60))m" "$GREEN"
        fi
    fi

    divider

    # Health
    if [[ -f "$BAT_PATH/energy_full" && -f "$BAT_PATH/energy_full_design" ]]; then
        local FULL DESIGN HEALTH H_COLOR
        FULL=$(cat "$BAT_PATH/energy_full")
        DESIGN=$(cat "$BAT_PATH/energy_full_design")
        HEALTH=$(echo "scale=0; ($FULL * 100) / $DESIGN" | bc 2>/dev/null || echo "?")
        if   [[ "$HEALTH" -ge 80 ]]; then H_COLOR="$GREEN"
        elif [[ "$HEALTH" -ge 60 ]]; then H_COLOR="$ORANGE"
        else                              H_COLOR="$RED"
        fi
        row "Health" "${HEALTH}%" "$H_COLOR"
        bar "$HEALTH" 100
    fi

    echo ""
}
