#!/bin/bash

# SnowFoxOS v3 — GRUB Theme Installer
# Philosophie: Radikaler Minimalismus. Tiefschwarz, zentrierter weißer Text, kein Rahmen.

# Fehler abfangen
set -e

# Sicherstellen, dass das Skript als root ausgeführt wird
if [ "$EUID" -ne 0 ]; then
  echo "[FEHLER] Bitte starte das Skript mit sudo: sudo bash $0"
  exit 1
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