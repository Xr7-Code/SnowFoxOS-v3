#!/bin/bash
# ============================================================
#  SnowFoxOS — CLI Module: Media (Download & Stream)
#  Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)
# ============================================================

COOKIE_FILE="$HOME/.config/snowfox/cookies.txt"
DOWNLOAD_DIR="$HOME/Downloads"

# ============================================================
# snowfox fetch — High-speed download via aria2
# ============================================================
cmd_fetch() {
    if ! command -v aria2c &>/dev/null; then
        err "aria2c not found. Install: sudo apt install aria2"
        exit 1
    fi

    if [[ -z "$1" ]]; then
        err "Usage: snowfox fetch <URL>"
        exit 1
    fi

    local URL="$1"
    local OUTDIR="${2:-$DOWNLOAD_DIR}"
    mkdir -p "$OUTDIR"

    header "Fetch"
    row "URL" "$URL"
    row "Destination" "$OUTDIR"
    row "Connections" "16 parallel"
    echo ""

    info "Starting download..."
    echo ""

    aria2c \
        --max-connection-per-server=16 \
        --split=16 \
        --min-split-size=1M \
        --file-allocation=none \
        --continue=true \
        --summary-interval=1 \
        --console-log-level=warn \
        --dir="$OUTDIR" \
        "$URL"

    if [[ $? -eq 0 ]]; then
        echo ""
        ok "Download complete: $OUTDIR"
    else
        echo ""
        err "Download failed."
        exit 1
    fi
}

# ============================================================
# snowfox dl — Download video/audio via yt-dlp
# ============================================================
cmd_download() {
    if ! command -v yt-dlp &>/dev/null; then
        err "yt-dlp not found. Install: sudo apt install yt-dlp"
        exit 1
    fi

    if [[ -z "$1" ]]; then
        err "Usage: snowfox dl <URL>"
        exit 1
    fi

    local URL="$1"
    mkdir -p "$(dirname "$COOKIE_FILE")"

    # Refresh cookies if older than 1 day
    if [[ ! -f "$COOKIE_FILE" ]] || [[ $(find "$COOKIE_FILE" -mtime +1 2>/dev/null) ]]; then
        if command -v firefox &>/dev/null; then
            yt-dlp --cookies-from-browser firefox --cookies "$COOKIE_FILE" 2>/dev/null || true
        fi
    fi

    local COOKIE_OPT=()
    if [[ -f "$COOKIE_FILE" && -s "$COOKIE_FILE" ]]; then
        COOKIE_OPT=(--cookies "$COOKIE_FILE")
    fi

    header "Download"
    row "URL" "$URL"
    echo ""

    echo -e "  ${CYAN}1${RESET}) Video (best quality)"
    echo -e "  ${CYAN}2${RESET}) Audio only (mp3)"
    echo -e "  ${CYAN}3${RESET}) Audio only (opus, smaller)"
    echo ""
    read -rp "$(echo -e ${PURPLE}${BOLD}"Format [1-3]: "${RESET})" FORMAT

    mkdir -p "$DOWNLOAD_DIR"

    local BASE_OPTS=(
        --force-ipv4
        --user-agent "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        "${COOKIE_OPT[@]}"
    )

    echo ""

    case "$FORMAT" in
        1)
            yt-dlp "${BASE_OPTS[@]}" \
                -f "bestvideo+bestaudio" \
                --merge-output-format mkv \
                -o "$DOWNLOAD_DIR/%(title)s.%(ext)s" \
                "$URL"
            ;;
        2)
            yt-dlp "${BASE_OPTS[@]}" \
                -x \
                --audio-format mp3 \
                --audio-quality 2 \
                --embed-thumbnail \
                --add-metadata \
                -o "$DOWNLOAD_DIR/%(title)s.%(ext)s" \
                "$URL"
            ;;
        3)
            yt-dlp "${BASE_OPTS[@]}" \
                -x \
                --audio-format opus \
                --embed-thumbnail \
                --add-metadata \
                -o "$DOWNLOAD_DIR/%(title)s.%(ext)s" \
                "$URL"
            ;;
        *)
            err "Invalid selection."
            exit 1
            ;;
    esac

    if [[ $? -eq 0 ]]; then
        echo ""
        ok "Saved to: $DOWNLOAD_DIR"
    else
        echo ""
        err "Download failed. Try: yt-dlp --update"
        exit 1
    fi
}

