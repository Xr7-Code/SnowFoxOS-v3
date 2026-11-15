#!/bin/bash
# ============================================================
#  SnowFoxOS v3.0 — Configuration & Finishing Steps
#  Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)
# ============================================================

source "$SCRIPT_DIR/lib/utils.sh"

step "10/10 — Configuration & Finishing"

CONFIG_DIR="$TARGET_HOME/.config"
mkdir -p "$CONFIG_DIR/fastfetch"
mkdir -p "$TARGET_HOME/Pictures/wallpapers"

# ── Distro identity ──────────────────────────────────────────
set_system_version

cat > /etc/lsb-release << 'EOF'
DISTRIB_ID=SnowFoxOS
DISTRIB_RELEASE=3.0
DISTRIB_CODENAME=fox
DISTRIB_DESCRIPTION="SnowFoxOS v3"
EOF

echo "snowfox"        > /etc/hostname
hostname snowfox 2>/dev/null || true
success "Distro identity set"

# ── GTK theme setup ──────────────────────────────────────────
info "Setting up GTK themes..."
mkdir -p "$CONFIG_DIR/xsettingsd"

# GTK settings.ini for GTK3 and GTK4 (small, still generated)
for version in "3.0" "4.0"; do
    mkdir -p "$CONFIG_DIR/gtk-$version"
    cat > "$CONFIG_DIR/gtk-$version/settings.ini" << GEOF
[Settings]
gtk-theme-name=Arc-Dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Inter 11
gtk-cursor-theme-name=Bibata-Modern-Classic
gtk-cursor-theme-size=24
gtk-application-prefer-dark-theme=1
gtk-decoration-layout=close,minimize,maximize:
GEOF
done

# GTK3 CSS override (from repo)
if [[ -f "$SCRIPT_DIR/configs/gtk-3.0/gtk.css" ]]; then
    mkdir -p "$CONFIG_DIR/gtk-3.0"
    cp "$SCRIPT_DIR/configs/gtk-3.0/gtk.css" "$CONFIG_DIR/gtk-3.0/gtk.css"
    success "GTK3 override installed"
else
    warn "configs/gtk-3.0/gtk.css not found"
fi

# GTK4 CSS override (from repo)
if [[ -f "$SCRIPT_DIR/configs/gtk-4.0/gtk.css" ]]; then
    mkdir -p "$CONFIG_DIR/gtk-4.0"
    cp "$SCRIPT_DIR/configs/gtk-4.0/gtk.css" "$CONFIG_DIR/gtk-4.0/gtk.css"
    success "GTK4 override installed"
else
    warn "configs/gtk-4.0/gtk.css not found"
fi

# GTK2 override (from repo)
if [[ -f "$SCRIPT_DIR/configs/gtkrc-2.0" ]]; then
    cp "$SCRIPT_DIR/configs/gtkrc-2.0" "$TARGET_HOME/.gtkrc-2.0"
    chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.gtkrc-2.0"
    success "GTK2 override installed"
else
    warn "configs/gtkrc-2.0 not found"
fi

# gsettings for dark mode
sudo -u "$TARGET_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u $TARGET_USER)/bus" \
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
sudo -u "$TARGET_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u $TARGET_USER)/bus" \
    gsettings set org.gnome.desktop.interface gtk-theme 'Arc-Dark' 2>/dev/null || true

# ── Papirus folder color ─────────────────────────────────────
info "Installing papirus-folders & setting folder color to violet..."
wget -qO- https://raw.githubusercontent.com/PapirusDevelopmentTeam/papirus-folders/master/install.sh \
    | sh 2>/dev/null || warn "papirus-folders installation failed"
if command -v papirus-folders &>/dev/null; then
    papirus-folders -t Papirus-Dark -C violet -u 2>/dev/null || \
        sudo -u "$TARGET_USER" papirus-folders -t Papirus-Dark -C violet -u 2>/dev/null || \
        warn "papirus-folders could not set folder color"
    success "Papirus folders set to violet"
