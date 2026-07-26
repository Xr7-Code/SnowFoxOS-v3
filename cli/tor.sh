#!/bin/bash
# ============================================================
#  SnowFoxOS — CLI Modul: Tor & Anonymität
#  Wird von /usr/local/bin/snowfox gesourced.
# ============================================================

_tor_check_deps() {
    local missing=()
    for dep in tor torsocks macchanger; do
        command -v "$dep" &>/dev/null || missing+=("$dep")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        warn "Fehlende Pakete: ${missing[*]}"
        info "Installieren mit: sudo apt-get install -y ${missing[*]}"
        return 1
    fi
    return 0
}

_tor_status() {
    local tor_running=false
    local ipv6_disabled=false
    local mac_random=false
    local dns_tor=false

    systemctl is-active --quiet tor 2>/dev/null && tor_running=true
    [[ "$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6 2>/dev/null)" == "1" ]] && ipv6_disabled=true
    grep -q "^nameserver 127.0.0.1" /etc/resolv.conf 2>/dev/null && dns_tor=true

    echo "$tor_running $ipv6_disabled $dns_tor"
}

_tor_enable() {
    fox "Aktiviere Tor-Modus..."

    # ── 1. Tor starten ───────────────────────────────────────
    info "Starte Tor-Dienst..."
    sudo systemctl enable --now tor 2>/dev/null
    sleep 2
    if ! systemctl is-active --quiet tor; then
        err "Tor konnte nicht gestartet werden"
        err "Prüfe: sudo journalctl -u tor -n 20"
        return 1
    fi
    ok "Tor läuft (SOCKS5: 127.0.0.1:9050)"

    # ── 2. IPv6 deaktivieren ─────────────────────────────────
    # IPv6 leakt oft an Tor vorbei — komplett deaktivieren
    info "Deaktiviere IPv6..."
    sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1     &>/dev/null
    sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1 &>/dev/null
    sudo sysctl -w net.ipv6.conf.lo.disable_ipv6=1      &>/dev/null
    ok "IPv6 deaktiviert"

    # ── 3. DNS durch Tor leiten ──────────────────────────────
    # Tor lauscht auf 127.0.0.1:9053 für DNS — verhindert DNS-Leaks
    info "Leite DNS durch Tor..."
    # torrc.d/ existiert nicht auf allen Systemen — direkt in torrc schreiben
    sudo mkdir -p /etc/tor
    # Vorherige SnowFox-DNS-Einträge entfernen falls vorhanden
    sudo sed -i '/# SnowFox-DNS-Start/,/# SnowFox-DNS-Ende/d' /etc/tor/torrc 2>/dev/null || true
    sudo bash -c "cat >> /etc/tor/torrc << 'TOREOF'
# SnowFox-DNS-Start
DNSPort 9053
AutomapHostsOnResolve 1
AutomapHostsSuffixes .exit,.onion
# SnowFox-DNS-Ende
TOREOF"
    sudo systemctl restart tor 2>/dev/null
    sleep 1

    # resolv.conf auf Tor-DNS umstellen
    # Backup nur wenn noch nicht Tor-DNS
    if ! grep -q "127.0.0.1" /etc/resolv.conf 2>/dev/null; then
        sudo cp /etc/resolv.conf /etc/resolv.conf.snowfox-bak
    fi
    sudo bash -c "echo 'nameserver 127.0.0.1' > /etc/resolv.conf"
    # NetworkManager daran hindern resolv.conf zu überschreiben
    sudo chattr +i /etc/resolv.conf 2>/dev/null || true
    ok "DNS → Tor (127.0.0.1:9053, kein DNS-Leak)"

    # ── 4. MAC-Adresse randomisieren ─────────────────────────
    info "Randomisiere MAC-Adressen..."
    for iface in $(ip link show | awk -F': ' '/^[0-9]+: (en|wl|eth)/{print $2}'); do
        sudo ip link set "$iface" down 2>/dev/null
        sudo macchanger -r "$iface" 2>/dev/null | grep "New MAC" | \
            awk -v i="$iface" '{print "  " i ": " $3}'
        sudo ip link set "$iface" up 2>/dev/null
    done
    ok "MAC-Adressen randomisiert"

    # ── 5. Status speichern ──────────────────────────────────
    mkdir -p "$HOME/.config/snowfox"
    echo "tor" > "$HOME/.config/snowfox/tor-mode"

    divider
    ok "Tor-Modus aktiv"
    info "Nutze 'torsocks <programm>' für einzelne Anwendungen"
    info "oder setze in Anwendungen SOCKS5-Proxy: 127.0.0.1:9050"
    echo ""
    info "Deine Tor-IP prüfen:"
    info "  torsocks curl https://check.torproject.org/api/ip"
    echo ""
    warn "Browser: Nur Tor Browser schützt gegen Fingerprinting"
    warn "Tor Browser: https://www.torproject.org/download/"
    echo ""
}

