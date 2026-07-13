#!/bin/bash
# ============================================================
#  SnowFoxOS v3.0 — Installer
#  Basis: Debian 12 (Bookworm) minimal
#  Desktop: i3 + Polybar + Rofi + Dunst + i3lock
#  Ausführen: sudo bash install.sh
# ============================================================

PURPLE='\033[0;35m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
GRAY='\033[0;37m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${PURPLE}${BOLD}[SnowFox]${RESET} $1"; }
success() { echo -e "${GREEN}${BOLD}[  OK  ]${RESET} $1"; }
warn()    { echo -e "${ORANGE}${BOLD}[ WARN ]${RESET} $1"; }
error()   { echo -e "${RED}${BOLD}[FEHLER]${RESET} $1"; exit 1; }
step()    { echo -e "\n${PURPLE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}";
            echo -e "${PURPLE}${BOLD}  $1${RESET}";
            echo -e "${PURPLE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"; }

ask_install() {
    echo ""
    read -rp "$(echo -e ${PURPLE}${BOLD}"[SnowFox] $1 installieren? [j/n]: "${RESET})" choice
    [[ "$choice" =~ ^[jJ]$ ]]
}

wait_apt() {
    local i=0
    while fuser /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock > /dev/null 2>&1; do
        [[ $i -eq 0 ]] && info "Warte auf apt-Lock..."
        sleep 2; i=$((i+1))
        [[ $i -gt 60 ]] && error "apt-Lock nach 120s nicht frei"
    done
}

if [[ $EUID -ne 0 ]]; then
    error "Bitte mit sudo ausführen: sudo bash install.sh"
fi

if [[ ! -f /etc/debian_version ]] || ! grep -q "^12\." /etc/debian_version; then
    warn "Dieses Script ist für Debian 12 (Bookworm) optimiert."
fi

TARGET_USER="${SUDO_USER:-$(logname 2>/dev/null || echo '')}"
if [[ -z "$TARGET_USER" || "$TARGET_USER" == "root" ]]; then
    read -rp "Benutzername: " TARGET_USER
fi
TARGET_HOME="/home/$TARGET_USER"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ ! -d "$TARGET_HOME" ]] && error "Home $TARGET_HOME nicht gefunden"

info "Installiere für: ${BOLD}$TARGET_USER${RESET}"
sleep 1

step "1/10 — System aktualisieren"

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

# ── System-Locales (verhindert XOpenIM()-Fehler u.a. in Steam) ─
info "Konfiguriere System-Locales (de_AT, en_US)..."
apt-get install -y locales
sed -i 's/^# *de_AT.UTF-8 UTF-8/de_AT.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
grep -q "^de_AT.UTF-8 UTF-8" /etc/locale.gen || echo "de_AT.UTF-8 UTF-8" >> /etc/locale.gen
grep -q "^en_US.UTF-8 UTF-8" /etc/locale.gen || echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
update-locale LANG=de_AT.UTF-8
success "Locales gesetzt (de_AT.UTF-8, en_US.UTF-8)"

info "Prüfe CPU-Kompatibilität für x64v3..."
if ! grep -q "avx2" /proc/cpuinfo; then
    error "CPU unterstützt kein AVX2 — Installation abgebrochen um System-Brick zu verhindern."
fi

info "Installiere DKMS-Tools..."
apt-get install -y --no-install-recommends dkms libdw-dev clang lld llvm
success "DKMS-Tools installiert"

info "Installiere XanMod LTS Kernel..."
dpkg --configure -a 2>/dev/null || true
apt-get -f install -y 2>/dev/null || true

mkdir -p /etc/apt/keyrings
wget -qO - https://dl.xanmod.org/archive.key \
    | gpg --dearmor --yes -o /etc/apt/keyrings/xanmod-archive-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org bookworm main" \
    > /etc/apt/sources.list.d/xanmod-release.list

wait_apt
apt-get update -qq
wait_apt

DEBIAN_FRONTEND=noninteractive apt-get install -y linux-xanmod-lts-x64v3
XANMOD_EXIT=$?

if [[ $XANMOD_EXIT -eq 0 ]]; then
    success "XanMod LTS Kernel installiert (aktiv nach Reboot)"

    if [[ -f /etc/default/grub ]]; then
        GRUB_PARAMS="quiet splash"

        if lspci | grep -qi nvidia; then
            GRUB_PARAMS="$GRUB_PARAMS nvidia-drm.modeset=1"
        fi

        if lspci | grep -qi nvidia && lspci | grep -qi amd; then
            # Fix: AMD+NVIDIA Hybrid verursachte dma_fence_wait_timeout Freeze
            # durch amdgpu Display-Engine Deadlock. amdgpu.dc=1 + amdgpu.dpm=1
            # stabilisieren den Display-Controller, IOMMU verhindert DMA-Konflikte.
            GRUB_PARAMS="$GRUB_PARAMS amd_iommu=on iommu=pt amdgpu.dc=1 amdgpu.dpm=1"
            info "AMD+NVIDIA Hybrid erkannt: IOMMU + amdgpu Freeze-Fix gesetzt"
        fi

        sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"$GRUB_PARAMS\"/" /etc/default/grub
        sed -i 's/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/' /etc/default/grub
    fi

    XANMOD_VER=$(ls /lib/modules 2>/dev/null | grep xanmod-lts 2>/dev/null | sort -V | tail -1)
    if [[ -n "$XANMOD_VER" ]]; then
        grub-set-default "Advanced options for SnowFoxOS GNU/Linux>SnowFoxOS GNU/Linux, with Linux $XANMOD_VER" 2>/dev/null || true
    fi

    update-grub 2>/dev/null || true
    success "Boot-Konfiguration aktualisiert"
else
    warn "XanMod fehlgeschlagen (Exit $XANMOD_EXIT) — Installation wird fortgesetzt"
fi

apt-get install -y firmware-misc-nonfree 2>/dev/null || true
if lsusb 2>/dev/null | grep -qi "fritz\|0x0bda\|2357"; then
    modprobe mt76x2u 2>/dev/null && \
        success "Fritz USB AC 860 Treiber geladen" || \
        warn "Fritz USB Treiber nicht gefunden — nach Reboot prüfen"
fi

cat > /etc/udev/rules.d/70-usb-wlan-power.rules << 'EOF'
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="057c", ATTR{power/control}="on"
ACTION=="add", SUBSYSTEM=="usb", DRIVER=="mt76x2u", ATTR{power/control}="on"
EOF
success "USB-WLAN Autosuspend-Fix installiert"

if lspci -k 2>/dev/null | grep -qi "RTL8821CE"; then
    info "RTL8821CE WLAN-Chip erkannt — wende Stabilitäts-Fix an..."
    cat > /etc/modprobe.d/rtw88.conf << 'EOF'
options rtw88_core disable_lps_deep=y
options rtw88_pci disable_aspm=y
EOF
    success "RTL8821CE Stabilitäts-Fix installiert (disable_lps_deep, disable_aspm)"

    # Fix: Im XanMod-Kernel hat sich der Modulname geändert
    # (Unterstrich fiel weg) -> Treiber wurde nicht gefunden.
    modprobe rtw88_8821ce 2>/dev/null && \
        success "rtw88_8821ce Modul geladen" || \
        warn "rtw88_8821ce Modul nicht gefunden — nach Reboot prüfen"
    echo "rtw88_8821ce" > /etc/modules-load.d/rtw88-8821ce.conf

    # Fix: Realtek-WLAN-Chip erzeugte massenhaft PCIe-Bus-Fehler (AER),
    # was den Kernel beim Start von X11/i3 komplett blockierte.
    if [[ -f /etc/default/grub ]] && ! grep -q "pci=noaer" /etc/default/grub; then
        sed -i 's/\(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*\)"/\1 pci=noaer"/' /etc/default/grub
        update-grub 2>/dev/null || true
        success "pci=noaer Kernel-Parameter gesetzt (verhindert Freeze durch Realtek-PCIe-Fehler)"
    fi
