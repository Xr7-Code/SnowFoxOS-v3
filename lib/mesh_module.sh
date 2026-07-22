#!/bin/bash

# ============================================================
#  SnowFoxOS v3.0 — Mesh Module (Reticulum P2P Network)
# ============================================================

# Load utilities (assumes SCRIPT_DIR is set before sourcing)
source "$SCRIPT_DIR/lib/utils.sh"

# Global variables from main script (assumed to be sourced/exported):
# TARGET_USER, TARGET_HOME, SCRIPT_DIR

step "6b/10 — Mesh-Modul (Reticulum P2P-Netzwerk)"

if ask_install "Reticulum Mesh-Modul (autarkes P2P-Netzwerk)"; then
    info "Installiere Reticulum Network Stack..."

    if ! command -v pipx &>/dev/null; then
        info "pipx wird installiert..."
        apt-get update -qq
        apt-get install -y pipx
        pipx ensurepath
        export PATH="$PATH:$HOME/.local/bin"
        success "pipx installiert"
    else
        success "pipx bereits installiert"
    fi

    info "Installiere Reticulum in isolierter Umgebung via pipx..."
    if pipx install rns 2>/dev/null; then
        success "Reticulum (rns) via pipx installiert"
    else
        warn "pipx Installation fehlgeschlagen, versuche Fallback..."
        if command -v pip3 &>/dev/null; then
            pip3 install rns --break-system-packages
            success "Reticulum via pip3 (--break-system-packages) installiert"
        else
            apt-get install -y python3-pip
            pip3 install rns --break-system-packages
            success "Reticulum via pip3 installiert"
        fi
    fi

    MESH_SCRIPT_SRC="$SCRIPT_DIR/configs/snowfox-mesh.sh"
    MESH_SCRIPT_DST="$TARGET_HOME/.config/snowfox-mesh.sh"

    if [[ -f "$MESH_SCRIPT_SRC" ]]; then
        cp "$MESH_SCRIPT_SRC" "$MESH_SCRIPT_DST"
        chmod +x "$MESH_SCRIPT_DST"
        chown "$TARGET_USER:$TARGET_USER" "$MESH_SCRIPT_DST"
        success "Mesh-Modul aus Repo kopiert ($(basename "$MESH_SCRIPT_SRC"))"
    else
        warn "Mesh-Skript nicht im Repo: $MESH_SCRIPT_SRC"
    fi

    mkdir -p "$TARGET_HOME/.config/snowfox/mesh"
    mkdir -p "$TARGET_HOME/Downloads/MeshShare"
    chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.config/snowfox" 2>/dev/null || true

    success "Mesh-Modul installiert"
    info "  Starten: ${CYAN}snowfox mesh start --name \"Meine Node\"${RESET}"
    info "  Hilfe:   ${CYAN}snowfox mesh help${RESET}"
else
    info "Mesh-Modul übersprungen"
fi
