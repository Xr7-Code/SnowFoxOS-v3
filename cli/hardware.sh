#!/usr/bin/env bash
# ============================================================
#  SnowFoxOS v4 — CLI: hardware
#  gpu / kill / air
# ============================================================

if [[ -n "${_SNOWFOX_CLI_HARDWARE_LOADED:-}" ]]; then return 0 2>/dev/null || true; fi
_SNOWFOX_CLI_HARDWARE_LOADED=1

cmd_gpu() {
    header "snowfox gpu"
    if ! command -v lspci >/dev/null 2>&1; then
        err "lspci not found"
        return "$SNOWFOX_EXIT_ERROR"
    fi
    local gpu
    gpu=$(lspci 2>/dev/null | grep -iE 'vga|3d|display')
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        row "GPU" "$line"
    done <<< "$gpu"
}

cmd_kill() {
    local what="${1:-}"
    case "$what" in
        mic)     _kill_device mic ;;
        cam)     _kill_device cam ;;
        all)     _kill_device mic; _kill_device cam ;;
        restore) _restore_devices ;;
        ""|status)
            header "snowfox kill"
            local mic cam
            mic=$(lsmod | grep -q '^snd_usb_audio' && echo on || echo blocked)
            cam=$(lsmod | grep -qE '^(uvcvideo|gspca)' && echo on || echo blocked)
            row_dot "Microphone" "$([[ $mic == on ]] && echo ok || echo err)" "$mic"
            row_dot "Webcam"     "$([[ $cam == on ]] && echo ok || echo err)" "$cam"
            ;;
        *) err "usage: snowfox kill <mic|cam|all|restore>"; return "$SNOWFOX_EXIT_ERROR" ;;
    esac
}

_kill_device() {
    local kind="$1"
    case "$kind" in
        mic) modprobe -r snd_usb_audio 2>/dev/null || true
             echo "install snd_usb_audio /bin/false" > /etc/modprobe.d/snowfox-kill-mic.conf
             ok "microphone disabled" ;;
        cam) modprobe -r uvcvideo 2>/dev/null || true
             echo "install uvcvideo /bin/false" > /etc/modprobe.d/snowfox-kill-cam.conf
             ok "webcam disabled" ;;
    esac
}

_restore_devices() {
    rm -f /etc/modprobe.d/snowfox-kill-mic.conf \
          /etc/modprobe.d/snowfox-kill-cam.conf
    modprobe snd_usb_audio 2>/dev/null || true
    modprobe uvcvideo      2>/dev/null || true
    ok "devices restored"
}

cmd_air() {
    local mode="${1:-status}"
    case "$mode" in
        on)  rfkill block all 2>/dev/null && ok "wireless off" || { err "rfkill failed"; return "$SNOWFOX_EXIT_ERROR"; } ;;
        off) rfkill unblock all 2>/dev/null && ok "wireless on"  || { err "rfkill failed"; return "$SNOWFOX_EXIT_ERROR"; } ;;
        status|"")
            header "snowfox air"
            if command -v rfkill >/dev/null 2>&1; then
                rfkill list 2>/dev/null | while IFS= read -r l; do row "rfkill" "$l"; done
            else
                info "rfkill not installed"
            fi
            ;;
        *) err "usage: snowfox air <on|off|status>"; return "$SNOWFOX_EXIT_ERROR" ;;
    esac
}
