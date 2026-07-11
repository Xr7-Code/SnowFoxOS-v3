#!/bin/bash
# ============================================================
#  SnowFox Mesh - Universelles P2P-Netzwerk
#  Version: 5.0 - Vollständig & Stabil
#  Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)
# ============================================================

# ── PATH für System-Tools ──
export PATH="$PATH:/usr/sbin:/sbin:/usr/local/sbin"

# ── Farben & Funktionen ──
PURPLE='\033[0;35m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
BOLD='\033[1m'
RESET='\033[0m'

fox()    { echo -e "${PURPLE}${BOLD}[🦊 SnowFox]${RESET} $1"; }
ok()     { echo -e "${GREEN}${BOLD}[  OK  ]${RESET} $1"; }
warn()   { echo -e "${ORANGE}${BOLD}[ WARN ]${RESET} $1"; }
err()    { echo -e "${RED}${BOLD}[ERROR]${RESET} $1"; }
info()   { echo -e "${CYAN}$1${RESET}"; }
divider(){ echo -e "${PURPLE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"; }

set -euo pipefail

# ── Konfiguration ──
MESH_DIR="$HOME/.config/snowfox/mesh"
MESH_CONFIG="$MESH_DIR/config"
MESH_NODES="$MESH_DIR/nodes.json"
MESH_MESSAGES="$MESH_DIR/messages"
MESH_SHARE="$HOME/Downloads/MeshShare"
MESH_BROADCAST="$MESH_DIR/broadcast.log"
MESH_CATALOG="$MESH_DIR/catalog.json"
MESH_PID_FILE="$MESH_DIR/mesh.pid"
MESH_PSK_FILE="$MESH_DIR/psk.key"
MESH_IDENTITY="$MESH_DIR/identity.json"
MESH_TEMP="$MESH_DIR/temp"
MESH_STATE="$MESH_DIR/mesh.state"
RETICULUM_CFG="$HOME/.reticulum/config"
MESH_LOCK="$MESH_DIR/mesh.lock"
NM_BACKUP="$MESH_DIR/nm.backup"
MESH_SERVICES_PID="$MESH_DIR/services.pid"
MESH_WEB_PID="$MESH_DIR/web.pid"
MESH_WEB_PORT=8080

# ──────────────────────────────────────────────────────────────
#  Prüfungen & Abhängigkeiten
# ──────────────────────────────────────────────────────────────

_mesh_check_deps() {
    local missing=()
    
    # Python und Reticulum prüfen
    if ! command -v python3 &>/dev/null; then
        missing+=("python3")
    else
        if ! python3 -c "import RNS" 2>/dev/null; then
            warn "Reticulum (RNS) nicht installiert!"
            info "  Installieren: ${CYAN}pip3 install rns --break-system-packages${RESET}"
            missing+=("rns")
        fi
    fi
    
    # iw mit vollem Pfad prüfen
    if ! command -v iw &>/dev/null && ! [[ -x /usr/sbin/iw ]] && ! [[ -x /sbin/iw ]]; then
        missing+=("iw")
    fi
    
    # nmcli mit vollem Pfad prüfen
    if ! command -v nmcli &>/dev/null && ! [[ -x /usr/bin/nmcli ]]; then
        missing+=("nmcli")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        err "Fehlende Abhängigkeiten: ${missing[*]}"
        info ""
        info "  Installieren:"
        info "    ${CYAN}sudo apt-get install -y iw wireless-tools network-manager${RESET}"
        info "    ${CYAN}pip3 install rns --break-system-packages${RESET}"
        return 1
    fi
    
    return 0
}

# ──────────────────────────────────────────────────────────────
#  Interface finden
# ──────────────────────────────────────────────────────────────

_mesh_find_interface() {
    local iface=""
    
    # 1. iw dev
    iface=$(iw dev 2>/dev/null | awk '$1=="Interface"{print $2}' | head -1)
    
    # 2. ip link (WLAN)
    if [[ -z "$iface" ]]; then
        iface=$(ip link show | grep -E '^[0-9]+: wl' | grep -v lo | head -1 | cut -d: -f2 | xargs)
    fi
    
    # 3. ip link (Ethernet)
    if [[ -z "$iface" ]]; then
        iface=$(ip link show | grep -E '^[0-9]+: en' | grep -v lo | head -1 | cut -d: -f2 | xargs)
    fi
    
    echo "$iface"
}

# ──────────────────────────────────────────────────────────────
#  NetworkManager-Zustand speichern
# ──────────────────────────────────────────────────────────────

_mesh_save_nm_state() {
    local interface="$1"
    mkdir -p "$MESH_DIR"
    
    {
        echo "INTERFACE=$interface"
        echo "NM_MANAGED=$(nmcli device show "$interface" 2>/dev/null | grep -i "managed" | awk '{print $2}' || echo "yes")"
        echo "NM_CONNECTED=$(nmcli -t -f GENERAL.STATE device show "$interface" 2>/dev/null | cut -d: -f2 || echo "unknown")"
        echo "NM_CONNECTION=$(nmcli -t -f GENERAL.CONNECTION device show "$interface" 2>/dev/null | cut -d: -f2 || echo "")"
    } > "$NM_BACKUP"
    
    ok "NetworkManager-Zustand gesichert"
}

# ──────────────────────────────────────────────────────────────
#  NetworkManager wiederherstellen
# ──────────────────────────────────────────────────────────────

_mesh_restore_nm_state() {
    if [[ ! -f "$NM_BACKUP" ]]; then
        warn "Kein NetworkManager-Backup gefunden"
        return 0
    fi
    
    local INTERFACE=""
    local NM_CONNECTION=""
    source "$NM_BACKUP" 2>/dev/null || true
    
    if [[ -n "$INTERFACE" ]]; then
        info "Stelle NetworkManager für $INTERFACE wieder her..."
        
        sudo nmcli device set "$INTERFACE" managed yes 2>/dev/null || true
        sudo systemctl restart NetworkManager 2>/dev/null || true
        sleep 2
        
        if [[ -n "$NM_CONNECTION" ]] && [[ "$NM_CONNECTION" != "--" ]]; then
            info "Stelle Verbindung '$NM_CONNECTION' wieder her..."
            sudo nmcli device connect "$INTERFACE" 2>/dev/null || true
        fi
        
        ok "NetworkManager wiederhergestellt"
        rm -f "$NM_BACKUP"
    fi
}

# ──────────────────────────────────────────────────────────────
#  Identity - Node benennen
# ──────────────────────────────────────────────────────────────

_mesh_identity() {
    local name="${1:-}"
    local type="${2:-node}"
    local location="${3:-}"
    
    mkdir -p "$MESH_DIR"
    
    if [[ -z "$name" ]]; then
        echo ""
        info "Gib deine Node-Identität ein:"
        read -rp "  Name (z.B. 'Server-01', 'Müller-Haus'): " name
        read -rp "  Typ (z.B. 'server', 'haus', 'mobil'): " type
        [[ -z "$type" ]] && type="node"
        read -rp "  Standort (optional): " location
    fi
    
    local node_id=""
    node_id=$(rnx --id 2>/dev/null | head -1 | tr -d '[]' || echo "unknown")
    
    cat > "$MESH_IDENTITY" << EOF
{
    "name": "$name",
    "type": "$type",
    "location": "$location",
    "node_id": "$node_id",
    "joined": "$(date -Iseconds)",
    "ip": "$(hostname -I | awk '{print $1}')"
}
EOF
    
    chmod 600 "$MESH_IDENTITY"
    ok "Identität gesetzt: ${BOLD}$name${RESET} (${type})${location:+, $location}"
}

# ──────────────────────────────────────────────────────────────
#  Reticulum starten
# ──────────────────────────────────────────────────────────────

_mesh_start_reticulum() {
    local interface="$1"
    local psk="$2"
    
    mkdir -p "$HOME/.reticulum"
    
    # Reticulum-Config
    # WICHTIG: AutoInterface unterstützt KEINEN 'interface'-Parameter!
    # AutoInterface erkennt automatisch alle verfügbaren Netzwerk-Interfaces.
    # Ein falscher 'interface'-Parameter verursacht die "could not autoconfigure"-Warnung.
    cat > "$RETICULUM_CFG" << EOF
[reticulum]
  enable_transport = True
  share_instance = Yes
  shared_instance_port = 37428
  instance_control_port = 37429
  panic_on_interface_error = No
  loglevel = 2

[logging]
  loglevel = 2

[interfaces]

  [[Mesh Interface]]
    type = AutoInterface
    interface_enabled = True
    group_id = snowfox_mesh
    discovery_scope = link
    discovery_port = 29716
    data_port = 42671
EOF

    if [[ -n "$psk" ]]; then
        echo "    preshared_key = ${psk}" >> "$RETICULUM_CFG"
    fi

    # Keine 'interface = ...' Zeile für AutoInterface! Das ist ein Bug gewesen.

    if [[ -n "$lora_port" ]]; then
        cat >> "$RETICULUM_CFG" << EOF

  [[LoRa Interface]]
    type = RNodeInterface
    interface_enabled = True
    device = ${lora_port}
    frequency = 868.1
    bandwidth = 125.0
    sf = 12
    cr = 5
    tx_power = 17
EOF
        if [[ -n "$psk" ]]; then
            echo "    preshared_key = ${psk}" >> "$RETICULUM_CFG"
        fi
    fi
    
    # Vorhandenen rnsd vollstaendig beenden
    # Zuerst sanft per TERM, dann hart per KILL
    pkill -TERM -f "rnsd" 2>/dev/null || true
    sleep 2
    pkill -KILL -f "rnsd" 2>/dev/null || true
    sleep 1

    # Reticulum shared-instance Ports (37428/37429) aktiv schliessen
    # Das verhindert "digest rejected" von alten Instanzen
    for port in 37428 37429; do
        local pid_on_port=""
        pid_on_port=$(ss -tlnp "sport = :$port" 2>/dev/null | grep -oP "pid=\K[0-9]+" | head -1 || true)
        if [[ -n "$pid_on_port" ]]; then
            kill -9 "$pid_on_port" 2>/dev/null || true
        fi
    done

    # Reticulum Lock-Dateien entfernen
    rm -f "$HOME/.reticulum/rnsd.lock" 2>/dev/null || true

    # Sicherstellen dass wirklich kein rnsd mehr läuft
    local kill_wait=0
    while pgrep -f "rnsd" >/dev/null 2>&1 && [[ $kill_wait -lt 5 ]]; do
        sleep 1
        ((kill_wait++))
    done
    nohup rnsd --config "$HOME/.reticulum" >> "$MESH_DIR/mesh.log" 2>&1 &
    local rnsd_pid=$!
    echo "$rnsd_pid" > "$MESH_PID_FILE"
    
    # Timeout für rnsd-Start
    # Warten bis rnsd läuft (kill -0 = Prozess existiert noch)
    local timeout=10
    local waited=0
    while ! kill -0 "$rnsd_pid" 2>/dev/null; do
        sleep 1
        ((waited++))
        if [[ $waited -ge $timeout ]]; then
            err "Reticulum konnte nicht starten (Timeout nach ${timeout}s)"
            tail -20 "$MESH_DIR/mesh.log"
            return 1
        fi
    done
    # Kurz warten damit rnsd sich initialisieren kann
    sleep 2
    
    ok "Reticulum-Daemon gestartet (PID $rnsd_pid)"
    return 0
}

