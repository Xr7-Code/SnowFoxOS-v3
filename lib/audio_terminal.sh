#!/usr/bin/env bash
# ============================================================
#  SnowFoxOS v4 — Audio and Terminal Setup
#  Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)
# ============================================================

source "$SCRIPT_DIR/lib/utils.sh"

step "4/10 — Audio (PipeWire)"

wait_apt
apt-get install -y \
    pipewire pipewire-pulse pipewire-alsa pipewire-audio \
    wireplumber pavucontrol pulseaudio-utils \
    libspa-0.2-bluetooth bluez-obexd

apt-get remove --purge -y pulseaudio pulseaudio-bluetooth 2>/dev/null || true

mkdir -p /etc/pipewire/wireplumber.conf.d
cat > /etc/pipewire/wireplumber.conf.d/51-bluez-config.conf <<'BTWEOF'
monitor.bluez.properties = {
  bluez5.enable-sbc-xq    = true
  bluez5.enable-msbc      = true
  bluez5.enable-hw-volume = true
  bluez5.headset-roles    = [ hsp_hs hsp_ag hfp_hf hfp_ag ]
  bluez5.a2dp.codecs      = [ sbc sbc_xq aac ldac aptx aptx_hd ]
}
BTWEOF

mkdir -p /etc/bluetooth
cat > /etc/bluetooth/main.conf <<'BZEOF'
[Policy]
AutoEnable=true

[General]
Enable=Source,Sink,Media,Socket
ControllerMode=dual
FastConnectable=true
ReconnectAttempts=7
ReconnectIntervals=1,2,4,8,16,32,64
BZEOF

loginctl enable-linger "$TARGET_USER" 2>/dev/null || true

sudo -u "$TARGET_USER" mkdir -p "$TARGET_HOME/.config/systemd/user/default.target.wants"
for svc in pipewire.service pipewire-pulse.service wireplumber.service; do
    src="/usr/lib/systemd/user/$svc"
    dst="$TARGET_HOME/.config/systemd/user/default.target.wants/$svc"
    [[ -f "$src" ]] && sudo -u "$TARGET_USER" ln -sf "$src" "$dst" 2>/dev/null || true
done

success "PipeWire + Bluetooth audio installed (A2DP, HFP, HSP)"

# kitty Fallback (v3 heredoc); theming_finishing rendert die echte Config
info "Configuring Kitty terminal..."
mkdir -p "$TARGET_HOME/.config/kitty"
cat > "$TARGET_HOME/.config/kitty/kitty.conf" <<'KITTYEOF'
background #2B2F38
foreground #E5E9F0
window_padding_width 8
cursor #9B59B6
cursor_text_color #2B2F38
selection_background #9B59B6
selection_foreground #2B2F38
color0  #3B4252
color1  #BF616A
color2  #A3BE8C
color3  #EBCB8B
color4  #81A1C1
color5  #9B59B6
color6  #88C0D0
color7  #E5E9F0
color8  #4C566A
color9  #D07A7F
color10 #B1C89A
color11 #E4CE91
color12 #93B5CC
color13 #B07CC6
color14 #9BCAD8
color15 #ECEFF4
font_family      JetBrainsMono Nerd Font
font_size        11.0

# BEGIN SNOWFOX PALETTE
# END SNOWFOX PALETTE
KITTYEOF
success "Kitty configured (fallback)"
