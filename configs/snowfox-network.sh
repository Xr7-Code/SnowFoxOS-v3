#!/bin/bash
# SnowFoxOS — Netzwerk-Manager via Rofi

ROFI_THEME="$HOME/.config/rofi/config.rasi"
ROFI_WIDTH=520

# ── Hilfsfunktionen ───────────────────────────────────────────

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

# ── Netzwerkliste aufbauen ────────────────────────────────────

build_network_list() {
    # Netzwerke neu scannen (asynchron)
    nmcli device wifi rescan &>/dev/null &

    nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list 2>/dev/null \
    | while IFS=: read -r INUSE SSID SIGNAL SECURITY; do
        [[ -z "$SSID" || "$SSID" == "--" ]] && continue
        SSID_CLEAN=$(echo "$SSID" | sed 's/\\:/:/g')

        # Icon je nach Status
        if [[ "$INUSE" == "*" ]]; then
            ICON="󰤨"   # verbunden
        elif nmcli connection show "$SSID_CLEAN" &>/dev/null; then
            ICON="󰤥"   # bekannt/gespeichert
        else
            ICON="󰤢"   # neu
        fi

        # Signal-Balken
        SIG=${SIGNAL:-0}
        if   (( SIG >= 75 )); then BAR="▂▄▆█"
        elif (( SIG >= 50 )); then BAR="▂▄▆_"
        elif (( SIG >= 25 )); then BAR="▂▄__"
        else                       BAR="▂___"
        fi

        SEC_LABEL=$([ -z "$SECURITY" ] && echo "OPEN" || echo "WPA")
        
        # Maximale Länge der SSID für die Ausrichtung begrenzen (z.B. 32 Zeichen)
        # Falls die SSID länger ist, schneiden wir sie ab, damit das Layout nicht bricht.
        SSID_DISPLAY=$(echo "$SSID_CLEAN" | cut -c1-32)

        # NEU: Das printf-Layout rechtsbündig formatiert:
        # %-34s -> Zeigt Icon + SSID linksbündig an (34 Zeichen breit)
        # %5s    -> Richtet den Signalbalken rechtsbündig aus
        # %4s%%  -> Richtet die Prozentzahl rechtsbündig aus
        # %5s    -> Richtet den Security-Typ rechtsbündig aus
        # Danach folgen die unsichtbaren Daten (\t) für die Verarbeitung im Case-Block.
        printf "%-34s %5s %4s%%  %5s\t%s\t%s\n" \
            "$ICON  $SSID_DISPLAY" "$BAR" "$SIGNAL" "$SEC_LABEL" "$SSID_CLEAN" "$SEC_LABEL"
    done
}

# ── Verbindung herstellen ─────────────────────────────────────

