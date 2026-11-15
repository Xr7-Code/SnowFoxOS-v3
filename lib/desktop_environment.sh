#!/usr/bin/env bash
# ============================================================
#  SnowFoxOS v4 — Desktop Environment
#  Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)
# ============================================================

source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/checksums.sh"

step "3/10 — i3 + Polybar + Rofi + Dunst + i3lock"

wait_apt
apt-get install -y \
    i3 i3lock picom polybar rofi dunst \
    libnotify-bin libayatana-appindicator3-1 feh \
    libdbusmenu-gtk3-4 redshift scrot brightnessctl playerctl \
    network-manager bluez \
    fonts-inter fonts-dejavu fonts-liberation fonts-noto-color-emoji \
    papirus-icon-theme arc-theme gtk2-engines-murrine \
    qt5-style-kvantum xsettingsd lxpolkit lxappearance \
    xss-lock xserver-xorg-input-libinput rxvt-unicode \
    cups cups-bsd cups-client printer-driver-splix
success "i3 desktop packages installed"

# clipnotify (pinned commit)
if [[ "${SNOWFOX_PHASE:-full}" != "full" && "${SNOWFOX_NETWORK:-online}" == "offline" ]]; then
    warn "Offline ISO install: clipnotify needs a git clone — skipping"
elif [[ -z "${CLIPNOTIFY_COMMIT:-}" || "$CLIPNOTIFY_COMMIT" == "UNPINNED" ]]; then
    warn "CLIPNOTIFY_COMMIT unpinned — skipping clipnotify"
elif rm -rf /tmp/clipnotify && \
     git clone https://github.com/cdown/clipnotify.git /tmp/clipnotify 2>/dev/null; then
    (
        cd /tmp/clipnotify || exit 1
        git checkout --detach "$CLIPNOTIFY_COMMIT" || exit 1
        make || exit 1
        install -m 0755 clipnotify /usr/local/bin/clipnotify
    ) && success "clipnotify installed (commit ${CLIPNOTIFY_COMMIT:0:12})" \
      || warn "clipnotify build failed"
fi
rm -rf /tmp/clipnotify

if [[ -f "$SCRIPT_DIR/configs/i3/clip-saver.sh" ]]; then
    mkdir -p "$TARGET_HOME/.config/i3"
    cp "$SCRIPT_DIR/configs/i3/clip-saver.sh" "$TARGET_HOME/.config/i3/clip-saver.sh"
    chmod +x "$TARGET_HOME/.config/i3/clip-saver.sh"
fi

# Bibata cursor
if [[ "${SNOWFOX_PHASE:-full}" != "full" && "${SNOWFOX_NETWORK:-online}" == "offline" ]]; then
    warn "Offline ISO install: skipping Bibata cursor download"
elif [[ ! -d /usr/share/icons/Bibata-Modern-Classic ]]; then
    BIBATA_URL="https://github.com/ful1e5/Bibata_Cursor/releases/download/${BIBATA_VERSION}/Bibata-Modern-Classic.tar.xz"
    _tmp_bibata=$(mktemp --suffix=.tar.xz)
    if _fetch_verified "$BIBATA_URL" "$_tmp_bibata" "$CHECKSUM_BIBATA" "Bibata-Modern-Classic"; then
        mkdir -p /usr/share/icons
        tar -xf "$_tmp_bibata" -C /usr/share/icons/ 2>/dev/null \
            && success "Bibata-Modern-Classic cursor installed" \
            || warn "Bibata archive extraction failed"
    fi
    rm -f "$_tmp_bibata"
fi

systemd_safe enable bluetooth
systemd_safe start bluetooth

# bluetui (pinned)
if [[ "${SNOWFOX_PHASE:-full}" != "full" ]]; then
    info "ISO install: bluetui stays optional (snowfox stash)"
elif ask_install "bluetui (Bluetooth Terminal UI)" no; then
    apt-get install -y bluez bluez-tools dbus 2>/dev/null
    if [[ -z "${CHECKSUM_BLUETUI:-}" || "$CHECKSUM_BLUETUI" == "UNPINNED" ]]; then
        warn "bluetui skipped — pin CHECKSUM_BLUETUI in lib/checksums.sh"
    else
        BLUETUI_URL="https://github.com/pythops/bluetui/releases/download/${BLUETUI_VERSION}/bluetui-x86_64-linux-musl"
        if _fetch_verified "$BLUETUI_URL" /usr/local/bin/bluetui "$CHECKSUM_BLUETUI" "bluetui"; then
            chmod 0755 /usr/local/bin/bluetui
            success "bluetui installed"
        fi
    fi
fi

mkdir -p "$TARGET_HOME/.local/share/applications"

cat > "$TARGET_HOME/.local/share/applications/nmtui.desktop" <<'EOF'
[Desktop Entry]
Name=Network
Comment=Manage network connections (nmtui)
Exec=kitty -e nmtui
Icon=network-wireless
Type=Application
Categories=Network;System;
EOF

cat > "$TARGET_HOME/.local/share/applications/bluetui.desktop" <<'EOF'
[Desktop Entry]
Name=Bluetooth
Comment=Manage Bluetooth devices (bluetui)
Exec=kitty -e bluetui
Icon=bluetooth
Type=Application
Categories=System;
EOF

