#!/usr/bin/env bash

RESET="\033[0m"
BLANCO="\033[1;37m"
CYAN="\033[1;36m"
DORADO="\033[1;33m"
VERDE="\033[1;32m"
ROJO="\033[1;31m"
GRIS="\033[0;37m"

USERDIR="/etc/adm-lite/userDIR"

clear
echo -e "${CYAN}◇ USUARIOS CONECTADOS SSH / WS / SSL ◇${RESET}"
echo -e "${CYAN}────────────────────────────────────────────${RESET}"
printf "${DORADO}%-18s${RESET} ${BLANCO}%-12s${RESET} ${VERDE}%-10s${RESET}\n" "USUARIO" "LÍMITE" "ESTADO"
echo -e "${CYAN}────────────────────────────────────────────${RESET}"

total=0

ps -eo args 2>/dev/null \
| grep -E "sshd: .*@|sshd: .*notty|sshd: .*pts" \
| grep -v grep \
| sed -E 's/.*sshd: ([^@ ]+).*/\1/' \
| sort -u \
| while read -r usuario; do
    [ -z "$usuario" ] && continue

    limite="1"
    if [ -f "$USERDIR/$usuario" ]; then
        limite="$(grep -i '^Límite:' "$USERDIR/$usuario" 2>/dev/null | head -1 | cut -d':' -f2- | xargs)"
        [ -z "$limite" ] && limite="1"
    fi

    printf "${BLANCO}%-18s${RESET} ${DORADO}%-12s${RESET} ${VERDE}%-10s${RESET}\n" "$usuario" "1/$limite" "ONLINE"
    total=$((total + 1))
done

echo -e "${CYAN}────────────────────────────────────────────${RESET}"
echo
echo -e "${BLANCO}Conexiones reales SSH detectadas desde OpenSSH.${RESET}"
echo
read -rp "Presiona ENTER para continuar..."