# ──────────────────────────────────────────────────────────────
#  QR-Code generieren
# ──────────────────────────────────────────────────────────────

_mesh_qr() {
    local ssid="$1"
    local password="$2"
    local ip="${3:-10.42.0.1}"
    
    if ! command -v qrencode &>/dev/null; then
        warn "qrencode nicht installiert - QR-Code wird nicht angezeigt"
        info "  Installieren: ${CYAN}sudo apt-get install -y qrencode${RESET}"
        return 1
    fi
    
    # WLAN QR-Code (WPA/WPA2)
    local wifi_string="WIFI:T:WPA;S:${ssid};P:${password};;"
    
    echo ""
    echo -e "${CYAN}${BOLD}  📱 QR-Code für Handy-Verbindung${RESET}"
    echo -e "${GRAY}  Scanne mit der Kamera (iOS/Android)${RESET}"
    echo ""
    
    # QR-Code in ASCII ausgeben
    qrencode -t ansiutf8 -m 2 "$wifi_string"
    
    echo ""
    echo -e "${GRAY}  Alternativ: Manuell verbinden${RESET}"
    echo -e "    SSID:     ${CYAN}$ssid${RESET}"
    echo -e "    Passwort: ${CYAN}$password${RESET}"
    echo -e "    Web:      ${CYAN}http://$ip:$MESH_WEB_PORT${RESET}"
    echo ""
}

# ──────────────────────────────────────────────────────────────
#  Python Broadcast-Hilfsfunktion
# ──────────────────────────────────────────────────────────────

_mesh_python_broadcast() {
    local message="$1"
    python3 - "$message" <<'PYEOF'
import RNS
import sys
import time

message = sys.argv[1]

try:
    reticulum = RNS.Reticulum()
    identity = RNS.Identity()
    
    dest = RNS.Destination(
        identity,
        RNS.Destination.OUT,
        RNS.Destination.SINGLE,
        "snowfox_mesh_chat"
    )
    
    packet = RNS.Packet(dest, message.encode('utf-8'))
    receipt = packet.send()
    
    if not receipt:
        print("  ⚠️ Broadcast konnte nicht gesendet werden")
    
except Exception as e:
    print(f"  ❌ Broadcast-Fehler: {e}")
PYEOF
}

# ──────────────────────────────────────────────────────────────
#  Web-Interface (für Handys) - Verbesserte Version
# ──────────────────────────────────────────────────────────────

_mesh_web() {
    local port="${1:-8080}"
    local token="${2:-}"
    local interface="${3:-}"
    
    # Prüfen ob Port frei ist: Exit 0 = bind erfolgreich = Port frei
    # Exit != 0 = bind fehlgeschlagen = Port belegt
    while ! python3 -c "
import socket, sys
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 0)
try:
    s.bind(('', $port))
    s.close()
    sys.exit(0)
except OSError:
    s.close()
    sys.exit(1)
