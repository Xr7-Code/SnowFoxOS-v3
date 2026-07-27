#!/bin/bash

# ============================================================
#  SnowFoxOS v3.0 — Default Applications Setup
# ============================================================

# Load utilities (assumes SCRIPT_DIR is set before sourcing)
source "$SCRIPT_DIR/lib/utils.sh"

# Global variables from main script (assumed to be sourced/exported):
# TARGET_USER, TARGET_HOME, SCRIPT_DIR

step "5/10 — Terminal & Standard-Apps"

wait_apt
apt-get install -y \
    kitty \
    mc \
    mousepad \
    ristretto \
    file-roller \
    mpv \
    ffmpeg

echo ""
echo -e "${PURPLE}${BOLD}  Dateimanager:${RESET}"
echo -e "  1) PCManFM (grafisch, leicht — empfohlen)"
echo -e "  2) MC      (Terminal, bereits installiert)"
echo -e "  3) Beide"
echo ""
read -rp "$(echo -e ${PURPLE}${BOLD}"Auswahl [1-3]: "${RESET})" FM_CHOICE
case "$FM_CHOICE" in
    1|3) apt-get install -y pcmanfm gvfs gvfs-backends
         success "PCManFM installiert" ;;
    2)   success "MC bereits installiert" ;;
    *)   apt-get install -y pcmanfm gvfs gvfs-backends
         success "PCManFM installiert (Standard)" ;;
esac

if ask_install "VLC Media Player"; then
    apt-get install -y vlc && success "VLC installiert"
fi

if ask_install "GIMP (Bildbearbeitung)"; then
    apt-get install -y gimp && success "GIMP installiert"
fi

if ask_install "VSCodium"; then
    curl -fsSL https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg \
        | gpg --dearmor | tee /usr/share/keyrings/vscodium-archive-keyring.gpg > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg] https://download.vscodium.com/debs vscodium main" \
        | tee /etc/apt/sources.list.d/vscodium.list
    wait_apt; apt-get update -qq
    apt-get install -y codium && success "VSCodium installiert" || warn "VSCodium fehlgeschlagen"
fi

if ask_install "OnlyOffice"; then
    mkdir -p -m 755 /etc/apt/keyrings
    curl -fsSL https://download.onlyoffice.com/GPG-KEY-ONLYOFFICE \
        | gpg --dearmor -o /etc/apt/keyrings/onlyoffice.gpg
    echo "deb [signed-by=/etc/apt/keyrings/onlyoffice.gpg] https://download.onlyoffice.com/repo/debian squeeze main" \
        | tee /etc/apt/sources.list.d/onlyoffice.list
    wait_apt; apt-get update -qq
    apt-get install -y onlyoffice-desktopeditors && success "OnlyOffice installiert" || warn "OnlyOffice fehlgeschlagen"
fi

curl -sL https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp \
    -o /usr/local/bin/yt-dlp && chmod +x /usr/local/bin/yt-dlp
success "yt-dlp installiert"

# Node.js — JS-Runtime für yt-dlp (YouTube-Signatur-Entschlüsselung)
# Ohne JS-Runtime fehlen ab yt-dlp 2025+ manche Formate
apt-get install -y nodejs 2>/dev/null || true
success "Node.js installiert (JS-Runtime für yt-dlp)"

# ── SnowFox Console Launcher klonen ──────────────────────────
info "Klone SnowFox Console Launcher..."
if git clone https://github.com/Xr7-Code/SnowFox-Console-Launcher \
    "$TARGET_HOME/SnowFox-Console-Launcher" 2>/dev/null; then
    chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/SnowFox-Console-Launcher"
    success "SnowFox Console Launcher geklont nach ~/SnowFox-Console-Launcher"
else
    warn "SnowFox Console Launcher konnte nicht geklont werden — manuell installieren"
fi
