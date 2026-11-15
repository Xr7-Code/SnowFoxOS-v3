#!/usr/bin/env bash
# ============================================================
#  SnowFoxOS v4 — CLI: snap (config snapshots)
# ============================================================

if [[ -n "${_SNOWFOX_CLI_SNAP_LOADED:-}" ]]; then return 0 2>/dev/null || true; fi
_SNOWFOX_CLI_SNAP_LOADED=1

SNAP_DIR="$HOME/.config/snowfox/snapshots"

cmd_snap() {
    local sub="${1:-}"; shift || true
    case "$sub" in
        ""|list)  _snap_list ;;
        save)     _snap_save "${1:-}" ;;
        restore)  _snap_restore "${1:-}" ;;
        diff)     _snap_diff "${1:-}" ;;
        delete)   _snap_delete "${1:-}" ;;
        *)        err "usage: snowfox snap <save|restore|diff|delete|list>"; return "$SNOWFOX_EXIT_ERROR" ;;
    esac
}

_snap_list() {
    header "snowfox snap"
    mkdir -p "$SNAP_DIR"
    [[ -z "$(ls -A "$SNAP_DIR" 2>/dev/null)" ]] && { info "no snapshots"; return 0; }
    local f
    for f in "$SNAP_DIR"/*.tar.gz; do
        [[ -e "$f" ]] || continue
        row "$(basename "$f" .tar.gz)" "$(stat -c %y "$f" | cut -d. -f1)"
    done
}

_snap_save() {
    local name="${1:-snap-$(date +%Y%m%d-%H%M%S)}"
    mkdir -p "$SNAP_DIR"
    local -a dirs=(
        "$HOME/.config/i3"
        "$HOME/.config/polybar"
        "$HOME/.config/rofi"
        "$HOME/.config/kitty"
        "$HOME/.config/dunst"
        "$HOME/.config/picom.conf"
        "$HOME/.config/snowfox"
    )
    local existing=()
    local d
    for d in "${dirs[@]}"; do
        [[ -e "$d" ]] && existing+=("$(basename "$d")")
    done
    if tar -czf "$SNAP_DIR/$name.tar.gz" -C "$HOME/.config" "${existing[@]}"; then
        ok "snapshot saved: $name"
    else
        err "snapshot failed"
        return "$SNOWFOX_EXIT_ERROR"
    fi
}

_snap_restore() {
    local name="${1:-}"
    [[ -z "$name" ]] && { err "usage: snowfox snap restore <id>"; return "$SNOWFOX_EXIT_ERROR"; }
    local f="$SNAP_DIR/$name.tar.gz"
    [[ -f "$f" ]] || { err "not found: $name"; return "$SNOWFOX_EXIT_ERROR"; }
    if tar -xzf "$f" -C "$HOME/.config"; then
        ok "restored: $name"
    else
        err "restore failed"
        return "$SNOWFOX_EXIT_ERROR"
    fi
}

_snap_diff() {
    local name="${1:-}"
    [[ -z "$name" ]] && { err "usage: snowfox snap diff <id>"; return "$SNOWFOX_EXIT_ERROR"; }
    local f="$SNAP_DIR/$name.tar.gz"
    [[ -f "$f" ]] || { err "not found: $name"; return "$SNOWFOX_EXIT_ERROR"; }
    local tmp
    tmp=$(mktemp -d)
    tar -xzf "$f" -C "$tmp"
    diff -ru "$tmp" "$HOME/.config" 2>/dev/null | head -100 || true
    rm -rf "$tmp"
}

_snap_delete() {
    local name="${1:-}"
    [[ -z "$name" ]] && { err "usage: snowfox snap delete <id>"; return "$SNOWFOX_EXIT_ERROR"; }
    rm -f "$SNAP_DIR/$name.tar.gz" && ok "deleted: $name"
}