" 2>/dev/null; do
        warn "Port $port bereits belegt, versuche $((port+1))..."
        ((port++))
        if [[ $port -gt 9000 ]]; then
            err "Kein freier Port gefunden!"
            return 1
        fi
    done
    
    cat > /tmp/mesh-web.html << 'HTML'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🦊 SnowFox Mesh</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, sans-serif; background: #0d0d1a; color: #e4e4e7; padding: 16px; }
        .chat { max-width: 600px; margin: 0 auto; background: #1a1a2e; border-radius: 16px; padding: 16px; height: 90vh; display: flex; flex-direction: column; }
        h1 { color: #bc95ff; font-size: 20px; margin-bottom: 12px; display: flex; align-items: center; gap: 8px; }
        .status-badge { font-size: 12px; background: #2a2a44; padding: 2px 10px; border-radius: 12px; color: #4ade80; }
        #messages { flex: 1; overflow-y: auto; padding: 8px; background: #12121f; border-radius: 8px; margin-bottom: 12px; }
        .msg { padding: 6px 0; border-bottom: 1px solid #1f1f33; }
        .sender { color: #bc95ff; font-weight: bold; }
        .own { color: #89dceb; }
        .time { color: #555; font-size: 11px; margin-left: 8px; }
        .input-row { display: flex; gap: 8px; }
        .input-row input { flex: 1; padding: 10px; border-radius: 8px; border: none; background: #2a2a44; color: white; font-size: 16px; }
        .input-row button { padding: 10px 20px; border-radius: 8px; border: none; background: #bc95ff; color: #0d0d1a; font-weight: bold; font-size: 16px; cursor: pointer; }
        .status { color: #4ade80; font-size: 12px; margin-top: 8px; text-align: center; }
    </style>
</head>
<body>
<div class="chat">
    <h1>
        🦊 SnowFox Mesh
        <span class="status-badge">● Live</span>
    </h1>
    <div id="messages">
        <div class="msg"><span class="sender">🦊 System:</span> Verbunden mit dem Mesh!</div>
    </div>
    <div class="input-row">
        <input type="text" id="msg" placeholder="Nachricht..." autofocus>
        <button onclick="sendMsg()">📤</button>
    </div>
    <div class="status" id="status">Bereit</div>
</div>
<script>
    const msgInput = document.getElementById('msg');
    const messages = document.getElementById('messages');
    const status = document.getElementById('status');
    let lastMsgCount = 0;

    function sendMsg() {
        const msg = msgInput.value.trim();
        if (!msg) return;
        status.textContent = '📤 Sende...';
        
        fetch('/send?msg=' + encodeURIComponent(msg))
            .then(r => r.text())
            .then(() => {
                addMessage('Du', msg, true);
                msgInput.value = '';
                status.textContent = '✅ Gesendet';
                setTimeout(() => status.textContent = 'Bereit', 1500);
            })
            .catch(() => status.textContent = '❌ Fehler');
    }

    function addMessage(sender, text, own, time) {
        const div = document.createElement('div');
        div.className = 'msg';
        const ts = time ? ' <span class="time">' + time + '</span>' : '';
        div.innerHTML = `<span class="sender ${own ? 'own' : ''}">${sender}:</span> ${text}${ts}`;
        messages.appendChild(div);
        messages.scrollTop = messages.scrollHeight;
    }

    msgInput.addEventListener('keypress', e => { if (e.key === 'Enter') sendMsg(); });
    msgInput.focus();

    setInterval(() => {
        fetch('/poll?last=' + lastMsgCount)
            .then(r => r.json())
            .then(data => {
                data.forEach(m => {
                    addMessage(m.sender, m.text, false, m.time);
                });
                lastMsgCount += data.length;
            })
            .catch(() => {});
    }, 3000);
</script>
</body>
</html>
HTML

    # Aktuelle IP für Anzeige ermitteln
    local web_ip=""
    web_ip=$(ip addr show "$interface" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1 || echo "10.42.0.1")
    # Fallback auf erste nicht-loopback IP
    [[ -z "$web_ip" || "$web_ip" == "" ]] && web_ip=$(ip route get 1 2>/dev/null | awk '{print $7; exit}' || echo "10.42.0.1")

    python3 - "$port" "$token" "$web_ip" << 'PYEOF'
import sys, http.server, socketserver, urllib.parse, json, os, time, subprocess, threading
from datetime import datetime

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
TOKEN = sys.argv[2] if len(sys.argv) > 2 else ""
WEB_IP = sys.argv[3] if len(sys.argv) > 3 else "10.42.0.1"
messages = []
MAX_MESSAGES = 200
msg_counter = 0

class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        url = urllib.parse.urlparse(self.path)
        
        if TOKEN:
            params = urllib.parse.parse_qs(url.query)
            if params.get('token', [''])[0] != TOKEN:
                self.send_response(403)
                self.end_headers()
                self.wfile.write(b'Forbidden - Invalid token')
                return
        
        if url.path == '/':
            self.path = '/tmp/mesh-web.html'
            return http.server.SimpleHTTPRequestHandler.do_GET(self)
            
        elif url.path == '/send':
            params = urllib.parse.parse_qs(url.query)
            msg = params.get('msg', [''])[0]
            if msg:
                global msg_counter
                msg_counter += 1
                timestamp = datetime.now().strftime('%H:%M')
                messages.append({
                    'id': msg_counter,
                    'sender': '📱 Handy',
                    'text': msg,
                    'time': timestamp
                })
                if len(messages) > MAX_MESSAGES:
                    messages[:] = messages[-MAX_MESSAGES:]
                
                # Broadcast via Python
                try:
                    import RNS
                    reticulum = RNS.Reticulum()
                    identity = RNS.Identity()
                    dest = RNS.Destination(
                        identity,
                        RNS.Destination.OUT,
                        RNS.Destination.SINGLE,
                        "snowfox_mesh_chat"
                    )
                    packet = RNS.Packet(dest, f"📱 Handy: {msg}".encode('utf-8'))
                    packet.send()
                except:
                    pass
                
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b'OK')
            return
            
        elif url.path == '/poll':
            params = urllib.parse.parse_qs(url.query)
            last = int(params.get('last', ['0'])[0])
            new_msgs = [m for m in messages if m.get('id', 0) > last]
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(new_msgs).encode())
            return

os.chdir('/tmp')
socketserver.TCPServer.allow_reuse_address = True
server = socketserver.TCPServer(('0.0.0.0', PORT), Handler)
print(f"🌐 Web: http://{WEB_IP}:{PORT}")
if TOKEN:
    print(f"🔑 Token: {TOKEN}")
server.serve_forever()
PYEOF
}

# ──────────────────────────────────────────────────────────────
#  DHCP-Server starten (eigener dnsmasq, nur DHCP kein DNS)
# ──────────────────────────────────────────────────────────────

_mesh_start_dhcp() {
    local interface="$1"

    if ! command -v dnsmasq &>/dev/null; then
        warn "dnsmasq nicht installiert - Handys bekommen keine IP!"
        info "  Installieren: ${CYAN}sudo apt-get install -y dnsmasq${RESET}"
        return 1
    fi

    # Warten bis Interface vom Kernel vollständig registriert ist
    # (nmcli meldet Erfolg bevor das Interface im Kernel "oben" ist)
    local iface_wait=0
    while [[ $iface_wait -lt 15 ]]; do
        if ip link show "$interface" >/dev/null 2>&1 &&            ip addr show "$interface" 2>/dev/null | grep -q "inet "; then
            break
        fi
        sleep 1
        ((iface_wait++))
    done
    # Extra Sekunde damit Kernel das Interface stabilisiert
    sleep 1

    # Konfigdatei: NUR DHCP (port=0 deaktiviert DNS -> kein Konflikt mit systemd-resolved)
    cat > /tmp/snowfox-dnsmasq.conf << DNSMASQ_EOF
# SnowFox Mesh - nur DHCP, kein DNS (verhindert Konflikt mit systemd-resolved)
port=0
interface=${interface}
bind-interfaces
except-interface=lo
dhcp-range=10.42.0.10,10.42.0.250,255.255.255.0,1h
dhcp-option=option:router,10.42.0.1
dhcp-option=option:dns-server,8.8.8.8,8.8.4.4
dhcp-authoritative
no-resolv
no-poll
log-dhcp
DNSMASQ_EOF

    # dnsmasq starten
    sudo dnsmasq         --conf-file=/tmp/snowfox-dnsmasq.conf         --pid-file=/tmp/snowfox-dnsmasq.pid         --log-facility=/tmp/snowfox-dnsmasq.log         2>/tmp/snowfox-dnsmasq.err || true

    sleep 1
    if pgrep -f "dnsmasq" >/dev/null 2>&1; then
        ok "DHCP-Server aktiv (Range: 10.42.0.10–10.42.0.250)"
        return 0
    fi

    # Fehlermeldung ausgeben
    warn "DHCP-Server konnte nicht starten:"
    grep -v "^$" /tmp/snowfox-dnsmasq.err 2>/dev/null | head -5 | while IFS= read -r line; do
        info "  $line"
    done
    info "  Vollständiges Log: cat /tmp/snowfox-dnsmasq.err"
    return 1
}

# ──────────────────────────────────────────────────────────────
#  Manueller Hotspot-Fallback (hostapd + dnsmasq)
# ──────────────────────────────────────────────────────────────

_mesh_hotspot_manual() {
    local interface="$1"
    local ssid="$2"
    local password="$3"

    # Prüfen ob hostapd verfügbar
    if ! command -v hostapd &>/dev/null; then
        err "Weder nmcli-Hotspot noch hostapd verfügbar!"
        info "  Installieren: ${CYAN}sudo apt-get install -y hostapd dnsmasq${RESET}"
        return 1
    fi

    # Interface vorbereiten
    sudo nmcli device set "$interface" managed no 2>/dev/null || true
    sudo ip link set "$interface" down 2>/dev/null || true
    sudo iw dev "$interface" set type managed 2>/dev/null || true
    sudo ip link set "$interface" up 2>/dev/null || true
    sudo ip addr flush dev "$interface" 2>/dev/null || true
    sudo ip addr add 10.42.0.1/24 dev "$interface" 2>/dev/null || true

    # hostapd Konfiguration
    local hostapd_conf="/tmp/snowfox-hostapd.conf"
    {
        echo "interface=$interface"
        echo "driver=nl80211"
        echo "ssid=$ssid"
        echo "hw_mode=g"
        echo "channel=6"
        echo "ieee80211n=1"
        echo "wmm_enabled=1"
        if [[ -n "$password" ]]; then
            echo "wpa=2"
            echo "wpa_passphrase=$password"
            echo "wpa_key_mgmt=WPA-PSK"
            echo "rsn_pairwise=CCMP"
        fi
    } > "$hostapd_conf"

    sudo hostapd -B "$hostapd_conf" 2>/dev/null || {
        err "hostapd konnte nicht starten"
        return 1
    }

    # dnsmasq für DHCP
    pkill -f "dnsmasq.*$interface" 2>/dev/null || true
    sudo dnsmasq \
        --interface="$interface" \
        --bind-interfaces \
        --dhcp-range=10.42.0.10,10.42.0.250,12h \
        --no-resolv \
        --no-poll \
        2>/dev/null || warn "dnsmasq konnte nicht starten (DHCP fehlt)"

    ok "Manueller Hotspot aktiv: $ssid"
}

# ──────────────────────────────────────────────────────────────
#  Mesh start - Universeller Start
# ──────────────────────────────────────────────────────────────

_mesh_start() {
    local ssid="🦊 SnowFox-Mesh"
    local password=""
    local lora_port=""
    local interface=""
    local node_name=""
    local node_type="node"
    local node_location=""
    local mode="hotspot"
    local web_token=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --ssid) ssid="$2"; shift 2 ;;
            --pass) password="$2"; shift 2 ;;
            --lora) lora_port="$2"; shift 2 ;;
            --iface) interface="$2"; shift 2 ;;
            --name) node_name="$2"; shift 2 ;;
            --type) node_type="$2"; shift 2 ;;
            --location) node_location="$2"; shift 2 ;;
            --mode) mode="$2"; shift 2 ;;
            --token) web_token="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    _mesh_check_deps || return 1

    # WPA2 erfordert Passwort mit 8-63 Zeichen (oder leer fuer offenes Netz)
    if [[ -n "$password" ]]; then
        local pass_len=${#password}
        if [[ $pass_len -lt 8 ]]; then
            err "Passwort zu kurz! WPA2 erfordert mindestens 8 Zeichen (aktuell: $pass_len)"
            info "  Beispiel: ${CYAN}--pass meinpasswort${RESET}"
            return 1
        fi
        if [[ $pass_len -gt 63 ]]; then
            err "Passwort zu lang! WPA2 erlaubt maximal 63 Zeichen (aktuell: $pass_len)"
            return 1
        fi
    fi

    if [[ -z "$interface" ]]; then
        interface=$(_mesh_find_interface)
    fi
    
    if [[ -z "$interface" ]]; then
        err "Kein Netzwerk-Interface gefunden!"
        info "  Verfügbare Interfaces:"
        ip link show | grep -E '^[0-9]+:' | grep -v lo | awk '{print "    " $2}' | sed 's/://'
        info ""
        info "  Manuell angeben: ${CYAN}--iface wlo1${RESET}"
        return 1
    fi
    
    info "Verwende Interface: ${BOLD}$interface${RESET}"
    
    # Alte Prozesse beenden - zuerst via gespeicherte PIDs (zuverlaessiger)
    if [[ -f "$MESH_WEB_PID" ]]; then
        local old_web_pid=""
        old_web_pid=$(cat "$MESH_WEB_PID" 2>/dev/null || echo "")
        [[ -n "$old_web_pid" ]] && kill "$old_web_pid" 2>/dev/null || true
    fi
    if [[ -f "$MESH_SERVICES_PID" ]]; then
        local old_svc_pid=""
        old_svc_pid=$(cat "$MESH_SERVICES_PID" 2>/dev/null || echo "")
        [[ -n "$old_svc_pid" ]] && kill "$old_svc_pid" 2>/dev/null || true
    fi
    pkill -f "rnsd" 2>/dev/null || true
    pkill -f "mesh-web" 2>/dev/null || true
    pkill -f "python3.*mesh-web" 2>/dev/null || true
    sudo nmcli connection delete "snowfox-hotspot" 2>/dev/null || true
    rm -f "$MESH_PID_FILE" "$MESH_WEB_PID" "$MESH_SERVICES_PID"
    sleep 1
    
    if [[ -f "$MESH_PID_FILE" ]]; then
        local pid=""
        pid=$(cat "$MESH_PID_FILE" 2>/dev/null || echo "")
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            warn "Mesh läuft bereits (PID $pid)"
            return 0
        fi
        rm -f "$MESH_PID_FILE"
    fi
    
    touch "$MESH_LOCK"
    
    if [[ -n "$node_name" ]]; then
        _mesh_identity "$node_name" "$node_type" "$node_location"
    else
        _mesh_identity
    fi
    
    divider
    local my_name=""
    my_name=$(jq -r '.name' "$MESH_IDENTITY" 2>/dev/null || echo "Node")
    fox "Starte Mesh-Netzwerk (Modus: $mode)"
    divider
    
    info "Node: $my_name"
    info "SSID: $ssid"
    
    _mesh_save_nm_state "$interface"

    case "$mode" in
        hotspot)
            info "Richte Hotspot ein (für Handys)..."

            # Bestehende Hotspot-Verbindungen entfernen
            sudo nmcli connection delete "Hotspot" 2>/dev/null || true
            sudo nmcli connection delete "snowfox-hotspot" 2>/dev/null || true
            sleep 1

            # Interface managed lassen - nmcli braucht das
            sudo nmcli device set "$interface" managed yes 2>/dev/null || true
            sudo ip link set "$interface" up 2>/dev/null || true

            local hotspot_result=0
            if [[ -n "$password" ]]; then
                sudo nmcli device wifi hotspot ifname "$interface" \
                    con-name "snowfox-hotspot" \
                    ssid "$ssid" \
                    password "$password" 2>/dev/null || hotspot_result=$?
            else
                sudo nmcli device wifi hotspot ifname "$interface" \
                    con-name "snowfox-hotspot" \
                    ssid "$ssid" 2>/dev/null || hotspot_result=$?
            fi

            if [[ $hotspot_result -ne 0 ]]; then
                warn "nmcli hotspot fehlgeschlagen, versuche manuellen Fallback..."
                _mesh_hotspot_manual "$interface" "$ssid" "$password"
            else
                # Warten bis NM das Interface konfiguriert hat
                sleep 3

                # Sicherstellen dass 10.42.0.1 gesetzt ist
                if ! ip addr show "$interface" 2>/dev/null | grep -q "10.42.0.1"; then
                    sudo ip addr add 10.42.0.1/24 dev "$interface" 2>/dev/null || true
                    info "IP manuell gesetzt: 10.42.0.1/24"
                fi

                # NMs internen dnsmasq ersetzen durch eigenen
                # NM-dnsmasq bindet manchmal falsch - wir starten unseren eigenen
                info "Starte eigenen DHCP-Server (dnsmasq)..."
                sudo pkill -f "dnsmasq" 2>/dev/null || true
                sleep 1

                _mesh_start_dhcp "$interface" || true   # Fehler nie das Hauptscript abbrechen lassen

                if [[ -n "$password" ]]; then
                    ok "Hotspot aktiv: $ssid (Passwort gesetzt)"
                else
                    warn "Hotspot aktiv: $ssid (OHNE Passwort!)"
                fi
            fi
            ;;

        adhoc)
            info "Richte Ad-Hoc Mesh ein..."
            # Für Ad-Hoc: Interface von NM befreien
            sudo nmcli device set "$interface" managed no 2>/dev/null || true
            sudo ip link set "$interface" down 2>/dev/null || true
            sudo iw dev "$interface" set type ibss 2>/dev/null || true
            sudo ip link set "$interface" up 2>/dev/null || true
            sudo iw dev "$interface" ibss join "$ssid" 6 2>/dev/null || true
            sudo ip addr add 10.42.0.1/24 dev "$interface" 2>/dev/null || true
            ok "Ad-Hoc Mesh aktiv: $ssid"
            ;;

        *)
            err "Unbekannter Modus: $mode"
            rm -f "$MESH_LOCK"
            return 1
            ;;
    esac
    
    local psk=""
    if [[ -n "$password" ]]; then
        psk=$(python3 - "$password" <<'PYEOF'
import sys, hashlib, binascii
password = sys.argv[1]
key = hashlib.pbkdf2_hmac('sha256', password.encode(), b'snowfox-mesh-salt', 200000, 32)
print(binascii.hexlify(key).decode())
PYEOF
)
        echo "$psk" > "$MESH_PSK_FILE"
        ok "🔒 Verschlüsseltes Mesh (Passwort)"
    else
        psk=$(openssl rand -hex 32)
        echo "$psk" > "$MESH_PSK_FILE"
        warn "🔓 Offenes Mesh - jeder kann beitreten!"
        info "  Mit Passwort schützen: ${CYAN}snowfox mesh start --pass \"meinpasswort\"${RESET}"
    fi
    chmod 600 "$MESH_PSK_FILE"
    
    if ! _mesh_start_reticulum "$interface" "$psk"; then
        rm -f "$MESH_LOCK"
        return 1
    fi
    
    _mesh_start_services &
    local svc_pid=$!
    echo "$svc_pid" > "$MESH_SERVICES_PID"
    
    # Port 8080 freimachen: Prozess der dort lauscht beenden
    local port_killer_pid=""
    port_killer_pid=$(ss -tlnp "sport = :$MESH_WEB_PORT" 2>/dev/null | grep -oP 'pid=\K[0-9]+' | head -1 || true)
    [[ -n "$port_killer_pid" ]] && kill "$port_killer_pid" 2>/dev/null && sleep 1 || true

    if [[ -n "$web_token" ]]; then
        _mesh_web "$MESH_WEB_PORT" "$web_token" "$interface" &
    else
        _mesh_web "$MESH_WEB_PORT" "" "$interface" &
    fi
    local web_pid=$!
    echo "$web_pid" > "$MESH_WEB_PID"
    
    echo "MODE=$mode" > "$MESH_STATE"
    echo "INTERFACE=$interface" >> "$MESH_STATE"
    echo "SSID=$ssid" >> "$MESH_STATE"
    echo "PASSWORD=$password" >> "$MESH_STATE"
    echo "TOKEN=$web_token" >> "$MESH_STATE"
    
    local ip=""
    ip=$(ip addr show "$interface" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
    [[ -z "$ip" ]] && ip="10.42.0.1"
    
    if [[ "$mode" == "hotspot" ]] && [[ -n "$password" ]]; then
        _mesh_qr "$ssid" "$password" "$ip"
    elif [[ "$mode" == "hotspot" ]]; then
        warn "Kein Passwort gesetzt - QR-Code würde offenes Netzwerk anzeigen"
        info "  Mit Passwort schützen für QR-Code: ${CYAN}--pass meinpasswort${RESET}"
    fi
    
    echo ""
    echo -e "  ${GREEN}✅ Mesh aktiv!${RESET}"
    echo -e "  ${GRAY}Node:       ${CYAN}$my_name${RESET}"
    echo -e "  ${GRAY}Modus:      ${CYAN}$mode${RESET}"
    echo -e "  ${GRAY}SSID:       ${CYAN}$ssid${RESET}"
    if [[ -n "$password" ]]; then
        echo -e "  ${GRAY}Passwort:   ${CYAN}$password${RESET}"
    fi
    echo -e "  ${GRAY}IP:         ${CYAN}$ip${RESET}"
    echo -e "  ${GRAY}Web:        ${CYAN}http://$ip:$MESH_WEB_PORT${RESET}"
    if [[ -n "$web_token" ]]; then
        echo -e "  ${GRAY}Web-Token:  ${CYAN}$web_token${RESET}"
    fi
    echo ""
    echo -e "  ${GRAY}Verfügbare Befehle:${RESET}"
    echo -e "    ${CYAN}snowfox mesh status${RESET}   — Status anzeigen"
    echo -e "    ${CYAN}snowfox mesh nodes${RESET}    — Alle Knoten anzeigen"
    echo -e "    ${CYAN}snowfox mesh chat${RESET}     — Interaktiver Chat"
    echo -e "    ${CYAN}snowfox mesh stop${RESET}     — Mesh herunterfahren"
    divider
    
    rm -f "$MESH_LOCK"
}

