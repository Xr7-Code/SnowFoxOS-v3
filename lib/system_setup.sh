#!/usr/bin/env bash
# ============================================================
#  SnowFoxOS v4 — System Setup Library
#  Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)
# ============================================================
#  NOTE: No `set -e` here — this file is sourced by install.sh.
#  Functions: set_system_version, set_grub_theme
#  Version comes from get_version() (§0d 30).
#
#  v4 changes:
#   - set_system_language removed (dead code: locale setup now
#     lives in base_system.sh / kernel_drivers.sh).
#   - set_grub_theme is idempotent: re-runs do not duplicate the
#     GRUB_THEME block, and GRUB_TIMEOUT is only written if absent.
#   - GRUB_TIMEOUT=5 (was 3) to give the user time to pick the
#     fallback kernel (plan §7 "fallback must stay bootable").
#   - get_version() called without argument (uses SCRIPT_DIR
#     default from lib/utils.sh).
# ============================================================

source "$SCRIPT_DIR/lib/utils.sh"

set_system_version() {
    if [[ "$EUID" -ne 0 ]]; then
        echo "[FAILED] Please run this function as root."
        return 1
    fi

    local version
    version="$(get_version)"
    OS_NAME="SnowFoxOS"
    OS_VERSION="v${version}"
    OS_VERSION_ID="${version}"
    OS_PRETTY_NAME="${OS_NAME} ${OS_VERSION}"
    OS_REPO_URL="https://github.com/Xr7-Code/SnowFoxOS"
    OS_COLOR="0;35"

    echo "[SnowFoxOS] Updating system identification to ${OS_PRETTY_NAME}..."

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

    echo -e "${OS_PRETTY_NAME} \\\n \\\l\n" > /etc/issue

    if [ -f /etc/default/grub ]; then
        sed -i '/^GRUB_DISTRIBUTOR=/d' /etc/default/grub
        echo "GRUB_DISTRIBUTOR=\"${OS_NAME} ${OS_VERSION}\"" >> /etc/default/grub
    fi

    update-grub

    echo "[SUCCESS] System renamed to ${OS_PRETTY_NAME}."
}

set_grub_theme() {
    if [[ "$EUID" -ne 0 ]]; then
        echo "[FAILED] Please run this function as root."
        return 1
    fi

    local version
    version="$(get_version)"

    THEME_DIR="/boot/grub/themes/snowfox"
    GRUB_CONFIG="/etc/default/grub"
    THEME_TXT="$THEME_DIR/theme.txt"

    # ── Theme asset (idempotent: overwrite is fine, small file) ─
    mkdir -p "$THEME_DIR"

    cat << EOF > "$THEME_TXT"
# SnowFoxOS v${version} Minimalist GRUB Theme
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
  text = "SnowFoxOS v${version}  |  Use arrow keys"
  color = "#555555"
}
EOF

    # ── /etc/default/grub: idempotent ──────────────────────
    # Backup once.
    if [ ! -f "${GRUB_CONFIG}.bak" ]; then
        cp "$GRUB_CONFIG" "${GRUB_CONFIG}.bak"
    fi

    # GRUB_TIMEOUT: only set when not already present. kernel_drivers.sh
    # owns this key when it runs; this function must not fight it.
    if ! grep -q '^GRUB_TIMEOUT=' "$GRUB_CONFIG"; then
        echo "GRUB_TIMEOUT=5" >> "$GRUB_CONFIG"
    fi

    # GRUB_TERMINAL_OUTPUT / GRUB_GFXMODE: fixed, safe to overwrite.
    sed -i '/^GRUB_TERMINAL_OUTPUT=/d' "$GRUB_CONFIG"
    sed -i '/^GRUB_GFXMODE=/d' "$GRUB_CONFIG"
    {
        echo 'GRUB_TERMINAL_OUTPUT="gfxterm"'
        echo 'GRUB_GFXMODE="1920x1080,auto"'
    } >> "$GRUB_CONFIG"

    # GRUB_THEME: only write the SnowFox block if the theme is not
    # already pointing at our theme.txt. Avoids duplicate blocks on
    # re-install (idempotency).
    if ! grep -qF "GRUB_THEME=\"$THEME_TXT\"" "$GRUB_CONFIG"; then
        sed -i '/^GRUB_THEME=/d' "$GRUB_CONFIG"
        {
            echo ""
            echo "# --- SnowFoxOS v${version} Visuals ---"
            echo "GRUB_THEME=\"$THEME_TXT\""
        } >> "$GRUB_CONFIG"
    fi

    update-grub

    echo "[SUCCESS] SnowFoxOS boot menu active."
}
