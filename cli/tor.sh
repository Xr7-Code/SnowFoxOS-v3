#!/bin/bash
# ============================================================
#  SnowFoxOS — Tor Modul (VOLLAUTOMATISCH mit Fehlerkorrektur)
#  Wird von /usr/local/bin/snowfox gesourced.
# ============================================================

# ─── Konstanten ──────────────────────────────────────────────
readonly TOR_SOCKS="9050"
readonly TOR_DNS="9053"
readonly TOR_CONFIG_DIR="/etc/tor"
readonly TORRC="${TOR_CONFIG_DIR}/torrc"
readonly SNOWFOX_CONFIG_DIR="${HOME}/.config/snowfox"
readonly TOR_MODE_FILE="${SNOWFOX_CONFIG_DIR}/tor-mode"
readonly RESOLV_BAK="/etc/resolv.conf.snowfox-bak"
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

# ─── HELPER: Automatischer Fix für Tor-Service ────────────
_tor_fix_service() {
    info "Prüfe Tor-Service..."
    
    # Prüfe ob tor-snowfox.service existiert
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
    
    # Prüfe ob Tor läuft
    if ! _tor_service_running; then
        info "Starte Tor-Service..."
        sudo systemctl start "$TOR_SERVICE" 2>/dev/null || {
            warn "Konnte Service nicht starten, starte Tor direkt..."
            sudo -u debian-tor tor -f "$TORRC" > /dev/null 2>&1 &
        }
        sleep 3
    fi
    
    # Prüfe ob Tor wirklich läuft
    if ! _tor_service_running && ! pgrep -f "tor.*torrc" > /dev/null; then
        err "Tor läuft nicht! Starte manuell:"
        echo "  sudo systemctl start $TOR_SERVICE"
        echo "  oder: sudo -u debian-tor tor -f $TORRC"
        return 1
    fi
    
    # Prüfe Ports
    if ! _tor_port_open "$TOR_SOCKS"; then
        warn "SOCKS5-Port $TOR_SOCKS nicht erreichbar. Warte..."
        sleep 5
        if ! _tor_port_open "$TOR_SOCKS"; then
            err "Tor läuft nicht richtig auf Port $TOR_SOCKS"
            return 1
        fi
    fi
    
    ok "Tor-Service läuft ✓"
    return 0
}

# ─── HELPER: Automatischer Fix für Torrc ──────────────────
_tor_fix_torrc() {
    info "Prüfe Torrc-Konfiguration..."
    local needs_fix=false
    
    # Prüfe ob Torrc existiert
    if [[ ! -f "$TORRC" ]]; then
        warn "Torrc nicht gefunden. Erstelle..."
        needs_fix=true
    fi
    
    # Prüfe ob DNSPort konfiguriert ist
    if ! grep -q "^DNSPort" "$TORRC" 2>/dev/null; then
        warn "DNSPort fehlt in Torrc"
        needs_fix=true
    fi
    
    # Prüfe ob SocksPort konfiguriert ist
    if ! grep -q "^SocksPort" "$TORRC" 2>/dev/null; then
        warn "SocksPort fehlt in Torrc"
        needs_fix=true
    fi
    
    if [[ "$needs_fix" == true ]]; then
        info "Erstelle korrekte Torrc..."
        
        # Backup der alten Torrc
        sudo cp "$TORRC" "${TORRC}.old" 2>/dev/null || true
        
        sudo tee "$TORRC" > /dev/null << 'EOF'
## SnowFoxOS Tor Configuration (AUTO-FIXED)

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

# Performance
CircuitBuildTimeout 60
NumEntryGuards 4

# Vermeide problematische Exit-Nodes
ExcludeExitNodes {ad},{ae},{af},{ag},{al},{am},{az},{ba},{bd},{bn},{bo},{bt},{bw},{by},{bz},{cd},{cf},{cg},{ci},{cm},{cn},{cu},{cy},{dj},{dz},{ec},{eg},{er},{et},{fj},{ge},{gh},{gm},{gn},{gq},{gt},{gw},{gy},{hn},{ht},{id},{in},{iq},{ir},{jo},{ke},{kg},{kh},{ki},{km},{kp},{kw},{kz},{la},{lb},{lk},{lr},{ls},{ly},{ma},{md},{me},{mg},{mk},{ml},{mm},{mn},{mr},{mt},{mu},{mv},{mw},{mx},{my},{mz},{na},{ne},{ng},{ni},{np},{pk},{py},{rs},{ru},{rw},{sa},{sb},{sd},{si},{sk},{sl},{sn},{so},{sr},{ss},{sv},{sy},{sz},{td},{tg},{th},{tj},{tm},{tn},{to},{tr},{tt},{tz},{ug},{uz},{ve},{vn},{vu},{ye},{za},{zm},{zw}
StrictNodes 1
EOF

        sudo chown debian-tor:debian-tor "$TORRC"
        sudo chmod 644 "$TORRC"
        ok "Torrc korrigiert"
        
        # Service neu starten
        sudo systemctl restart "$TOR_SERVICE" 2>/dev/null || sudo pkill -f "tor.*torrc"
        sleep 3
    else
        ok "Torrc ist korrekt ✓"
    fi
    
    return 0
}