# ──────────────────────────────────────────────────────────────
#  Status - Mesh-Status anzeigen
# ──────────────────────────────────────────────────────────────

_mesh_status() {
    divider
    echo -e "${PURPLE}${BOLD}  🦊 SnowFox Mesh - Status${RESET}"
    divider
    
    local running=false
    local pid=""
    if [[ -f "$MESH_PID_FILE" ]]; then
        pid=$(cat "$MESH_PID_FILE" 2>/dev/null || echo "")
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            running=true
        fi
    fi
    
    if [[ "$running" == "true" ]]; then
        echo -e "  ${GREEN}●${RESET} Status:   ${BOLD}AKTIV${RESET} (PID $pid)"
    else
        echo -e "  ${RED}●${RESET} Status:   ${BOLD}INAKTIV${RESET}"
        echo ""
        info "  Starten: ${CYAN}snowfox mesh start --name NAME${RESET}"
        divider
        return 0
    fi
    
    local interface=""
    local mode=""
    local ssid=""
    local password=""
    if [[ -f "$MESH_STATE" ]]; then
        source "$MESH_STATE" 2>/dev/null || true
    fi
    
    echo -e "  ${GRAY}Interface:  ${CYAN}${interface:-unbekannt}${RESET}"
    echo -e "  ${GRAY}Modus:      ${CYAN}${mode:-unbekannt}${RESET}"
    echo -e "  ${GRAY}SSID:       ${CYAN}${ssid:-unbekannt}${RESET}"
    [[ -n "$password" ]] && echo -e "  ${GRAY}Passwort:   ${CYAN}$password${RESET}"
    
    local ip=""
    if [[ -n "$interface" ]]; then
        ip=$(ip addr show "$interface" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
    fi
    echo -e "  ${GRAY}IP:         ${CYAN}${ip:-10.42.0.1}${RESET}"
    
    if [[ -f "$MESH_WEB_PID" ]]; then
        local web_pid=""
        web_pid=$(cat "$MESH_WEB_PID" 2>/dev/null || echo "")
        if [[ -n "$web_pid" ]] && kill -0 "$web_pid" 2>/dev/null; then
            echo -e "  ${GRAY}Web:        ${GREEN}aktiv${RESET} (PID $web_pid) ${CYAN}http://${ip:-10.42.0.1}:$MESH_WEB_PORT${RESET}"
        else
            echo -e "  ${GRAY}Web:        ${RED}inaktiv${RESET}"
        fi
    fi
    
    if [[ -f "$MESH_DIR/gateway.state" ]]; then
        local wan=""
        wan=$(cat "$MESH_DIR/gateway.iface" 2>/dev/null || echo "unbekannt")
        echo -e "  ${GRAY}Gateway:    ${GREEN}AKTIV${RESET} (WAN: $wan)"
    else
        echo -e "  ${GRAY}Gateway:    ${GRAY}inaktiv${RESET}"
    fi
    
    echo ""
    echo -e "  ${GRAY}Knoten im Mesh:${RESET}"
    python3 - <<'PYEOF'
import RNS, time
try:
    reticulum = RNS.Reticulum()
    time.sleep(0.5)
    count = 0
    for h in RNS.Transport.peers:
        if RNS.Transport.has_path(h):
            count += 1
    if count == 0:
        print("    ${GRAY}(keine anderen Knoten sichtbar)${RESET}")
    else:
        print(f"    ${CYAN}{count}${RESET} andere Knoten")
except:
    print("    ${GRAY}(Fehler beim Abrufen)${RESET}")
PYEOF
    
    divider
}

# ──────────────────────────────────────────────────────────────
#  Chat - Interaktiver Chat
# ──────────────────────────────────────────────────────────────

_mesh_chat() {
    divider
    echo -e "${PURPLE}${BOLD}  💬 Mesh Chat${RESET}"
    echo -e "${GRAY}  @all text  - Broadcast  |  @name text  - Privat${RESET}"
    echo -e "${GRAY}  /nodes     - Alle Knoten  |  /catalog  - Freigaben${RESET}"
    echo -e "${GRAY}  /status    - Mesh-Status  |  /quit     - Beenden${RESET}"
    divider
    
    _mesh_listen &
    local listener_pid=$!
    
    while true; do
        echo -ne "  Du > "
        read -r input
        [[ -z "$input" ]] && break
        
        case "$input" in
            /nodes) _mesh_nodes ;;
            /catalog) _mesh_catalog ;;
            /status) _mesh_status ;;
            /quit|/exit) break ;;
            @all*) _mesh_send_broadcast "${input#@all }" ;;
            @*) 
                local target=""
                local msg=""
                target=$(echo "$input" | awk '{print $1}' | sed 's/^@//')
                msg=$(echo "$input" | cut -d' ' -f2-)
                if [[ -n "$target" ]] && [[ -n "$msg" ]]; then
                    # Privatnachricht via Python
                    python3 - "$target" "$msg" <<'PYEOF'
