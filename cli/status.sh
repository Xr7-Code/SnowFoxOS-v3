#!/usr/bin/env bash
# ============================================================
#  SnowFoxOS v4 — CLI: status
# ============================================================

if [[ -n "${_SNOWFOX_CLI_STATUS_LOADED:-}" ]]; then return 0 2>/dev/null || true; fi
_SNOWFOX_CLI_STATUS_LOADED=1

cmd_status() {
    case "${1:-}" in
        battery|bat) _status_battery ;;
        ""|overview) _status_overview ;;
        -h|--help)   info "usage: snowfox status [battery]" ;;
        *)           err "unknown status mode: $1"; return 1 ;;
    esac
}

_status_overview() {
    header "snowfox status"
    row "Host" "$(hostname 2>/dev/null || echo unknown)"

    local os="SnowFoxOS v4"
    [[ -r /etc/os-release ]] && os="$(. /etc/os-release && echo "$PRETTY_NAME")"
    row "OS" "$os"
    row "Kernel" "$(uname -r)"

    if [[ -r /proc/uptime ]]; then
        local up_s
        up_s=$(awk '{printf "%d", $1}' /proc/uptime)
        row "Uptime" "$(printf '%dd %02dh %02dm' $((up_s/86400)) $((up_s%86400/3600)) $((up_s%3600/60)))"
    fi

    if [[ -r /proc/meminfo ]]; then
        local total_kb avail_kb used_kb
        total_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
        avail_kb=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
        used_kb=$(( total_kb - avail_kb ))
        row "Memory" "$(human_bytes $((used_kb * 1024))) / $(human_bytes $((total_kb * 1024)))"
    fi

    if command -v df >/dev/null 2>&1; then
        local df_out
        df_out=$(df -h --output=used,size,pcent / 2>/dev/null | tail -n1)
        [[ -n "$df_out" ]] && row "Disk /" "$(echo "$df_out" | awk '{print $1 " / " $2 " (" $3 ")"}')"
    fi

    [[ -r /proc/loadavg ]] && row "Load" "$(awk '{print $1, $2, $3}' /proc/loadavg)"

    section "Status"
    _dot_ufw
    _dot_ssh
    _dot_dot
    _dot_unattended
    _dot_foxdock

    if _is_laptop; then
        section "Battery"
        _status_battery
    fi
}

_status_battery() {
    header "snowfox status battery"

    if ! _is_laptop; then
        info "not a laptop — no battery"
        return 0
    fi

    local bat
    bat=$(ls /sys/class/power_supply/ 2>/dev/null | grep -E '^BAT' | head -n1)
    if [[ -z "$bat" ]]; then
        info "no battery device"
        return 0
    fi

    local cap status
    cap=$(cat "/sys/class/power_supply/$bat/capacity" 2>/dev/null || echo 0)
    status=$(cat "/sys/class/power_supply/$bat/status"  2>/dev/null || echo Unknown)
    row "Capacity" "$cap%"
    row "Status"   "$status"
    bar "$cap" 100

    local health="unknown"
    if [[ -r "/sys/class/power_supply/$bat/energy_full" ]] \
       && [[ -r "/sys/class/power_supply/$bat/energy_full_design" ]]; then
        local full design
        full=$(cat "/sys/class/power_supply/$bat/energy_full")
        design=$(cat "/sys/class/power_supply/$bat/energy_full_design")
        [[ "$design" -gt 0 ]] && health=$(( full * 100 / design ))
    fi
    row "Health" "${health}%"
}

_is_laptop() {
    local chassis
    chassis=$(cat /sys/class/dmi/id/chassis_type 2>/dev/null || echo 0)
    [[ "$chassis" =~ ^(8|9|10|14)$ ]] && return 0
    compgen -G "/sys/class/power_supply/BAT*" >/dev/null && return 0
    return 1
}

_dot_ufw() {
    if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
        row_dot "Firewall (ufw)" ok "active"
    else
        row_dot "Firewall (ufw)" err "inactive"
    fi
}

_dot_ssh() {
    if systemctl is-active ssh >/dev/null 2>&1; then
        row_dot "SSH server" warn "running"
    else
        row_dot "SSH server" ok "disabled"
    fi
}

_dot_dot() {
    if [[ -r /etc/systemd/resolved.conf.d/snowfox.conf ]] \
       && grep -q '^DNSOverTLS=yes' /etc/systemd/resolved.conf.d/snowfox.conf; then
        row_dot "DNS over TLS" ok "enabled"
    else
        row_dot "DNS over TLS" warn "not configured"
    fi
}

_dot_unattended() {
    if systemctl is-active unattended-upgrades >/dev/null 2>&1; then
        row_dot "Auto updates" ok "security only"
    else
        row_dot "Auto updates" warn "inactive"
    fi
}

_dot_foxdock() {
    if pgrep -x foxdock >/dev/null 2>&1; then
        row_dot "foxdock" ok "running"
    else
        row_dot "foxdock" warn "not running"
    fi
}
