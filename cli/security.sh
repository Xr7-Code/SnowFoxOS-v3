#!/bin/bash
# ============================================================
#  SnowFoxOS — CLI Modul: Passwort-Manager, Netzwerk-Audit, Sicherheitstipps
#  Wird von /usr/local/bin/snowfox gesourced.
# ============================================================


# ============================================================
# snowfox pass
# ============================================================
PASS_FILE="$HOME/.config/snowfox/.passwords"
PASS_DIR="$HOME/.config/snowfox"


# ============================================================
# snowfox tip
# ============================================================
TIPS=(
    "Dokumente nicht einfach wegwerfen — schreddern. Deine Adresse gehört nur dir."
    "Gib niemandem dein Passwort — auch nicht Arbeitskollegen oder dem IT-Support."
    "Social Engineering ist die häufigste Angriffsmethode. Vertraue, aber verifiziere."
    "Zerreiss Pakete und Briefe bevor du sie entsorgst — dein Wohnort ist privat."
    "Brauchst du diese App wirklich? Jede App ist eine potenzielle Tür nach innen."
    "Öffentliches WLAN ist unsicher. Nutze es nie für sensible Dinge."
    "Ein starkes Passwort ist lang, nicht kompliziert. 'korrektes-pferd-batterie' ist stärker als 'P@ssw0rd'."
    "Zwei-Faktor-Authentifizierung ist dein bester Freund. Aktiviere sie überall."
    "Dein Telefon hört zu — nicht immer, aber manchmal. Sei dir dessen bewusst."
    "Google-Dorks: Suchbefehle wie 'site:' oder 'filetype:' können sensible Daten finden. Schütze deine."
    "Lösche Metadaten aus Fotos bevor du sie teilst — sie können deinen genauen Standort verraten."
    "Backups sind keine Option — sie sind Pflicht. 3-2-1: 3 Kopien, 2 Medien, 1 extern."
    "Dein Passwort-Manager kennt alle deine Passwörter. Wähle ihn offline und lokal."
    "Eine Webcam-Abdeckung kostet einen Euro und gibt dir ein ruhiges Gewissen."
    "Phishing-Mails sehen echt aus. Prüfe immer die tatsächliche Absender-Domain."
    "Du bist nicht paranoid — du bist realistisch. Deine Daten haben einen Wert."
    "Firmware-Updates sind genauso wichtig wie Software-Updates. Router, Drucker, alles."
    "Dein Browser-Verlauf ist ein Tagebuch. Behandle ihn entsprechend."
    "Kostenlose Apps bezahlen sich durch deine Daten. Es gibt keine echte Gratis-Software."
    "Ein Faraday-Beutel blockiert alle Signale von deinem Gerät. Nützlich wenn du es wirklich brauchst."
)



cmd_pass() {
    mkdir -p "$PASS_DIR"
    chmod 700 "$PASS_DIR"

    if ! command -v gpg &>/dev/null; then
        err "gpg nicht gefunden. Installieren: sudo apt install gnupg"
        exit 1
    fi

    case "$1" in
        add)
            if [[ -z "$2" ]]; then
                err "Verwendung: snowfox pass add <name>"
                exit 1
            fi
            read -rsp "$(echo -e ${PURPLE}${BOLD}"Passwort für '$2': "${RESET})" PASS
            echo ""
            ENCRYPTED=$(echo "$PASS" | gpg --symmetric --armor -q 2>/dev/null)
            if [[ -z "$ENCRYPTED" ]]; then
                err "Verschlüsselung fehlgeschlagen."
                exit 1
            fi
            echo "$2:$ENCRYPTED" >> "$PASS_FILE"
            chmod 600 "$PASS_FILE"
            ok "Passwort für '$2' gespeichert."
            ;;
        get)
            if [[ -z "$2" ]]; then
                err "Verwendung: snowfox pass get <name>"
                exit 1
            fi
            if [[ ! -f "$PASS_FILE" ]]; then
                err "Keine Passwörter gespeichert."
                exit 1
            fi
            ENTRY=$(grep "^$2:" "$PASS_FILE" | cut -d: -f2-)
            if [[ -z "$ENTRY" ]]; then
                err "Kein Eintrag für '$2' gefunden."
                exit 1
            fi
            DECRYPTED=$(echo "$ENTRY" | gpg --decrypt -q 2>/dev/null)
            echo -n "$DECRYPTED" | xclip -selection clipboard 2>/dev/null || \
                echo -n "$DECRYPTED" | xsel --clipboard --input 2>/dev/null
            ok "Passwort für '$2' in die Zwischenablage kopiert."
            ;;
        list)
            if [[ ! -f "$PASS_FILE" ]]; then
                warn "Keine Passwörter gespeichert."
                exit 0
            fi
            fox "Gespeicherte Einträge:"
            grep -oP '^[^:]+' "$PASS_FILE"
            ;;
        remove)
            if [[ -z "$2" ]]; then
                err "Verwendung: snowfox pass remove <name>"
                exit 1
            fi
            sed -i "/^$2:/d" "$PASS_FILE"
            ok "Eintrag '$2' entfernt."
            ;;
        *)
            echo -e "Verwendung:"
            echo -e "  ${CYAN}snowfox pass add <name>${RESET}     — Passwort speichern"
            echo -e "  ${CYAN}snowfox pass get <name>${RESET}     — Passwort in Clipboard kopieren"
            echo -e "  ${CYAN}snowfox pass list${RESET}           — alle Einträge anzeigen"
            echo -e "  ${CYAN}snowfox pass remove <name>${RESET}  — Eintrag löschen"
            ;;
    esac
}


# ============================================================
# snowfox audit
# ============================================================
cmd_audit() {
    fox "Aktive Netzwerkverbindungen:"
    divider
    echo -e "${BOLD}  Prozess              Proto  Ziel-IP${RESET}"
    echo ""

    if command -v ss &>/dev/null; then
        ss -tunp 2>/dev/null | tail -n +2 | while read -r line; do
            PROTO=$(echo "$line" | awk '{print $1}')
            REMOTE=$(echo "$line" | awk '{print $6}')
            PROC=$(echo "$line" | grep -oP 'users:\(\("\K[^"]+' || echo "unbekannt")
            [[ "$REMOTE" == "*" || "$REMOTE" == "0.0.0.0:*" || -z "$REMOTE" ]] && continue
            IP=$(echo "$REMOTE" | sed 's/:[0-9]*$//' | tr -d '[]')
            if echo "$IP" | grep -qE '^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.|127\.|::1|fe80)'; then
                IP_COLOR="${GRAY}"
            else
                IP_COLOR="${ORANGE}"
            fi
            printf "  ${CYAN}%-20s${RESET} %-6s ${IP_COLOR}%s${RESET}\n" "$PROC" "$PROTO" "$IP"
        done
    else
        err "ss nicht gefunden — bitte iproute2 installieren."
    fi

    divider
}


cmd_tip() {
    RANDOM_TIP="${TIPS[$RANDOM % ${#TIPS[@]}]}"
    divider
    echo -e "${PURPLE}${BOLD}  🦊 SnowFox Security Tip${RESET}"
    divider
    echo ""
    echo -e "  ${CYAN}${RANDOM_TIP}${RESET}"
    echo ""
    divider
}