fi

step "2/10 — Hardware-Analyse & Treiber"

IS_LAPTOP=false
[[ "$(cat /sys/class/dmi/id/chassis_type 2>/dev/null)" =~ ^(8|9|10|14)$ ]] && IS_LAPTOP=true

CPU_INFO=$(grep -m1 "vendor_id" /proc/cpuinfo)
if echo "$CPU_INFO" | grep -qi "AuthenticAMD"; then
    apt-get install -y amd64-microcode
    success "AMD CPU Microcode installiert"
else
    apt-get install -y intel-microcode
    success "Intel CPU Microcode installiert"
fi

GPU_INFO=$(lspci | grep -iE 'vga|3d|display')
HAS_NVIDIA=false
HAS_AMD=false
HAS_INTEL=false
echo "$GPU_INFO" | grep -qi "nvidia" && HAS_NVIDIA=true
echo "$GPU_INFO" | grep -qi "amd"    && HAS_AMD=true
echo "$GPU_INFO" | grep -qi "intel"  && HAS_INTEL=true

if $HAS_NVIDIA; then
    info "NVIDIA GPU erkannt — Installiere Treiber via CUDA-Repo..."

    apt-get install -y clang-19 lld-19 2>/dev/null || apt-get install -y clang lld || true
    update-alternatives --install /usr/bin/clang   clang   /usr/bin/clang-19  100 2>/dev/null || true
    update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-19 100 2>/dev/null || true
    update-alternatives --install /usr/bin/lld     lld     /usr/bin/lld-19    100 2>/dev/null || true
    update-alternatives --install /usr/bin/ld.lld  ld.lld  /usr/bin/lld-19    100 2>/dev/null || true
    update-alternatives --set clang  /usr/bin/clang-19  2>/dev/null || true
    update-alternatives --set lld    /usr/bin/lld-19    2>/dev/null || true
    update-alternatives --set ld.lld /usr/bin/lld-19    2>/dev/null || true

    curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/3bf863cc.pub \
        | gpg --dearmor | tee /usr/share/keyrings/nvidia-cuda-keyring.gpg > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/nvidia-cuda-keyring.gpg] https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/ /" \
        | tee /etc/apt/sources.list.d/nvidia-cuda.list

    cat > /etc/apt/preferences.d/nvidia-cuda << 'EOF'
Package: cuda-drivers* nvidia-* libcuda* libnvidia-*
Pin: origin "developer.download.nvidia.com"
Pin-Priority: 900

Package: *
Pin: release o=Debian
Pin-Priority: 500
EOF

    wait_apt
    apt-get update -qq
    apt-get purge -y nvidia-driver nvidia-kernel-dkms 2>/dev/null || true
    wait_apt
    apt-get install -y \
        cuda-drivers-580 \
        libvulkan1 libvulkan1:i386 \
        nvidia-vulkan-icd nvidia-vulkan-icd:i386

    if $HAS_AMD; then
        info "AMD+NVIDIA Hybrid erkannt — Konfiguriere Freeze-Fix..."

        # Fix: dcfeaturemask=0x8 deaktiviert PSR (Panel Self Refresh)
        # PSR war die Ursache aller dma_fence_wait_timeout Freezes auf
        # AMD+NVIDIA Hybrid-Systemen. Beim Aufwachen aus PSR blockiert der
        # Fence-Mechanismus den gesamten X11-Server.
        # runpm=0 deaktiviert zusätzlich Runtime Power Management.
        cat > /etc/modprobe.d/amdgpu.conf << 'EOF'
# SnowFoxOS — AMD GPU Konfiguration (Hybrid-Fix)
# Fix: dcfeaturemask=0x8 deaktiviert PSR (Panel Self Refresh)
# verhindert dma_fence_wait_timeout Freeze auf AMD+NVIDIA Systemen
options amdgpu bpc=8
options amdgpu dc=1 dcfeaturemask=0x8
options amdgpu dpm=1
options amdgpu audio=0
options amdgpu runpm=0
EOF
        success "amdgpu Hybrid-Freeze-Fix installiert (PSR deaktiviert via dcfeaturemask=0x8)"
    fi

    XANMOD_KERNEL=$(ls /lib/modules 2>/dev/null | grep xanmod | sort -V | tail -1)
    NVIDIA_VER=$(ls /var/lib/dkms/nvidia/ 2>/dev/null | sort -V | tail -1)
    if [[ -n "$XANMOD_KERNEL" && -n "$NVIDIA_VER" ]]; then
        info "Baue NVIDIA DKMS-Module für $XANMOD_KERNEL..."
        dkms install nvidia/"$NVIDIA_VER" -k "$XANMOD_KERNEL" 2>/dev/null || \
            warn "DKMS-Build fehlgeschlagen — nach Reboot prüfen"
        success "NVIDIA DKMS-Module gebaut"
    else
        warn "DKMS übersprungen (Kernel: ${XANMOD_KERNEL:-?}, NVIDIA: ${NVIDIA_VER:-?})"
    fi

    success "NVIDIA Stack installiert"

elif $HAS_AMD; then
    info "AMD GPU erkannt — Nutze Mesa..."
    apt-get install -y firmware-amd-graphics mesa-vulkan-drivers mesa-va-drivers

    cat > /etc/modprobe.d/amdgpu.conf << 'EOF'
# SnowFoxOS — AMD GPU Konfiguration
options amdgpu bpc=8
options amdgpu dc=1 dcfeaturemask=0x8
options amdgpu dpm=1
options amdgpu audio=0
EOF
    success "AMD Stack installiert"

elif $HAS_INTEL; then
    info "Intel Grafik erkannt..."
    apt-get install -y intel-media-va-driver-non-free i965-va-driver 2>/dev/null || true
    success "Intel Stack installiert"
fi

if $IS_LAPTOP; then
    info "Laptop erkannt: Installiere Akku- & Touchpad-Tools..."
    apt-get install -y tlp tlp-rdw thermald xserver-xorg-input-libinput
    systemctl enable tlp thermald
    success "Laptop-Optimierung abgeschlossen"
fi

