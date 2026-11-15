#!/usr/bin/env bash
# ============================================================
#  SnowFoxOS v4 — CLI: settings
#  set / bt / kb / lang / tz / user / def
# ============================================================

if [[ -n "${_SNOWFOX_CLI_SETTINGS_LOADED:-}" ]]; then return 0 2>/dev/null || true; fi
_SNOWFOX_CLI_SETTINGS_LOADED=1

cmd_settings() {
    local sub="${1:-}"
    case "$sub" in
        gui) _settings_gui ;;
        "")  _settings_terminal ;;
        *)   _settings_terminal ;;
    esac
}

_settings_terminal() {
    header "snowfox set"
    local bt kb lang tz user
    bt=$(bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && echo on || echo off)
    kb=$(grep -oP 'XKBLAYOUT="\K[^"]+' /etc/default/keyboard 2>/dev/null || echo unknown)
    lang="${LANG:-unknown}"
    tz=$(timedatectl show -p Timezone --value 2>/dev/null || echo unknown)
    user=$(id -un)
    row "Bluetooth" "$bt"
    row "Keyboard"  "$kb"
    row "Language"  "$lang"
    row "Timezone"  "$tz"
    row "User"      "$user"
    info "snowfox set gui  → Rofi menu"
}

_settings_gui() {
    if ! command -v rofi >/dev/null 2>&1; then
        err "rofi not installed"
        return "$SNOWFOX_EXIT_ERROR"
    fi
    local choice
    choice=$(printf 'Bluetooth\nKeyboard\nLanguage\nTimezone\nUser' | rofi -dmenu -p "Settings")
    case "$choice" in
        Bluetooth) cmd_bluetooth ;;
        Keyboard)  info "use: snowfox kb <layout>" ;;
        Language)  info "use: snowfox lang <locale>" ;;
        Timezone)  info "use: snowfox tz <zone>" ;;
        User)      info "use: snowfox user passwd" ;;
    esac
}

cmd_bluetooth() {
    local act="${1:-toggle}"
    case "$act" in
        on)     bluetoothctl power on  >/dev/null && ok "bluetooth on"  ;;
        off)    bluetoothctl power off >/dev/null && ok "bluetooth off" ;;
        toggle|"")
            if bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; then
                bluetoothctl power off >/dev/null; ok "bluetooth off"
            else
                bluetoothctl power on  >/dev/null; ok "bluetooth on"
            fi
            ;;
        *) err "usage: snowfox bt <on|off|toggle>"; return "$SNOWFOX_EXIT_ERROR" ;;
    esac
}

cmd_keyboard() {
    local layout="${1:-}"
    [[ -z "$layout" ]] && { err "usage: snowfox kb <layout>"; return "$SNOWFOX_EXIT_ERROR"; }
    sed -i "s/^XKBLAYOUT=.*/XKBLAYOUT=\"$layout\"/" /etc/default/keyboard
    setupcon 2>/dev/null || true
    ok "keyboard layout: $layout"
}

cmd_language() {
    local locale="${1:-}"
    [[ -z "$locale" ]] && { err "usage: snowfox lang <locale>"; return "$SNOWFOX_EXIT_ERROR"; }
    update-locale LANG="$locale"
    ok "language: $locale"
}

cmd_timezone() {
    local zone="${1:-}"
    [[ -z "$zone" ]] && { err "usage: snowfox tz <zone>"; return "$SNOWFOX_EXIT_ERROR"; }
    timedatectl set-timezone "$zone" && ok "timezone: $zone"
}

cmd_user() {
    local sub="${1:-}" name="${2:-}"
    case "$sub" in
        passwd) passwd "$name" ;;
        add)    useradd -m -s /bin/bash "$name" && ok "added user: $name" ;;
        del)    userdel -r "$name" 2>/dev/null && ok "removed user: $name" ;;
        *)      err "usage: snowfox user <passwd|add|del> [name]"; return "$SNOWFOX_EXIT_ERROR" ;;
    esac
}

cmd_defaults() {
    local sub="${1:-}" key="${2:-}" val="${3:-}"
    local file="$HOME/.config/mimeapps.list"
    case "$sub" in
        set)
            [[ -z "$key" || -z "$val" ]] && { err "usage: snowfox def set <mime> <desktop>"; return "$SNOWFOX_EXIT_ERROR"; }
            mkdir -p "$(dirname "$file")"
            if grep -q "^$key=" "$file" 2>/dev/null; then
                sed -i "s|^$key=.*|$key=$val|" "$file"
            else
                echo "$key=$val" >> "$file"
            fi
            ok "$key → $val"
            ;;
        ""|list)
            header "snowfox def"
            [[ -r "$file" ]] && while IFS= read -r l; do row "" "$l"; done < "$file"
            ;;
        *) err "usage: snowfox def <set|list> [key] [value]"; return "$SNOWFOX_EXIT_ERROR" ;;
    esac
}
