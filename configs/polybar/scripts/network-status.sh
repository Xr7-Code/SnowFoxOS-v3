#!/bin/bash
# ============================================================
#  SnowFoxOS — Polybar Network Status Script
#  Path: ~/.config/polybar/scripts/network-status.sh
# ============================================================

# Check via nmcli
if command -v nmcli &> /dev/null; then
    # WiFi SSID
    SSID=$(LC_ALL=C nmcli -t -f ACTIVE,SSID dev wifi | grep '^yes:' | cut -d: -f2)
    if [ -n "$SSID" ]; then
        echo "󰤨 $SSID"
        exit 0
    fi

    # Check LAN
    CONNECTIONS=$(nmcli -t -f TYPE,STATE device status | grep '^ethernet:connected' || true)
    if [ -n "$CONNECTIONS" ]; then
        echo "󰌘 LAN"
        exit 0
    fi
fi

# Fallback: manual check
# Check WiFi via iwgetid
if command -v iwgetid &> /dev/null; then
    SSID=$(iwgetid -r)
    if [ -n "$SSID" ]; then
        echo "󰤨 $SSID"
        exit 0
    fi
fi

# Check LAN (cable)
for iface in /sys/class/net/en*; do
    if [ -e "$iface/carrier" ]; then
        LAN_STATUS=$(cat "$iface/carrier" 2>/dev/null)
        if [ "$LAN_STATUS" = "1" ]; then
            echo "󰌘 LAN"
            exit 0
        fi
    fi
done

# No connection
echo "󰤭 offline"
