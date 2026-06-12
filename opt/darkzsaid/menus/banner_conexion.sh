#!/usr/bin/env bash

RESET="\033[0m"
BLANCO="\033[1;37m"
CYAN="\033[1;36m"
DORADO="\033[1;33m"
VERDE="\033[1;32m"
ROJO="\033[1;31m"
MORADO="\033[1;35m"
GRIS="\033[0;37m"

USERDIR="/etc/adm-lite/userDIR"

usuario="${PAM_USER:-${USER:-${LOGNAME:-}}}"
[ -z "$usuario" ] && usuario="$(id -un 2>/dev/null)"
[ "$usuario" = "root" ] && exit 0

file="$USERDIR/$usuario"

limite="1"
caduca="Sin fecha"
consumo="0"
estado="ACTIVO"
dias=""

if [ -f "$file" ]; then
    limite="$(grep -i '^Límite:' "$file" 2>/dev/null | head -1 | cut -d':' -f2- | xargs)"
    [ -z "$limite" ] && limite="$(grep -i '^Limite:' "$file" 2>/dev/null | head -1 | cut -d':' -f2- | xargs)"
    [ -z "$limite" ] && limite="1"

    caduca="$(grep -i '^Caduca:' "$file" 2>/dev/null | head -1 | cut -d':' -f2- | xargs)"
    [ -z "$caduca" ] && caduca="$(grep -i '^Data:' "$file" 2>/dev/null | head -1 | cut -d':' -f2- | xargs)"
    [ -z "$caduca" ] && caduca="Sin fecha"

    consumo="$(grep -i '^Consumo:' "$file" 2>/dev/null | head -1 | cut -d':' -f2- | xargs)"
    [ -z "$consumo" ] && consumo="0"
fi

if echo "$caduca" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
    hoy="$(date +%s)"
    fin="$(date -d "$caduca" +%s 2>/dev/null || echo 0)"
    if [ "$fin" -gt 0 ]; then
        dias=$(( (fin - hoy) / 86400 ))
        [ "$dias" -lt 0 ] && estado="VENCIDO"
    fi
fi

echo
echo -e "${CYAN}╔════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${RESET}       ${BLANCO}⚡ DARKZSAID LITE PREMIUM ⚡${RESET}      ${CYAN}║${RESET}"
echo -e "${CYAN}║${RESET}          ${DORADO}SSH • WS • SSL${RESET}                 ${CYAN}║${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${RESET}"
echo
echo -e "${CYAN}◇ INFORMACIÓN DE LA CUENTA ◇${RESET}"
echo -e "${CYAN}────────────────────────────────────────────${RESET}"
echo -e "${BLANCO}Usuario:${RESET}      ${DORADO}${usuario}${RESET}"
echo -e "${BLANCO}Estado:${RESET}       ${VERDE}${estado}${RESET}"
echo -e "${BLANCO}Límite:${RESET}       ${DORADO}${limite}${RESET}"
echo -e "${BLANCO}Caduca:${RESET}       ${DORADO}${caduca}${RESET}"
[ -n "$dias" ] && echo -e "${BLANCO}Días:${RESET}         ${DORADO}${dias}${RESET}"
echo -e "${BLANCO}Consumo:${RESET}      ${MORADO}${consumo}${RESET}"
echo -e "${BLANCO}Puertos:${RESET}      ${VERDE}80 90 443 8080 8082 8084 8086${RESET}"
echo -e "${CYAN}────────────────────────────────────────────${RESET}"
echo
