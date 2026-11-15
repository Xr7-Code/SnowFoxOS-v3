#!/usr/bin/env bash
# ============================================================
#  SnowFoxOS v4 — CLI: theme
#  Thin wrapper around lib/theme_engine.sh (Prompt 2)
# ============================================================
set -u
set -o pipefail

if [[ -n "${_SNOWFOX_CLI_THEME_LOADED:-}" ]]; then return 0 2>/dev/null || true; fi
_SNOWFOX_CLI_THEME_LOADED=1

_self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/theme_engine.sh
if ! source "$_self_dir/lib/theme_engine.sh"; then
    err "failed to load lib/theme_engine.sh"
    return 1
fi

cmd_theme() {
    local sub="${1:-}"; shift || true
    case "$sub" in
        ""|list)    _theme_list ;;
        show)       _theme_show "${1:-}" ;;
        gui)        _theme_gui ;;
        color)      _theme_color "${1:-}" ;;
        check)      theme_check ;;
        reset)      theme_reset "${1:-nightfox}" && ok "reset to nightfox" ;;
        *)          theme_apply "$sub" && ok "theme applied: $sub" ;;
    esac
}

_theme_list() {
    header "snowfox theme"
    local active
    active=$(head -n1 "${TARGET_HOME:-$HOME}/.config/snowfox/theme" 2>/dev/null || echo "")
    theme_list | while IFS=$'\t' read -r name accent bg; do
        local marker=" "
        [[ "$name" == "$active" ]] && marker="●"
        printf '  %s %-16s %s████%s %s%s%s\n' \
            "$marker" "$name" \
            "$(_hex_to_ansi_fg "$accent")" "$RESET" \
            "$FG_DIM" "$bg" "$RESET"
    done
    printf '\n'
    info "snowfox theme <name>   apply"
    info "snowfox theme gui      Rofi picker"
}

_theme_show() {
    local name="${1:-$(head -n1 "${TARGET_HOME:-$HOME}/.config/snowfox/theme" 2>/dev/null || echo nightfox)}"
    theme_load "$THEME_DIR/${name}.theme" || { err "unknown theme: $name"; return "$SNOWFOX_EXIT_ERROR"; }
    header "snowfox theme show $name"
    row "dark"     "$THEME_DARK"
    row "accent"   "$THEME_ACCENT"
    row "accent2"  "$THEME_ACCENT2"
    row "accent3"  "$THEME_ACCENT3"
    row "bg"       "$THEME_BG"
    row "bg2"      "$THEME_BG2"
    row "fg"       "$THEME_FG"
    row "fg_dim"   "$THEME_FG_DIM"
}

_theme_gui() {
    if ! command -v rofi >/dev/null 2>&1; then
        err "rofi not installed"
        return "$SNOWFOX_EXIT_ERROR"
    fi
    local choice
    choice=$(theme_list | cut -f1 | rofi -dmenu -p "Theme")
    if [[ -n "$choice" ]]; then
        theme_apply "$choice" && ok "theme applied: $choice"
    fi
}

_theme_color() {
    local token="${1:-}"
    [[ -z "$token" ]] && { err "usage: snowfox theme color <accent|bg|fg|...>"; return "$SNOWFOX_EXIT_ERROR"; }
    local active
    active=$(head -n1 "${TARGET_HOME:-$HOME}/.config/snowfox/theme" 2>/dev/null || echo nightfox)
    theme_load "$THEME_DIR/${active}.theme" || return "$SNOWFOX_EXIT_ERROR"
    local var="THEME_${token^^}"
    printf '%s\n' "${!var:-}"
}
