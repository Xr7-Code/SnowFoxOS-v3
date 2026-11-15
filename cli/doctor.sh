#!/bin/bash
# ============================================================
#  SnowFoxOS — CLI Module: System Diagnostics (Doctor)
#  Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)
# ============================================================

cmd_doctor() {
    local ISSUES=0
    local WARNINGS=0

    _doc_ok()   { echo -e "  ${GREEN}${BOLD}[  OK  ]${RESET} $1"; }
    _doc_warn() { echo -e "  ${ORANGE}${BOLD}[ WARN ]${RESET} $1"; ((WARNINGS++)); }
    _doc_err()  { echo -e "  ${RED}${BOLD}[FAILED]${RESET} $1"; ((ISSUES++)); }
    _doc_info() { echo -e "  ${CYAN}        ${RESET} $1"; }
    _doc_head() { echo ""; echo -e "${PURPLE}${BOLD}  ▸ $1${RESET}"; echo "  ──────────────────────────────────────────"; }

    divider
    echo -e "${PURPLE}${BOLD}  🦊 SnowFoxOS — Doctor${RESET}"
    echo -e "${GRAY}  Running system diagnostics...${RESET}"
    divider

    # ══════════════════════════════════════════════════════
    # 1. RAM analysis
    # ══════════════════════════════════════════════════════
    _doc_head "RAM Analysis"

    local RAM_TOTAL RAM_FREE RAM_USED RAM_PCT
    RAM_TOTAL=$(awk '/^MemTotal:/    {print int($2/1024)}' /proc/meminfo)
    RAM_FREE=$(awk  '/^MemAvailable:/{print int($2/1024)}' /proc/meminfo)
    RAM_USED=$((RAM_TOTAL - RAM_FREE))
    RAM_PCT=$(echo "scale=0; $RAM_USED * 100 / $RAM_TOTAL" | bc 2>/dev/null || echo "?")

    if [[ "$RAM_PCT" -ge 90 ]]; then
        _doc_err  "RAM usage critical: ${RAM_USED}MB / ${RAM_TOTAL}MB (${RAM_PCT}%)"
    elif [[ "$RAM_PCT" -ge 70 ]]; then
        _doc_warn "RAM usage high: ${RAM_USED}MB / ${RAM_TOTAL}MB (${RAM_PCT}%)"
    else
        _doc_ok   "RAM: ${RAM_USED}MB / ${RAM_TOTAL}MB (${RAM_PCT}% used)"
    fi

    # Swap
    local SWAP_TOTAL SWAP_FREE SWAP_USED
    SWAP_TOTAL=$(awk '/^SwapTotal:/{print int($2/1024)}' /proc/meminfo)
    SWAP_FREE=$(awk  '/^SwapFree:/ {print int($2/1024)}' /proc/meminfo)
    SWAP_USED=$((SWAP_TOTAL - SWAP_FREE))
    if [[ "$SWAP_TOTAL" -eq 0 ]]; then
        _doc_warn "No swap active — no buffer for RAM pressure"
    elif [[ "$SWAP_USED" -gt 0 ]]; then
        _doc_warn "Swap in use: ${SWAP_USED}MB — RAM may be tight"
    else
        _doc_ok   "Swap: ${SWAP_TOTAL}MB available, not in use"
    fi

    # zRAM
    if ls /dev/zram* &>/dev/null 2>&1; then
        _doc_ok   "zRAM active"
    else
        _doc_warn "zRAM not active — recommended for SnowFoxOS (lz4, 50%)"
        _doc_info "Enable: sudo systemctl enable --now systemd-zram-setup@zram0"
    fi

    # Top RAM consumers
    echo ""
    echo -e "  ${GRAY}  Top-5 RAM consumers:${RESET}"
    ps aux --sort=-%mem 2>/dev/null | awk 'NR>1 && NR<=6 {
        printf "    \033[0;36m%-22s\033[0m %5s%%  %s MB\n", $11, $4, int($6/1024)
    }'

    # ══════════════════════════════════════════════════════
    # 2. Largest installed packages
    # ══════════════════════════════════════════════════════
    _doc_head "Largest Installed Packages"

    if command -v dpkg-query &>/dev/null; then
        echo -e "  ${GRAY}  Top-10 by installed size:${RESET}"
        dpkg-query -W --showformat='${Installed-Size}\t${Package}\n' 2>/dev/null \
            | sort -rn | head -10 \
            | awk '{printf "    \033[0;36m%-40s\033[0m %s MB\n", $2, int($1/1024)}'
        _doc_ok "Package list analyzed"
    else
        _doc_warn "dpkg-query not found"
    fi

    # Orphaned packages
    local ORPHANS
    ORPHANS=$(deborphan 2>/dev/null | wc -l)
    if command -v deborphan &>/dev/null && [[ "$ORPHANS" -gt 0 ]]; then
        _doc_warn "${ORPHANS} orphaned packages — 'sudo deborphan | xargs apt purge -y'"
    elif command -v deborphan &>/dev/null; then
        _doc_ok   "No orphaned packages"
    fi

    # apt autoremove
    local AUTOREMOVE
    AUTOREMOVE=$(apt-get --simulate autoremove 2>/dev/null | grep "^Remv" | wc -l)
    if [[ "$AUTOREMOVE" -gt 0 ]]; then
        _doc_warn "${AUTOREMOVE} packages can be removed — 'sudo apt autoremove'"
    else
        _doc_ok   "No unnecessary packages"
    fi

    # ══════════════════════════════════════════════════════
    # 3. Driver check
    # ══════════════════════════════════════════════════════
    _doc_head "Drivers & Hardware"

    # Missing firmware (dmesg)
    local MISSING_FW
    MISSING_FW=$(dmesg 2>/dev/null | grep -i "firmware.*failed\|failed to load firmware\|Direct firmware load.*failed" | \
        grep -oP 'for \K[^\s]+' | sort -u)
    if [[ -n "$MISSING_FW" ]]; then
        _doc_err  "Missing firmware detected:"
        echo "$MISSING_FW" | while read -r fw; do
            _doc_info "→ $fw"
        done
        _doc_info "Fix: sudo apt install firmware-linux firmware-linux-nonfree"
    else
        _doc_ok   "No missing firmware in dmesg"
    fi

    # Graphics drivers
    _doc_head "Graphics Drivers"

    local GPU_INFO
    GPU_INFO=$(lspci 2>/dev/null | grep -iE "VGA|3D|Display")
    if [[ -z "$GPU_INFO" ]]; then
        _doc_warn "No GPU detected via lspci"
    else
        echo "$GPU_INFO" | while IFS= read -r line; do
            _doc_info "GPU: $line"
        done
    fi

    # NVIDIA
    if lspci 2>/dev/null | grep -qi nvidia; then
        if command -v nvidia-smi &>/dev/null; then
            local NV_VER
            NV_VER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1)
            _doc_ok   "NVIDIA driver installed (v${NV_VER})"
        else
            _doc_err  "NVIDIA GPU detected, but no driver installed"
            _doc_info "Fix: sudo apt install nvidia-driver"
        fi
    fi

    # AMD (exclude Intel false positives)
    local AMD_GPU
    AMD_GPU=$(lspci 2>/dev/null | grep -iE "AMD|ATI" | grep -iE "VGA|3D|Display" | grep -iv "Intel")
    if [[ -n "$AMD_GPU" ]]; then
        if lsmod 2>/dev/null | grep -qE "amdgpu|radeon"; then
            _doc_ok   "AMD driver (amdgpu/radeon) loaded"
        else
            _doc_warn "AMD GPU detected, but no kernel module loaded"
            _doc_info "  $AMD_GPU"
        fi
    fi

    # Intel
    if lspci 2>/dev/null | grep -qi "Intel.*Graphics\|Intel.*VGA"; then
        if lsmod 2>/dev/null | grep -q "i915"; then
            _doc_ok   "Intel i915 driver loaded"
        else
            _doc_warn "Intel GPU detected, but i915 not loaded"
        fi
    fi

    # VA-API
    if command -v vainfo &>/dev/null; then
        if vainfo &>/dev/null 2>&1; then
            _doc_ok   "VA-API (hardware video decode) available"
        else
            _doc_warn "VA-API not functional"
            _doc_info "Packages: intel-media-va-driver / mesa-va-drivers / nvidia-vaapi-driver"
        fi
    else
        _doc_warn "vainfo not installed — VA-API status unknown"
        _doc_info "Install: sudo apt install vainfo"
    fi

    # ══════════════════════════════════════════════════════
    # 4. i3 configuration
    # ══════════════════════════════════════════════════════
    _doc_head "i3 Configuration"

    local I3_CFG="$HOME/.config/i3/config"
    if [[ ! -f "$I3_CFG" ]]; then
        _doc_err  "i3 config not found: $I3_CFG"
    else
        # Syntax check
        if command -v i3 &>/dev/null; then
            local I3_ERR
            I3_ERR=$(i3 -C -c "$I3_CFG" 2>&1)
            if [[ -z "$I3_ERR" ]]; then
                _doc_ok   "i3 config syntax OK"
            else
                _doc_err  "Errors in i3 config:"
                echo "$I3_ERR" | while IFS= read -r line; do _doc_info "  $line"; done
            fi
        else
            _doc_warn "i3 not in PATH — syntax check skipped"
        fi

        # Missing exec binaries
        local AUTOSTART_MISSING=0
        while IFS= read -r line; do
            local BIN
            BIN=$(echo "$line" | sed 's/^exec[[:space:]]*//' \
                | sed 's/--no-startup-id[[:space:]]*//' \
                | awk '{print $1}')
            [[ -z "$BIN" ]] && continue
            BIN="${BIN/#\~/$HOME}"
            local BIN_BASE
            BIN_BASE=$(basename "$BIN")
            if command -v "$BIN_BASE" &>/dev/null; then
                continue
            elif [[ -x "$BIN" ]]; then
                continue
            elif [[ -x "$HOME/.config/$BIN_BASE" ]]; then
                continue
            else
                _doc_warn "Autostart binary not found: ${BIN_BASE}"
                ((AUTOSTART_MISSING++))
            fi
        done < <(grep "^exec " "$I3_CFG" 2>/dev/null)
        [[ $AUTOSTART_MISSING -eq 0 ]] && _doc_ok "Autostart entries verified"
    fi

    # Polybar
    local POLY_CFG="$HOME/.config/polybar/config.ini"
    [[ ! -f "$POLY_CFG" ]] && POLY_CFG="$HOME/.config/polybar/config"
    if [[ ! -f "$POLY_CFG" ]]; then
        _doc_warn "Polybar config not found"
    else
        _doc_ok   "Polybar config present"
        if ! pgrep -x polybar &>/dev/null; then
            _doc_warn "Polybar not running"
        else
            _doc_ok   "Polybar running"
        fi
    fi

    # Rofi
    local ROFI_CFG="$HOME/.config/rofi/config.rasi"
    if [[ ! -f "$ROFI_CFG" ]]; then
        _doc_warn "Rofi config not found: $ROFI_CFG"
    else
        _doc_ok   "Rofi config present"
    fi

    # Dunst
    local DUNST_CFG="$HOME/.config/dunst/dunstrc"
    if [[ ! -f "$DUNST_CFG" ]]; then
        _doc_warn "Dunst config not found: $DUNST_CFG"
    else
        _doc_ok   "Dunst config present"
        if ! pgrep -x dunst &>/dev/null; then
            _doc_warn "Dunst not running"
        else
            _doc_ok   "Dunst running"
        fi
    fi

    # Kitty
    local KITTY_CFG="$HOME/.config/kitty/kitty.conf"
    if [[ ! -f "$KITTY_CFG" ]]; then
        _doc_warn "Kitty config not found"
    else
        _doc_ok   "Kitty config present"
    fi

    # ══════════════════════════════════════════════════════
    # 5. Audio
    # ══════════════════════════════════════════════════════
    _doc_head "Audio (PipeWire)"

    if systemctl --user is-active pipewire &>/dev/null; then
        _doc_ok   "PipeWire running"
    else
        _doc_err  "PipeWire not running"
        _doc_info "Start: systemctl --user start pipewire pipewire-pulse wireplumber"
    fi

    if systemctl --user is-active wireplumber &>/dev/null; then
        _doc_ok   "WirePlumber running"
    else
        _doc_warn "WirePlumber not running"
    fi

    if command -v pactl &>/dev/null; then
        local SINK_COUNT
        SINK_COUNT=$(pactl list sinks short 2>/dev/null | wc -l)
        if [[ "$SINK_COUNT" -eq 0 ]]; then
            _doc_warn "No audio output devices detected"
        else
            _doc_ok   "${SINK_COUNT} audio output device(s) detected"
        fi
    fi

    # ══════════════════════════════════════════════════════
    # 6. Network & systemd services
    # ══════════════════════════════════════════════════════
    _doc_head "Systemd Services"

    if systemctl is-active NetworkManager &>/dev/null; then
        _doc_ok   "NetworkManager running"
    else
        _doc_err  "NetworkManager not running"
        _doc_info "Start: sudo systemctl start NetworkManager"
    fi

    if systemctl is-active bluetooth &>/dev/null; then
        _doc_ok   "Bluetooth service running"
    else
        _doc_warn "Bluetooth service not running"
    fi

    # Failed services
    local FAILED
    FAILED=$(systemctl --failed --no-legend 2>/dev/null | awk '{print $1}' | head -5)
    if [[ -n "$FAILED" ]]; then
        _doc_err  "Failed systemd services:"
        echo "$FAILED" | while read -r svc; do _doc_info "→ $svc"; done
        _doc_info "Details: systemctl status <service>"
    else
        _doc_ok   "No failed services"
    fi

    # ══════════════════════════════════════════════════════
    # 7. Disk & filesystem
    # ══════════════════════════════════════════════════════
    _doc_head "Disk & Filesystem"

    local DISK_PCT DISK_FREE
    DISK_PCT=$(df / | awk 'NR==2 {gsub(/%/,"",$5); print $5}')
    DISK_FREE=$(df -h / | awk 'NR==2 {print $4}')
    if [[ "$DISK_PCT" -ge 90 ]]; then
        _doc_err  "Disk almost full: ${DISK_PCT}% used (${DISK_FREE} free)"
    elif [[ "$DISK_PCT" -ge 75 ]]; then
        _doc_warn "Disk: ${DISK_PCT}% used (${DISK_FREE} free)"
    else
        _doc_ok   "Disk: ${DISK_PCT}% used (${DISK_FREE} free)"
    fi

    # /tmp
    local TMP_SIZE
    TMP_SIZE=$(du -sh /tmp 2>/dev/null | awk '{print $1}')
    _doc_info "/tmp usage: ${TMP_SIZE}"

    # Journald size
    local JOURNAL_SIZE
    JOURNAL_SIZE=$(journalctl --disk-usage 2>/dev/null | grep -oP '\d+\.\d+[MG]' | head -1)
    if [[ -n "$JOURNAL_SIZE" ]]; then
        _doc_info "Journal size: ${JOURNAL_SIZE} — 'sudo journalctl --vacuum-size=200M' to clean up"
    fi

    # ══════════════════════════════════════════════════════
    # 8. Security & privacy
    # ══════════════════════════════════════════════════════
    _doc_head "Security & Privacy"

    # Firewall
    if command -v ufw &>/dev/null || dpkg -l ufw &>/dev/null 2>&1; then
        local UFW_STATUS
        UFW_STATUS=$(sudo ufw status 2>/dev/null | grep "Status:" | awk '{print $2}')
        if [[ "$UFW_STATUS" == "active" ]]; then
            _doc_ok   "UFW firewall active"
        else
            _doc_warn "UFW firewall inactive — 'sudo ufw enable'"
        fi
    else
        _doc_warn "UFW not installed — 'sudo apt install ufw'"
    fi

    # SSH service
    if systemctl is-active ssh &>/dev/null || systemctl is-active sshd &>/dev/null; then
        _doc_warn "SSH service running — disable if not needed"
        _doc_info "Disable: sudo systemctl disable --now ssh"
    else
        _doc_ok   "SSH service not active"
    fi

    # Pending security updates
    local SECURITY_UPDATES
    SECURITY_UPDATES=$(apt-get --simulate upgrade 2>/dev/null | grep -i "security" | wc -l)
    if [[ "$SECURITY_UPDATES" -gt 0 ]]; then
        _doc_warn "${SECURITY_UPDATES} security updates available — 'snowfox up'"
    else
        _doc_ok   "No pending security updates"
    fi

    # ══════════════════════════════════════════════════════
    # 9. SnowFoxOS-specific checks
    # ══════════════════════════════════════════════════════
    _doc_head "SnowFoxOS Integrity"

    # CLI itself
    if [[ -x /usr/local/bin/snowfox ]]; then
        _doc_ok   "snowfox CLI installed in /usr/local/bin"
    else
        _doc_warn "snowfox CLI not in /usr/local/bin — only runnable locally"
    fi

    # Profile file
    local PROFILE
    PROFILE=$(cat "$HOME/.config/snowfox/profile" 2>/dev/null || echo "")
    if [[ -n "$PROFILE" ]]; then
        _doc_ok   "Active profile: ${PROFILE}"
    else
        _doc_warn "No profile set — default 'balanced' will be used"
    fi

    # Wallpaper directory
    if [[ -d "$HOME/Pictures/wallpapers" ]] || \
       [[ -d "$HOME/wallpapers" ]] || \
       [[ -d "$HOME/.config/wallpapers" ]] || \
       ls "$HOME"/*.{jpg,jpeg,png,webp} &>/dev/null 2>&1; then
        _doc_ok   "Wallpaper directory present"
    else
        _doc_warn "Wallpaper directory missing"
    fi

    # Required tools
    for tool in git curl gpg pactl rfkill yt-dlp mpv; do
        if command -v "$tool" &>/dev/null; then
            _doc_ok   "$tool available"
        else
            _doc_warn "$tool not installed"
        fi
    done

    # ══════════════════════════════════════════════════════
    # Summary
    # ══════════════════════════════════════════════════════
    echo ""
    divider
    section "Diagnostics complete"
    if [[ "$ISSUES" -eq 0 && "$WARNINGS" -eq 0 ]]; then
        echo -e "  ${GREEN}${BOLD}✓ System is in perfect condition.${RESET}"
    else
        [[ "$ISSUES"   -gt 0 ]] && echo -e "  ${RED}${BOLD}✗ Errors:   ${ISSUES}${RESET}"
        [[ "$WARNINGS" -gt 0 ]] && echo -e "  ${ORANGE}${BOLD}⚠ Warnings: ${WARNINGS}${RESET}"
    fi
    divider
}
