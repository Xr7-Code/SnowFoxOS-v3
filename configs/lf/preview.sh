#!/bin/bash
FILE="$1"
W="$2"
H="$3"
X="$4"
Y="$5"

MIME=$(file -bL --mime-type "$FILE" 2>/dev/null)

case "$MIME" in
    image/*)
        kitty +kitten icat --silent --stdin no --transfer-mode file \
            --place "${W}x${H}@${X}x${Y}" "$FILE" < /dev/null > /dev/tty
        exit 1
        ;;
    video/*)
        THUMB="/tmp/lf-thumb-$(echo "$FILE" | md5sum | cut -d' ' -f1).jpg"
        ffmpegthumbnailer -i "$FILE" -o "$THUMB" -s 0 -q 5 2>/dev/null
        kitty +kitten icat --silent --stdin no --transfer-mode file \
            --place "${W}x${H}@${X}x${Y}" "$THUMB" < /dev/null > /dev/tty
        exit 1
        ;;
    application/pdf)
        THUMB="/tmp/lf-thumb-$(echo "$FILE" | md5sum | cut -d' ' -f1)"
        pdftoppm -jpeg -f 1 -l 1 "$FILE" "$THUMB" 2>/dev/null
        kitty +kitten icat --silent --stdin no --transfer-mode file \
            --place "${W}x${H}@${X}x${Y}" "${THUMB}-1.jpg" < /dev/null > /dev/tty
        exit 1
        ;;
    text/*)
        bat --color=always --style=numbers --line-range=:100 "$FILE" 2>/dev/null || cat "$FILE"
        exit 0
        ;;
    *)
        echo "$(basename "$FILE")"
        file -b "$FILE"
        exit 0
        ;;
esac
