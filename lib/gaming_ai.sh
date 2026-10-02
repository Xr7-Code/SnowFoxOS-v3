#!/bin/bash
# ============================================================
#  SnowFoxOS v3.0 — Gaming & AI Setup
#  Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)
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
        gamemode 2>/dev/null || warn "Steam partially failed"
    systemctl enable gamemoded 2>/dev/null || true
    success "Steam + GameMode installed"

    # Fix: Steam freezes on workspace switch — the minimal system
    # was missing 64-bit Intel media drivers and off-screen rendering extensions.
    if $HAS_INTEL; then
        info "Installing Intel media drivers & off-screen rendering for Steam..."
        apt-get install -y intel-media-va-driver:amd64 libosmesa6 2>/dev/null || \
            warn "Intel media drivers partially failed"
        success "Intel media drivers for Steam installed (prevents workspace freezes)"
    fi

    info "Installing Proton GE..."
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
        success "Proton GE installed"
    else
        warn "Proton GE URL not found — install manually"
    fi
fi

step "7b/10 — Ollama (Local AI)"

if ask_install "Ollama (local AI, no model — engine only)"; then
    info "Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh 2>/dev/null || warn "Ollama installation failed"

    systemctl disable ollama 2>/dev/null || true
    systemctl stop ollama 2>/dev/null || true

    success "Ollama installed (not active — start with: ollama serve)"
    info "Install models with: ollama pull <model> (e.g. ollama pull mistral)"
fi

# ── SnowFox Console Launcher ─────────────────────────────────
LAUNCHER_DIR="$TARGET_HOME/SnowFox-Console-Launcher"
if ask_install "SnowFox Console Launcher (game hub for Steam & GOG)"; then
    if command -v git &>/dev/null; then
        info "Cloning SnowFox Console Launcher..."
        if [[ -d "$LAUNCHER_DIR" ]]; then
            info "Already present — updating..."
            if git -C "$LAUNCHER_DIR" pull 2>/dev/null; then
                success "Console Launcher updated"
            else
                warn "Update failed — check manually"
            fi
        else
            if sudo -u "$TARGET_USER" git clone \
                https://github.com/Xr7-Code/SnowFox-Console-Launcher.git \
                "$LAUNCHER_DIR" 2>/dev/null; then
                success "Console Launcher installed → $LAUNCHER_DIR"
            else
                warn "Clone failed — check network"
            fi
        fi

        # Set execute bit
        if [[ -f "$LAUNCHER_DIR/snowfox_launcher" ]]; then
            chmod +x "$LAUNCHER_DIR/snowfox_launcher"
            chown "$TARGET_USER:$TARGET_USER" "$LAUNCHER_DIR/snowfox_launcher"
            success "snowfox_launcher is executable"
        fi
    else
        warn "git not found — Console Launcher not installed"
        info "Install manually:"
        info "  git clone https://github.com/Xr7-Code/SnowFox-Console-Launcher.git ~/SnowFox-Console-Launcher"
    fi
fi
