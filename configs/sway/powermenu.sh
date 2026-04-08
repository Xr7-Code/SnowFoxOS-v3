#!/bin/bash
# SnowFoxOS — Power Menü mit Wofi

OPTIONS="  Sperren\n  Abmelden\n  Neu starten\n  Ausschalten\n  Ruhezustand"

CHOSEN=$(echo -e "$OPTIONS" | wofi \
    --dmenu \
    --prompt "Power" \
    --width 250 \
    --height 230 \
    --cache-file /dev/null \
    --hide-scroll \
    --no-actions \
    --insensitive)

case "$CHOSEN" in
    *Sperren)
        swaylock -f
        ;;
    *Abmelden)
        swaymsg exit
        ;;
    *"Neu starten")
        systemctl reboot
        ;;
    *Ausschalten)
        systemctl poweroff
        ;;
    *Ruhezustand)
        systemctl suspend
        ;;
esac
