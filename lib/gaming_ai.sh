#!/bin/bash

# ============================================================
#  SnowFoxOS v3.0 — Gaming & AI Setup
# ============================================================

# Load utilities (assumes SCRIPT_DIR is set before sourcing)
source "$SCRIPT_DIR/lib/utils.sh"

# Global variables from main script (assumed to be sourced/exported):
# TARGET_USER, TARGET_HOME, HAS_INTEL

step "7/10 — Steam & Gaming"

if ask_install "Steam"; then
    wait_apt
    apt-get install -y \
        steam steam-devices \
        libvulkan1 libvulkan1:i386 \
        vulkan-tools libgl1-mesa-dri:i386 \
        mesa-vulkan-drivers:i386 \
        gamemode 2>/dev/null || warn "Steam teilweise fehlgeschlagen"
    systemctl enable gamemoded 2>/dev/null || true
    success "Steam + GameMode installiert"

    # Fix: Steam-Freezes beim Workspace-Wechsel — dem Minimalsystem
    # fehlten die 64-Bit-Intel-Medientreiber und Off-Screen-Rendering-Erweiterungen.
    if $HAS_INTEL; then
        info "Installiere Intel-Medientreiber & Off-Screen-Rendering für Steam..."
        apt-get install -y intel-media-va-driver:amd64 libosmesa6 2>/dev/null || \
            warn "Intel-Medientreiber teilweise fehlgeschlagen"
        success "Intel-Medientreiber für Steam installiert (verhindert Workspace-Freezes)"
    fi

    info "Installiere Proton GE..."
    PROTON_GE_URL=""
    PROTON_GE_JSON=$(curl -sf https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest 2>/dev/null)
    if [[ -n "$PROTON_GE_JSON" ]]; then
        PROTON_GE_URL=$(echo "$PROTON_GE_JSON" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for a in data.get('assets', []):
        if a['name'].endswith('.tar.gz'):
            print(a['browser_download_url'])
            break
except: pass
" 2>/dev/null)
    fi
    if [[ -n "$PROTON_GE_URL" ]]; then
        curl -L "$PROTON_GE_URL" -o /tmp/proton-ge.tar.gz
        mkdir -p "$TARGET_HOME/.steam/root/compatibilitytools.d"
        tar -xzf /tmp/proton-ge.tar.gz -C "$TARGET_HOME/.steam/root/compatibilitytools.d/"
        rm -f /tmp/proton-ge.tar.gz
        chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.steam/root/compatibilitytools.d/"
        success "Proton GE installiert"
    else
        warn "Proton GE URL nicht ermittelt — manuell installieren"
    fi
fi

step "7b/10 — Ollama (Lokale KI)"

if ask_install "Ollama (lokale KI, kein Modell — nur Engine)"; then
    info "Installiere Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh 2>/dev/null || warn "Ollama Installation fehlgeschlagen"

    systemctl disable ollama 2>/dev/null || true
    systemctl stop ollama 2>/dev/null || true

    success "Ollama installiert (nicht aktiv — starten mit: ollama serve)"
    info "Modelle installieren mit: ollama pull <modell> (z.B. ollama pull mistral)"
fi
