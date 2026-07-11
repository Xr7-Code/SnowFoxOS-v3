#!/bin/bash
# SnowFoxOS — Power Menu via Rofi
# NF v3 Icons:
#   nf-md-power      (U+F0425) → 󰐥
#   nf-md-restart    (U+F0453) → 󰑓
#   nf-md-logout     (U+F0343) → 󰍃
#   nf-md-sleep      (U+F04B2) → 󰒲
#   nf-md-lock       (U+F033E) → 󰌾

CHOICE=$(echo -e "󰐥  Shutdown\n󰑓  Reboot\n󰍃  Logout\n󰒲  Suspend\n󰌾  Lock" | \
    rofi -dmenu \
    -p "󰐥 Power" \
    -theme ~/.config/rofi/config.rasi \
    -width 250 \
    -lines 5)

case "$CHOICE" in
    *Shutdown)  systemctl poweroff ;;
    *Reboot)    systemctl reboot ;;
    *Logout)    i3-msg exit ;;
    *Suspend)   systemctl suspend ;;
    *Lock)      i3lock -c 0d0d0d ;;
esac
