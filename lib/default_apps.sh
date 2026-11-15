#!/usr/bin/env bash
# ============================================================
#  SnowFoxOS v4 — Default Applications
#  Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)
# ============================================================

source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/checksums.sh"

step "5/10 — Terminal & Default Apps"

if [[ "${SNOWFOX_PHASE:-full}" != "full" ]]; then
    info "ISO phase: network-only default apps are handled by snowfox-setup"
elif ! grep -q "bookworm-backports" /etc/apt/sources.list 2>/dev/null; then
    info "Adding bookworm-backports for yt-dlp..."
    echo "deb http://deb.debian.org/debian bookworm-backports main contrib non-free non-free-firmware" \
        >> /etc/apt/sources.list
    wait_apt
    apt-get update -qq
fi

wait_apt
apt-get install -y kitty mc ristretto file-roller mpv ffmpeg

echo ""
echo -e "${PURPLE}${BOLD}  File manager:${RESET}"
echo -e "  1) PCManFM (graphical, lightweight — recommended)"
echo -e "  2) MC      (terminal, already installed)"
echo -e "  3) Both"
echo ""
if [[ "$SNOWFOX_UNATTENDED" == "true" ]] || [[ ! -t 0 ]]; then
    FM_CHOICE="1"
    info "Unattended mode: selecting PCManFM (1)"
else
    read -rp "$(echo -e ${PURPLE}${BOLD}"Choice [1-3]: "${RESET})" FM_CHOICE
fi
case "$FM_CHOICE" in
    1|3) apt-get install -y pcmanfm gvfs gvfs-backends
         success "PCManFM installed" ;;
    2)   success "MC already installed" ;;
    *)   apt-get install -y pcmanfm gvfs gvfs-backends
         success "PCManFM installed (default)" ;;
esac

if ask_install "VLC Media Player" no; then
    apt-get install -y vlc && success "VLC installed"
fi

apt-get install -y geany \
    geany-plugin-addons geany-plugin-autoclose geany-plugin-codenav \
    geany-plugin-ctags geany-plugin-git-changebar geany-plugin-projectorganizer \
    geany-plugin-spellcheck geany-plugin-treebrowser
success "Geany + plugins installed"

apt-get install -y flameshot
success "Flameshot installed"

if ask_install "GIMP (professional image editing, ~300 MB)" no; then
    apt-get install -y gimp && success "GIMP installed"
fi

# VSCodium (pinned key)
if ask_install "VSCodium" no; then
    set -o pipefail
    _VSCODIUM_KEY_FPR="${VSCODIUM_GPG_FPR:-}"
    if [[ -z "$_VSCODIUM_KEY_FPR" || "$_VSCODIUM_KEY_FPR" == "UNPINNED" ]]; then
        warn "VSCodium GPG fingerprint not pinned — skipping"
    else
        _tmp_key=$(mktemp)
        if curl -fsSL --proto '=https' --tlsv1.2 --max-time 30 \
             https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg \
             -o "$_tmp_key"; then
            _actual_fpr=$(gpg --show-keys --with-colons "$_tmp_key" 2>/dev/null \
                | awk -F: '/^fpr:/ {print $10; exit}')
            if [[ "$_actual_fpr" == "$_VSCODIUM_KEY_FPR" ]]; then
                gpg --dearmor < "$_tmp_key" > /usr/share/keyrings/vscodium-archive-keyring.gpg
                chmod 0644 /usr/share/keyrings/vscodium-archive-keyring.gpg
                echo "deb [signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg] https://download.vscodium.com/debs vscodium main" \
                    > /etc/apt/sources.list.d/vscodium.list
                chmod 0644 /etc/apt/sources.list.d/vscodium.list
                wait_apt; apt-get update -qq
                apt-get install -y codium && success "VSCodium installed" \
                    || warn "VSCodium install failed"
            else
                warn "VSCodium GPG fingerprint mismatch — refusing"
            fi
        fi
        rm -f "$_tmp_key"
    fi
    set +o pipefail
fi

# OnlyOffice (pinned key)
if ask_install "OnlyOffice" no; then
    set -o pipefail
    _ONLYOFFICE_KEY_FPR="${ONLYOFFICE_GPG_FPR:-}"
    if [[ -z "$_ONLYOFFICE_KEY_FPR" || "$_ONLYOFFICE_KEY_FPR" == "UNPINNED" ]]; then
        warn "OnlyOffice GPG fingerprint not pinned — skipping"
    else
        mkdir -p -m 755 /etc/apt/keyrings
        _tmp_key=$(mktemp)
        if curl -fsSL --proto '=https' --tlsv1.2 --max-time 30 \
             https://download.onlyoffice.com/GPG-KEY-ONLYOFFICE \
             -o "$_tmp_key"; then
            _actual_fpr=$(gpg --show-keys --with-colons "$_tmp_key" 2>/dev/null \
                | awk -F: '/^fpr:/ {print $10; exit}')
            if [[ "$_actual_fpr" == "$_ONLYOFFICE_KEY_FPR" ]]; then
                gpg --dearmor < "$_tmp_key" > /etc/apt/keyrings/onlyoffice.gpg
                chmod 0644 /etc/apt/keyrings/onlyoffice.gpg
                echo "deb [signed-by=/etc/apt/keyrings/onlyoffice.gpg] https://download.onlyoffice.com/repo/debian squeeze main" \
                    > /etc/apt/sources.list.d/onlyoffice.list
                chmod 0644 /etc/apt/sources.list.d/onlyoffice.list
                wait_apt; apt-get update -qq
                apt-get install -y onlyoffice-desktopeditors \
                    && success "OnlyOffice installed" \
                    || warn "OnlyOffice install failed"
            else
                warn "OnlyOffice GPG fingerprint mismatch — refusing"
            fi
        fi
        rm -f "$_tmp_key"
    fi
    set +o pipefail
fi

if [[ "${SNOWFOX_PHASE:-full}" == "full" ]]; then
    info "Installing yt-dlp from bookworm-backports..."
    if apt-get install -y -t bookworm-backports yt-dlp; then
        success "yt-dlp installed (bookworm-backports)"
    else
        warn "yt-dlp install failed — trying bookworm version"
        apt-get install -y yt-dlp && success "yt-dlp installed (bookworm)" \
            || warn "yt-dlp could not be installed"
    fi

    apt-get install -y nodejs 2>/dev/null || true
    success "Node.js installed (JS runtime for yt-dlp)"

    info "Installing gum (TUI toolkit)..."
    apt-get install -y gum || warn "gum could not be installed"

    info "Cloning SnowFox Console Launcher..."
    if git clone --depth 1 https://github.com/Xr7-Code/SnowFox-Console-Launcher \
        "$TARGET_HOME/SnowFox-Console-Launcher" 2>/dev/null; then
        chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/SnowFox-Console-Launcher"
        success "SnowFox Console Launcher cloned"
    else
        warn "SnowFox Console Launcher clone failed"
    fi
else
    info "ISO phase: yt-dlp, gum and the console launcher are skipped (optional)"
fi