else
    warn "papirus-folders not found — folder color stays default"
fi

# ── xsettingsd ───────────────────────────────────────────────
cat > "$CONFIG_DIR/xsettingsd/xsettingsd.conf" << XEOF
Net/ThemeName "Arc-Dark"
Net/IconThemeName "Papirus-Dark"
Gtk/CursorThemeName "Bibata-Modern-Classic"
Gtk/CursorThemeSize 24
XEOF

mkdir -p "$TARGET_HOME/.icons/default"
cat > "$TARGET_HOME/.icons/default/index.theme" << IEOF
[Icon Theme]
Name=Default
Comment=Default Cursor Theme
Inherits=Bibata-Modern-Classic
IEOF

# ── Qt Styling ───────────────────────────────────────────────
info "Configuring Qt styling..."
mkdir -p "$CONFIG_DIR/qt5ct" "$CONFIG_DIR/qt6ct"

cat > "$CONFIG_DIR/qt5ct/qt5ct.conf" << Q5EOF
[Appearance]
style=gtk2
Q5EOF

cat > "$CONFIG_DIR/qt6ct/qt6ct.conf" << Q6EOF
[Appearance]
style=gtk2
Q6EOF

# ── fastfetch config ─────────────────────────────────────────
info "Configuring fastfetch..."
if [[ -f "$SCRIPT_DIR/configs/fastfetch/config.jsonc" ]]; then
    mkdir -p "$CONFIG_DIR/fastfetch"
    cp "$SCRIPT_DIR/configs/fastfetch/config.jsonc" "$CONFIG_DIR/fastfetch/config.jsonc"
    sed -i "s|/home/xr7-code/SnowFoxOS-v2.2/assets/fuchs.png|$SCRIPT_DIR/assets/fuchs.png|g" \
        "$CONFIG_DIR/fastfetch/config.jsonc"
    success "fastfetch config copied from repo"
else
    mkdir -p "$CONFIG_DIR/fastfetch"
    cat > "$CONFIG_DIR/fastfetch/config.jsonc" << FFEOF
{
  "\$schema": "https://github.com/fastfetch-cli/fastfetch/raw/master/doc/json_schema.json",
  "logo": {
    "source": "$SCRIPT_DIR/assets/fuchs.png",
    "type": "kitty-direct",
    "width": 24,
    "height": 11
  },
  "modules": [
    "title", "separator", "os", "host", "kernel", "uptime",
    "packages", "shell", "display", "wm", "theme", "icons",
    "font", "cursor", "terminal", "terminalfont", "cpu", "gpu",
    "memory", "swap", "disk", "localip", "locale", "break", "colors"
  ]
}
FFEOF
    success "fastfetch config created"
fi

# ── bashrc greeting ──────────────────────────────────────────
grep -q "fastfetch\|neofetch\|snowfox-greeting" "$TARGET_HOME/.bashrc" 2>/dev/null || \
    printf '\n# SnowFoxOS Greeting\n[[ -x /usr/local/bin/snowfox-greeting ]] && snowfox-greeting\n' \
    >> "$TARGET_HOME/.bashrc"

