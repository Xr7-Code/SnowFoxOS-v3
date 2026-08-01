#!/bin/bash
# ============================================================
#  SnowFoxOS — Tor Modul (KORRIGIERT - DNS FIX)
# ============================================================

readonly TOR_SOCKS="9050"
readonly TOR_DNS="9053"
readonly TOR_CONFIG_DIR="/etc/tor"
readonly TORRC="${TOR_CONFIG_DIR}/torrc"
readonly SNOWFOX_CONFIG_DIR="${HOME}/.config/snowfox"
readonly TOR_MODE_FILE="${SNOWFOX_CONFIG_DIR}/tor-mode"
readonly RESOLV_BAK="/etc/resolv.conf.snowfox-bak"
readonly RESOLV_ORIG="/etc/resolv.conf.orig"
readonly TOR_SERVICE="tor-snowfox.service"

# ─── Dependency Check ──────────────────────────────────────
_tor_check_deps() {
    local missing=()
    local deps=(tor torsocks macchanger curl nc dig systemctl)
    
    for dep in "${deps[@]}"; do
        command -v "$dep" &>/dev/null || missing+=("$dep")
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        warn "Fehlende Pakete: ${missing[*]}"
        info "Installieren mit: sudo apt-get install -y ${missing[*]}"
        return 1
    fi
    return 0
}

# ─── Helper: Service prüfen ──────────────────────────────
_tor_service_running() {
    systemctl is-active --quiet "$TOR_SERVICE" 2>/dev/null
}

# ─── Helper: Port prüfen ──────────────────────────────────
_tor_port_open() {
    local port="$1"
    nc -z 127.0.0.1 "$port" 2>/dev/null
}

# ─── Helper: IPv6 Status ──────────────────────────────────
_ipv6_is_disabled() {
    [[ "$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6 2>/dev/null)" == "1" ]]
}

# ─── Helper: DNS via Tor ──────────────────────────────────
_dns_via_tor() {
    grep -q "^nameserver 127.0.0.1" /etc/resolv.conf 2>/dev/null
}

# ─── Helper: MAC randomisieren ────────────────────────────
_randomize_mac() {
    local iface="$1"
    sudo ip link set "$iface" down 2>/dev/null || return 1
    sudo macchanger -r "$iface" 2>/dev/null | grep -q "New MAC"
    local result=$?
    sudo ip link set "$iface" up 2>/dev/null
    return $result
}

# ─── Helper: Interface Liste ──────────────────────────────
_get_network_interfaces() {
    ip link show | awk -F': ' '/^[0-9]+: (en|wl|eth)/{print $2}'
}

# ─── Helper: Standard DNS wiederherstellen ────────────────
_restore_standard_dns() {
    info "Stelle Standard-DNS wieder her..."
    sudo chattr -i /etc/resolv.conf 2>/dev/null || true
    
    if [[ -f "$RESOLV_ORIG" ]]; then
        sudo cp "$RESOLV_ORIG" /etc/resolv.conf
        ok "DNS aus Original-Backup wiederhergestellt"
    elif [[ -f "$RESOLV_BAK" ]]; then
        sudo cp "$RESOLV_BAK" /etc/resolv.conf
        ok "DNS aus Backup wiederhergestellt"
    else
        # Standard-DNS setzen
        cat > /tmp/resolv.conf << 'EOF'
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF
        sudo cp /tmp/resolv.conf /etc/resolv.conf
        rm /tmp/resolv.conf
        ok "DNS auf Standard zurückgesetzt"
    fi
    
    # NetworkManager neu starten falls vorhanden
    if command -v NetworkManager &>/dev/null; then
        sudo systemctl restart NetworkManager 2>/dev/null || true
    fi
}

# ─── HELPER: Tor Service fixen ────────────────────────────
_tor_fix_service() {
    info "Prüfe Tor-Service..."
    
    if [[ ! -f /etc/systemd/system/tor-snowfox.service ]]; then
        warn "tor-snowfox.service nicht gefunden. Erstelle..."
        
        sudo tee /etc/systemd/system/tor-snowfox.service << 'EOF'
[Unit]
Description=Tor SnowFox Service
After=network.target

[Service]
Type=simple
User=debian-tor
Group=debian-tor
ExecStart=/usr/bin/tor -f /etc/tor/torrc
Restart=on-failure
RestartSec=10
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
        sudo systemctl daemon-reload
        ok "tor-snowfox.service erstellt"
    fi
    
    if ! _tor_service_running; then
        info "Starte Tor-Service..."
        sudo systemctl start "$TOR_SERVICE" 2>/dev/null || {
            warn "Konnte Service nicht starten, starte Tor direkt..."
            sudo -u debian-tor tor -f "$TORRC" > /dev/null 2>&1 &
        }
        sleep 3
    fi
    
    if ! _tor_service_running && ! pgrep -f "tor.*torrc" > /dev/null; then
        err "Tor läuft nicht!"
        return 1
    fi
    
    ok "Tor-Service läuft ✓"
    return 0
}

