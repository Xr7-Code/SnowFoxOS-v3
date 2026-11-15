#!/bin/bash
# ============================================================
#  SnowFoxOS — CLI Utilities (Colors & Output Helpers)
#  Copyright (c) 2026 Alexander Valentin Ludwig (Xr7-Code)
# ============================================================

# ── Colors ───────────────────────────────────────────────────
PURPLE='\033[0;35m'
LPURPLE='\033[1;35m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
DGRAY='\033[2;37m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ── Output Helpers ───────────────────────────────────────────
header() {
    local title="$1"
    local width=48
    local pad=$(( (width - ${#title} - 2) / 2 ))
    local line
    line=$(printf '─%.0s' $(seq 1 $width))
    echo -e ""
    echo -e "${PURPLE}${BOLD}  ┌${line}┐${RESET}"
    echo -e "${PURPLE}${BOLD}  │$(printf '%*s' $((width)) '')│${RESET}"
    printf "${PURPLE}${BOLD}  │%*s${LPURPLE}🦊 %s${PURPLE}%*s│${RESET}\n" \
        $pad "" "$title" $pad ""
    echo -e "${PURPLE}${BOLD}  │$(printf '%*s' $((width)) '')│${RESET}"
    echo -e "${PURPLE}${BOLD}  └${line}┘${RESET}"
    echo ""
}

divider() {
    echo -e "${PURPLE}${DIM}  ────────────────────────────────────────────────${RESET}"
}

section() {
    echo ""
    echo -e "${LPURPLE}${BOLD}  $1${RESET}"
    divider
}

row() {
    # row "Label" "Value" [color]
    local label="$1"
    local value="$2"
    local color="${3:-$RESET}"
    printf "  ${DGRAY}%-16s${RESET} ${color}${BOLD}%s${RESET}\n" "$label" "$value"
}

bool_row() {
    # bool_row "Label" true|false [true_label] [false_label]
    local label="$1"
    local state="$2"
    local true_label="${3:-active}"
    local false_label="${4:-inactive}"
    if [[ "$state" == "true" ]]; then
        row "$label" "$true_label" "$GREEN"
    else
        row "$label" "$false_label" "$RED"
    fi
}

hint() {
    # Subtle hint below a row
    echo -e "  ${DGRAY}  $1${RESET}"
}

ok()   { echo -e "  ${GREEN}${BOLD}✓${RESET}  $1"; }
warn() { echo -e "  ${ORANGE}${BOLD}⚠${RESET}  $1"; }
err()  { echo -e "  ${RED}${BOLD}✗${RESET}  $1"; }
info() { echo -e "  ${DGRAY}$1${RESET}"; }
fox()  { echo -e "\n  ${LPURPLE}${BOLD}🦊  $1${RESET}\n"; }

# Progress bar: bar 75 100
bar() {
    local val=$1 max=$2 width=20
    local filled=$(( val * width / max ))
    local empty=$(( width - filled ))
    local b="${PURPLE}${BOLD}"
    local d="${DGRAY}"
    printf "  ["
    printf "${b}%0.s█${RESET}" $(seq 1 $filled)
    printf "${d}%0.s░${RESET}" $(seq 1 $empty)
    printf "] ${BOLD}%s%%${RESET}\n" "$val"
}
