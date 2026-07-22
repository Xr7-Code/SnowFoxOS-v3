#!/bin/bash
# SnowFoxOS v3 — System Setup Library
# Enthält Funktionen zur Systemversionierung und GRUB-Themeninstallation.

set -e

# Funktion zum Aktualisieren der Systemidentifikation
set_system_version() {
  # Sicherstellen, dass die Funktion als root ausgeführt wird
  if [ "$EUID" -ne 0 ]; then
    echo "[FEHLER] Bitte starte diese Funktion als root (z.B. mit sudo bash -c 'source lib/system_setup.sh && set_system_version')."
    return 1
  fi

  # KONFIGURATION — Hier die neuen Werte eintragen
  OS_NAME="SnowFoxOS"
  OS_VERSION="v3"
  OS_VERSION_ID="3.0"
  OS_PRETTY_NAME="${OS_NAME} ${OS_VERSION}"
  OS_REPO_URL="https://github.com/Xr7-Code/SnowFoxOS-v3"
  OS_COLOR="0;35" # Lila / Purple (SnowFox Standard)

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
}

# Funktion zum Installieren des GRUB-Themes
set_grub_theme() {
  # Sicherstellen, dass die Funktion als root ausgeführt wird
  if [ "$EUID" -ne 0 ]; then
    echo "[FEHLER] Bitte starte diese Funktion als root (z.B. mit sudo bash -c 'source lib/system_setup.sh && set_grub_theme')."
    return 1
  fi

  echo "[SnowFoxOS] Starte SnowFoxOS GRUB-Theme Installation..."

  THEME_DIR="/boot/grub/themes/snowfox"
  GRUB_CONFIG="/etc/default/grub"

  # 1. Verzeichnis anlegen
  echo "[INFO] Erstelle Theme-Verzeichnis unter $THEME_DIR..."
  mkdir -p "$THEME_DIR"

  # 2. theme.txt schreiben (Reiner Code, keine Rahmen, keine Bilder)
  echo "[INFO] Schreibe minimalistische theme.txt..."
  cat << 'EOF' > "$THEME_DIR/theme.txt"
# SnowFoxOS v3 Minimalist GRUB Theme
desktop-color: "#000000"

+ boot_menu {
  left = 33%
  top = 33%
  width = 34%
  height = 34%

  border_width = 0
  background_color = "#000000"

  item_color = "#888888"
  selected_item_color = "#FFFFFF"
  selected_item_bg_color = "#111111"

  item_height = 24
  item_spacing = 6
  scrollbar = false
}

+ label {
  left = 0
  top = 95%
  width = 100%
  align = "center"
  text = "SnowFoxOS v3  |  Nutze die Pfeiltasten"
  color = "#555555"
}
EOF

  # 3. /etc/default/grub modifizieren
  echo "[INFO] Passe GRUB-Systemkonfiguration an..."

  # Backup der alten Konfiguration erstellen, falls noch nicht vorhanden
  if [ ! -f "${GRUB_CONFIG}.bak" ]; then
    cp "$GRUB_CONFIG" "${GRUB_CONFIG}.bak"
    echo "[INFO] Backup der Original-Konfiguration unter ${GRUB_CONFIG}.bak erstellt."
  fi

  # Bestehende Einträge auskommentieren/entfernen, um Duplikate zu verhindern
  sed -i '/^GRUB_TIMEOUT=/d' "$GRUB_CONFIG"
  sed -i '/^GRUB_TERMINAL_OUTPUT=/d' "$GRUB_CONFIG"
  sed -i '/^GRUB_GFXMODE=/d' "$GRUB_CONFIG"
  sed -i '/^GRUB_THEME=/d' "$GRUB_CONFIG"

  # Neue, saubere Parameter anhängen
  cat << EOF >> "$GRUB_CONFIG"

# --- SnowFoxOS v3 Visuals ---
GRUB_TIMEOUT=1
GRUB_TERMINAL_OUTPUT="gfxterm"
GRUB_GFXMODE="1920x1080,auto"
GRUB_THEME="$THEME_DIR/theme.txt"
EOF

  # 4. GRUB aktualisieren
  echo "[INFO] Aktualisiere GRUB-Bootloader..."
  update-grub

  echo "[ERFOLG] Das minimalistische SnowFoxOS Boot-Menü ist jetzt aktiv."
  echo "Beim nächsten Neustart siehst du deine zentrierten Textoptionen."
}
