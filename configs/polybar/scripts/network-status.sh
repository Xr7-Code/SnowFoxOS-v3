#!/bin/bash

# Prüfe WLAN
WLAN_SSID=$(iw dev | grep ssid | awk '{print $2}')
if [ -n "$WLAN_SSID" ]; then
    echo "󰤨 $WLAN_SSID"
    exit 0
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
