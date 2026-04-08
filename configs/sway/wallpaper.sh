#!/bin/bash
# SnowFoxOS — Wallpaper setzen
WALLPAPER="$HOME/Pictures/wallpapers/wallpaper.jpg"
FALLBACK="#0f0f0f"

if [[ -f "$WALLPAPER" ]]; then
    swaymsg "output * bg $WALLPAPER fill"
else
    swaymsg "output * bg $FALLBACK solid_color"
fi
