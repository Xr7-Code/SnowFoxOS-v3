#!/bin/bash
# ============================================================
#  SnowFoxOS v3.0 — Mesh Module (Reticulum P2P Network)
#  Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)
# ============================================================

# Load utilities (assumes SCRIPT_DIR is set before sourcing)
source "$SCRIPT_DIR/lib/utils.sh"

# Global variables from main script (assumed to be sourced/exported):
# TARGET_USER, TARGET_HOME, SCRIPT_DIR

step "6b/10 — Mesh module (Reticulum P2P network)"

if ask_install "Reticulum Mesh module (self-contained P2P network)"; then
    info "Installing Reticulum Network Stack..."

    if ! command -v pipx &>/dev/null; then
        info "Installing pipx..."
        apt-get update -qq
        apt-get install -y pipx
        pipx ensurepath
        export PATH="$PATH:$HOME/.local/bin"
        success "pipx installed"
    else
        success "pipx already installed"
    fi

    info "Installing Reticulum in an isolated environment via pipx..."
    if pipx install rns 2>/dev/null; then
        success "Reticulum (rns) installed via pipx"
    else
        warn "pipx installation failed, trying fallback..."
        if command -v pip3 &>/dev/null; then
            pip3 install rns --break-system-packages
            success "Reticulum installed via pip3 (--break-system-packages)"
        else
            apt-get install -y python3-pip
            pip3 install rns --break-system-packages
            success "Reticulum installed via pip3"
        fi
    fi

    MESH_SCRIPT_SRC="$SCRIPT_DIR/configs/snowfox-mesh.sh"
    MESH_SCRIPT_DST="$TARGET_HOME/.config/snowfox-mesh.sh"

    if [[ -f "$MESH_SCRIPT_SRC" ]]; then
        cp "$MESH_SCRIPT_SRC" "$MESH_SCRIPT_DST"
        chmod +x "$MESH_SCRIPT_DST"
        chown "$TARGET_USER:$TARGET_USER" "$MESH_SCRIPT_DST"
        success "Mesh module copied from repo ($(basename "$MESH_SCRIPT_SRC"))"
    else
        warn "Mesh script not found in repo: $MESH_SCRIPT_SRC"
    fi

    mkdir -p "$TARGET_HOME/.config/snowfox/mesh"
    mkdir -p "$TARGET_HOME/Downloads/MeshShare"
    chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.config/snowfox" 2>/dev/null || true

    success "Mesh module installed"
    info "  Start: ${CYAN}snowfox mesh start --name \"My Node\"${RESET}"
    info "  Help:  ${CYAN}snowfox mesh help${RESET}"
else
    info "Mesh module skipped"
fi
