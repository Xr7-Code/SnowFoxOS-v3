#!/bin/bash
# ============================================================
#  SnowFoxOS — CLI Module: Help & Command Overview
#  Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)
# ============================================================

cmd_help() {
    echo ""
    echo -e "${PURPLE}${BOLD}  ┌────────────────────────────────────────────────┐${RESET}"
    echo -e "${PURPLE}${BOLD}  │                                                │${RESET}"
    echo -e "${PURPLE}${BOLD}  │   🦊  ${LPURPLE}SnowFoxOS ${DGRAY}— snowfox CLI${PURPLE}                  │${RESET}"
    echo -e "${PURPLE}${BOLD}  │   ${DGRAY}Copyright (c) 2026 Alexander Valentin Ludwig${PURPLE}  │${RESET}"
    echo -e "${PURPLE}${BOLD}  │                                                │${RESET}"
    echo -e "${PURPLE}${BOLD}  └────────────────────────────────────────────────┘${RESET}"
    echo ""

    _help_section() {
        echo -e "  ${LPURPLE}${BOLD}$1${RESET}"
        echo -e "  ${PURPLE}${DIM}  ──────────────────────────────────────────────${RESET}"
    }

    _help_cmd() {
        local cmd="$1" desc="$2"
        printf "  ${CYAN}${BOLD}  %-34s${RESET}${DGRAY}%s${RESET}\n" "$cmd" "$desc"
    }

    _help_section "System & Status"
    _help_cmd "snowfox st"                 "System overview"
    _help_cmd "snowfox bat"                "Battery, consumption & health"
    _help_cmd "snowfox up"                 "Update system & CLI"
    _help_cmd "snowfox prof [name]"        "balanced · performance · battery · privacy"
    _help_cmd "snowfox doc"                "Diagnostics: RAM, drivers, configs"
    _help_cmd "snowfox rst"                "Factory reset — deletes all data"
    echo ""

    _help_section "Hardware & Privacy"
    _help_cmd "snowfox gpu"                "Switch GPU mode (Hybrid)"
    _help_cmd "snowfox kill [mic|cam|all|restore]" "Hardware kill switches"
    _help_cmd "snowfox air [on|off|status]" "Disable all wireless interfaces"
    _help_cmd "snowfox audit"              "Active network connections"
    _help_cmd "snowfox pass [add|get|list|remove]" "Password manager"
    _help_cmd "snowfox tip"                "Security tip"
    _help_cmd "snowfox tor [on|off|status]" "Tor mode: IP, DNS, MAC anonymization"
    echo ""

    _help_section "Media"
    _help_cmd "snowfox stream <search|URL>" "Stream video/audio via mpv"
    _help_cmd "snowfox dl <URL>"            "Download video or audio"
    _help_cmd "snowfox fetch <URL>"         "High-speed download (16 connections)"
    echo ""

    _help_section "Desktop"
    _help_cmd "snowfox auto [list|enable|disable]" "Manage autostart"
    _help_cmd "snowfox lay [tiling|floating]" "Switch window mode"
    _help_cmd "snowfox apps [list|remove]"  "Manage Rofi apps"
    _help_cmd "snowfox web [add|list|open|remove]" "Manage web apps"
    _help_cmd "snowfox net"                 "Network manager"
    _help_cmd "snowfox wall"                "Wallpaper selector"
    _help_cmd "snowfox disp"                "Display configuration"
    _help_cmd "snowfox lock"                "Lock screen"
    echo ""

    _help_section "Settings"
    _help_cmd "snowfox set"                 "Settings overview (terminal)"
    _help_cmd "snowfox set gui"             "Settings overview (Rofi menu)"
    _help_cmd "snowfox bt [on|off|toggle]"  "Bluetooth control"
    _help_cmd "snowfox kb [layout]"         "Keyboard layout (e.g. de, us)"
    _help_cmd "snowfox lang [locale]"       "System language (e.g. en_US.UTF-8)"
    _help_cmd "snowfox tz [zone]"           "Timezone (e.g. Europe/Berlin)"
    _help_cmd "snowfox user [passwd|add|del]" "User management"
    _help_cmd "snowfox def [set] <key> <val>" "Default applications"
    echo ""

    _help_section "Node & AI"
    _help_cmd "snowfox node [desktop|server|console]" "System mode"
    _help_cmd "snowfox ai"                  "Offline AI (Ollama)"
    # _help_cmd "snowfox mesh"              "P2P mesh (Reticulum)"
    echo ""

    divider
    info "snowfox <command> --help  for details on a command"
    echo ""
}
