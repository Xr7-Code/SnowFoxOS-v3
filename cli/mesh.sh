#!/bin/bash
# ============================================================
#  SnowFoxOS — CLI Module: P2P Mesh Network (Wrapper)
#  Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)
# ============================================================

MESH_SCRIPT="$HOME/.config/snowfox-mesh.sh"

cmd_mesh_wrapper() {
    if [[ ! -f "$MESH_SCRIPT" ]]; then
        err "Mesh module not found!"
        info "  Install it with:"
        info "    ${CYAN}curl -o $MESH_SCRIPT https://raw.githubusercontent.com/Xr7-Code/SnowFoxOS-v3/main/snowfox-mesh.sh${RESET}"
        info "    ${CYAN}chmod +x $MESH_SCRIPT${RESET}"
        exit 1
    fi
    [[ ! -x "$MESH_SCRIPT" ]] && chmod +x "$MESH_SCRIPT"
    "$MESH_SCRIPT" "$@"
}
