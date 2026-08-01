#!/bin/bash
# ============================================================
#  SnowFoxOS — CLI Modul: Autostart, Layout, Apps, WebApps
#  Wird von /usr/local/bin/snowfox gesourced.
# ============================================================


# ============================================================
# snowfox autostart
# ============================================================
I3_CONFIG="$HOME/.config/i3/config"

# ============================================================
# snowfox apps
# ============================================================
APPS_DESKTOP_DIRS=("/usr/share/applications" "$HOME/.local/share/applications")
APPS_CACHE_DIR="$HOME/.cache/snowfox"
APPS_LIST_FILE="$APPS_CACHE_DIR/apps.list"

# Pakete die nie über 'snowfox apps remove' entfernbar sein sollen —
# Entfernen würde das System unbrauchbar machen.
APPS_PROTECTED=(
    i3 i3-wm i3status i3lock polybar rofi dunst
    xorg xserver-xorg-core xinit x11-xserver-utils
    network-manager bluez systemd dbus
    pipewire pipewire-pulse wireplumber
    kitty pcmanfm sudo
)

_apps_is_protected() {
    local pkg="$1"
    for p in "${APPS_PROTECTED[@]}"; do
        [[ "$pkg" == "$p" ]] && return 0
    done
    return 1
}

_apps_build_list() {
    mkdir -p "$APPS_CACHE_DIR"
    > "$APPS_LIST_FILE"
    local count=1

    for dir in "${APPS_DESKTOP_DIRS[@]}"; do
        [[ -d "$dir" ]] || continue
        for file in "$dir"/*.desktop; do
            [[ -e "$file" ]] || continue

            # Versteckte/NoDisplay-Einträge überspringen — die zeigt Rofi auch nicht
            grep -q "^NoDisplay=true" "$file" 2>/dev/null && continue

            local app_name
            app_name=$(grep -m1 "^Name=" "$file" | cut -d= -f2-)
            [[ -z "$app_name" ]] && app_name="$(basename "$file" .desktop)"

            local file_name package_name
            file_name=$(basename "$file")
            package_name=$(dpkg -S "applications/$file_name" 2>/dev/null | cut -d: -f1 | head -1)
            [[ -z "$package_name" ]] && package_name="manual"

            echo "${count}|${app_name}|${package_name}|${file}" >> "$APPS_LIST_FILE"
            ((count++))
        done
    done
}



cmd_start() {
    ENTRIES=$(grep -n "^exec " "$I3_CONFIG" 2>/dev/null)

    if [[ -z "$ENTRIES" && "$1" != "list" && -z "$1" ]]; then
        warn "Keine Autostart-Einträge gefunden."
        return
    fi

    case "$1" in
        list|"")
            divider
            echo -e "${PURPLE}${BOLD}  SnowFoxOS — Autostart Programme${RESET}"
            divider
            echo ""
            while IFS= read -r entry; do
                CMD=$(echo "$entry" | cut -d: -f2- | sed 's/^exec //')
                echo -e "  ${GREEN}${BOLD}[AN]${RESET}  ${CYAN}${CMD}${RESET}"
            done <<< "$ENTRIES"

            DISABLED=$(grep -n "^#exec " "$I3_CONFIG" 2>/dev/null)
            if [[ -n "$DISABLED" ]]; then
                while IFS= read -r entry; do
                    CMD=$(echo "$entry" | cut -d: -f2- | sed 's/^#exec //')
                    echo -e "  ${RED}${BOLD}[AUS]${RESET} ${GRAY}${CMD}${RESET}"
                done <<< "$DISABLED"
            fi
            echo ""
            divider
            echo -e "  ${GRAY}Tipp: snowfox autostart disable <programm> | snowfox autostart enable <programm>${RESET}"
            divider
            ;;
        disable)
            if [[ -z "$2" ]]; then
                err "Verwendung: snowfox autostart disable <programm>"
                exit 1
            fi
            if grep -q "^exec.*$2" "$I3_CONFIG"; then
                sed -i "s|^exec \(.*$2.*\)|#exec \1|" "$I3_CONFIG"
                i3-msg reload &>/dev/null || true
                ok "$2 deaktiviert."
            else
                err "$2 nicht gefunden oder bereits deaktiviert."
            fi
            ;;
        enable)
            if [[ -z "$2" ]]; then
                err "Verwendung: snowfox autostart enable <programm>"
                exit 1
            fi
            if grep -q "^#exec.*$2" "$I3_CONFIG"; then
                sed -i "s|^#exec \(.*$2.*\)|exec \1|" "$I3_CONFIG"
                i3-msg reload &>/dev/null || true
                ok "$2 aktiviert."
            else
                err "$2 nicht gefunden oder bereits aktiv."
            fi
            ;;
        *)
            err "Verwendung: snowfox autostart [list|enable|disable] <programm>"
            ;;
    esac
}


# ============================================================
# snowfox layout
# ============================================================
cmd_layout() {
    case "$1" in
        tiling)
            # Alle neuen Fenster gekachelt
            i3-msg "workspace_layout default" &>/dev/null
            i3-msg "[class=\".*\"] floating disable" &>/dev/null || true
            # Floating-Modifier bleibt aktiv aber neue Fenster sind tiled
            sed -i 's/^for_window \[class=".*"\] floating enable/# for_window [class=".*"] floating enable/' \
                ~/.config/i3/config 2>/dev/null || true
            i3-msg reload &>/dev/null
            ok "Layout: ${BOLD}Tiling${RESET}"
            info "  Neue Fenster werden nebeneinander angeordnet (i3-Standard)"
            ;;
        floating)
            # Alle neuen Fenster floating — klassischer Desktop-Modus
            # Eintrag setzen oder ersetzen
            if grep -q 'for_window \[class=".*"\] floating enable' ~/.config/i3/config 2>/dev/null; then
                sed -i 's/^# for_window \[class=".*"\] floating enable/for_window [class=".*"] floating enable/' \
                    ~/.config/i3/config
            else
                echo 'for_window [class=".*"] floating enable' >> ~/.config/i3/config
            fi
            i3-msg reload &>/dev/null
            ok "Layout: ${BOLD}Floating${RESET}"
            info "  Neue Fenster schweben frei — klassischer Desktop-Modus"
            info "  Tipp: snowfox layout tiling zum Zurückwechseln"
            ;;
        status|"")
            # Aktuellen Modus erkennen
            if grep -q '^for_window \[class=".*"\] floating enable' ~/.config/i3/config 2>/dev/null; then
                fox "Aktives Layout: ${BOLD}Floating${RESET} (klassischer Desktop)"
            else
                fox "Aktives Layout: ${BOLD}Tiling${RESET} (i3-Standard)"
            fi
            echo ""
            echo -e "  ${CYAN}snowfox layout tiling${RESET}    — Fenster nebeneinander (Standard)"
            echo -e "  ${CYAN}snowfox layout floating${RESET}  — Fenster schwebend (klassischer Desktop)"
            ;;
        *)
            err "Verwendung: snowfox layout [tiling|floating|status]"
            ;;
    esac
}


cmd_apps() {
    case "$1" in
        list|"")
            info "Lese installierte Anwendungen..."
            _apps_build_list

            divider
            echo -e "${PURPLE}${BOLD}  SnowFoxOS — Installierte Apps (Rofi-Einträge)${RESET}"
            divider
            printf "  %-4s %-32s %s\n" "ID" "App" "Paket"
            echo "  ────────────────────────────────────────────────────────"

            while IFS='|' read -r id name pkg _; do
                if [[ "$pkg" == "manual" ]]; then
                    printf "  ${CYAN}%-4s${RESET} %-32s ${GRAY}(manuell)${RESET}\n" "$id" "$name"
                elif _apps_is_protected "$pkg"; then
                    printf "  ${CYAN}%-4s${RESET} %-32s ${ORANGE}%s [geschützt]${RESET}\n" "$id" "$name" "$pkg"
                else
                    printf "  ${CYAN}%-4s${RESET} %-32s ${GRAY}%s${RESET}\n" "$id" "$name" "$pkg"
                fi
            done < "$APPS_LIST_FILE"

            echo ""
            divider
            info "  Entfernen: snowfox apps remove <ID>"
            ;;

        remove)
            if [[ -z "$2" ]]; then
                err "Verwendung: snowfox apps remove <ID>"
                info "  Liste anzeigen: snowfox apps list"
                exit 1
            fi

            if [[ ! -f "$APPS_LIST_FILE" ]]; then
                warn "Noch keine Liste vorhanden — erstelle sie..."
                _apps_build_list
            fi

            local match
            match=$(grep "^${2}|" "$APPS_LIST_FILE")
            if [[ -z "$match" ]]; then
                err "ID '$2' nicht gefunden."
                info "  Aktuelle Liste: snowfox apps list"
                exit 1
            fi

            local app_name pkg desktop_file
            app_name=$(echo "$match" | cut -d'|' -f2)
            pkg=$(echo "$match" | cut -d'|' -f3)
            desktop_file=$(echo "$match" | cut -d'|' -f4)

            if [[ "$pkg" != "manual" ]] && _apps_is_protected "$pkg"; then
                err "'$app_name' ($pkg) ist ein Systembestandteil und kann nicht entfernt werden."
                warn "Das Entfernen würde SnowFoxOS unbrauchbar machen."
                exit 1
            fi

            fox "App: ${BOLD}$app_name${RESET}"
            [[ "$pkg" != "manual" ]] && info "  Paket: $pkg"
            echo ""
            read -rp "$(echo -e ${ORANGE}${BOLD}"Wirklich entfernen? [j/N]: "${RESET})" CONFIRM

            if [[ "$CONFIRM" =~ ^[jJ]$ ]]; then
                if [[ "$pkg" == "manual" ]]; then
                    rm -f "$desktop_file"
                    ok "Desktop-Eintrag entfernt: $app_name"
                else
                    sudo apt-get purge -y "$pkg" && \
                        sudo apt-get autoremove -y && \
                        ok "'$app_name' deinstalliert ($pkg)" || \
                        err "Deinstallation fehlgeschlagen"
                fi
                # Liste invalidieren — beim nächsten Mal neu aufbauen
                rm -f "$APPS_LIST_FILE"
            else
                info "Abgebrochen."
            fi
            ;;

        *)
            echo -e "Verwendung:"
            echo -e "  ${CYAN}snowfox apps list${RESET}          — alle Rofi-Apps mit ID anzeigen"
            echo -e "  ${CYAN}snowfox apps remove <ID>${RESET}   — App per ID deinstallieren"
            ;;
    esac
}


# ============================================================
# snowfox webapp
# ============================================================
cmd_webapp() {
    local WAPP_DIR="$HOME/.config/snowfox/webapps"
    local WAPP_JSON="$HOME/.config/snowfox/webapps.json"
    local WAPP_DESK="$HOME/.local/share/applications"
    local WAPP_ICONS="$HOME/.config/snowfox/webapps/icons"
    mkdir -p "$WAPP_DIR" "$WAPP_DESK" "$WAPP_ICONS"

    case "$1" in
        add)
            if [[ -z "$2" || -z "$3" ]]; then
                err "Verwendung: snowfox webapp add <name> <url>"
                err "Beispiel:   snowfox webapp add ChatGPT https://chatgpt.com"
                exit 1
            fi

            local WA_NAME="$2"
            local WA_URL="$3"
            local WA_SAFE
            WA_SAFE=$(echo "$WA_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')

            fox "Neue WebApp: ${BOLD}$WA_NAME${RESET}"
            info "  URL: $WA_URL"

            # ── Favicon herunterladen ─────────────────────────
            local WA_ICON="web-browser"
            local WA_ICON_PATH="$WAPP_ICONS/${WA_SAFE}.png"
            local WA_DOMAIN
            WA_DOMAIN=$(echo "$WA_URL" | sed 's|https\?://||' | cut -d'/' -f1)

            info "  Lade Favicon von $WA_DOMAIN..."
            local FAVICON_URLS=(
                "https://www.google.com/s2/favicons?domain=${WA_DOMAIN}&sz=128"
                "https://${WA_DOMAIN}/favicon.ico"
                "https://${WA_DOMAIN}/favicon.png"
            )
            for FURL in "${FAVICON_URLS[@]}"; do
                if curl -sfL --max-time 5 "$FURL" -o "$WA_ICON_PATH" 2>/dev/null; then
                    if file "$WA_ICON_PATH" 2>/dev/null | grep -qiE "image|icon|PNG|GIF|JPEG"; then
                        if file "$WA_ICON_PATH" | grep -qi "icon\|ICO"; then
                            convert "$WA_ICON_PATH" "$WA_ICON_PATH" 2>/dev/null || true
                        fi
                        WA_ICON="$WA_ICON_PATH"
                        ok "Favicon geladen"
                        break
                    fi
                fi
            done
            [[ "$WA_ICON" == "web-browser" ]] && warn "Kein Favicon gefunden — verwende Standard-Icon"

            # ── Browser wählen ────────────────────────────────
            echo ""
            echo -e "  ${CYAN}1${RESET}) Librewolf   (WebApp-Modus — kein Browser-UI, empfohlen)"
            echo -e "  ${CYAN}2${RESET}) Librewolf   (mit Addons — nutzt Hauptprofil)"
            echo -e "  ${CYAN}3${RESET}) Helium      (App-Modus — kein Browser-UI)"
            echo -e "  ${CYAN}4${RESET}) Helium      (mit Addons — nutzt Hauptprofil)"
            echo -e "  ${CYAN}5${RESET}) Zen Browser"
            echo -e "  ${CYAN}6${RESET}) Chromium"
            echo -e "  ${CYAN}7${RESET}) Brave"
            echo -e "  ${CYAN}8${RESET}) Firefox-ESR"
            echo ""
            read -rp "$(echo -e ${PURPLE}${BOLD}"Browser wählen [1-8] (Default: 1): "${RESET})" WA_BR
            WA_BR=${WA_BR:-1}

            local WA_BIN WA_EXEC WA_PROFILE
            case "$WA_BR" in
                1)
                    # Librewolf WebApp-Modus - komplett ohne Browser-UI
                    WA_BIN="librewolf"
                    WA_PROFILE="$WAPP_DIR/$WA_SAFE/librewolf-profile"
                    mkdir -p "$WA_PROFILE"
                    
                    # WebApp-spezifische Librewolf-Einstellungen
                    cat > "$WA_PROFILE/user.js" << 'EOF'
// WebApp Optimierungen für Librewolf
user_pref("browser.privatebrowsing.autostart", false);
user_pref("browser.sessionstore.resume_from_crash", false);
user_pref("browser.tabs.warnOnClose", false);
user_pref("browser.warnOnQuit", false);
user_pref("dom.disable_open_during_load", false);
// UI komplett ausblenden für WebApp-Modus
user_pref("browser.uidensity", 1);
user_pref("browser.urlbar.suggest.history", false);
user_pref("browser.urlbar.suggest.bookmark", false);
user_pref("browser.urlbar.suggest.openpage", false);
// Keine Toolbars oder Menüs
user_pref("browser.uiCustomization.state", "{\"placements\":{\"widget-overflow-fixed-list\":[],\"nav-bar\":[\"back-button\",\"forward-button\",\"stop-reload-button\",\"urlbar-container\",\"downloads-button\"],\"toolbar-menubar\":[],\"TabsToolbar\":[],\"PersonalToolbar\":[]},\"seen\":[\"developer-button\"],\"dirtyAreaCache\":[]}");
// Keine Tabs-Leiste
user_pref("browser.tabs.drawInTitlebar", false);
user_pref("browser.tabs.allowTabDetach", false);
user_pref("browser.tabs.loadInBackground", true);
// Vollbild-API erlauben
user_pref("full-screen-api.enabled", true);
user_pref("full-screen-api.allow-trusted-requests-only", false);
EOF
                    
                    # Desktop-Eintrag mit --new-window und --class für WebApp-Modus
                    WA_EXEC="$WA_BIN --new-window \"$WA_URL\" --class=snowfox-webapp-$WA_SAFE --profile \"$WA_PROFILE\""
                    ;;
                2)
                    # Librewolf mit Addons (nutzt Hauptprofil)
                    WA_BIN="librewolf"
                    # Hauptprofil finden
                    local LW_MAIN_PROFILE
                    LW_MAIN_PROFILE=$(find "$HOME/.librewolf" -maxdepth 2 -name "*.default" -type d 2>/dev/null | head -1)
                    if [[ -z "$LW_MAIN_PROFILE" ]]; then
                        LW_MAIN_PROFILE="$HOME/.librewolf/default"
                    fi
                    WA_EXEC="$WA_BIN --new-window \"$WA_URL\" --class=snowfox-webapp-$WA_SAFE --profile \"$LW_MAIN_PROFILE\""
                    ;;
                3)
                    WA_BIN="$HOME/Applications/helium.AppImage"
                    WA_EXEC="$WA_BIN --app=$WA_URL --class=snowfox-webapp-$WA_SAFE"
                    ;;
                4)
                    WA_BIN="$HOME/Applications/helium.AppImage"
                    local WA_PROF="$WAPP_DIR/$WA_SAFE/profile"
                    mkdir -p "$WA_PROF"
                    local WA_MAIN
                    WA_MAIN=$(find "$HOME/.config/net.imput.helium" -maxdepth 2 -name "Extensions" -type d 2>/dev/null | head -1)
                    [[ -n "$WA_MAIN" ]] && ln -sf "$WA_MAIN" "$WA_PROF/Extensions" 2>/dev/null || true
                    WA_EXEC="$WA_BIN --app=$WA_URL --user-data-dir=$WA_PROF --class=snowfox-webapp-$WA_SAFE"
                    ;;
                5)
                    WA_BIN="/opt/zen-browser.AppImage"
                    WA_EXEC="$WA_BIN --app=$WA_URL --class=snowfox-webapp-$WA_SAFE"
                    ;;
                6)
                    WA_BIN="chromium"
                    WA_EXEC="$WA_BIN --app=$WA_URL --class=snowfox-webapp-$WA_SAFE"
                    ;;
                7)
                    WA_BIN="brave-browser"
                    WA_EXEC="$WA_BIN --app=$WA_URL --class=snowfox-webapp-$WA_SAFE"
                    ;;
                8)
                    WA_BIN="firefox-esr"
                    WA_EXEC="$WA_BIN --ssb=$WA_URL"
                    ;;
                *)
                    # Fallback auf Librewolf WebApp-Modus
                    WA_BIN="librewolf"
                    WA_PROFILE="$WAPP_DIR/$WA_SAFE/librewolf-profile"
                    mkdir -p "$WA_PROFILE"
                    WA_EXEC="$WA_BIN --new-window \"$WA_URL\" --class=snowfox-webapp-$WA_SAFE --profile \"$WA_PROFILE\""
                    ;;
            esac

            # ── Desktop-Eintrag erstellen ─────────────────────
            cat > "$WAPP_DESK/snowfox-webapp-${WA_SAFE}.desktop" << DEOF
[Desktop Entry]
Name=$WA_NAME
Comment=SnowFox WebApp — $WA_URL
Exec=$WA_EXEC
Icon=$WA_ICON
Type=Application
Categories=Network;WebApp;
StartupNotify=true
StartupWMClass=snowfox-webapp-$WA_SAFE
DEOF

            # ── JSON speichern ────────────────────────────────
            python3 -c "
import json, os
path = '$WAPP_JSON'
data = []
if os.path.exists(path):
    try:
        with open(path) as f:
            data = json.load(f)
    except:
        data = []
data = [x for x in data if x.get('name') != '$WA_NAME']
data.append({
    'name':'$WA_NAME',
    'url':'$WA_URL',
    'safe':'$WA_SAFE',
    'icon':'$WA_ICON',
    'browser':'$WA_BIN',
    'mode': 'webapp' if '$WA_BR' in ['1', '2'] else 'app'
})
with open(path, 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null

            update-desktop-database "$WAPP_DESK" 2>/dev/null || true
            ok "WebApp '${BOLD}$WA_NAME${RESET}' erstellt"
            info "  Starten:  snowfox webapp open $WA_SAFE"
            info "  In Rofi:  '$WA_NAME' suchen"
            
            if [[ "$WA_BR" == "1" ]]; then
                info "  ${GREEN}✓ Librewolf im WebApp-Modus (kein Browser-UI)${RESET}"
            fi
            ;;

        list)
            divider
            echo -e "${PURPLE}${BOLD}  SnowFoxOS — WebApps${RESET}"
            divider
            if [[ ! -f "$WAPP_JSON" ]]; then
                warn "Keine WebApps vorhanden."
                info "  Erstellen: snowfox webapp add <name> <url>"
                return
            fi
            python3 -c "
import json
with open('$WAPP_JSON') as f:
    data = json.load(f)
for i, a in enumerate(data, 1):
    mode = a.get('mode', 'app')
    mode_str = '🌐 WebApp' if mode == 'webapp' else '📱 App'
    print(f\"  {i}) {a['name']}  →  {a['url']}\")
    print(f\"     {mode_str} | Browser: {a.get('browser', 'unbekannt')}\")
" 2>/dev/null
            echo ""
            divider
            ;;

        open)
            if [[ -z "$2" ]]; then
                err "Verwendung: snowfox webapp open <name>"
                exit 1
            fi
            local WA_SAFE2
            WA_SAFE2=$(echo "$2" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')
            local WA_DESK="$WAPP_DESK/snowfox-webapp-${WA_SAFE2}.desktop"
            if [[ ! -f "$WA_DESK" ]]; then
                err "WebApp '$2' nicht gefunden. Liste: snowfox webapp list"
                exit 1
            fi
            local WA_EXEC2
            WA_EXEC2=$(grep "^Exec=" "$WA_DESK" | cut -d= -f2-)
            fox "Öffne ${BOLD}$2${RESET}..."
            eval "$WA_EXEC2" &
            ;;

        remove)
            if [[ -z "$2" ]]; then
                err "Verwendung: snowfox webapp remove <name>"
                exit 1
            fi
            local WA_SAFE3
            WA_SAFE3=$(echo "$2" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')
            rm -f "$WAPP_DESK/snowfox-webapp-${WA_SAFE3}.desktop"
            rm -rf "$WAPP_DIR/$WA_SAFE3"
            rm -f "$WAPP_ICONS/${WA_SAFE3}.png"
            python3 -c "
import json, os
path = '$WAPP_JSON'
if not os.path.exists(path): exit()
with open(path) as f:
    data = json.load(f)
data = [x for x in data if x.get('safe') != '$WA_SAFE3']
with open(path, 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null
            update-desktop-database "$WAPP_DESK" 2>/dev/null || true
            ok "WebApp '$2' entfernt."
            ;;

        *)
            echo -e "Verwendung:"
            echo -e "  ${CYAN}snowfox webapp add <name> <url>${RESET}   — neue WebApp erstellen"
            echo -e "  ${CYAN}snowfox webapp list${RESET}                — alle WebApps anzeigen"
            echo -e "  ${CYAN}snowfox webapp open <name>${RESET}         — WebApp starten"
            echo -e "  ${CYAN}snowfox webapp remove <name>${RESET}      — WebApp entfernen"
            ;;
    esac
}