import RNS
import sys

target_hash_str = sys.argv[1]
message = sys.argv[2]

try:
    reticulum = RNS.Reticulum()
    target_hash = bytes.fromhex(target_hash_str.replace(":", "").replace(" ", "").replace("[", "").replace("]", ""))
    identity = RNS.Identity.recall(target_hash)
    
    if identity is None:
        print(f"  Node {target_hash_str} nicht gefunden")
        sys.exit(1)
    
    dest = RNS.Destination(
        identity,
        RNS.Destination.OUT,
        RNS.Destination.SINGLE,
        "snowfox_mesh_chat"
    )
    
    packet = RNS.Packet(dest, message.encode('utf-8'))
    packet.send()
    print(f"  ✅ Privatnachricht an {target_hash_str[:12]}… gesendet")
    
except Exception as e:
    print(f"  ❌ Fehler: {e}")
PYEOF
                else
                    warn "Format: @name nachricht"
                fi
                ;;
            *) _mesh_send_broadcast "$input" ;;
        esac
    done
    
    kill $listener_pid 2>/dev/null
    echo ""
    fox "Chat beendet"
}

# ──────────────────────────────────────────────────────────────
#  Listen - Nachrichten empfangen
# ──────────────────────────────────────────────────────────────

_mesh_listen() {
    python3 - <<'PYEOF'
import RNS
import time
import json
import os
from datetime import datetime

IDENTITY_FILE = os.path.expanduser("~/.config/snowfox/mesh/identity.json")
my_name = "Node"
if os.path.exists(IDENTITY_FILE):
    try:
        with open(IDENTITY_FILE) as f:
            my_name = json.load(f).get('name', 'Node')
    except: pass

PURPLE = '\033[0;35m'
CYAN   = '\033[0;36m'
GREEN  = '\033[0;32m'
GRAY   = '\033[0;37m'
BOLD   = '\033[1m'
RESET  = '\033[0m'

def message_received(message, timestamp, sender_hash, sender_identity, is_trusted):
    ts = datetime.fromtimestamp(timestamp).strftime('%H:%M')
    try:
        msg = message.decode('utf-8')
        if msg.startswith('[') and ']' in msg:
            name_end = msg.index(']')
            sender = msg[1:name_end]
            content = msg[name_end+1:].strip()
            print(f"\n  {GRAY}[{ts}]{RESET} {CYAN}{BOLD}{sender}{RESET} > {content}")
        else:
            print(f"\n  {GRAY}[{ts}]{RESET} {CYAN}Nachricht{RESET} empfangen")
        print("  Du > ", end='', flush=True)
    except: pass

try:
    reticulum = RNS.Reticulum()
    identity = RNS.Identity()
    dest = RNS.Destination(identity, RNS.Destination.IN, RNS.Destination.SINGLE, "snowfox_mesh_chat")
    dest.set_message_callback(message_received)
    dest.announce()
    print(f"  Du bist: {my_name}")
    print("  Du > ", end='', flush=True)
    while True:
        time.sleep(0.1)
except KeyboardInterrupt:
    pass
PYEOF
}

# ──────────────────────────────────────────────────────────────
#  Share - Dateien/Ordner teilen (mit Race-Condition-Fix)
# ──────────────────────────────────────────────────────────────

_mesh_share() {
    local path="$1"
    local name="$2"
    local description="$3"
    
    if [[ -z "$path" ]] || [[ ! -e "$path" ]]; then
        err "Pfad nicht gefunden: $path"
        info "  Datei:    ${CYAN}snowfox mesh share datei.txt${RESET}"
        info "  Ordner:   ${CYAN}snowfox mesh share dokumente/${RESET}"
        info "  Mit Name: ${CYAN}snowfox mesh share datei.txt \"Mein Dokument\"${RESET}"
        return 1
    fi
    
    divider
    local node_name
    node_name=$(jq -r '.name' "$MESH_IDENTITY" 2>/dev/null || echo "Node")
    fox "Teile: ${BOLD}$(basename "$path")${RESET} ($node_name)"
    divider
    
    local item_name="$name"
    if [[ -z "$item_name" ]]; then
        item_name=$(basename "$path")
    fi
    
    local item_type="file"
    local temp_zip=""
    
    if [[ -d "$path" ]]; then
        item_type="directory"
        temp_zip="/tmp/share-$(date +%s).zip"
        info "Komprimiere Ordner..."
        (cd "$(dirname "$path")" && zip -r "$temp_zip" "$(basename "$path")" -q)
        path="$temp_zip"
        item_name="${item_name}.zip"
        item_type="archive"
    fi
    
    local size
    size=$(du -h "$path" | awk '{print $1}')
    local hash
    hash=$(sha256sum "$path" | awk '{print $1}')
    
    local meta="{\"name\":\"$item_name\",\"type\":\"$item_type\",\"size\":\"$size\",\"hash\":\"$hash\",\"owner\":\"$node_name\",\"desc\":\"$description\",\"timestamp\":\"$(date -Iseconds)\"}"
    
    # ── 1. Catalog aktualisieren ──
    python3 - "$meta" <<'PYEOF'
import json
import os
import sys

meta = json.loads(sys.argv[1])
catalog_file = os.path.expanduser("~/.config/snowfox/mesh/catalog.json")

if os.path.exists(catalog_file):
    with open(catalog_file) as f:
        data = json.load(f)
else:
    data = {"shared": []}

data['shared'] = [x for x in data['shared'] if x.get('hash') != meta.get('hash')]
data['shared'].append(meta)

with open(catalog_file, 'w') as f:
    json.dump(data, f, indent=2)
PYEOF
    
    # ── 2. Catalog-Broadcast (mit Verzögerung für Race-Condition) ──
    info "Broadcast: Inhalte werden im Mesh bekannt gemacht..."
    python3 - "$meta" "$node_name" <<'PYEOF'
import RNS
import json
import sys
import time

meta = json.loads(sys.argv[1])
node_name = sys.argv[2]

try:
    reticulum = RNS.Reticulum()
    identity = RNS.Identity()
    
    dest = RNS.Destination(
        identity,
        RNS.Destination.OUT,
        RNS.Destination.SINGLE,
        "snowfox_mesh_catalog"
    )
    
    catalog_msg = f"📚 CATALOG|{json.dumps({'node': node_name, 'items': [meta]})}"
    RNS.Packet(dest, catalog_msg.encode('utf-8')).send()
    
    print("  Warte 2 Sekunden für Broadcast...")
    time.sleep(2)
    
except Exception as e:
    print(f"  Broadcast-Fehler: {e}")
PYEOF
    
    # ── 3. Resource erstellen (nach dem Broadcast) ──
    info "Resource wird verfügbar gemacht..."
    python3 - "$path" "$meta" <<'PYEOF'
import RNS
import sys
import time
import json
import os

filepath = sys.argv[1]
meta = json.loads(sys.argv[2])

try:
    reticulum = RNS.Reticulum()
    identity = RNS.Identity()
    
    dest = RNS.Destination(
        identity,
        RNS.Destination.IN,
        RNS.Destination.SINGLE,
        "snowfox_mesh_transfer"
    )
    dest.announce()
    
    resource = RNS.Resource(open(filepath, 'rb'), dest)
    
    total = resource.get_total_size() if hasattr(resource, 'get_total_size') else 1
    while not resource.is_complete():
        if hasattr(resource, 'get_transfer_size'):
            progress = resource.get_transfer_size() / total * 100
            print(f"\r  Fortschritt: {progress:.1f}%", end='', flush=True)
        time.sleep(0.5)
    
    print()
    print("  ✅ Resource verfügbar!")
    
    if filepath.startswith('/tmp/share-'):
        os.unlink(filepath)
    
except Exception as e:
    print(f"  Resource-Fehler: {e}")
PYEOF
    
    echo ""
    ok "Freigegeben: ${BOLD}$item_name${RESET} ($size)"
    info "  Hash: $hash"
    info "  Abrufen: ${CYAN}snowfox mesh get $hash${RESET}"
    info "  Alle Freigaben: ${CYAN}snowfox mesh catalog${RESET}"
    
    _mesh_send_broadcast "📄 $node_name hat '$item_name' geteilt${description:+ - $description}"
    
    divider
}

