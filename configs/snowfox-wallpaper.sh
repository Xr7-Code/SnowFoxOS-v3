#!/bin/bash
# ============================================================
#  SnowFoxOS — Wallpaper Selector via Rofi
#  Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)
# ============================================================

WP_DIR="$HOME/Pictures/wallpapers"

# Check if directory exists
if [[ ! -d "$WP_DIR" ]]; then
    notify-send "🦊 SnowFox" "Wallpaper folder not found: $WP_DIR"
    exit 1
fi

# List images (jpg, png, webp, jpeg)
FILES=$(ls "$WP_DIR" 2>/dev/null | grep -iE "\.jpg$|\.png$|\.webp$|\.jpeg$")

CHOICE=$(echo -e "$FILES" | rofi -dmenu \
    -p "Wallpaper" \
    -theme ~/.config/rofi/config.rasi \
    -width 400 \
    -lines 10)

if [[ -n "$CHOICE" ]] && [[ -f "$WP_DIR/$CHOICE" ]]; then
    # feh --bg-fill creates/updates ~/.fehbg automatically for persistence
    feh --bg-fill "$WP_DIR/$CHOICE" 2>/dev/null
    notify-send "🦊 SnowFox" "Wallpaper updated: $CHOICE"
fi
