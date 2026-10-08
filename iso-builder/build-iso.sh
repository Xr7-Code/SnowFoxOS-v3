#!/bin/bash
# ============================================================
#  SnowFoxOS v3 — ISO Builder
#  Builds a bootable installer ISO from the SnowFoxOS-v3 repo.
#  Run from anywhere — detects repo root automatically.
#  Output: <repo-root>/SnowFoxOS-v3.iso
#
#  Usage: sudo bash iso-builder/build-iso.sh
#  Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)
# ============================================================

set -euo pipefail

# ── Colors ───────────────────────────────────────────────────
PURPLE='\033[0;35m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
RED='\033[0;31m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${PURPLE}${BOLD}[ISO-Builder]${RESET} $1"; }
success() { echo -e "${GREEN}${BOLD}[  OK  ]${RESET} $1"; }
warn()    { echo -e "${ORANGE}${BOLD}[ WARN ]${RESET} $1"; }
error()   { echo -e "${RED}${BOLD}[FAILED]${RESET} $1"; exit 1; }

step() {
    echo -e "\n${PURPLE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${PURPLE}${BOLD}  $1${RESET}"
    echo -e "${PURPLE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
}

# ── Root check ───────────────────────────────────────────────
[[ $EUID -ne 0 ]] && error "Run with sudo: sudo bash iso-builder/build-iso.sh"

# ── Paths ────────────────────────────────────────────────────
# SCRIPT_DIR = iso-builder/
# REPO_ROOT  = SnowFoxOS-v3/
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="/var/tmp/snowfox-iso-build"
LB_DIR="$BUILD_DIR/lb"
ISO_OUT="$REPO_ROOT/SnowFoxOS-v3.iso"

info "Repo root : $REPO_ROOT"
info "Build dir : $BUILD_DIR"
info "ISO output: $ISO_OUT"

# ── Dependencies ─────────────────────────────────────────────
step "Checking build dependencies"

apt-get update -qq
apt-get install -y \
    live-build \
    debootstrap \
    squashfs-tools \
    xorriso \
    grub-efi-amd64-bin \
    grub-pc-bin \
    mtools \
    dialog \
    rsync \
    python3 \
    curl \
    ca-certificates 2>/dev/null

success "Build dependencies ready"

# ── Clean previous build ─────────────────────────────────────
step "Preparing build directory"

if [[ -d "$LB_DIR" ]]; then
    warn "Previous build found — cleaning..."
    cd "$LB_DIR" && lb clean --purge 2>/dev/null || true
    cd /
fi

rm -rf "$BUILD_DIR"
mkdir -p "$LB_DIR"
cd "$LB_DIR"
success "Build directory ready: $LB_DIR"

# ── live-build configuration ─────────────────────────────────
step "Configuring live-build"

lb config \
    --mode debian \
    --system normal \
    --distribution bookworm \
    --architectures amd64 \
    --binary-images iso-hybrid \
    --bootloaders "grub-efi" \
    --debian-installer none \
    --archive-areas "main contrib non-free non-free-firmware" \
    --apt-options "--yes" \
    --apt-indices false \
    --memtest none \
    --win32-loader false \
    --iso-volume "SnowFoxOS-v3" \
    --iso-publisher "Alexander Valentin Ludwig (Xr7-Code)" \
    --iso-application "SnowFoxOS v3 Installer" \
    --zsync false

success "live-build configured"

# ── apt: no recommends ───────────────────────────────────────
# live-build ignores --apt-options for this — must be set via apt.conf
mkdir -p "$LB_DIR/config/apt"
cat > "$LB_DIR/config/apt/apt.conf.chroot" << 'APTEOF'
APT::Install-Recommends "false";
APT::Install-Suggests "false";
APTEOF

# ── Package list ─────────────────────────────────────────────
step "Writing package list"

# These packages are cached IN the ISO — no download during install.
# Covers: base system, X11, i3 stack, audio, fonts, tools.
# Hardware-specific (NVIDIA CUDA, XanMod) are downloaded live.
cat > "$LB_DIR/config/package-lists/snowfox.list.chroot" << 'PKGEOF'
# ── Base system ──────────────────────────────────────────────
sudo
curl
wget
git
unzip
build-essential
ca-certificates
aria2
fzf
lz4
gnupg
pciutils
usbutils
htop
btop
irqbalance
bash-completion
xdg-utils
xdg-user-dirs
rfkill
systemd-resolved
iw
wireless-tools
imagemagick
bc
locales
dkms
libdw-dev
python3
python3-pip
pipx

# ── Firmware ─────────────────────────────────────────────────
firmware-linux
firmware-misc-nonfree
firmware-amd-graphics
firmware-iwlwifi
firmware-realtek
firmware-atheros
firmware-brcm80211
amd64-microcode
intel-microcode

# ── X11 ──────────────────────────────────────────────────────
xorg
xinit
x11-utils
x11-xserver-utils
xclip
xdotool
dbus-x11
lm-sensors
qt5ct
qt5-style-plugins
qt6ct
xserver-xorg-input-libinput

# ── i3 desktop stack ─────────────────────────────────────────
i3
i3lock
picom
polybar
rofi
dunst
libnotify-bin
libappindicator3-1
libayatana-appindicator3-1
feh
libdbusmenu-gtk3-4
redshift
scrot
brightnessctl
playerctl
xsettingsd
lxpolkit
lxappearance
xss-lock
flameshot

# ── Network & Bluetooth ──────────────────────────────────────
network-manager
bluez
bluez-tools
bluez-obexd