# ── Copy remaining configs from repo ─────────────────────────
if [[ -d "$SCRIPT_DIR/configs" ]]; then
    cp -r "$SCRIPT_DIR/configs/"* "$CONFIG_DIR/"
    success "Configuration files copied"

    # picom.conf explicitly
    if [[ -f "$SCRIPT_DIR/configs/picom.conf" ]]; then
        cp "$SCRIPT_DIR/configs/picom.conf" "$CONFIG_DIR/picom.conf"
        success "picom.conf installed"
    else
        warn "configs/picom.conf not found — picom will run without config"
    fi

    # Adjust Rofi config
    if [[ -f "$CONFIG_DIR/rofi/config.rasi" ]]; then
        sed -i 's/show-icons: .*/show-icons: true;/' "$CONFIG_DIR/rofi/config.rasi"
        sed -i 's/icon-theme: .*/icon-theme: "Papirus-Dark";/' "$CONFIG_DIR/rofi/config.rasi"
        success "Rofi config adjusted"
    fi

    # Adjust i3 config
    I3_CONFIG_PATH="$CONFIG_DIR/i3/config"

    if grep -q '^bindsym \$mod+e' "$I3_CONFIG_PATH"; then
        sed -i 's|^bindsym \$mod+e.*|bindsym $mod+e exec pcmanfm|' "$I3_CONFIG_PATH"
    else
        echo 'bindsym $mod+e exec pcmanfm' >> "$I3_CONFIG_PATH"
    fi

    if grep -q '^bindsym \$mod+n' "$I3_CONFIG_PATH"; then
        sed -i 's|^bindsym \$mod+n.*|bindsym $mod+n exec kitty -e nmtui|' "$I3_CONFIG_PATH"
    else
        echo 'bindsym $mod+n exec kitty -e nmtui' >> "$I3_CONFIG_PATH"
    fi

    # clip-saver instead of greenclip
    if grep -q "greenclip" "$I3_CONFIG_PATH"; then
        sed -i 's|exec --no-startup-id greenclip daemon|exec --no-startup-id ~/.config/i3/clip-saver.sh|' \
            "$I3_CONFIG_PATH"
        sed -i '/greenclip print/d' "$I3_CONFIG_PATH"
    else
        grep -q "clip-saver" "$I3_CONFIG_PATH" || \
            echo 'exec --no-startup-id ~/.config/i3/clip-saver.sh' >> "$I3_CONFIG_PATH"
    fi

    # Install clip-saver.sh
    mkdir -p "$CONFIG_DIR/i3"
    if [[ -f "$SCRIPT_DIR/configs/i3/clip-saver.sh" ]]; then
        cp "$SCRIPT_DIR/configs/i3/clip-saver.sh" "$CONFIG_DIR/i3/clip-saver.sh"
        chmod +x "$CONFIG_DIR/i3/clip-saver.sh"
        success "clip-saver.sh installed"
    else
        warn "configs/i3/clip-saver.sh not found"
    fi

    success "i3 config adjusted"

    # Re-apply GTK3/GTK4/GTK2 overrides after repo copy
    info "Ensuring theme overrides after repo copy..."
    [[ -f "$SCRIPT_DIR/configs/gtk-3.0/gtk.css" ]] && \
        cp "$SCRIPT_DIR/configs/gtk-3.0/gtk.css" "$CONFIG_DIR/gtk-3.0/gtk.css"
    [[ -f "$SCRIPT_DIR/configs/gtk-4.0/gtk.css" ]] && \
        cp "$SCRIPT_DIR/configs/gtk-4.0/gtk.css" "$CONFIG_DIR/gtk-4.0/gtk.css"
    [[ -f "$SCRIPT_DIR/configs/gtkrc-2.0" ]] && \
        cp "$SCRIPT_DIR/configs/gtkrc-2.0" "$TARGET_HOME/.gtkrc-2.0"

    if [[ -f "$CONFIG_DIR/fastfetch/config.jsonc" ]]; then
        sed -i "s|/home/xr7-code/SnowFoxOS-v2.2/assets/fuchs.png|$SCRIPT_DIR/assets/fuchs.png|g" \
            "$CONFIG_DIR/fastfetch/config.jsonc" 2>/dev/null || true
    fi

    success "Theme overrides ensured"
else
    warn "configs/ directory not found"
fi

find "$CONFIG_DIR" -name "*.sh" -exec chmod +x {} +

# ── Wallpaper ────────────────────────────────────────────────
[[ -d "$SCRIPT_DIR/wallpapers" ]] && \
    cp -r "$SCRIPT_DIR/wallpapers/." "$TARGET_HOME/Pictures/wallpapers/"

DEFAULT_WP=$(ls "$TARGET_HOME/Pictures/wallpapers" 2>/dev/null \
    | grep -iE "\.jpg$|\.png$|\.webp$|\.jpeg$" | head -n 1)
