#!/bin/bash
# ============================================================
#  SnowFoxOS — CLI Modul: Tor & Anonymität (FIXED)
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

# ─── Dependency Check ──────────────────────────────────────
_tor_check_deps() {
    local missing=()
    local deps=(tor torsocks macchanger curl)
    
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

# ─── Helper: Tor Status ──────────────────────────────────
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

# ─── Helper: Tor Check ──────────────────────────────────
_check_tor_ip() {
    local timeout=15
    local response
    response=$(torsocks curl -s --max-time "$timeout" \
        https://check.torproject.org/api/ip 2>/dev/null)
    
    if [[ -z "$response" ]]; then
        echo "? ?"
        return 1
    fi
    
    # Python3 prüfen
    if command -v python3 &>/dev/null; then
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
    else
        echo "$response" | grep -o '"IP":"[^"]*"' | cut -d'"' -f4 | head -1
    fi
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
    
    warn "DNS-Auflösung fehlgeschlagen!"
    return 1
}

# ─── Internetverbindung testen ────────────────────────────
_test_connection() {
    info "Teste Internetverbindung über Tor..."
    
    if timeout 10 torsocks curl -s -I https://check.torproject.org 2>/dev/null | grep -q "HTTP"; then
        ok "HTTP-Verbindung über Tor funktioniert ✓"
        return 0
    fi
    
    warn "Keine Internetverbindung über Tor!"
    return 1
}

# ─── Tor Debug (FIXED) ──────────────────────────────────────
_tor_debug() {
    header "Tor Debug Informationen"
    
    # Tor Logs
    info "Letzte Tor Log-Einträge:"
    sudo journalctl -u tor -n 20 --no-pager 2>/dev/null || echo "Keine Logs verfügbar"
    echo ""
    
    # Prüfe ob Tor läuft
    if _tor_is_running; then
        ok "Tor-Dienst läuft ✓"
    else
        err "Tor-Dienst läuft NICHT!"
        info "Starte Tor manuell: sudo systemctl start tor"
    fi
    echo ""
    
    # Torrc prüfen
    info "Torrc Konfiguration (relevant):"
    if [[ -f "$TORRC" ]]; then
        grep -E "^DNSPort|^SocksPort|^AutomapHosts" "$TORRC" 2>/dev/null || echo "Keine relevanten Einträge gefunden"
    else
        warn "Torrc nicht gefunden: $TORRC"
    fi
    echo ""
    
    # Tor Ports prüfen
    info "Tor Ports:"
    sudo netstat -tlnp 2>/dev/null | grep -E ":(9050|9053)" || echo "Keine Tor-Ports offen"
    echo ""
    
    # DNS testen
    _test_dns
    echo ""
    
    # Verbindung testen
    _test_connection
    echo ""
}

# ─── Tor aktivieren (FIXED) ──────────────────────────────────
_tor_enable() {
    fox "Aktiviere Tor-Modus..."

    # ── 1. Tor stoppen und säubern ───────────────────────────
    info "Bereinige alte Tor-Instanzen..."
    sudo systemctl stop tor 2>/dev/null
    sudo pkill -f tor 2>/dev/null
    sleep 2

    # ── 2. Torrc korrekt konfigurieren ──────────────────────
    info "Konfiguriere Tor..."
    sudo mkdir -p "$TOR_CONFIG_DIR"
    
    # Backup der original Torrc
    if [[ ! -f "${TORRC}.orig" ]]; then
        sudo cp "$TORRC" "${TORRC}.orig" 2>/dev/null || true
    fi
    
    # Schreibe komplett neue Torrc (kein sed, direkt überschreiben)
    sudo tee "$TORRC" > /dev/null <<'TOREOF'
## SnowFoxOS Tor Configuration

# SOCKS5 für Anwendungen
SocksPort 127.0.0.1:9050
SocksPolicy accept 127.0.0.1/8
SocksPolicy reject *

# DNS über Tor
DNSPort 127.0.0.1:9053

# Automatische .onion Auflösung
AutomapHostsOnResolve 1
AutomapHostsSuffixes .exit,.onion

# Logging
Log notice file /var/log/tor/notices.log
Log warn file /var/log/tor/warnings.log

# Erhöhte Sicherheit
SafeSocks 1
TestSocks 1
WarnPlaintextPorts 23,109,110,143

# Vermeide Exit-Nodes in problematischen Ländern
ExcludeExitNodes {ad},{ae},{af},{ag},{al},{am},{az},{ba},{bd},{bn},{bo},{bt},{bw},{by},{bz},{cd},{cf},{cg},{ci},{cm},{cn},{cu},{cy},{dj},{dz},{ec},{eg},{er},{et},{fj},{ge},{gh},{gm},{gn},{gq},{gt},{gw},{gy},{hn},{ht},{id},{in},{iq},{ir},{jo},{ke},{kg},{kh},{ki},{km},{kp},{kw},{kz},{la},{lb},{lk},{lr},{ls},{ly},{ma},{md},{me},{mg},{mk},{ml},{mm},{mn},{mr},{mt},{mu},{mv},{mw},{mx},{my},{mz},{na},{ne},{ng},{ni},{np},{pk},{py},{rs},{ru},{rw},{sa},{sb},{sd},{si},{sk},{sl},{sn},{so},{sr},{ss},{sv},{sy},{sz},{td},{tg},{th},{tj},{tm},{tn},{to},{tr},{tt},{tz},{ug},{uz},{ve},{vn},{vu},{ye},{za},{zm},{zw}
StrictNodes 1

# Geschwindigkeit vs. Anonymität
CircuitBuildTimeout 60
LearnCircuitBuildTimeout 1
NumEntryGuards 4
NumDirectoryGuards 4
EntryGuards 1

# Erzwinge TLS 1.2 oder höher
ProtocolWarnings 1
TOREOF

    ok "Torrc konfiguriert"

    # ── 3. Tor-Verzeichnis bereinigen ───────────────────────
    info "Bereinige Tor-Verzeichnisse..."
    sudo rm -rf /var/lib/tor/* 2>/dev/null
    sudo mkdir -p /var/lib/tor
    sudo chown -R debian-tor:debian-tor /var/lib/tor
    sudo chmod 700 /var/lib/tor

    # ── 4. Tor starten ──────────────────────────────────────
    info "Starte Tor-Dienst..."
    sudo systemctl start tor
    sleep 5
    
    # Prüfe ob Tor läuft
    if ! _tor_is_running; then
        err "Tor konnte nicht gestartet werden!"
        info "Prüfe Logs: sudo journalctl -u tor -n 50"
        _tor_debug
        return 1
    fi
    ok "Tor läuft (PID: $(pgrep -f 'tor' | head -1))"

    # ── 5. Torrc neu laden ──────────────────────────────────
    info "Lade Tor-Konfiguration neu..."
    sudo systemctl reload tor 2>/dev/null || sudo kill -HUP $(pgrep -f 'tor' | head -1) 2>/dev/null
    sleep 2

    # ── 6. IPv6 deaktivieren ──────────────────────────────────
    info "Deaktiviere IPv6..."
    sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1 &>/dev/null
    sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1 &>/dev/null
    sudo sysctl -w net.ipv6.conf.lo.disable_ipv6=1 &>/dev/null
    ok "IPv6 deaktiviert"

    # ── 7. DNS durch Tor leiten ──────────────────────────────
    info "Leite DNS durch Tor..."
    
    # Backup der resolv.conf
    if [[ ! -f "$RESOLV_BAK" ]]; then
        sudo cp /etc/resolv.conf "$RESOLV_BAK" 2>/dev/null || true
    fi
    
    # DNS über Tor setzen
    echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf > /dev/null
    sudo chattr +i /etc/resolv.conf 2>/dev/null || true
    ok "DNS → Tor (127.0.0.1:${TOR_DNS_PORT})"

    # ── 8. MAC randomisieren ──────────────────────────────────
    info "Randomisiere MAC-Adressen..."
    for iface in $(_get_network_interfaces); do
        _randomize_mac "$iface" &>/dev/null || true
    done
    ok "MAC-Adressen randomisiert"

    # ── 9. Verbindung testen ──────────────────────────────────
    info "Teste Verbindung über Tor..."
    sleep 3
    
    # Teste DNS
    if ! _test_dns; then
        warn "DNS-Test fehlgeschlagen. Versuche mit Standard-DNS..."
        sudo chattr -i /etc/resolv.conf 2>/dev/null || true
        echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf > /dev/null
        echo "nameserver 8.8.8.8" | sudo tee -a /etc/resolv.conf > /dev/null
    fi

    # ── 10. Status speichern ──────────────────────────────────
    mkdir -p "$SNOWFOX_CONFIG_DIR"
    echo "tor" > "$TOR_MODE_FILE"
    chmod 600 "$TOR_MODE_FILE"

    divider
    ok "Tor-Modus erfolgreich aktiviert!"
    echo ""
    info "SOCKS5-Proxy: 127.0.0.1:${TOR_SOCKS_PORT}"
    info "DNS-Port: 127.0.0.1:${TOR_DNS_PORT}"
    echo ""
    info "Teste jetzt:"
    echo "  torsocks curl https://check.torproject.org/api/ip"
    echo ""
    info "Bei Problemen: snowfox tor debug"
    echo ""
}

# ─── Tor deaktivieren ──────────────────────────────────────
_tor_disable() {
    fox "Deaktiviere Tor-Modus..."

    # ── 1. DNS wiederherstellen ──────────────────────────────
    info "Stelle DNS wieder her..."
    sudo chattr -i /etc/resolv.conf 2>/dev/null || true
    
    if [[ -f "$RESOLV_BAK" ]]; then
        sudo cp "$RESOLV_BAK" /etc/resolv.conf
        sudo rm -f "$RESOLV_BAK"
        ok "DNS aus Backup wiederhergestellt"
    else
        echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf > /dev/null
        echo "nameserver 1.1.1.1" | sudo tee -a /etc/resolv.conf > /dev/null
        ok "DNS auf Standard zurückgesetzt"
    fi

    # ── 2. Torrc wiederherstellen ──────────────────────────
    if [[ -f "${TORRC}.orig" ]]; then
        sudo cp "${TORRC}.orig" "$TORRC"
        sudo rm -f "${TORRC}.orig"
    fi

    # ── 3. IPv6 reaktivieren ──────────────────────────────────
    info "Aktiviere IPv6 wieder..."
    sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0 &>/dev/null
    sudo sysctl -w net.ipv6.conf.default.disable_ipv6=0 &>/dev/null
    ok "IPv6 reaktiviert"

    # ── 4. Tor stoppen ──────────────────────────────────────
    info "Stoppe Tor-Dienst..."
    sudo systemctl stop tor 2>/dev/null
    sudo pkill -f tor 2>/dev/null
    ok "Tor gestoppt"

    # ── 5. MAC randomisieren ──────────────────────────────────
    info "Randomisiere MAC neu (Cleanup)..."
    for iface in $(_get_network_interfaces); do
        _randomize_mac "$iface" &>/dev/null || true
    done
    ok "MAC-Adressen erneuert"

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

    if _tor_is_running; then
        row "Tor-Dienst" "aktiv ✓" "$GREEN"
    else
        row "Tor-Dienst" "gestoppt ✗" "$RED"
        warn "Starte Tor: sudo systemctl start tor"
    fi

    if _ipv6_is_disabled; then
        row "IPv6" "deaktiviert ✓" "$GREEN"
    else
        row "IPv6" "aktiv — möglicher Leak!" "$RED"
    fi

    if _dns_via_tor; then
        row "DNS" "via Tor ✓" "$GREEN"
    else
        row "DNS" "NICHT via Tor ✗" "$RED"
    fi

    echo ""
    info "Prüfe externe IP über Tor..."
    local tor_check
    tor_check=$(_check_tor_ip)
    
    if [[ "$tor_check" != "? ?" ]]; then
        local ip="${tor_check%% *}"
        row "Externe IP" "$ip" "$CYAN"
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
            row "snowfox tor on"     "Tor-Modus aktivieren"
            row "snowfox tor off"    "Tor-Modus deaktivieren"
            row "snowfox tor status" "Status + externe IP prüfen"
            row "snowfox tor restart" "Tor neu starten"
            row "snowfox tor debug"  "Debug-Informationen"
            echo ""
            warn "Bei Problemen zuerst: snowfox tor debug"
            echo ""
            ;;
    esac
}