connect_network() {
    local SSID="$1"
    local SECURITY="$2"

    CURRENT=$(active_ssid)
    if [[ "$CURRENT" == "$SSID" ]]; then
        # Versuche zuerst Google's Captive Portal Check
        PORTAL=$(curl -s -o /dev/null -w "%{redirect_url}" --max-time 5 http://connectivitycheck.gstatic.com/generate_204)
        # Wenn Google keinen Redirect liefert, versuche neverssl.com
        if [[ -z "$PORTAL" ]]; then
            PORTAL=$(curl -s -o /dev/null -w "%{redirect_url}" --max-time 5 http://neverssl.com/)
        fi

        if [[ -n "$PORTAL" ]]; then
            notify "Captive Portal erkannt — Browser wird geöffnet"
            # xdg-open kann fehlschlagen, wenn kein Browser konfiguriert ist oder andere Probleme auftreten
            xdg-open "$PORTAL" &>/dev/null || notify "Fehler: Browser konnte Captive Portal nicht öffnen. Bitte manuell 'http://neverssl.com/' im Browser öffnen."
        else
            notify "Bereits verbunden mit: $SSID"
        fi
        return
    fi

    # Gespeicherte Verbindung vorhanden?
    if nmcli connection show "$SSID" &>/dev/null; then
        notify "Verbinde mit: $SSID"
        nmcli connection up "$SSID" &>/dev/null && \
            notify "Verbunden mit: $SSID" || \
            notify "Verbindung fehlgeschlagen"
        return
    fi

    # Offenes Netzwerk
    if [[ "$SECURITY" == "OPEN" ]]; then
        notify "Verbinde mit: $SSID (offen)"
        nmcli device wifi connect "$SSID" &>/dev/null && \
            notify "Verbunden mit: $SSID" || \
            notify "Verbindung fehlgeschlagen"
        return
    fi

    # Passwort abfragen
    PASS=$(rofi -dmenu \
        -p "󰌋  Passwort für '$SSID'" \
        -theme "$ROFI_THEME" \
        -theme-str "window { width: 420px; } listview { lines: 0; }" \
        -password)

    [[ -z "$PASS" ]] && exit 0

    notify "Verbinde mit: $SSID ..."

    # Direktes Capturen des Fehlers in eine Variable statt Datei
    ERR=$(nmcli device wifi connect "$SSID" password "$PASS" 2>&1)
    if [[ $? -eq 0 ]]; then
        notify "Verbunden mit: $SSID"
        sleep 2
        PORTAL=$(curl -s -o /dev/null -w "%{redirect_url}" \
            --max-time 5 http://connectivitycheck.gstatic.com/generate_204)
        if [[ -z "$PORTAL" ]]; then
            PORTAL=$(curl -s -o /dev/null -w "%{redirect_url}" --max-time 5 http://neverssl.com/)
        fi
        [[ -n "$PORTAL" ]] && xdg-open "$PORTAL" &>/dev/null || notify "Fehler: Browser konnte Captive Portal nicht öffnen. Bitte manuell 'http://neverssl.com/' im Browser öffnen."
    else
        notify "Fehlgeschlagen: $(echo "$ERR" | head -1)"
    fi
}

# ── Restliche Funktionen ──────────────────────────────────────

forget_network() {
    SAVED=$(nmcli -t -f NAME,TYPE connection show | grep wireless | cut -d: -f1)
    [[ -z "$SAVED" ]] && notify "Keine gespeicherten Netzwerke" && return

    CHOICE=$(echo "$SAVED" | rofi -dmenu \
        -p "󰆴  Netzwerk vergessen" \
        -theme "$ROFI_THEME" \
        -theme-str "window { width: 400px; } listview { lines: 8; }")

    [[ -z "$CHOICE" ]] && return

    nmcli connection delete "$CHOICE" &>/dev/null && \
        notify "Vergessen: $CHOICE" || \
        notify "Fehler beim Löschen"
}

show_details() {
    local IFACE
    IFACE=$(nmcli -t -f DEVICE,STATE device | grep ":connected" | cut -d: -f1 | head -1)

    if [[ -z "$IFACE" ]]; then
        notify "Keine aktive Verbindung"
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

# ── Hauptmenü ─────────────────────────────────────────────────

WIFI_ON=$(wifi_state)
WIFI_LABEL=$([ "$WIFI_ON" == "enabled" ] && echo "󰤭  WiFi deaktivieren" || echo "󰤨  WiFi aktivieren")
ACTIVE=$(active_ssid)
ACTIVE_LABEL=$([ -n "$ACTIVE" ] && echo "󰤮  Trennen ($ACTIVE)" || echo "󰤮  Verbindung trennen")

NETWORKS=$(build_network_list)

MENU="$NETWORKS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
$WIFI_LABEL
$ACTIVE_LABEL
󰆴  Netzwerk vergessen
󰈀  Ethernet-Status
󰋌  Netzwerk-Details"

CHOICE=$(echo -e "$MENU" | rofi -dmenu \
    -p "󰤨  Netzwerk" \
    -theme "$ROFI_THEME" \
    -theme-str "window { width: ${ROFI_WIDTH}px; } listview { lines: 14; }")

[[ -z "$CHOICE" ]] && exit 0

# ── Aktionen ──────────────────────────────────────────────────

case "$CHOICE" in
    *"WiFi aktivieren"*)
        nmcli radio wifi on && notify "WiFi aktiviert"
        ;;
    *"WiFi deaktivieren"*)
        nmcli radio wifi off && notify "WiFi deaktiviert"
        ;;
    *"Verbindung trennen"*|*"Trennen ("*)
        CONN=$(active_connection)
        if [[ -n "$CONN" ]]; then
            nmcli connection down "$CONN" &>/dev/null && \
                notify "Getrennt von: $CONN" || \
                notify "Trennen fehlgeschlagen"
        else
            notify "Keine aktive Verbindung"
        fi
        ;;
    *"Netzwerk vergessen"*)
        forget_network
        ;;
    *"Ethernet-Status"*)
        ETH=$(nmcli device status | grep -i ethernet | awk '{print $1 ": " $3}')
        [[ -z "$ETH" ]] && ETH="Kein Ethernet-Gerät gefunden"
        notify "$ETH"
        ;;
    *"Netzwerk-Details"*)
        show_details
        ;;
    *"━━━"*)
        exit 0
        ;;
    *)
        # Hier extrahieren wir die unsichtbaren Tab-Daten am Ende der Zeile!
        SSID=$(echo "$CHOICE" | cut -f2)
        SECURITY=$(echo "$CHOICE" | cut -f3)

        [[ -z "$SSID" ]] && exit 0
        connect_network "$SSID" "$SECURITY"
        ;;
esac