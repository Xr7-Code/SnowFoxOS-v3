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

    # Cookies aus Browser holen (einmal pro Tag)
    COOKIE_FILE="$HOME/.config/snowfox/cookies.txt"
    mkdir -p "$(dirname "$COOKIE_FILE")"
    if [[ ! -f "$COOKIE_FILE" || $(find "$COOKIE_FILE" -mtime +1 2>/dev/null) ]]; then
        # Versuche Cookies aus Firefox zu holen
        if command -v firefox &>/dev/null; then
            yt-dlp --cookies-from-browser firefox --cookies "$COOKIE_FILE" 2>/dev/null || true
        fi
    fi

    COOKIE_OPT=""
    if [[ -f "$COOKIE_FILE" && -s "$COOKIE_FILE" ]]; then
        COOKIE_OPT="--cookies $COOKIE_FILE"
    fi

    fox "Was möchtest du herunterladen?"
    echo -e "  ${CYAN}1${RESET}) Video (beste Qualität)"
    echo -e "  ${CYAN}2${RESET}) Nur Audio (mp3)"
    echo -e "  ${CYAN}3${RESET}) Nur Audio (opus, kleiner)"
    echo ""
    read -rp "$(echo -e ${PURPLE}${BOLD}"Auswahl [1-3]: "${RESET})" FORMAT

    OUTDIR="$HOME/Downloads"
    mkdir -p "$OUTDIR"

    # Moderne Optionen für YouTube
    BASE_OPTS="--force-ipv4 \
        --extractor-args youtube:skip=hls,dash,translated_subs \
        --user-agent 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36' \
        $COOKIE_OPT"

    case "$FORMAT" in
        1) 
            yt-dlp $BASE_OPTS -f "bestvideo+bestaudio" \
                -o "$OUTDIR/%(title)s.%(ext)s" "$1" ;;
        2) 
            yt-dlp $BASE_OPTS -f "140" \
                -o "$OUTDIR/%(title)s.%(ext)s" "$1" ;;
        3) 
            yt-dlp $BASE_OPTS -f "251" \
                -o "$OUTDIR/%(title)s.%(ext)s" "$1" ;;
        *) 
            err "Ungültige Auswahl." 
            return 1 ;;
    esac

    if [[ $? -eq 0 ]]; then
        ok "Gespeichert in: $OUTDIR"
    else
        err "Download fehlgeschlagen. Versuche: yt-dlp --update"
    fi
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

        # Ein yt-dlp-Aufruf mit Trennzeichen das nie in Titeln vorkommt
        # deutlich schneller als zwei separate Aufrufe
        mapfile -t RESULTS < <(yt-dlp --force-ipv4             --print "%(title)s	%(id)s"             --flat-playlist "ytsearch5:$QUERY" 2>/dev/null)

        if [[ ${#RESULTS[@]} -eq 0 ]]; then
            err "Keine Ergebnisse gefunden."
            return
        fi

        divider
        for i in "${!RESULTS[@]}"; do
            title="${RESULTS[$i]%	*}"
            echo -e "  ${CYAN}$((i+1))${RESET}) $title"
        done
        divider

        read -rp "$(echo -e ${PURPLE}${BOLD}"Auswahl [1-${#RESULTS[@]}]: "${RESET})" CHOICE
        [[ -z "$CHOICE" || ! "$CHOICE" =~ ^[1-9]$ ]] && return
        [[ "$CHOICE" -gt "${#RESULTS[@]}" ]] && return

        # ID nach dem Tab-Trennzeichen extrahieren und validieren
        ID="${RESULTS[$((CHOICE-1))]##*	}"
        if [[ ! "$ID" =~ ^[A-Za-z0-9_-]{11}$ ]]; then
            TITLE="${RESULTS[$((CHOICE-1))]%	*}"
            URL="ytsearch1:$TITLE"
        else
            URL="https://www.youtube.com/watch?v=$ID"
        fi
    fi

    fox "Starte Stream..."
    # --ytdl-raw-options: IPv4 erzwingen verhindert 403-Fehler bei IPv6
    # yt-dlp als ytdl-Backend explizit setzen (neuere mpv-Versionen)
    # VP9/H264 bevorzugen — AV1 (libdav1d) verursacht OBU-Decoder-Fehler
    # auf älteren libdav1d-Versionen. VP9 ist stabil und überall unterstützt.
    mpv         --ytdl-raw-options="force-ipv4=,no-check-certificate="         --ytdl-format="bestvideo[vcodec^=vp9][height<=1080]+bestaudio/bestvideo[vcodec^=avc1][height<=1080]+bestaudio/best[height<=1080]"         --script-opts=ytdl_hook-ytdl_path=yt-dlp         "$URL"
}