if [[ -n "$DEFAULT_WP" ]]; then
    echo "#!/bin/sh" > "$TARGET_HOME/.fehbg"
    echo "feh --bg-fill '$TARGET_HOME/Pictures/wallpapers/$DEFAULT_WP'" >> "$TARGET_HOME/.fehbg"
    chmod +x "$TARGET_HOME/.fehbg"
    chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.fehbg"
    info "Default wallpaper set: $DEFAULT_WP"
fi

# ── Polybar ──────────────────────────────────────────────────
POLYBAR_CONF="$CONFIG_DIR/polybar/config.ini"
if [[ -f "$POLYBAR_CONF" ]]; then
    if [[ "$IS_LAPTOP" == "true" ]]; then
        BAT_NAME=$(ls /sys/class/power_supply/ 2>/dev/null | grep -E "BAT|battery" | head -1)
        [[ -n "$BAT_NAME" ]] && sed -i "s/battery = BAT1/battery = $BAT_NAME/" "$POLYBAR_CONF"

        BL_NAME=$(ls /sys/class/backlight/ 2>/dev/null | grep -E "amdgpu_bl|intel_backlight" | head -1)
        BL_NAME="${BL_NAME:-$(ls /sys/class/backlight/ 2>/dev/null | head -1)}"

        if [[ -n "$BL_NAME" ]]; then
            sed -i "s/^card = .*/card = $BL_NAME/" "$POLYBAR_CONF"
            success "Polybar: backlight card set → $BL_NAME"
        else
            sed -i "s/^card = .*/card = amdgpu_bl0/" "$POLYBAR_CONF"
            warn "Backlight device not visible yet — fallback amdgpu_bl0 set"
        fi

        sed -i 's/^modules-right =.*/modules-right = backlight gap battery gap memory gap network gap pulseaudio gap bluetooth gap tray-spacer/' "$POLYBAR_CONF"
        success "Polybar: laptop mode active"
    else
        sed -i 's/^modules-right =.*/modules-right = memory gap network gap pulseaudio gap bluetooth gap tray-spacer/' "$POLYBAR_CONF"
        success "Polybar: desktop mode active"
    fi
fi

# ── modprobe configs ─────────────────────────────────────────
if [[ -d "$SCRIPT_DIR/configs/modprobe" ]]; then
    if [[ -f "$SCRIPT_DIR/configs/modprobe/nvidia.conf" ]]; then
        cp "$SCRIPT_DIR/configs/modprobe/nvidia.conf" /etc/modprobe.d/nvidia.conf
    fi
    update-initramfs -u 2>/dev/null || true
    success "modprobe configs installed"
fi

if [[ ! -f /etc/modprobe.d/nvidia.conf ]]; then
    cat > /etc/modprobe.d/nvidia.conf << 'EOF'
# SnowFoxOS — NVIDIA Configuration
blacklist nouveau
options nvidia NVreg_TemporaryFilePath=/var/tmp
options nvidia NVreg_EnableS0ixPowerManagement=0
options nvidia NVreg_PreserveVideoMemoryAllocations=1
options nvidia-drm modeset=1
options nvidia NVreg_DynamicPowerManagement=0x00
options nvidia NVreg_EnableGpuFirmware=0
EOF
    success "nvidia.conf written"
fi

# ── Helper scripts ───────────────────────────────────────────
[[ -f "$SCRIPT_DIR/configs/powermenu.sh" ]] && \
    cp "$SCRIPT_DIR/configs/powermenu.sh" /usr/local/bin/snowfox-powermenu && \
    chmod +x /usr/local/bin/snowfox-powermenu