success "GPU-Treiber eingerichtet"

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
if ask_install "bluetui (Bluetooth Terminal UI)"; then
    info "Installiere System-Abhängigkeiten für Bluetooth..."
    apt-get install -y bluez dbus pkg-config libdbus-1-dev 2>/dev/null

    info "Lade vorkompiliertes bluetui Binary von GitHub..."
    BLUETUI_VERSION=$(curl -sf https://api.github.com/repos/pythops/bluetui/releases/latest | python3 -c "import sys,json; print(json.load(sys.stdin).get('tag_name','v0.8.1'))" 2>/dev/null || echo "v0.8.1")
    BLUETUI_URL="https://github.com/pythops/bluetui/releases/download/${BLUETUI_VERSION}/bluetui-x86_64-linux-musl"

    if curl -L "$BLUETUI_URL" -o /usr/local/bin/bluetui 2>/dev/null; then
        chmod +x /usr/local/bin/bluetui
        systemctl enable --now bluetooth 2>/dev/null
        success "bluetui erfolgreich installiert!"
    else
        warn "Konnte Binary nicht laden. Versuche Cargo Fallback..."
        apt-get install -y cargo 2>/dev/null
        cargo install bluetui --root /usr/local/ 2>/dev/null && success "bluetui via Cargo installiert!" || warn "bluetui Installation fehlgeschlagen."
    fi
fi

systemctl enable bluetooth

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

step "5/10 — Terminal & Standard-Apps"

wait_apt
apt-get install -y \
    kitty \
    mc \
    mousepad \
    ristretto \
    file-roller \
    mpv \
    ffmpeg

echo ""
echo -e "${PURPLE}${BOLD}  Dateimanager:${RESET}"
echo -e "  1) PCManFM (grafisch, leicht — empfohlen)"
echo -e "  2) MC      (Terminal, bereits installiert)"
echo -e "  3) Beide"
echo ""
read -rp "$(echo -e ${PURPLE}${BOLD}"Auswahl [1-3]: "${RESET})" FM_CHOICE
case "$FM_CHOICE" in
    1|3) apt-get install -y pcmanfm gvfs gvfs-backends
         success "PCManFM installiert" ;;
    2)   success "MC bereits installiert" ;;
    *)   apt-get install -y pcmanfm gvfs gvfs-backends
         success "PCManFM installiert (Standard)" ;;
esac

if ask_install "VLC Media Player"; then
    apt-get install -y vlc && success "VLC installiert"
fi

if ask_install "GIMP (Bildbearbeitung)"; then
    apt-get install -y gimp && success "GIMP installiert"
fi

if ask_install "VSCodium"; then
    curl -fsSL https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg \
        | gpg --dearmor | tee /usr/share/keyrings/vscodium-archive-keyring.gpg > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg] https://download.vscodium.com/debs vscodium main" \
        | tee /etc/apt/sources.list.d/vscodium.list
    wait_apt; apt-get update -qq
    apt-get install -y codium && success "VSCodium installiert" || warn "VSCodium fehlgeschlagen"
fi

if ask_install "OnlyOffice"; then
    mkdir -p -m 755 /etc/apt/keyrings
    curl -fsSL https://download.onlyoffice.com/GPG-KEY-ONLYOFFICE \
        | gpg --dearmor -o /etc/apt/keyrings/onlyoffice.gpg
    echo "deb [signed-by=/etc/apt/keyrings/onlyoffice.gpg] https://download.onlyoffice.com/repo/debian squeeze main" \
        | tee /etc/apt/sources.list.d/onlyoffice.list
    wait_apt; apt-get update -qq
    apt-get install -y onlyoffice-desktopeditors && success "OnlyOffice installiert" || warn "OnlyOffice fehlgeschlagen"
fi

curl -sL https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp \
    -o /usr/local/bin/yt-dlp && chmod +x /usr/local/bin/yt-dlp
success "yt-dlp installiert"

# ── SnowFox Console Launcher klonen ──────────────────────────
info "Klone SnowFox Console Launcher..."
if git clone https://github.com/Xr7-Code/SnowFox-Console-Launcher \
    "$TARGET_HOME/SnowFox-Console-Launcher" 2>/dev/null; then
    chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/SnowFox-Console-Launcher"
    success "SnowFox Console Launcher geklont nach ~/SnowFox-Console-Launcher"
else
    warn "SnowFox Console Launcher konnte nicht geklont werden — manuell installieren"
fi

step "6/10 — Browser"

echo ""
echo -e "${PURPLE}${BOLD}  Browser Wahl:${RESET}"
echo -e "  1) Zen Browser  (Firefox-Basis, Privacy — empfohlen)"
echo -e "  2) LibreWolf    (gehärteter Firefox, max. Privacy)"
echo -e "  3) Brave        (Chromium-Basis, Privacy)"
echo -e "  4) Firefox-ESR  (Standard, stabil)"
echo -e "  5) Chromium     (leicht)"
echo -e "  6) Keinen"
echo ""
read -rp "$(echo -e ${PURPLE}${BOLD}"Auswahl [1-6]: "${RESET})" BROWSER_CHOICE

DEFAULT_BROWSER_DESKTOP="firefox-esr.desktop"
case "$BROWSER_CHOICE" in
    1)
        info "Installiere Zen Browser..."
        ZEN_URL=""
        ZEN_JSON=$(curl -sf https://api.github.com/repos/zen-browser/desktop/releases/latest 2>/dev/null)
        if [[ -n "$ZEN_JSON" ]]; then
            ZEN_URL=$(echo "$ZEN_JSON" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for a in data.get('assets', []):
        if a['name'].endswith('x86_64.AppImage'):
            print(a['browser_download_url'])
            break
except: pass
" 2>/dev/null)
        fi
        if [[ -n "$ZEN_URL" ]]; then
            curl -L "$ZEN_URL" -o /opt/zen-browser.AppImage
            chmod +x /opt/zen-browser.AppImage
            apt-get install -y libfuse2 2>/dev/null || true
            cat > /usr/share/applications/zen-browser.desktop << 'EOF'
[Desktop Entry]
Name=Zen Browser
Comment=Privacy-focused web browser
Exec=/opt/zen-browser.AppImage %u
Icon=firefox
Type=Application
Categories=Network;WebBrowser;
MimeType=x-scheme-handler/http;x-scheme-handler/https;text/html;
StartupNotify=true
EOF
            DEFAULT_BROWSER_DESKTOP="zen-browser.desktop"
            success "Zen Browser installiert"
        else
            warn "Zen Browser nicht verfügbar — Fallback: Firefox-ESR"
            apt-get install -y firefox-esr
            DEFAULT_BROWSER_DESKTOP="firefox-esr.desktop"
        fi ;;
    2)
        curl -fsSL https://deb.librewolf.net/keyring.gpg \
            | gpg --dearmor | tee /usr/share/keyrings/librewolf.gpg > /dev/null
        echo "deb [signed-by=/usr/share/keyrings/librewolf.gpg arch=amd64] https://deb.librewolf.net bookworm main" \
            | tee /etc/apt/sources.list.d/librewolf.list
        wait_apt; apt-get update -qq
        apt-get install -y librewolf && success "LibreWolf installiert" || warn "LibreWolf fehlgeschlagen"
        DEFAULT_BROWSER_DESKTOP="librewolf.desktop" ;;
    3)
        curl -fsS https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg \
            | tee /usr/share/keyrings/brave-browser-archive-keyring.gpg > /dev/null
        echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" \
            | tee /etc/apt/sources.list.d/brave-browser.list
        wait_apt; apt-get update -qq; apt-get install -y brave-browser
        DEFAULT_BROWSER_DESKTOP="brave-browser.desktop"
        success "Brave installiert" ;;
    4)
        apt-get install -y firefox-esr
        DEFAULT_BROWSER_DESKTOP="firefox-esr.desktop"
        success "Firefox-ESR installiert" ;;
    5)
        apt-get install -y chromium
        DEFAULT_BROWSER_DESKTOP="chromium.desktop"
        success "Chromium installiert" ;;
    *)
        warn "Kein Browser installiert" ;;
esac

# ============================================================
#  Mesh-Modul installieren (Reticulum P2P-Netzwerk)
# ============================================================
step "6b/10 — Mesh-Modul (Reticulum P2P-Netzwerk)"

