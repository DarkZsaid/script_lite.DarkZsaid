#!/usr/bin/env bash

RESET="\033[0m"
BLANCO="\033[1;37m"
NEGRO="\033[0;30m"
ROJO="\033[1;31m"
VERDE="\033[1;32m"
AMARILLO="\033[1;33m"
AZUL="\033[1;34m"
MORADO="\033[1;35m"
CYAN="\033[1;36m"
GRIS="\033[0;37m"
DORADO="\033[1;33m"
NARANJA="\033[38;5;208m"

RED="$ROJO"
GREEN="$VERDE"
YELLOW="$AMARILLO"
BLUE="$AZUL"
MAGENTA="$MORADO"
WHITE="$BLANCO"

print_center() {
    local texto="$1"
    echo -e "$texto"
}

linea() {
    echo -e "${CYAN}────────────────────────────────────────────${RESET}"
}
