#!/bin/bash
# SnowFoxOS — Smart Lock
# Sperrt nicht wenn Video/Audio aktiv ist

# Prüfen ob ein Mediaplayer aktiv ist
if playerctl status 2>/dev/null | grep -q "Playing"; then
    exit 0
fi

# Prüfen ob mpv oder ein Browser im Fullscreen ist
IS_FS=$(xprop -id $(xdotool getactivewindow 2>/dev/null) _NET_WM_STATE 2>/dev/null | grep -q "_NET_WM_STATE_FULLSCREEN" && echo "1" || echo "0")
if [[ "$IS_FS" -eq 1 ]]; then
    # Aktives Fenster prüfen
    WM_CLASS=$(xdotool getactivewindow getwindowclassname 2>/dev/null)
    if echo "$WM_CLASS" | grep -qiE "mpv|vlc|firefox|chromium|brave|chrom"; then
        exit 0
    fi
fi

# Alles OK — sperren
i3lock -c 000000