if ask_install "Reticulum Mesh-Modul (autarkes P2P-Netzwerk)"; then
    info "Installiere Reticulum Network Stack..."

    if ! command -v pipx &>/dev/null; then
        info "pipx wird installiert..."
        apt-get update -qq
        apt-get install -y pipx
        pipx ensurepath
        export PATH="$PATH:$HOME/.local/bin"
        success "pipx installiert"
    else
        success "pipx bereits installiert"
    fi

    info "Installiere Reticulum in isolierter Umgebung via pipx..."
    if pipx install rns 2>/dev/null; then
        success "Reticulum (rns) via pipx installiert"
    else
        warn "pipx Installation fehlgeschlagen, versuche Fallback..."
        if command -v pip3 &>/dev/null; then
            pip3 install rns --break-system-packages
            success "Reticulum via pip3 (--break-system-packages) installiert"
        else
            apt-get install -y python3-pip
            pip3 install rns --break-system-packages
            success "Reticulum via pip3 installiert"
        fi
    fi

    MESH_SCRIPT_SRC="$SCRIPT_DIR/configs/snowfox-mesh.sh"
    MESH_SCRIPT_DST="$TARGET_HOME/.config/snowfox-mesh.sh"

    if [[ -f "$MESH_SCRIPT_SRC" ]]; then
        cp "$MESH_SCRIPT_SRC" "$MESH_SCRIPT_DST"
        chmod +x "$MESH_SCRIPT_DST"
        chown "$TARGET_USER:$TARGET_USER" "$MESH_SCRIPT_DST"
        success "Mesh-Modul aus Repo kopiert ($(basename "$MESH_SCRIPT_SRC"))"
    else
        warn "Mesh-Skript nicht im Repo: $MESH_SCRIPT_SRC"
    fi

    mkdir -p "$TARGET_HOME/.config/snowfox/mesh"
    mkdir -p "$TARGET_HOME/Downloads/MeshShare"
    chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.config/snowfox" 2>/dev/null || true

    success "Mesh-Modul installiert"
    info "  Starten: ${CYAN}snowfox mesh start --name \"Meine Node\"${RESET}"
    info "  Hilfe:   ${CYAN}snowfox mesh help${RESET}"
else
    info "Mesh-Modul übersprungen"
fi

step "7/10 — Steam & Gaming"

