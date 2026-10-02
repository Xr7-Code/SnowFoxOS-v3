#!/bin/bash
# ============================================================
#  SnowFoxOS v3.0 — Base System Setup
#  Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)
# ============================================================

# Load utilities (assumes SCRIPT_DIR is set before sourcing)
source "$SCRIPT_DIR/lib/utils.sh"

# Global variables from main script (assumed to be sourced/exported):
# TARGET_USER, SCRIPT_DIR, DKMS_HOOKS

info "Installing for: ${BOLD}$TARGET_USER${RESET}"
sleep 1

step "1/10 — System update"

# DKMS_HOOKS is defined in the main script and assumed to be available
DKMS_HOOKS=(
    /etc/kernel/postinst.d/dkms
    /etc/kernel/prerm.d/dkms
    /usr/lib/kernel/install.d/50-dkms.install
)
for hook in "${DKMS_HOOKS[@]}"; do
    [[ -f "$hook" ]] && mv "$hook" "${hook}.snowfox-bak"
done
info "DKMS hooks disabled for installer run"

systemctl disable apt-daily.service apt-daily.timer 2>/dev/null || true
systemctl disable apt-daily-upgrade.service apt-daily-upgrade.timer 2>/dev/null || true
systemctl stop apt-daily.service apt-daily-upgrade.service 2>/dev/null || true
success "apt-daily disabled"

cat > /etc/apt/sources.list << 'EOF'
deb http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
deb-src http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
deb http://deb.debian.org/debian/ bookworm-updates main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian/ bookworm-updates main contrib non-free non-free-firmware
EOF

wait_apt
dpkg --add-architecture i386
apt-get update -qq
dpkg --configure -a 2>/dev/null || true
apt-get -f install -y 2>/dev/null || true
wait_apt
apt-get upgrade -y
apt-get install -y \
    curl wget git unzip \
    build-essential \
    ca-certificates \
    aria2 \
    fzf \
    lz4 \
    gnupg \
    pciutils usbutils \
    htop btop irqbalance \
    bash-completion \
    xdg-utils \
    xdg-user-dirs \
    rfkill \
    systemd-resolved \
    iw wireless-tools \
    imagemagick \
    bc \
    xorg \
    xinit \
    x11-utils \
    x11-xserver-utils \
    xclip \
    xdotool \
    dbus-x11 \
    lm-sensors \
    qt5ct \
    qt5-style-plugins \
    qt6ct

# ── Disable dnsmasq (conflicts with systemd-resolved) ────────
info "Disabling dnsmasq..."
systemctl stop dnsmasq 2>/dev/null || true
systemctl disable dnsmasq 2>/dev/null || true
systemctl mask dnsmasq 2>/dev/null || true
success "dnsmasq disabled"

# ── Enable systemd-resolved ──────────────────────────────────
info "Enabling systemd-resolved..."
systemctl enable --now systemd-resolved 2>/dev/null || true
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf 2>/dev/null || true
success "systemd-resolved enabled"

# ── PATH extension for /usr/sbin ─────────────────────────────
info "Adding /usr/sbin to PATH..."
if ! grep -q "export PATH=\$PATH:/usr/sbin" /etc/profile; then
    echo 'export PATH=$PATH:/usr/sbin' >> /etc/profile
    success "PATH extension added to /etc/profile"
else
    info "PATH extension already present in /etc/profile"
fi

# Also for the user in ~/.bashrc
if ! grep -q "export PATH=\$PATH:/usr/sbin" "/home/$TARGET_USER/.bashrc"; then
    echo 'export PATH=$PATH:/usr/sbin' >> "/home/$TARGET_USER/.bashrc"
    success "PATH extension added to ~/.bashrc"
else
    info "PATH extension already present in ~/.bashrc"
fi

sudo -u "$TARGET_USER" xdg-user-dirs-update
success "System updated"

# ── Install fastfetch ────────────────────────────────────────
info "Installing fastfetch..."
FASTFETCH_DEB_URL=$(curl -sf https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest 2>/dev/null \
    | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for a in data.get('assets', []):
        if a['name'].endswith('amd64.deb'):
            print(a['browser_download_url'])
            break
except: pass
" 2>/dev/null)
if [[ -n "$FASTFETCH_DEB_URL" ]]; then
    curl -L "$FASTFETCH_DEB_URL" -o /tmp/fastfetch.deb 2>/dev/null && \
        dpkg -i /tmp/fastfetch.deb 2>/dev/null && \
        rm -f /tmp/fastfetch.deb && \
        success "fastfetch installed" || \
        warn "fastfetch installation failed"
else
    # Fallback: direct download of the known package
    curl -L "https://github.com/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-amd64.deb" \
        -o /tmp/fastfetch.deb 2>/dev/null && \
        dpkg -i /tmp/fastfetch.deb 2>/dev/null && \
        rm -f /tmp/fastfetch.deb && \
        success "fastfetch installed (fallback)" || \
        warn "fastfetch installation failed — install manually"
fi

# ── X11 / startx without sudo ────────────────────────────────
# Debian 12 ships Xorg without the SUID bit (rootless Xorg).
# For "startx" directly from the TTY without sudo, two things are needed:
#
# 1. Xwrapper.config:
#    allowed_users=anybody  → anyone may start X (not just console owner)
#    needs_root_rights=auto → Xorg asks systemd-logind for device access.
#                             In a real TTY session (getty → PAM → logind)
#                             Xorg receives ACLs on /dev/dri/* and /dev/input/*.
#                             This is safer than needs_root_rights=yes (SUID).
#
# 2. Groups:
#    video  → /dev/dri/* (GPU/DRM)
#    input  → /dev/input/* (keyboard, mouse) — Debian does NOT assign this automatically
#    render → /dev/dri/renderD* (GPU rendering)
#    tty    → /dev/tty* (TTY switching by X)
#    audio  → /dev/snd/* (PipeWire, for safety)
#
# Without group membership, startx fails with "No screens found" or
# "Cannot open /dev/dri/card0" — even with allowed_users=anybody.

mkdir -p /etc/X11
cat > /etc/X11/Xwrapper.config << 'XWEOF'
allowed_users=anybody
needs_root_rights=auto
XWEOF
success "Xwrapper.config set (allowed_users=anybody, needs_root_rights=auto)"

info "Setting groups for $TARGET_USER (video, input, render, tty, audio)..."
for grp in video input render tty audio; do
    if getent group "$grp" > /dev/null 2>&1; then
        usermod -aG "$grp" "$TARGET_USER"
    else
        warn "Group '$grp' not found — skipping"
    fi
done
success "Groups set — $TARGET_USER can use startx without sudo"
