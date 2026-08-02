#!/bin/bash
# ============================================================
#   SnowFoxOS v3 — Clip-Saver
#   Hält X11-Clipboard-Daten aktiv, auch wenn das
#   Quellfenster geschlossen wird.
#   Requires: clipnotify, xclip
# ============================================================

while clipnotify; do
    # Prüfen ob ein Bild in der Zwischenablage liegt
    if xclip -selection clipboard -t TARGETS -o 2>/dev/null | grep -q 'image/'; then
        # Bildinhalte neu verankern
        xclip -selection clipboard -t image/png -o 2>/dev/null \
            | xclip -selection clipboard -t image/png 2>/dev/null
    else
        # Text neu verankern
        xclip -selection clipboard -o 2>/dev/null \
            | xclip -selection clipboard 2>/dev/null
    fi
done
