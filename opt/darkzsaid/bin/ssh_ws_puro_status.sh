#!/usr/bin/env bash

RESET="\033[0m"
BLANCO="\033[1;37m"
CYAN="\033[1;36m"
AZUL="\033[1;34m"
DORADO="\033[1;33m"
VERDE="\033[1;32m"
NARANJA="\033[38;5;208m"
GRIS="\033[0;37m"

estado_puerto() {
    local puerto="$1"
    if ss -ltnp 2>/dev/null | grep -q ":$puerto "; then
        echo -e "${VERDE}ON${RESET}"
    else
        echo -e "${GRIS}OFF${RESET}"
    fi
}

fila() {
    local puerto="$1"
    local servicio="$2"
    local destino="$3"
    local estado
    estado="$(estado_puerto "$puerto")"

    printf "${DORADO}%-8s${RESET} ${BLANCO}%-13s${RESET} ${NARANJA}%-21s${RESET} %b\n" \
        "$puerto" "$servicio" "$destino" "$estado"
}

clear
echo -e "${CYAN}✦ ESTADO PREMIUM DE PUERTOS ✦${RESET}"
echo -e "${CYAN}────────────────────────────────────────────${RESET}"
printf "${AZUL}%-8s %-13s %-21s %-8s${RESET}\n" "PUERTO" "SERVICIO" "DESTINO" "ESTADO"
echo -e "${CYAN}────────────────────────────────────────────${RESET}"

fila "22"   "OpenSSH"     "SSH directo"
fila "443"  "SSL/Stunnel" "443 -> WS 80"
fila "80"   "WS SSH"      "80 -> SSH 22"
fila "90"   "WS SSH"      "90 -> SSH 22"
fila "8080" "WS SSH"      "8080 -> SSH 22"
fila "8082" "WS SSH"      "8082 -> SSH 22"
fila "8084" "WS SSH"      "8084 -> SSH 22"
fila "8086" "WS SSH"      "8086 -> SSH 22"

echo -e "${CYAN}────────────────────────────────────────────${RESET}"
echo