# ─── HELPER: Torrc fixen ──────────────────────────────────
_tor_fix_torrc() {
    info "Prüfe Torrc-Konfiguration..."
    local needs_fix=false
    
    if [[ ! -f "$TORRC" ]]; then
        warn "Torrc nicht gefunden. Erstelle..."
        needs_fix=true
    fi
    
    if ! grep -q "^DNSPort" "$TORRC" 2>/dev/null; then
        warn "DNSPort fehlt in Torrc"
        needs_fix=true
    fi
    
    if ! grep -q "^SocksPort" "$TORRC" 2>/dev/null; then
        warn "SocksPort fehlt in Torrc"
        needs_fix=true
    fi
    
    if [[ "$needs_fix" == true ]]; then
        info "Erstelle korrekte Torrc..."
        sudo cp "$TORRC" "${TORRC}.old" 2>/dev/null || true
        
        sudo tee "$TORRC" > /dev/null << 'EOF'
## SnowFoxOS Tor Configuration
SocksPort 127.0.0.1:9050
SocksPolicy accept 127.0.0.1/8
SocksPolicy reject *
DNSPort 127.0.0.1:9053
AutomapHostsOnResolve 1
AutomapHostsSuffixes .exit,.onion
Log notice file /var/log/tor/notices.log
SafeSocks 1
TestSocks 1
CircuitBuildTimeout 60
NumEntryGuards 4
EOF

        sudo chown debian-tor:debian-tor "$TORRC"
        sudo chmod 644 "$TORRC"
        ok "Torrc korrigiert"
        
        sudo systemctl restart "$TOR_SERVICE" 2>/dev/null || sudo pkill -f "tor.*torrc"
        sleep 3
    else
        ok "Torrc ist korrekt ✓"
    fi
    
    return 0
}

# ─── HELPER: DNS fixen ────────────────────────────────────
_tor_fix_dns() {
    info "Prüfe DNS-Konfiguration..."
    
    # Backup der originalen resolv.conf (einmalig)
    if [[ ! -f "$RESOLV_ORIG" ]] && [[ -f /etc/resolv.conf ]]; then
        sudo cp /etc/resolv.conf "$RESOLV_ORIG"
    fi
    
    # Teste DNS über Tor
    if dig @"127.0.0.1" -p "$TOR_DNS" google.com +short 2>/dev/null | grep -qE '^[0-9.]+$'; then
        ok "DNS über Tor funktioniert ✓"
        
        if ! _dns_via_tor; then
            info "Stelle DNS auf Tor um..."
            if [[ ! -f "$RESOLV_BAK" ]]; then
                sudo cp /etc/resolv.conf "$RESOLV_BAK"
            fi
            echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf > /dev/null
            sudo chattr +i /etc/resolv.conf 2>/dev/null || true
            ok "DNS auf Tor umgestellt"
        fi
        return 0
    else
        warn "DNS über Tor funktioniert nicht"
        _restore_standard_dns
        return 1
    fi
}

# ─── HELPER: IPv6 fixen ────────────────────────────────────
_tor_fix_ipv6() {
    info "Prüfe IPv6-Konfiguration..."
    
    if _ipv6_is_disabled; then
        ok "IPv6 bereits deaktiviert ✓"
        return 0
    fi
    
    info "Deaktiviere IPv6..."
    sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1 &>/dev/null
    sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1 &>/dev/null
    sudo sysctl -w net.ipv6.conf.lo.disable_ipv6=1 &>/dev/null
    
    ok "IPv6 deaktiviert ✓"
    return 0
}

