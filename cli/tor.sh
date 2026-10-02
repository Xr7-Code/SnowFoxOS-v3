#!/bin/bash
# ============================================================
#  SnowFoxOS — CLI Module: Tor (Transparent Proxy)
#  Routes all network traffic through Tor via iptables.
#  Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)
# ============================================================

readonly TOR_TRANS_PORT="9040"
readonly TOR_DNS_PORT="5353"
readonly TOR_SOCKS_PORT="9050"
readonly TOR_CONFIG_DIR="/etc/tor"
readonly TORRC="${TOR_CONFIG_DIR}/torrc"
readonly TOR_SERVICE="tor"
readonly SNOWFOX_CONFIG_DIR="${HOME}/.config/snowfox"
readonly TOR_MODE_FILE="${SNOWFOX_CONFIG_DIR}/tor-mode"
readonly RESOLV_BAK="/etc/resolv.conf.snowfox-bak"
readonly IPTABLES_SAVE="/etc/iptables.snowfox-tor.rules"
readonly IPTABLES_SAVE_IP6="/etc/ip6tables.snowfox-tor.rules"

# ─── Helper: Tor UID ─────────────────────────────────────────
_tor_get_uid() {
    local uid
    uid=$(id -ur debian-tor 2>/dev/null) || uid=$(id -ur tor 2>/dev/null)
    echo "$uid"
}

# ─── Helper: Dependencies ────────────────────────────────────
_tor_check_deps() {
    local missing=()
    local deps=(tor iptables ip6tables torsocks curl)
    
    for dep in "${deps[@]}"; do
        command -v "$dep" &>/dev/null || missing+=("$dep")
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        warn "Missing packages: ${missing[*]}"
        info "Install with: sudo apt-get install -y ${missing[*]}"
        return 1
    fi
    return 0
}

# ─── Helper: Service check ───────────────────────────────────
_tor_service_running() {
    systemctl is-active --quiet "$TOR_SERVICE" 2>/dev/null
}

# ─── Helper: Port check ──────────────────────────────────────
_tor_port_open() {
    local port="$1"
    ss -tulpn 2>/dev/null | grep -q ":${port} " || nc -z 127.0.0.1 "$port" 2>/dev/null
}

# ─── Helper: IPv6 status ─────────────────────────────────────
_tor_ipv6_disabled() {
    [[ "$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6 2>/dev/null)" == "1" ]]
}

# ─── Helper: DNS via Tor ─────────────────────────────────────
_tor_dns_via_tor() {
    grep -q "^nameserver 127.0.0.1" /etc/resolv.conf 2>/dev/null
}

# ─── Helper: Backup resolv.conf ──────────────────────────────
_tor_backup_resolv() {
    if [[ ! -f "$RESOLV_BAK" ]] && [[ -f /etc/resolv.conf ]]; then
        sudo cp /etc/resolv.conf "$RESOLV_BAK"
    fi
}

# ─── Helper: Restore resolv.conf ─────────────────────────────
_tor_restore_resolv() {
    info "Restoring system DNS..."
    sudo chattr -i /etc/resolv.conf 2>/dev/null || true
    
    if [[ -f "$RESOLV_BAK" ]]; then
        sudo cp "$RESOLV_BAK" /etc/resolv.conf
        ok "DNS restored from backup"
    else
        printf "nameserver 1.1.1.1\nnameserver 9.9.9.9\n" | sudo tee /etc/resolv.conf > /dev/null
        ok "DNS reset to defaults"
    fi
    
    if command -v NetworkManager &>/dev/null; then
        sudo systemctl restart NetworkManager 2>/dev/null || true
    fi
}