# ── Audio (PipeWire) ─────────────────────────────────────────
pipewire
pipewire-pulse
pipewire-alsa
pipewire-audio
wireplumber
pavucontrol
pulseaudio-utils
libspa-0.2-bluetooth

# ── Terminal & Shell ─────────────────────────────────────────
kitty
mc

# ── File manager & tools ─────────────────────────────────────
pcmanfm
gvfs
gvfs-backends
ristretto
file-roller
mpv
ffmpeg

# ── Code editor ──────────────────────────────────────────────
geany
geany-plugin-addons
geany-plugin-autoclose
geany-plugin-codenav
geany-plugin-ctags
geany-plugin-git-changebar
geany-plugin-projectorganizer
geany-plugin-spellcheck
geany-plugin-treebrowser

# ── Fonts & Icons ────────────────────────────────────────────
fonts-inter
fonts-noto
fonts-noto-color-emoji
papirus-icon-theme
arc-theme
gtk2-engines-murrine
qt5-style-kvantum

# ── GTK / Qt theming ─────────────────────────────────────────
libx11-dev
libxfixes-dev

# ── Performance & Security ───────────────────────────────────
zram-tools
earlyoom
ufw
tlp
tlp-rdw
thermald

# ── Mesa / GPU base (AMD + Intel — NVIDIA is live) ───────────
mesa-vulkan-drivers
mesa-va-drivers
libvulkan1
vulkan-tools
libgl1-mesa-dri

# ── i386 multiarch base (Steam) ──────────────────────────────
libvulkan1:i386
mesa-vulkan-drivers:i386
mesa-va-drivers:i386
libgl1-mesa-dri:i386

# ── Boot ─────────────────────────────────────────────────────
plymouth
plymouth-themes
grub2

# ── Printer support ──────────────────────────────────────────
cups
cups-bsd
cups-client
printer-driver-splix

# ── Misc ─────────────────────────────────────────────────────
nodejs
yt-dlp
PKGEOF

success "Package list written"

# ── Embed repo into ISO ──────────────────────────────────────
step "Embedding SnowFoxOS-v3 repo into ISO"

REPO_EMBED_DIR="$LB_DIR/config/includes.chroot/opt/SnowFoxOS-v3"
mkdir -p "$REPO_EMBED_DIR"

# Copy entire repo — excluding the build output and git history
rsync -a \
    --exclude='.git' \
    --exclude='iso-builder/live-build/' \
    --exclude='SnowFoxOS-v3.iso' \
    "$REPO_ROOT/" "$REPO_EMBED_DIR/"

success "Repo embedded at /opt/SnowFoxOS-v3"

# ── Embed installer scripts ──────────────────────────────────
step "Embedding installer"

mkdir -p "$LB_DIR/config/includes.chroot/usr/local/bin"
mkdir -p "$LB_DIR/config/includes.chroot/etc/systemd/system"

# Copy TUI installer and auto-install wrapper
cp "$SCRIPT_DIR/installer/tui-installer.sh" \
    "$LB_DIR/config/includes.chroot/usr/local/bin/snowfox-installer"
cp "$SCRIPT_DIR/installer/auto-install.sh" \
    "$LB_DIR/config/includes.chroot/usr/local/bin/snowfox-auto-install"

chmod +x "$LB_DIR/config/includes.chroot/usr/local/bin/snowfox-installer"
chmod +x "$LB_DIR/config/includes.chroot/usr/local/bin/snowfox-auto-install"

# Systemd unit: auto-start installer on TTY1 after boot
cat > "$LB_DIR/config/includes.chroot/etc/systemd/system/snowfox-installer.service" << 'SVCEOF'
[Unit]
Description=SnowFoxOS Installer
After=getty@tty1.service
Conflicts=getty@tty1.service

[Service]
Type=idle
ExecStart=/usr/local/bin/snowfox-installer
StandardInput=tty
StandardOutput=tty
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
Restart=no

[Install]
WantedBy=multi-user.target
SVCEOF

success "Installer embedded"

# ── Hooks ────────────────────────────────────────────────────
step "Installing build hooks"

mkdir -p "$LB_DIR/config/hooks/live"
cp "$SCRIPT_DIR/live-build/hooks/01-cache.sh" \
    "$LB_DIR/config/hooks/live/01-cache.sh"
chmod +x "$LB_DIR/config/hooks/live/01-cache.sh"

success "Hooks installed"

# ── Build ────────────────────────────────────────────────────
step "Building ISO — this will take 10–30 minutes"
info "Packages are being downloaded and cached into the ISO..."
info "Subsequent builds are faster due to apt cache."

cd "$LB_DIR"

# Enable i386 multiarch before build
dpkg --add-architecture i386

lb build 2>&1 | tee "$BUILD_DIR/build.log"

# ── Find and move ISO ─────────────────────────────────────────
BUILT_ISO=$(find "$LB_DIR" -maxdepth 1 -name "*.iso" | head -1)
[[ -z "$BUILT_ISO" ]] && error "Build failed — no ISO found. Check $BUILD_DIR/build.log"

mv "$BUILT_ISO" "$ISO_OUT"
ISO_SIZE=$(du -sh "$ISO_OUT" | cut -f1)

# ── Done ──────────────────────────────────────────────────────
echo -e "\n${PURPLE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}${BOLD}  ISO built successfully!${RESET}"
echo -e "${PURPLE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "  Output : ${BOLD}$ISO_OUT${RESET}"
echo -e "  Size   : ${BOLD}$ISO_SIZE${RESET}"
echo -e "  Log    : $BUILD_DIR/build.log"
echo ""
info "Flash to USB: sudo dd if=$ISO_OUT of=/dev/sdX bs=4M status=progress && sync"
echo ""
