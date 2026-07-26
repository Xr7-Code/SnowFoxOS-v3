#!/bin/bash

# ============================================================
#  SnowFoxOS v3.0 — Desktop Environment Setup
# ============================================================

# Load utilities (assumes SCRIPT_DIR is set before sourcing)
source "$SCRIPT_DIR/lib/utils.sh"

# Global variables from main script (assumed to be sourced/exported):
# TARGET_USER, TARGET_HOME, SCRIPT_DIR

step "3/10 — i3 + Polybar + Rofi + Dunst + i3lock"

wait_apt
apt-get install -y \
    i3 \
    i3lock \
    polybar \
    rofi \
    dunst \
    libnotify-bin \
    libappindicator3-1 \
    libayatana-appindicator3-1 \
    feh \
    libdbusmenu-gtk3-4 \
    redshift \
    scrot \
    brightnessctl \
    playerctl \
    network-manager \
    bluez \
    fonts-inter \
    fonts-noto \
    fonts-noto-color-emoji \
    papirus-icon-theme \
    arc-theme \
    gtk2-engines-murrine \
    qt5-style-kvantum \
    xsettingsd \
    lxpolkit \
    lxappearance \
    xss-lock \
    xserver-xorg-input-libinput \
    cups cups-bsd cups-client \
    printer-driver-splix

# Picom wurde entfernt — verursachte Grafikkonflikte auf AMD+NVIDIA Hybrid
# und erhöhte unnötig RAM/GPU-Last. i3 braucht keinen Compositor zwingend.
success "i3 Desktop-Pakete installiert (ohne picom)"

# ── Greenclip — schlanker Clipboard-Manager ───────────────────
info "Installiere Greenclip Clipboard-Manager..."
if curl -L "https://github.com/erebe/greenclip/releases/latest/download/greenclip" \
    -o /usr/local/bin/greenclip 2>/dev/null; then
    chmod +x /usr/local/bin/greenclip
    success "Greenclip installiert"
else
    warn "Greenclip Download fehlgeschlagen — manuell installieren"
fi

