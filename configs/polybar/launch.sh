#!/bin/bash
# SnowFoxOS — Polybar Starter

sleep 2
killall -q polybar

while pgrep -u $UID -x polybar >/dev/null; do sleep 0.1; done

PRIMARY=$(xrandr --query | grep " connected primary" | cut -d" " -f1)
[[ -z "$PRIMARY" ]] && PRIMARY=$(xrandr --query | grep " connected" | head -1 | cut -d" " -f1)

CHASSIS=$(cat /sys/class/dmi/id/chassis_type 2>/dev/null || echo "0")
IS_LAPTOP=false
[[ "$CHASSIS" =~ ^(8|9|10|14)$ ]] && IS_LAPTOP=true
ls /sys/class/power_supply/BAT* &>/dev/null && IS_LAPTOP=true

if $IS_LAPTOP; then
    BAT=$(ls /sys/class/power_supply/ | grep -E '^BAT' | head -1)
    AC=$(ls /sys/class/power_supply/ | grep -E '^(AC|ADP|ACAD)' | head -1)
    [[ -n "$BAT" ]] && sed -i "s/^battery = .*/battery = $BAT/" ~/.config/polybar/config.ini
    [[ -n "$AC" ]]  && sed -i "s/^adapter = .*/adapter = $AC/"  ~/.config/polybar/config.ini
    BACKLIGHT_CARD=$(ls /sys/class/backlight/ | head -1)
    [[ -n "$BACKLIGHT_CARD" ]] && sed -i "s/^card = .*/card = $BACKLIGHT_CARD/" ~/.config/polybar/config.ini
    MONITOR=$PRIMARY polybar snowfox-laptop 2>/tmp/polybar.log &
else
    MONITOR=$PRIMARY polybar snowfox 2>/tmp/polybar.log &
fi

# ── Polybar immer im Vordergrund halten ──────────────────
sleep 1
i3-msg '[class="Polybar"] border none, sticky enable'
