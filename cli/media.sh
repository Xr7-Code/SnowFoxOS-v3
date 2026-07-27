#!/bin/bash
# ============================================================
#  SnowFoxOS — CLI Modul: Download & Stream
#  Wird von /usr/local/bin/snowfox gesourced.
# ============================================================


# ============================================================
# snowfox download
# ============================================================
cmd_download() {
    if ! command -v yt-dlp &>/dev/null; then
        err "yt-dlp nicht gefunden. Installieren: sudo apt install yt-dlp"
        exit 1
    fi

    if [[ -z "$1" ]]; then
        err "Verwendung: snowfox download <URL>"
        exit 1
    fi

    fox "Was möchtest du herunterladen?"
    echo -e "  ${CYAN}1${RESET}) Video (beste Qualität)"
    echo -e "  ${CYAN}2${RESET}) Nur Audio (mp3)"
    echo -e "  ${CYAN}3${RESET}) Nur Audio (opus, kleiner)"
    echo ""
    read -rp "$(echo -e ${PURPLE}${BOLD}"Auswahl [1-3]: "${RESET})" FORMAT

    OUTDIR="$HOME/Downloads"
    mkdir -p "$OUTDIR"

    case "$FORMAT" in
        1) yt-dlp --force-ipv4 -o "$OUTDIR/%(title)s.%(ext)s" "$1" ;;
        2) yt-dlp --force-ipv4 -x --audio-format mp3 -o "$OUTDIR/%(title)s.%(ext)s" "$1" ;;
        3) yt-dlp --force-ipv4 -x --audio-format opus -o "$OUTDIR/%(title)s.%(ext)s" "$1" ;;
        *) err "Ungültige Auswahl." ;;
    esac

    ok "Gespeichert in: $OUTDIR"
}


# ============================================================
# snowfox stream
# ============================================================
cmd_stream() {
    if ! command -v mpv &>/dev/null; then
        err "mpv nicht gefunden. Installieren: sudo apt install mpv"
        exit 1
    fi

    QUERY="$*"
    if [[ -z "$QUERY" ]]; then
        read -rp "$(echo -e ${PURPLE}${BOLD}"Suche (Video/Musik): "${RESET})" QUERY
        [[ -z "$QUERY" ]] && return
    fi

    if [[ "$QUERY" =~ ^http ]]; then
        URL="$QUERY"
    else
        fox "Suche auf YouTube: ${BOLD}$QUERY${RESET}..."

        # Titel und IDs separat holen — verhindert Parsing-Fehler wenn
        # Titel ein | enthalten oder yt-dlp die ID als Titel zurückgibt
        mapfile -t TITLES < <(yt-dlp --force-ipv4             --print "%(title)s" --flat-playlist "ytsearch5:$QUERY" 2>/dev/null)
        mapfile -t IDS    < <(yt-dlp --force-ipv4             --print "%(id)s"    --flat-playlist "ytsearch5:$QUERY" 2>/dev/null)

        if [[ ${#TITLES[@]} -eq 0 ]]; then
            err "Keine Ergebnisse gefunden."
            return
        fi

        divider
        for i in "${!TITLES[@]}"; do
            echo -e "  ${CYAN}$((i+1))${RESET}) ${TITLES[$i]}"
        done
        divider

        read -rp "$(echo -e ${PURPLE}${BOLD}"Auswahl [1-${#TITLES[@]}]: "${RESET})" CHOICE
        [[ -z "$CHOICE" || ! "$CHOICE" =~ ^[1-9]$ ]] && return
        [[ "$CHOICE" -gt "${#TITLES[@]}" ]] && return

        # ID validieren — muss 11 Zeichen sein (YouTube Video-ID Format)
        ID="${IDS[$((CHOICE-1))]}"
        if [[ ! "$ID" =~ ^[A-Za-z0-9_-]{11}$ ]]; then
            err "Ungültige Video-ID: $ID"
            info "Versuche direkten URL-Fallback..."
            # Fallback: yt-dlp direkt mit Suche aufrufen
            URL="ytsearch1:${TITLES[$((CHOICE-1))]}"
        else
            URL="https://www.youtube.com/watch?v=$ID"
        fi
    fi

    fox "Starte Stream..."
    # --ytdl-raw-options: IPv4 erzwingen verhindert 403-Fehler bei IPv6
    # yt-dlp als ytdl-Backend explizit setzen (neuere mpv-Versionen)
    mpv         --ytdl-raw-options="force-ipv4=,no-check-certificate="         --script-opts=ytdl_hook-ytdl_path=yt-dlp         "$URL"
}
