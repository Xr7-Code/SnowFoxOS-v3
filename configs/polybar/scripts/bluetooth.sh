#!/bin/bash
# ============================================================
#  SnowFoxOS — Polybar Bluetooth Status Script
#  Pfad: ~/.config/polybar/scripts/bluetooth.sh
# ============================================================

# Polybar Farb-Definitionen (passend zu deiner Palette)
COLOR_CYAN="%{F#89dceb}"
COLOR_GREEN="%{F#a6e3a1}"
COLOR_DIM="%{F#7f849c}"
RESET="%{F-}"

# 1. Bluetooth ausgeschaltet?
if ! bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
    echo "${COLOR_DIM}󰂲 aus${RESET}"
    exit 0
fi

# 2. Verbundenes Gerät ermitteln
DEV=$(bluetoothctl devices Connected 2>/dev/null | head -n1 | cut -d' ' -f3-)

if [[ -n "$DEV" ]]; then
    # Gerät verbunden (Grünes Icon + Gerätename)
    echo "${COLOR_GREEN}󰂱${RESET} $DEV"
else
    # Bluetooth an, aber nicht verbunden (Cyan Icon + "an")
    echo "${COLOR_CYAN}󰂯${RESET} an"
fi
