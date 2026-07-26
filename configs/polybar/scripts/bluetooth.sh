#!/bin/bash
# SnowFoxOS — Polybar Bluetooth Status Script
# Externes Script verhindert Backslash-Probleme in der polybar ini-Datei

if ! bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
    echo "aus"
    exit 0
fi

# Verbundenes Gerät ermitteln
DEV=$(bluetoothctl devices Connected 2>/dev/null \
    | head -n1 \
    | awk '{$1=""; $2=""; print $0}' \
    | xargs)

if [[ -n "$DEV" ]]; then
    echo "$DEV"
else
    echo "an"
fi
