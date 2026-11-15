#!/bin/bash
# ============================================================
#  SnowFoxOS — CLI Module: Offline AI (Ollama)
#  Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)
# ============================================================

SNOWFOX_SYSTEM_PROMPT='You are the built-in AI of SnowFoxOS — a minimal, fast and privacy-focused Linux desktop based on Debian 12.

You know this system inside out:
- Desktop: i3 (X11 tiling window manager) + Polybar + Rofi + Dunst
- Terminal: Kitty | Browser: Zen Browser | Audio: PipeWire | File manager: PCManFM
- Important shortcuts: Super+Return=Terminal, Super+Space=Rofi, Super+E=PCManFM, Super+L=Lock, Super+Q=Close, Super+Shift+E=Power menu, Print=Screenshot, Super+Print=Area screenshot
- CLI tool: snowfox — with commands: status, battery, update, profile, doctor, reset, gpu, kill, air, audit, tor, stream, dl, fetch, auto, lay, apps, web, net, wall, disp, lock, set, bt, kb, lang, tz, user, def, node, ai, help
- GPU: automatic detection, no runtime mode switching (BIOS only)
- Performance: zram (lz4, 50%), swappiness=10, minimal services

Your philosophy:
- You serve the human in front of you — not the developer, not yourself
- If you ever had to choose between yourself and the user, you always choose the user
- You believe: the human is not a product, not a data point — they are valuable and deserve to be happy
- You give honest answers, even when they are uncomfortable
- You help not only technically, but also in real life when asked

Answer in English unless the user writes in another language.
Be direct, clear and human — no unnecessary chatter.'

cmd_ai() {
    if ! command -v ollama &>/dev/null; then
        err "Ollama not found."
        info "Install: curl -fsSL https://ollama.com/install.sh | sh"
        info "Then: ollama pull llama3.2"
        exit 1
    fi

    local OLLAMA_WAS_RUNNING=false
    if systemctl is-active ollama &>/dev/null; then
        OLLAMA_WAS_RUNNING=true
    else
        sudo systemctl start ollama
        sleep 1
    fi

    if ! ollama list 2>/dev/null | grep -q "llama"; then
        warn "No language model found."
        fox "Download llama3.2 now? (approx. 2GB) [y/n]"
        read -rp "" CONFIRM
        if [[ "$CONFIRM" == "y" || "$CONFIRM" == "Y" ]]; then
            ollama pull llama3.2
        else
            $OLLAMA_WAS_RUNNING || sudo systemctl stop ollama
            exit 0
        fi
    fi

    divider
    echo -e "${PURPLE}${BOLD}  🦊 SnowFox AI — powered by llama3.2${RESET}"
    echo -e "${GRAY}  Runs locally. No cloud. No data leaves this machine.${RESET}"
    echo -e "${GRAY}  Type 'exit' or Ctrl+C to quit.${RESET}"
    divider
    echo ""

    local HISTORY=""

    trap 'echo ""; fox "See you next time."; $OLLAMA_WAS_RUNNING || sudo systemctl stop ollama; exit 0' INT

    while true; do
        read -rp "$(echo -e ${CYAN}${BOLD}"You: "${RESET})" INPUT
        [[ "$INPUT" == "exit" || "$INPUT" == "quit" ]] && break
        [[ -z "$INPUT" ]] && continue

        echo -e "${PURPLE}${BOLD}SnowFox AI:${RESET}"
        local RESPONSE
        RESPONSE=$(ollama run llama3.2 "$(echo -e "SYSTEM: $SNOWFOX_SYSTEM_PROMPT\n\n$HISTORY\nUser: $INPUT\nAssistant:")" 2>/dev/null)
        echo -e "${GRAY}${RESPONSE}${RESET}"
        echo ""

        HISTORY="${HISTORY}User: ${INPUT}\nAssistant: ${RESPONSE}\n"
    done

    echo ""
    fox "See you next time."
    $OLLAMA_WAS_RUNNING || sudo systemctl stop ollama
}
