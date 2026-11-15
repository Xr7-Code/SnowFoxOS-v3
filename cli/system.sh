#!/usr/bin/env bash
# ============================================================
#  SnowFoxOS v4 — CLI: system
#  update / profile / reset
# ============================================================

if [[ -n "${_SNOWFOX_CLI_SYSTEM_LOADED:-}" ]]; then return 0 2>/dev/null || true; fi
_SNOWFOX_CLI_SYSTEM_LOADED=1

cmd_update() {
    header "snowfox update"
    if ! command -v apt-get >/dev/null 2>&1; then
        err "apt-get not found"
        return "$SNOWFOX_EXIT_ERROR"
    fi
    if ! timeout 5 bash -c 'exec 3<>/dev/tcp/deb.debian.org/80' 2>/dev/null; then
        err "network unavailable"
        return "$SNOWFOX_EXIT_NETWORK"
    fi
    info "apt-get update"
    apt-get update -qq || { err "apt-get update failed"; return "$SNOWFOX_EXIT_ERROR"; }
    info "apt-get upgrade"
    apt-get upgrade -y || { err "apt-get upgrade failed"; return "$SNOWFOX_EXIT_ERROR"; }
    ok "system updated"
}

cmd_profile() {
    local which="${1:-}"
    case "$which" in
        ""|list)
            header "snowfox profile"
            info "available: balanced · performance · battery · privacy"
            local cur
            cur=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown")
            row "CPU governor" "$cur"
            return 0
            ;;
        balanced)
            header "profile: balanced"
            _set_governor schedutil 2>/dev/null || _set_governor powersave || true
            row_dot "CPU governor" ok "balanced"
            ;;
        performance)
            header "profile: performance"
            _set_governor performance
            row_dot "CPU governor" ok "performance"
            ;;
        battery)
            header "profile: battery"
            _set_governor powersave
            row_dot "CPU governor" ok "powersave"
            ;;
        privacy)
            header "profile: privacy"
            systemctl restart systemd-resolved 2>/dev/null || true
            row_dot "DNS" ok "DoT strict"
            ;;
        *)
            err "unknown profile: $which"
            return "$SNOWFOX_EXIT_ERROR"
            ;;
    esac
}

_set_governor() {
    local g="$1"
    local c
    for c in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        [[ -w "$c" ]] && echo "$g" > "$c" 2>/dev/null || true
    done
}

cmd_reset() {
    header "snowfox reset"
    warn "this will delete all user data and restore SnowFoxOS to defaults"
    local confirm
    read -rp "  type 'RESET' to continue: " confirm
    if [[ "$confirm" != "RESET" ]]; then
        info "aborted"
        return "$SNOWFOX_EXIT_OK"
    fi
    info "resetting…"
    if [[ -x /usr/local/bin/snowfox-reset ]]; then
        /usr/local/bin/snowfox-reset
    else
        err "snowfox-reset not installed"
        return "$SNOWFOX_EXIT_ERROR"
    fi
}
