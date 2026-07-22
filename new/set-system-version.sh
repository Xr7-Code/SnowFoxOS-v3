#!/bin/bash

# SnowFoxOS v3 — System Version & Naming Manager
# Philosophie: Modulare Systemkonfiguration über saubere Variablen.

set -e

# Sicherstellen, dass das Skript als root ausgeführt wird
if [ "$EUID" -ne 0 ]; then
  echo "[FEHLER] Bitte starte das Skript mit sudo: sudo bash $0"
  exit 1
fi

# ==========================================
# KONFIGURATION — Hier die neuen Werte eintragen
# ==========================================
OS_NAME="SnowFoxOS"
OS_VERSION="v3"
OS_VERSION_ID="3.0"
OS_PRETTY_NAME="${OS_NAME} ${OS_VERSION}"
OS_REPO_URL="https://github.com/Xr7-Code/SnowFoxOS-v3"
OS_COLOR="0;35" # Lila / Purple (SnowFox Standard)
# ==========================================

echo "[SnowFoxOS] Aktualisiere Systemidentifikation für ${OS_PRETTY_NAME}..."

# 1. /etc/os-release neu schreiben
echo "[INFO] Aktualisiere /etc/os-release..."
cat << EOF > /etc/os-release
NAME="${OS_NAME}"
VERSION="${OS_VERSION}"
VERSION_ID="${OS_VERSION_ID}"
PRETTY_NAME="${OS_PRETTY_NAME}"
ID=snowfoxos
ID_LIKE=debian
HOME_URL="${OS_REPO_URL}"
ANSI_COLOR="${OS_COLOR}"
EOF

# 2. /etc/issue anpassen (Der Text, der vor dem Login auf TTY1 steht)
echo "[INFO] Aktualisiere System-Login-Banner (/etc/issue)..."
echo -e "${OS_PRETTY_NAME} \\\n \\\l\n" > /etc/issue

# 3. GRUB-Menü-Eintrag für das Hauptsystem anpassen
if [ -f /etc/default/grub ]; then
  echo "[INFO] Synchronisiere Namen mit der GRUB-Konfiguration..."
  sed -i '/^GRUB_DISTRIBUTOR=/d' /etc/default/grub
  echo "GRUB_DISTRIBUTOR=\"${OS_NAME} ${OS_VERSION}\"" >> /etc/default/grub
fi

# 4. Änderungen systemweit anwenden
echo "[INFO] Generiere GRUB-Bootloader-Konfiguration neu..."
update-grub

echo "[ERFOLG] System erfolgreich auf ${OS_PRETTY_NAME} umgestellt!"
echo "Die Änderungen sind im Terminal (z.B. bei fastfetch) und im GRUB-Menü aktiv."