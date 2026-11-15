#!/usr/bin/env bash
# ============================================================
#  SnowFoxOS v4 — CLI: desktop
#  auto / layout / web
# ============================================================

if [[ -n "${_SNOWFOX_CLI_DESKTOP_LOADED:-}" ]]; then return 0 2>/dev/null || true; fi
_SNOWFOX_CLI_DESKTOP_LOADED=1

cmd_start() {
    local action="${1:-list}"
    local name="${2:-}"
    local autostart_dir="$HOME/.config/autostart"

    case "$action" in
        list)
            header "snowfox auto"
            if [[ -d "$autostart_dir" ]]; then
                local f
                for f in "$autostart_dir"/*.desktop; do
                    [[ -e "$f" ]] || continue
                    row "$(basename "$f" .desktop)" "enabled"
                done
            else
                info "no autostart entries"
            fi
            ;;
        enable)
            [[ -z "$name" ]] && { err "usage: snowfox auto enable <name>"; return "$SNOWFOX_EXIT_ERROR"; }
            mkdir -p "$autostart_dir"
            ln -sf "/usr/share/applications/${name}.desktop" "$autostart_dir/${name}.desktop"
            ok "enabled: $name"
            ;;
        disable)
            [[ -z "$name" ]] && { err "usage: snowfox auto disable <name>"; return "$SNOWFOX_EXIT_ERROR"; }
            rm -f "$autostart_dir/${name}.desktop"
            ok "disabled: $name"
            ;;
        *) err "usage: snowfox auto <list|enable|disable>"; return "$SNOWFOX_EXIT_ERROR" ;;
    esac
}

cmd_layout() {
    local mode="${1:-}"
    case "$mode" in
        tiling)   i3-msg 'workspace_layout default' >/dev/null && ok "layout: tiling" ;;
        floating) i3-msg 'workspace_layout stacking' >/dev/null && ok "layout: floating" ;;
        ""|show)
            header "snowfox layout"
            if i3-msg -t get_tree 2>/dev/null | grep -q '"layout":"stacked"'; then
                row "layout" "floating"
            else
                row "layout" "tiling"
            fi
            ;;
        *) err "usage: snowfox layout <tiling|floating>"; return "$SNOWFOX_EXIT_ERROR" ;;
    esac
}

cmd_webapp() {
    local sub="${1:-}"
    local arg="${2:-}"
    local WEBAPP_DIR="$HOME/.local/share/applications"
    local WEBAPP_DATA="$HOME/.config/snowfox/webapps"

    case "$sub" in
        ""|list)
            header "snowfox web"
            mkdir -p "$WEBAPP_DATA"
            [[ -z "$(ls -A "$WEBAPP_DATA" 2>/dev/null)" ]] && { info "no webapps registered"; return 0; }
            local f
            for f in "$WEBAPP_DATA"/*.url; do
                [[ -e "$f" ]] || continue
                row "$(basename "$f" .url)" "$(cat "$f")"
            done
            ;;
        add)
            [[ -z "$arg" ]] && { err "usage: snowfox web add <name> [url]"; return "$SNOWFOX_EXIT_ERROR"; }
            local name="$arg"
            local url="${3:-}"
            if [[ -z "$url" ]]; then
                read -rp "  URL: " url
            fi
            [[ -z "$url" ]] && { err "no URL"; return "$SNOWFOX_EXIT_ERROR"; }
            mkdir -p "$WEBAPP_DATA" "$WEBAPP_DIR"
            echo "$url" > "$WEBAPP_DATA/${name}.url"
            cat > "$WEBAPP_DIR/snowfox-web-${name}.desktop" <<EOF
[Desktop Entry]
Name=${name}
Comment=WebApp — ${url}
Exec=firefox-esr --new-window ${url}
Icon=web-browser
Type=Application
Categories=Network;WebBrowser;
EOF
            ok "webapp added: $name"
            ;;
        open)
            [[ -z "$arg" ]] && { err "usage: snowfox web open <name>"; return "$SNOWFOX_EXIT_ERROR"; }
            local url
            url=$(cat "$WEBAPP_DATA/${arg}.url" 2>/dev/null || true)
            [[ -z "$url" ]] && { err "unknown webapp: $arg"; return "$SNOWFOX_EXIT_ERROR"; }
            firefox-esr --new-window "$url" &
            ;;
        remove)
            [[ -z "$arg" ]] && { err "usage: snowfox web remove <name>"; return "$SNOWFOX_EXIT_ERROR"; }
            rm -f "$WEBAPP_DATA/${arg}.url" "$WEBAPP_DIR/snowfox-web-${arg}.desktop"
            ok "webapp removed: $arg"
            ;;
        *) err "usage: snowfox web <add|list|open|remove>"; return "$SNOWFOX_EXIT_ERROR" ;;
    esac
}