if ask_install "Steam"; then
    wait_apt
    apt-get install -y \
        steam steam-devices \
        libvulkan1 libvulkan1:i386 \
        vulkan-tools libgl1-mesa-dri:i386 \
        mesa-vulkan-drivers:i386 \
        gamemode 2>/dev/null || warn "Steam teilweise fehlgeschlagen"
    systemctl enable gamemoded 2>/dev/null || true
    success "Steam + GameMode installiert"

    # Fix: Steam-Freezes beim Workspace-Wechsel — dem Minimalsystem
    # fehlten die 64-Bit-Intel-Medientreiber und Off-Screen-Rendering-Erweiterungen.
    if $HAS_INTEL; then
        info "Installiere Intel-Medientreiber & Off-Screen-Rendering für Steam..."
        apt-get install -y intel-media-va-driver:amd64 libosmesa6 2>/dev/null || \
            warn "Intel-Medientreiber teilweise fehlgeschlagen"
        success "Intel-Medientreiber für Steam installiert (verhindert Workspace-Freezes)"
    fi

    info "Installiere Proton GE..."
    PROTON_GE_URL=""
    PROTON_GE_JSON=$(curl -sf https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest 2>/dev/null)
    if [[ -n "$PROTON_GE_JSON" ]]; then
        PROTON_GE_URL=$(echo "$PROTON_GE_JSON" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for a in data.get('assets', []):
        if a['name'].endswith('.tar.gz'):
            print(a['browser_download_url'])
            break
except: pass
" 2>/dev/null)
    fi
    if [[ -n "$PROTON_GE_URL" ]]; then
        curl -L "$PROTON_GE_URL" -o /tmp/proton-ge.tar.gz
        mkdir -p "$TARGET_HOME/.steam/root/compatibilitytools.d"
        tar -xzf /tmp/proton-ge.tar.gz -C "$TARGET_HOME/.steam/root/compatibilitytools.d/"
        rm -f /tmp/proton-ge.tar.gz
        chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.steam/root/compatibilitytools.d/"
        success "Proton GE installiert"
    else
        warn "Proton GE URL nicht ermittelt — manuell installieren"
    fi
fi

step "7b/10 — Ollama (Lokale KI)"

if ask_install "Ollama (lokale KI, kein Modell — nur Engine)"; then
    info "Installiere Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh 2>/dev/null || warn "Ollama Installation fehlgeschlagen"

    systemctl disable ollama 2>/dev/null || true
    systemctl stop ollama 2>/dev/null || true

    success "Ollama installiert (nicht aktiv — starten mit: ollama serve)"
    info "Modelle installieren mit: ollama pull <modell> (z.B. ollama pull mistral)"
fi

step "8/10 — Performance & Sicherheit"

wait_apt
apt-get install -y zram-tools earlyoom ufw
command -v tlp &>/dev/null || apt-get install -y tlp tlp-rdw

cat > /etc/default/zramswap << 'EOF'
ALGO=lz4
PERCENT=50
PRIORITY=100
EOF

if [[ -f /etc/initramfs-tools/initramfs.conf ]]; then
    sed -i 's/^COMPRESS=.*/COMPRESS=lz4/' /etc/initramfs-tools/initramfs.conf
    update-initramfs -u 2>/dev/null || true
fi

systemctl enable zramswap earlyoom tlp 2>/dev/null || true

cat > /etc/sysctl.d/99-snowfox.conf << 'EOF'
# RAM & Swap
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_background_ratio=3
vm.dirty_ratio=6

# Netzwerk
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.core.rmem_max=16777216
net.core.wmem_max=16777216

# IPv6 Privacy
net.ipv6.conf.all.use_tempaddr=2
net.ipv6.conf.default.use_tempaddr=2

# CPU
kernel.nmi_watchdog=0
EOF

info "Optimiere fstab..."
sed -i 's/errors=remount-ro/errors=remount-ro,noatime/g' /etc/fstab
sed -i '/tmpfs \/tmp tmpfs/d' /etc/fstab
echo "tmpfs /tmp tmpfs defaults,noatime,size=4G,mode=1777 0 0" >> /etc/fstab
success "fstab optimiert (noatime, tmpfs einmalig)"

ufw default deny incoming  2>/dev/null || true
ufw default allow outgoing 2>/dev/null || true
ufw --force enable         2>/dev/null || true
success "ufw Firewall aktiviert"

# ── WLAN-Karte freigeben ──────────────────────────────────────
if [[ -f /etc/network/interfaces ]]; then
    cp /etc/network/interfaces /etc/network/interfaces.snowfox-bak
    sed -i -E '/^[[:space:]]*(auto|allow-hotplug|iface)[[:space:]]+(wl|en|eth)/ s/^/#/' /etc/network/interfaces
    success "ifupdown-Einträge für WLAN/LAN auskommentiert (Übergabe an NetworkManager)"
fi

mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/NetworkManager.conf << 'EOF'
[main]
plugins=ifupdown,keyfile

[ifupdown]
managed=true
EOF

cat > /etc/NetworkManager/conf.d/99-snowfox-wifi-powersave.conf << 'EOF'
[connection]
wifi.powersave=2
EOF

mkdir -p /etc/systemd/resolved.conf.d
cat > /etc/systemd/resolved.conf.d/snowfox.conf << 'EOF'
[Resolve]
DNS=1.1.1.1#cloudflare-dns.com 9.9.9.9#dns.quad9.net
FallbackDNS=8.8.8.8
DNSSEC=allow-downgrade
DNSOverTLS=opportunistic
EOF
systemctl enable systemd-resolved irqbalance 2>/dev/null || true

for svc in avahi-daemon cups-browsed ModemManager colord blueman; do
    systemctl disable "$svc" 2>/dev/null || true
done

systemctl mask NetworkManager-wait-online.service 2>/dev/null || true
systemctl mask systemd-networkd-wait-online.service 2>/dev/null || true

# ── Unnötige Programme & Dienste entfernen ────────────────────
apt-get purge -y zeitgeist zeitgeist-core zeitgeist-datahub 2>/dev/null || true
apt-get purge -y diodon 2>/dev/null || true
apt-get purge -y xterm uxterm 2>/dev/null || true
apt-get autoremove -y 2>/dev/null || true
sudo -u "$TARGET_USER" systemctl --user mask xdg-desktop-portal.service \
    xdg-desktop-portal-gtk.service xdg-desktop-portal-gnome.service 2>/dev/null || true
success "Ballast entfernt (zeitgeist, diodon, xterm, uxterm)"

sed -i 's/#HandlePowerKey=.*/HandlePowerKey=ignore/' /etc/systemd/logind.conf

success "Performance & Sicherheit optimiert"

step "9/10 — Plymouth & Boot-Screen"

apt-get install -y plymouth plymouth-themes 2>/dev/null || true
PLYMOUTH_DIR="/usr/share/plymouth/themes/snowfox"
mkdir -p "$PLYMOUTH_DIR"

cat > "$PLYMOUTH_DIR/snowfox.plymouth" << 'EOF'
[Plymouth Theme]
Name=SnowFox
Description=SnowFoxOS Boot Theme
ModuleName=script
[script]
ImageDir=/usr/share/plymouth/themes/snowfox
ScriptFile=/usr/share/plymouth/themes/snowfox/snowfox.script
EOF

cat > "$PLYMOUTH_DIR/snowfox.script" << 'EOF'
wallpaper_image = Image("background.png");
screen_width = Window.GetWidth();
screen_height = Window.GetHeight();
wallpaper_sprite = Sprite(wallpaper_image);
wallpaper_sprite.SetX(screen_width / 2 - wallpaper_image.GetWidth() / 2);
wallpaper_sprite.SetY(screen_height / 2 - wallpaper_image.GetHeight() / 2);
logo_image = Image("logo.png");
logo_sprite = Sprite(logo_image);
logo_sprite.SetX(screen_width / 2 - logo_image.GetWidth() / 2);
logo_sprite.SetY(screen_height / 2 - logo_image.GetHeight() / 2);
EOF

[[ -f "$SCRIPT_DIR/assets/fuchs.png" ]] && \
    convert "$SCRIPT_DIR/assets/fuchs.png" -resize 200x200 "$PLYMOUTH_DIR/logo.png" 2>/dev/null || true
convert -size 1920x1080 xc:#0f0f0f "$PLYMOUTH_DIR/background.png" 2>/dev/null || true
plymouth-set-default-theme -R snowfox 2>/dev/null || \
    { plymouth-set-default-theme snowfox 2>/dev/null || true; update-initramfs -u 2>/dev/null || true; }

success "Boot-Screen bereit"

step "10/10 — Konfiguration & Finishing"

CONFIG_DIR="$TARGET_HOME/.config"
mkdir -p "$CONFIG_DIR/fastfetch"
mkdir -p "$TARGET_HOME/Pictures/wallpapers"

# ── Distro-Identität ─────────────────────────────────────────
cat > /etc/os-release << 'EOF'
PRETTY_NAME="SnowFoxOS 3.0"
NAME="SnowFoxOS"
VERSION="3.0"
VERSION_ID="3.0"
ID=snowfoxos
ID_LIKE=debian
HOME_URL="https://github.com/Xr7-Code/SnowFoxOS-v2.2"
ANSI_COLOR="0;35"
EOF

cat > /etc/lsb-release << 'EOF'
DISTRIB_ID=SnowFoxOS
DISTRIB_RELEASE=3.0
DISTRIB_CODENAME=fox
DISTRIB_DESCRIPTION="SnowFoxOS 3.0"
EOF

echo "snowfox"             > /etc/hostname
echo "SnowFoxOS 3.0"       > /etc/issue
echo "SnowFoxOS 3.0 \n \l" > /etc/issue.net
hostname snowfox 2>/dev/null || true
success "Distro-Identität gesetzt"

# ── Theme & GTK ──────────────────────────────────────────────
info "Aktiviere Arc-Dark + SnowFox-Farb-Overrides..."
mkdir -p "$CONFIG_DIR/xsettingsd"

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

# gsettings Darkmode erzwingen
sudo -u "$TARGET_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u $TARGET_USER)/bus" \
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
sudo -u "$TARGET_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u $TARGET_USER)/bus" \
    gsettings set org.gnome.desktop.interface gtk-theme 'Arc-Dark' 2>/dev/null || true

# ── Papirus-Ordnerfarbe (violett statt Standard-Blau) ─────────
info "Installiere papirus-folders & setze Ordnerfarbe auf violett..."
wget -qO- https://raw.githubusercontent.com/PapirusDevelopmentTeam/papirus-folders/master/install.sh \
    | sh 2>/dev/null || warn "papirus-folders Installation fehlgeschlagen"
if command -v papirus-folders &>/dev/null; then
    papirus-folders -t Papirus-Dark -C violet -u 2>/dev/null || \
        sudo -u "$TARGET_USER" papirus-folders -t Papirus-Dark -C violet -u 2>/dev/null || \
        warn "papirus-folders konnte Ordnerfarbe nicht setzen"
    success "Papirus-Ordner auf violett umgestellt"
else
    warn "papirus-folders nicht gefunden — Ordnerfarbe bleibt Standard"
fi

cat > "$CONFIG_DIR/gtk-3.0/gtk.css" << 'CSSEOF'
/* SnowFox GTK3 Color Override — lädt über Arc-Dark */
@define-color bg_color          #1e1e2e;
@define-color bg_alt_color      #252538;
@define-color bg_hover_color    #2e2e45;
@define-color fg_color          #cdd6f4;
@define-color fg_dim_color      #6c7086;
@define-color selected_bg_color #8139e8;
@define-color selected_fg_color #ffffff;
@define-color purple_hover      #9b5ef0;
@define-color purple_active     #6a2fc0;
@define-color error_color       #e05555;
@define-color success_color     #5faf5f;
@define-color warning_color     #ff9f5e;
@define-color border_color      #3d2a5c;

@define-color theme_bg_color              #1e1e2e;
@define-color theme_fg_color              #cdd6f4;
@define-color theme_base_color            #252538;
@define-color theme_text_color            #cdd6f4;
@define-color theme_selected_bg_color     #8139e8;
@define-color theme_selected_fg_color     #ffffff;
@define-color theme_tooltip_bg_color      #252538;
@define-color theme_tooltip_fg_color      #cdd6f4;
@define-color insensitive_bg_color        #1e1e2e;
@define-color insensitive_fg_color        #6c7086;
@define-color borders                     #3d2a5c;
@define-color alt_borders                 #3d2a5c;
@define-color sidebar_bg_color            #252538;
@define-color sidebar_fg_color            #cdd6f4;
@define-color link_color                  #9b5ef0;
@define-color link_visited_color          #6a2fc0;

window, .background         { background-color: @bg_color; color: @fg_color; }
headerbar, .titlebar        { background-color: @bg_alt_color; color: @fg_color; border-bottom: 1px solid @border_color; }
headerbar:backdrop          { background-color: @bg_color; color: @fg_dim_color; }
button                      { background-color: @bg_alt_color; color: @fg_color; border-color: @border_color; border-radius: 5px; }
button:hover                { background-color: @bg_hover_color; border-color: @selected_bg_color; }
button:active, button:checked { background-color: @purple_active; color: @selected_fg_color; border-color: @selected_bg_color; }
button:disabled             { background-color: @bg_color; color: @fg_dim_color; }
button.suggested-action     { background-color: @selected_bg_color; color: @selected_fg_color; border-color: @selected_bg_color; }
button.suggested-action:hover { background-color: @purple_hover; }
button.destructive-action   { background-color: @error_color; color: @selected_fg_color; border-color: @error_color; }
entry, spinbutton           { background-color: @bg_alt_color; color: @fg_color; border-color: @border_color; border-radius: 5px; caret-color: @selected_bg_color; }
entry:focus, spinbutton:focus { border-color: @selected_bg_color; }
entry selection             { background-color: @selected_bg_color; color: @selected_fg_color; }
menubar                     { background-color: @bg_color; color: @fg_color; }
menubar > menuitem:hover    { background-color: @bg_hover_color; }
menu, .menu                 { background-color: @bg_alt_color; color: @fg_color; border-color: @border_color; }
menuitem                    { color: @fg_color; }
menuitem:hover              { background-color: @selected_bg_color; color: @selected_fg_color; }
menuitem:disabled           { color: @fg_dim_color; }
.sidebar, placessidebar     { background-color: @bg_alt_color; color: @fg_color; border-color: @border_color; }
.sidebar row:hover, placessidebar row:hover { background-color: @bg_hover_color; }
.sidebar row:selected, placessidebar row:selected { background-color: @selected_bg_color; color: @selected_fg_color; }
treeview, treeview.view     { background-color: @bg_color; color: @fg_color; }
treeview:selected, treeview row:selected { background-color: @selected_bg_color; color: @selected_fg_color; }
treeview:hover              { background-color: @bg_hover_color; }
notebook > header           { background-color: @bg_alt_color; border-color: @border_color; }
notebook > header > tabs > tab { background-color: transparent; color: @fg_dim_color; }
notebook > header > tabs > tab:checked { background-color: @bg_color; color: @fg_color; }
notebook > header > tabs > tab:hover { background-color: @bg_hover_color; color: @fg_color; }
scrollbar trough            { background-color: @bg_alt_color; }
scrollbar slider            { background-color: @fg_dim_color; border-radius: 8px; }
scrollbar slider:hover      { background-color: @selected_bg_color; }
tooltip                     { background-color: @bg_alt_color; color: @fg_color; border-color: @border_color; border-radius: 5px; }
tooltip label               { color: @fg_color; }
popover                     { background-color: @bg_alt_color; border-color: @border_color; border-radius: 8px; }
list, listbox               { background-color: @bg_color; color: @fg_color; }
list row:hover, listbox row:hover { background-color: @bg_hover_color; }
list row:selected, listbox row:selected { background-color: @selected_bg_color; color: @selected_fg_color; }
check:checked, radio:checked { background-color: @selected_bg_color; border-color: @selected_bg_color; color: @selected_fg_color; }
switch:checked              { background-color: @selected_bg_color; border-color: @selected_bg_color; }
progressbar progress        { background-color: @selected_bg_color; }
progressbar trough          { background-color: @bg_alt_color; }
scale trough highlight      { background-color: @selected_bg_color; }
scale slider                { background-color: @selected_bg_color; border-color: @selected_bg_color; }
paned > separator           { background-color: @bg_hover_color; }
paned > separator:hover     { background-color: @selected_bg_color; }
statusbar                   { background-color: @bg_color; color: @fg_dim_color; }
label                       { color: @fg_color; }
label.dim-label, label:disabled { color: @fg_dim_color; }
*:link                      { color: @purple_hover; }
*:visited                   { color: @purple_active; }
button, entry, menu, menuitem, popover,
notebook > header > tabs > tab { border-radius: 5px; }
CSSEOF

cat > "$CONFIG_DIR/gtk-4.0/gtk.css" << 'CSS4EOF'
/* SnowFox GTK4 / Libadwaita Color Override */
:root {
    --accent-bg-color:       #8139e8;
    --accent-fg-color:       #ffffff;
    --accent-color:          #9b5ef0;
    --destructive-bg-color:  #e05555;
    --destructive-fg-color:  #ffffff;
    --success-bg-color:      #5faf5f;
    --success-fg-color:      #ffffff;
    --warning-bg-color:      #ff9f5e;
    --warning-fg-color:      #1e1e2e;
    --error-bg-color:        #e05555;
    --error-fg-color:        #ffffff;
    --window-bg-color:       #1e1e2e;
    --window-fg-color:       #cdd6f4;
    --view-bg-color:         #252538;
    --view-fg-color:         #cdd6f4;
    --headerbar-bg-color:    #252538;
    --headerbar-fg-color:    #cdd6f4;
    --headerbar-border-color:#3d2a5c;
    --headerbar-shade-color: rgba(0,0,0,0.2);
    --sidebar-bg-color:      #252538;
    --sidebar-fg-color:      #cdd6f4;
    --sidebar-border-color:  #3d2a5c;
    --card-bg-color:         #252538;
    --card-fg-color:         #cdd6f4;
    --card-shade-color:      rgba(0,0,0,0.15);
    --dialog-bg-color:       #1e1e2e;
    --dialog-fg-color:       #cdd6f4;
    --popover-bg-color:      #252538;
    --popover-fg-color:      #cdd6f4;
    --shade-color:           rgba(0,0,0,0.25);
    --scrollbar-outline-color: rgba(0,0,0,0.3);
    --thumbnail-bg-color:    #2e2e45;
    --thumbnail-fg-color:    #cdd6f4;
}
CSS4EOF

# GTK2
cat > "$TARGET_HOME/.gtkrc-2.0" << G2EOF
include "/usr/share/themes/Arc-Dark/gtk-2.0/gtkrc"
include "$TARGET_HOME/.gtkrc-2.0.mine"
G2EOF

cat > "$TARGET_HOME/.gtkrc-2.0.mine" << 'G2EOF'
# SnowFox GTK2 Override (FLAT/MODERN)
gtk-color-scheme = "main_bg:#1e1e2e\nmain_fg:#cdd6f4\ntext_color:#cdd6f4\nbase_color:#1e1e2e\nselected_bg_color:#8139e8\nselected_fg_color:#ffffff\ntoolbar_bg:#1e1e2e\nmenubar_bg:#1e1e2e"

style "snowfox-colors" {
    base[NORMAL]      = "#1e1e2e"
    base[ACTIVE]      = "#8139e8"
    base[INSENSITIVE] = "#1e1e2e"
    base[SELECTED]    = "#8139e8"
    bg[NORMAL]        = "#1e1e2e"
    bg[ACTIVE]        = "#252538"
    bg[INSENSITIVE]   = "#1e1e2e"
    bg[SELECTED]      = "#8139e8"
    bg[PRELIGHT]      = "#252538"
    text[NORMAL]      = "#cdd6f4"
    text[ACTIVE]      = "#ffffff"
    text[SELECTED]    = "#ffffff"
    fg[NORMAL]        = "#cdd6f4"
    fg[ACTIVE]        = "#ffffff"
    fg[SELECTED]      = "#ffffff"
    fg[PRELIGHT]      = "#ffffff"
}

style "snowfox-sidebar" {
    base[NORMAL]      = "#252538"
    base[ACTIVE]      = "#2e2e45"
    base[SELECTED]    = "#8139e8"
    bg[NORMAL]        = "#252538"
    bg[ACTIVE]        = "#2e2e45"
    text[NORMAL]      = "#cdd6f4"
    text[SELECTED]    = "#ffffff"
    fg[NORMAL]        = "#cdd6f4"
    GtkTreeView::vertical-separator   = 4
    GtkTreeView::horizontal-separator = 4
}

style "snowfox-leisten" {
    bg[NORMAL]   = "#1e1e2e"
    bg[ACTIVE]   = "#252538"
    bg[PRELIGHT] = "#252538"
    fg[NORMAL]   = "#cdd6f4"
    engine "murrine" {
        gradient_shades   = { 1.0, 1.0, 1.0, 1.0 }
        contrast          = 0.0
        lightborder_shade = 1.0
        glow_shade        = 1.0
    }
}

style "snowfox-menus" {
    base[NORMAL]   = "#252538"
    bg[NORMAL]     = "#252538"
    bg[PRELIGHT]   = "#8139e8"
    bg[SELECTED]   = "#8139e8"
    fg[NORMAL]     = "#cdd6f4"
    fg[PRELIGHT]   = "#ffffff"
    text[NORMAL]   = "#cdd6f4"
    text[PRELIGHT] = "#ffffff"
    engine "murrine" {
        gradient_shades   = { 1.0, 1.0, 1.0, 1.0 }
        contrast          = 0.0
        lightborder_shade = 1.0
        glow_shade        = 1.0
        roundness         = 0
    }
}

style "snowfox-widgets" {
    base[NORMAL]   = "#252538"
    bg[NORMAL]     = "#252538"
    bg[PRELIGHT]   = "#2e2e45"
    bg[ACTIVE]     = "#8139e8"
    fg[NORMAL]     = "#cdd6f4"
    text[NORMAL]   = "#cdd6f4"
    engine "murrine" {
        gradient_shades   = { 1.0, 1.0, 1.0, 1.0 }
        contrast          = 0.0
        lightborder_shade = 1.0
        glow_shade        = 1.0
        roundness         = 3
    }
}

style "snowfox-trenner" {
    bg[NORMAL]        = "#8139e8"
    bg[ACTIVE]        = "#8139e8"
    bg[PRELIGHT]      = "#8139e8"
    GtkPaned::handle-size = 2
}

class "GtkWidget"                   style "snowfox-colors"
widget_class "*"                    style "snowfox-colors"
widget_class "*<GtkMenuBar>*"       style "snowfox-leisten"
widget_class "*<GtkToolbar>*"       style "snowfox-leisten"
class "GtkPaned"                    style "snowfox-trenner"
widget_class "*<GtkButton>*"        style "snowfox-widgets"
widget_class "*<GtkEntry>*"         style "snowfox-widgets"
widget_class "*<GtkMenu>*"          style:highest "snowfox-menus"
widget_class "*<GtkMenuItem>*"      style:highest "snowfox-menus"
widget_class "*MenuBar*.*MenuItem*" style:highest "snowfox-menus"
widget_class "*<GtkTreeView>*"      style "snowfox-sidebar"
widget_class "*<GtkSidePane>*"      style "snowfox-sidebar"
widget_class "*FmSidebar*"          style "snowfox-sidebar"
widget_class "*FmSidePane*"         style "snowfox-sidebar"
widget_class "*FmTreeView*"         style "snowfox-sidebar"
G2EOF

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

info "Konfiguriere Qt-Styling..."
mkdir -p "$CONFIG_DIR/qt5ct" "$CONFIG_DIR/qt6ct"

cat > "$CONFIG_DIR/qt5ct/qt5ct.conf" << Q5EOF
[Appearance]
style=gtk2
Q5EOF

cat > "$CONFIG_DIR/qt6ct/qt6ct.conf" << Q6EOF
[Appearance]
style=gtk2
Q6EOF

# ── fastfetch Config ──────────────────────────────────────────
info "Konfiguriere fastfetch..."
if [[ -f "$SCRIPT_DIR/configs/fastfetch/config.jsonc" ]]; then
    mkdir -p "$CONFIG_DIR/fastfetch"
    cp "$SCRIPT_DIR/configs/fastfetch/config.jsonc" "$CONFIG_DIR/fastfetch/config.jsonc"
    # Logo-Pfad auf aktuelles Repo anpassen
    sed -i "s|/home/xr7-code/SnowFoxOS-v2.2/assets/fuchs.png|$SCRIPT_DIR/assets/fuchs.png|g" \
        "$CONFIG_DIR/fastfetch/config.jsonc"
    success "fastfetch Config aus Repo kopiert"
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
    "title",
    "separator",
    "os",
    "host",
    "kernel",
    "uptime",
    "packages",
    "shell",
    "display",
    "wm",
    "theme",
    "icons",
    "font",
    "cursor",
    "terminal",
    "terminalfont",
    "cpu",
    "gpu",
    "memory",
    "swap",
    "disk",
    "localip",
    "locale",
    "break",
    "colors"
  ]
}
FFEOF
    success "fastfetch Config erstellt"
