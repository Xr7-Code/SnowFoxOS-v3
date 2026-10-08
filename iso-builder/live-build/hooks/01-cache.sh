#!/bin/bash
# ============================================================
#  SnowFoxOS v3 — live-build Hook: Installer Prep
#  Runs inside the chroot during ISO build.
#  Keeps the live environment minimal — only installer tools.
#  SnowFoxOS packages are installed by install.sh on target.
#  Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)
# ============================================================

set -euo pipefail

echo "[SnowFox Hook] Preparing installer environment..."

# ── Strip bloat from live chroot ──────────────────────────────
# doc, locale, man pages — not needed in the installer
rm -rf /usr/share/doc/*
rm -rf /usr/share/man/*
rm -rf /usr/share/info/*
rm -rf /usr/share/locale/*
# Keep en and de
mkdir -p /usr/share/locale/en_US /usr/share/locale/de_AT

# ── Clean apt cache in chroot ─────────────────────────────────
apt-get clean

# ── Enable installer service ──────────────────────────────────
if [[ -f /etc/systemd/system/snowfox-installer.service ]]; then
    systemctl enable snowfox-installer.service 2>/dev/null || true
    systemctl disable getty@tty1.service 2>/dev/null || true
    echo "[SnowFox Hook] Installer service enabled"
else
    echo "[SnowFox Hook] WARNING: snowfox-installer.service not found"
fi

# ── Auto-login as root on TTY1 ────────────────────────────────
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << 'ALOEOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I $TERM
ALOEOF

echo "[SnowFox Hook] Installer environment ready"