# ─── HELPER: Automatischer Fix für DNS ────────────────────
_tor_fix_dns() {
    info "Prüfe DNS-Konfiguration..."
    
    # Teste DNS über Tor
    if dig @"127.0.0.1" -p "$TOR_DNS" google.com +short 2>/dev/null | grep -qE '^[0-9.]+$'; then
        ok "DNS über Tor funktioniert ✓"
        
        # Stelle sicher dass resolv.conf auf Tor zeigt
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
        
        # Fallback: Standard-DNS mit torsocks
        if [[ -f "$RESOLV_BAK" ]]; then
            sudo cp "$RESOLV_BAK" /etc/resolv.conf
        else
            echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf > /dev/null
            echo "nameserver 1.1.1.1" | sudo tee -a /etc/resolv.conf > /dev/null
        fi
        sudo chattr -i /etc/resolv.conf 2>/dev/null || true
        warn "DNS auf Standard zurückgesetzt (HTTP über Tor funktioniert trotzdem)"
        return 0
    fi
}

# ─── HELPER: Automatischer Fix für IPv6 ───────────────────
_tor_fix_ipv6() {
    info "Prüfe IPv6-Konfiguration..."
    
    if _ipv6_is_disabled; then
        ok "IPv6 bereits deaktiviert ✓"
        return 0
    fi
    
    info "Deaktiviere IPv6 (verhindert Leaks)..."
    sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1 &>/dev/null
    sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1 &>/dev/null
    sudo sysctl -w net.ipv6.conf.lo.disable_ipv6=1 &>/dev/null
    
    # Persistente Konfiguration
    if ! grep -q "net.ipv6.conf.all.disable_ipv6=1" /etc/sysctl.conf 2>/dev/null; then
        echo "net.ipv6.conf.all.disable_ipv6=1" | sudo tee -a /etc/sysctl.conf > /dev/null
    fi
    
    ok "IPv6 deaktiviert ✓"
    return 0
}

# ─── HELPER: Automatischer Fix für MAC ────────────────────
_tor_fix_mac() {
    info "Randomisiere MAC-Adressen..."
    local mac_count=0
    
    for iface in $(_get_network_interfaces); do
        if _randomize_mac "$iface"; then
            ((mac_count++))
        else
            warn "Konnte MAC für $iface nicht randomisieren"
        fi
    done
    
    if [[ $mac_count -gt 0 ]]; then
        ok "${mac_count} MAC-Adresse(n) randomisiert ✓"
    else
        warn "Keine MAC-Adressen randomisiert"
    fi
    return 0
}

