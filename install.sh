#!/bin/bash
# ============================================================
#  SnowFoxOS v3.0 — Installer
#  Basis: Debian 12 (Bookworm) minimal
#  Desktop: i3 + Polybar + Rofi + Dunst + i3lock
#  Ausführen: sudo bash install.sh
# ============================================================

# ── Basis-Checks vor dem Source der lib ──────────────────────
if [[ $EUID -ne 0 ]]; then
    echo "Bitte mit sudo ausführen: sudo bash install.sh"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Utils laden (Farben, info/success/warn/error/step/ask_install/wait_apt) ──
source "$SCRIPT_DIR/lib/utils.sh"

# ── Debian-Version prüfen ────────────────────────────────────
if [[ ! -f /etc/debian_version ]] || ! grep -q "^12\." /etc/debian_version; then
    warn "Dieses Script ist für Debian 12 (Bookworm) optimiert."
fi

# ── Ziel-Benutzer ermitteln ──────────────────────────────────
TARGET_USER="${SUDO_USER:-$(logname 2>/dev/null || echo '')}"
if [[ -z "$TARGET_USER" || "$TARGET_USER" == "root" ]]; then
    read -rp "Benutzername: " TARGET_USER
fi
TARGET_HOME="/home/$TARGET_USER"
[[ ! -d "$TARGET_HOME" ]] && error "Home $TARGET_HOME nicht gefunden"

# ── Globale Variablen exportieren (werden von lib-Dateien gebraucht) ─
export TARGET_USER
export TARGET_HOME
export SCRIPT_DIR

# DKMS_HOOKS wird von base_system.sh deaktiviert und von theming_finishing.sh
# wiederhergestellt — als exportiertes Array übergeben.
export DKMS_HOOKS=(
    /etc/kernel/postinst.d/dkms
    /etc/kernel/prerm.d/dkms
    /usr/lib/kernel/install.d/50-dkms.install
)

# GPU- und Hardware-Flags — werden in kernel_drivers.sh gesetzt
# und von gaming_ai.sh sowie theming_finishing.sh gebraucht.
export HAS_NVIDIA=false
export HAS_AMD=false
export HAS_INTEL=false
export IS_LAPTOP=false

# Browser/Editor/FM — werden in browser_selection.sh bzw. theming_finishing.sh gesetzt
export DEFAULT_BROWSER_DESKTOP="firefox-esr.desktop"
export DEFAULT_EDITOR_DESKTOP="mousepad.desktop"
export DEFAULT_FM_DESKTOP="pcmanfm.desktop"

# ============================================================
#  Module laden — jedes sourced lib/utils.sh selbst nochmal,
#  das ist unschädlich da nur Variablen/Funktionen gesetzt werden.
# ============================================================

# Schritt 1 — System aktualisieren
source "$SCRIPT_DIR/lib/base_system.sh"

# Schritt 2 — Kernel, Treiber, GPU-Erkennung
# Setzt HAS_NVIDIA, HAS_AMD, HAS_INTEL, IS_LAPTOP
source "$SCRIPT_DIR/lib/kernel_drivers.sh"

# Schritt 3 — i3 Desktop-Umgebung
source "$SCRIPT_DIR/lib/desktop_environment.sh"

# Schritt 4 — Audio (PipeWire) + Kitty Terminal
source "$SCRIPT_DIR/lib/audio_terminal.sh"

# Schritt 5 — Standard-Apps (Dateimanager, Office, yt-dlp, ...)
source "$SCRIPT_DIR/lib/default_apps.sh"

# Schritt 6 — Browser-Auswahl
# Setzt DEFAULT_BROWSER_DESKTOP
source "$SCRIPT_DIR/lib/browser_selection.sh"

# Schritt 6b — Mesh-Modul (Reticulum P2P)
source "$SCRIPT_DIR/lib/mesh_module.sh"

# Schritt 7 + 7b — Steam/Gaming + Ollama
source "$SCRIPT_DIR/lib/gaming_ai.sh"

# Schritt 8 — Performance & Sicherheit
source "$SCRIPT_DIR/lib/performance_security.sh"

# Schritt 9 — Plymouth Boot-Screen
source "$SCRIPT_DIR/lib/boot_screen.sh"

# Schritt 10 — Theming, Configs, Finishing
# Braucht DEFAULT_BROWSER_DESKTOP, IS_LAPTOP, HAS_NVIDIA, DKMS_HOOKS
source "$SCRIPT_DIR/lib/theming_finishing.sh"

# Abschluss — Banner + Hinweis
source "$SCRIPT_DIR/lib/cleanup_final.sh"
