#!/bin/bash

# ============================================================
#  SnowFoxOS v3.0 — Audio and Terminal Setup
# ============================================================

# Load utilities (assumes SCRIPT_DIR is set before sourcing)
source "$SCRIPT_DIR/lib/utils.sh"

# Global variables from main script (assumed to be sourced/exported):
# TARGET_USER, TARGET_HOME

step "4/10 — Audio (PipeWire)"

wait_apt
apt-get install -y \
    pipewire \
    pipewire-pulse \
    pipewire-alsa \
    pipewire-audio \
    wireplumber \
    pavucontrol \
    pulseaudio-utils \
    libspa-0.2-bluetooth \
    bluez-obexd

apt-get remove --purge -y pulseaudio pulseaudio-bluetooth 2>/dev/null || true

# PipeWire-Bluetooth-Profil: verhindert "br-connection-profile-unavailable"
# BlueZ braucht explizit die Policy für alle Profile inkl. A2DP und HFP/HSP.
mkdir -p /etc/pipewire/wireplumber.conf.d
cat > /etc/pipewire/wireplumber.conf.d/51-bluez-config.conf << 'BTWEOF'
monitor.bluez.properties = {
  bluez5.enable-sbc-xq    = true
  bluez5.enable-msbc      = true
  bluez5.enable-hw-volume = true
  bluez5.headset-roles    = [ hsp_hs hsp_ag hfp_hf hfp_ag ]
  bluez5.a2dp.codecs      = [ sbc sbc_xq aac ldac aptx aptx_hd ]
}
BTWEOF

# BlueZ-Hauptkonfiguration: verhindert Aufhängen bei A2DP-Verbindungen
# AutoEnable=true startet BT nach Boot automatisch ohne manuelles "power on"
mkdir -p /etc/bluetooth
cat > /etc/bluetooth/main.conf << 'BZEOF'
[Policy]
AutoEnable=true

[General]
Enable=Source,Sink,Media,Socket
ControllerMode=dual
FastConnectable=true
ReconnectAttempts=7
ReconnectIntervals=1,2,4,8,16,32,64
BZEOF

# systemctl --user in einem sudo-Kontext ist unzuverlässig (kein DBUS_SESSION_BUS_ADDRESS).
# Stattdessen loginctl-linger aktivieren damit User-Services beim Boot starten.
loginctl enable-linger "$TARGET_USER" 2>/dev/null || true

# Symlinks für PipeWire-Autostart im User-Systemd anlegen
sudo -u "$TARGET_USER" mkdir -p "$TARGET_HOME/.config/systemd/user/default.target.wants"
for svc in pipewire.service pipewire-pulse.service wireplumber.service; do
    src="/usr/lib/systemd/user/$svc"
    dst="$TARGET_HOME/.config/systemd/user/default.target.wants/$svc"
    [[ -f "$src" ]] && sudo -u "$TARGET_USER" ln -sf "$src" "$dst" 2>/dev/null || true
done

success "PipeWire + Bluetooth-Audio installiert (A2DP, HFP, HSP)"

# ── Kitty Terminal Konfiguration ──────────────────────────────
info "Konfiguriere Kitty Terminal..."
mkdir -p "$TARGET_HOME/.config/kitty"
cat > "$TARGET_HOME/.config/kitty/kitty.conf" << 'KITTYEOF'
# SnowFox Kitty Theme
background #11111b
foreground #cdd6f4
window_padding_width 8

# Cursor
cursor            #8139e8
cursor_text_color #11111b

# Auswahl
selection_background #8139e8
selection_foreground #ffffff

# Farben (passend zur SnowFox-Palette)
color0  #1e1e2e
color1  #e05555
color2  #5faf5f
color3  #ff9f5e
color4  #8139e8
color5  #9b5ef0
color6  #89dceb
color7  #cdd6f4
color8  #6c7086
color9  #e05555
color10 #5faf5f
color11 #ff9f5e
color12 #8139e8
color13 #9b5ef0
color14 #89dceb
color15 #ffffff

# Font
font_family      JetBrainsMono Nerd Font
font_size        11.0
KITTYEOF
success "Kitty konfiguriert"