# ─── HELPER: MAC fixen ────────────────────────────────────
_tor_fix_mac() {
    info "Randomisiere MAC-Adressen..."
    local mac_count=0
    
    for iface in $(_get_network_interfaces); do
        if _randomize_mac "$iface"; then
            ((mac_count++))
        fi
    done
    
    if [[ $mac_count -gt 0 ]]; then
        ok "${mac_count} MAC-Adresse(n) randomisiert ✓"
    fi
    return 0
}

# ─── HELPER: Tor Verbindung testen ────────────────────────
_tor_test_connection() {
    info "Teste Tor-Verbindung..."
    sleep 2
    
    local tor_ip
    tor_ip=$(torsocks curl -s --max-time 5 https://icanhazip.com 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}')
    
    if [[ -n "$tor_ip" ]]; then
        ok "Tor-IP: $tor_ip ✓"
        return 0
    fi
    
    warn "Verbindungstest fehlgeschlagen"
    info "Manueller Test: torsocks curl https://icanhazip.com"
    return 1
}

# ─── Hauptfunktion: Tor aktivieren ──────────────────────
_tor_enable() {
    fox "Aktiviere Tor-Modus..."

    _tor_check_deps || return 1
    _tor_fix_torrc || return 1
    _tor_fix_service || return 1
    _tor_fix_ipv6 || return 1
    _tor_fix_dns || {
        warn "DNS über Tor nicht möglich, aber HTTP funktioniert"
    }
    _tor_fix_mac
    _tor_test_connection

    mkdir -p "$SNOWFOX_CONFIG_DIR"
    echo "tor" > "$TOR_MODE_FILE"
    chmod 600 "$TOR_MODE_FILE"

    divider
    ok "Tor-Modus erfolgreich aktiviert! 🦊"
    echo ""
    info "SOCKS5-Proxy: 127.0.0.1:${TOR_SOCKS}"
    info "DNS-Port: 127.0.0.1:${TOR_DNS}"
    echo ""
    info "Teste Verbindung:"
    echo "  torsocks curl https://icanhazip.com"
    echo "  torsocks curl https://check.torproject.org/api/ip"
    echo ""
}

# ─── Tor deaktivieren ──────────────────────────────────────
_tor_disable() {
    fox "Deaktiviere Tor-Modus..."

    _restore_standard_dns

    info "Aktiviere IPv6 wieder..."
    sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0 &>/dev/null
    sudo sysctl -w net.ipv6.conf.default.disable_ipv6=0 &>/dev/null
    ok "IPv6 reaktiviert"

    rm -f "$TOR_MODE_FILE"

    divider
    ok "Tor-Modus deaktiviert"
    info "Tor-Service läuft weiter ($TOR_SERVICE)"
    info "Zum Stoppen: sudo systemctl stop $TOR_SERVICE"
    echo ""
}

# ─── Tor Status ──────────────────────────────────────────
_tor_status() {
    header "Tor Status"
    
    if [[ ! -f "$TOR_MODE_FILE" ]]; then
        row "Tor-Modus" "inaktiv" "$DGRAY"
        echo ""
        return
    fi

    if _tor_service_running; then
        row "Tor-Dienst" "läuft ✓" "$GREEN"
    else
        row "Tor-Dienst" "gestoppt ✗" "$RED"
    fi

    if _tor_port_open "$TOR_SOCKS"; then
        row "SOCKS5" "127.0.0.1:${TOR_SOCKS} ✓" "$GREEN"
    else
        row "SOCKS5" "nicht erreichbar ✗" "$RED"
    fi

    if _dns_via_tor; then
        row "DNS" "via Tor ✓" "$GREEN"
    else
        row "DNS" "Standard" "$YELLOW"
    fi

    echo ""
    info "Prüfe externe IP..."
    local tor_ip
    tor_ip=$(torsocks curl -s --max-time 5 https://icanhazip.com 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}')
    if [[ -n "$tor_ip" ]]; then
        row "Tor-IP" "$tor_ip" "$GREEN"
    else
        row "Tor-IP" "❌ Nicht erreichbar" "$RED"
    fi
    echo ""
}

# ─── Hauptbefehl ────────────────────────────────────────────
cmd_tor() {
    case "$1" in
        on|enable|start)
            _tor_enable
            ;;
        off|disable|stop)
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
            row "snowfox tor on"     "Tor-Modus aktivieren"
            row "snowfox tor off"    "Tor-Modus deaktivieren"
            row "snowfox tor status" "Status anzeigen"
            row "snowfox tor restart" "Tor neu starten"
            echo ""
            ;;
    esac
}