# ──────────────────────────────────────────────────────────────
#  Share-All - Ganzen Ordner teilen
# ──────────────────────────────────────────────────────────────

_mesh_share_all() {
    local dir="$1"
    
    if [[ -z "$dir" ]] || [[ ! -d "$dir" ]]; then
        err "Ordner nicht gefunden: $dir"
        return 1
    fi
    
    divider
    fox "Teile gesamten Ordner: ${BOLD}$dir${RESET}"
    divider
    
    local count=0
    local failed=0
    
    while IFS= read -r file; do
        if [[ -f "$file" ]]; then
            ((count++))
            echo -ne "  Teile $count: $(basename "$file")... "
            if _mesh_share "$file" "" "Aus $dir" > /dev/null 2>&1; then
                echo "✅"
            else
                echo "❌"
                ((failed++))
            fi
        fi
    done < <(find "$dir" -type f 2>/dev/null)
    
    echo ""
    if [[ $failed -eq 0 ]]; then
        ok "Alle $count Dateien geteilt!"
    else
        warn "$count Dateien geteilt, $failed fehlgeschlagen"
    fi
    divider
}

# ──────────────────────────────────────────────────────────────
#  Get - Datei abrufen
# ──────────────────────────────────────────────────────────────

_mesh_get() {
    local hash="$1"
    
    if [[ -z "$hash" ]]; then
        err "Verwendung: snowfox mesh get <hash>"
        info "  Verfügbare Dateien: ${CYAN}snowfox mesh catalog${RESET}"
        return 1
    fi
    
    divider
    fox "Lade Datei aus dem Mesh..."
    divider
    
    mkdir -p "$MESH_SHARE"
    
    local item_name
    item_name=$(python3 - "$hash" <<'PYEOF'
import json
import os
import sys

hash_search = sys.argv[1]
catalog_file = os.path.expanduser("~/.config/snowfox/mesh/catalog.json")

if os.path.exists(catalog_file):
    with open(catalog_file) as f:
        data = json.load(f)
        for item in data.get('shared', []):
            if item.get('hash') == hash_search:
                print(item.get('name', 'unbekannt'))
                break
PYEOF
)
    
    if [[ -z "$item_name" ]]; then
        item_name="datei-$hash"
    fi
    
    info "Lade: $item_name"
    
    python3 - "$hash" "$MESH_SHARE/$item_name" <<'PYEOF'
import RNS
import sys
import time
import os

hash_str = sys.argv[1]
save_path = sys.argv[2]

try:
    reticulum = RNS.Reticulum()
    
    found = False
    for resource in RNS.Transport.resources:
        if str(resource.hash) == hash_str:
            found = True
            print(f"  Resource gefunden, lade...")
            
            resource.download(save_path)
            
            while not resource.is_complete():
                if hasattr(resource, 'get_transfer_size'):
                    total = resource.get_total_size() if hasattr(resource, 'get_total_size') else 1
                    progress = resource.get_transfer_size() / total * 100
                    print(f"\r  Fortschritt: {progress:.1f}%", end='', flush=True)
                time.sleep(0.5)
            
            print()
            print("  ✅ Download abgeschlossen")
            break
    
    if not found:
        print("  ❌ Datei nicht gefunden im Mesh")
        print("  Stelle sicher, dass jemand sie geteilt hat")
        print("  Verfügbare Inhalte: snowfox mesh catalog")
        
except Exception as e:
    print(f"  Fehler: {e}")
PYEOF
    
    if [[ -f "$MESH_SHARE/$item_name" ]]; then
        ok "Datei gespeichert: $MESH_SHARE/$item_name"
    fi
    
    divider
}

# ──────────────────────────────────────────────────────────────
#  Gateway - Internet teilen (mit Sicherheits-Fixes)
# ──────────────────────────────────────────────────────────────

_mesh_gateway() {
    local action="$1"
    local GATEWAY_STATE="$MESH_DIR/gateway.state"
    local SYSCTL_BACKUP="$MESH_DIR/sysctl.ip_forward.backup"
    local interface=""
    local wan_iface=""
    
    if [[ -f "$MESH_STATE" ]]; then
        source "$MESH_STATE" 2>/dev/null || true
    fi
    
    if [[ -z "$INTERFACE" ]]; then
        INTERFACE=$(_mesh_find_interface)
    fi
    
    if [[ -z "$INTERFACE" ]]; then
        err "Kein Mesh-Interface gefunden!"
        return 1
    fi
    
    case "$action" in
        enable|--enable)
            divider
            fox "Aktiviere Internet-Gateway auf $INTERFACE"
            divider
            
            if [[ ! -f "$MESH_PID_FILE" ]]; then
                err "Mesh läuft nicht! Zuerst: ${CYAN}snowfox mesh start${RESET}"
                return 1
            fi
            
            local current_forward
            current_forward=$(sysctl -n net.ipv4.ip_forward 2>/dev/null || echo "0")
            echo "$current_forward" > "$SYSCTL_BACKUP"
            
            sudo sysctl -w net.ipv4.ip_forward=1
            echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
            
            wan_iface=$(ip route | grep default | awk '{print $5}' | head -1)
            
            if [[ -z "$wan_iface" ]]; then
                err "Kein Internet-Interface!"
                return 1
            fi
            
            sudo iptables-save > "$MESH_DIR/iptables.backup"
            
            sudo iptables -t nat -A POSTROUTING -o "$wan_iface" -j MASQUERADE
            sudo iptables -A FORWARD -i "$INTERFACE" -o "$wan_iface" -j ACCEPT
            sudo iptables -A FORWARD -i "$wan_iface" -o "$INTERFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT
            
            sudo nmcli device set "$wan_iface" managed yes 2>/dev/null || true
            
            echo "enabled" > "$GATEWAY_STATE"
            echo "$wan_iface" > "$MESH_DIR/gateway.iface"
            
            local node_name
            node_name=$(jq -r '.name' "$MESH_IDENTITY" 2>/dev/null || echo "Node")
            _mesh_send_broadcast "🌐 $node_name teilt Internet ($wan_iface)"
            
            ok "Gateway aktiv auf $wan_iface → $INTERFACE"
            info "  Deaktivieren: ${CYAN}snowfox mesh gateway disable${RESET}"
            divider
            ;;
            
        disable|--disable)
            fox "Deaktiviere Gateway (inkl. IP-Forwarding)"
            
            if [[ -f "$MESH_DIR/gateway.iface" ]]; then
                wan_iface=$(cat "$MESH_DIR/gateway.iface" 2>/dev/null || echo "")
            fi
            if [[ -z "$wan_iface" ]]; then
                wan_iface=$(ip route | grep default | awk '{print $5}' | head -1)
            fi
            
            if [[ -f "$MESH_DIR/iptables.backup" ]]; then
                sudo iptables-restore < "$MESH_DIR/iptables.backup" 2>/dev/null || true
                rm -f "$MESH_DIR/iptables.backup"
            else
                sudo iptables -t nat -D POSTROUTING -o "$wan_iface" -j MASQUERADE 2>/dev/null || true
                sudo iptables -F FORWARD 2>/dev/null || true
            fi
            
            if [[ -f "$SYSCTL_BACKUP" ]]; then
                local old_value
                old_value=$(cat "$SYSCTL_BACKUP")
                sudo sysctl -w "net.ipv4.ip_forward=$old_value" 2>/dev/null || true
                rm -f "$SYSCTL_BACKUP"
            else
                sudo sysctl -w net.ipv4.ip_forward=0 2>/dev/null || true
            fi
            
            rm -f "$GATEWAY_STATE"
            rm -f "$MESH_DIR/gateway.iface"
            
            _mesh_send_broadcast "🌐 Internet-Gateway deaktiviert"
            ok "Gateway deaktiviert - IP-Forwarding zurückgesetzt"
            ;;
            
        status)
            if [[ -f "$GATEWAY_STATE" ]]; then
                local iface
                iface=$(cat "$MESH_DIR/gateway.iface" 2>/dev/null || echo "unbekannt")
                local forward
                forward=$(sysctl -n net.ipv4.ip_forward 2>/dev/null || echo "0")
                ok "Gateway: AKTIV"
                info "  Interface: $iface"
                info "  IP-Forward: $forward"
            else
                local forward
                forward=$(sysctl -n net.ipv4.ip_forward 2>/dev/null || echo "0")
                if [[ "$forward" == "1" ]]; then
                    warn "IP-Forwarding ist aktiv, aber Gateway-Status unbekannt"
                    info "  Führe aus: ${CYAN}snowfox mesh gateway disable${RESET} zum Zurücksetzen"
                else
                    info "Gateway: inaktiv"
                fi
            fi
            ;;
            
        *)
            echo "Verwendung:"
            echo "  ${CYAN}snowfox mesh gateway enable${RESET}  — Internet teilen"
            echo "  ${CYAN}snowfox mesh gateway disable${RESET} — Internet teilen stoppen (inkl. IP-Forward)"
            echo "  ${CYAN}snowfox mesh gateway status${RESET}  — Status anzeigen"
            ;;
    esac
}

