#!/usr/bin/env bash
# ============================================================
#  SnowFoxOS v4 — Configuration & Finishing
#  Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)
# ============================================================

source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/theme_engine.sh"

VERSION="$(get_version)"
CONFIG_DIR="$TARGET_HOME/.config"

step "10/10 — Configuration & Finishing"

mkdir -p "$CONFIG_DIR/fastfetch"
mkdir -p "$TARGET_HOME/Pictures/wallpapers"

set_system_version

cat > /etc/lsb-release <<EOF
DISTRIB_ID=SnowFoxOS
DISTRIB_RELEASE=${VERSION}
DISTRIB_CODENAME=fox
DISTRIB_DESCRIPTION="SnowFoxOS v${VERSION}"
EOF

echo "snowfox" > /etc/hostname
hostname snowfox 2>/dev/null || true
success "Distro identity set (v${VERSION})"

# GTK3/4 settings.ini (Marker-Block wird gleich vom theme_apply
# neu geschrieben; der Platzhalter hier ist nötig, damit die
# Marker-Sanity in diesem Lauf etwas findet.)
mkdir -p "$CONFIG_DIR/xsettingsd"
for version in "3.0" "4.0"; do
    mkdir -p "$CONFIG_DIR/gtk-$version"
    cat > "$CONFIG_DIR/gtk-$version/settings.ini" <<'GEOF'
[Settings]
gtk-theme-name=Arc-Dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Inter 11
gtk-cursor-theme-name=Bibata-Modern-Classic
gtk-cursor-theme-size=24
gtk-application-prefer-dark-theme=1

# BEGIN SNOWFOX PALETTE
# END SNOWFOX PALETTE
GEOF
done

if [[ -f "$SCRIPT_DIR/configs/gtk-3.0/gtk.css" ]]; then
    mkdir -p "$CONFIG_DIR/gtk-3.0"
    cp "$SCRIPT_DIR/configs/gtk-3.0/gtk.css" "$CONFIG_DIR/gtk-3.0/gtk.css"
fi
if [[ -f "$SCRIPT_DIR/configs/gtk-4.0/gtk.css" ]]; then
    mkdir -p "$CONFIG_DIR/gtk-4.0"
    cp "$SCRIPT_DIR/configs/gtk-4.0/gtk.css" "$CONFIG_DIR/gtk-4.0/gtk.css"
fi
if [[ -f "$SCRIPT_DIR/configs/gtkrc-2.0" ]]; then
    cp "$SCRIPT_DIR/configs/gtkrc-2.0" "$TARGET_HOME/.gtkrc-2.0"
    chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.gtkrc-2.0"
fi

sudo -u "$TARGET_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "$TARGET_USER")/bus" \
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
sudo -u "$TARGET_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "$TARGET_USER")/bus" \
    gsettings set org.gnome.desktop.interface gtk-theme 'Arc-Dark' 2>/dev/null || true

if command -v papirus-folders &>/dev/null; then
    papirus-folders -t Papirus-Dark -C violet -u 2>/dev/null || \
        sudo -u "$TARGET_USER" papirus-folders -t Papirus-Dark -C violet -u 2>/dev/null || true
fi

cat > "$CONFIG_DIR/xsettingsd/xsettingsd.conf" <<'XEOF'
Net/ThemeName "Arc-Dark"
Net/IconThemeName "Papirus-Dark"
Gtk/CursorThemeName "Bibata-Modern-Classic"
Gtk/CursorThemeSize 24

# BEGIN SNOWFOX PALETTE
# END SNOWFOX PALETTE
XEOF

mkdir -p "$TARGET_HOME/.icons/default"
cat > "$TARGET_HOME/.icons/default/index.theme" <<'IEOF'
[Icon Theme]
Name=Default
Comment=Default Cursor Theme
Inherits=Bibata-Modern-Classic
IEOF

mkdir -p "$CONFIG_DIR/qt5ct" "$CONFIG_DIR/qt6ct"
for v in 5 6; do
    cat > "$CONFIG_DIR/qt${v}ct/qt${v}ct.conf" <<'QEOF'
[Appearance]
style=gtk2

# BEGIN SNOWFOX PALETTE
# END SNOWFOX PALETTE
QEOF
done

if [[ -f "$SCRIPT_DIR/configs/fastfetch/config.jsonc" ]]; then
    mkdir -p "$CONFIG_DIR/fastfetch"
    cp "$SCRIPT_DIR/configs/fastfetch/config.jsonc" "$CONFIG_DIR/fastfetch/config.jsonc"
    sed -i "s|/home/xr7-code/SnowFoxOS-v2.2/assets/fuchs.png|$SCRIPT_DIR/assets/fuchs.png|g" \
        "$CONFIG_DIR/fastfetch/config.jsonc"
