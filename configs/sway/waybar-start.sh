#!/bin/bash
# SnowFoxOS — Waybar Starter
# Wartet bis NetworkManager bereit ist, dann startet Waybar.
# Kein blindes sleep — startet so früh wie möglich, max. 15s Timeout.

TIMEOUT=15
ELAPSED=0

while ! nmcli general status &>/dev/null; do
    sleep 0.5
    ELAPSED=$((ELAPSED + 1))
    [[ $ELAPSED -ge $((TIMEOUT * 2)) ]] && break
done

exec waybar
