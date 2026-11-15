#!/usr/bin/env bash
# ============================================================
#  SnowFoxOS v4 — CLI: stash (package manager)
#  (v3 logic, v4 design, browser category added per §3b)
# ============================================================

if [[ -n "${_SNOWFOX_CLI_STASH_LOADED:-}" ]]; then return 0 2>/dev/null || true; fi
_SNOWFOX_CLI_STASH_LOADED=1

cmd_stash() {
    local sub="${1:-}"; shift || true
    case "$sub" in
        "")        _stash_categories ;;
        list)      _stash_list_installed ;;
        find)      _stash_find "${1:-}" ;;
        info)      _stash_info "${1:-}" ;;
        install)   _stash_install "${1:-}" ;;
        remove)    _stash_remove "${1:-}" ;;
        browser)   _stash_browser ;;
        *)         _stash_category "$sub" ;;
    esac
}

_stash_categories() {
    header "snowfox stash"
    row "browser"  "Firefox ESR, Chromium, LibreWolf, Zen, Brave, qutebrowser"
    row "media"    "mpv, vlc, gimp, obs-studio, yt-dlp"
    row "office"   "libreoffice, onlyoffice-desktopeditors"
    row "dev"      "vscodium, geany, git"
    row "privacy"  "tor, torsocks, librewolf"
    row "games"    "steam, gamemode, mangohud"
    info "snowfox stash find <query>   search apt"
    info "snowfox stash install <pkg>  install a package"
}

_stash_browser() {
    header "snowfox stash browser"
    info "v4 default: Firefox ESR (§3b)"
    info "  sudo apt install firefox-esr"
    info "Alternatives:"
    info "  LibreWolf    → snowfox stash install librewolf"
    info "  Chromium     → snowfox stash install chromium"
    info "  Brave        → requires own repo (snowfox stash info brave-browser)"
    info "  Zen Browser  → manual (AppImage)"
    info "  qutebrowser  → snowfox stash install qutebrowser"
}

_stash_list_installed() {
    header "snowfox stash list"
    local list
    list=$(apt-mark showmanual 2>/dev/null)
    if [[ -z "$list" ]]; then
        info "no manually installed packages"
        return 0
    fi
    printf '%s\n' "$list" | while IFS= read -r p; do
        row "$p" ""
    done
}

_stash_find() {
    local query="${1:-}"
    [[ -z "$query" ]] && { err "usage: snowfox stash find <query>"; return "$SNOWFOX_EXIT_ERROR"; }
    header "snowfox stash find $query"
    apt-cache search "$query" 2>/dev/null | head -n 30 | while IFS=' - ' read -r pkg desc; do
        row "$pkg" "$desc"
    done
}

_stash_info() {
    local pkg="${1:-}"
    [[ -z "$pkg" ]] && { err "usage: snowfox stash info <package>"; return "$SNOWFOX_EXIT_ERROR"; }
    header "snowfox stash info $pkg"
    apt-cache show "$pkg" 2>/dev/null | awk '
        /^Package:/     {print "  package:  " $2}
        /^Version:/     {print "  version:  " $2}
        /^Installed-Size:/ {print "  size:     " $2 " KB"}
        /^Description:/ {found=1; print "  desc:     " substr($0,14); next}
        found && /^ /  {print "            " substr($0,2)}
    ' | head -n 20
}

_stash_install() {
    local pkg="${1:-}"
    [[ -z "$pkg" ]] && { err "usage: snowfox stash install <package>"; return "$SNOWFOX_EXIT_ERROR"; }
    header "snowfox stash install $pkg"
    if apt-get install -y "$pkg"; then
        ok "$pkg installed"
    else
        err "$pkg install failed"
        return "$SNOWFOX_EXIT_ERROR"
    fi
}

_stash_remove() {
    local pkg="${1:-}"
    [[ -z "$pkg" ]] && { err "usage: snowfox stash remove <package>"; return "$SNOWFOX_EXIT_ERROR"; }
    header "snowfox stash remove $pkg"
    if apt-get remove --purge -y "$pkg"; then
        ok "$pkg removed"
    else
        err "$pkg remove failed"
        return "$SNOWFOX_EXIT_ERROR"
    fi
}

_stash_category() {
    local cat="$1"
    header "snowfox stash $cat"
    case "$cat" in
        browser) _stash_browser ;;
        media)   apt-cache search '^(mpv|vlc|gimp|obs-studio|yt-dlp)' 2>/dev/null | while IFS=' - ' read -r p d; do row "$p" "$d"; done ;;
        office)  apt-cache search '^(libreoffice|onlyoffice)' 2>/dev/null | while IFS=' - ' read -r p d; do row "$p" "$d"; done ;;
        dev)     apt-cache search '^(vscodium|geany|git)$' 2>/dev/null | while IFS=' - ' read -r p d; do row "$p" "$d"; done ;;
        privacy) apt-cache search '^(tor|torsocks|librewolf)' 2>/dev/null | while IFS=' - ' read -r p d; do row "$p" "$d"; done ;;
        games)   apt-cache search '^(steam|gamemode|mangohud)' 2>/dev/null | while IFS=' - ' read -r p d; do row "$p" "$d"; done ;;
        *) err "unknown category: $cat"; return "$SNOWFOX_EXIT_ERROR" ;;
    esac
}
