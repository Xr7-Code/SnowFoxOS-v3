#!/bin/bash
# SnowFoxOS — Polybar Starter

sleep 2
killall -q polybar
while pgrep -u $UID -x polybar >/dev/null; do sleep 0.1; done

# Monitor ermitteln
PRIMARY=$(xrandr --query | grep " connected primary" | cut -d" " -f1)
[[ -z "$PRIMARY" ]] && PRIMARY=$(xrandr --query | grep " connected" | head -1 | cut -d" " -f1)

# Laptop-Erkennung
CHASSIS=$(cat /sys/class/dmi/id/chassis_type 2>/dev/null || echo "0")
IS_LAPTOP=false
[[ "$CHASSIS" =~ ^(8|9|10|14)$ ]] && IS_LAPTOP=true
ls /sys/class/power_supply/BAT* &>/dev/null && IS_LAPTOP=true

if $IS_LAPTOP; then
    # Akku + Adapter Pfad automatisch setzen
    BAT=$(ls /sys/class/power_supply/ | grep -E '^BAT' | head -1)
    AC=$(ls /sys/class/power_supply/ | grep -E '^(AC|ADP|ACAD)' | head -1)
    [[ -n "$BAT" ]] && sed -i "s/^battery = .*/battery = $BAT/" ~/.config/polybar/config.ini
    [[ -n "$AC" ]]  && sed -i "s/^adapter = .*/adapter = $AC/"  ~/.config/polybar/config.ini
    MONITOR=$PRIMARY polybar snowfox-laptop 2>/tmp/polybar.log &
else
    MONITOR=$PRIMARY polybar snowfox 2>/tmp/polybar.log &
fi
