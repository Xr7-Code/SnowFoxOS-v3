#!/bin/bash
# ============================================================
#  SnowFoxOS v3 — System Setup Library
#  Functions for system versioning and GRUB theme installation.
#  Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)
# ============================================================

# NOTE: No `set -e` here — this file is sourced by install.sh,
# and `set -e` would make the entire installer fragile. Errors
# must be handled explicitly where they matter.

# ────────────────────────────────────────────────────────────
# set_system_version — Update system identification
# ────────────────────────────────────────────────────────────
set_system_version() {
    # Require root
    if [ "$EUID" -ne 0 ]; then
        echo "[FAILED] Please run this function as root (e.g. sudo bash -c 'source lib/system_setup.sh && set_system_version')."
        return 1
    fi

    # Configuration — set values here
    OS_NAME="SnowFoxOS"
    OS_VERSION="v3"
    OS_VERSION_ID="3.0"
    OS_PRETTY_NAME="${OS_NAME} ${OS_VERSION}"
    OS_REPO_URL="https://github.com/Xr7-Code/SnowFoxOS-v3"
    OS_COLOR="0;35" # Purple (SnowFox default)

    echo "[SnowFoxOS] Updating system identification to ${OS_PRETTY_NAME}..."

    # 1. Rewrite /etc/os-release
    echo "[INFO] Updating /etc/os-release..."
    cat << EOF > /etc/os-release
NAME="${OS_NAME}"
VERSION="${OS_VERSION}"
VERSION_ID="${OS_VERSION_ID}"
PRETTY_NAME="${OS_PRETTY_NAME}"
ID=snowfoxos
ID_LIKE=debian
HOME_URL="${OS_REPO_URL}"
ANSI_COLOR="${OS_COLOR}"
EOF

    # 2. Update /etc/issue (login banner shown before TTY1 login)
    echo "[INFO] Updating login banner (/etc/issue)..."
    echo -e "${OS_PRETTY_NAME} \\\n \\\l\n" > /etc/issue

    # 3. Sync name with GRUB menu entry
    if [ -f /etc/default/grub ]; then
        echo "[INFO] Syncing name with GRUB configuration..."
        sed -i '/^GRUB_DISTRIBUTOR=/d' /etc/default/grub
        echo "GRUB_DISTRIBUTOR=\"${OS_NAME} ${OS_VERSION}\"" >> /etc/default/grub
    fi

    # 4. Apply changes system-wide
    echo "[INFO] Regenerating GRUB bootloader configuration..."
    update-grub

    echo "[SUCCESS] System successfully renamed to ${OS_PRETTY_NAME}!"
    echo "Changes are visible in the terminal (e.g. fastfetch) and in the GRUB menu."
}

# ────────────────────────────────────────────────────────────
# set_grub_theme — Install minimalist SnowFox GRUB theme
# ────────────────────────────────────────────────────────────
set_grub_theme() {
    # Require root
    if [ "$EUID" -ne 0 ]; then
        echo "[FAILED] Please run this function as root (e.g. sudo bash -c 'source lib/system_setup.sh && set_grub_theme')."
        return 1
    fi

    echo "[SnowFoxOS] Starting SnowFoxOS GRUB theme installation..."

    THEME_DIR="/boot/grub/themes/snowfox"
    GRUB_CONFIG="/etc/default/grub"

    # 1. Create theme directory
    echo "[INFO] Creating theme directory at $THEME_DIR..."
    mkdir -p "$THEME_DIR"

    # 2. Write theme.txt (pure text, no borders, no images)
    echo "[INFO] Writing minimalist theme.txt..."
    cat << 'EOF' > "$THEME_DIR/theme.txt"
# SnowFoxOS v3 Minimalist GRUB Theme
desktop-color: "#000000"

+ boot_menu {
  left = 33%
  top = 33%
  width = 34%
  height = 34%

  border_width = 0
  background_color = "#000000"

  item_color = "#888888"
  selected_item_color = "#FFFFFF"
  selected_item_bg_color = "#111111"

  item_height = 24
  item_spacing = 6
  scrollbar = false
}

+ label {
  left = 0
  top = 95%
  width = 100%
  align = "center"
  text = "SnowFoxOS v3  |  Use arrow keys"
  color = "#555555"
}
EOF

    # 3. Modify /etc/default/grub
    echo "[INFO] Adjusting GRUB system configuration..."

    # Back up original config (once)
    if [ ! -f "${GRUB_CONFIG}.bak" ]; then
        cp "$GRUB_CONFIG" "${GRUB_CONFIG}.bak"
        echo "[INFO] Backup of original configuration saved to ${GRUB_CONFIG}.bak."
    fi

    # Remove existing entries to prevent duplicates
    sed -i '/^GRUB_TIMEOUT=/d' "$GRUB_CONFIG"
    sed -i '/^GRUB_TERMINAL_OUTPUT=/d' "$GRUB_CONFIG"
    sed -i '/^GRUB_GFXMODE=/d' "$GRUB_CONFIG"
    sed -i '/^GRUB_THEME=/d' "$GRUB_CONFIG"

    # Append clean parameters
    cat << EOF >> "$GRUB_CONFIG"

# --- SnowFoxOS v3 Visuals ---
GRUB_TIMEOUT=1
GRUB_TERMINAL_OUTPUT="gfxterm"
GRUB_GFXMODE="1920x1080,auto"
GRUB_THEME="$THEME_DIR/theme.txt"
EOF

    # 4. Update GRUB
    echo "[INFO] Updating GRUB bootloader..."
    update-grub

    echo "[SUCCESS] The minimalist SnowFoxOS boot menu is now active."
    echo "On next reboot you will see your centered text options."
}
