#!/usr/bin/env bash
# ============================================================
#  SnowFoxOS v4 — CLI: security (network audit)
#  (v3 hardened parser, v4 design system)
# ============================================================

if [[ -n "${_SNOWFOX_CLI_SECURITY_LOADED:-}" ]]; then return 0 2>/dev/null || true; fi
_SNOWFOX_CLI_SECURITY_LOADED=1

export PATH="/usr/sbin:/usr/bin:/sbin:/bin"
unset SHELL 2>/dev/null || true
unset LD_PRELOAD LD_LIBRARY_PATH 2>/dev/null || true

readonly SS_BIN="/usr/sbin/ss"
readonly TIMEOUT_BIN="/usr/bin/timeout"
readonly AWK_BIN="/usr/bin/awk"
readonly GREP_BIN="/usr/bin/grep"
readonly TR_BIN="/usr/bin/tr"
readonly SED_BIN="/usr/bin/sed"
readonly SLEEP_BIN="/usr/bin/sleep"

[[ -x "$SS_BIN" ]]      || SS_BIN="/bin/ss"
[[ -x "$TIMEOUT_BIN" ]] || TIMEOUT_BIN="/bin/timeout"
[[ -x "$AWK_BIN" ]]     || AWK_BIN="/usr/bin/gawk"
[[ -x "$AWK_BIN" ]]     || AWK_BIN="/bin/awk"
[[ -x "$GREP_BIN" ]]    || GREP_BIN="/bin/grep"
[[ -x "$TR_BIN" ]]      || TR_BIN="/bin/tr"
[[ -x "$SED_BIN" ]]     || SED_BIN="/bin/sed"
[[ -x "$SLEEP_BIN" ]]   || SLEEP_BIN="/bin/sleep"

readonly SS_TIMEOUT=10

cmd_audit() {
    case "${1:-}" in
        live|ongoing|l) _audit_live; return $? ;;
        ""|once|snapshot) _audit_snapshot; return $? ;;
        -h|--help|help) _audit_usage; return 0 ;;
        *) err "unknown audit mode: $1"; _audit_usage; return "$SNOWFOX_EXIT_ERROR" ;;
    esac
}

_audit_usage() {
    cat <<'EOF'
Usage: snowfox audit [mode]

Modes:
  (none) | once | snapshot   One-shot snapshot of active connections
  live | ongoing | l         Live refresh (Ctrl+C to exit)
  help                       Show this help
EOF
}

_audit_preflight() {
    if [[ ! -x "$SS_BIN" ]]; then
        err "ss not found at $SS_BIN — install iproute2"
        return 1
    fi
    if ! "$SS_BIN" -h >/dev/null 2>&1; then
        err "ss is not executable or broken: $SS_BIN"
        return 1
    fi
    return 0
}

_audit_can_see_processes() {
    local out
    out=$("$TIMEOUT_BIN" "$SS_TIMEOUT" "$SS_BIN" -tunpH 2>/dev/null) || return 1
    [[ -n "$out" ]] || return 1
    printf '%s\n' "$out" | "$GREP_BIN" -q 'users:('
}

_audit_parse_line() {
    local line="$1"
    local netid state recvq sendq local_addr peer_addr proc_field
    local proc ip

    _p_proto=""
    _p_remote=""
    _p_proc=""

    read -r netid state recvq sendq local_addr peer_addr proc_field <<< "$line"

    _p_proto="$netid"
    _p_remote="$peer_addr"

    [[ -z "$_p_remote" ]] && return 1
    [[ "$_p_remote" == "*" || "$_p_remote" == "*:*" ]] && return 1
    [[ "$_p_remote" == "0.0.0.0:*" ]] && return 1
    [[ "$_p_remote" == "[::]:*" ]] && return 1

    if [[ -n "$proc_field" ]]; then
        proc_field=$("$TR_BIN" -cd '[:print:]' <<< "$proc_field")
        proc=$("$GREP_BIN" -oP 'users:\(\(\("\K[^"]+' <<< "$proc_field" 2>/dev/null \
               | "$AWK_BIN" '!seen[$0]++' \
               | "$AWK_BIN" 'BEGIN{sep=""} {printf "%s%s", sep, $0; sep=","}')
    fi
    [[ -z "$proc" ]] && proc="unknown"

    _p_proc="$proc"

    ip=$(printf '%s' "$_p_remote" \
         | "$SED_BIN" -E 's/^\[([^]]+)\]:[0-9]+$/\1/; s/^([^:]+):[0-9]+$/\1/')
    _p_remote="$ip"

    return 0
}