# ─── Helper: Configure torrc ─────────────────────────────────
_tor_configure_torrc() {
    info "Configuring Tor transparent proxy..."
    
    # Backup existing torrc once
    if [[ ! -f "${TORRC}.snowfox-bak" && -f "$TORRC" ]]; then
        sudo cp "$TORRC" "${TORRC}.snowfox-bak"
    fi
    
    sudo tee "$TORRC" > /dev/null << 'EOF'
## SnowFoxOS — Tor Transparent Proxy Configuration

SocksPort 127.0.0.1:9050
TransPort 127.0.0.1:9040
DNSPort 127.0.0.1:5353

## Automap .onion addresses
VirtualAddrNetworkIPv4 10.192.0.0/10
AutomapHostsOnResolve 1
AutomapHostsSuffixes .exit,.onion

## Logging
Log notice file /var/log/tor/notices.log

## Safety
SafeSocks 1
TestSocks 1

## Performance
CircuitBuildTimeout 60
NumEntryGuards 4
EOF

    sudo chown debian-tor:debian-tor "$TORRC" 2>/dev/null || sudo chown tor:tor "$TORRC" 2>/dev/null || true
    sudo chmod 644 "$TORRC"
    ok "Tor configured (TransPort: ${TOR_TRANS_PORT}, DNSPort: ${TOR_DNS_PORT})"
}

# ─── Helper: Start Tor service ───────────────────────────────
_tor_start_service() {
    if _tor_service_running; then
        info "Tor service already running"
        return 0
    fi
    
    info "Starting Tor service..."
    sudo systemctl restart "$TOR_SERVICE" 2>/dev/null || {
        warn "systemd service failed, starting Tor directly..."
        sudo -u debian-tor tor -f "$TORRC" > /dev/null 2>&1 &
    }
    
    # Wait for ports to be ready (max 15s)
    local i=0
    while [[ $i -lt 15 ]]; do
        if _tor_port_open "$TOR_TRANS_PORT" && _tor_port_open "$TOR_DNS_PORT"; then
            ok "Tor ports are ready"
            return 0
        fi
        sleep 1
        ((i++))
    done
    
    err "Tor failed to open ports within 15 seconds"
    return 1
}

# ─── Helper: Apply iptables rules ────────────────────────────
_tor_apply_iptables() {
    local tor_uid
    tor_uid=$(_tor_get_uid)
    
    if [[ -z "$tor_uid" ]]; then
        err "Could not determine Tor user UID"
        return 1
    fi
    
    info "Applying iptables rules (Tor UID: $tor_uid)..."
    
    # Save current rules for restore
    sudo iptables-save | sudo tee "$IPTABLES_SAVE" > /dev/null
    sudo ip6tables-save | sudo tee "$IPTABLES_SAVE_IP6" > /dev/null 2>&1 || true
    
    # ── IPv4 NAT table ──────────────────────────────────────
    sudo iptables -t nat -F OUTPUT
    
    # Tor user traffic bypasses
    sudo iptables -t nat -A OUTPUT -m owner --uid-owner "$tor_uid" -j RETURN
    # Localhost bypass
    sudo iptables -t nat -A OUTPUT -d 127.0.0.0/8 -j RETURN
    # Local network bypass
    sudo iptables -t nat -A OUTPUT -d 192.168.0.0/16 -j RETURN
    sudo iptables -t nat -A OUTPUT -d 10.0.0.0/8 -j RETURN
    sudo iptables -t nat -A OUTPUT -d 172.16.0.0/12 -j RETURN
    # DNS redirect
    sudo iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports "$TOR_DNS_PORT"
    sudo iptables -t nat -A OUTPUT -p tcp --dport 53 -j REDIRECT --to-ports "$TOR_DNS_PORT"
    # All TCP redirect
    sudo iptables -t nat -A OUTPUT -p tcp --syn -j REDIRECT --to-ports "$TOR_TRANS_PORT"
    
    # ── IPv4 filter table ──────────────────────────────────
    sudo iptables -F OUTPUT
    
    # Established connections
    sudo iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    # Localhost
    sudo iptables -A OUTPUT -d 127.0.0.0/8 -j ACCEPT
    # Local network
    sudo iptables -A OUTPUT -d 192.168.0.0/16 -j ACCEPT
    sudo iptables -A OUTPUT -d 10.0.0.0/8 -j ACCEPT
    sudo iptables -A OUTPUT -d 172.16.0.0/12 -j ACCEPT
    # Tor user
    sudo iptables -A OUTPUT -m owner --uid-owner "$tor_uid" -j ACCEPT
    # Tor ports
    sudo iptables -A OUTPUT -p tcp --dport "$TOR_SOCKS_PORT" -j ACCEPT
    sudo iptables -A OUTPUT -p tcp --dport "$TOR_TRANS_PORT" -j ACCEPT
    sudo iptables -A OUTPUT -p udp --dport "$TOR_DNS_PORT" -j ACCEPT
    # Reject everything else (fail-closed)
    sudo iptables -A OUTPUT -j REJECT --reject-with icmp-port-unreachable
    
    # ── IPv6: block everything ─────────────────────────────
    sudo ip6tables -F OUTPUT 2>/dev/null || true
    sudo ip6tables -A OUTPUT -m owner --uid-owner "$tor_uid" -j ACCEPT 2>/dev/null || true
    sudo ip6tables -A OUTPUT -d ::1/128 -j ACCEPT 2>/dev/null || true
    sudo ip6tables -A OUTPUT -j DROP 2>/dev/null || true
    
    ok "iptables rules applied (fail-closed)"
}

