#!/bin/bash
# ============================================================
#  SnowFoxOS — Polybar Bluetooth Status & Toggle Script
#  Pfad: ~/.config/polybar/scripts/bluetooth.sh
# ============================================================

COLOR_CYAN="%{F#89dceb}"
COLOR_GREEN="%{F#a6e3a1}"
COLOR_DIM="%{F#7f849c}"
RESET="%{F-}"

# ── 1. Toggle-Logik (wird ausgeführt, wenn in der Bar geklickt wird) ──
if [[ "$1" == "toggle" ]]; then
    if bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
        bluetoothctl power off &>/dev/null || rfkill block bluetooth &>/dev/null
    else
        rfkill unblock bluetooth &>/dev/null
        bluetoothctl power on &>/dev/null
    fi
    exit 0
fi

# ── 2. Status-Anzeige (wird alle X Sekunden von Polybar aufgerufen) ──

# Prüfen, ob Bluetooth eingeschaltet ist
IS_POWERED=$(bluetoothctl show 2>/dev/null | grep "Powered: yes")

if [[ -z "$IS_POWERED" ]]; then
    # Bleibt IMMER sichtbar, auch wenn der Dienst/Sendechip aus ist!
    echo "${COLOR_DIM}󰂲 aus${RESET}"
    exit 0
fi

# Verbundenes Gerät ermitteln
DEV=$(bluetoothctl devices Connected 2>/dev/null | head -n1 | cut -d' ' -f3-)

if [[ -n "$DEV" ]]; then
    # Verbunden (Grünes Icon + Name)
    echo "${COLOR_GREEN}󰂱${RESET} $DEV"
else
    # Aktiviert, aber nicht verbunden (Cyan Icon + "an")
    echo "${COLOR_CYAN}󰂯${RESET} an"
fi