_tor_disable() {
    fox "Deaktiviere Tor-Modus..."

    # ── DNS wiederherstellen ─────────────────────────────────
    info "Stelle DNS wieder her..."
    sudo chattr -i /etc/resolv.conf 2>/dev/null || true
    if [[ -f /etc/resolv.conf.snowfox-bak ]]; then
        sudo cp /etc/resolv.conf.snowfox-bak /etc/resolv.conf
        sudo rm -f /etc/resolv.conf.snowfox-bak
        ok "DNS wiederhergestellt"
    else
        # NetworkManager resolv.conf neu generieren lassen
        sudo systemctl restart NetworkManager 2>/dev/null
        ok "DNS über NetworkManager wiederhergestellt"
    fi

    # ── Tor-DNS-Config entfernen ─────────────────────────────
    # SnowFox-DNS-Einträge aus torrc entfernen
    sudo sed -i '/# SnowFox-DNS-Start/,/# SnowFox-DNS-Ende/d' /etc/tor/torrc 2>/dev/null || true
    sudo systemctl restart tor 2>/dev/null

    # ── IPv6 wieder aktivieren ───────────────────────────────
    info "Aktiviere IPv6 wieder..."
    sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0     &>/dev/null
    sudo sysctl -w net.ipv6.conf.default.disable_ipv6=0 &>/dev/null
    ok "IPv6 aktiv"

    # ── Tor stoppen ──────────────────────────────────────────
    info "Stoppe Tor..."
    sudo systemctl disable --now tor 2>/dev/null
    ok "Tor gestoppt"

    # ── Neue zufällige MAC nach Session ─────────────────────
    info "Randomisiere MAC erneut (sauberer Neustart)..."
    for iface in $(ip link show | awk -F': ' '/^[0-9]+: (en|wl|eth)/{print $2}'); do
        sudo ip link set "$iface" down 2>/dev/null
        sudo macchanger -r "$iface" &>/dev/null
        sudo ip link set "$iface" up 2>/dev/null
    done
    ok "MAC-Adressen erneut randomisiert"

    rm -f "$HOME/.config/snowfox/tor-mode"

    divider
    ok "Tor-Modus deaktiviert — normaler Betrieb"
    echo ""
}

_tor_check() {
    header "Tor Status"

    if [[ ! -f "$HOME/.config/snowfox/tor-mode" ]]; then
        row "Tor-Modus" "inaktiv" "$DGRAY"
        echo ""
        return
    fi

    # Tor-Dienst
    if systemctl is-active --quiet tor 2>/dev/null; then
        row "Tor-Dienst" "läuft" "$GREEN"
    else
        row "Tor-Dienst" "gestoppt" "$RED"
    fi

    # IPv6
    if [[ "$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6 2>/dev/null)" == "1" ]]; then
        row "IPv6" "deaktiviert ✓" "$GREEN"
    else
        row "IPv6" "aktiv — möglicher Leak!" "$RED"
    fi

    # DNS
    if grep -q "^nameserver 127.0.0.1" /etc/resolv.conf 2>/dev/null; then
        row "DNS" "durch Tor ✓" "$GREEN"
    else
        row "DNS" "NICHT durch Tor — DNS-Leak!" "$RED"
    fi

    # Externe IP über Tor
    info "Prüfe externe Tor-IP (braucht einen Moment)..."
    TOR_IP=$(torsocks curl -s --max-time 10 https://check.torproject.org/api/ip 2>/dev/null \
        | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('IP','?'))" 2>/dev/null \
        || echo "Timeout / nicht erreichbar")
    IS_TOR=$(torsocks curl -s --max-time 10 https://check.torproject.org/api/ip 2>/dev/null \
        | python3 -c "import sys,json; d=json.load(sys.stdin); print('ja' if d.get('IsTor') else 'nein')" 2>/dev/null \
        || echo "?")

    row "Externe IP" "$TOR_IP" "$CYAN"
    if [[ "$IS_TOR" == "ja" ]]; then
        row "Tor bestätigt" "ja ✓" "$GREEN"
    else
        row "Tor bestätigt" "nein — Traffic läuft NICHT durch Tor!" "$RED"
    fi

    echo ""
}

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
        *)
            header "snowfox tor"
            info "Verwendung:"
            echo ""
            row "snowfox tor on"     "Tor-Modus aktivieren (IP, DNS, MAC, IPv6)"
            row "snowfox tor off"    "Tor-Modus deaktivieren"
            row "snowfox tor status" "Aktuellen Status + externe IP prüfen"
            echo ""
            warn "Tor Browser für vollständige Anonymität im Browser empfohlen"
            echo ""
            ;;
    esac
}