# ─── Helper: Remove iptables rules ───────────────────────────
_tor_remove_iptables() {
    info "Removing iptables rules..."
    
    if [[ -f "$IPTABLES_SAVE" ]]; then
        sudo iptables-restore < "$IPTABLES_SAVE" 2>/dev/null || {
            sudo iptables -F OUTPUT
            sudo iptables -t nat -F OUTPUT
        }
    else
        sudo iptables -F OUTPUT
        sudo iptables -t nat -F OUTPUT
    fi
    
    if [[ -f "$IPTABLES_SAVE_IP6" ]]; then
        sudo ip6tables-restore < "$IPTABLES_SAVE_IP6" 2>/dev/null || sudo ip6tables -F OUTPUT 2>/dev/null || true
    fi
    
    ok "iptables rules removed"
}

# ─── Helper: Configure DNS ───────────────────────────────────
_tor_configure_dns() {
    _tor_backup_resolv
    
    info "Pointing DNS to Tor..."
    sudo chattr -i /etc/resolv.conf 2>/dev/null || true
    printf "nameserver 127.0.0.1\n" | sudo tee /etc/resolv.conf > /dev/null
    sudo chattr +i /etc/resolv.conf 2>/dev/null || true
    ok "DNS set to 127.0.0.1 (Tor DNSPort)"
}

# ─── Helper: Disable IPv6 ────────────────────────────────────
_tor_disable_ipv6() {
    if _tor_ipv6_disabled; then
        info "IPv6 already disabled"
        return 0
    fi
    
    info "Disabling IPv6 (Tor does not support it)..."
    sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1 &>/dev/null
    sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1 &>/dev/null
    sudo sysctl -w net.ipv6.conf.lo.disable_ipv6=1 &>/dev/null
    ok "IPv6 disabled"
}

# ─── Helper: Enable IPv6 ─────────────────────────────────────
_tor_enable_ipv6() {
    info "Re-enabling IPv6..."
    sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0 &>/dev/null
    sudo sysctl -w net.ipv6.conf.default.disable_ipv6=0 &>/dev/null
    ok "IPv6 re-enabled"
}