fi

grep -q "snowfox-greeting" "$TARGET_HOME/.bashrc" 2>/dev/null || \
    printf '\n# SnowFoxOS Greeting\n[[ -x /usr/local/bin/snowfox-greeting ]] && snowfox-greeting\n' \
    >> "$TARGET_HOME/.bashrc"

# Repo-Configs kopieren (ohne palette.conf)
if [[ -d "$SCRIPT_DIR/configs" ]]; then
    cp -r "$SCRIPT_DIR/configs/"* "$CONFIG_DIR/"
    rm -f "$CONFIG_DIR/snowfox/palette.conf"
    success "Configuration files copied"
fi

# foxdock/dock.conf
if [[ -f "$SCRIPT_DIR/configs/foxdock/dock.conf" ]]; then
    install -d -m 0755 -o "$TARGET_USER" -g "$TARGET_USER" "$CONFIG_DIR/foxdock"
    if [[ ! -f "$CONFIG_DIR/foxdock/dock.conf" ]]; then
        cp "$SCRIPT_DIR/configs/foxdock/dock.conf" "$CONFIG_DIR/foxdock/dock.conf"
        chown "$TARGET_USER:$TARGET_USER" "$CONFIG_DIR/foxdock/dock.conf"
        success "foxdock/dock.conf installed"
    fi
fi

# i3-Config-Anpassungen (v3)
I3_CONFIG_PATH="$CONFIG_DIR/i3/config"
if [[ -f "$I3_CONFIG_PATH" ]]; then
    grep -q '^bindsym \$mod+e' "$I3_CONFIG_PATH" \
        && sed -i 's|^bindsym \$mod+e.*|bindsym $mod+e exec pcmanfm|' "$I3_CONFIG_PATH" \
        || echo 'bindsym $mod+e exec pcmanfm' >> "$I3_CONFIG_PATH"
    grep -q '^bindsym \$mod+n' "$I3_CONFIG_PATH" \
        && sed -i 's|^bindsym \$mod+n.*|bindsym $mod+n exec kitty -e nmtui|' "$I3_CONFIG_PATH" \
        || echo 'bindsym $mod+n exec kitty -e nmtui' >> "$I3_CONFIG_PATH"
fi

if [[ -f "$CONFIG_DIR/rofi/config.rasi" ]]; then
    sed -i 's/show-icons: .*/show-icons: true;/' "$CONFIG_DIR/rofi/config.rasi" 2>/dev/null || true
fi

# Helper
[[ -f "$SCRIPT_DIR/configs/powermenu.sh" ]] && \
    cp "$SCRIPT_DIR/configs/powermenu.sh" /usr/local/bin/snowfox-powermenu && \
    chmod +x /usr/local/bin/snowfox-powermenu

mkdir -p "$CONFIG_DIR/polybar/scripts"
if [[ -f "$SCRIPT_DIR/configs/polybar/launch.sh" ]]; then
    cp "$SCRIPT_DIR/configs/polybar/launch.sh" "$CONFIG_DIR/polybar/launch.sh"
    chmod +x "$CONFIG_DIR/polybar/launch.sh"
fi
if [[ -f "$SCRIPT_DIR/configs/polybar/scripts/bluetooth.sh" ]]; then
    cp "$SCRIPT_DIR/configs/polybar/scripts/bluetooth.sh" \
        "$CONFIG_DIR/polybar/scripts/bluetooth.sh"
    chmod +x "$CONFIG_DIR/polybar/scripts/bluetooth.sh"
fi

# Wallpaper
[[ -d "$SCRIPT_DIR/wallpapers" ]] && \
    cp -r "$SCRIPT_DIR/wallpapers/." "$TARGET_HOME/Pictures/wallpapers/"

DEFAULT_WP=$(ls "$TARGET_HOME/Pictures/wallpapers" 2>/dev/null \
    | grep -iE "\.jpg$|\.png$|\.webp$|\.jpeg$" | head -n 1)
if [[ -n "$DEFAULT_WP" ]]; then
    cat > "$TARGET_HOME/.fehbg" <<EOF
#!/bin/sh
feh --bg-fill '$TARGET_HOME/Pictures/wallpapers/$DEFAULT_WP'
EOF
    chmod +x "$TARGET_HOME/.fehbg"
    chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.fehbg"