# ============================================================
# snowfox stream — Stream video/audio via mpv
# ============================================================
cmd_stream() {
    if ! command -v mpv &>/dev/null; then
        err "mpv not found. Install: sudo apt install mpv"
        exit 1
    fi

    if ! command -v yt-dlp &>/dev/null; then
        err "yt-dlp not found. Install: sudo apt install yt-dlp"
        exit 1
    fi

    local AUDIO_ONLY=false
    if [[ "$1" == "-a" || "$1" == "--audio" ]]; then
        AUDIO_ONLY=true
        shift
    fi

    local QUERY="$*"
    if [[ -z "$QUERY" ]]; then
        read -rp "$(echo -e ${PURPLE}${BOLD}"Search (video/music): "${RESET})" QUERY
        [[ -z "$QUERY" ]] && exit 0
    fi

    local URL
    if [[ "$QUERY" =~ ^http ]]; then
        URL="$QUERY"
    else
        header "Stream"
        fox "Searching YouTube: ${BOLD}$QUERY${RESET}"

        local -a RESULTS
        mapfile -t RESULTS < <(yt-dlp --force-ipv4 \
            --print "%(title)s|%(id)s" \
            --flat-playlist "ytsearch5:$QUERY" 2>/dev/null)

        if [[ ${#RESULTS[@]} -eq 0 ]]; then
            err "No results found."
            exit 1
        fi

        divider
        for i in "${!RESULTS[@]}"; do
            local title="${RESULTS[$i]%|*}"
            echo -e "  ${CYAN}$((i+1))${RESET}) $title"
        done
        divider
        echo ""

        read -rp "$(echo -e ${PURPLE}${BOLD}"Select [1-${#RESULTS[@]}]: "${RESET})" CHOICE
        [[ -z "$CHOICE" || ! "$CHOICE" =~ ^[0-9]+$ ]] && exit 0
        [[ "$CHOICE" -lt 1 || "$CHOICE" -gt "${#RESULTS[@]}" ]] && exit 0

        local ID="${RESULTS[$((CHOICE-1))]##*|}"
        if [[ ! "$ID" =~ ^[A-Za-z0-9_-]{11}$ ]]; then
            local TITLE="${RESULTS[$((CHOICE-1))]%|*}"
            URL="ytsearch1:$TITLE"
        else
            URL="https://www.youtube.com/watch?v=$ID"
        fi
    fi

    local EXTRA_OPTS=""
    if $AUDIO_ONLY; then
        info "Audio-only mode active."
        EXTRA_OPTS="--no-video"
    elif [[ -z "$DISPLAY" ]]; then
        info "No graphical session detected — starting in audio-only mode."
        EXTRA_OPTS="--no-video"
    fi

    echo ""
    echo -e "${PURPLE}${BOLD}  mpv controls:${RESET}"
    echo -e "    ${CYAN}Space${RESET}       —  Pause / Play"
    echo -e "    ${CYAN}9 / 0${RESET}       —  Volume down / up"
    echo -e "    ${CYAN}m${RESET}           —  Mute"
    echo -e "    ${CYAN}← / →${RESET}       —  10 seconds back / forward"
    echo -e "    ${CYAN}q${RESET}           —  Quit"
    echo ""

    fox "Starting stream..."
    mpv \
        --ytdl-raw-options="force-ipv4=,no-check-certificate=" \
        --ytdl-format="bestvideo[vcodec^=vp9][height<=1080]+bestaudio/bestvideo[vcodec^=avc1][height<=1080]+bestaudio/best[height<=1080]" \
        --script-opts=ytdl_hook-ytdl_path=yt-dlp \
        --cache=yes \
        --demuxer-max-bytes=150MiB \
        --demuxer-max-back-bytes=75MiB \
        $EXTRA_OPTS \
        "$URL"
}