# ─── Helper: Test connection ─────────────────────────────────
_tor_test_connection() {
    info "Testing Tor connection..."
    sleep 2
    
    local tor_ip
    tor_ip=$(torsocks curl -s --max-time 10 https://check.torproject.org/api/ip 2>/dev/null | grep -oE '"IP":"[0-9.]+"' | cut -d'"' -f4)
    
    if [[ -n "$tor_ip" ]]; then
        ok "Tor is working (Exit IP: $tor_ip)"
        return 0
    fi
    
    warn "Tor connection test failed"
    info "Manual test: torsocks curl https://check.torproject.org/api/ip"
    return 1
}

# ─── Enable Tor mode ─────────────────────────────────────────
_tor_enable() {
    fox "Enabling Tor transparent proxy..."

    _tor_check_deps || return 1
    _tor_configure_torrc || return 1
    _tor_start_service || return 1
    _tor_disable_ipv6 || return 1
    _tor_configure_dns || return 1
    _tor_apply_iptables || return 1
    _tor_test_connection

    mkdir -p "$SNOWFOX_CONFIG_DIR"
    echo "tor" > "$TOR_MODE_FILE"
    chmod 600 "$TOR_MODE_FILE"

    echo ""
    divider
    ok "Tor mode enabled — all traffic routed through Tor"
    echo ""
    info "SOCKS5:    127.0.0.1:${TOR_SOCKS_PORT}"
    info "TransPort: 127.0.0.1:${TOR_TRANS_PORT}"
    info "DNSPort:   127.0.0.1:${TOR_DNS_PORT}"
    echo ""
    warn "Network is fail-closed: if Tor stops, no traffic leaves"
    echo ""
}

# ─── Disable Tor mode ────────────────────────────────────────
_tor_disable() {
    fox "Disabling Tor mode..."

    _tor_remove_iptables
    _tor_restore_resolv
    _tor_enable_ipv6

    rm -f "$TOR_MODE_FILE"

    echo ""
    divider
    ok "Tor mode disabled — normal network restored"
    echo ""
    info "Tor service still running: ${TOR_SERVICE}"
    info "Stop with: sudo systemctl stop ${TOR_SERVICE}"
    echo ""
}

# ─── Tor status ──────────────────────────────────────────────
_tor_status() {
    header "Tor Status"

    if [[ ! -f "$TOR_MODE_FILE" ]]; then
        row "Tor mode" "inactive" "$DGRAY"
        echo ""
        info "Enable: snowfox tor on"
        echo ""
        return
    fi

    if _tor_service_running; then
        row "Tor service" "running" "$GREEN"
    else
        row "Tor service" "stopped" "$RED"
    fi

    if _tor_port_open "$TOR_TRANS_PORT"; then
        row "TransPort" "127.0.0.1:${TOR_TRANS_PORT}" "$GREEN"
    else
        row "TransPort" "not reachable" "$RED"
    fi

    if _tor_port_open "$TOR_DNS_PORT"; then
        row "DNSPort" "127.0.0.1:${TOR_DNS_PORT}" "$GREEN"
    else
        row "DNSPort" "not reachable" "$RED"
    fi

    if _tor_dns_via_tor; then
        row "DNS" "via Tor" "$GREEN"
    else
        row "DNS" "standard" "$ORANGE"
    fi

    if _tor_ipv6_disabled; then
        row "IPv6" "disabled" "$GREEN"
    else
        row "IPv6" "enabled (leak risk)" "$RED"
    fi

    echo ""
    info "Checking external IP..."

    local tor_ip
    tor_ip=$(torsocks curl -s --max-time 10 https://check.torproject.org/api/ip 2>/dev/null | grep -oE '"IP":"[0-9.]+"' | cut -d'"' -f4)

    if [[ -n "$tor_ip" ]]; then
        row "Exit IP" "$tor_ip" "$GREEN"
    else
        row "Exit IP" "not reachable" "$RED"
    fi
    echo ""
}

# ─── Main command ────────────────────────────────────────────
cmd_tor() {
    case "$1" in
        on|enable)
            _tor_enable
            ;;
        off|disable)
            _tor_disable
            ;;
        status|"")
            _tor_status
            ;;
        restart)
            _tor_disable
            sleep 2
            _tor_enable
            ;;
        *)
            header "snowfox tor"
            echo ""
            row "snowfox tor on"     "Enable transparent Tor proxy"
            row "snowfox tor off"    "Disable Tor mode"
            row "snowfox tor status" "Show current status"
            row "snowfox tor restart" "Restart Tor"
            echo ""
            divider
            info "Tor routes all TCP traffic and DNS queries through the Tor network."
            info "When enabled, non-Tor traffic is blocked (fail-closed)."
            echo ""
            ;;
    esac
}
