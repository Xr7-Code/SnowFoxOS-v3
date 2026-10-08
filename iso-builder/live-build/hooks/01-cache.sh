#!/bin/bash
# ============================================================
#  SnowFoxOS v3 — live-build Hook: Cache & System Prep
#  Runs inside the chroot during ISO build.
#  Prepares the live environment:
#    - Enables i386 multiarch
#    - Pre-downloads all base packages into apt cache
#    - Installs dialog for TUI installer
#    - Sets up the installer service
#    - Removes live-system cruft not needed in the installer
#  Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)
# ============================================================

set -euo pipefail

echo "[SnowFox Hook] Starting ISO cache preparation..."

# ── i386 multiarch ───────────────────────────────────────────
dpkg --add-architecture i386
apt-get update -qq

# ── Installer dependencies ───────────────────────────────────
# dialog: TUI installer (disk selection, menus)
# debootstrap: installs Debian base on target disk
# parted + sgdisk: partitioning
# dosfstools: mkfs.fat for EFI partition
# e2fsprogs: mkfs.ext4
# rsync: copy repo into installed system
# pv: progress display during debootstrap
apt-get install -y \
    dialog \
    debootstrap \
    parted \
    gdisk \
    dosfstools \
    e2fsprogs \
    grub-efi-amd64 \
    grub-efi-amd64-signed \
    shim-signed \
    grub-pc \
    rsync \
    pv \
    arch-install-scripts \
    console-setup \
    keyboard-configuration

echo "[SnowFox Hook] Installer tools installed"

# ── Pre-cache all SnowFoxOS base packages ─────────────────────
# Download without installing — they go into /var/cache/apt/archives/
# The TUI installer copies this cache into the target system,
# so apt on the installed system can install from cache without
# re-downloading from the internet.
echo "[SnowFox Hook] Pre-caching SnowFoxOS base packages..."

apt-get install -y --download-only \
    i3 i3lock picom polybar rofi dunst libnotify-bin \
    feh redshift scrot brightnessctl playerctl \
    xsettingsd lxpolkit lxappearance xss-lock \
    libappindicator3-1 libayatana-appindicator3-1 \
    libdbusmenu-gtk3-4 flameshot \
    pipewire pipewire-pulse pipewire-alsa pipewire-audio \
    wireplumber pavucontrol pulseaudio-utils libspa-0.2-bluetooth \
    bluez bluez-tools bluez-obexd \
    network-manager \
    kitty mc \
    pcmanfm gvfs gvfs-backends \
    ristretto file-roller mpv ffmpeg \
    geany \
    geany-plugin-addons geany-plugin-autoclose geany-plugin-codenav \
    geany-plugin-ctags geany-plugin-git-changebar \
    geany-plugin-projectorganizer geany-plugin-spellcheck \
    geany-plugin-treebrowser \
    fonts-inter fonts-noto fonts-noto-color-emoji \
    papirus-icon-theme arc-theme gtk2-engines-murrine \
    qt5-style-kvantum qt5ct qt5-style-plugins qt6ct \
    zram-tools earlyoom ufw tlp tlp-rdw thermald \
    mesa-vulkan-drivers mesa-va-drivers \
    libvulkan1 vulkan-tools libgl1-mesa-dri \
    libvulkan1:i386 mesa-vulkan-drivers:i386 \
    mesa-va-drivers:i386 libgl1-mesa-dri:i386 \
    plymouth plymouth-themes \
    firmware-linux firmware-misc-nonfree firmware-amd-graphics \
    firmware-iwlwifi firmware-realtek firmware-atheros \
    firmware-brcm80211 amd64-microcode intel-microcode \
    cups cups-bsd cups-client \
    nodejs \
    libx11-dev libxfixes-dev \
    dkms libdw-dev \
    xorg xinit x11-utils x11-xserver-utils \
    xclip xdotool dbus-x11 lm-sensors \
    xserver-xorg-input-libinput \
    build-essential curl wget git unzip \
    ca-certificates gnupg pciutils usbutils \
    htop btop irqbalance bash-completion \
    xdg-utils xdg-user-dirs rfkill \
    systemd-resolved iw wireless-tools \
    imagemagick bc fzf lz4 aria2 python3 python3-pip \
    2>/dev/null || echo "[SnowFox Hook] Some packages failed to pre-cache — will download live"

echo "[SnowFox Hook] Base packages pre-cached"

# ── Enable installer service ──────────────────────────────────
# The service file was placed by build-iso.sh into includes.chroot
# and is now available inside the chroot.
if [[ -f /etc/systemd/system/snowfox-installer.service ]]; then
    systemctl enable snowfox-installer.service 2>/dev/null || true
    # Disable getty on tty1 — the installer takes over
    systemctl disable getty@tty1.service 2>/dev/null || true
    echo "[SnowFox Hook] Installer service enabled"
else
    echo "[SnowFox Hook] WARNING: snowfox-installer.service not found"
fi

# ── Auto-login as root on TTY1 for installer ─────────────────
# The installer runs as root — no login prompt needed.
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << 'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I $TERM
EOF

# ── Clean up live-system packages not needed in installer ─────
# Remove desktop environments, display managers, etc. that
# live-build may have added automatically.
apt-get purge -y \
    task-desktop task-gnome-desktop task-kde-desktop \
    gdm3 sddm lightdm \
    gnome-shell plasma-desktop \
    2>/dev/null || true

apt-get autoremove -y 2>/dev/null || true

echo "[SnowFox Hook] ISO cache preparation complete"
echo "[SnowFox Hook] Approximate ISO size: 1.5–2.5 GB"
