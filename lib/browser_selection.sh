#!/bin/bash

# ============================================================
#  SnowFoxOS v3.0 — Browser Selection
# ============================================================

# Load utilities (assumes SCRIPT_DIR is set before sourcing)
source "$SCRIPT_DIR/lib/utils.sh"

# Global variables from main script (assumed to be sourced/exported):
# DEFAULT_BROWSER_DESKTOP (will be set here and potentially used by other modules)

step "6/10 — Browser"

echo ""
echo -e "${PURPLE}${BOLD}  Browser Wahl:${RESET}"
echo -e "  1) Zen Browser  (Firefox-Basis, Privacy — empfohlen)"
echo -e "  2) LibreWolf    (gehärteter Firefox, max. Privacy)"
echo -e "  3) Brave        (Chromium-Basis, Privacy)"
echo -e "  4) Firefox-ESR  (Standard, stabil)"
echo -e "  5) Chromium     (leicht)"
echo -e "  6) Keinen"
echo ""
read -rp "$(echo -e ${PURPLE}${BOLD}"Auswahl [1-6]: "${RESET})" BROWSER_CHOICE

DEFAULT_BROWSER_DESKTOP="firefox-esr.desktop"
case "$BROWSER_CHOICE" in
    1)
        info "Installiere Zen Browser..."
        ZEN_URL=""
        ZEN_JSON=$(curl -sf https://api.github.com/repos/zen-browser/desktop/releases/latest 2>/dev/null)
        if [[ -n "$ZEN_JSON" ]]; then
            ZEN_URL=$(echo "$ZEN_JSON" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for a in data.get('assets', []):
        if a['name'].endswith('x86_64.AppImage'):
            print(a['browser_download_url'])
            break
except: pass
" 2>/dev/null)
        fi
        if [[ -n "$ZEN_URL" ]]; then
            curl -L "$ZEN_URL" -o /opt/zen-browser.AppImage
            chmod +x /opt/zen-browser.AppImage
            apt-get install -y libfuse2 2>/dev/null || true
            cat > /usr/share/applications/zen-browser.desktop << 'EOF'
[Desktop Entry]
Name=Zen Browser
Comment=Privacy-focused web browser
Exec=/opt/zen-browser.AppImage %u
Icon=firefox
Type=Application
Categories=Network;WebBrowser;
MimeType=x-scheme-handler/http;x-scheme-handler/https;text/html;
StartupNotify=true
EOF
            DEFAULT_BROWSER_DESKTOP="zen-browser.desktop"
            success "Zen Browser installiert"
        else
            warn "Zen Browser nicht verfügbar — Fallback: Firefox-ESR"
            apt-get install -y firefox-esr
            DEFAULT_BROWSER_DESKTOP="firefox-esr.desktop"
        fi ;;
    2)
        curl -fsSL https://deb.librewolf.net/keyring.gpg \
            | gpg --dearmor | tee /usr/share/keyrings/librewolf.gpg > /dev/null
        echo "deb [signed-by=/usr/share/keyrings/librewolf.gpg arch=amd64] https://deb.librewolf.net bookworm main" \
            | tee /etc/apt/sources.list.d/librewolf.list
        wait_apt; apt-get update -qq
        apt-get install -y librewolf && success "LibreWolf installiert" || warn "LibreWolf fehlgeschlagen"
        DEFAULT_BROWSER_DESKTOP="librewolf.desktop" ;;
    3)
        curl -fsS https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg \
            | tee /usr/share/keyrings/brave-browser-archive-keyring.gpg > /dev/null
        echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" \
            | tee /etc/apt/sources.list.d/brave-browser.list
        wait_apt; apt-get update -qq; apt-get install -y brave-browser
        DEFAULT_BROWSER_DESKTOP="brave-browser.desktop"
        success "Brave installiert" ;;
    4)
        apt-get install -y firefox-esr
        DEFAULT_BROWSER_DESKTOP="firefox-esr.desktop"
        success "Firefox-ESR installiert" ;;
    5)
        apt-get install -y chromium
        DEFAULT_BROWSER_DESKTOP="chromium.desktop"
        success "Chromium installiert" ;;
    *)
        warn "Kein Browser installiert" ;;
esac
