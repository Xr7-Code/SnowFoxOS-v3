#!/bin/bash
# SnowFoxOS v3 Installer
# Basis: Void Linux (musl) + runit + i3 + X11
# Autor: Alexander Valentin Ludwig (Xr7-Code)

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

banner() {
cat << 'EOF'

  ███████╗███╗   ██╗ ██████╗ ██╗    ██╗███████╗ ██████╗ ██╗  ██╗
  ██╔════╝████╗  ██║██╔═══██╗██║    ██║██╔════╝██╔═══██╗╚██╗██╔╝
  ███████╗██╔██╗ ██║██║   ██║██║ █╗ ██║█████╗  ██║   ██║ ╚███╔╝
  ╚════██║██║╚██╗██║██║   ██║██║███╗██║██╔══╝  ██║   ██║ ██╔██╗
  ███████║██║ ╚████║╚██████╔╝╚███╔███╔╝██║     ╚██████╔╝██╔╝ ██╗
  ╚══════╝╚═╝  ╚═══╝ ╚═════╝  ╚══╝╚══╝ ╚═╝      ╚═════╝ ╚═╝  ╚═╝

       SnowFoxOS v3 — Void Linux (musl) + runit + i3 + X11
       Your computer belongs to you.

EOF
}

check_root() {
    [[ $EUID -ne 0 ]] && error "Bitte als root ausführen: sudo ./install.sh"
}

check_void() {
    [[ ! -f /etc/void-release ]] && error "Dieses Script ist nur für Void Linux."
}

check_user() {
    [[ -z "$SUDO_USER" ]] && error "Bitte mit sudo ausführen, nicht direkt als root."
    REALUSER="$SUDO_USER"
    HOMEDIR="/home/$REALUSER"
    info "Installiere für Nutzer: $REALUSER ($HOMEDIR)"
}

detect_gpu() {
    info "GPU wird erkannt..."
    if lspci 2>/dev/null | grep -qi "nvidia"; then
        GPU="nvidia"
        info "NVIDIA GPU erkannt."
        EXTRA_PACKAGES=(nvidia nvidia-dkms)
    elif lspci 2>/dev/null | grep -qi "amd\|radeon"; then
        GPU="amd"
        info "AMD GPU erkannt."
        EXTRA_PACKAGES=(mesa vulkan-loader mesa-vulkan-radeon)
    elif lspci 2>/dev/null | grep -qi "intel"; then
        GPU="intel"
        info "Intel GPU erkannt."
        EXTRA_PACKAGES=(mesa vulkan-loader mesa-vulkan-intel)
    else
        GPU="generic"
        warn "GPU nicht erkannt — generische Treiber."
        EXTRA_PACKAGES=(mesa)
    fi
}

PACKAGES=(
    # X11
    xorg-minimal xorg-input-drivers xorg-video-drivers
    xinit xrandr xset xsetroot xclip
    # i3 Desktop
    i3 i3lock polybar rofi feh dunst libnotify picom
    # Terminal + Browser + Dateimanager
    kitty librewolf lf
    # Audio
    pipewire pipewire-pulse wireplumber alsa-utils alsa-pipewire
    # Netzwerk
    NetworkManager network-manager-applet
    # Fonts
    noto-fonts-ttf noto-fonts-emoji font-awesome6
    # Tools
    btop curl wget git unzip zip maim scrot
    # Media
    mpv yt-dlp
    # Akku + Blaulicht
    tlp redshift
    # Theming
    gtk+3 adwaita-icon-theme lxappearance
    # System
    dbus elogind polkit udisks2 brightnessctl
    # Passwort
    gnupg pass
    # Gaming
    steam lutris gamemode
)

update_system() {
    info "System wird aktualisiert..."
    xbps-install -Syu --yes
    success "System aktuell."
}

install_packages() {
    info "Pakete werden installiert (das kann etwas dauern)..."
    xbps-install -S --yes "${PACKAGES[@]}" "${EXTRA_PACKAGES[@]}" || {
        warn "Einige Pakete konnten nicht installiert werden — wird fortgesetzt."
    }
    success "Pakete installiert."
}

enable_services() {
    info "Dienste werden aktiviert (runit)..."
    local services=(dbus elogind NetworkManager tlp pipewire wireplumber)
    for svc in "${services[@]}"; do
        if [[ -d /etc/sv/$svc ]]; then
            ln -sf /etc/sv/$svc /var/service/$svc 2>/dev/null || true
            success "Service aktiviert: $svc"
        else
            warn "Service nicht gefunden: $svc (übersprungen)"
        fi
    done
}

disable_services() {
    local disable=(wpa_supplicant acpid)
    for svc in "${disable[@]}"; do
        [[ -L /var/service/$svc ]] && rm -f /var/service/$svc && success "Service deaktiviert: $svc"
    done
}