fi

# Polybar-Anpassung (laptop/desktop)
POLYBAR_CONF="$CONFIG_DIR/polybar/config.ini"
if [[ -f "$POLYBAR_CONF" ]]; then
    if [[ "${IS_LAPTOP:-false}" == "true" ]]; then
        BAT_NAME=$(ls /sys/class/power_supply/ 2>/dev/null | grep -E "BAT" | head -1)
        [[ -n "$BAT_NAME" ]] && sed -i "s/battery = BAT1/battery = $BAT_NAME/" "$POLYBAR_CONF"
        BL_NAME=$(ls /sys/class/backlight/ 2>/dev/null | head -1)
        [[ -n "$BL_NAME" ]] && sed -i "s/^card = .*/card = $BL_NAME/" "$POLYBAR_CONF"
        sed -i 's/^modules-right =.*/modules-right = backlight gap battery gap memory gap network gap pulseaudio gap bluetooth gap tray-spacer/' "$POLYBAR_CONF"
    else
        sed -i 's/^modules-right =.*/modules-right = memory gap network gap pulseaudio gap bluetooth gap tray-spacer/' "$POLYBAR_CONF"
    fi
fi

# nvidia modprobe config
if ${HAS_NVIDIA:-false}; then
    cat > /etc/modprobe.d/nvidia.conf <<'EOF'
blacklist nouveau
options nvidia NVreg_TemporaryFilePath=/var/tmp
options nvidia NVreg_EnableS0ixPowerManagement=0
options nvidia NVreg_PreserveVideoMemoryAllocations=1
options nvidia-drm modeset=1
options nvidia NVreg_DynamicPowerManagement=0x00
options nvidia NVreg_EnableGpuFirmware=0
EOF
    update-initramfs -u 2>/dev/null || true
fi

