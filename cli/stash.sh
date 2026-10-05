#!/bin/bash
# ============================================================
#   SnowFoxOS — CLI Module: stash (Package Manager)
#   Curated categories + apt-cache search + size preview.
#   Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)
# ============================================================

STASH_CACHE_DIR="$HOME/.cache/snowfox"
STASH_INSTALLED_FILE="$STASH_CACHE_DIR/installed.list"

# ── Protected packages (never removable via stash) ───────────
STASH_PROTECTED=(
    i3 i3-wm i3status i3lock polybar rofi dunst
    xorg xserver-xorg-core xinit x11-xserver-utils
    network-manager bluez systemd dbus
    pipewire pipewire-pulse wireplumber
    kitty pcmanfm sudo
)

_stash_is_protected() {
    local pkg="$1"
    for p in "${STASH_PROTECTED[@]}"; do
        [[ "$pkg" == "$p" ]] && return 0
    done
    return 1
}

# ── Curated categories ───────────────────────────────────────
declare -A STASH_CATEGORIES=(
    ["internet"]="zen-browser librewolf brave-browser chromium firefox-esr thunderbird"
    ["office"]="onlyoffice-desktopeditors libreoffice gimp inkscape"
    ["ide"]="geany codium vim neovim emacs bluefish kate"
    ["media"]="vlc mpv audacity obs-studio kdenlive"
    ["gaming"]="steam lutris heroic-games-launcher gamemode mangohud"
    ["games"]="supertuxkart 0ad gnome-games"
    ["ai"]="ollama"
    ["security"]="keepassxc pass gnupg age tor torsocks macchanger"
    ["development"]="git build-essential python3 nodejs rustc golang"
    ["system"]="htop btop ncdu rsync tmux zsh fish"
    ["network"]="nmap wireshark tcpdump curl wget aria2 rsync"
    ["multimedia"]="ffmpeg imagemagick yt-dlp flameshot scrot"
)

# ── Spinner (Braille) ────────────────────────────────────────
_STASH_SPINNER_FRAMES=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
_STASH_SPINNER_PID=""

_stash_spinner_start() {
    local msg="$1"
    (
        local i=0
        while true; do
            printf "\r  ${PURPLE}%s${RESET}  %s" "${_STASH_SPINNER_FRAMES[$i]}" "$msg"
            i=$(( (i + 1) % ${#_STASH_SPINNER_FRAMES[@]} ))
            sleep 0.1
        done
    ) &
    _STASH_SPINNER_PID=$!
}

_stash_spinner_stop() {
    if [[ -n "$_STASH_SPINNER_PID" ]]; then
        kill "$_STASH_SPINNER_PID" 2>/dev/null
        wait "$_STASH_SPINNER_PID" 2>/dev/null
        printf "\r\033[K"
        _STASH_SPINNER_PID=""
    fi
}

# ── Size preview via apt simulation / cache ──────────────────
_stash_preview_size() {
    local pkg="$1"
    local size_bytes
    
    # Try apt-cache first
    size_bytes=$(apt-cache show "$pkg" 2>/dev/null | grep -m1 '^Size:' | awk '{print $2}')
    
    # Fallback: parse from apt-get simulation if size is missing
    if [[ -z "$size_bytes" || "$size_bytes" -eq 0 ]]; then
        size_bytes=$(apt-get install --simulate "$pkg" 2>/dev/null | grep -i "need to get" | grep -oE '[0-9.,]+ [kMG]?B' | head -1)
        echo "${size_bytes:-unknown}"
        return
    fi

    local size_str="unknown"
    if [[ -n "$size_bytes" && "$size_bytes" -gt 0 ]]; then
        if   [[ "$size_bytes" -ge 1073741824 ]]; then
            size_str=$(awk "BEGIN {printf \"%.1f GB\", $size_bytes/1073741824}")
        elif [[ "$size_bytes" -ge 1048576 ]]; then
            size_str=$(awk "BEGIN {printf \"%.1f MB\", $size_bytes/1048576}")
        elif [[ "$size_bytes" -ge 1024 ]]; then
            size_str=$(awk "BEGIN {printf \"%.0f KB\", $size_bytes/1024}")
        else
            size_str="${size_bytes} B"
        fi
    fi

    echo "$size_str"
}

# ============================================================
# snowfox stash — Main dispatcher
# ============================================================
cmd_stash() {
    if [[ -z "$1" ]]; then
        _stash_categories
        return
    fi

    if [[ -n "${STASH_CATEGORIES[$1]}" ]]; then
        _stash_show_category "$1"
        return
    fi

    case "$1" in
        find)
            shift
            _stash_find "$*"
            ;;
        info)
            _stash_info "$2"
            ;;
        install)
            _stash_install "$2"
            ;;
        list)
            _stash_installed_list
            ;;
        remove)
            _stash_remove "$2"
            ;;
        *)
            header "snowfox stash"
            info "  snowfox stash              — show curated categories"
            info "  snowfox stash <category>   — list packages in a category"
            info "  snowfox stash find <query> — search apt repositories"
            info "  snowfox stash info <pkg>   — show package details"
            info "  snowfox stash install <pkg>— install a package"
            info "  snowfox stash list         — list installed apps"
            info "  snowfox stash remove <pkg> — remove a package"
            echo ""
            divider
            info "Categories: internet, office, ide, media, gaming, games,"
            info "            ai, security, development, system, network, multimedia"
            echo ""
            ;;
    esac
}