# ──────────────────────────────────────────────────────────────
#  Stop - Mesh herunterfahren (mit Cleanup)
# ──────────────────────────────────────────────────────────────

_mesh_stop() {
    divider
    fox "Fahre Mesh-Netzwerk herunter..."
    divider
    
    # 1. Web-Interface stoppen
    if [[ -f "$MESH_WEB_PID" ]]; then
        local web_pid=""
        web_pid=$(cat "$MESH_WEB_PID" 2>/dev/null || echo "")
        if [[ -n "$web_pid" ]] && kill -0 "$web_pid" 2>/dev/null; then
            kill "$web_pid" 2>/dev/null || true
            ok "Web-Interface gestoppt (PID $web_pid)"
        fi
        rm -f "$MESH_WEB_PID"
    fi
    pkill -f "mesh-web" 2>/dev/null || true
    pkill -f "python3.*mesh-web" 2>/dev/null || true
    
    # 2. Services stoppen
    if [[ -f "$MESH_SERVICES_PID" ]]; then
        local svc_pid=""
        svc_pid=$(cat "$MESH_SERVICES_PID" 2>/dev/null || echo "")
        if [[ -n "$svc_pid" ]] && kill -0 "$svc_pid" 2>/dev/null; then
            kill "$svc_pid" 2>/dev/null || true
            ok "Services gestoppt (PID $svc_pid)"
        fi
        rm -f "$MESH_SERVICES_PID"
    fi
    
    # 3. Gateway deaktivieren (falls aktiv)
    if [[ -f "$MESH_DIR/gateway.state" ]]; then
        warn "Gateway ist aktiv - wird deaktiviert..."
        _mesh_gateway disable
    fi
    
    # 4. Reticulum stoppen
    if [[ -f "$MESH_PID_FILE" ]]; then
        local pid=""
        pid=$(cat "$MESH_PID_FILE" 2>/dev/null || echo "")
        if [[ -n "$pid" ]]; then
            kill "$pid" 2>/dev/null || true
            sleep 2
            kill -9 "$pid" 2>/dev/null || true
            ok "Reticulum-Daemon gestoppt (PID $pid)"
        fi
        rm -f "$MESH_PID_FILE"
    fi
    pkill -f "rnsd" 2>/dev/null || true
    
    # 5. hostapd/dnsmasq stoppen (manueller Fallback UND NM-eigener)
    sudo pkill -f "hostapd.*snowfox" 2>/dev/null || true
    # Eigenen dnsmasq via PID-Datei stoppen
    if [[ -f /tmp/snowfox-dnsmasq.pid ]]; then
        local dnsmasq_pid=""
        dnsmasq_pid=$(cat /tmp/snowfox-dnsmasq.pid 2>/dev/null || echo "")
        [[ -n "$dnsmasq_pid" ]] && sudo kill "$dnsmasq_pid" 2>/dev/null || true
        rm -f /tmp/snowfox-dnsmasq.pid
    fi
    rm -f /tmp/snowfox-hostapd.conf /tmp/snowfox-dnsmasq.log 2>/dev/null || true

    # nmcli Hotspot-Verbindung entfernen
    sudo nmcli connection delete "snowfox-hotspot" 2>/dev/null || true

    # 6. Interface zurücksetzen
    if [[ -f "$MESH_STATE" ]]; then
        local INTERFACE=""
        source "$MESH_STATE" 2>/dev/null || true
        
        if [[ -n "$INTERFACE" ]]; then
            info "Setze $INTERFACE zurück..."
            
            sudo iw dev "$INTERFACE" ibss leave 2>/dev/null || true
            sudo ip link set "$INTERFACE" down 2>/dev/null || true
            sudo ip addr flush dev "$INTERFACE" 2>/dev/null || true
            sudo iw dev "$INTERFACE" set type managed 2>/dev/null || true
            sudo ip link set "$INTERFACE" up 2>/dev/null || true
            
            ok "Interface zurückgesetzt"
        fi
    fi
    
    # 7. NetworkManager wiederherstellen
    _mesh_restore_nm_state
    
    # 8. NetworkManager neu starten
    if systemctl is-active NetworkManager &>/dev/null; then
        sudo systemctl restart NetworkManager 2>/dev/null || true
        ok "NetworkManager neu gestartet"
    fi
    
    # 9. Aufräumen
    rm -f "$MESH_STATE" 2>/dev/null || true
    rm -f "$MESH_LOCK" 2>/dev/null || true
    pkill -f "snowfox mesh" 2>/dev/null || true
    
    local node_name
    node_name=$(jq -r '.name' "$MESH_IDENTITY" 2>/dev/null || echo "Node")
    _mesh_send_broadcast "👋 $node_name verlässt das Mesh"
    sleep 1
    
    ok "Mesh-Netzwerk gestoppt"
    divider
}

# ──────────────────────────────────────────────────────────────
#  Katalog - Verbesserte Version mit Live-Update
# ──────────────────────────────────────────────────────────────

_mesh_catalog() {
    divider
    echo -e "${PURPLE}${BOLD}  📚 Mesh-Katalog - Freigegebene Inhalte${RESET}"
    divider
    
    echo -e "${GRAY}  📁 Lokal freigegeben:${RESET}"
    if [[ -f "$MESH_CATALOG" ]]; then
        python3 - <<'PYEOF'
import json
import os

catalog_file = os.path.expanduser("~/.config/snowfox/mesh/catalog.json")

if os.path.exists(catalog_file):
    with open(catalog_file) as f:
        data = json.load(f)
        shared = data.get('shared', [])
        
        if not shared:
            print("    ${GRAY}(keine lokalen Freigaben)${RESET}")
        else:
            for item in shared:
                name = item.get('name', 'Unbenannt')
                size = item.get('size', '?')
                typ = item.get('type', 'datei')
                print(f"    📄 {name} ({size}) [{typ}]")
PYEOF
    else
        echo "    ${GRAY}(keine lokalen Freigaben)${RESET}"
    fi
    
    echo ""
    echo -e "${GRAY}  🌐 Im Mesh verfügbar:${RESET}"
    
    python3 - <<'PYEOF'
import RNS
import time
import json
import sys

received = {}
timeout = 5

def message_received(message, timestamp, sender_hash, sender_identity, is_trusted):
    try:
        msg = message.decode('utf-8')
        if msg.startswith('📚 CATALOG|'):
            data = json.loads(msg.split('|')[1])
            node = data.get('node', 'Unbekannt')
            items = data.get('items', [])
            received[node] = items
    except:
        pass

try:
    reticulum = RNS.Reticulum()
    identity = RNS.Identity()
    
    dest = RNS.Destination(
        identity,
        RNS.Destination.IN,
        RNS.Destination.SINGLE,
        "snowfox_mesh_catalog"
    )
    dest.set_message_callback(message_received)
    dest.announce()
    
    start = time.time()
    while time.time() - start < timeout:
        time.sleep(0.5)
    
    if not received:
        print("    ${GRAY}(keine Freigaben im Mesh gefunden)${RESET}")
    else:
        for node, items in received.items():
            print(f"    📚 {node}:")
            for item in items:
                name = item.get('name', 'Unbenannt')
                size = item.get('size', '?')
                typ = item.get('type', 'datei')
                print(f"       📄 {name} ({size}) [{typ}]")
                
except Exception as e:
    print(f"    Fehler beim Abrufen: {e}")
PYEOF
    
    echo ""
    divider
    echo -e "  ${GRAY}Eigenes Zeug teilen: ${CYAN}snowfox mesh share <datei/ordner>${RESET}"
    echo -e "  ${GRAY}Alles abrufen:       ${CYAN}snowfox mesh get <hash>${RESET}"
    divider
}

# ──────────────────────────────────────────────────────────────
#  Nodes - Verbesserte Version
# ──────────────────────────────────────────────────────────────

