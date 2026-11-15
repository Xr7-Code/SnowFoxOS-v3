#!/usr/bin/env bash
# ============================================================
#  SnowFoxOS v4 — CLI Utilities (quiet, minimal, English)
#  Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)
# ============================================================
#  Design principles (plan §5):
#   - header: accent color, no ASCII art
#   - key-value rows, fixed column width
#   - status dots (● green/yellow/red), not long text
#   - no spinner unless action > 2 s
#   - English everywhere
#   - exit codes: 0 ok, 1 error, 75 network unavailable
# ============================================================

if [[ -n "${_SNOWFOX_CLI_UTILS_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi
_SNOWFOX_CLI_UTILS_LOADED=1

# ─── Palette-driven colors ─────────────────────────────────
_PALETTE="${HOME}/.config/snowfox/palette.conf"

_cli_palette_get() {
    local key="$1" fallback="$2"
    if [[ -r "$_PALETTE" ]]; then
        local v
        v=$(sed -n "s/^${key}=//p" "$_PALETTE" | head -n1)
        [[ -n "$v" ]] && { printf '%s' "$v"; return 0; }
    fi
    printf '%s' "$fallback"
}

_hex_to_ansi_fg() {
    local h="${1#\#}"
    local r=$((16#${h:0:2})) g=$((16#${h:2:2})) b=$((16#${h:4:2}))
    printf '\033[38;2;%d;%d;%dm' "$r" "$g" "$b"
}

ACCENT=$(_hex_to_ansi_fg "$(_cli_palette_get accent '#9B59B6')")
FG=$(_hex_to_ansi_fg "$(_cli_palette_get fg '#E5E9F0')")
FG_DIM=$(_hex_to_ansi_fg "$(_cli_palette_get fg_dim '#8A919E')")

GREEN=$(_hex_to_ansi_fg "$(_cli_palette_get status_green '#7FB069')")
YELLOW=$(_hex_to_ansi_fg "$(_cli_palette_get status_yellow '#D4B86A')")
RED=$(_hex_to_ansi_fg "$(_cli_palette_get status_red '#C96A6A')")

BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# Legacy aliases — kept so existing module bodies still resolve.
PURPLE="$ACCENT"
LPURPLE="$ACCENT$BOLD"
ORANGE="$YELLOW"
CYAN="$ACCENT"
GRAY="$FG_DIM"
DGRAY="$FG_DIM"

# ─── Output helpers ────────────────────────────────────────
header() {
    printf '\n%s%s  %s%s\n' "$ACCENT" "$BOLD" "$1" "$RESET"
    printf '%s  %s%s\n' "$FG_DIM" "$(printf '─%.0s' $(seq 1 48))" "$RESET"
}

row() {
    local label="$1" value="$2" color="${3:-$FG}"
    printf '  %s%-18s%s %s%s%s\n' "$FG_DIM" "$label" "$RESET" "$color" "$value" "$RESET"
}

row_dot() {
    local label="$1" state="$2" value="$3"
    local dot color
    case "$state" in
        ok)   dot='●'; color="$GREEN"  ;;
        warn) dot='●'; color="$YELLOW" ;;
        err)  dot='●'; color="$RED"    ;;
        *)    dot='○'; color="$FG_DIM" ;;
    esac
    printf '  %s%-18s%s %s%s%s %s%s%s\n' \
        "$FG_DIM" "$label" "$RESET" "$color" "$dot" "$RESET" "$color" "$value" "$RESET"
}

bool_row() {
    if [[ "$2" == "true" ]]; then
        row_dot "$1" ok "on"
    else
        row_dot "$1" err "off"
    fi
}

info() { printf '  %s%s%s\n' "$FG_DIM" "$1" "$RESET"; }
ok()   { printf '  %s●%s %s\n' "$GREEN" "$RESET" "$1"; }
warn() { printf '  %s●%s %s\n' "$YELLOW" "$RESET" "$1" >&2; }
err()  { printf '  %s●%s %s\n' "$RED" "$RESET" "$1" >&2; }

divider() {
    printf '  %s%s%s\n' "$FG_DIM" "$(printf '─%.0s' $(seq 1 48))" "$RESET"
}

section() {
    printf '\n  %s%s%s%s\n' "$ACCENT" "$BOLD" "$1" "$RESET"
    divider
}

hint() {
    printf '  %s  %s%s\n' "$FG_DIM" "$1" "$RESET"
}

# ─── Progress bar ──────────────────────────────────────────
bar() {
    local val="${1:-0}" max="${2:-100}" width=20
    [[ "$max" -le 0 ]] && max=100
    [[ "$val" -lt 0 ]] && val=0
    [[ "$val" -gt "$max" ]] && val=$max
    local filled=$(( val * width / max ))
    local empty=$(( width - filled ))
    local pct=$(( val * 100 / max ))
    printf '  ['
    [[ $filled -gt 0 ]] && printf '%s%s%s' "$ACCENT" "$(printf '█%.0s' $(seq 1 $filled))" "$RESET"
    [[ $empty  -gt 0 ]] && printf '%s%s%s' "$FG_DIM" "$(printf '░%.0s' $(seq 1 $empty))" "$RESET"
    printf '] %s%s%%%s\n' "$BOLD" "$pct" "$RESET"
}

# ─── Spinner (only for actions > 2 s) ──────────────────────
_SPIN_PID=""
_SPIN_FRAMES=('·' '✻' '✽' '✶' '✳' '✢')

spin_start() {
    local msg="${1:-Working...}"
    (
        local i=0
        while true; do
            printf "\r  %s%s%s  %s%s%s " "$ACCENT" "${_SPIN_FRAMES[$i]}" "$RESET" "$FG_DIM" "$msg" "$RESET"
            i=$(( (i + 1) % ${#_SPIN_FRAMES[@]} ))
            sleep 0.1
        done
    ) &
    _SPIN_PID=$!
    disown "$_SPIN_PID" 2>/dev/null || true
}

_spin_kill() {
    if [[ -n "$_SPIN_PID" ]]; then
        kill "$_SPIN_PID" 2>/dev/null
        wait "$_SPIN_PID" 2>/dev/null || true
        printf '\r\033[K'
        _SPIN_PID=""
    fi
}

spin_stop() { _spin_kill; }
spin_ok()   { _spin_kill; ok "$1"; }
spin_err()  { _spin_kill; err "$1"; }
spin_warn() { _spin_kill; warn "$1"; }

# ─── Human-readable bytes ──────────────────────────────────
human_bytes() {
    local bytes="${1:-0}"
    if   [[ "$bytes" -ge 1073741824 ]]; then awk "BEGIN {printf \"%.1f GB\", $bytes/1073741824}"
    elif [[ "$bytes" -ge 1048576 ]];    then awk "BEGIN {printf \"%.1f MB\", $bytes/1048576}"
    elif [[ "$bytes" -ge 1024 ]];       then awk "BEGIN {printf \"%.0f KB\", $bytes/1024}"
    else echo "${bytes} B"
    fi
}

# ─── Exit codes ────────────────────────────────────────────
SNOWFOX_EXIT_OK=0
SNOWFOX_EXIT_ERROR=1
SNOWFOX_EXIT_NETWORK=75
