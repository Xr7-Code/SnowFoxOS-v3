#!/bin/bash
# ============================================================
#  SnowFoxOS — CLI Modul: P2P-Mesh-Netzwerk
#  Wird von /usr/local/bin/snowfox gesourced.
# ============================================================


# ============================================================
# Dispatcher
# ============================================================

# ── Mesh-Wrapper ──
MESH_SCRIPT="$HOME/.config/snowfox-mesh.sh"



cmd_mesh_wrapper() {
    if [[ ! -f "$MESH_SCRIPT" ]]; then
        err "Mesh-Modul nicht gefunden!"
        info "  Installiere es mit:"
        info "    ${CYAN}curl -o $MESH_SCRIPT https://raw.githubusercontent.com/Xr7-Code/SnowFoxOS-v3/main/snowfox-mesh.sh${RESET}"
        info "    ${CYAN}chmod +x $MESH_SCRIPT${RESET}"
        exit 1
    fi
    [[ ! -x "$MESH_SCRIPT" ]] && chmod +x "$MESH_SCRIPT"
    "$MESH_SCRIPT" "$@"
}
