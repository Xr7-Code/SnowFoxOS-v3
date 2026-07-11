#!/bin/bash
# SnowFoxOS — Wallpaper Selector via Rofi

WP_DIR="$HOME/Pictures/wallpapers"

# Prüfen ob Verzeichnis existiert
if [[ ! -d "$WP_DIR" ]]; then
    notify-send "🦊 SnowFox" "Wallpaper-Ordner nicht gefunden: $WP_DIR"
    exit 1
fi

# Bilder auflisten (jpg, png, webp, jpeg)
FILES=$(ls "$WP_DIR" 2>/dev/null | grep -iE ".jpg$|.png$|.webp$|.jpeg$")

CHOICE=$(echo -e "$FILES" | rofi -dmenu \
    -p "Wallpaper" \
    -theme ~/.config/rofi/config.rasi \
    -width 400 \
    -lines 10)

if [[ -n "$CHOICE" ]] && [[ -f "$WP_DIR/$CHOICE" ]]; then
    # feh --bg-fill erstellt/aktualisiert automatisch ~/.fehbg für Persistenz
    feh --bg-fill "$WP_DIR/$CHOICE" 2>/dev/null
    notify-send "🦊 SnowFox" "Hintergrund aktualisiert: $CHOICE"
fi