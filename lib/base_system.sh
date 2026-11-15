#!/usr/bin/env bash
# ============================================================
#  SnowFoxOS v4 — Base System Setup
#  Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)
# ============================================================

source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/checksums.sh"

info "Installing for: ${BOLD}$TARGET_USER${RESET}"
sleep 1

step "1/10 — System update"

DKMS_HOOKS=(
    /etc/kernel/postinst.d/dkms
    /etc/kernel/prerm.d/dkms
    /usr/lib/kernel/install.d/50-dkms.install
)
for hook in "${DKMS_HOOKS[@]}"; do
    [[ -f "$hook" ]] && mv "$hook" "${hook}.snowfox-bak"
done
info "DKMS hooks disabled for installer run"

systemd_safe disable apt-daily.service
systemd_safe disable apt-daily.timer
systemd_safe disable apt-daily-upgrade.service
systemd_safe disable apt-daily-upgrade.timer
systemd_safe stop apt-daily.service
systemd_safe stop apt-daily-upgrade.service
success "apt-daily disabled"

if [[ "${SNOWFOX_PHASE:-full}" == "full" ]]; then
    cat > /etc/apt/sources.list <<'EOF'
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
else
    info "ISO phase: keeping installer-provided APT sources (no dist-upgrade)"
    dpkg --add-architecture i386
    wait_apt
    apt-get update -qq 2>/dev/null || warn "apt-get update failed — using the local ISO pool only"
    dpkg --configure -a 2>/dev/null || true
    apt-get -f install -y 2>/dev/null || true
fi

audit_recommends() {
    local out="/var/log/snowfox/recommends-audit.log"
    install -d -m 0755 "$(dirname "$out")"
    : > "$out"

    local pkg
    for pkg in "$@"; do
        local with rec without
        with=$(apt-get install -s --no-install-recommends "$pkg" 2>/dev/null \
               | awk '/^Inst / {print $2}' | sort -u)
        rec=$(apt-get install -s "$pkg" 2>/dev/null \
               | awk '/^Inst / {print $2}' | sort -u)
        without=$(comm -13 <(printf '%s\n' "$with") <(printf '%s\n' "$rec"))
        if [[ -n "$without" ]]; then
            {
                echo "== $pkg =="
                printf '%s\n' "$without" | sed 's/^/  + /'
                echo
            } >> "$out"
        fi
    done
    info "Recommends audit written to $out"
}

BASE_PACKAGES=(
    curl wget git unzip
    ca-certificates aria2 fzf jq lz4 gnupg
    pciutils usbutils htop btop irqbalance
    bash-completion sudo openssh-client
    xdg-utils xdg-user-dirs
    rfkill wpasupplicant wireless-regdb
    systemd-resolved systemd-timesyncd
    iw wireless-tools
    imagemagick bc
    xorg xserver-xorg-legacy xinit
    x11-utils x11-xserver-utils
    xclip xdotool dbus-x11
    lm-sensors
    qt5ct qt5-style-plugins qt6ct
    # foxdock build deps (§0c 21) — purged in cleanup_final.sh
    libx11-dev libimlib2-dev
    feh
)
[[ "${SNOWFOX_PHASE:-full}" == "full" ]] && BASE_PACKAGES+=(build-essential)

audit_recommends "${BASE_PACKAGES[@]}"
apt-get install -y "${BASE_PACKAGES[@]}"

systemd_safe stop dnsmasq
systemd_safe disable dnsmasq
systemd_safe mask dnsmasq
systemd_safe enable systemd-resolved

if [[ "${SNOWFOX_PHASE:-full}" == "full" ]]; then
    ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf 2>/dev/null || true
else
    info "ISO phase: keeping installer DNS configuration for the chroot"
fi

cat > /etc/profile.d/99-snowfox-path.sh <<'EOF'
case ":$PATH:" in
    *:/usr/sbin:*) ;;
    *) export PATH="$PATH:/usr/sbin" ;;
esac
EOF
chmod 0644 /etc/profile.d/99-snowfox-path.sh

# Locales nur full
if [[ "${SNOWFOX_PHASE:-full}" != "full" ]]; then
    info "Generating locales selected in debian-installer..."
    apt-get install -y locales
    SEL_LANG="$(sed -n 's/^LANG=//p' /etc/default/locale 2>/dev/null | tr -d '"' | head -n1)"
    [[ -z "$SEL_LANG" ]] && SEL_LANG="${LANG:-en_US.UTF-8}"
    for loc in "$SEL_LANG" "en_US.UTF-8"; do
        [[ -z "$loc" || "$loc" == "C" || "$loc" == "POSIX" ]] && continue
        [[ "$loc" == *.* ]] || loc="${loc}.UTF-8"
        grep -q "^${loc} " /etc/locale.gen 2>/dev/null || {
            sed -i "s/^# *${loc} /${loc} /" /etc/locale.gen 2>/dev/null || true
            grep -q "^${loc} " /etc/locale.gen 2>/dev/null || \
                echo "$loc UTF-8" >> /etc/locale.gen
        }
    done
    locale-gen
    success "ISO locale preserved: ${SEL_LANG}"
fi

if [[ "${SNOWFOX_PHASE:-full}" == "full" ]]; then
    sudo -u "$TARGET_USER" xdg-user-dirs-update
else
    info "ISO phase: XDG user dirs deferred to firstboot"
fi
success "System updated"

# ── fastfetch (verified) ──────────────────────────────────
info "Installing fastfetch (verified)..."

_fetch_verified() {
    local url="$1" dest="$2" expected="$3" name="$4"
    local tmp
    tmp=$(mktemp) || error "mktemp failed"
    if ! curl -fsSL --proto '=https' --tlsv1.2 --max-time 120 "$url" -o "$tmp"; then
        rm -f "$tmp"; warn "Download failed: $url — skipping $name"; return 1
    fi
    _verify_checksum "$tmp" "$expected" "$name" || { rm -f "$tmp"; return 1; }
    mv "$tmp" "$dest"; chmod 0644 "$dest"
}

if [[ "${SNOWFOX_PHASE:-full}" != "full" && "${SNOWFOX_NETWORK:-online}" == "offline" ]]; then
    info "ISO offline: skipping optional fastfetch download"
else
    FASTFETCH_DEB_URL="https://github.com/fastfetch-cli/fastfetch/releases/download/${FASTFETCH_VERSION}/fastfetch-linux-amd64.deb"
    if _fetch_verified "$FASTFETCH_DEB_URL" /tmp/fastfetch.deb \
            "$CHECKSUM_FASTFETCH" "fastfetch"; then
        dpkg -i /tmp/fastfetch.deb 2>/dev/null \
            && success "fastfetch installed" \
            || warn "fastfetch .deb failed to install — install manually"
        rm -f /tmp/fastfetch.deb
    fi
fi

# ── X11 ───────────────────────────────────────────────────
mkdir -p /etc/X11
cat > /etc/X11/Xwrapper.config <<'XWEOF'
allowed_users=anybody
needs_root_rights=auto
XWEOF
success "Xwrapper.config set"

# ── Gruppen ───────────────────────────────────────────────
info "Setting groups for $TARGET_USER (sudo, video, input, render, tty, audio)..."
for grp in sudo video input render tty audio; do
    if getent group "$grp" > /dev/null 2>&1; then
        usermod -aG "$grp" "$TARGET_USER"
    else
        warn "Group '$grp' not found — skipping"
    fi
done
success "Groups set for $TARGET_USER"
