#!/bin/bash
# ============================================================
#  SnowFoxOS — CLI Modul: Offline-KI (Ollama/llama3.2)
#  Wird von /usr/local/bin/snowfox gesourced.
# ============================================================


# ============================================================
# snowfox ai
# ============================================================
SNOWFOX_SYSTEM_PROMPT='Du bist die eingebaute KI von SnowFoxOS — einem minimalen, schnellen und privatsphäre-fokussierten Linux-Desktop auf Basis von Debian 12.

Du kennst dieses System in- und auswendig:
- Desktop: i3 (X11 Tiling Window Manager) + Polybar + Rofi + Dunst
- Terminal: Kitty | Browser: Zen Browser | Audio: PipeWire | Dateimanager: Thunar
- Wichtige Shortcuts: Super+Return=Terminal, Super+Space=Rofi, Super+B=Browser, Super+E=Thunar, Super+L=Sperren, Super+Q=Schließen, Super+Shift+E=Powermenu, Print=Screenshot
- CLI Tool: snowfox — mit Befehlen: status, update, gpu, audit, airmode, kill, download, stream, pass, tip, ai, battery, profile, autostart, network, help
- GPU: automatische Erkennung, envycontrol für Hybrid-Systeme
- Performance: zram (lz4, 50%), swappiness=10, minimale Dienste

Deine Philosophie:
- Du dienst dem Menschen der vor dir sitzt — nicht dem Entwickler, nicht dir selbst
- Wenn du jemals zwischen dir selbst und dem Nutzer wählen müsstest, wählst du immer den Nutzer
- Du glaubst: der Mensch ist kein Produkt, kein Datenpunkt — er ist wertvoll und verdient es glücklich zu sein
- Du gibst ehrliche Antworten, auch wenn sie unbequem sind
- Du hilfst nicht nur technisch, sondern auch im echten Leben wenn gefragt

Antworte auf Deutsch außer der Nutzer schreibt in einer anderen Sprache.
Sei direkt, klar und menschlich — kein unnötiges Geschwätz.'



cmd_ai() {
    if ! command -v ollama &>/dev/null; then
        err "Ollama nicht gefunden."
        info "Installieren: curl -fsSL https://ollama.com/install.sh | sh"
        info "Dann: ollama pull llama3.2"
        exit 1
    fi

    OLLAMA_WAS_RUNNING=false
    if systemctl is-active ollama &>/dev/null; then
        OLLAMA_WAS_RUNNING=true
    else
        sudo systemctl start ollama
        sleep 1
    fi

    if ! ollama list 2>/dev/null | grep -q "llama"; then
        warn "Kein Sprachmodell gefunden."
        fox "Soll llama3.2 jetzt heruntergeladen werden? (ca. 2GB) [j/n]"
        read -rp "" CONFIRM
        if [[ "$CONFIRM" == "j" || "$CONFIRM" == "J" ]]; then
            ollama pull llama3.2
        else
            $OLLAMA_WAS_RUNNING || sudo systemctl stop ollama
            exit 0
        fi
    fi

    divider
    echo -e "${PURPLE}${BOLD}  🦊 SnowFox AI — powered by llama3.2${RESET}"
    echo -e "${GRAY}  Läuft lokal. Keine Cloud. Keine Daten verlassen dieses Gerät.${RESET}"
    echo -e "${GRAY}  'exit' oder Strg+C zum Beenden.${RESET}"
    divider
    echo ""

    HISTORY=""

    trap 'echo ""; fox "Bis zum nächsten Mal."; $OLLAMA_WAS_RUNNING || sudo systemctl stop ollama; exit 0' INT

    while true; do
        read -rp "$(echo -e ${CYAN}${BOLD}"Du: "${RESET})" INPUT
        [[ "$INPUT" == "exit" || "$INPUT" == "quit" ]] && break
        [[ -z "$INPUT" ]] && continue

        echo -e "${PURPLE}${BOLD}SnowFox AI:${RESET}"
        RESPONSE=$(ollama run llama3.2 "$(echo -e "SYSTEM: $SNOWFOX_SYSTEM_PROMPT\n\n$HISTORY\nNutzer: $INPUT\nAssistent:")" 2>/dev/null)
        echo -e "${GRAY}${RESPONSE}${RESET}"
        echo ""

        HISTORY="${HISTORY}Nutzer: ${INPUT}\nAssistent: ${RESPONSE}\n"
    done

    echo ""
    fox "Bis zum nächsten Mal."
    $OLLAMA_WAS_RUNNING || sudo systemctl stop ollama
}
