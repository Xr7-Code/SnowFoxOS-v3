#!/bin/bash

# ============================================================
#  SnowFoxOS v3.0 — Base System Setup
# ============================================================

# Load utilities (assumes SCRIPT_DIR is set before sourcing)
source "$SCRIPT_DIR/lib/utils.sh"

# Global variables from main script (assumed to be sourced/exported):
# TARGET_USER, SCRIPT_DIR, DKMS_HOOKS

info "Installiere für: ${BOLD}$TARGET_USER${RESET}"
sleep 1

step "1/10 — System aktualisieren"

# DKMS_HOOKS is defined in the main script and assumed to be available
DKMS_HOOKS=(
    /etc/kernel/postinst.d/dkms
    /etc/kernel/prerm.d/dkms
    /usr/lib/kernel/install.d/50-dkms.install
)
for hook in "${DKMS_HOOKS[@]}"; do
    [[ -f "$hook" ]] && mv "$hook" "${hook}.snowfox-bak"
done
info "DKMS-Hooks für Installer-Lauf deaktiviert"

systemctl disable apt-daily.service apt-daily.timer 2>/dev/null || true
systemctl disable apt-daily-upgrade.service apt-daily-upgrade.timer 2>/dev/null || true
systemctl stop apt-daily.service apt-daily-upgrade.service 2>/dev/null || true
success "apt-daily deaktiviert"

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

sudo -u "$TARGET_USER" xdg-user-dirs-update
success "System aktualisiert"

# ── fastfetch installieren ────────────────────────────────────
info "Installiere fastfetch..."
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
        success "fastfetch installiert" || \
        warn "fastfetch Installation fehlgeschlagen"
else
    # Fallback: direkter Download des bekannten Pakets
    curl -L "https://github.com/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-amd64.deb" \
        -o /tmp/fastfetch.deb 2>/dev/null && \
        dpkg -i /tmp/fastfetch.deb 2>/dev/null && \
        rm -f /tmp/fastfetch.deb && \
        success "fastfetch installiert (Fallback)" || \
        warn "fastfetch Installation fehlgeschlagen — manuell installieren"
fi

# ── X11 / startx ohne sudo ────────────────────────────────────
# Fix: X-Server blockiert normalen Benutzern standardmäßig den
# Zugriff auf die physische Konsole (TTY) -> startx brauchte sudo.
if [[ -f /etc/X11/Xwrapper.config ]]; then
    if grep -q "^allowed_users=" /etc/X11/Xwrapper.config; then
        sed -i 's/^allowed_users=.*/allowed_users=anybody/' /etc/X11/Xwrapper.config
    else
        echo "allowed_users=anybody" >> /etc/X11/Xwrapper.config
    fi
else
    mkdir -p /etc/X11
    echo "allowed_users=anybody" > /etc/X11/Xwrapper.config
fi
success "Xwrapper.config: startx ohne sudo erlaubt"