install_configs() {
    info "Konfigurationsdateien werden installiert..."
    local cfg="$(dirname "$0")/configs"
    mkdir -p "$HOMEDIR/.config"

    for dir in i3 polybar rofi kitty dunst redshift; do
        if [[ -d "$cfg/$dir" ]]; then
            cp -r "$cfg/$dir" "$HOMEDIR/.config/"
            success "Config installiert: $dir"
        fi
    done

    # Polybar launch.sh ausführbar machen
    chmod +x "$HOMEDIR/.config/polybar/launch.sh" 2>/dev/null || true

    # i3lock script
    if [[ -f "$cfg/i3lock/lock.sh" ]]; then
        cp "$cfg/i3lock/lock.sh" /usr/local/bin/snowfox-lock
        chmod +x /usr/local/bin/snowfox-lock
        success "Lock-Screen installiert."
    fi

    chown -R "$REALUSER:$REALUSER" "$HOMEDIR/.config"
}

setup_autostart() {
    info "X11 Autostart wird eingerichtet..."

    cat > "$HOMEDIR/.xinitrc" << 'EOF'
#!/bin/sh
# SnowFoxOS v3 — .xinitrc
export $(dbus-launch --sh-syntax)
export GTK_THEME=Adwaita:dark
xsetroot -cursor_name left_ptr
setxkbmap de
exec i3
EOF

    cat > "$HOMEDIR/.bash_profile" << 'EOF'
# SnowFoxOS v3 — X11 startet automatisch auf TTY1
if [[ -z $DISPLAY && $XDG_VTNR -eq 1 ]]; then
    exec startx
fi
EOF

    chmod +x "$HOMEDIR/.xinitrc"
    chown "$REALUSER:$REALUSER" "$HOMEDIR/.xinitrc" "$HOMEDIR/.bash_profile"
    success "Autostart eingerichtet (startx auf TTY1)."
}

install_snowfox_cli() {
    info "snowfox CLI wird installiert..."
    cp "$(dirname "$0")/snowfox" /usr/local/bin/snowfox
    chmod +x /usr/local/bin/snowfox
    success "snowfox CLI installiert."
}

tune_system() {
    info "System wird optimiert..."

    cat > /etc/sysctl.d/99-snowfox.conf << 'EOF'
vm.swappiness=10
vm.vfs_cache_pressure=50
kernel.nmi_watchdog=0
net.core.netdev_max_backlog=16384
EOF
    sysctl -p /etc/sysctl.d/99-snowfox.conf 2>/dev/null || true

    mkdir -p "$HOMEDIR/Pictures/Wallpapers"
    cp "$(dirname "$0")/wallpapers/"* "$HOMEDIR/Pictures/Wallpapers/" 2>/dev/null || true
    chown -R "$REALUSER:$REALUSER" "$HOMEDIR/Pictures"
    success "System optimiert."
}

install_greeting() {
    info "Greeting wird installiert..."
    cp "$(dirname "$0")/snowfox-greeting.sh" /usr/local/bin/snowfox-greeting
    chmod +x /usr/local/bin/snowfox-greeting

    if ! grep -q "snowfox-greeting" "$HOMEDIR/.bashrc" 2>/dev/null; then
        printf '\n# SnowFoxOS Greeting\n[[ -x /usr/local/bin/snowfox-greeting ]] && snowfox-greeting\n' >> "$HOMEDIR/.bashrc"
    fi
    chown "$REALUSER:$REALUSER" "$HOMEDIR/.bashrc"
    success "Greeting installiert."
}

main() {
    clear
    banner
    check_root
    check_void
    check_user
    detect_gpu

    echo ""
    echo -e "${BOLD}Installation wird gestartet für: $REALUSER${NC}"
    echo -e "${YELLOW}Basis: Void Linux (musl) + runit + i3 + X11${NC}"
    echo -e "${CYAN}GPU:   $GPU${NC}"
    echo ""
    read -rp "Fortfahren? [j/N] " confirm
    [[ "$confirm" =~ ^[jJ]$ ]] || { echo "Abgebrochen."; exit 0; }
    echo ""

    update_system
    install_packages
    enable_services
    disable_services
    install_configs
    setup_autostart
    install_snowfox_cli
    tune_system
    install_greeting

    echo ""
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║   SnowFoxOS v3 erfolgreich installiert!  ║${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Starte neu und logge dich auf ${BOLD}TTY1${NC} ein."
    echo -e "  X11 + i3 starten automatisch."
    echo ""
    read -rp "Jetzt neu starten? [j/N] " reboot_now
    [[ "$reboot_now" =~ ^[jJ]$ ]] && reboot
}

main "$@"
