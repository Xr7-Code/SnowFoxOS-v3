#!/usr/bin/env bash
# ============================================================
#  SnowFoxOS v4 — CLI: help
# ============================================================

if [[ -n "${_SNOWFOX_CLI_HELP_LOADED:-}" ]]; then return 0 2>/dev/null || true; fi
_SNOWFOX_CLI_HELP_LOADED=1

cmd_help() {
    printf '\n'
    printf '%s%s  SnowFoxOS v4%s\n' "$ACCENT" "$BOLD" "$RESET"
    printf '%s  snowfox CLI%s\n\n' "$FG_DIM" "$RESET"

    _help_group() {
        printf '  %s%s%s%s\n' "$ACCENT" "$BOLD" "$1" "$RESET"
        printf '  %s%s%s\n' "$FG_DIM" "$(printf '─%.0s' $(seq 1 46))" "$RESET"
    }
    _help_item() {
        printf '  %s%-32s%s %s%s%s\n' "$FG" "$1" "$RESET" "$FG_DIM" "$2" "$RESET"
    }

    _help_group "System"
    _help_item "snowfox status [battery]"     "System overview / battery details"
    _help_item "snowfox update"               "Update system & CLI"
    _help_item "snowfox profile <name>"       "balanced · performance · battery · privacy"
    _help_item "snowfox doctor"               "Diagnostics"
    _help_item "snowfox reset"                "Factory reset"
    printf '\n'

    _help_group "Hardware & Privacy"
    _help_item "snowfox gpu"                  "GPU information"
    _help_item "snowfox kill <mic|cam|all|restore>" "Hardware kill switches"
    _help_item "snowfox air <on|off|status>"  "Disable wireless interfaces"
    _help_item "snowfox audit [live]"         "Active network connections"
    printf '\n'

    _help_group "Media"
    _help_item "snowfox stream <query|URL>"   "Stream video/audio via mpv"
    _help_item "snowfox download <URL>"       "Download video/audio"
    _help_item "snowfox fetch <URL>"          "High-speed download (16 connections)"
    printf '\n'

    _help_group "Desktop"
    _help_item "snowfox auto <list|enable|disable>" "Manage autostart entries"
    _help_item "snowfox layout <tiling|floating>"   "Switch window mode"
    _help_item "snowfox web <add|list|open|remove>" "Manage WebApps"
    printf '\n'

    _help_group "Theme"
    _help_item "snowfox theme"                "List themes with swatches"
    _help_item "snowfox theme <name>"         "Apply a theme"
    _help_item "snowfox theme show [name]"    "Show all colors of a theme"
    _help_item "snowfox theme gui"            "Rofi theme picker"
    _help_item "snowfox theme color <token>"  "Print a single color value"
    _help_item "snowfox theme check"          "Validate theme files"
    _help_item "snowfox theme reset"          "Back to default (nightfox)"
    _help_item "snowfox wallpaper"            "Wallpaper selector"
    _help_item "snowfox wallpaper auto <img>" "Generate theme from image"
    printf '\n'

    _help_group "Stash — Package Manager"
    _help_item "snowfox stash"                "Show categories"
    _help_item "snowfox stash <category>"     "List packages in category"
    _help_item "snowfox stash find <query>"   "Search apt"
    _help_item "snowfox stash install <pkg>"  "Install a package"
    _help_item "snowfox stash list"           "List installed apps"
    _help_item "snowfox stash remove <pkg>"   "Remove a package"
    printf '\n'

    _help_group "Settings"
    _help_item "snowfox set"                  "Terminal settings overview"
    _help_item "snowfox set gui"              "Rofi settings menu"
    _help_item "snowfox bt <on|off|toggle>"   "Bluetooth control"
    _help_item "snowfox kb <layout>"          "Keyboard layout"
    _help_item "snowfox lang <locale>"        "System language"
    _help_item "snowfox tz <zone>"            "Timezone"
    _help_item "snowfox user <passwd|add|del>" "User management"
    _help_item "snowfox def <set> <key> <val>" "Default applications"
    printf '\n'

    _help_group "Snapshots"
    _help_item "snowfox snap save [name]"     "Save current config"
    _help_item "snowfox snap restore <id>"    "Restore a snapshot"
    _help_item "snowfox snap diff <id>"       "Compare snapshot to current"
    _help_item "snowfox snap delete <id>"     "Delete a snapshot"
    printf '\n'

    divider
    info "snowfox <command> --help  for details on a command"
    printf '\n'
}
