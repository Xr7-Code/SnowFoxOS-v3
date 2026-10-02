#!/bin/bash
# ============================================================
#   SnowFoxOS v3 — Clip-Saver
#   Keeps X11 clipboard data (text/PNG) alive even when the
#   source window is closed. File operations (PCManFM, Thunar,
#   Nautilus ...) are deliberately NOT touched.
#   Requires: clipnotify, xclip
#   Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)
# ============================================================

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
last_hash=""

while clipnotify; do
    targets=$(xclip -selection clipboard -t TARGETS -o 2>/dev/null) || continue

    # File copy/cut: never touch, otherwise x-special/gnome-copied-files
    # and text/uri-list are lost.
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

    # Loop protection: our own xclip triggers clipnotify again.
    hash=$(sha256sum <"$tmp" | cut -d' ' -f1)
    [ "$hash" = "$last_hash" ] && continue
    last_hash="$hash"

    # Re-anchor content (xclip keeps running in the background)
    xclip -selection clipboard -t "$type" -i <"$tmp" 2>/dev/null
done
