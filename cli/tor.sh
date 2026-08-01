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

# ─── Dependency Check ──────────────────────────────────────
_tor_check_deps() {
    local missing=()
    local deps=(tor torsocks macchanger curl python3)
    
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

# ─── Tor aktivieren ──────────────────────────────────────
_tor_enable() {
    fox "Aktiviere Tor-Modus..."

    # ── 1. Tor starten ──────────────────────────────────────
    info "Starte Tor-Dienst..."
    if ! sudo systemctl enable --now tor 2>/dev/null; then
        err "Tor konnte nicht aktiviert werden"
        err "Prüfe: sudo journalctl -u tor -n 20"
        return 1
    fi
    
    sleep 2
    if ! _tor_is_running; then
        err "Tor läuft nicht nach Aktivierung"
        return 1
    fi
    ok "Tor läuft (SOCKS5: 127.0.0.1:${TOR_SOCKS_PORT})"

    # ── 2. IPv6 deaktivieren ──────────────────────────────
    info "Deaktiviere IPv6 (verhindert Leaks)..."
    local ipv6_opts=(
        "net.ipv6.conf.all.disable_ipv6=1"
        "net.ipv6.conf.default.disable_ipv6=1"
        "net.ipv6.conf.lo.disable_ipv6=1"
    )
    for opt in "${ipv6_opts[@]}"; do
        sudo sysctl -w "$opt" &>/dev/null || warn "Konnte $opt nicht setzen"
    done
    ok "IPv6 deaktiviert"

    # ── 3. DNS durch Tor leiten ────────────────────────────
    info "Leite DNS durch Tor (Port ${TOR_DNS_PORT})..."
    sudo mkdir -p "$TOR_CONFIG_DIR"
    
    # Entferne alte SnowFox-Einträge sicher
    sudo sed -i '/# SnowFox-DNS-Start/,/# SnowFox-DNS-Ende/d' "$TORRC" 2>/dev/null || true
    
    # Füge neue DNS-Konfiguration hinzu
    sudo tee -a "$TORRC" > /dev/null <<TOREOF
# SnowFox-DNS-Start
DNSPort ${TOR_DNS_PORT}
AutomapHostsOnResolve 1
AutomapHostsSuffixes .exit,.onion
# SnowFox-DNS-Ende
TOREOF

    sudo systemctl restart tor 2>/dev/null
    sleep 2
    
    # DNS umstellen
    if ! _dns_via_tor; then
        sudo cp /etc/resolv.conf "$RESOLV_BAK" 2>/dev/null || true
    fi
    
    echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf > /dev/null
    sudo chattr +i /etc/resolv.conf 2>/dev/null || warn "Konnte resolv.conf nicht schützen"
    ok "DNS → Tor (keine DNS-Leaks)"

    # ── 4. MAC randomisieren ──────────────────────────────
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

    # ── 5. Status speichern ────────────────────────────────
    mkdir -p "$SNOWFOX_CONFIG_DIR"
    echo "tor" > "$TOR_MODE_FILE"
    chmod 600 "$TOR_MODE_FILE"

    # ── 6. Erfolgsmeldung ──────────────────────────────────
    divider
    ok "Tor-Modus erfolgreich aktiviert"
    info "Nutze 'torsocks <programm>' für einzelne Anwendungen"
    info "oder konfiguriere SOCKS5-Proxy: 127.0.0.1:${TOR_SOCKS_PORT}"
    echo ""
    info "Prüfe deine Tor-IP:"
    info "  torsocks curl https://check.torproject.org/api/ip"
    echo ""
    warn "Browser: Nutze den Tor Browser für vollständigen Schutz"
    warn "Tor Browser: https://www.torproject.org/download/"
    echo ""
}

# ─── Tor deaktivieren ──────────────────────────────────────
_tor_disable() {
    fox "Deaktiviere Tor-Modus..."

    # ── 1. DNS wiederherstellen ────────────────────────────
    info "Stelle DNS wieder her..."
    sudo chattr -i /etc/resolv.conf 2>/dev/null || true
    
    if [[ -f "$RESOLV_BAK" ]]; then
        sudo cp "$RESOLV_BAK" /etc/resolv.conf
        sudo rm -f "$RESOLV_BAK"
        ok "DNS aus Backup wiederhergestellt"
    elif command -v NetworkManager &>/dev/null; then
        sudo systemctl restart NetworkManager 2>/dev/null
        ok "DNS über NetworkManager wiederhergestellt"
    else
        warn "Kein DNS-Backup gefunden, manuelle Wiederherstellung erforderlich"
    fi

    # ── 2. Tor-DNS-Config entfernen ──────────────────────
    sudo sed -i '/# SnowFox-DNS-Start/,/# SnowFox-DNS-Ende/d' "$TORRC" 2>/dev/null || true
    sudo systemctl restart tor 2>/dev/null

    # ── 3. IPv6 reaktivieren ──────────────────────────────
    info "Aktiviere IPv6 wieder..."
    local ipv6_opts=(
        "net.ipv6.conf.all.disable_ipv6=0"
        "net.ipv6.conf.default.disable_ipv6=0"
    )
    for opt in "${ipv6_opts[@]}"; do
        sudo sysctl -w "$opt" &>/dev/null || warn "Konnte $opt nicht setzen"
    done
    ok "IPv6 reaktiviert"

    # ── 4. Tor stoppen ─────────────────────────────────────
    info "Stoppe Tor-Dienst..."
    sudo systemctl disable --now tor 2>/dev/null
    ok "Tor gestoppt"

    # ── 5. MAC randomisieren ──────────────────────────────
    info "Randomisiere MAC neu (Cleanup)..."
    for iface in $(_get_network_interfaces); do
        _randomize_mac "$iface" &>/dev/null || true
    done
    ok "MAC-Adressen erneuert"

    # ── 6. Cleanup ──────────────────────────────────────────
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
            _tor_check_deps || return 1
            _tor_enable
            ;;
        *)
            header "snowfox tor — Anonymitätsmodus"
            info "Verwendung:"
            echo ""
            row "snowfox tor on"     "Tor-Modus aktivieren (VPN-ähnlich)"
            row "snowfox tor off"    "Tor-Modus deaktivieren"
            row "snowfox tor status" "Status + externe IP prüfen"
            row "snowfox tor restart" "Tor neu starten"
            echo ""
            warn "Hinweise:"
            info "• Tor Browser für Browser-Anonymität empfohlen"
            info "• torsocks für CLI-Anwendungen: torsocks curl ifconfig.me"
            info "• SOCKS5-Proxy: 127.0.0.1:${TOR_SOCKS_PORT}"
            echo ""
            ;;
    esac
}
