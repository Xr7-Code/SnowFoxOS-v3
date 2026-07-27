#!/bin/bash

# ============================================================
#  SnowFoxOS v3.0 — Performance & Security Optimizations
# ============================================================

# Load utilities (assumes SCRIPT_DIR is set before sourcing)
source "$SCRIPT_DIR/lib/utils.sh"

# Global variables from main script (assumed to be sourced/exported):
# TARGET_USER

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
DNSSEC=yes
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

# ── Kernel-Härtung ────────────────────────────────────────────
info "Setze Kernel-Sicherheitsparameter..."
cat > /etc/sysctl.d/99-snowfox-security.conf << 'SYSCTLEOF'
# SnowFoxOS Kernel-Härtung

# Kernel-Informationen verstecken
kernel.dmesg_restrict=1
kernel.kptr_restrict=2
kernel.perf_event_paranoid=3
kernel.unprivileged_bpf_disabled=1
net.core.bpf_jit_harden=2

# Netzwerk-Härtung
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1
net.ipv4.tcp_syncookies=1
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv6.conf.all.accept_redirects=0
net.ipv4.conf.all.log_martians=1
net.ipv4.tcp_max_syn_backlog=2048
net.ipv4.tcp_synack_retries=2

# Core Dumps deaktivieren
fs.suid_dumpable=0
kernel.core_pattern=|/bin/false
SYSCTLEOF
sysctl -p /etc/sysctl.d/99-snowfox-security.conf &>/dev/null
success "Kernel-Härtung gesetzt"

# ── SSH deaktivieren ──────────────────────────────────────────
if systemctl is-enabled ssh &>/dev/null 2>&1; then
    systemctl disable --now ssh 2>/dev/null || true
    info "SSH deaktiviert (aktivieren: sudo systemctl enable --now ssh)"
fi

# ── UFW: SSH-Regel entfernen ──────────────────────────────────
if command -v ufw &>/dev/null; then
    ufw delete allow 22/tcp 2>/dev/null || true
    ufw delete allow ssh    2>/dev/null || true
    ufw --force enable      2>/dev/null || true
    success "UFW: SSH-Regel entfernt"
fi

# ── rfkill installieren (für snowfox airmode) ─────────────────
apt-get install -y rfkill 2>/dev/null || true