fi

# ── bashrc — fastfetch statt neofetch ────────────────────────
grep -q "fastfetch\|neofetch\|snowfox-greeting" "$TARGET_HOME/.bashrc" 2>/dev/null || \
    printf '\n# SnowFoxOS Greeting\n[[ -x /usr/local/bin/snowfox-greeting ]] && snowfox-greeting\n' \
    >> "$TARGET_HOME/.bashrc"

if [[ -d "$SCRIPT_DIR/configs" ]]; then
    cp -r "$SCRIPT_DIR/configs/"* "$CONFIG_DIR/"
    success "Konfigurationsdateien kopiert"

    # Rofi Config anpassen — kein border-radius (kein picom mehr)
    if [[ -f "$CONFIG_DIR/rofi/config.rasi" ]]; then
        sed -i 's/show-icons: .*/show-icons: false;/' "$CONFIG_DIR/rofi/config.rasi"
        sed -i 's/icon-theme: .*/icon-theme: "Papirus-Dark";/' "$CONFIG_DIR/rofi/config.rasi"
        # border-radius auf 0 da kein picom
        sed -i 's/border-radius: [0-9]*;/border-radius: 0;/g' "$CONFIG_DIR/rofi/config.rasi"
        success "Rofi Config angepasst (border-radius=0, kein picom)"
    fi

    # picom Config entfernen falls vorhanden
    rm -f "$CONFIG_DIR/picom.conf" 2>/dev/null || true

    I3_CONFIG_PATH="$CONFIG_DIR/i3/config"
    if [[ -f "$I3_CONFIG_PATH" ]]; then
        # picom aus i3 Autostart entfernen
        sed -i '/exec.*picom/d' "$I3_CONFIG_PATH"
        sed -i '/exec --no-startup-id picom/d' "$I3_CONFIG_PATH"

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

        # Greenclip Autostart
        grep -q "greenclip" "$I3_CONFIG_PATH" || \
            echo 'exec --no-startup-id greenclip daemon' >> "$I3_CONFIG_PATH"

        success "i3-Config angepasst (picom entfernt, Shortcuts gesetzt, greenclip)"
    fi

    # GTK3-Override nach cp sicherstellen
    info "Stelle GTK3-Override nach Repo-Kopie sicher..."
    cp "$CONFIG_DIR/gtk-3.0/gtk.css" "$CONFIG_DIR/gtk-3.0/gtk.css.repo-bak" 2>/dev/null || true
    # (gtk.css wurde bereits oben geschrieben, cp -r könnte sie überschreiben haben)
    # Daher nochmal die fastfetch Config sichern
    if [[ -f "$CONFIG_DIR/fastfetch/config.jsonc" ]]; then
        sed -i "s|/home/xr7-code/SnowFoxOS-v2.2/assets/fuchs.png|$SCRIPT_DIR/assets/fuchs.png|g" \
            "$CONFIG_DIR/fastfetch/config.jsonc" 2>/dev/null || true
    fi

    success "GTK3-Override sichergestellt"