if [[ -f "$SCRIPT_DIR/configs/snowfox-display.sh" ]]; then
    cp "$SCRIPT_DIR/configs/snowfox-display.sh" "$CONFIG_DIR/snowfox-display.sh"
    if ! grep -q "polybar/launch.sh" "$CONFIG_DIR/snowfox-display.sh"; then
        sed -i 's/i3-msg restart/i3-msg reload/' "$CONFIG_DIR/snowfox-display.sh"
        echo "" >> "$CONFIG_DIR/snowfox-display.sh"
        echo "sleep 0.5" >> "$CONFIG_DIR/snowfox-display.sh"
        echo "~/.config/polybar/launch.sh" >> "$CONFIG_DIR/snowfox-display.sh"
    fi
    chmod +x "$CONFIG_DIR/snowfox-display.sh"
    success "snowfox-display.sh installed"
fi

# ── Polybar launch.sh ────────────────────────────────────────
mkdir -p "$CONFIG_DIR/polybar/scripts"

if [[ -f "$SCRIPT_DIR/configs/polybar/launch.sh" ]]; then
    cp "$SCRIPT_DIR/configs/polybar/launch.sh" "$CONFIG_DIR/polybar/launch.sh"
    chmod +x "$CONFIG_DIR/polybar/launch.sh"
    success "polybar/launch.sh installed"
else
    warn "configs/polybar/launch.sh not found — writing fallback"
    cat > "$CONFIG_DIR/polybar/launch.sh" << 'LAUNCHEOF'
#!/bin/bash
# SnowFoxOS — Polybar Starter
sleep 2
killall -q polybar
while pgrep -u $UID -x polybar >/dev/null; do sleep 0.1; done
PRIMARY=$(xrandr --query | grep " connected primary" | cut -d" " -f1)
[[ -z "$PRIMARY" ]] && PRIMARY=$(xrandr --query | grep " connected" | head -1 | cut -d" " -f1)
CHASSIS=$(cat /sys/class/dmi/id/chassis_type 2>/dev/null || echo "0")
IS_LAPTOP=false
[[ "$CHASSIS" =~ ^(8|9|10|14)$ ]] && IS_LAPTOP=true
ls /sys/class/power_supply/BAT* &>/dev/null && IS_LAPTOP=true
if $IS_LAPTOP; then
    BAT=$(ls /sys/class/power_supply/ | grep -E '^BAT' | head -1)
    AC=$(ls /sys/class/power_supply/ | grep -E '^(AC|ADP|ACAD)' | head -1)
    [[ -n "$BAT" ]] && sed -i "s/^battery = .*/battery = $BAT/" ~/.config/polybar/config.ini
    [[ -n "$AC" ]]  && sed -i "s/^adapter = .*/adapter = $AC/"  ~/.config/polybar/config.ini
    BACKLIGHT_CARD=$(ls /sys/class/backlight/ | head -1)
    [[ -n "$BACKLIGHT_CARD" ]] && sed -i "s/^card = .*/card = $BACKLIGHT_CARD/" ~/.config/polybar/config.ini
    MONITOR=$PRIMARY polybar snowfox-laptop 2>/tmp/polybar.log &
else
    MONITOR=$PRIMARY polybar snowfox 2>/tmp/polybar.log &
fi
LAUNCHEOF
    chmod +x "$CONFIG_DIR/polybar/launch.sh"
fi

# ── Bluetooth script ─────────────────────────────────────────
if [[ -f "$SCRIPT_DIR/configs/polybar/scripts/bluetooth.sh" ]]; then
    cp "$SCRIPT_DIR/configs/polybar/scripts/bluetooth.sh" \
        "$CONFIG_DIR/polybar/scripts/bluetooth.sh"
else
    cat > "$CONFIG_DIR/polybar/scripts/bluetooth.sh" << 'BTEOF'
#!/bin/bash
if ! bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
    echo "off"
    exit 0
fi
DEV=$(bluetoothctl devices Connected 2>/dev/null \
    | head -n1 \
    | awk '{$1=""; $2=""; print $0}' \
    | xargs)
[[ -n "$DEV" ]] && echo "$DEV" || echo "on"
BTEOF
fi
chmod +x "$CONFIG_DIR/polybar/scripts/bluetooth.sh"
success "polybar/scripts/bluetooth.sh installed"

