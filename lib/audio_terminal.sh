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
    wireplumber \
    pavucontrol \
    pulseaudio-utils

apt-get remove --purge -y pulseaudio 2>/dev/null || true
sudo -u "$TARGET_USER" systemctl --user enable pipewire pipewire-pulse wireplumber 2>/dev/null || true

success "PipeWire installiert"

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
