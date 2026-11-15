#!/usr/bin/env bash
# ============================================================
#  SnowFoxOS v4 — Performance & Security
#  Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)
# ============================================================

source "$SCRIPT_DIR/lib/utils.sh"

step "8/10 — Performance & Security"

wait_apt
apt-get install -y zram-tools earlyoom ufw

if [[ "${IS_LAPTOP:-false}" == "true" ]]; then
    command -v tlp &>/dev/null || apt-get install -y tlp tlp-rdw
    systemd_safe enable tlp
else
    systemd_safe disable tlp
    [[ -f /etc/tlp.conf ]] && sed -i 's/^USB_AUTOSUSPEND=.*/USB_AUTOSUSPEND=0/' /etc/tlp.conf
fi

cat > /etc/default/zramswap <<'EOF'
ALGO=lz4
PERCENT=50
PRIORITY=100
EOF

if [[ -f /etc/initramfs-tools/initramfs.conf ]]; then
    sed -i 's/^COMPRESS=.*/COMPRESS=lz4/' /etc/initramfs-tools/initramfs.conf
    update-initramfs -u 2>/dev/null || true
fi

systemd_safe enable zramswap
systemd_safe enable earlyoom

cat > /etc/sysctl.d/99-snowfox.conf <<'EOF'
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_background_ratio=3
vm.dirty_ratio=6
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv6.conf.all.use_tempaddr=2
net.ipv6.conf.default.use_tempaddr=2
kernel.nmi_watchdog=0
EOF

info "Optimizing fstab (idempotent)..."
if ! grep -q '^tmpfs[[:space:]]\+/tmp[[:space:]]' /etc/fstab; then
    mem_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    tmp_kb=$(( mem_kb / 4 ))
    (( tmp_kb < 1048576 )) && tmp_kb=1048576
    (( tmp_kb > 4194304 )) && tmp_kb=4194304
    tmp_mb=$(( tmp_kb / 1024 ))
    echo "tmpfs /tmp tmpfs defaults,noatime,size=${tmp_mb}M,mode=1777 0 0" >> /etc/fstab
    success "tmpfs /tmp mounted with ${tmp_mb}M"
fi

if awk '$2=="/" && $4 !~ /(^|,)noatime(,|$)/ {exit 1}' /etc/fstab; then
    sed -i -E 's#^([^[:space:]]+[[:space:]]+/[[:space:]]+[^[:space:]]+[[:space:]]+)([^[:space:]]+)#\1\2,noatime#' /etc/fstab
    success "noatime added to root mount"
fi
sed -i -E 's/(,noatime)+/,noatime/g' /etc/fstab

ufw --force reset  >/dev/null 2>&1 || true
ufw default deny incoming  2>/dev/null || true
ufw default allow outgoing 2>/dev/null || true
ufw --force enable         2>/dev/null || true
success "ufw enabled"

if [[ -f /etc/network/interfaces ]]; then
    cp -n /etc/network/interfaces /etc/network/interfaces.snowfox-bak 2>/dev/null || true
    sed -i -E '/^[[:space:]]*(auto|allow-hotplug|iface)[[:space:]]+(wl|en|eth)/ s/^/#/' /etc/network/interfaces
    success "ifupdown entries for WiFi/LAN commented out"
fi

mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/NetworkManager.conf <<'EOF'
[main]
plugins=ifupdown,keyfile

[ifupdown]
managed=true
EOF

cat > /etc/NetworkManager/conf.d/99-snowfox-wifi-powersave.conf <<'EOF'
[connection]
wifi.powersave=2
EOF

mkdir -p /etc/systemd/resolved.conf.d
cat > /etc/systemd/resolved.conf.d/snowfox.conf <<'EOF'
[Resolve]
DNS=1.1.1.1#cloudflare-dns.com 9.9.9.9#dns.quad9.net
FallbackDNS=9.9.9.9#dns.quad9.net
DNSSEC=yes
DNSOverTLS=yes
EOF
systemd_safe enable systemd-resolved
systemd_safe restart systemd-resolved
systemd_safe enable irqbalance

