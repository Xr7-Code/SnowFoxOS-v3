#!/usr/bin/env bash
# ============================================================
#  SnowFoxOS v4 — CLI: doctor
#  Diagnostics (RAM, drivers, configs)
# ============================================================

if [[ -n "${_SNOWFOX_CLI_DOCTOR_LOADED:-}" ]]; then return 0 2>/dev/null || true; fi
_SNOWFOX_CLI_DOCTOR_LOADED=1

cmd_doctor() {
    header "snowfox doctor"

    if [[ -r /proc/meminfo ]]; then
        local total avail
        total=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
        avail=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
        row "Memory" "$(human_bytes $(( (total-avail) * 1024 ))) used / $(human_bytes $((total * 1024))) total"
    fi

    if command -v lspci >/dev/null 2>&1; then
        local nvidia amd intel
        nvidia=$(lspci 2>/dev/null | grep -ic nvidia)
        amd=$(lspci 2>/dev/null | grep -ic amd)
        intel=$(lspci 2>/dev/null | grep -ic intel)
        row_dot "NVIDIA" "$([[ $nvidia -gt 0 ]] && echo ok || echo warn)" "$([[ $nvidia -gt 0 ]] && echo detected || echo absent)"
        row_dot "AMD"    "$([[ $amd -gt 0 ]] && echo ok || echo warn)"    "$([[ $amd -gt 0 ]] && echo detected || echo absent)"
        row_dot "Intel"  "$([[ $intel -gt 0 ]] && echo ok || echo warn)"  "$([[ $intel -gt 0 ]] && echo detected || echo absent)"
    fi

    local -a confs=(
        "$HOME/.config/i3/config"
        "$HOME/.config/polybar/config.ini"
        "$HOME/.config/rofi/config.rasi"
        "$HOME/.config/kitty/kitty.conf"
        "$HOME/.config/dunst/dunstrc"
        "$HOME/.config/picom.conf"
        "$HOME/.config/snowfox/palette.conf"
    )
    local c
    for c in "${confs[@]}"; do
        local name
        name=$(basename "$c")
        if [[ -r "$c" ]]; then
            row_dot "$name" ok "present"
        else
            row_dot "$name" warn "missing"
        fi
    done

    local svc
    for svc in foxdock polybar picom dunst; do
        if pgrep -x "$svc" >/dev/null 2>&1; then
            row_dot "$svc" ok "running"
        else
            row_dot "$svc" warn "not running"
        fi
    done
}
