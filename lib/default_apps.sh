#!/bin/bash
# ============================================================
#  SnowFoxOS v3.0 — Default Applications Setup
#  Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)
# ============================================================

# Load utilities (assumes SCRIPT_DIR is set before sourcing)
source "$SCRIPT_DIR/lib/utils.sh"

# Global variables from main script (assumed to be sourced/exported):
# TARGET_USER, TARGET_HOME, SCRIPT_DIR

step "5/10 — Terminal & Default Apps"

wait_apt
apt-get install -y \
    kitty \
    mc \
    ristretto \
    file-roller \
    mpv \
    ffmpeg

echo ""
echo -e "${PURPLE}${BOLD}  File manager:${RESET}"
echo -e "  1) PCManFM (graphical, lightweight — recommended)"
echo -e "  2) MC      (terminal, already installed)"
echo -e "  3) Both"
echo ""
read -rp "$(echo -e ${PURPLE}${BOLD}"Choice [1-3]: "${RESET})" FM_CHOICE
case "$FM_CHOICE" in
    1|3) apt-get install -y pcmanfm gvfs gvfs-backends
         success "PCManFM installed" ;;
    2)   success "MC already installed" ;;
    *)   apt-get install -y pcmanfm gvfs gvfs-backends
         success "PCManFM installed (default)" ;;
esac

if ask_install "VLC Media Player"; then
    apt-get install -y vlc && success "VLC installed"
fi

# ── Code Editor / IDE ────────────────────────────────────────
# Geany: lightweight, fast. Plugins selected individually —
# not the metapackage, to avoid bloat.
apt-get install -y geany \
    geany-plugin-addons \
    geany-plugin-autoclose \
    geany-plugin-codenav \
    geany-plugin-ctags \
    geany-plugin-git-changebar \
    geany-plugin-projectorganizer \
    geany-plugin-spellcheck \
    geany-plugin-treebrowser
success "Geany + plugins installed"

# ── Screenshot Tool ──────────────────────────────────────────
apt-get install -y flameshot
success "Flameshot installed"

# ── GIMP only as optional ────────────────────────────────────
if ask_install "GIMP (professional image editing, ~300 MB)"; then
    apt-get install -y gimp && success "GIMP installed"
fi

if ask_install "VSCodium"; then
    curl -fsSL https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg \
        | gpg --dearmor | tee /usr/share/keyrings/vscodium-archive-keyring.gpg > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg] https://download.vscodium.com/debs vscodium main" \
        | tee /etc/apt/sources.list.d/vscodium.list
    wait_apt; apt-get update -qq
    apt-get install -y codium && success "VSCodium installed" || warn "VSCodium failed"
fi

if ask_install "OnlyOffice"; then
    mkdir -p -m 755 /etc/apt/keyrings
    curl -fsSL https://download.onlyoffice.com/GPG-KEY-ONLYOFFICE \
        | gpg --dearmor -o /etc/apt/keyrings/onlyoffice.gpg
    echo "deb [signed-by=/etc/apt/keyrings/onlyoffice.gpg] https://download.onlyoffice.com/repo/debian squeeze main" \
        | tee /etc/apt/sources.list.d/onlyoffice.list
    wait_apt; apt-get update -qq
    apt-get install -y onlyoffice-desktopeditors && success "OnlyOffice installed" || warn "OnlyOffice failed"
fi

curl -sL https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp \
    -o /usr/local/bin/yt-dlp && chmod +x /usr/local/bin/yt-dlp
success "yt-dlp installed"

# Node.js — JS runtime for yt-dlp (YouTube signature decryption)
# Without a JS runtime, some formats are missing as of yt-dlp 2025+
apt-get install -y nodejs 2>/dev/null || true
success "Node.js installed (JS runtime for yt-dlp)"

# ── Clone SnowFox Console Launcher ───────────────────────────
info "Cloning SnowFox Console Launcher..."
if git clone https://github.com/Xr7-Code/SnowFox-Console-Launcher \
    "$TARGET_HOME/SnowFox-Console-Launcher" 2>/dev/null; then
    chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/SnowFox-Console-Launcher"
    success "SnowFox Console Launcher cloned to ~/SnowFox-Console-Launcher"
else
    warn "SnowFox Console Launcher could not be cloned — install manually"
fi
