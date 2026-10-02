#!/bin/bash
# ============================================================
#  SnowFoxOS — Network Manager via Rofi
#  Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)
# ============================================================

ROFI_THEME="$HOME/.config/rofi/config.rasi"
ROFI_WIDTH=520

# ── Helper functions ─────────────────────────────────────────

notify() {
    notify-send "🦊 SnowFox" "$1"
}

wifi_state() {
    nmcli radio wifi 2>/dev/null
}

active_ssid() {
    nmcli -t -f active,ssid dev wifi 2>/dev/null \
        | grep "^yes" | cut -d: -f2- | sed 's/\\:/:/g' | head -1
}

active_connection() {
    nmcli -t -f NAME connection show --active 2>/dev/null | head -1
}

# ── Build network list ───────────────────────────────────────

build_network_list() {
    # Rescan networks asynchronously
    nmcli device wifi rescan &>/dev/null &

    nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list 2>/dev/null \
    | while IFS=: read -r INUSE SSID SIGNAL SECURITY; do
        [[ -z "$SSID" || "$SSID" == "--" ]] && continue
        SSID_CLEAN=$(echo "$SSID" | sed 's/\\:/:/g')

        # Icon based on status
        if [[ "$INUSE" == "*" ]]; then
            ICON="󰤨"   # connected
        elif nmcli connection show "$SSID_CLEAN" &>/dev/null; then
            ICON="󰤥"   # known/saved
        else
            ICON="󰤢"   # new
        fi

        # Signal bars
        SIG=${SIGNAL:-0}
        if   (( SIG >= 75 )); then BAR="▂▄▆█"
        elif (( SIG >= 50 )); then BAR="▂▄▆_"
        elif (( SIG >= 25 )); then BAR="▂▄__"
        else                       BAR="▂___"
        fi

        SEC_LABEL=$([ -z "$SECURITY" ] && echo "OPEN" || echo "WPA")

        # Limit SSID length for alignment (32 chars max)
        SSID_DISPLAY=$(echo "$SSID_CLEAN" | cut -c1-32)

        # printf layout:
        # %-34s  -> Icon + SSID, left-aligned (34 chars wide)
        # %5s    -> Signal bars, right-aligned
        # %4s%%  -> Percentage, right-aligned
        # %5s    -> Security type, right-aligned
        # Then invisible data (\t) for parsing in the case block.
        printf "%-34s %5s %4s%%  %5s\t%s\t%s\n" \
            "$ICON  $SSID_DISPLAY" "$BAR" "$SIGNAL" "$SEC_LABEL" "$SSID_CLEAN" "$SEC_LABEL"
    done
}

# ── Connect to network ───────────────────────────────────────