# ── Bibata Cursor Theme installieren ─────────────────────────
info "Installiere Bibata-Modern-Classic Cursor..."
BIBATA_DIR="/usr/share/icons/Bibata-Modern-Classic"
if [ ! -d "$BIBATA_DIR" ]; then
    BIBATA_VERSION=$(curl -sf https://api.github.com/repos/ful1e5/Bibata_Cursor/releases/latest | python3 -c "import sys,json; print(json.load(sys.stdin).get('tag_name','v2.0.7'))" 2>/dev/null || echo "v2.0.7")
    BIBATA_URL="https://github.com/ful1e5/Bibata_Cursor/releases/download/${BIBATA_VERSION}/Bibata-Modern-Classic.tar.xz"

    mkdir -p /usr/share/icons
    curl -L "$BIBATA_URL" -o /tmp/Bibata-Modern-Classic.tar.xz 2>/dev/null && \
        tar -xf /tmp/Bibata-Modern-Classic.tar.xz -C /usr/share/icons/ 2>/dev/null && \
        rm -f /tmp/Bibata-Modern-Classic.tar.xz && \
        success "Bibata-Modern-Classic Cursor installiert" || \
        warn "Bibata Cursor Download fehlgeschlagen — manuell installieren"
else
    success "Bibata-Modern-Classic bereits vorhanden"
fi

# ── bluetui — Terminal Bluetooth Manager ─────────────────────
# ── Bluetooth: BlueZ-Dienst aktivieren ───────────────────────
# bluetooth.service muss laufen bevor bluetui oder bluetoothctl genutzt wird.
# Timeout verhindert Aufhängen falls der Dienst nicht antwortet.
systemctl enable bluetooth 2>/dev/null || true
systemctl start bluetooth 2>/dev/null &
BT_PID=$!
sleep 3
if ! kill -0 $BT_PID 2>/dev/null; then
    success "Bluetooth-Dienst gestartet"
else
    kill $BT_PID 2>/dev/null || true
    warn "Bluetooth-Dienst Timeout — wird nach Reboot aktiv"
fi

if ask_install "bluetui (Bluetooth Terminal UI)"; then
    info "Installiere bluetui Abhängigkeiten..."
    # bluez-tools für vollständige Profil-Unterstützung
    apt-get install -y bluez bluez-tools dbus pkg-config libdbus-1-dev 2>/dev/null

    info "Lade vorkompiliertes bluetui Binary von GitHub..."
    BLUETUI_VERSION=$(curl -sf --max-time 10         https://api.github.com/repos/pythops/bluetui/releases/latest |         python3 -c "import sys,json; print(json.load(sys.stdin).get('tag_name','v0.8.1'))"         2>/dev/null || echo "v0.8.1")
    BLUETUI_URL="https://github.com/pythops/bluetui/releases/download/${BLUETUI_VERSION}/bluetui-x86_64-linux-musl"

    if curl -L --max-time 30 "$BLUETUI_URL" -o /usr/local/bin/bluetui 2>/dev/null; then
        chmod +x /usr/local/bin/bluetui
        success "bluetui installiert (${BLUETUI_VERSION})"
    else
        warn "bluetui Download fehlgeschlagen — versuche Cargo..."
        apt-get install -y cargo 2>/dev/null
        cargo install bluetui --root /usr/local/ 2>/dev/null             && success "bluetui via Cargo installiert"             || warn "bluetui konnte nicht installiert werden"
    fi
fi

# Desktop-Einträge — nmtui, bluetui, pcmanfm (für Rofi)
mkdir -p "$TARGET_HOME/.local/share/applications"

cat > "$TARGET_HOME/.local/share/applications/nmtui.desktop" << 'EOF'
[Desktop Entry]
Name=Netzwerk
Comment=Netzwerkverbindungen verwalten (nmtui)
Exec=kitty -e nmtui
Icon=network-wireless
Type=Application
Categories=Network;System;
EOF

cat > "$TARGET_HOME/.local/share/applications/bluetui.desktop" << 'EOF'
[Desktop Entry]
Name=Bluetooth
Comment=Bluetooth-Geräte verwalten (bluetui)
Exec=kitty -e bluetui
Icon=bluetooth
Type=Application
Categories=System;
EOF

cat > "$TARGET_HOME/.local/share/applications/pcmanfm.desktop" << 'EOF'
[Desktop Entry]
Name=Dateien
Comment=Dateimanager
Exec=pcmanfm %U
Icon=system-file-manager
Type=Application
Categories=System;FileManager;
EOF

chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.local/share/applications"
success "Desktop-Einträge für Netzwerk, Bluetooth, Dateien installiert (Rofi-fähig)"

# Touchpad-Config
mkdir -p /etc/X11/xorg.conf.d
if [[ -f "$SCRIPT_DIR/configs/xorg/30-touchpad.conf" ]]; then
    cp "$SCRIPT_DIR/configs/xorg/30-touchpad.conf" /etc/X11/xorg.conf.d/30-touchpad.conf
    info "Touchpad-Config aus Repo kopiert"
else
    cat > /etc/X11/xorg.conf.d/30-touchpad.conf << 'EOF'
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
    info "Touchpad-Config erstellt"
fi

# i3 Autostart
BASH_PROFILE="$TARGET_HOME/.bash_profile"
if ! grep -q "startx" "$BASH_PROFILE" 2>/dev/null; then
    echo '' >> "$BASH_PROFILE"
    echo '# SnowFoxOS — i3 automatisch starten' >> "$BASH_PROFILE"
    echo '[ "$(tty)" = "/dev/tty1" ] && exec startx' >> "$BASH_PROFILE"
fi

cat > "$TARGET_HOME/.xinitrc" << 'EOF'
#!/bin/sh
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games

export GTK_THEME=Arc-Dark
export QT_QPA_PLATFORMTHEME=qt5ct
export QT_STYLE_OVERRIDE=gtk2
export QT_AUTO_SCREEN_SCALE_FACTOR=0
export ELECTRON_OZONE_PLATFORM_HINT=auto
export _JAVA_AWT_WM_NONREPARENTING=1

xsettingsd &

if [ -f /usr/bin/dbus-launch ]; then
    eval $(/usr/bin/dbus-launch --sh-syntax --exit-with-session)
fi

# Fix: AMD+NVIDIA Hybrid — xrandr Provider verbinden damit AMD als
# Output-Slave für den zweiten Monitor fungiert ohne eigene Fence-Ops.
# Verhindert dma_fence_wait_timeout Freeze (amdgpu Display-Engine Deadlock).
# HAS_NVIDIA and HAS_AMD are assumed to be exported/sourced from main script.
if lspci | grep -qi nvidia && lspci | grep -qi amd; then
    xrandr --setprovideroutputsource 1 0
    xrandr --auto
fi

exec i3
EOF
chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.xinitrc"
chmod +x "$TARGET_HOME/.xinitrc"

success "i3 Desktop & Autostart eingerichtet"

# ── Nerd Fonts ───────────────────────────────────────────────
info "Installiere Nerd Fonts (JetBrainsMono)..."
NERD_VERSION=$(curl -sf https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('tag_name','v3.2.1'))" 2>/dev/null || echo "v3.2.1")
NERD_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_VERSION}/JetBrainsMono.zip"
mkdir -p /usr/local/share/fonts/nerd-fonts
curl -L "$NERD_URL" -o /tmp/JetBrainsMono.zip 2>/dev/null && \
    unzip -o /tmp/JetBrainsMono.zip "*.ttf" -d /usr/local/share/fonts/nerd-fonts/ 2>/dev/null && \
    fc-cache -fv /usr/local/share/fonts/nerd-fonts/ 2>/dev/null && \
    rm -f /tmp/JetBrainsMono.zip && \
    success "JetBrainsMono Nerd Font installiert" || \
    warn "Nerd Fonts Download fehlgeschlagen — manuell installieren"
