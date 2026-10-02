#!/bin/bash
# ============================================================
#  SnowFoxOS — CLI Module: Desktop
#  Autostart, Layout, Apps, WebApps
#  Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)
# ============================================================

I3_CONFIG="$HOME/.config/i3/config"
WEBAPP_DIR="$HOME/.config/snowfox/webapps"
WEBAPP_DESK="$HOME/.local/share/applications"
WEBAPP_ICONS="$HOME/.config/snowfox/webapps/icons"

# ============================================================
# snowfox auto — Autostart management
# ============================================================
cmd_start() {
    case "$1" in
        list|"")
            _auto_list
            ;;
        enable)
            _auto_enable "$2"
            ;;
        disable)
            _auto_disable "$2"
            ;;
        *)
            err "Usage: snowfox auto [list|enable|disable] [program]"
            exit 1
            ;;
    esac
}

_auto_list() {
    header "Autostart"

    # ── Custom autostart entries (snowfox-managed) ──────────
    local AUTO_DIR="$HOME/.config/autostart"
    section "User Applications"

    if [[ -d "$AUTO_DIR" ]]; then
        local found=false
        for desktop in "$AUTO_DIR"/*.desktop; do
            [[ -e "$desktop" ]] || continue
            local name
            name=$(grep -m1 "^Name=" "$desktop" | cut -d= -f2-)
            local hidden
            hidden=$(grep -m1 "^Hidden=" "$desktop" | cut -d= -f2-)
            [[ -z "$name" ]] && name=$(basename "$desktop" .desktop)

            if [[ "$hidden" == "true" ]]; then
                printf "  ${RED}%-4s${RESET} ${GRAY}%s${RESET}\n" "[off]" "$name"
            else
                printf "  ${GREEN}%-4s${RESET} ${CYAN}%s${RESET}\n" "[on]" "$name"
            fi
            found=true
        done
        if ! $found; then
            info "  No user autostart entries."
        fi
    else
        info "  No autostart directory found."
    fi

    # ── i3 exec entries (system/desktop components) ────────
    section "i3 Session"

    local i3_entries
    i3_entries=$(grep -n "^exec " "$I3_CONFIG" 2>/dev/null)
    if [[ -n "$i3_entries" ]]; then
        while IFS= read -r entry; do
            local cmd
            cmd=$(echo "$entry" | cut -d: -f2- | sed 's/^exec //')
            printf "  ${GREEN}%-4s${RESET} ${CYAN}%s${RESET}\n" "[on]" "$cmd"
        done <<< "$i3_entries"
    else
        info "  No exec entries in i3 config."
    fi

    local i3_disabled
    i3_disabled=$(grep -n "^#exec " "$I3_CONFIG" 2>/dev/null)
    if [[ -n "$i3_disabled" ]]; then
        while IFS= read -r entry; do
            local cmd
            cmd=$(echo "$entry" | cut -d: -f2- | sed 's/^#exec //')
            printf "  ${RED}%-4s${RESET} ${GRAY}%s${RESET}\n" "[off]" "$cmd"
        done <<< "$i3_disabled"
    fi

    divider
    info "Enable:  snowfox auto enable <program>"
    info "Disable: snowfox auto disable <program>"
    echo ""
}

_auto_enable() {
    local target="$1"
    [[ -z "$target" ]] && err "Usage: snowfox auto enable <program>" && exit 1

    # Try i3 config first
    if grep -q "^#exec.*$target" "$I3_CONFIG" 2>/dev/null; then
        sed -i "s|^#exec \(.*$target.*\)|exec \1|" "$I3_CONFIG"
        i3-msg reload &>/dev/null || true
        ok "$target enabled in i3."
        return
    fi

    # Try user autostart
    local desktop="$HOME/.config/autostart/$target.desktop"
    if [[ -f "$desktop" ]]; then
        sed -i 's/^Hidden=true/Hidden=false/' "$desktop"
        ok "$target enabled in autostart."
        return
    fi

    err "$target not found in i3 config or autostart."
}

_auto_disable() {
    local target="$1"
    [[ -z "$target" ]] && err "Usage: snowfox auto disable <program>" && exit 1

    # Try i3 config first
    if grep -q "^exec.*$target" "$I3_CONFIG" 2>/dev/null; then
        sed -i "s|^exec \(.*$target.*\)|#exec \1|" "$I3_CONFIG"
        i3-msg reload &>/dev/null || true
        ok "$target disabled in i3."
        return
    fi

    # Try user autostart
    local desktop="$HOME/.config/autostart/$target.desktop"
    if [[ -f "$desktop" ]]; then
        sed -i 's/^Hidden=false/Hidden=true/' "$desktop"
        ok "$target disabled in autostart."
        return
    fi

    err "$target not found in i3 config or autostart."
}

# ============================================================
# snowfox lay — Window layout mode
# ============================================================
cmd_layout() {
    case "$1" in
        tiling)
            i3-msg "workspace_layout default" &>/dev/null
            i3-msg "[class=\".*\"] floating disable" &>/dev/null || true
            sed -i 's/^for_window \[class=".*"\] floating enable/# for_window [class=".*"] floating enable/' \
                ~/.config/i3/config 2>/dev/null || true
            i3-msg reload &>/dev/null
            ok "Layout: ${BOLD}Tiling${RESET}"
            info "  New windows are arranged side by side (i3 default)"
            ;;
        floating)
            if grep -q 'for_window \[class=".*"\] floating enable' ~/.config/i3/config 2>/dev/null; then
                sed -i 's/^# for_window \[class=".*"\] floating enable/for_window [class=".*"] floating enable/' \
                    ~/.config/i3/config
            else
                echo 'for_window [class=".*"] floating enable' >> ~/.config/i3/config
            fi
            i3-msg reload &>/dev/null
            ok "Layout: ${BOLD}Floating${RESET}"
            info "  New windows float freely — classic desktop mode"
            ;;
        status|"")
            header "Window Layout"
            if grep -q '^for_window \[class=".*"\] floating enable' ~/.config/i3/config 2>/dev/null; then
                row "Current" "Floating (classic desktop)" "$CYAN"
            else
                row "Current" "Tiling (i3 default)" "$CYAN"
            fi
            echo ""
            info "snowfox lay tiling    — windows arranged side by side"
            info "snowfox lay floating  — windows float freely"
            echo ""
            ;;
        *)
            err "Usage: snowfox lay [tiling|floating|status]"
            exit 1
            ;;
    esac
}

# ============================================================
# snowfox apps — Installed applications (Rofi entries)
# ============================================================
cmd_apps() {
    case "$1" in
        list|"")
            _apps_list
            ;;
        remove)
            _apps_remove "$2"
            ;;
        find|install)
            # Placeholder — not yet implemented
            header "App Store"
            warn "Not implemented yet."
            info "  Planned: search and install packages from the terminal."
            info "  Current workaround: sudo apt install <package>"
            echo ""
            ;;
        *)
            err "Usage: snowfox apps [list|remove|find]"
            exit 1
            ;;
    esac
}

APPS_CACHE_DIR="$HOME/.cache/snowfox"
APPS_LIST_FILE="$APPS_CACHE_DIR/apps.list"
APPS_DESKTOP_DIRS=("/usr/share/applications" "$HOME/.local/share/applications")

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

_apps_list() {
    info "Reading installed applications..."
    _apps_build_list

    header "Installed Apps"

    printf "  %-4s %-32s %s\n" "ID" "App" "Package"
    divider

    while IFS='|' read -r id name pkg _; do
        if [[ "$pkg" == "manual" ]]; then
            printf "  ${CYAN}%-4s${RESET} %-32s ${GRAY}(manual)${RESET}\n" "$id" "$name"
        elif _apps_is_protected "$pkg"; then
            printf "  ${CYAN}%-4s${RESET} %-32s ${ORANGE}%s [protected]${RESET}\n" "$id" "$name" "$pkg"
        else
            printf "  ${CYAN}%-4s${RESET} %-32s ${GRAY}%s${RESET}\n" "$id" "$name" "$pkg"
        fi
    done < "$APPS_LIST_FILE"

    divider
    info "Remove: snowfox apps remove <ID>"
    echo ""
}

_apps_remove() {
    local id="$1"
    [[ -z "$id" ]] && err "Usage: snowfox apps remove <ID>" && exit 1

    if [[ ! -f "$APPS_LIST_FILE" ]]; then
        warn "No list cached — building..."
        _apps_build_list
    fi

    local match
    match=$(grep "^${id}|" "$APPS_LIST_FILE")
    if [[ -z "$match" ]]; then
        err "ID '$id' not found."
        info "  Show list: snowfox apps list"
        exit 1
    fi

    local app_name pkg desktop_file
    app_name=$(echo "$match" | cut -d'|' -f2)
    pkg=$(echo "$match" | cut -d'|' -f3)
    desktop_file=$(echo "$match" | cut -d'|' -f4)

    if [[ "$pkg" != "manual" ]] && _apps_is_protected "$pkg"; then
        err "'$app_name' ($pkg) is a system component and cannot be removed."
        exit 1
    fi

    fox "App: ${BOLD}$app_name${RESET}"
    [[ "$pkg" != "manual" ]] && info "  Package: $pkg"
    echo ""
    read -rp "$(echo -e ${ORANGE}${BOLD}"Really remove? [y/N]: "${RESET})" CONFIRM

    if [[ "$CONFIRM" =~ ^[yY]$ ]]; then
        if [[ "$pkg" == "manual" ]]; then
            rm -f "$desktop_file"
            ok "Desktop entry removed: $app_name"
        else
            sudo apt-get purge -y "$pkg" && \
                sudo apt-get autoremove -y && \
                ok "'$app_name' uninstalled ($pkg)" || \
                err "Uninstall failed"
        fi
        rm -f "$APPS_LIST_FILE"
    else
        info "Cancelled."
    fi
}

# ============================================================
# snowfox web — WebApps (Zen Browser, app mode)
# ============================================================
cmd_webapp() {
    mkdir -p "$WEBAPP_DIR" "$WEBAPP_DESK" "$WEBAPP_ICONS"

    case "$1" in
        add)
            _webapp_add "$2" "$3"
            ;;
        list)
            _webapp_list
            ;;
        open)
            _webapp_open "$2"
            ;;
        remove)
            _webapp_remove "$2"
            ;;
        *)
            header "snowfox web"
            info "  snowfox web add <name> <url>  — create new web app"
            info "  snowfox web list             — list all web apps"
            info "  snowfox web open <name>      — launch web app"
            info "  snowfox web remove <name>    — remove web app"
            echo ""
            ;;
    esac
}

_webapp_add() {
    local name="$1"
    local url="$2"

    if [[ -z "$name" || -z "$url" ]]; then
        err "Usage: snowfox web add <name> <url>"
        err "Example: snowfox web add ChatGPT https://chatgpt.com"
        exit 1
    fi

    local safe
    safe=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')

    fox "New WebApp: ${BOLD}$name${RESET}"
    info "  URL: $url"

    # ── Download favicon ─────────────────────────────────────
    local icon="web-browser"
    local icon_path="$WEBAPP_ICONS/${safe}.png"
    local domain
    domain=$(echo "$url" | sed 's|https\?://||' | cut -d'/' -f1)

    info "  Fetching favicon from $domain..."
    local favicon_urls=(
        "https://www.google.com/s2/favicons?domain=${domain}&sz=128"
        "https://${domain}/favicon.ico"
        "https://${domain}/favicon.png"
    )
    for furl in "${favicon_urls[@]}"; do
        if curl -sfL --max-time 5 "$furl" -o "$icon_path" 2>/dev/null; then
            if file "$icon_path" 2>/dev/null | grep -qiE "image|icon|PNG|GIF|JPEG"; then
                icon="$icon_path"
                ok "Favicon loaded"
                break
            fi
        fi
    done
    [[ "$icon" == "web-browser" ]] && warn "No favicon found — using default icon"

    # ── Zen Browser app mode ─────────────────────────────────
    # Zen has no native --app flag. We launch it as a separate instance
    # with a dedicated profile directory and no browser UI via CSS.
    # The custom profile ensures isolation from the main browser session.
    local profile_dir="$WEBAPP_DIR/$safe/zen-profile"
    mkdir -p "$profile_dir"

    # Create userChrome.css to hide all browser UI (tabs, URL bar, sidebar)
    mkdir -p "$profile_dir/chrome"
    cat > "$profile_dir/chrome/userChrome.css" << 'CSSEOF'
/* SnowFox WebApp — hide all browser chrome */
#navigator-toolbox,
#sidebar-box,
#sidebar-main,
#tabbrowser-tabs,
#urlbar-container,
#PersonalToolbar,
#TabsToolbar {
    display: none !important;
}
/* Full window content */
#browser {
    margin-top: 0 !important;
}
CSSEOF

    # Preferences for app mode
    cat > "$profile_dir/user.js" << 'JSEOF'