connect_network() {
    local SSID="$1"
    local SECURITY="$2"

    CURRENT=$(active_ssid)
    if [[ "$CURRENT" == "$SSID" ]]; then
        # Try Google's captive portal check first
        PORTAL=$(curl -s -o /dev/null -w "%{redirect_url}" --max-time 5 http://connectivitycheck.gstatic.com/generate_204)
        # If Google returns no redirect, try neverssl.com
        if [[ -z "$PORTAL" ]]; then
            PORTAL=$(curl -s -o /dev/null -w "%{redirect_url}" --max-time 5 http://neverssl.com/)
        fi

        if [[ -n "$PORTAL" ]]; then
            notify "Captive portal detected — opening browser"
            # xdg-open may fail if no browser is configured
            xdg-open "$PORTAL" &>/dev/null || notify "Error: could not open captive portal. Manually open 'http://neverssl.com/' in your browser."
        else
            notify "Already connected to: $SSID"
        fi
        return
    fi

    # Saved connection available?
    if nmcli connection show "$SSID" &>/dev/null; then
        notify "Connecting to: $SSID"
        nmcli connection up "$SSID" &>/dev/null && \
            notify "Connected to: $SSID" || \
            notify "Connection failed"
        return
    fi

    # Open network
    if [[ "$SECURITY" == "OPEN" ]]; then
        notify "Connecting to: $SSID (open)"
        nmcli device wifi connect "$SSID" &>/dev/null && \
            notify "Connected to: $SSID" || \
            notify "Connection failed"
        return
    fi

    # Prompt for password
    PASS=$(rofi -dmenu \
        -p "󰌋  Password for '$SSID'" \
        -theme "$ROFI_THEME" \
        -theme-str "window { width: 420px; } listview { lines: 0; }" \
        -password)

    [[ -z "$PASS" ]] && exit 0

    notify "Connecting to: $SSID ..."

    # Capture error directly into a variable instead of a file
    ERR=$(nmcli device wifi connect "$SSID" password "$PASS" 2>&1)
    if [[ $? -eq 0 ]]; then
        notify "Connected to: $SSID"
        sleep 2
        PORTAL=$(curl -s -o /dev/null -w "%{redirect_url}" \
            --max-time 5 http://connectivitycheck.gstatic.com/generate_204)
        if [[ -z "$PORTAL" ]]; then
            PORTAL=$(curl -s -o /dev/null -w "%{redirect_url}" --max-time 5 http://neverssl.com/)
        fi
        [[ -n "$PORTAL" ]] && xdg-open "$PORTAL" &>/dev/null || notify "Error: could not open captive portal. Manually open 'http://neverssl.com/' in your browser."
    else
        notify "Failed: $(echo "$ERR" | head -1)"
    fi
}

# ── Other functions ──────────────────────────────────────────

forget_network() {
    SAVED=$(nmcli -t -f NAME,TYPE connection show | grep wireless | cut -d: -f1)
    [[ -z "$SAVED" ]] && notify "No saved networks" && return

    CHOICE=$(echo "$SAVED" | rofi -dmenu \
        -p "󰆴  Forget network" \
        -theme "$ROFI_THEME" \
        -theme-str "window { width: 400px; } listview { lines: 8; }")

    [[ -z "$CHOICE" ]] && return

    nmcli connection delete "$CHOICE" &>/dev/null && \
        notify "Forgotten: $CHOICE" || \
        notify "Failed to delete"
}

show_details() {
    local IFACE
    IFACE=$(nmcli -t -f DEVICE,STATE device | grep ":connected" | cut -d: -f1 | head -1)

    if [[ -z "$IFACE" ]]; then
        notify "No active connection"
        return
    fi

    IP=$(nmcli -g IP4.ADDRESS device show "$IFACE" | head -1)
    GW=$(nmcli -g IP4.GATEWAY device show "$IFACE" | head -1)
    DNS=$(nmcli -g IP4.DNS device show "$IFACE" | head -1)
    SSID=$(active_ssid)
    MAC=$(cat /sys/class/net/"$IFACE"/address 2>/dev/null)

    INFO="Interface:  $IFACE\nSSID:       ${SSID:-—}\nIP:         ${IP:-—}\nGateway:    ${GW:-—}\nDNS:        ${DNS:-—}\nMAC:        ${MAC:-—}"
    notify -e "$INFO"
}

# ── Main menu ────────────────────────────────────────────────

WIFI_ON=$(wifi_state)
WIFI_LABEL=$([ "$WIFI_ON" == "enabled" ] && echo "󰤭  Disable WiFi" || echo "󰤨  Enable WiFi")
ACTIVE=$(active_ssid)
ACTIVE_LABEL=$([ -n "$ACTIVE" ] && echo "󰤮  Disconnect ($ACTIVE)" || echo "󰤮  Disconnect")

NETWORKS=$(build_network_list)

MENU="$NETWORKS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
$WIFI_LABEL
$ACTIVE_LABEL
󰆴  Forget network
󰈀  Ethernet status
󰋌  Network details"

CHOICE=$(echo -e "$MENU" | rofi -dmenu \
    -p "󰤨  Network" \
    -theme "$ROFI_THEME" \
    -theme-str "window { width: ${ROFI_WIDTH}px; } listview { lines: 14; }")

[[ -z "$CHOICE" ]] && exit 0

# ── Actions ──────────────────────────────────────────────────

case "$CHOICE" in
    *"Enable WiFi"*)
        nmcli radio wifi on && notify "WiFi enabled"
        ;;
    *"Disable WiFi"*)
        nmcli radio wifi off && notify "WiFi disabled"
        ;;
    *"Disconnect"*)
        CONN=$(active_connection)
        if [[ -n "$CONN" ]]; then
            nmcli connection down "$CONN" &>/dev/null && \
                notify "Disconnected from: $CONN" || \
                notify "Disconnect failed"
        else
            notify "No active connection"
        fi
        ;;
    *"Forget network"*)
        forget_network
        ;;
    *"Ethernet status"*)
        ETH=$(nmcli device status | grep -i ethernet | awk '{print $1 ": " $3}')
        [[ -z "$ETH" ]] && ETH="No Ethernet device found"
        notify "$ETH"
        ;;
    *"Network details"*)
        show_details
        ;;
    *"━━━"*)
        exit 0
        ;;
    *)
        # Extract invisible tab data from end of line
        SSID=$(echo "$CHOICE" | cut -f2)
        SECURITY=$(echo "$CHOICE" | cut -f3)

        [[ -z "$SSID" ]] && exit 0
        connect_network "$SSID" "$SECURITY"
        ;;
esac
