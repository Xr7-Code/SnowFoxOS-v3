#!/bin/bash
# ============================================================
#  SnowFoxOS — CLI Modul: Tor & Anonymität
#  Wird von /usr/local/bin/snowfox gesourced.
# ============================================================

# ─── Konstanten ──────────────────────────────────────────────
readonly TOR_CONFIG_DIR="/etc/tor"
readonly TORRC="${TOR_CONFIG_DIR}/torrc"
readonly SNOWFOX_CONFIG_DIR="${HOME}/.config/snowfox"
readonly TOR_MODE_FILE="${SNOWFOX_CONFIG_DIR}/tor-mode"
readonly RESOLV_BAK="/etc/resolv.conf.snowfox-bak"
readonly TOR_SOCKS_PORT="9050"
readonly TOR_DNS_PORT="9053"
readonly TOR_TRANSPARENT_PORT="9040"

# ─── Dependency Check ──────────────────────────────────────
_tor_check_deps() {
    local missing=()
    local deps=(tor torsocks macchanger curl python3 iptables)
    
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

# ─── Helper: Tor Status prüfen ────────────────────────────
_tor_is_running() {
    systemctl is-active --quiet tor 2>/dev/null
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

# ─── Helper: Tor Check mit Fallback ──────────────────────
_check_tor_ip() {
    local timeout=15
    local response
    response=$(torsocks curl -s --max-time "$timeout" \
        https://check.torproject.org/api/ip 2>/dev/null)
    
    if [[ -z "$response" ]]; then
        echo "? ?"
        return 1
    fi
    
    echo "$response" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    ip = data.get('IP', '?')
    is_tor = 'ja' if data.get('IsTor', False) else 'nein'
    print(f'{ip} {is_tor}')
except:
    print('? ?')
" 2>/dev/null || echo "? ?"
}

# ─── DNS testen ────────────────────────────────────────────
_test_dns() {
    local test_domain="${1:-google.com}"
    info "Teste DNS-Auflösung für $test_domain..."
    
    # Versuche DNS über Tor
    if timeout 5 dig @"127.0.0.1" -p "$TOR_DNS_PORT" "$test_domain" +short 2>/dev/null | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        ok "DNS via Tor funktioniert ✓"
        return 0
    fi
    
    # Fallback: Versuche über torsocks
    if timeout 5 torsocks dig "$test_domain" +short 2>/dev/null | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        ok "DNS via torsocks funktioniert ✓"
        return 0
    fi
    
    warn "DNS-Auflösung fehlgeschlagen!"
    return 1
}

# ─── Internetverbindung testen ────────────────────────────
_test_connection() {
    info "Teste Internetverbindung über Tor..."
    
    # Einfacher HTTP-Test
    if timeout 10 torsocks curl -s -I https://check.torproject.org 2>/dev/null | grep -q "HTTP"; then
        ok "HTTP-Verbindung über Tor funktioniert ✓"
        return 0
    fi
    
    # Fallback: Ping über Tor
    if timeout 10 torsocks ping -c 1 8.8.8.8 2>/dev/null | grep -q "1 packets transmitted"; then
        ok "Ping über Tor funktioniert ✓"
        return 0
    fi
    
    warn "Keine Internetverbindung über Tor!"
    return 1
}

# ─── Tor Debug ─────────────────────────────────────────────
_tor_debug() {
    header "Tor Debug Informationen"
    
    # Tor Logs
    info "Letzte Tor Log-Einträge:"
    sudo journalctl -u tor -n 10 --no-pager 2>/dev/null || echo "Keine Logs verfügbar"
    echo ""
    
    # Torrc prüfen
    info "Torrc Konfiguration (relevant):"
    grep -E "^DNSPort|^AutomapHosts|^SocksPort|^TransPort" "$TORRC" 2>/dev/null || echo "Keine relevanten Einträge gefunden"
    echo ""
    
    # Netzwerk-Interfaces
    info "Netzwerk-Interfaces:"
    ip addr show | grep -E "^[0-9]+:|inet " | head -20
    echo ""
    
    # DNS testen
    _test_dns
    echo ""
    
    # Verbindung testen
    _test_connection
    echo ""
    
    # IP prüfen
    info "Prüfe Tor-IP:"
    local tor_check
    tor_check=$(_check_tor_ip)
    echo "  $tor_check"
    echo ""
}

# ─── Tor aktivieren (verbesserte Version) ──────────────────
_tor_enable() {
    fox "Aktiviere Tor-Modus..."

    # ── 1. Prüfe ob Tor bereits läuft ────────────────────────
    if _tor_is_running; then
        warn "Tor läuft bereits. Starte neu..."
        sudo systemctl restart tor
        sleep 2
    fi

    # ── 2. Torrc konfigurieren ───────────────────────────────
    info "Konfiguriere Tor für transparentes Proxying..."
    sudo mkdir -p "$TOR_CONFIG_DIR"
    
    # Backup der original Torrc
    if [[ ! -f "${TORRC}.orig" ]]; then
        sudo cp "$TORRC" "${TORRC}.orig" 2>/dev/null || true
    fi
    
    # Entferne alte SnowFox-Einträge
    sudo sed -i '/# SnowFox-Start/,/# SnowFox-Ende/d' "$TORRC" 2>/dev/null || true
    
    # Füge neue Konfiguration hinzu
    sudo tee -a "$TORRC" > /dev/null <<TOREOF

# SnowFox-Start
# SOCKS5 für Anwendungen
SocksPort 127.0.0.1:${TOR_SOCKS_PORT}

# Transparent Proxy für systemweites Routing
TransPort 127.0.0.1:${TOR_TRANSPARENT_PORT}

# DNS über Tor
DNSPort 127.0.0.1:${TOR_DNS_PORT}

# Automatische .onion Auflösung
AutomapHostsOnResolve 1
AutomapHostsSuffixes .exit,.onion

# Erzwinge Tor für ausgehende Verbindungen
ExitNodes {us},{ca},{gb},{de}
StrictNodes 1

# Erhöhte Sicherheit
SafeSocks 1
TestSocks 1
WarnPlaintextPorts 23,109,110,143
# SnowFox-Ende
TOREOF

    # ── 3. Tor starten ─────────────────────────────────────────
    info "Starte Tor-Dienst..."
    if ! sudo systemctl enable --now tor 2>/dev/null; then
        err "Tor konnte nicht aktiviert werden"
        _tor_debug
        return 1
    fi
    
    sleep 3
    if ! _tor_is_running; then
        err "Tor läuft nicht!"
        _tor_debug
        return 1
    fi
    ok "Tor läuft (Ports: SOCKS=${TOR_SOCKS_PORT}, DNS=${TOR_DNS_PORT}, Trans=${TOR_TRANSPARENT_PORT})"

    # ── 4. IPv6 deaktivieren ──────────────────────────────────
    info "Deaktiviere IPv6..."
    local ipv6_opts=(
        "net.ipv6.conf.all.disable_ipv6=1"
        "net.ipv6.conf.default.disable_ipv6=1"
        "net.ipv6.conf.lo.disable_ipv6=1"
    )
    for opt in "${ipv6_opts[@]}"; do
        sudo sysctl -w "$opt" &>/dev/null || warn "Konnte $opt nicht setzen"
    done
    # Persistente Konfiguration
    echo "net.ipv6.conf.all.disable_ipv6=1" | sudo tee -a /etc/sysctl.conf > /dev/null
    ok "IPv6 deaktiviert"

    # ── 5. DNS durch Tor leiten ──────────────────────────────
    info "Leite DNS durch Tor..."
    
    # Backup der resolv.conf
    if [[ ! -f "$RESOLV_BAK" ]]; then
        sudo cp /etc/resolv.conf "$RESOLV_BAK"
    fi
    
    # DNS über Tor setzen
    echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf > /dev/null
    
    # resolv.conf vor Änderungen schützen
    sudo chattr +i /etc/resolv.conf 2>/dev/null || true
    
    # Zusätzlich dnsmasq deaktivieren falls vorhanden
    if systemctl is-active --quiet dnsmasq 2>/dev/null; then
        sudo systemctl stop dnsmasq
        sudo systemctl disable dnsmasq
    fi
    
    ok "DNS → Tor (127.0.0.1:${TOR_DNS_PORT})"

    # ── 6. Systemweites Routing über Tor ──────────────────────
    info "Richte transparentes Proxying ein..."
    
    # iptables Regeln für Tor Transparent Proxy
    sudo iptables -t nat -F
    sudo iptables -t nat -A OUTPUT -m owner --uid-owner debian-tor -j RETURN
    sudo iptables -t nat -A OUTPUT -p tcp --dport 53 -j REDIRECT --to-ports ${TOR_DNS_PORT}
    sudo iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports ${TOR_DNS_PORT}
    sudo iptables -t nat -A OUTPUT -p tcp --dport 80 -j REDIRECT --to-ports ${TOR_TRANSPARENT_PORT}
    sudo iptables -t nat -A OUTPUT -p tcp --dport 443 -j REDIRECT --to-ports ${TOR_TRANSPARENT_PORT}
    
    ok "Transparentes Routing aktiviert"

    # ── 7. MAC randomisieren ──────────────────────────────────
    info "Randomisiere MAC-Adressen..."
    local mac_count=0
    for iface in $(_get_network_interfaces); do
        if _randomize_mac "$iface"; then
            ((mac_count++))
        else
            warn "Konnte MAC für $iface nicht randomisieren"
        fi
    done
    ok "${mac_count} MAC-Adresse(n) randomisiert"

    # ── 8. Verbindung testen ──────────────────────────────────
    info "Teste Verbindung über Tor..."
    sleep 2
    
    if ! _test_dns; then
        warn "DNS-Test fehlgeschlagen. Versuche alternative Konfiguration..."
        # Alternative: DNS über System-resolv
        echo "nameserver 1.1.1.1" | sudo tee -a /etc/resolv.conf > /dev/null
        sudo chattr +i /etc/resolv.conf 2>/dev/null || true
    fi
    
    if ! _test_connection; then
        warn "Verbindungstest fehlgeschlagen. Starte Debug-Modus..."
        _tor_debug
        
        warn "Mögliche Lösungen:"
        echo "  1. Prüfe Firewall: sudo ufw disable"
        echo "  2. Prüfe Tor Logs: sudo journalctl -u tor -f"
        echo "  3. Manueller Test: torsocks curl https://check.torproject.org"
        echo "  4. Alternative Bridge verwenden"
        
        read -p "Möchtest du trotzdem fortfahren? (j/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Jj]$ ]]; then
            _tor_disable
            return 1
        fi
    else
        ok "Tor-Verbindung erfolgreich getestet ✓"
    fi

    # ── 9. Status speichern ───────────────────────────────────
    mkdir -p "$SNOWFOX_CONFIG_DIR"
    echo "tor" > "$TOR_MODE_FILE"
    chmod 600 "$TOR_MODE_FILE"

    # ── 10. Erfolgsmeldung ──────────────────────────────────
    divider
    ok "Tor-Modus erfolgreich aktiviert"
    echo ""
    info "Systemweites Routing:"
    echo "  • HTTP/HTTPS → Tor (transparent)"
    echo "  • DNS → Tor (127.0.0.1:${TOR_DNS_PORT})"
    echo "  • SOCKS5 → 127.0.0.1:${TOR_SOCKS_PORT}"
    echo ""
    info "Teste deine Verbindung:"
    echo "  torsocks curl https://check.torproject.org/api/ip"
    echo "  oder einfach: curl https://ifconfig.me  # (via Tor)"
    echo ""
    info "Bei Problemen: snowfox tor debug"
    echo ""
}

# ─── Tor deaktivieren ──────────────────────────────────────
_tor_disable() {
    fox "Deaktiviere Tor-Modus..."

    # ── 1. iptables zurücksetzen ─────────────────────────────
    info "Setze Firewall-Regeln zurück..."
    sudo iptables -t nat -F
    sudo iptables -t nat -X
    ok "Firewall zurückgesetzt"

    # ── 2. DNS wiederherstellen ──────────────────────────────
    info "Stelle DNS wieder her..."
    sudo chattr -i /etc/resolv.conf 2>/dev/null || true
    
    if [[ -f "$RESOLV_BAK" ]]; then
        sudo cp "$RESOLV_BAK" /etc/resolv.conf
        sudo rm -f "$RESOLV_BAK"
        ok "DNS aus Backup wiederhergestellt"
    else
        # Standard DNS setzen
        echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf > /dev/null
        echo "nameserver 1.1.1.1" | sudo tee -a /etc/resolv.conf > /dev/null
        ok "DNS auf Standard zurückgesetzt"
    fi

    # ── 3. Tor-DNS aus Torrc entfernen ──────────────────────
    sudo sed -i '/# SnowFox-Start/,/# SnowFox-Ende/d' "$TORRC" 2>/dev/null || true
    
    # Original Torrc wiederherstellen
    if [[ -f "${TORRC}.orig" ]]; then
        sudo cp "${TORRC}.orig" "$TORRC"
        sudo rm -f "${TORRC}.orig"
    fi
    
    sudo systemctl restart tor 2>/dev/null

    # ── 4. IPv6 reaktivieren ──────────────────────────────────
    info "Aktiviere IPv6 wieder..."
    sudo sed -i '/net.ipv6.conf.all.disable_ipv6=1/d' /etc/sysctl.conf
    
    local ipv6_opts=(
        "net.ipv6.conf.all.disable_ipv6=0"
        "net.ipv6.conf.default.disable_ipv6=0"
    )
    for opt in "${ipv6_opts[@]}"; do
        sudo sysctl -w "$opt" &>/dev/null || warn "Konnte $opt nicht setzen"
    done
    ok "IPv6 reaktiviert"

    # ── 5. dnsmasq wieder aktivieren ─────────────────────────
    if systemctl is-enabled --quiet dnsmasq 2>/dev/null; then
        sudo systemctl start dnsmasq
    fi

    # ── 6. Tor stoppen ──────────────────────────────────────
    info "Stoppe Tor-Dienst..."
    sudo systemctl disable --now tor 2>/dev/null
    ok "Tor gestoppt"

    # ── 7. MAC randomisieren ──────────────────────────────────
    info "Randomisiere MAC neu (Cleanup)..."
    for iface in $(_get_network_interfaces); do
        _randomize_mac "$iface" &>/dev/null || true
    done
    ok "MAC-Adressen erneuert"

    # ── 8. Cleanup ────────────────────────────────────────────
    rm -f "$TOR_MODE_FILE"

    divider
    ok "Tor-Modus deaktiviert — normale Verbindung wiederhergestellt"
    echo ""
}

# ─── Tor Status anzeigen ──────────────────────────────────
_tor_check() {
    header "Tor Status"

    if [[ ! -f "$TOR_MODE_FILE" ]]; then
        row "Tor-Modus" "inaktiv" "$DGRAY"
        echo ""
        return
    fi

    # System-Status
    if _tor_is_running; then
        row "Tor-Dienst" "aktiv ✓" "$GREEN"
    else
        row "Tor-Dienst" "gestoppt ✗" "$RED"
    fi

    # IPv6
    if _ipv6_is_disabled; then
        row "IPv6" "deaktiviert ✓" "$GREEN"
    else
        row "IPv6" "aktiv — möglicher Leak!" "$RED"
    fi

    # DNS
    if _dns_via_tor; then
        row "DNS" "via Tor ✓" "$GREEN"
    else
        row "DNS" "NICHT via Tor ✗" "$RED"
    fi

    # Transparent Proxy
    if sudo iptables -t nat -L -n 2>/dev/null | grep -q "${TOR_TRANSPARENT_PORT}"; then
        row "Transparent Proxy" "aktiv ✓" "$GREEN"
    else
        row "Transparent Proxy" "inaktiv" "$YELLOW"
    fi

    # Externe IP prüfen
    echo ""
    info "Prüfe externe IP über Tor (max. 15s)..."
    local tor_check
    tor_check=$(_check_tor_ip)
    
    if [[ "$tor_check" != "? ?" ]]; then
        local ip="${tor_check%% *}"
        local is_tor="${tor_check##* }"
        row "Externe IP" "$ip" "$CYAN"
        
        if [[ "$is_tor" == "ja" ]]; then
            row "Tor bestätigt" "✅" "$GREEN"
        else
            row "Tor bestätigt" "❌ — Traffic NICHT durch Tor!" "$RED"
        fi
    else
        row "Externe IP" "❌ Nicht erreichbar" "$RED"
    fi

    echo ""
}

# ─── Hauptbefehl ────────────────────────────────────────────
cmd_tor() {
    case "$1" in
        on|enable|start)
            _tor_check_deps || return 1
            _tor_enable
            ;;
        off|disable|stop)
            _tor_disable
            ;;
        status|"")
            _tor_check
            ;;
        restart)
            _tor_disable
            sleep 2
            _tor_check_deps || return 1
            _tor_enable
            ;;
        debug)
            _tor_debug
            ;;
        *)
            header "snowfox tor — Anonymitätsmodus"
            info "Verwendung:"
            echo ""
            row "snowfox tor on"     "Tor-Modus aktivieren (VPN-ähnlich)"
            row "snowfox tor off"    "Tor-Modus deaktivieren"
            row "snowfox tor status" "Status + externe IP prüfen"
            row "snowfox tor restart" "Tor neu starten"
            row "snowfox tor debug"  "Debug-Informationen anzeigen"
            echo ""
            warn "Hinweise:"
            info "• Bei Verbindungsproblemen: snowfox tor debug"
            info "• Tor Browser für Browser-Anonymität empfohlen"
            info "• torsocks für CLI-Anwendungen: torsocks curl ifconfig.me"
            info "• SOCKS5-Proxy: 127.0.0.1:${TOR_SOCKS_PORT}"
            echo ""
            ;;
    esac
}