// SnowFox WebApp preferences
user_pref("browser.tabs.drawInTitlebar", false);
user_pref("browser.tabs.warnOnClose", false);
user_pref("browser.warnOnQuit", false);
user_pref("browser.sessionstore.resume_from_crash", false);
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("browser.fullscreen.autohide", true);
user_pref("dom.disable_open_during_load", false);
JSEOF

    local exec_cmd="zen-browser --profile \"$profile_dir\" --new-window \"$url\""

    # ── Create .desktop entry ────────────────────────────────
    cat > "$WEBAPP_DESK/snowfox-webapp-${safe}.desktop" << DEOF
[Desktop Entry]
Name=$name
Comment=SnowFox WebApp — $url
Exec=$exec_cmd
Icon=$icon
Type=Application
Categories=Network;WebApp;
StartupNotify=true
StartupWMClass=zen
DEOF

    update-desktop-database "$WEBAPP_DESK" 2>/dev/null || true

    ok "WebApp '${BOLD}$name${RESET}' created"
    info "  Launch: snowfox web open $safe"
    info "  Rofi:   search for '$name'"
    echo ""
}

_webapp_list() {
    header "WebApps"

    if [[ ! -d "$WEBAPP_DESK" ]]; then
        info "No WebApps found."
        exit 0
    fi

    local found=false
    for desktop in "$WEBAPP_DESK"/snowfox-webapp-*.desktop; do
        [[ -e "$desktop" ]] || continue
        local name url
        name=$(grep -m1 "^Name=" "$desktop" | cut -d= -f2-)
        url=$(grep -m1 "^Comment=" "$desktop" | sed 's/.*— //')
        printf "  ${CYAN}%-24s${RESET} ${GRAY}%s${RESET}\n" "$name" "$url"
        found=true
    done

    if ! $found; then
        info "No WebApps found."
    fi
    echo ""
}

_webapp_open() {
    local name="$1"
    [[ -z "$name" ]] && err "Usage: snowfox web open <name>" && exit 1

    local safe
    safe=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')

    local desktop="$WEBAPP_DESK/snowfox-webapp-${safe}.desktop"
    if [[ ! -f "$desktop" ]]; then
        err "WebApp '$name' not found. List: snowfox web list"
        exit 1
    fi

    local exec_cmd
    exec_cmd=$(grep "^Exec=" "$desktop" | cut -d= -f2-)
    fox "Opening ${BOLD}$name${RESET}..."
    eval "$exec_cmd" &
}

_webapp_remove() {
    local name="$1"
    [[ -z "$name" ]] && err "Usage: snowfox web remove <name>" && exit 1

    local safe
    safe=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')

    rm -f "$WEBAPP_DESK/snowfox-webapp-${safe}.desktop"
    rm -rf "$WEBAPP_DIR/$safe"
    rm -f "$WEBAPP_ICONS/${safe}.png"

    update-desktop-database "$WEBAPP_DESK" 2>/dev/null || true
    ok "WebApp '$name' removed."
}
