#!/bin/bash
# ============================================================
#  SnowFoxOS — Terminal Greeting
# ============================================================

PURPLE='\033[0;35m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
BOLD='\033[1m'
RESET='\033[0m'

# Damit die Begrüßung pro Terminal-Fenster nur einmal erscheint,
# prüfen wir eine temporäre Datei, die an die Terminal-Session gebunden ist.
SESSION_ID=$(basename "$(tty)")
STATE_FILE="/tmp/snowfox_greeted_${USER}_${SESSION_ID}"
[[ -f "$STATE_FILE" ]] && exit 0
touch "$STATE_FILE"

# Uhrzeit & Datum
HOUR=$(date +%H)
DATE=$(date '+%A, %d. %B %Y')

if   [[ $HOUR -ge 5  && $HOUR -lt 12 ]]; then GREETING="Guten Morgen"
elif [[ $HOUR -ge 12 && $HOUR -lt 18 ]]; then GREETING="Guten Tag"
elif [[ $HOUR -ge 18 && $HOUR -lt 22 ]]; then GREETING="Guten Abend"
else GREETING="Gute Nacht"
fi

# System Info (Debian-kompatibel)
UPTIME=$(uptime -p | sed 's/up //')
RAM_TOTAL=$(awk '/^MemTotal:/ {print int($2/1024)}' /proc/meminfo)
RAM_AVAIL=$(awk '/^MemAvailable:/ {print int($2/1024)}' /proc/meminfo)
DISK_FREE=$(df -h / | awk 'NR==2 {print $4}')

# Zitate
QUOTES=(
    "\"Your computer belongs to you. Not to Microsoft.\""
    "\"Windows is checking for updates... SnowFox is already done.\""
    "\"No telemetry. No ads. No subscriptions. Just your machine.\""
    "\"While others collect your data, SnowFox deletes it.\""
    "\"Freedom is not a feature. It is the foundation.\""
    "\"You are not a product. You are a person.\""
    "\"Somewhere, a Windows user is waiting for a reboot.\""
    "\"The best surveillance tool is the one you willingly install.\""
    "\"Small is fast. Fast is free. Free is SnowFox.\""
    "\"You deserve a computer that works for you — not against you.\""
)
QUOTE="${QUOTES[$RANDOM % ${#QUOTES[@]}]}"

echo ""
# Kleine Animation beim Start
echo -e "${PURPLE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -ne "${PURPLE}${BOLD}  🦊 ( - . - )  SnowFoxOS${RESET}\r"
sleep 0.5
echo -ne "${PURPLE}${BOLD}  🦊 ( o . o )  SnowFoxOS${RESET}\r"
sleep 0.5
echo -e "${PURPLE}${BOLD}  🦊 ( ^ . ^ )  SnowFoxOS${RESET}  ${GRAY}— ${DATE}${RESET}"
echo -e "${PURPLE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

echo -e "  ${CYAN}${GREETING}, $USER.${RESET}"
echo ""
echo -e "  ${GRAY}Uptime:   ${BOLD}${UPTIME}${RESET}"
echo -e "  ${GRAY}RAM:      ${BOLD}${RAM_AVAIL}MB verfügbar von ${RAM_TOTAL}MB${RESET}"
echo -e "  ${GRAY}Disk:     ${BOLD}${DISK_FREE} frei${RESET}"
echo ""
echo -e "  ${ORANGE}${QUOTE}${RESET}"
echo ""
echo -e "${PURPLE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "  ${GRAY}You are not a product. You are not data. You are a person.${RESET}"
echo -e "  ${GRAY}                       — Alexander Valentin Ludwig${RESET}"
echo -e "${PURPLE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
