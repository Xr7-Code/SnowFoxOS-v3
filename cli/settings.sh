#!/bin/bash
# ============================================================
#  SnowFoxOS — CLI Modul: Central Settings Manager
#  Zweck: System-Standards, Sprache, Tastatur, Nutzer & Zeit
# ============================================================

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/snowfox"
CONFIG_FILE="$CONFIG_DIR/snowfox.conf"

init_settings() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        mkdir -p "$CONFIG_DIR"
        cat <<'EOF' > "$CONFIG_FILE"
# ============================================================
#  SnowFoxOS — Standard-Anwendungen & Präferenzen
# ============================================================

DEFAULT_BROWSER=librewolf
DEFAULT_TERMINAL=kitty
DEFAULT_EDITOR=codium
DEFAULT_FILEMANAGER=pcmanfm
EOF
        chmod 644 "$CONFIG_FILE"
    fi
}

get_setting() {
    init_settings
    local key="$1"
    local default_val="$2"
    local val
    key=$(echo "$key" | tr '[:lower:]' '[:upper:]')
    val=$(grep -E "^${key}=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2-)
    echo "${val:-$default_val}"
}

set_setting() {
    init_settings
    local key="$1"
    local val="$2"
    key=$(echo "$key" | tr '[:lower:]' '[:upper:]')

    if grep -q -E "^${key}=" "$CONFIG_FILE"; then
        sed -i "s|^${key}=.*|${key}=${val}|" "$CONFIG_FILE"
    else
        echo "${key}=${val}" >> "$CONFIG_FILE"
    fi
}

# ── Unterfunktionen ──────────────────────────────────────────

# 1. Standard-Anwendungen
settings_defaults() {
    header "Standard-Anwendungen"
    case "$1" in
        set)
            if [[ -z "$2" || -z "$3" ]]; then
                err "Verwendung: snowfox settings defaults set <browser|terminal|editor|fm> <befehl>"
                return 1
            fi
            case "$2" in
                browser) set_setting "DEFAULT_BROWSER" "$3" ;;
                terminal) set_setting "DEFAULT_TERMINAL" "$3" ;;
                editor)   set_setting "DEFAULT_EDITOR" "$3" ;;
                fm|filemanager) set_setting "DEFAULT_FILEMANAGER" "$3" ;;
                *) err "Unbekannte Kategorie: $2 (Erlaubt: browser, terminal, editor, fm)"; return 1 ;;
            esac
            ok "Standard für $2 auf '$3' gesetzt."
            ;;
        *)
            row "Browser"      "$(get_setting "DEFAULT_BROWSER" "librewolf")"
            row "Terminal"     "$(get_setting "DEFAULT_TERMINAL" "kitty")"
            row "Editor"       "$(get_setting "DEFAULT_EDITOR" "codium")"
            row "Dateimanager" "$(get_setting "DEFAULT_FILEMANAGER" "pcmanfm")"
            echo ""
            info "Ändern mit: snowfox settings defaults set <kategorie> <programm>"
            ;;
    esac
}

# 2. Tastaturlayout
settings_keyboard() {
    header "Tastaturlayout"
    if [[ -n "$1" ]]; then
        sudo localectl set-x11-keymap "$1"
        setxkbmap "$1" 2>/dev/null || true
        ok "Tastaturlayout auf '$1' geändert."
    else
        local current
        current=$(localectl status | grep "X11 Layout" | awk '{print $3}')
        row "Aktuelles Layout" "${current:-de}"
        echo ""
        info "Ändern mit: snowfox settings keyboard <layout> (z. B. de, us)"
    fi
}

# 3. Sprache & Region (Locale)
settings_locale() {
    header "Sprache & Region"
    if [[ -n "$1" ]]; then
        sudo localectl set-locale LANG="$1"
        ok "Systemsprache auf '$1' gesetzt (Neuanmeldung erforderlich)."
    else
        local current
        current=$(localectl status | grep "System Locale" | cut -d'=' -f2)
        row "Aktuelle Sprache" "${current:-de_DE.UTF-8}"
        echo ""
        info "Ändern mit: snowfox settings language <locale> (z. B. de_DE.UTF-8, en_US.UTF-8)"
    fi
}

# 4. Zeit & Zeitzone
settings_time() {
    header "Uhrzeit & Standort"
    if [[ -n "$1" ]]; then
        if sudo timedatectl set-timezone "$1" 2>/dev/null; then
            ok "Zeitzone auf '$1' geändert."
        else
            err "Ungültige Zeitzone: $1"
            info "Mögliche Zeitzonen anzeigen: timedatectl list-timezones"
        fi
    else
        local tz
        tz=$(timedatectl show --property=Timezone --value 2>/dev/null || echo "Unbekannt")
        local time_str
        time_str=$(date "+%Y-%m-%d %H:%M:%S %Z")
        row "Aktuelle Zeitzone" "$tz"
        row "Systemzeit"        "$time_str"
        echo ""
        info "Ändern mit: snowfox settings time <Zeitzone> (z. B. Europe/Berlin)"
    fi
}

