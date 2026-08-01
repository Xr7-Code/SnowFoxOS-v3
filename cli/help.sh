#!/bin/bash
# ============================================================
#  SnowFoxOS — CLI Modul: Hilfe & Befehlsübersicht
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
        printf "  ${CYAN}${BOLD}  %-38s${RESET}${DGRAY}%s${RESET}\n" "$cmd" "$desc"
    }

    _help_section "System & Status"
    _help_cmd "snowfox status"                    "System-Übersicht"
    _help_cmd "snowfox battery"                   "Akku, Verbrauch & Gesundheit"
    _help_cmd "snowfox update"                    "System & CLI aktualisieren"
    _help_cmd "snowfox profile [name]"            "balanced · performance · battery · privacy"
    _help_cmd "snowfox node [desktop|server|console]" "Systemmodus wechseln"
    _help_cmd "snowfox doctor"                    "Diagnose: RAM, Treiber, Configs"
    _help_cmd "snowfox reset"                     "Werkszustand / System zurücksetzen"
    echo ""

    _help_section "Einstellungen & Konfiguration"
    _help_cmd "snowfox settings"                  "Übersicht aller Einstellungen"
    _help_cmd "snowfox settings defaults"         "Standard-Apps (LibreWolf, Codium, PCManFM, Kitty)"
    _help_cmd "snowfox settings keyboard [layout]" "Tastaturlayout anzeigen / ändern (z.B. de)"
    _help_cmd "snowfox settings language [locale]" "Systemsprache festlegen (z.B. de_DE.UTF-8)"
    _help_cmd "snowfox settings time [zone]"      "Zeitzone & Uhrzeit (z.B. Europe/Berlin)"
    _help_cmd "snowfox settings user [passwd|add|del]" "Nutzer & Passwörter verwalten"
    _help_cmd "snowfox settings bluetooth [on|off]" "Bluetooth steuern"
    echo ""

    _help_section "Hardware & Sicherheit"
    _help_cmd "snowfox gpu"                       "GPU-Modus wechseln (Hybrid)"
    _help_cmd "snowfox kill [mic|cam|all|restore]" "Hardware-Kill"
    _help_cmd "snowfox airmode [on|off|status]"   "Funk komplett deaktivieren"
    _help_cmd "snowfox audit"                     "Aktive Netzwerkverbindungen"
    _help_cmd "snowfox pass [add|get|list|remove]" "Passwort-Manager"
    _help_cmd "snowfox tip"                       "Sicherheitstipp"
    echo ""

    _help_section "Desktop"
    _help_cmd "snowfox autostart [list|enable|disable]" "Autostart verwalten"
    _help_cmd "snowfox layout [tiling|floating]"  "Fenstermodus wechseln"
    _help_cmd "snowfox apps [list|remove]"        "Rofi-Apps verwalten"
    _help_cmd "snowfox webapp [add|list|open|remove]" "WebApps verwalten"
    _help_cmd "snowfox network"                   "Netzwerk-Manager"
    echo ""

    _help_section "Medien & KI"
    _help_cmd "snowfox download <URL>"            "Video/Audio herunterladen"
    _help_cmd "snowfox stream <Suche|URL>"        "Video/Musik streamen"
    _help_cmd "snowfox tor [on|off|status]"       "Tor-Modus: IP, DNS, MAC anonymisieren"
    _help_cmd "snowfox mesh"                      "P2P-Mesh (autark, verschlüsselt)"
    _help_cmd "snowfox ai"                        "Offline-KI (Ollama)"
    echo ""

    divider
    info "snowfox <Befehl> --help  für Details zu einem Befehl"
    echo ""
}