# ── snowfox CLI ──────────────────────────────────────────────
if [[ -f "$SCRIPT_DIR/snowfox" ]]; then
    cp "$SCRIPT_DIR/snowfox" /usr/local/bin/snowfox
    chmod +x /usr/local/bin/snowfox
    if [[ -d "$SCRIPT_DIR/cli" ]]; then
        mkdir -p /usr/local/lib/snowfox/cli
        cp "$SCRIPT_DIR/cli/"*.sh /usr/local/lib/snowfox/cli/
        chmod 644 /usr/local/lib/snowfox/cli/*.sh
        success "snowfox CLI + modules installed"
    else
        warn "cli/ directory not found — only snowfox binary copied"
        success "snowfox CLI installed (without modules)"
    fi
fi

[[ -f "$SCRIPT_DIR/snowfox-greeting.sh" ]] && \
    cp "$SCRIPT_DIR/snowfox-greeting.sh" /usr/local/bin/snowfox-greeting && \
    chmod +x /usr/local/bin/snowfox-greeting

# ── Default applications ─────────────────────────────────────
echo ""
echo -e "${PURPLE}${BOLD}  Default text editor:${RESET}"
echo -e "  1) Geany (default)"
echo -e "  2) VSCodium"
read -rp "$(echo -e ${PURPLE}${BOLD}"Choice [1-2]: "${RESET})" DEFAULT_EDITOR
case "$DEFAULT_EDITOR" in
    2) DEFAULT_EDITOR_DESKTOP="codium.desktop" ;;
    *) DEFAULT_EDITOR_DESKTOP="geany.desktop" ;;
esac

DEFAULT_FM_DESKTOP="pcmanfm.desktop"

cat > "$CONFIG_DIR/mimeapps.list" << MEOF
[Default Applications]
inode/directory=$DEFAULT_FM_DESKTOP
text/plain=$DEFAULT_EDITOR_DESKTOP
text/x-python=$DEFAULT_EDITOR_DESKTOP
text/x-shellscript=$DEFAULT_EDITOR_DESKTOP
application/x-shellscript=$DEFAULT_EDITOR_DESKTOP
x-scheme-handler/http=$DEFAULT_BROWSER_DESKTOP
x-scheme-handler/https=$DEFAULT_BROWSER_DESKTOP
text/html=$DEFAULT_BROWSER_DESKTOP
application/xhtml+xml=$DEFAULT_BROWSER_DESKTOP
application/pdf=$DEFAULT_BROWSER_DESKTOP
image/png=ristretto.desktop
image/jpeg=ristretto.desktop
image/gif=ristretto.desktop
video/mp4=mpv.desktop
video/x-matroska=mpv.desktop
audio/mpeg=mpv.desktop
application/zip=file-roller.desktop
application/x-tar=file-roller.desktop
MEOF
success "Default applications set"

# ── Permissions ──────────────────────────────────────────────
chown -R "$TARGET_USER:$TARGET_USER" "$CONFIG_DIR"
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/Pictures/wallpapers"
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.icons"
chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.gtkrc-2.0"
chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.bash_profile"

info "Setting ownership for $TARGET_HOME ($TARGET_USER)..."
mkdir -p "$TARGET_HOME/.local/share/xorg"
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME"
success "Permissions set — $TARGET_HOME belongs to $TARGET_USER"

# ── Restore DKMS hooks ───────────────────────────────────────
DKMS_HOOKS=(
    /etc/kernel/postinst.d/dkms
    /etc/kernel/prerm.d/dkms
    /usr/lib/kernel/install.d/50-dkms.install
)
for hook in "${DKMS_HOOKS[@]}"; do
    [[ -f "${hook}.snowfox-bak" ]] && mv "${hook}.snowfox-bak" "$hook"
done
info "DKMS hooks restored"

# ── initramfs ────────────────────────────────────────────────
info "Rebuilding initramfs with all fixes..."
update-initramfs -u 2>/dev/null || true
success "initramfs updated"
