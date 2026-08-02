#!/bin/bash
# ============================================================
#   SnowFoxOS v3 — Smart Lock
#   Sperrt nicht wenn Video/Audio aktiv ist
#   Hintergrund: aktuelles Wallpaper, geblurrt & gedimmt
# ============================================================

# Prüfen ob ein Mediaplayer aktiv ist
if playerctl status 2>/dev/null | grep -q "Playing"; then
    exit 0
fi

# Prüfen ob mpv oder ein Browser im Fullscreen ist
IS_FS=$(xprop -id $(xdotool getactivewindow 2>/dev/null) _NET_WM_STATE 2>/dev/null | grep -q "_NET_WM_STATE_FULLSCREEN"; echo $?)
if [[ "$IS_FS" -eq 0 ]]; then
    WM_CLASS=$(xdotool getactivewindow getwindowclassname 2>/dev/null)
    if echo "$WM_CLASS" | grep -qiE "mpv|vlc|firefox|chromium|brave|chrom"; then
        exit 0
    fi
fi

# Aktuelles Wallpaper auslesen
WALLPAPER=$(grep -oP "(?<=--bg-fill ').*(?=')" ~/.fehbg)
LOCK_IMG="/tmp/snowfox-lock.png"

# Wallpaper blurren und dimmen
if [ -f "$WALLPAPER" ]; then
    convert "$WALLPAPER" \
        -scale 1920x1080! \
        -blur 0x8 \
        -fill "#1a1825" \
        -colorize 30 \
        "$LOCK_IMG"
else
    convert -size 1920x1080 xc:#1a1825 "$LOCK_IMG"
fi

# Sperren
i3lock -i "$LOCK_IMG" --nofork

# Aufräumen
rm -f "$LOCK_IMG"
