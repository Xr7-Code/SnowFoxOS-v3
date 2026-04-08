#!/bin/bash
# ============================================================
#  SnowFoxOS — Terminal Greeting
#  Wird in ~/.bashrc eingebunden
# ============================================================

PURPLE='\033[0;35m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
BOLD='\033[1m'
RESET='\033[0m'

# Nur beim ersten Terminal pro Session anzeigen
GREETING_FLAG="/tmp/.snowfox-greeted-$$"
PARENT_SESSION="/tmp/.snowfox-greeted-$(cat /proc/$PPID/sessionid 2>/dev/null || echo 0)"
[[ -f "$PARENT_SESSION" ]] && exit 0
touch "$PARENT_SESSION"

# Uhrzeit & Datum
HOUR=$(date +%H)
DATE=$(date '+%A, %d. %B %Y')

if   [[ $HOUR -ge 5  && $HOUR -lt 12 ]]; then GREETING="Guten Morgen"
elif [[ $HOUR -ge 12 && $HOUR -lt 18 ]]; then GREETING="Guten Tag"
elif [[ $HOUR -ge 18 && $HOUR -lt 22 ]]; then GREETING="Guten Abend"
else GREETING="Gute Nacht"
fi

# System Info
UPTIME=$(uptime -p | sed 's/up //')
RAM_TOTAL=$(awk '/^MemTotal:/ {print int($2/1024)}' /proc/meminfo)
RAM_FREE=$(awk '/^MemAvailable:/ {print int($2/1024)}' /proc/meminfo)
RAM_USED=$((RAM_TOTAL - RAM_FREE))
DISK_FREE=$(df -h / | awk 'NR==2 {print $4}')

# Zitate & Seitenhiebe
QUOTES=(
    "\"Your computer belongs to you. Not to Microsoft. Not to anyone else.\""
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
echo -e "${PURPLE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${PURPLE}${BOLD}  🦊 SnowFoxOS${RESET}  ${GRAY}— ${DATE}${RESET}"
echo -e "${PURPLE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo -e "  ${CYAN}${GREETING}.${RESET}"
echo ""
echo -e "  ${GRAY}Uptime:  ${BOLD}${UPTIME}${RESET}"
echo -e "  ${GRAY}RAM:     ${BOLD}${RAM_FREE}MB frei von ${RAM_TOTAL}MB${RESET}"
echo -e "  ${GRAY}Disk:    ${BOLD}${DISK_FREE} frei${RESET}"
echo ""
echo -e "  ${ORANGE}${QUOTE}${RESET}"
echo ""
echo -e "${PURPLE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "  ${GRAY}You are not a product. You are not data. You are a person.${RESET}"
echo -e "  ${GRAY}                          — Alexander Valentin Ludwig${RESET}"
echo -e "${PURPLE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
