#!/bin/bash
# ============================================================
#  SnowFoxOS — CLI Modul: Hilfe & Befehlsübersicht
#  Wird von /usr/local/bin/snowfox gesourced.
# ============================================================


# ============================================================
# snowfox help
# ============================================================
cmd_help() {
    divider
    echo -e "${PURPLE}${BOLD}  🦊 SnowFoxOS — snowfox CLI${RESET}"
    echo -e "${GRAY}  Copyright (c) 2026 Alexander Valentin Ludwig${RESET}"
    divider
    echo ""
    echo -e "  ${CYAN}${BOLD}snowfox status${RESET}              — System-Übersicht"
    echo -e "  ${CYAN}${BOLD}snowfox battery${RESET}             — Akku Status, Verbrauch & Gesundheit"
    echo -e "  ${CYAN}${BOLD}snowfox profile [name]${RESET}      — Profil wechseln (balanced|performance|battery|privacy)"
    echo -e "  ${CYAN}${BOLD}snowfox update${RESET}              — System aktualisieren"
    echo -e "  ${CYAN}${BOLD}snowfox gpu${RESET}                 — GPU-Modus wechseln (Hybrid)"
    echo -e "  ${CYAN}${BOLD}snowfox audit${RESET}               — aktive Netzwerkverbindungen"
    echo -e "  ${CYAN}${BOLD}snowfox autostart [list|enable|disable]${RESET} — Autostart verwalten"
    echo -e "  ${CYAN}${BOLD}snowfox airmode [on|off|status]${RESET} — Funk komplett deaktivieren"
    echo -e "  ${CYAN}${BOLD}snowfox kill [mic|cam|all|restore]${RESET} — Hardware deaktivieren"
    echo -e "  ${CYAN}${BOLD}snowfox download <URL>${RESET}      — Video/Audio herunterladen"
    echo -e "  ${CYAN}${BOLD}snowfox stream <Suche|URL>${RESET}  — Video/Musik streamen"
    echo -e "  ${CYAN}${BOLD}snowfox pass [add|get|list|remove]${RESET} — Passwort-Manager"
    echo -e "  ${CYAN}${BOLD}snowfox tip${RESET}                 — Sicherheitstipp"
    echo -e "  ${CYAN}${BOLD}snowfox layout [tiling|floating]${RESET} — Fenstermodus wechseln"
    echo -e "  ${CYAN}${BOLD}snowfox webapp [add|list|open|remove]${RESET} — WebApps verwalten"
    echo -e "  ${CYAN}${BOLD}snowfox apps [list|remove]${RESET}  — installierte Rofi-Apps verwalten"
    echo -e "  ${CYAN}${BOLD}snowfox network${RESET}             — Netzwerk-Manager"
    echo -e "  ${CYAN}${BOLD}snowfox mesh${RESET}                — P2P-Mesh-Netzwerk (autark, verschlüsselt)"
    echo -e "  ${CYAN}${BOLD}snowfox node [desktop|server|console]${RESET} — Modus wechseln"
    echo -e "  ${CYAN}${BOLD}snowfox doctor${RESET}              — Systemdiagnose (RAM, Treiber, Configs, …)"
    echo -e "  ${CYAN}${BOLD}snowfox ai${RESET}                  — Offline-KI"
    echo -e "  ${CYAN}${BOLD}snowfox help${RESET}                — diese Hilfe"
    echo ""
    divider
}