cat > "$TARGET_HOME/.local/share/applications/pcmanfm.desktop" <<'EOF'
[Desktop Entry]
Name=Files
Comment=File manager
Exec=pcmanfm %U
Icon=system-file-manager
Type=Application
Categories=System;FileManager;
EOF

chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.local/share/applications"
success "Desktop entries installed (Rofi-ready)"

mkdir -p /etc/X11/xorg.conf.d
if [[ -f "$SCRIPT_DIR/configs/xorg/30-touchpad.conf" ]]; then
    cp "$SCRIPT_DIR/configs/xorg/30-touchpad.conf" /etc/X11/xorg.conf.d/30-touchpad.conf
else
    cat > /etc/X11/xorg.conf.d/30-touchpad.conf <<'EOF'
Section "InputClass"
    Identifier      "libinput touchpad"
    MatchIsTouchpad "on"
    MatchDevicePath "/dev/input/event*"
    Driver          "libinput"
    Option          "Tapping"            "on"
    Option          "ClickMethod"        "clickfinger"
    Option          "NaturalScrolling"   "true"
    Option          "DisableWhileTyping" "on"
EndSection
EOF
fi

# First-login setup + autostart
BASH_PROFILE="$TARGET_HOME/.bash_profile"
if ! grep -q "SnowFoxOS — first-login setup" "$BASH_PROFILE" 2>/dev/null; then
    {
        echo ''
        echo '# SnowFoxOS — first-login setup (tty1, once)'
        echo 'if [ -x /usr/local/bin/snowfox-setup ] && [ ! -f "$HOME/.config/snowfox/setup-done" ] && [ "$(tty)" = "/dev/tty1" ]; then'
        echo '    /usr/local/bin/snowfox-setup || true'
        echo 'fi'
    } >> "$BASH_PROFILE"
fi
if ! grep -q "SnowFoxOS — start i3 automatically" "$BASH_PROFILE" 2>/dev/null; then
    {
        echo ''
        echo '# SnowFoxOS — start i3 automatically'
        echo '[ "$(tty)" = "/dev/tty1" ] && exec startx'
    } >> "$BASH_PROFILE"
fi

cat > "$TARGET_HOME/.xinitrc" <<'EOF'
#!/bin/sh
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/games:/usr/games
export GTK_THEME=Arc-Dark
export QT_QPA_PLATFORMTHEME=qt5ct
export QT_STYLE_OVERRIDE=gtk2
export QT_AUTO_SCREEN_SCALE_FACTOR=0
export ELECTRON_OZONE_PLATFORM_HINT=auto
export _JAVA_AWT_WM_NONREPARENTING=1
export XDG_CURRENT_DESKTOP=i3

xsettingsd &

if [ -f /usr/bin/dbus-launch ]; then
    eval $(/usr/bin/dbus-launch --sh-syntax --exit-with-session)
    dbus-update-activation-environment --systemd \
        DISPLAY XAUTHORITY XDG_CURRENT_DESKTOP QT_QPA_PLATFORMTHEME
fi

exec i3
EOF
chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.xinitrc"
chmod +x "$TARGET_HOME/.xinitrc"

success "i3 desktop & autostart configured"

# Nerd Fonts (verified)
if [[ "${SNOWFOX_PHASE:-full}" != "full" && "${SNOWFOX_NETWORK:-online}" == "offline" ]]; then
    warn "Offline ISO install: skipping Nerd Font download"
else
    NERD_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_VERSION}/JetBrainsMono.zip"
    _tmp_nerd=$(mktemp --suffix=.zip)
    if _fetch_verified "$NERD_URL" "$_tmp_nerd" "$CHECKSUM_JETBRAINSMONO" "JetBrainsMono Nerd Font"; then
        _tmp_extract=$(mktemp -d)
        if unzip -q "$_tmp_nerd" "*.ttf" -d "$_tmp_extract" 2>/dev/null; then
            mkdir -p /usr/local/share/fonts/nerd-fonts
            mv "$_tmp_extract"/*.ttf /usr/local/share/fonts/nerd-fonts/
            chmod 0644 /usr/local/share/fonts/nerd-fonts/*.ttf
            fc-cache -f /usr/local/share/fonts/nerd-fonts/ >/dev/null 2>&1 || true
            success "JetBrainsMono Nerd Font installed"
        fi
        rm -rf "$_tmp_extract"
    fi
    rm -f "$_tmp_nerd"
fi

# foxdock build (§0c 21)
if [[ -d "$SCRIPT_DIR/foxdock" && -f "$SCRIPT_DIR/foxdock/Makefile" ]]; then
    info "Building foxdock..."
    if make -C "$SCRIPT_DIR/foxdock" -j"$(nproc)" 2>/dev/null; then
        make -C "$SCRIPT_DIR/foxdock" install 2>/dev/null \
            && success "foxdock built and installed" \
            || warn "foxdock install failed — dock will not start"
    else
        warn "foxdock build failed — libx11-dev/libimlib2-dev missing?"
    fi
fi