# 5. Nutzerverwaltung & Passwörter
settings_user() {
    header "Nutzerverwaltung"
    local action="$1"
    local username="$2"

    case "$action" in
        passwd)
            local target_user="${username:-$USER}"
            info "Passwort ändern für Nutzer: $target_user"
            passwd "$target_user"
            ;;
        add)
            if [[ -z "$username" ]]; then
                err "Verwendung: snowfox settings user add <benutzername>"
                return 1
            fi
            sudo adduser "$username"
            ;;
        del)
            if [[ -z "$username" ]]; then
                err "Verwendung: snowfox settings user del <benutzername>"
                return 1
            fi
            sudo deluser --remove-home "$username"
            ;;
        *)
            row "Aktueller Nutzer" "$USER"
            row "Home-Verzeichnis" "$HOME"
            echo ""
            info "Befehle:"
            info "  snowfox settings user passwd [username] — Passwort ändern"
            info "  snowfox settings user add <username>     — Neuen Nutzer anlegen"
            info "  snowfox settings user del <username>     — Nutzer löschen"
            ;;
    esac
}

# 6. Bluetooth
settings_bluetooth() {
    header "Bluetooth"
    case "$1" in
        on)
            sudo systemctl enable --now bluetooth &>/dev/null
            rfkill unblock bluetooth &>/dev/null
            bluetoothctl power on &>/dev/null
            ok "Bluetooth aktiviert."
            ;;
        off)
            bluetoothctl power off &>/dev/null
            rfkill block bluetooth &>/dev/null
            info "Bluetooth deaktiviert."
            ;;
        toggle)
            if bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
                settings_bluetooth off
            else
                settings_bluetooth on
            fi
            ;;
        boot-off)
            sudo sed -i -E 's/^#?\s*AutoEnable\s*=.*/AutoEnable=false/' /etc/bluetooth/main.conf
            ok "Bluetooth wird ab dem nächsten Booten standardmäßig AUS sein."
            ;;
        boot-on)
            sudo sed -i -E 's/^#?\s*AutoEnable\s*=.*/AutoEnable=true/' /etc/bluetooth/main.conf
            ok "Bluetooth wird ab dem nächsten Booten standardmäßig AN sein."
            ;;
        *)
            local status="inaktiv"
            bluetoothctl show 2>/dev/null | grep -q "Powered: yes" && status="aktiv"
            
            local boot_status="AUS (Standard)"
            if grep -iE '^\s*AutoEnable\s*=\s*true' /etc/bluetooth/main.conf &>/dev/null; then
                boot_status="AN"
            elif grep -iE '^\s*AutoEnable\s*=\s*false' /etc/bluetooth/main.conf &>/dev/null; then
                boot_status="AUS"
            fi

            row "Bluetooth Status (aktuell)" "$status"
            row "Autostart beim Booten"      "$boot_status"
            echo ""
            info "Befehle:"
            info "  snowfox settings bluetooth <on|off|toggle>"
            info "  snowfox settings bluetooth <boot-on|boot-off>"
            ;;
    esac
}

# ── Hauptfunktion: Main CLI Entrypoint ───────────────────────
cmd_settings() {
    init_settings
    local subcmd="$1"
    shift 2>/dev/null || true

    case "$subcmd" in
        defaults)  settings_defaults "$@" ;;
        keyboard|keymap) settings_keyboard "$@" ;;
        language|locale) settings_locale "$@" ;;
        time|timezone)   settings_time "$@" ;;
        user|users)      settings_user "$@" ;;
        bluetooth|bt)    settings_bluetooth "$@" ;;

        list|show|"")
            header "SnowFoxOS — Einstellungen Overview"
            settings_defaults
            echo ""
            settings_keyboard
            echo ""
            settings_time
            echo ""
            settings_bluetooth
            divider
            ;;

        help|*)
            header "SnowFoxOS Settings Manager"
            row "snowfox settings defaults"  "Standard-Apps verwalten (LibreWolf, PCManFM, Codium, Kitty)"
            row "snowfox settings keyboard"  "Tastaturlayout anzeigen / ändern"
            row "snowfox settings language"  "Systemsprache anzeigen / ändern"
            row "snowfox settings time"      "Zeitzone & Uhrzeit konfigurieren"
            row "snowfox settings user"      "Nutzer anlegen, löschen oder Passwort ändern"
            row "snowfox settings bluetooth" "Bluetooth ein-/ausschalten"
            divider
            ;;
    esac
}