for svc in avahi-daemon cups-browsed ModemManager colord blueman; do
    systemd_safe disable "$svc"
done
systemd_safe mask NetworkManager-wait-online.service
systemd_safe mask systemd-networkd-wait-online.service

apt-get purge -y zeitgeist zeitgeist-core zeitgeist-datahub 2>/dev/null || true
apt-get purge -y diodon 2>/dev/null || true
apt-get purge -y xterm uxterm 2>/dev/null || true
apt-get autoremove -y 2>/dev/null || true
success "Bloat removed"

if systemctl --user list-unit-files xdg-desktop-portal-gnome.service &>/dev/null; then
    sudo -u "$TARGET_USER" systemctl --user mask \
        xdg-desktop-portal-gnome.service 2>/dev/null || true
fi

sed -i 's/#HandlePowerKey=.*/HandlePowerKey=ignore/' /etc/systemd/logind.conf

cat > /etc/sysctl.d/99-snowfox-security.conf <<'SYSCTLEOF'
kernel.dmesg_restrict=1
kernel.kptr_restrict=2
kernel.perf_event_paranoid=3
kernel.unprivileged_bpf_disabled=1
net.core.bpf_jit_harden=2
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
fs.suid_dumpable=0
kernel.core_pattern=|/bin/false
SYSCTLEOF
sysctl -p /etc/sysctl.d/99-snowfox-security.conf &>/dev/null || true
success "Kernel hardening applied"

if systemctl is-enabled ssh &>/dev/null 2>&1; then
    systemd_safe disable ssh
    info "SSH disabled"
fi

if command -v ufw &>/dev/null; then
    ufw delete allow 22/tcp 2>/dev/null || true
    ufw delete allow ssh    2>/dev/null || true
    ufw --force enable      2>/dev/null || true
    success "UFW: SSH rule removed"
fi

apt-get install -y rfkill 2>/dev/null || true

info "Configuring unattended-upgrades (security only)..."
apt-get install -y unattended-upgrades apt-listchanges

cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

cat > /etc/apt/apt.conf.d/51unattended-upgrades-snowfox <<'EOF'
// SnowFoxOS — security-only automatic updates.
Unattended-Upgrade::Origins-Pattern {
    "origin=Debian,codename=${distro_codename},label=Debian-Security";
    "origin=Debian,codename=${distro_codename}-security,label=Debian-Security";
};
Unattended-Upgrade::Package-Blacklist {
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::SyslogEnable "true";
EOF

systemd_safe enable unattended-upgrades
systemd_safe start unattended-upgrades
success "unattended-upgrades configured (Debian-Security only)"

info "Setting up AIDE (file integrity baseline)..."
apt-get install -y aide aide-common

mkdir -p /etc/aide/aide.conf.d
cat > /etc/aide/aide.conf.d/99-snowfox <<'EOF'
/usr/bin    p+i+n+u+g+s+m+c+sha256
/usr/sbin   p+i+n+u+g+s+m+c+sha256
/usr/local/bin  p+i+n+u+g+s+m+c+sha256
/usr/local/sbin p+i+n+u+g+s+m+c+sha256
/etc        p+i+n+u+g+s+m+c+sha256
/home/*/.config/autostart  p+i+n+u+g+s+m+c+sha256
/home/*/.local/share/applications  p+i+n+u+g+s+m+c+sha256
/home/*/.local/bin  p+i+n+u+g+s+m+c+sha256
EOF

if [[ "${SNOWFOX_PHASE:-full}" != "full" ]]; then
    info "ISO phase: AIDE baseline deferred to firstboot"
elif command -v aideinit >/dev/null 2>&1; then
    aideinit -y -f >/dev/null 2>&1 || warn "aideinit failed"
    if [[ -f /var/lib/aide/aide.db.new ]]; then
        mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
        chmod 0600 /var/lib/aide/aide.db
        success "AIDE baseline initialised"
    fi
else
    warn "aideinit not found — AIDE not initialised"
fi

systemd_safe enable dailyaidecheck.timer
success "All performance & security steps complete"
