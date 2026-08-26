#!/bin/bash

# Prüfe WLAN mit ip
WLAN_SSID=$(ip link show | grep -o 'wlan[0-9]' | head -1)
if [ -n "$WLAN_SSID" ]; then
    # Versuche SSID mit nmcli oder iwgetid zu bekommen
    if command -v nmcli &> /dev/null; then
        SSID=$(nmcli -t -f ACTIVE,SSID dev wifi | grep '^ja:' | cut -d: -f2)
        if [ -n "$SSID" ]; then
            echo "󰤨 $SSID"
            exit 0
        fi
    elif command -v iwgetid &> /dev/null; then
        SSID=$(iwgetid -r)
        if [ -n "$SSID" ]; then
            echo "󰤨 $SSID"
            exit 0
        fi
    else
        echo "󰤨 WLAN"
        exit 0
    fi
fi

# Prüfe LAN (Kabel)
for iface in /sys/class/net/en*; do
    if [ -e "$iface/carrier" ]; then
        LAN_STATUS=$(cat "$iface/carrier" 2>/dev/null)
        if [ "$LAN_STATUS" = "1" ]; then
            echo "󰌘 LAN"
            exit 0
        fi
    fi
done

# Keine Verbindung
echo "󰤭 offline"