# snowfox CLI
if [[ -f "$SCRIPT_DIR/snowfox" ]]; then
    cp "$SCRIPT_DIR/snowfox" /usr/local/bin/snowfox
    chmod +x /usr/local/bin/snowfox
    if [[ -d "$SCRIPT_DIR/cli" ]]; then
        mkdir -p /usr/local/lib/snowfox/cli
        cp "$SCRIPT_DIR/cli/"*.sh /usr/local/lib/snowfox/cli/
        chmod 644 /usr/local/lib/snowfox/cli/*.sh
    fi
    if [[ -f "$SCRIPT_DIR/snowfox-setup" ]]; then
        cp "$SCRIPT_DIR/snowfox-setup" /usr/local/bin/snowfox-setup
        chmod 0755 /usr/local/bin/snowfox-setup
        install -d -m 0755 /etc/snowfox
        printf '%s\n' "$SCRIPT_DIR" > /etc/snowfox/installer-path
        chmod 0644 /etc/snowfox/installer-path
    fi
    if [[ -f "$SCRIPT_DIR/completions/snowfox-completion.bash" ]]; then
        mkdir -p /usr/local/lib/snowfox/completions
        cp "$SCRIPT_DIR/completions/snowfox-completion.bash" \
           /usr/local/lib/snowfox/completions/snowfox-completion.bash
        [[ -d /etc/bash_completion.d ]] && \
            ln -sf /usr/local/lib/snowfox/completions/snowfox-completion.bash \
                   /etc/bash_completion.d/snowfox 2>/dev/null || true
    fi
fi

# Theme-Engine nach /usr/local/lib/snowfox/lib/ (§0d 27)
install -d -m 0755 /usr/local/lib/snowfox/lib
install -m 0644 "$SCRIPT_DIR/lib/theme_engine.sh" \
               /usr/local/lib/snowfox/lib/theme_engine.sh
success "theme_engine.sh installed to /usr/local/lib/snowfox/lib/"

# Marker-Sanity (§0c 11)
marker_sanity_check() {
    local f missing=0
    local -a targets=(
        "$CONFIG_DIR/i3/config"
        "$CONFIG_DIR/polybar/config.ini"
        "$CONFIG_DIR/rofi/config.rasi"
        "$CONFIG_DIR/kitty/kitty.conf"
        "$CONFIG_DIR/dunst/dunstrc"
        "$CONFIG_DIR/picom.conf"
        "$CONFIG_DIR/xsettingsd/xsettingsd.conf"
        "$CONFIG_DIR/gtk-3.0/settings.ini"
        "$CONFIG_DIR/gtk-4.0/settings.ini"
        "$CONFIG_DIR/gtk-3.0/gtk.css"
        "$CONFIG_DIR/gtk-4.0/gtk.css"
        "$TARGET_HOME/.gtkrc-2.0"
        "$CONFIG_DIR/qt5ct/qt5ct.conf"
        "$CONFIG_DIR/qt6ct/qt6ct.conf"
    )
    for f in "${targets[@]}"; do
        [[ -f "$f" ]] || continue
        if ! grep -qF "BEGIN SNOWFOX PALETTE" "$f" \
           || ! grep -qF "END SNOWFOX PALETTE" "$f"; then
            warn "marker missing: $f"
            missing=$((missing + 1))
        fi
    done
    (( missing > 0 )) \
        && warn "$missing config(s) without markers — theme_apply will append at EOF" \
        || success "all target configs have palette markers"
}
marker_sanity_check

# theme_apply
SAVED_THEME=""
[[ -f "$CONFIG_DIR/snowfox/theme" ]] && \
    SAVED_THEME="$(head -n1 "$CONFIG_DIR/snowfox/theme" | tr -d '[:space:]')"
[[ -z "$SAVED_THEME" ]] && SAVED_THEME="nightfox"
info "Applying theme: $SAVED_THEME"
sudo -u "$TARGET_USER" env \
    HOME="$TARGET_HOME" \
    XDG_CONFIG_HOME="$TARGET_HOME/.config" \
    bash -c "source '$SCRIPT_DIR/lib/theme_engine.sh' && theme_apply '$SAVED_THEME'" \
    || warn "theme_apply failed — palette not rendered"

# /etc/snowfox/palette.conf (§0d 27)
install -d -m 0755 /etc/snowfox
if [[ -f "$CONFIG_DIR/snowfox/palette.conf" ]]; then
    cp "$CONFIG_DIR/snowfox/palette.conf" /etc/snowfox/palette.conf
    chmod 0644 /etc/snowfox/palette.conf
    chown root:root /etc/snowfox/palette.conf
    success "/etc/snowfox/palette.conf written"
else
    warn "user palette missing — /etc/snowfox/palette.conf not written"
fi

# MIME
DEFAULT_EDITOR_DESKTOP="geany.desktop"
DEFAULT_FM_DESKTOP="pcmanfm.desktop"
cat > "$CONFIG_DIR/mimeapps.list" <<MEOF
[Default Applications]
inode/directory=$DEFAULT_FM_DESKTOP
text/plain=$DEFAULT_EDITOR_DESKTOP
text/x-python=$DEFAULT_EDITOR_DESKTOP
text/x-shellscript=$DEFAULT_EDITOR_DESKTOP
application/x-shellscript=$DEFAULT_EDITOR_DESKTOP
x-scheme-handler/http=${DEFAULT_BROWSER_DESKTOP:-firefox-esr.desktop}
x-scheme-handler/https=${DEFAULT_BROWSER_DESKTOP:-firefox-esr.desktop}
text/html=${DEFAULT_BROWSER_DESKTOP:-firefox-esr.desktop}
application/xhtml+xml=${DEFAULT_BROWSER_DESKTOP:-firefox-esr.desktop}
application/pdf=${DEFAULT_BROWSER_DESKTOP:-firefox-esr.desktop}
image/png=ristretto.desktop
image/jpeg=ristretto.desktop
image/gif=ristretto.desktop
video/mp4=mpv.desktop
video/x-matroska=mpv.desktop
audio/mpeg=mpv.desktop
application/zip=file-roller.desktop
application/x-tar=file-roller.desktop
MEOF

# Permissions
chown -R "$TARGET_USER:$TARGET_USER" "$CONFIG_DIR"
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/Pictures/wallpapers"
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.icons" 2>/dev/null || true
[[ -f "$TARGET_HOME/.gtkrc-2.0" ]] && chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.gtkrc-2.0"
[[ -f "$TARGET_HOME/.bash_profile" ]] && chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.bash_profile"

mkdir -p "$TARGET_HOME/.local/share/xorg"
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME"
success "Permissions set"

# DKMS hooks restaurieren
DKMS_HOOKS=(
    /etc/kernel/postinst.d/dkms
    /etc/kernel/prerm.d/dkms
    /usr/lib/kernel/install.d/50-dkms.install
)
for hook in "${DKMS_HOOKS[@]}"; do
    [[ -f "${hook}.snowfox-bak" ]] && mv "${hook}.snowfox-bak" "$hook"
done

update-initramfs -u 2>/dev/null || true
success "initramfs updated"