_mesh_nodes() {
    divider
    echo -e "${PURPLE}${BOLD}  🌐 Mesh-Knoten${RESET}"
    divider
    
    local my_name
    my_name=$(jq -r '.name' "$MESH_IDENTITY" 2>/dev/null || echo "Du")
    
    echo -e "  ${GREEN}●${RESET} ${BOLD}$my_name${RESET} ${GRAY}(das bist du)${RESET}"
    echo "  ────────────────────────────────────────────"
    
    python3 - <<'PYEOF'
import RNS
import time
import json
import os

IDENTITY_FILE = os.path.expanduser("~/.config/snowfox/mesh/identity.json")

my_name = "Du"
if os.path.exists(IDENTITY_FILE):
    try:
        with open(IDENTITY_FILE) as f:
            data = json.load(f)
            my_name = data.get('name', 'Du')
    except:
        pass

try:
    reticulum = RNS.Reticulum()
    time.sleep(1)
    
    nodes = []
    for hash_bytes in RNS.Transport.peers:
        if RNS.Transport.has_path(hash_bytes):
            hash_str = RNS.prettyhexrep(hash_bytes)
            name = hash_str[:12]
            
            identity = RNS.Identity.recall(hash_bytes)
            if identity:
                pass
            
            if name != my_name:
                nodes.append((name, hash_str))
    
    nodes.sort()
    
    if not nodes:
        print("  ${GRAY}(keine anderen Knoten sichtbar)${RESET}")
    else:
        for i, (name, hash_str) in enumerate(nodes, 1):
            print(f"  {i:2}. {name}")
            print(f"      ID: {hash_str[:16]}…")
            
except Exception as e:
    print(f"  Fehler: {e}")
PYEOF
    
    echo ""
    divider
}

# ──────────────────────────────────────────────────────────────
#  Hilfsfunktionen
# ──────────────────────────────────────────────────────────────

_mesh_write_config() {
    local psk="$1"
    local interface="$2"
    local lora_port="$3"
    
    mkdir -p "$(dirname "$RETICULUM_CFG")"
    
    cat > "$RETICULUM_CFG" << EOF
# SnowFox Mesh Config - Universell
[reticulum]
  enable_transport = True
  share_instance = Yes
  shared_instance_port = 37428
  instance_control_port = 37429
  panic_on_interface_error = No
  loglevel = 2

[logging]
  loglevel = 2

[interfaces]

  [[Mesh Interface]]
    type = AutoInterface
    interface_enabled = True
    group_id = snowfox_mesh
    discovery_scope = link
    discovery_port = 29716
    data_port = 42671
EOF

    if [[ -n "$psk" ]]; then
        echo "    preshared_key = ${psk}" >> "$RETICULUM_CFG"
    fi
    
    # KEIN 'interface = ...' für AutoInterface - das verursacht "could not autoconfigure"!

    if [[ -n "$lora_port" ]]; then
        cat >> "$RETICULUM_CFG" << EOF

  [[LoRa Interface]]
    type = RNodeInterface
    interface_enabled = True
    device = ${lora_port}
    frequency = 868.1
    bandwidth = 125.0
    sf = 12
    cr = 5
    tx_power = 17
EOF
        if [[ -n "$psk" ]]; then
            echo "    preshared_key = ${psk}" >> "$RETICULUM_CFG"
        fi
    fi
    
    chmod 600 "$RETICULUM_CFG"
}

_mesh_start_services() {
    if [[ ! -f "$MESH_CATALOG" ]]; then
        echo '{"shared": []}' > "$MESH_CATALOG"
    fi
    
    while true; do
        if [[ -f "$MESH_CATALOG" ]]; then
            local node_name
            node_name=$(jq -r '.name' "$MESH_IDENTITY" 2>/dev/null || echo "Node")
            
            python3 - "$node_name" <<'PYEOF'
import json
import os
import sys
import time

node_name = sys.argv[1]
catalog_file = os.path.expanduser("~/.config/snowfox/mesh/catalog.json")

if os.path.exists(catalog_file):
    with open(catalog_file) as f:
        data = json.load(f)
        if data.get('shared'):
            try:
                import RNS
                identity = RNS.Identity()
                dest = RNS.Destination(
                    identity,
                    RNS.Destination.OUT,
                    RNS.Destination.SINGLE,
                    "snowfox_mesh_catalog"
                )
                msg = f"📚 CATALOG|{json.dumps({'node': node_name, 'items': data['shared']})}"
                RNS.Packet(dest, msg.encode('utf-8')).send()
            except:
                pass
PYEOF
        fi
        sleep 60
    done &
    
    while true; do
        local node_name
        node_name=$(jq -r '.name' "$MESH_IDENTITY" 2>/dev/null || echo "Node")
        _mesh_python_broadcast "🏠 NODE|$node_name"
        sleep 30
    done &
}

# ──────────────────────────────────────────────────────────────
#  Broadcast senden (Python-Version - KEIN rnx mehr!)
# ──────────────────────────────────────────────────────────────

_mesh_send_broadcast() {
    local message="$1"
    local node_name
    node_name=$(jq -r '.name' "$MESH_IDENTITY" 2>/dev/null || echo "Node")
    
    # Python-Broadcast (statt rnx)
    python3 - "$node_name" "$message" <<'PYEOF'
import RNS
import sys

node_name = sys.argv[1]
message = sys.argv[2]

try:
    reticulum = RNS.Reticulum()
    identity = RNS.Identity()
    
    dest = RNS.Destination(
        identity,
        RNS.Destination.OUT,
        RNS.Destination.SINGLE,
        "snowfox_mesh_chat"
    )
    
    full_msg = f"[{node_name}] {message}"
    packet = RNS.Packet(dest, full_msg.encode('utf-8'))
    receipt = packet.send()
    
    if not receipt:
        print("  ⚠️ Broadcast konnte nicht gesendet werden")
    
except Exception as e:
    print(f"  ❌ Broadcast-Fehler: {e}")
PYEOF
    
    echo "[$(date -Iseconds)] $node_name: $message" >> "$MESH_BROADCAST"
}

# ──────────────────────────────────────────────────────────────
#  Hilfe
# ──────────────────────────────────────────────────────────────

_mesh_help() {
    divider
    echo -e "${PURPLE}${BOLD}  🦊 SnowFox Mesh - Universelles P2P-Netzwerk${RESET}"
    echo -e "${GRAY}  Dezentral · Verschlüsselt · Autark · Handy-kompatibel${RESET}"
    divider
    echo ""
    echo -e "  ${CYAN}${BOLD}IDENTITÄT${RESET}"
    echo -e "    snowfox mesh identity [name] [typ] [ort]  — Node benennen"
    echo ""
    echo -e "  ${CYAN}${BOLD}NETZWERK${RESET}"
    echo -e "    snowfox mesh start [--name NAME]          — Mesh starten (Hotspot für Handys)"
    echo -e "    snowfox mesh start --mode adhoc           — Ad-Hoc für SnowFox-Geräte"
    echo -e "    snowfox mesh start --pass PASSWORT        — Mit Passwort schützen"
    echo -e "    snowfox mesh start --ssid NAME            — Eigene SSID setzen"
    echo -e "    snowfox mesh start --token TOKEN          — Web-Interface mit Token schützen"
    echo -e "    snowfox mesh status                       — Status anzeigen"
    echo -e "    snowfox mesh stop                         — Mesh herunterfahren (mit Cleanup)"
    echo -e "    snowfox mesh nodes                        — Alle Knoten anzeigen"
    echo -e "    snowfox mesh gateway [enable|disable]     — Internet teilen (mit IP-Forward)"
    echo ""
    echo -e "  ${CYAN}${BOLD}KOMMUNIKATION${RESET}"
    echo -e "    snowfox mesh chat                         — Interaktiver Chat"
    echo -e "    snowfox mesh chat @node \"text\"           — Privatnachricht"
    echo -e "    snowfox mesh chat @all \"text\"            — Broadcast an alle"
    echo ""
    echo -e "  ${CYAN}${BOLD}DATEIEN & INFORMATIONEN${RESET}"
    echo -e "    snowfox mesh share <pfad>                 — Datei/Ordner teilen"
    echo -e "    snowfox mesh share-all <ordner>          — Ganzen Ordner teilen"
    echo -e "    snowfox mesh get <hash>                   — Datei abrufen"
    echo -e "    snowfox mesh catalog                      — Alle Freigaben anzeigen"
    echo ""
    echo -e "  ${CYAN}${BOLD}WEB-INTERFACE (für Handys)${RESET}"
    echo -e "    snowfox mesh web                          — Webinterface starten"
    echo -e "    ${GRAY}Handy: WLAN verbinden, Browser öffnen${RESET}"
    echo -e "    ${GRAY}QR-Code wird beim Start angezeigt${RESET}"
    echo ""
    echo -e "  ${CYAN}${BOLD}WICHTIGE HINWEISE${RESET}"
    echo -e "    ${GRAY}• NetworkManager wird für Mesh-Interface deaktiviert${RESET}"
    echo -e "    ${GRAY}• Nach 'stop' wird NetworkManager automatisch wiederhergestellt${RESET}"
    echo -e "    ${GRAY}• Gateway deaktiviert IP-Forwarding automatisch${RESET}"
    echo -e "    ${GRAY}• Race-Conditions bei Ressourcen sind abgesichert${RESET}"
    echo -e "    ${GRAY}• Alle Abhängigkeiten werden geprüft${RESET}"
    divider
}

# ──────────────────────────────────────────────────────────────
#  Main Dispatcher
# ──────────────────────────────────────────────────────────────

cmd_mesh() {
    local sub="${1:-}"
    
    if [[ -z "$sub" ]]; then
        _mesh_help
        return 0
    fi
    
    shift || true
    
    case "$sub" in
        identity) _mesh_identity "$@" ;;
        start) _mesh_start "$@" ;;
        status) _mesh_status ;;
        stop) _mesh_stop ;;
        nodes) _mesh_nodes ;;
        chat) _mesh_chat ;;
        listen) _mesh_listen ;;
        share) _mesh_share "$@" ;;
        share-all) _mesh_share_all "$@" ;;
        get) _mesh_get "$@" ;;
        catalog) _mesh_catalog ;;
        gateway) _mesh_gateway "$@" ;;
        web) _mesh_web ;;
        help|"") _mesh_help ;;
        *) err "Unbekannt: $sub" && _mesh_help ;;
    esac
}

# ── Ausführung ──
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    cmd_mesh "$@"
fi
