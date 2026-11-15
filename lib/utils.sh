#!/usr/bin/env bash
# ============================================================
#  SnowFoxOS v4 — Installer Utils
#  Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)
# ============================================================
#  - Source-guard
#  - Logging (info/success/warn/error/step)
#  - ask_install <prompt> [default=no] (§0b 3)
#  - wait_apt
#  - get_version() (§0d 30)
# ============================================================

if [[ -n "${_SNOWFOX_UTILS_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi
_SNOWFOX_UTILS_LOADED=1

PURPLE='\033[0;35m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
GRAY='\033[0;37m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${PURPLE}${BOLD}[SnowFox]${RESET} $1"; }
success() { echo -e "${GREEN}${BOLD}[  OK  ]${RESET} $1"; }
warn()    { echo -e "${ORANGE}${BOLD}[ WARN ]${RESET} $1"; }
error()   { echo -e "${RED}${BOLD}[FAILED]${RESET} $1"; exit 1; }

step() {
    echo -e "\n${PURPLE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${PURPLE}${BOLD}  $1${RESET}"
    echo -e "${PURPLE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
}

# ─── Version ────────────────────────────────────────────────
# Reads VERSION from the repo root. Returns semver or 0.0.0-*.
get_version() {
    local dir="${1:-${SCRIPT_DIR:-}}"
    local file="${dir:+$dir/}VERSION"
    if [[ ! -r "$file" ]]; then
        printf '0.0.0-unknown\n'
        return 1
    fi
    local v
    v="$(head -n1 "$file" | tr -d '[:space:]')"
    if [[ ! "$v" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        printf '0.0.0-invalid\n'
        return 1
    fi
    printf '%s\n' "$v"
}

# ─── ask_install (§0b 3) ────────────────────────────────────
# ask_install <prompt> [default=no]
# Defaults/unattended mode: deterministic, logs the answer.
# Interactive: [y/N] prompt, default N.
ask_install() {
    local prompt_text="$1"
    local default="${2:-no}"
    local unattended=false
    if [[ "${SNOWFOX_UNATTENDED:-false}" == "true" ]] \
       || [[ "${SNOWFOX_DEFAULTS:-false}" == "true" ]] \
       || [[ ! -t 0 ]]; then
        unattended=true
    fi

    if $unattended; then
        case "$default" in
            yes|y|1)
                info "[default] ${prompt_text}: yes (auto-answered)"
                return 0
                ;;
            *)
                info "[default] ${prompt_text}: no (auto-answered)"
                return 1
                ;;
        esac
    fi

    echo ""
    read -rp "$(echo -e "${PURPLE}${BOLD}"[SnowFox] Install "${prompt_text}"? [y/N]: "${RESET}")" choice
    [[ "$choice" =~ ^[yY]$ ]]
}

# ─── apt-Lock ───────────────────────────────────────────────
wait_apt() {
    local i=0
    while fuser /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock > /dev/null 2>&1; do
        [[ $i -eq 0 ]] && info "Waiting for apt lock..."
        sleep 2; i=$((i+1))
        [[ $i -gt 60 ]] && error "apt lock not released after 120s"
    done
}
