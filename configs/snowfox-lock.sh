#!/bin/bash
# SnowFoxOS — Smart Lock

if playerctl status 2>/dev/null | grep -q "Playing"; then
    exit 0
fi

IS_FS=$(xprop -id $(xdotool getactivewindow 2>/dev/null) _NET_WM_STATE 2>/dev/null | grep -q "_NET_WM_STATE_FULLSCREEN"; echo $?)
if [[ "$IS_FS" -eq 0 ]]; then
    WM_CLASS=$(xdotool getactivewindow getwindowclassname 2>/dev/null)
    if echo "$WM_CLASS" | grep -qiE "mpv|vlc|firefox|chromium|brave|chrom"; then
        exit 0
    fi
fi

WALLPAPER=$(grep -oP "(?<=--bg-fill ').*(?=')" ~/.fehbg)
LOCK_IMG="/tmp/snowfox-lock.png"

convert "$WALLPAPER" \
    -scale 1920x1080! \
    -blur 0x8 \
    -fill "#1a1825" \
    -colorize 30 \
    "$LOCK_IMG"

i3lock -i "$LOCK_IMG" --nofork
rm -f "$LOCK_IMG"
