#!/bin/bash
# SnowFoxOS — CLI Utilities (Farben & Ausgabefunktionen)

PURPLE='\033[0;35m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
BOLD='\033[1m'
RESET='\033[0m'

fox()     { echo -e "${PURPLE}${BOLD}[🦊 SnowFox]${RESET} $1"; }
ok()      { echo -e "${GREEN}${BOLD}[  OK  ]${RESET} $1"; }
warn()    { echo -e "${ORANGE}${BOLD}[ WARN ]${RESET} $1"; }
err()     { echo -e "${RED}${BOLD}[ERROR]${RESET} $1"; }
info()    { echo -e "${CYAN}$1${RESET}"; }
divider() { echo -e "${PURPLE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"; }