else
    warn "configs/-Verzeichnis nicht gefunden"
fi

find "$CONFIG_DIR" -name "*.sh" -exec chmod +x {} +

[[ -d "$SCRIPT_DIR/wallpapers" ]] && \
    cp -r "$SCRIPT_DIR/wallpapers/." "$TARGET_HOME/Pictures/wallpapers/"

DEFAULT_WP=$(ls "$TARGET_HOME/Pictures/wallpapers" 2>/dev/null | grep -iE "\.jpg$|\.png$|\.webp$|\.jpeg$" | head -n 1)
if [[ -n "$DEFAULT_WP" ]]; then
    echo "#!/bin/sh" > "$TARGET_HOME/.fehbg"
    echo "feh --bg-fill '$TARGET_HOME/Pictures/wallpapers/$DEFAULT_WP'" >> "$TARGET_HOME/.fehbg"
    chmod +x "$TARGET_HOME/.fehbg"
    chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.fehbg"
    info "Standard-Wallpaper gesetzt: $DEFAULT_WP"
fi

POLYBAR_CONF="$CONFIG_DIR/polybar/config.ini"
if [[ -f "$POLYBAR_CONF" ]]; then
    if [[ "$IS_LAPTOP" == "true" ]]; then
        BAT_NAME=$(ls /sys/class/power_supply/ 2>/dev/null | grep -E "BAT|battery" | head -1)
        [[ -n "$BAT_NAME" ]] && sed -i "s/battery = BAT1/battery = $BAT_NAME/" "$POLYBAR_CONF"

        BL_NAME=$(ls /sys/class/backlight/ 2>/dev/null | head -1)
        [[ -n "$BL_NAME" ]] && sed -i "s/card = intel_backlight/card = $BL_NAME/" "$POLYBAR_CONF"

        sed -i 's/^modules-right =.*/modules-right = backlight battery memory network pulseaudio/' "$POLYBAR_CONF"
        success "Polybar: Laptop-Modus (Akku + Helligkeit aktiv)"
    else
        sed -i 's/^modules-right =.*/modules-right = memory network pulseaudio/' "$POLYBAR_CONF"
        success "Polybar: Desktop-Modus (kein Akku/Helligkeit)"
    fi