# ============================================================
# Category overview
# ============================================================
_stash_categories() {
    header "stash — Categories"

    for cat in internet office ide media gaming games ai security development system network multimedia; do
        local count
        count=$(echo "${STASH_CATEGORIES[$cat]}" | wc -w)
        printf "  ${CYAN}%-14s${RESET} ${DGRAY}%2d packages${RESET}\n" "$cat" "$count"
    done

    divider
    info "Show category: snowfox stash <category>"
    info "Search all:    snowfox stash find <query>"
    echo ""
}

# ============================================================
# List packages in a category
# ============================================================
_stash_show_category() {
    local cat="$1"

    header "stash — $cat"

    local pkgs="${STASH_CATEGORIES[$cat]}"
    for pkg in $pkgs; do
        local status status_color
        if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
            status="installed"
            status_color="$GREEN"
        elif apt-cache show "$pkg" &>/dev/null; then
            status="available"
            status_color="$CYAN"
        else
            status="unavailable"
            status_color="$RED"
        fi
        printf "  ${status_color}%-32s${RESET} ${DGRAY}%s${RESET}\n" "$pkg" "$status"
    done

    divider
    info "Install: snowfox stash install <package>"
    echo ""
}

# ============================================================
# Search apt repositories
# ============================================================
_stash_find() {
    local query="$1"

    if [[ -z "$query" ]]; then
        err "Usage: snowfox stash find <query>"
        exit 1
    fi

    header "stash — Search: $query"

    local results
    results=$(apt-cache search "$query" 2>/dev/null | head -30)

    if [[ -z "$results" ]]; then
        info "No results for '$query'."
        exit 0
    fi

    while IFS= read -r line; do
        local pkg desc
        pkg=$(echo "$line" | cut -d' ' -f1)
        desc=$(echo "$line" | cut -d' ' -f2- | cut -c1-60)

        local color="$CYAN"
        dpkg -l "$pkg" 2>/dev/null | grep -q "^ii" && color="$GREEN"

        printf "  ${color}%-28s${RESET} ${DGRAY}%s${RESET}\n" "$pkg" "$desc"
    done <<< "$results"

    divider
    info "Install: snowfox stash install <package>"
    echo ""
}

# ============================================================
# Package info
# ============================================================
_stash_info() {
    local pkg="$1"

    if [[ -z "$pkg" ]]; then
        err "Usage: snowfox stash info <package>"
        exit 1
    fi

    if ! apt-cache show "$pkg" &>/dev/null; then
        err "Package '$pkg' not found."
        exit 1
    fi

    header "stash — $pkg"

    local version size desc homepage
    version=$(apt-cache show "$pkg" 2>/dev/null | grep -m1 "^Version:" | awk '{print $2}')
    size=$(apt-cache show "$pkg" 2>/dev/null | grep -m1 "^Size:" | awk '{print $2}')
    desc=$(apt-cache show "$pkg" 2>/dev/null | grep -m1 "^Description-en:" | cut -d: -f2- | xargs)
    homepage=$(apt-cache show "$pkg" 2>/dev/null | grep -m1 "^Homepage:" | awk '{print $2}')

    row "Version" "${version:-unknown}"
    if [[ -n "$size" ]]; then
        local size_mb
        size_mb=$(awk "BEGIN {printf \"%.1f\", $size/1024/1024}")
        row "Size" "${size_mb} MB"
    fi
    [[ -n "$homepage" ]] && row "Homepage" "$homepage"
    echo ""
    [[ -n "$desc" ]] && info "$desc"

    divider
    info "Install: snowfox stash install $pkg"
    echo ""
}

