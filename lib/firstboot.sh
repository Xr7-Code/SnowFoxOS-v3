#!/usr/bin/env bash
# ============================================================
#  SnowFoxOS v4 — First-boot completion (ISO installs)
#  Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)
# ============================================================
#  Runs on the installed system, after network-online.target.
#  Completes everything that needs a live systemd/user session.
# ============================================================

source "$SCRIPT_DIR/lib/utils.sh"

step "First-boot completion"

FIRSTBOOT_FAILED=false
USER_UID="$(id -u "$TARGET_USER" 2>/dev/null || true)"
USER_RUNTIME="/run/user/${USER_UID:-0}"

# ── 0. DNS: hand /etc/resolv.conf to systemd-resolved ──────
if systemctl is-enabled systemd-resolved >/dev/null 2>&1 || \
   systemctl is-active systemd-resolved >/dev/null 2>&1; then
    systemctl enable --now systemd-resolved >/dev/null 2>&1 || true
    if [[ -e /run/systemd/resolve/stub-resolv.conf ]]; then
        ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
        success "DNS handed over to systemd-resolved"
    fi
fi

# ── 0a. Clear stale offline flag ───────────────────────────
if [[ -f /var/lib/snowfox/net-offline ]]; then
    if timeout 10 bash -c 'exec 3<>/dev/tcp/deb.debian.org/80' 2>/dev/null; then
        rm -f /var/lib/snowfox/net-offline
        success "Network available — stale offline flag cleared"
    else
        warn "Still offline — GPU/extras stay deferred"
    fi
fi

# ── 0b. AIDE baseline ─────────────────────────────────────
if command -v aideinit >/dev/null 2>&1; then
    if [[ ! -f /var/lib/aide/aide.db ]]; then
        info "Initialising deferred AIDE baseline..."
        if aideinit -y -f >/dev/null 2>&1 && [[ -f /var/lib/aide/aide.db.new ]]; then
            mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
            chmod 0600 /var/lib/aide/aide.db
            success "AIDE baseline initialised"
        else
            warn "AIDE baseline not initialised — run 'sudo aideinit' later"
        fi
    fi
fi

# ── 1. Deferred GPU/kernel phase ──────────────────────────
if [[ -f /var/lib/snowfox/firstboot-pending ]]; then
    info "First-boot marker found — retrying kernel/GPU phase..."
    if bash "$SCRIPT_DIR/install.sh" --phase iso-gpu; then
        success "Kernel/GPU phase completed on first boot"
        rm -f /var/lib/snowfox/firstboot-pending
    else
        rc=$?
        warn "Kernel/GPU phase still failing (exit $rc) — will retry on next boot"
        FIRSTBOOT_FAILED=true
    fi
fi

# ── 2. User session bits ──────────────────────────────────
if [[ -n "$USER_UID" ]]; then
    loginctl enable-linger "$TARGET_USER" 2>/dev/null || true

    if [[ -d "$USER_RUNTIME" ]]; then
        sudo -u "$TARGET_USER" env \
            HOME="$TARGET_HOME" \
            XDG_RUNTIME_DIR="$USER_RUNTIME" \
            DBUS_SESSION_BUS_ADDRESS="unix:path=${USER_RUNTIME}/bus" \
            gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' \
            2>/dev/null || true
        sudo -u "$TARGET_USER" env \
            HOME="$TARGET_HOME" \
            XDG_RUNTIME_DIR="$USER_RUNTIME" \
            DBUS_SESSION_BUS_ADDRESS="unix:path=${USER_RUNTIME}/bus" \
            gsettings set org.gnome.desktop.interface gtk-theme 'Arc-Dark' \
            2>/dev/null || true
        sudo -u "$TARGET_USER" env \
            HOME="$TARGET_HOME" \
            XDG_RUNTIME_DIR="$USER_RUNTIME" \
            DBUS_SESSION_BUS_ADDRESS="unix:path=${USER_RUNTIME}/bus" \
            systemctl --user mask xdg-desktop-portal-gnome.service \
            2>/dev/null || true
    else
        info "No active user runtime yet — session settings will apply on login"
    fi

    sudo -u "$TARGET_USER" xdg-user-dirs-update 2>/dev/null || \
        warn "xdg-user-dirs-update failed — run it once as $TARGET_USER"
else
    warn "User $TARGET_USER has no UID — skipping session setup"
fi

# ── 3. Font cache ─────────────────────────────────────────
fc-cache -f 2>/dev/null || true

# ── 4. Re-apply saved theme ───────────────────────────────
if [[ -f "$TARGET_HOME/.config/snowfox/theme" ]]; then
    SAVED_THEME="$(head -n1 "$TARGET_HOME/.config/snowfox/theme" | tr -d '[:space:]')"
    if [[ -n "$SAVED_THEME" && -x /usr/local/bin/snowfox ]]; then
        sudo -u "$TARGET_USER" env \
            HOME="$TARGET_HOME" \
            XDG_CONFIG_HOME="$TARGET_HOME/.config" \
            XDG_RUNTIME_DIR="$USER_RUNTIME" \
            DBUS_SESSION_BUS_ADDRESS="unix:path=${USER_RUNTIME}/bus" \
            /usr/local/bin/snowfox theme "$SAVED_THEME" &>/dev/null \
            && success "Color theme re-applied: $SAVED_THEME" \
            || warn "Could not re-apply color theme"
    fi
fi

# ── 5. Final self-check ───────────────────────────────────
if command -v snowfox >/dev/null 2>&1; then
    timeout 30 snowfox status >/dev/null 2>&1 \
        && success "snowfox status works" \
        || warn "snowfox status returned an error — check: snowfox doctor"
fi

if $FIRSTBOOT_FAILED; then
    warn "First-boot completion incomplete — service keeps retrying"
    exit 1
fi

success "First-boot completion finished"
