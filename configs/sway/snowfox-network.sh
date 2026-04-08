#!/bin/bash
# ============================================================
#  SnowFoxOS — Netzwerk-Manager via Wofi
# ============================================================

# Verfügbare WLANs scannen
NETWORKS=$(nmcli -f IN-USE,SSID,SIGNAL,SECURITY device wifi list 2>/dev/null | tail -n +2 | while IFS= read -r line; do
    INUSE=$(echo "$line" | cut -c1-8 | xargs)
    SSID=$(echo "$line" | cut -c9-31 | xargs)
    SIGNAL=$(echo "$line" | cut -c32-39 | xargs)
    SECURITY=$(echo "$line" | cut -c40- | xargs)
    [[ -z "$SSID" || "$SSID" == "--" ]] && continue
    ICON=$([ "$INUSE" = "*" ] && echo "✓" || echo " ")
    SEC_LABEL=$([ "$SECURITY" = "--" ] && echo "OPEN" || echo "$SECURITY")
    printf "%s %-30s %3s%%  %s\n" "$ICON" "$SSID" "$SIGNAL" "$SEC_LABEL"
done)

if [[ -z "$NETWORKS" ]]; then
    notify-send "SnowFox Netzwerk" "Keine WLANs gefunden — ist WiFi aktiv?"
    exit 1
fi

# Zusätzliche Optionen
EXTRAS="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Ethernet-Status
  WiFi an/aus
  Verbindung trennen
  Netzwerk-Details"

CHOICE=$(echo -e "$NETWORKS\n$EXTRAS" | wofi --show dmenu \
    --prompt "Netzwerk" \
    --width 500 \
    --height 400 \
    --insensitive)

[[ -z "$CHOICE" ]] && exit 0

# Auswahl verarbeiten
case "$CHOICE" in
    *"WiFi an/aus"*)
        STATE=$(nmcli radio wifi)
        if [[ "$STATE" == "enabled" ]]; then
            nmcli radio wifi off
            notify-send "🦊 SnowFox" "WiFi deaktiviert"
        else
            nmcli radio wifi on
            notify-send "🦊 SnowFox" "WiFi aktiviert"
        fi
        ;;
    *"Verbindung trennen"*)
        ACTIVE=$(nmcli -t -f NAME connection show --active | head -1)
        if [[ -n "$ACTIVE" ]]; then
            nmcli connection down "$ACTIVE"
            notify-send "🦊 SnowFox" "Getrennt von: $ACTIVE"
        else
            notify-send "🦊 SnowFox" "Keine aktive Verbindung"
        fi
        ;;
    *"Ethernet-Status"*)
        ETH=$(nmcli device status | grep ethernet)
        notify-send "🦊 SnowFox Ethernet" "$ETH"
        ;;
    *"Netzwerk-Details"*)
        INFO=$(nmcli device show | grep -E "GENERAL.DEVICE|GENERAL.STATE|IP4.ADDRESS|IP4.GATEWAY" | head -12)
        notify-send "🦊 SnowFox Netzwerk" "$INFO"
        ;;
    *"━━━"*)
        exit 0
        ;;
    *)
        # SSID extrahieren — Icon (1 Zeichen) + Leerzeichen, dann SSID bis zum ersten Leerzeichen+Zahl
        SSID=$(echo "$CHOICE" | cut -c3- | awk '{print $1}' | xargs)
        [[ -z "$SSID" ]] && exit 0

        # Prüfen ob bereits verbunden
        CURRENT=$(nmcli -t -f active,ssid dev wifi | grep "^yes" | cut -d: -f2)
        if [[ "$CURRENT" == "$SSID" ]]; then
            # Bereits verbunden — Captive Portal prüfen
            CAPTIVE=$(curl -s --max-time 3 -o /dev/null -w "%{http_code}" http://detectportal.firefox.com/success.txt)
            if [[ "$CAPTIVE" != "200" ]]; then
                notify-send "🦊 SnowFox" "Captive Portal erkannt — Browser wird geöffnet"
                brave-browser "http://detectportal.firefox.com/success.txt" &
            else
                notify-send "🦊 SnowFox" "Bereits verbunden mit: $SSID"
            fi
            exit 0
        fi

        # Sicherheit des gewählten Netzwerks prüfen
        SECURITY=$(nmcli -f SSID,SECURITY device wifi list | grep "^${SSID} " | awk '{print $NF}' | head -1)

        # Bekannte Verbindung
        if nmcli connection show "$SSID" &>/dev/null; then
            nmcli connection up "$SSID" && \
                notify-send "🦊 SnowFox" "Verbunden mit: $SSID" || \
                notify-send "🦊 SnowFox" "Verbindung fehlgeschlagen"

        # Offenes Netzwerk — kein Passwort, Captive Portal möglich
        elif [[ "$SECURITY" = "--" || "$CHOICE" == *"OPEN"* ]]; then
            notify-send "🦊 SnowFox" "Verbinde mit: $SSID"
            # Verbinden ohne auf Internet zu warten
            nmcli device wifi connect "$SSID" -- connection.id "$SSID" 2>/dev/null || \
            nmcli device wifi connect "$SSID" 2>/dev/null
            sleep 3
            # Browser sofort öffnen — Captive Portal zeigt sich selbst
            notify-send "🦊 SnowFox" "Browser wird für Portal geöffnet..."
            brave-browser "http://captive.apple.com/hotspot-detect.html" &

        # Verschlüsseltes Netzwerk — Passwort abfragen
        else
            PASS=$(echo "" | wofi --show dmenu \
                --prompt "Passwort für $SSID" \
                --width 400 --height 100 \
                --password)

            if [[ -n "$PASS" ]]; then
                nmcli device wifi connect "$SSID" password "$PASS" && \
                    notify-send "🦊 SnowFox" "Verbunden mit: $SSID" || \
                    notify-send "🦊 SnowFox" "Verbindung fehlgeschlagen — falsches Passwort?"
            else
                # Leeres Passwort — als offenes Netzwerk behandeln
                nmcli device wifi connect "$SSID" && \
                    notify-send "🦊 SnowFox" "Verbunden mit: $SSID" || \
                    notify-send "🦊 SnowFox" "Verbindung fehlgeschlagen"
            fi
        fi
        ;;
esac
