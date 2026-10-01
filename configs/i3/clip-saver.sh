#!/bin/bash
# ============================================================
#   SnowFoxOS v3 — Clip-Saver
#   Hält X11-Clipboard-Daten (Text/PNG) aktiv, auch wenn das
#   Quellfenster geschlossen wird. Dateien (PCManFM, Thunar,
#   Nautilus ...) werden bewusst NICHT angefasst.
#   Requires: clipnotify, xclip
# ============================================================

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
last_hash=""

while clipnotify; do
    targets=$(xclip -selection clipboard -t TARGETS -o 2>/dev/null) || continue

    # Datei-Kopieren/Ausschneiden: nie anfassen, sonst gehen
    # x-special/gnome-copied-files und text/uri-list verloren.
    if grep -qE 'x-special/|text/uri-list|XdndDirectSave' <<<"$targets"; then
        last_hash=""
        continue
    fi

    if grep -qx 'image/png' <<<"$targets"; then
        type="image/png"
    elif grep -qx 'UTF8_STRING' <<<"$targets"; then
        type="UTF8_STRING"
    else
        continue
    fi

    xclip -selection clipboard -t "$type" -o >"$tmp" 2>/dev/null || continue
    [ -s "$tmp" ] || continue

    # Schleifenschutz: Unser eigenes xclip löst clipnotify erneut aus.
    hash=$(sha256sum <"$tmp" | cut -d' ' -f1)
    [ "$hash" = "$last_hash" ] && continue
    last_hash="$hash"

    # Inhalt neu verankern (xclip läuft im Hintergrund weiter)
    xclip -selection clipboard -t "$type" -i <"$tmp" 2>/dev/null
done