# ============================================================
# Install a package
# ============================================================
_stash_install() {
    local pkg="$1"

    if [[ -z "$pkg" ]]; then
        err "Usage: snowfox stash install <package>"
        exit 1
    fi

    if ! apt-cache show "$pkg" &>/dev/null; then
        err "Package '$pkg' not found."
        info "  Search: snowfox stash find <query>"
        exit 1
    fi

    if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
        info "Package '$pkg' is already installed."
        exit 0
    fi

    header "stash — Install: $pkg"

    info "Analyzing package..."
    local download_size
    download_size=$(_stash_preview_size "$pkg")

    echo ""
    if [[ "$download_size" != "unknown" ]]; then
        row "Download size" "$download_size"
    else
        row "Download size" "unknown" "$ORANGE"
    fi
    echo ""

    read -rp "$(echo -e ${PURPLE}${BOLD}"Install? [y/N]: "${RESET})" CONFIRM
    if [[ ! "$CONFIRM" =~ ^[yY]$ ]]; then
        info "Cancelled."
        exit 0
    fi

    echo ""
    _stash_spinner_start "Installing $pkg..."
    sudo apt-get install -y "$pkg" > /tmp/stash-install.log 2>&1
    local EXIT=$?
    _stash_spinner_stop

    if [[ $EXIT -eq 0 ]]; then
        ok "$pkg installed."
    else
        err "Installation failed."
        info "  Log: /tmp/stash-install.log"
        exit 1
    fi
}

# ============================================================
# List installed apps
# ============================================================
_stash_installed_list() {
    header "stash — Installed Apps"

    local dirs=("/usr/share/applications" "$HOME/.local/share/applications")
    local found=false

    printf "  ${DGRAY}%-32s %s${RESET}\n" "App" "Package"
    divider

    for dir in "${dirs[@]}"; do
        [[ -d "$dir" ]] || continue
        for file in "$dir"/*.desktop; do
            [[ -e "$file" ]] || continue
            grep -q "^NoDisplay=true" "$file" 2>/dev/null && continue

            local app_name pkg
            app_name=$(grep -m1 "^Name=" "$file" | cut -d= -f2-)
            [[ -z "$app_name" ]] && app_name=$(basename "$file" .desktop)

            pkg=$(dpkg -S "applications/$(basename "$file")" 2>/dev/null | cut -d: -f1 | head -1)
            [[ -z "$pkg" ]] && pkg="(manual)"

            if [[ "$pkg" == "(manual)" ]]; then
                printf "  ${CYAN}%-32s${RESET} ${GRAY}%s${RESET}\n" "$app_name" "$pkg"
            elif _stash_is_protected "$pkg"; then
                printf "  ${CYAN}%-32s${RESET} ${ORANGE}%s [protected]${RESET}\n" "$app_name" "$pkg"
            else
                printf "  ${CYAN}%-32s${RESET} ${DGRAY}%s${RESET}\n" "$app_name" "$pkg"
            fi
            found=true
        done
    done

    $found || info "No applications found."
    divider
    info "Remove: snowfox stash remove <package>"
    echo ""
}

# ============================================================
# Remove a package
# ============================================================
_stash_remove() {
    local pkg="$1"

    if [[ -z "$pkg" ]]; then
        err "Usage: snowfox stash remove <package>"
        info "  List installed: snowfox stash list"
        exit 1
    fi

    if ! dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
        err "Package '$pkg' is not installed."
        exit 1
    fi

    if _stash_is_protected "$pkg"; then
        err "'$pkg' is a system component and cannot be removed."
        warn "Removing it would break SnowFoxOS."
        exit 1
    fi

    header "stash — Remove: $pkg"

    local size
    size=$(dpkg-query -W --showformat='${Installed-Size}' "$pkg" 2>/dev/null)
    if [[ -n "$size" ]]; then
        local size_mb
        size_mb=$(awk "BEGIN {printf \"%.1f\", $size/1024}")
        row "Installed size" "${size_mb} MB"
    fi
    echo ""

    read -rp "$(echo -e ${ORANGE}${BOLD}"Remove $pkg? [y/N]: "${RESET})" CONFIRM
    if [[ ! "$CONFIRM" =~ ^[yY]$ ]]; then
        info "Cancelled."
        exit 0
    fi

    echo ""
    _stash_spinner_start "Removing $pkg..."
    sudo apt-get purge -y "$pkg" > /tmp/stash-remove.log 2>&1
    local EXIT=$?
    sudo apt-get autoremove -y >> /tmp/stash-remove.log 2>&1
    _stash_spinner_stop

    if [[ $EXIT -eq 0 ]]; then
        ok "$pkg removed."
    else
        err "Removal failed."
        info "  Log: /tmp/stash-remove.log"
        exit 1
    fi
}
