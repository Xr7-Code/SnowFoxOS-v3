#!/bin/bash
# ============================================================
#  SnowFoxOS v3 — Installer
#  Base: Debian 12 (Bookworm) minimal
#  Desktop: i3 + Polybar + Rofi + Dunst + i3lock
#  Run: sudo bash install.sh
#  Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)
# ============================================================

# ── Basic checks before sourcing lib ─────────────────────────
if [[ $EUID -ne 0 ]]; then
    echo "Please run with sudo: sudo bash install.sh"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Load utils (colors, info/success/warn/error/step/ask_install/wait_apt) ──
source "$SCRIPT_DIR/lib/utils.sh"

# ── Check Debian version ─────────────────────────────────────
if [[ ! -f /etc/debian_version ]] || ! grep -q "^12\." /etc/debian_version; then
    warn "This script is optimized for Debian 12 (Bookworm)."
fi

# ── Determine target user ────────────────────────────────────
TARGET_USER="${SUDO_USER:-$(logname 2>/dev/null || echo '')}"
if [[ -z "$TARGET_USER" || "$TARGET_USER" == "root" ]]; then
    read -rp "Username: " TARGET_USER
fi
TARGET_HOME="/home/$TARGET_USER"
[[ ! -d "$TARGET_HOME" ]] && error "Home $TARGET_HOME not found"

# ── Export global variables (used by lib files) ──────────────
export TARGET_USER
export TARGET_HOME
export SCRIPT_DIR

# DKMS_HOOKS is disabled by base_system.sh and restored by
# theming_finishing.sh — passed as exported array.
export DKMS_HOOKS=(
    /etc/kernel/postinst.d/dkms
    /etc/kernel/prerm.d/dkms
    /usr/lib/kernel/install.d/50-dkms.install
)

# GPU and hardware flags — set in kernel_drivers.sh
# and used by gaming_ai.sh and theming_finishing.sh.
export HAS_NVIDIA=false
export HAS_AMD=false
export HAS_INTEL=false
export IS_LAPTOP=false

# Browser/Editor/FM — set in browser_selection.sh,
# used by theming_finishing.sh for MIME defaults.
export DEFAULT_BROWSER_DESKTOP="firefox-esr.desktop"
export DEFAULT_EDITOR_DESKTOP="geany.desktop"
export DEFAULT_FM_DESKTOP="pcmanfm.desktop"

# ============================================================
#  Load modules — all run in the same shell process (source),
#  so variables and functions are immediately in scope.
# ============================================================

# Function library: set_system_version(), set_grub_theme()
# Must be loaded before theming_finishing.sh and boot_screen.sh.
source "$SCRIPT_DIR/lib/system_setup.sh"

# Step 1 — System update, Xwrapper, groups
source "$SCRIPT_DIR/lib/base_system.sh"

# Step 2 — Kernel, drivers, GPU detection
# Sets HAS_NVIDIA, HAS_AMD, HAS_INTEL, IS_LAPTOP
source "$SCRIPT_DIR/lib/kernel_drivers.sh"

# Step 3 — i3 desktop environment, .xinitrc, .bash_profile
source "$SCRIPT_DIR/lib/desktop_environment.sh"

# Step 4 — Audio (PipeWire) + Kitty terminal
source "$SCRIPT_DIR/lib/audio_terminal.sh"

# Step 5 — Default apps (PCManFM, Office, yt-dlp, ...)
source "$SCRIPT_DIR/lib/default_apps.sh"

# Step 6 — Browser selection
# Sets DEFAULT_BROWSER_DESKTOP
source "$SCRIPT_DIR/lib/browser_selection.sh"

# Step 6b — Mesh module (Reticulum P2P)
source "$SCRIPT_DIR/lib/mesh_module.sh"

# Step 7 + 7b — Steam/Gaming + Ollama
# Reads HAS_NVIDIA, HAS_AMD, HAS_INTEL, IS_LAPTOP
source "$SCRIPT_DIR/lib/gaming_ai.sh"

# Step 8 — Performance & Security
source "$SCRIPT_DIR/lib/performance_security.sh"

# Step 9 — Plymouth boot screen + GRUB theme (via set_grub_theme())
source "$SCRIPT_DIR/lib/boot_screen.sh"

# Step 10 — Theming, configs, finishing
# Reads DEFAULT_BROWSER_DESKTOP, IS_LAPTOP, HAS_NVIDIA, DKMS_HOOKS
# Calls set_system_version()
source "$SCRIPT_DIR/lib/theming_finishing.sh"

# Final — Banner + reboot hint
source "$SCRIPT_DIR/lib/cleanup_final.sh"


# Thousands of bodies lie dead in the sand
# Whom they belonged to, slain by whose hand?
# Half-rotten faces with holes instead eyes
# Is my mind telling me lies?

# The wheel is rolling on and on
# This is a path of no return
# A chain of births and deaths unites
# Centuries

# A crowd of spirits that were slain
# Are now deep inside your brain
# All that you have considered you
# Is not true
# Hundreds of times, killed again and again
# Living all shades between pleasure and pain
# Men, women, children, all gone and dead
# Now safely locked in my head


# The wheel is rolling on and on
# This is a path of no return
# A chain of births and deaths unites
# Centuries

# A crowd of spirits that were slain
# Are now deep inside your brain
# All that you have considered you
# Is not true
# Rise, the ones who have fallen
# Speak what you have to say
# Share with me your knowledge
# And become myself

# The wheel is rolling on and on
# This is a path of no return
# A chain of births and deaths unites
# Centuries

# A crowd of spirits that were slain
# Are now deep inside your brain
# All that you have considered you
# Is not true

# The wheel is rolling on and on
# This is a path of no return
# A chain of births and deaths unites
# Centuries

# A crowd of spirits that were slain
# Are now deep inside your brain
# All that you have considered you
# Is not true
