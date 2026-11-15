#!/usr/bin/env bash
# ============================================================
#  SnowFoxOS v4 — Cleanup & Finalization
#  Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)
# ============================================================

source "$SCRIPT_DIR/lib/utils.sh"

VERSION="$(get_version)"

info "Removing build-only dependencies..."
# libx11-dev / libimlib2-dev were only needed for the foxdock build
# in desktop_environment.sh (§0c 21).
apt-get purge -y libx11-dev libimlib2-dev 2>/dev/null || true

info "Cleaning up old packages..."
apt-get autoremove --purge -y 2>/dev/null || true
success "Cleanup complete"

echo ""
success "SnowFoxOS v${VERSION} installed successfully!"
warn   "Please reboot: sudo reboot"