# ─── HELPER: Tor Verbindung testen ────────────────────────
_tor_test_connection() {
    info "Teste Tor-Verbindung..."
    sleep 2
    
    local tor_ip
    local services=(
        "https://icanhazip.com"
        "https://check.torproject.org/api/ip"
        "https://api.ipify.org"
    )
    
    for service in "${services[@]}"; do
        tor_ip=$(torsocks curl -s --max-time 5 "$service" 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
        if [[ -n "$tor_ip" ]]; then
            ok "Tor-IP: $tor_ip ✓"
            return 0
        fi
    done
    
    warn "Verbindungstest fehlgeschlagen, aber Tor läuft möglicherweise"
    info "Manueller Test: torsocks curl https://icanhazip.com"
    return 1
}

# ─── Hauptfunktion: Tor aktivieren (mit automatischen Fixes) ──
_tor_enable() {
    fox "Aktiviere Tor-Modus mit automatischer Fehlerkorrektur..."

    # ── 1. Dependencies prüfen ──────────────────────────────
    _tor_check_deps || return 1

    # ── 2. Torrc fixen ──────────────────────────────────────
    _tor_fix_torrc || return 1

    # ── 3. Tor-Service fixen ────────────────────────────────
    _tor_fix_service || return 1

    # ── 4. IPv6 fixen ──────────────────────────────────────
    _tor_fix_ipv6 || return 1

    # ── 5. DNS fixen ────────────────────────────────────────
    _tor_fix_dns || return 1

    # ── 6. MAC randomisieren ────────────────────────────────
    _tor_fix_mac || return 1

    # ── 7. Verbindung testen ────────────────────────────────
    _tor_test_connection

    # ── 8. Status speichern ──────────────────────────────────
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
    info "Service: $TOR_SERVICE (läuft automatisch)"
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

    # ── 2. IPv6 reaktivieren ──────────────────────────────────
    info "Aktiviere IPv6 wieder..."
    sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0 &>/dev/null
    sudo sysctl -w net.ipv6.conf.default.disable_ipv6=0 &>/dev/null
    ok "IPv6 reaktiviert"

    # ── 3. MAC randomisieren ──────────────────────────────────
    info "Randomisiere MAC neu (Cleanup)..."
    for iface in $(_get_network_interfaces); do
        _randomize_mac "$iface" &>/dev/null || true
    done
    ok "MAC-Adressen erneuert"

    # ── 4. Status löschen ────────────────────────────────────
    rm -f "$TOR_MODE_FILE"

    divider
    ok "Tor-Modus deaktiviert"
    info "Tor-Service läuft weiter ($TOR_SERVICE)"
    info "Zum vollständigen Stoppen: sudo systemctl stop $TOR_SERVICE"
    echo ""
}

# ─── Tor Status anzeigen ──────────────────────────────────
_tor_status() {
    header "Tor Status"
    
    if [[ ! -f "$TOR_MODE_FILE" ]]; then
        row "Tor-Modus" "inaktiv" "$DGRAY"
        echo ""
        info "Aktivieren mit: snowfox tor on"
        return
    fi

    # Service Status
    if _tor_service_running; then
        row "Tor-Dienst" "läuft ✓" "$GREEN"
        row "Service" "$TOR_SERVICE" "$CYAN"
    else
        row "Tor-Dienst" "gestoppt ✗" "$RED"
        warn "Starte: sudo systemctl start $TOR_SERVICE"
    fi

    # SOCKS5
    if _tor_port_open "$TOR_SOCKS"; then
        row "SOCKS5" "127.0.0.1:${TOR_SOCKS} ✓" "$GREEN"
    else
        row "SOCKS5" "nicht erreichbar ✗" "$RED"
    fi

    # DNS
    if _tor_port_open "$TOR_DNS"; then
        row "DNS" "127.0.0.1:${TOR_DNS} ✓" "$GREEN"
    else
        row "DNS" "nicht erreichbar ✗" "$RED"
    fi

    # IPv6
    if _ipv6_is_disabled; then
        row "IPv6" "deaktiviert ✓" "$GREEN"
    else
        row "IPv6" "aktiv — möglicher Leak!" "$RED"
    fi

    # DNS Konfiguration
    if _dns_via_tor; then
        row "DNS-Config" "via Tor ✓" "$GREEN"
    else
        row "DNS-Config" "Standard DNS" "$YELLOW"
    fi

    # Externe IP
    echo ""
    info "Prüfe externe IP über Tor..."
    local tor_ip
    tor_ip=$(torsocks curl -s --max-time 5 https://icanhazip.com 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}')
    
    if [[ -n "$tor_ip" ]]; then
        row "Tor-IP" "$tor_ip" "$GREEN"
    else
        row "Tor-IP" "❌ Nicht erreichbar" "$RED"
    fi
    
    echo ""
}

# ─── Tor Debug (mit automatischen Fixes) ──────────────────
_tor_debug() {
    header "Tor Debug mit automatischer Fehlererkennung"
    
    # 1. Service prüfen
    echo "1. Service Status:"
    if _tor_service_running; then
        echo "   ✅ tor-snowfox.service läuft"
    else
        echo "   ❌ tor-snowfox.service läuft NICHT"
        echo "   🔧 Führe Fix aus..."
        _tor_fix_service
    fi
    echo ""
    
    # 2. Ports prüfen
    echo "2. Ports:"
    for port in "$TOR_SOCKS" "$TOR_DNS"; do
        if _tor_port_open "$port"; then
            echo "   ✅ Port $port offen"
        else
            echo "   ❌ Port $port geschlossen"
        fi
    done
    echo ""
    
    # 3. Torrc prüfen
    echo "3. Torrc:"
    if [[ -f "$TORRC" ]]; then
        echo "   ✅ Torrc existiert"
        grep -E "^SocksPort|^DNSPort|^AutomapHosts" "$TORRC" 2>/dev/null || echo "   ⚠️  Keine relevanten Einträge"
    else
        echo "   ❌ Torrc fehlt"
        _tor_fix_torrc
    fi
    echo ""
    
    # 4. DNS prüfen
    echo "4. DNS:"
    if _dns_via_tor; then
        echo "   ✅ DNS über Tor aktiviert"
    else
        echo "   ⚠️  DNS nicht über Tor"
        _tor_fix_dns
    fi
    echo ""
    
    # 5. IPv6 prüfen
    echo "5. IPv6:"
    if _ipv6_is_disabled; then
        echo "   ✅ IPv6 deaktiviert"
    else
        echo "   ⚠️  IPv6 aktiv (möglicher Leak!)"
        _tor_fix_ipv6
    fi
    echo ""
    
    # 6. Verbindung testen
    echo "6. Verbindung:"
    _tor_test_connection
    echo ""
    
    # 7. Tor Logs
    echo "7. Letzte Tor Logs:"
    sudo journalctl -u "$TOR_SERVICE" -n 5 --no-pager 2>/dev/null || echo "Keine Logs verfügbar"
    echo ""
    
    echo "=== Debug abgeschlossen ==="
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
        debug)
            _tor_debug
            ;;
        fix)
            header "Tor Auto-Fix"
            info "Führe automatische Fehlerkorrektur durch..."
            _tor_fix_torrc
            _tor_fix_service
            _tor_fix_ipv6
            _tor_fix_dns
            _tor_fix_mac
            _tor_test_connection
            divider
            ok "Alle Fixes angewendet! 🦊"
            echo ""
            ;;
        *)
            header "snowfox tor — Anonymitätsmodus"
            info "Verwendung:"
            echo ""
            row "snowfox tor on"     "Tor-Modus aktivieren (mit Auto-Fix)"
            row "snowfox tor off"    "Tor-Modus deaktivieren"
            row "snowfox tor status" "Status anzeigen"
            row "snowfox tor restart" "Tor neu starten"
            row "snowfox tor debug"  "Debug mit Fehlererkennung"
            row "snowfox tor fix"    "Alle Fixes manuell ausführen"
            echo ""
            info "Tor-Service: $TOR_SERVICE"
            info "SOCKS5: 127.0.0.1:${TOR_SOCKS}"
            info "DNS: 127.0.0.1:${TOR_DNS}"
            echo ""
            warn "Bei Problemen: snowfox tor debug"
            echo ""
            ;;
    esac
}