fi

if [[ -d "$SCRIPT_DIR/configs/modprobe" ]]; then
    # amdgpu.conf wurde bereits oben mit Freeze-Fix geschrieben, nicht überschreiben
    # nvidia.conf aus Repo kopieren falls vorhanden, sonst Standard schreiben
    if [[ -f "$SCRIPT_DIR/configs/modprobe/nvidia.conf" ]]; then
        cp "$SCRIPT_DIR/configs/modprobe/nvidia.conf" /etc/modprobe.d/nvidia.conf
    fi
    update-initramfs -u 2>/dev/null || true
    success "modprobe Configs installiert"
fi

# nvidia.conf sicherstellen — falls nicht aus Repo kopiert
if [[ ! -f /etc/modprobe.d/nvidia.conf ]]; then
    cat > /etc/modprobe.d/nvidia.conf << 'EOF'
# SnowFoxOS — NVIDIA Konfiguration
blacklist nouveau

options nvidia NVreg_TemporaryFilePath=/var/tmp
options nvidia NVreg_EnableS0ixPowerManagement=0
options nvidia NVreg_PreserveVideoMemoryAllocations=1
options nvidia-drm modeset=1
options nvidia NVreg_DynamicPowerManagement=0x00
options nvidia NVreg_EnableGpuFirmware=0
EOF
    success "nvidia.conf geschrieben"
fi

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
    success "snowfox-display.sh installiert"
fi

mkdir -p "$CONFIG_DIR/polybar"
cat > "$CONFIG_DIR/polybar/launch.sh" << 'LAUNCHEOF'
#!/bin/bash
# SnowFoxOS — Polybar Starter
sleep 2
killall -q polybar
while pgrep -u $UID -x polybar >/dev/null; do sleep 0.1; done
PRIMARY=$(xrandr --query | grep " connected primary" | cut -d" " -f1)
if [[ -z "$PRIMARY" ]]; then
    PRIMARY=$(xrandr --query | grep " connected" | head -1 | cut -d" " -f1)
fi
MONITOR=$PRIMARY polybar snowfox 2>/tmp/polybar.log &
LAUNCHEOF
chmod +x "$CONFIG_DIR/polybar/launch.sh"
success "polybar/launch.sh installiert"

[[ -f "$SCRIPT_DIR/snowfox" ]] && \
    cp "$SCRIPT_DIR/snowfox" /usr/local/bin/snowfox && chmod +x /usr/local/bin/snowfox

[[ -f "$SCRIPT_DIR/snowfox-greeting.sh" ]] && \
    cp "$SCRIPT_DIR/snowfox-greeting.sh" /usr/local/bin/snowfox-greeting && \
    chmod +x /usr/local/bin/snowfox-greeting

echo ""
echo -e "${PURPLE}${BOLD}  Standard-Texteditor:${RESET}"
echo -e "  1) Mousepad (Standard)"
echo -e "  2) VSCodium"
read -rp "$(echo -e ${PURPLE}${BOLD}"Auswahl [1-2]: "${RESET})" DEFAULT_EDITOR
case "$DEFAULT_EDITOR" in
    2) DEFAULT_EDITOR_DESKTOP="codium.desktop" ;;
    *) DEFAULT_EDITOR_DESKTOP="mousepad.desktop" ;;
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
success "Standard-Anwendungen gesetzt"

# ── Berechtigungen ───────────────────────────────────────────
chown -R "$TARGET_USER:$TARGET_USER" "$CONFIG_DIR"
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/Pictures/wallpapers"
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.icons"
chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.gtkrc-2.0"
chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.gtkrc-2.0.mine"
chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.bash_profile"

for hook in "${DKMS_HOOKS[@]}"; do
    [[ -f "${hook}.snowfox-bak" ]] && mv "${hook}.snowfox-bak" "$hook"
done
info "DKMS-Hooks wiederhergestellt"

# ── initramfs mit allen Fixes neu bauen ──────────────────────
info "Baue initramfs mit allen Fixes neu..."
update-initramfs -u 2>/dev/null || true
success "initramfs aktualisiert"

info "Bereinige alte Pakete..."
apt-get autoremove --purge -y 2>/dev/null || true
success "Bereinigung abgeschlossen"

echo -e "${PURPLE}${BOLD}"
echo "  ███████╗███╗  ██╗ ██████╗ ██╗    ██╗███████╗ ██████╗ ██╗  ██╗"
echo "  ██╔════╝████╗ ██║██╔═══██╗██║    ██║██╔════╝██╔═══██╗╚██╗██╔╝"
echo "  ███████╗██╔██╗██║██║   ██║██║ █╗ ██║█████╗  ██║   ██║ ╚███╔╝ "
echo "  ╚════██║██║╚████║██║   ██║██║███╗██║██╔══╝  ██║   ██║ ██╔██╗ "
echo "  ███████║██║ ╚███║╚██████╔╝╚███╔███╔╝██║     ╚██████╔╝██╔╝╚██╗"
echo "  ╚══════╝╚═╝  ╚══╝ ╚═════╝  ╚══╝╚══╝ ╚═╝     ╚═════╝ ╚═╝  ╚═╝"
echo -e "${RESET}"
success "SnowFoxOS v3.0 erfolgreich installiert!"
warn   "Bitte neu starten: sudo reboot"
