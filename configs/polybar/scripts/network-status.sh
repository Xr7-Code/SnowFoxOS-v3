#!/bin/bash

# Prüfe mit nmcli
if command -v nmcli &> /dev/null; then
    # WLAN SSID
    SSID=$(nmcli -t -f ACTIVE,SSID dev wifi | grep '^ja:' | cut -d: -f2)
    if [ -n "$SSID" ]; then
        echo "󰤨 $SSID"
        exit 0
    fi
    
    # Prüfe LAN
    CONNECTIONS=$(nmcli -t -f TYPE,STATE device status | grep '^ethernet:verbunden' || true)
    if [ -n "$CONNECTIONS" ]; then
        echo "󰌘 LAN"
        exit 0
    fi
fi

# Fallback: manuelle Prüfung
# Prüfe WLAN mit iwgetid
if command -v iwgetid &> /dev/null; then
    SSID=$(iwgetid -r)
    if [ -n "$SSID" ]; then
        echo "󰤨 $SSID"
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