_audit_classify_ip() {
    local ip="$1"
    if printf '%s' "$ip" | "$GREP_BIN" -qE '^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.|127\.|169\.254\.|::1|fe80:|fc|fd)'; then
        _p_color="$FG_DIM"
    else
        _p_color="$YELLOW"
    fi
}

_audit_render_row() {
    local proc="$1" proto="$2" ip="$3" color="$4"
    printf "  %s%-24s%s %-6s %s%s%s\n" "$ACCENT" "$proc" "$RESET" "$proto" "$color" "$ip" "$RESET"
}

_audit_render_snapshot_body() {
    local ss_out="$1"
    local line count=0
    _p_count=0

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        _audit_parse_line "$line" || continue
        _audit_classify_ip "$_p_remote"
        _audit_render_row "$_p_proc" "$_p_proto" "$_p_remote" "$_p_color"
        count=$((count + 1))
    done <<< "$ss_out"

    _p_count=$count
}

_audit_snapshot() {
    header "snowfox audit"

    _audit_preflight || return 1

    if ! _audit_can_see_processes; then
        info "Process names are not visible (need root or CAP_NET_ADMIN)."
        info "For full output: sudo snowfox audit"
        echo ""
    fi

    divider
    printf "  %s%-24s %-6s %s%s\n" "$BOLD" "Process" "Proto" "Destination" "$RESET"
    divider

    local ss_out ss_rc
    ss_out=$("$TIMEOUT_BIN" "$SS_TIMEOUT" "$SS_BIN" -tunpH 2>/dev/null)
    ss_rc=$?

    if [[ $ss_rc -ne 0 ]]; then
        divider
        err "ss failed (exit $ss_rc) — cannot audit connections."
        err "Try: sudo snowfox audit"
        echo ""
        return 1
    fi

    _audit_render_snapshot_body "$ss_out"
    divider

    if [[ $_p_count -eq 0 ]]; then
        info "No active connections."
    else
        info "$_p_count active connection(s)."
    fi
    echo ""
    return 0
}

_audit_live() {
    _audit_preflight || return 1

    if ! _audit_can_see_processes; then
        info "Process names are not visible (need root or CAP_NET_ADMIN)."
        info "For full output: sudo snowfox audit live"
        echo ""
    fi

    info "Live audit — press Ctrl+C to exit."
    "$SLEEP_BIN" 1

    local _prev_int _prev_term _prev_exit
    _prev_int=$(trap -p INT)
    _prev_term=$(trap -p TERM)
    _prev_exit=$(trap -p EXIT)

    _audit_live_cleanup() {
        printf '\033[?25h\033[?1049l'
    }

    printf '\033[?1049h\033[?25l'
    trap '_audit_live_cleanup; return 0' INT TERM EXIT

    local ss_out ss_rc line
    while true; do
        printf '\033[H\033[2J'
        printf "  %sSnowFoxOS Network Audit — live (Ctrl+C to exit)%s\n" "$BOLD" "$RESET"
        divider
        printf "  %s%-24s %-6s %s%s\n" "$BOLD" "Process" "Proto" "Destination" "$RESET"
        divider

        ss_out=$("$TIMEOUT_BIN" "$SS_TIMEOUT" "$SS_BIN" -tunpH 2>/dev/null)
        ss_rc=$?

        if [[ $ss_rc -ne 0 ]]; then
            err "ss failed (exit $ss_rc) — cannot audit."
        elif [[ -z "$ss_out" ]]; then
            info "No active connections."
        else
            local live_count=0
            while IFS= read -r line; do
                [[ -z "$line" ]] && continue
                _audit_parse_line "$line" || continue
                _audit_classify_ip "$_p_remote"
                _audit_render_row "$_p_proc" "$_p_proto" "$_p_remote" "$_p_color"
                live_count=$((live_count + 1))
            done <<< "$ss_out"

            divider
            info "$live_count active connection(s)."
        fi

        "$SLEEP_BIN" 2
    done

    eval "${_prev_int:-trap - INT}"
    eval "${_prev_term:-trap - TERM}"
    eval "${_prev_exit:-trap - EXIT}"
}
