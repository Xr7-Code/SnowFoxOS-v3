#!/bin/bash

#SnowFoxOS v3.2 - Void Fixed (v2 Feature Complete + i3)

#Stable base + restored v2 desktop environment

RED='\033[0;31m' GREEN='\033[0;32m' CYAN='\033[0;36m' YELLOW='\033[1;33m' BOLD='\033[1m' NC='\033[0m'

info(){ echo -e "${CYAN}[INFO]${NC} $1"; } success(){ echo -e "${GREEN}[OK]${NC} $1"; } warn(){ echo -e "${YELLOW}[WARN]${NC} $1"; } error(){ echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

-------------------- checks --------------------

check_root(){ [[ $EUID -ne 0 ]] && error "Run as root" }

check_void(){ . /etc/os-release 2>/dev/null || error "Missing os-release" [[ "$ID" != "void" ]] && error "Not Void Linux" command -v xbps-install >/dev/null 2>&1 || error "xbps missing" success "Void Linux detected" }

check_user(){ REALUSER=${SUDO_USER:-$(logname 2>/dev/null)} [[ -z "$REALUSER" ]] && error "No user found" HOMEDIR="/home/$REALUSER" [[ ! -d "$HOMEDIR" ]] && error "Home missing" success "User: $REALUSER" }

-------------------- gpu --------------------

detect_gpu(){ command -v lspci >/dev/null || xbps-install -Sy pciutils GPU="generic" lspci | grep -qi nvidia && GPU="nvidia" lspci | grep -qi amd && GPU="amd" lspci | grep -qi intel && GPU="intel" success "GPU: $GPU" }

-------------------- packages (v2 restored + improved) --------------------

PACKAGES=( # X11 base xorg-minimal xinit xrandr xset xsetroot xclip xprop xf86-input-libinput

# i3 ecosystem (v2 restored)
i3 i3status i3lock dmenu
polybar rofi picom feh dunst libnotify

# terminal / file
kitty alacritty lf

# audio (safe Void stack)
pipewire pipewire-pulse wireplumber alsa-utils

# network
NetworkManager network-manager-applet

# fonts
noto-fonts font-awesome

# tools
git curl wget unzip zip pciutils btop

# media (v2 restored)
mpv yt-dlp

# power / system tools (v2 restored)
tlp tlp-runit redshift brightnessctl

# theming
gtk+3 lxappearance adwaita-icon-theme

# system core
dbus elogind polkit udisks2

)

-------------------- system --------------------

update_system(){ info "System update" xbps-install -Syu -y || error "update failed" }

install_packages(){ info "Installing packages" for p in "${PACKAGES[@]}"; do xbps-install -S -y "$p" || warn "skip: $p" done }

-------------------- services --------------------

enable_services(){ info "Enabling services" for s in dbus elogind NetworkManager tlp; do [[ -d /etc/sv/$s ]] && ln -sf /etc/sv/$s /var/service/ || warn "missing service: $s" done }

-------------------- user groups --------------------

setup_groups(){ info "User groups" for g in wheel audio video input network storage; do getent group "$g" >/dev/null && usermod -aG "$g" "$REALUSER" || true done }

-------------------- configs (v2 restored) --------------------

install_configs(){ info "Installing configs" local base base="$(dirname "$(realpath "$0")")/configs"

[[ ! -d "$base" ]] && warn "configs missing" && return

mkdir -p "$HOMEDIR/.config"

for d in i3 polybar rofi kitty dunst redshift lf; do
    [[ -d "$base/$d" ]] && cp -rn "$base/$d" "$HOMEDIR/.config/" || warn "missing config: $d"
done

chown -R "$REALUSER:$REALUSER" "$HOMEDIR/.config"

}

-------------------- x session --------------------

setup_x(){ cat > "$HOMEDIR/.xinitrc" <<EOF #!/bin/sh setxkbmap de xsetroot -cursor_name left_ptr exec i3 EOF chown "$REALUSER:$REALUSER" "$HOMEDIR/.xinitrc" }

setup_autostart(){ cat > "$HOMEDIR/.bash_profile" <<EOF if [[ -z $DISPLAY ]] && [[ $(tty) == /dev/tty1 ]]; then exec startx fi EOF }

-------------------- extras (v2 restored) --------------------

install_snowfox_cli(){ local dir dir="$(dirname "$(realpath "$0")")" [[ -f "$dir/snowfox" ]] && cp "$dir/snowfox" /usr/local/bin/ && chmod +x /usr/local/bin/snowfox || warn "snowfox missing" }

install_greeting(){ local dir dir="$(dirname "$(realpath "$0")")"

if [[ -f "$dir/snowfox-greeting.sh" ]]; then
    cp "$dir/snowfox-greeting.sh" /usr/local/bin/snowfox-greeting
    chmod +x /usr/local/bin/snowfox-greeting

    grep -q "snowfox-greeting" "$HOMEDIR/.bashrc" 2>/dev/null || \
    echo '[[ -x /usr/local/bin/snowfox-greeting ]] && snowfox-greeting' >> "$HOMEDIR/.bashrc"

    chown "$REALUSER:$REALUSER" "$HOMEDIR/.bashrc"
fi

}

-------------------- tuning --------------------

tune_system(){ cat > /etc/sysctl.d/99-snowfox.conf <<EOF vm.swappiness=10 vm.vfs_cache_pressure=50 kernel.nmi_watchdog=0 EOF

sysctl -p /etc/sysctl.d/99-snowfox.conf 2>/dev/null || true

}

-------------------- main --------------------

main(){ check_root check_void check_user detect_gpu

update_system
install_packages
enable_services
setup_groups
install_configs
setup_x
setup_autostart
install_snowfox_cli
install_greeting
tune_system

success "SnowFoxOS v3.2 installed (v2 feature complete)"

}

main "$@"
