#!/bin/bash
# ============================================================
#  SnowFoxOS — Display Manager via Rofi
#  Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)
# ============================================================

# Detect connected monitors
MONITORS=$(xrandr --query | grep " connected" | awk '{print $1}')
PRIMARY=$(xrandr --query | grep " connected primary" | awk '{print $1}')

[[ -z "$MONITORS" ]] && exit 1

MENU=""
while IFS= read -r mon; do
    STATUS=$(xrandr --query | grep "^$mon" | grep -q "connected primary" && echo "★ PRIMARY" || echo "")
    ACTIVE=$(xrandr --query | grep "^$mon" | grep -q "\*" && echo "ON" || echo "OFF")
    MENU="${MENU}${mon}  [${ACTIVE}] ${STATUS}\n"
done <<< "$MONITORS"

MENU="${MENU}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
MENU="${MENU}  Mirror all\n"
MENU="${MENU}  Extend all (left-right)\n"
MENU="${MENU}  Primary monitor only\n"
MENU="${MENU}  Configure arrangement\n"
MENU="${MENU}  Hybrid-Sync Refresh"

CHOICE=$(echo -e "$MENU" | rofi -dmenu \
    -p "Display" \
    -theme "$HOME/.config/rofi/config.rasi" \
    -width 450 \
    -lines 12)

[[ -z "$CHOICE" ]] && exit 0

case "$CHOICE" in
    *"Mirror all"*)
        FIRST=""
        while IFS= read -r mon; do
            xrandr --output "$mon" --auto
            if [[ -z "$FIRST" ]]; then
                xrandr --output "$mon" --primary
                FIRST="$mon"
            else
                xrandr --output "$mon" --same-as "$FIRST"
            fi
        done <<< "$MONITORS"
        notify-send "🦊 SnowFox Display" "All monitors mirrored"
        ;;

    *"Extend all"*)
        # Use existing primary as anchor if available
        ANCHOR="${PRIMARY:-$(echo "$MONITORS" | head -n1)}"
        xrandr --output "$ANCHOR" --auto --primary
        while IFS= read -r mon; do
            if [[ "$mon" != "$ANCHOR" ]]; then
                xrandr --output "$mon" --auto --right-of "$ANCHOR"
            fi
        done <<< "$MONITORS"
        notify-send "🦊 SnowFox Display" "Extended (left to right)"
        ;;

    *"Primary monitor only"*)
        while IFS= read -r mon; do
            if [[ "$mon" == "$PRIMARY" ]]; then
                xrandr --output "$mon" --auto --primary
            else
                xrandr --output "$mon" --off
            fi
        done <<< "$MONITORS"
        notify-send "🦊 SnowFox Display" "Primary monitor only"
        ;;

    *"Configure arrangement"*)
        NEW_PRIMARY=$(echo "$MONITORS" | rofi -dmenu \
            -p "Choose primary monitor" \
            -theme "$HOME/.config/rofi/config.rasi" \
            -width 350 \
            -lines 5)
        [[ -z "$NEW_PRIMARY" ]] && exit 0

        OTHER=$(echo "$MONITORS" | grep -v "$NEW_PRIMARY" | head -1)
        if [[ -n "$OTHER" ]]; then
            POS=$(echo -e "Right of $NEW_PRIMARY\nLeft of $NEW_PRIMARY\nAbove $NEW_PRIMARY\nBelow $NEW_PRIMARY\nTurn off" | \
                rofi -dmenu \
                -p "$OTHER position" \
                -theme "$HOME/.config/rofi/config.rasi" \
                -width 350 \
                -lines 5)

            xrandr --output "$NEW_PRIMARY" --auto --primary
            case "$POS" in
                *Right*)  xrandr --output "$OTHER" --auto --right-of "$NEW_PRIMARY" ;;
                *Left*)   xrandr --output "$OTHER" --auto --left-of  "$NEW_PRIMARY" ;;
                *Above*)  xrandr --output "$OTHER" --auto --above    "$NEW_PRIMARY" ;;
                *Below*)  xrandr --output "$OTHER" --auto --below    "$NEW_PRIMARY" ;;
                *"Turn off"*) xrandr --output "$OTHER" --off ;;
            esac
            notify-send "🦊 SnowFox Display" "$NEW_PRIMARY is now primary"
        else
            xrandr --output "$NEW_PRIMARY" --auto --primary
            notify-send "🦊 SnowFox Display" "$NEW_PRIMARY is now primary"
        fi
        ;;

    *"Hybrid-Sync Refresh"*)
        # Forces resynchronization of X providers (helps against freezes)
        xrandr --auto
        notify-send "🦊 SnowFox" "Hybrid-Sync buffer refreshed"
        ;;

    *)
        MON=$(echo "$CHOICE" | awk '{print $1}')
        [[ -z "$MON" ]] && exit 0
        STATUS=$(xrandr | grep "^$MON" | grep -c "\*" || true)
        if [[ "$STATUS" -gt 0 ]]; then
            xrandr --output "$MON" --off
            notify-send "🦊 SnowFox Display" "$MON turned off"
        else
            xrandr --output "$MON" --auto
            notify-send "🦊 SnowFox Display" "$MON turned on"
        fi
        ;;
esac

# Reload i3 and restart Polybar on primary monitor
i3-msg reload 2>/dev/null || true
sleep 0.5
~/.config/polybar/launch.sh
