#!/bin/bash
# ============================================================
#  SnowFoxOS — CLI Module: Security (Network Audit)
#  Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)
# ============================================================

# ============================================================
# snowfox audit — Active network connections
# ============================================================
cmd_audit() {
    case "$1" in
        live|ongoing|l)
            _audit_live
            ;;
        ""|once|snapshot)
            _audit_snapshot
            ;;
        *)
            err "Usage: snowfox audit [live]"
            exit 1
            ;;
    esac
}

# ─── One-shot snapshot ───────────────────────────────────────
_audit_snapshot() {
    header "Network Audit"

    if ! command -v ss &>/dev/null; then
        err "ss not found — install iproute2"
        exit 1
    fi

    local has_root=false
    [[ $EUID -eq 0 ]] && has_root=true

    if ! $has_root; then
        info "Running without root — some process names may be hidden."
        info "For full output: sudo snowfox audit"
        echo ""
    fi

    divider
    printf "  ${BOLD}%-24s %-6s %s${RESET}\n" "Process" "Proto" "Destination"
    divider

    local count=0
    while IFS= read -r line; do
        local PROTO REMOTE PROC IP IP_COLOR

        PROTO=$(echo "$line" | awk '{print $1}')
        REMOTE=$(echo "$line" | awk '{print $6}')
        PROC=$(echo "$line" | grep -oP 'users:\(\("\K[^"]+' || echo "unknown")

        # Skip empty / listening on all interfaces
        [[ "$REMOTE" == "*" || "$REMOTE" == "0.0.0.0:*" || -z "$REMOTE" ]] && continue

        IP=$(echo "$REMOTE" | sed 's/:[0-9]*$//' | tr -d '[]')

        # Color code: local networks gray, external orange
        if echo "$IP" | grep -qE '^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.|127\.|::1|fe80)'; then
            IP_COLOR="${GRAY}"
        else
            IP_COLOR="${ORANGE}"
        fi

        printf "  ${CYAN}%-24s${RESET} %-6s ${IP_COLOR}%s${RESET}\n" "$PROC" "$PROTO" "$IP"
        ((count++))
    done < <(ss -tunp 2>/dev/null | tail -n +2)

    divider

    if [[ $count -eq 0 ]]; then
        info "No active connections."
    else
        info "$count active connection(s)."
    fi
    echo ""
}

# ─── Live mode (Ctrl+C to exit) ──────────────────────────────
_audit_live() {
    if ! command -v ss &>/dev/null; then
        err "ss not found — install iproute2"
        exit 1
    fi

    if ! command -v watch &>/dev/null; then
        err "watch not found — install procps"
        exit 1
    fi

    info "Live audit — press Ctrl+C to exit."
    sleep 1

    watch -n 2 -t \
        'ss -tunp 2>/dev/null | tail -n +2 | grep -vE "^(udp|tcp).*\*" || echo "  No active connections."'
}
