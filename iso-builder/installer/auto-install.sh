#!/bin/bash
# ============================================================
#  SnowFoxOS v3 — Auto-Install Wrapper
#  Runs on first boot of the installed system.
#  Overrides all interactive prompts in install.sh with
#  sensible defaults, then calls install.sh unattended.
#
#  Usage: sudo bash snowfox-auto-install <username>
#  Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)
# ============================================================

set -euo pipefail

PURPLE='\033[0;35m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
RED='\033[0;31m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${PURPLE}${BOLD}[SnowFox]${RESET} $1"; }
success() { echo -e "${GREEN}${BOLD}[  OK  ]${RESET} $1"; }
warn()    { echo -e "${ORANGE}${BOLD}[ WARN ]${RESET} $1"; }
error()   { echo -e "${RED}${BOLD}[FAILED]${RESET} $1"; exit 1; }

# ── Arguments ────────────────────────────────────────────────
TARGET_USER="${1:-}"
[[ -z "$TARGET_USER" ]] && error "Usage: sudo bash snowfox-auto-install <username>"
[[ $EUID -ne 0 ]]       && error "Must run as root"

TARGET_HOME="/home/$TARGET_USER"
[[ ! -d "$TARGET_HOME" ]] && error "Home directory not found: $TARGET_HOME"

REPO_DIR="$TARGET_HOME/SnowFoxOS-v3"
[[ ! -f "$REPO_DIR/install.sh" ]] && error "install.sh not found in $REPO_DIR"

# ── Wait for network ─────────────────────────────────────────
info "Waiting for network..."
for i in $(seq 1 30); do
    if curl -sf --max-time 3 https://deb.debian.org > /dev/null 2>&1; then
        success "Network ready"
        break
    fi
    [[ $i -eq 30 ]] && warn "No network after 60s — some components may fail"
    sleep 2
done

# ── Override interactive functions ───────────────────────────
# We patch ask_install() and all read prompts by exporting
# a modified utils.sh that always returns "yes" for our
# chosen defaults and "no" for everything else.
#
# Defaults enabled:
#   - Zen Browser
#   - PCManFM (file manager)
#   - Geany (editor)
#   - Reticulum mesh module
#   - SnowFox Console Launcher
#   - bluetui
#
# Defaults disabled:
#   - Steam (user installs via snowfox stash)
#   - Ollama (user installs via snowfox stash)
#   - GIMP, VLC, VSCodium, OnlyOffice

export SNOWFOX_UNATTENDED=1

# ── Patch utils.sh for unattended mode ───────────────────────
# We write a wrapper that sources the original utils.sh
# and then overrides ask_install() and read.

PATCHED_UTILS="$(mktemp /tmp/snowfox-utils-XXXXXX.sh)"
cat > "$PATCHED_UTILS" << 'UTILEOF'
#!/bin/bash
# Patched utils.sh for unattended ISO install

PURPLE='\033[0;35m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
GRAY='\033[0;37m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${PURPLE}${BOLD}[SnowFox]${RESET} $1"; }
success() { echo -e "${GREEN}${BOLD}[  OK  ]${RESET} $1"; }
warn()    { echo -e "${ORANGE}${BOLD}[ WARN ]${RESET} $1"; }
error()   { echo -e "${RED}${BOLD}[FAILED]${RESET} $1"; exit 1; }

step() {
    echo -e "\n${PURPLE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${PURPLE}${BOLD}  $1${RESET}"
    echo -e "${PURPLE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
}

wait_apt() {
    local i=0
    while fuser /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock > /dev/null 2>&1; do
        [[ $i -eq 0 ]] && info "Waiting for apt lock..."
        sleep 2; i=$((i+1))
        [[ $i -gt 60 ]] && error "apt lock not released after 120s"
    done
}

# ── Unattended ask_install ────────────────────────────────────
# Returns 0 (yes) for enabled defaults, 1 (no) for everything else.
ask_install() {
    local pkg="$1"
    local pkg_lower
    pkg_lower=$(echo "$pkg" | tr '[:upper:]' '[:lower:]')

    # Enabled defaults
    case "$pkg_lower" in
        *zen*browser*)
            info "Auto-selecting: $pkg [default: YES]"
            return 0 ;;
        *pcmanfm*|*file\ manager*|*file-manager*)
            info "Auto-selecting: $pkg [default: YES]"
            return 0 ;;
        *geany*)
            info "Auto-selecting: $pkg [default: YES]"
            return 0 ;;
        *reticulum*|*mesh*)
            info "Auto-selecting: $pkg [default: YES]"
            return 0 ;;
        *console\ launcher*|*snowfox\ console*)
            info "Auto-selecting: $pkg [default: YES]"
            return 0 ;;
        *bluetui*|*bluetooth\ terminal*)
            info "Auto-selecting: $pkg [default: YES]"
            return 0 ;;
    esac

    # Everything else: skip
    info "Auto-skipping: $pkg [default: NO]"
    return 1
}
UTILEOF

# ── Patch read prompts via environment overrides ──────────────
# For the few remaining read -rp prompts in lib files:
# browser_selection.sh  → choice "1" (Zen Browser)
# default_apps.sh       → FM choice "1" (PCManFM), editor choice "1" (Geany)
# theming_finishing.sh  → editor choice "1" (Geany)
#
# We do this by replacing the lib/utils.sh symlink before running install.sh.

LIB_UTILS="$REPO_DIR/lib/utils.sh"
LIB_UTILS_BAK="$REPO_DIR/lib/utils.sh.iso-bak"

cp "$LIB_UTILS" "$LIB_UTILS_BAK"
cp "$PATCHED_UTILS" "$LIB_UTILS"
rm -f "$PATCHED_UTILS"

# ── Patch read prompts via stdin substitution ─────────────────
# We pipe pre-filled answers to all remaining read prompts.
# Order matches the prompts in install.sh lib files:
#   1. browser_selection.sh : browser choice       → "1" (Zen)
#   2. default_apps.sh      : file manager choice  → "1" (PCManFM)
#   3. theming_finishing.sh : default editor choice → "1" (Geany)

ANSWERS_FILE="$(mktemp /tmp/snowfox-answers-XXXXXX)"
cat > "$ANSWERS_FILE" << 'ANSEOF'
1
1
1
ANSEOF

# ── Run install.sh ────────────────────────────────────────────
info "Starting SnowFoxOS installation for user: $TARGET_USER"
info "All prompts answered automatically with defaults."
echo ""

SUDO_USER="$TARGET_USER" \
    bash "$REPO_DIR/install.sh" < "$ANSWERS_FILE"

INSTALL_EXIT=$?

# ── Restore utils.sh ─────────────────────────────────────────
cp "$LIB_UTILS_BAK" "$LIB_UTILS"
rm -f "$LIB_UTILS_BAK" "$ANSWERS_FILE"

# ── Disable firstboot service (don't run again) ───────────────
systemctl disable snowfox-firstboot.service 2>/dev/null || true

if [[ $INSTALL_EXIT -eq 0 ]]; then
    success "SnowFoxOS installation complete!"
    info "Rebooting in 5 seconds..."
    sleep 5
    reboot
else
    error "Installation failed with exit code $INSTALL_EXIT"
    info "Check /var/log for details."
    info "You can retry manually: sudo bash ~/SnowFoxOS-v3/install.sh"
fi
