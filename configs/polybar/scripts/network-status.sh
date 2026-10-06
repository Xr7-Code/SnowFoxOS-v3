#!/bin/bash
# ============================================================
#  SnowFoxOS — Polybar Network Status Script
#  Path: ~/.config/polybar/scripts/network-status.sh
# ============================================================

# 1. Aktive Standard-Schnittstelle über das System-Routing ermitteln
DEFAULT_IFACE=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'dev \K\S+')

# Keine aktive Route gefunden -> Offline
if [ -z "$DEFAULT_IFACE" ]; then
    echo "󰤭 offline"
    exit 0
fi

# 2. Prüfen, ob die aktive Schnittstelle WLAN ist
if [ -d "/sys/class/net/$DEFAULT_IFACE/wireless" ] || [ -d "/sys/class/net/$DEFAULT_IFACE/phy80211" ]; then
    SSID=""

    # Kaskade zum Auslesen der SSID (je nachdem, was installiert ist)
    if command -v iw &>/dev/null; then
        SSID=$(iw dev "$DEFAULT_IFACE" link 2>/dev/null | grep 'SSID:' | sed 's/^[ \t]*SSID: //')
    fi

    if [ -z "$SSID" ] && command -v nmcli &>/dev/null; then
        SSID=$(LC_ALL=C nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | grep '^yes:' | cut -d: -f2)
    fi

    if [ -z "$SSID" ] && command -v iwgetid &>/dev/null; then
        SSID=$(iwgetid -r "$DEFAULT_IFACE" 2>/dev/null)
    fi

    # Fallback, falls kein WLAN-Tool die SSID auslesen konnte
    if [ -z "$SSID" ]; then
        SSID="WLAN"
    fi

    echo "󰤨 $SSID"
    exit 0
fi

# 3. Wenn aktiv und kein WLAN -> LAN / Ethernet
echo "󰌘 LAN"
exit 0
