#!/usr/bin/env bash

RESET="\033[0m"
BLANCO="\033[1;37m"
CYAN="\033[1;36m"
DORADO="\033[1;33m"
VERDE="\033[1;32m"
GRIS="\033[0;37m"
NARANJA="\033[38;5;208m"

tcp_on() {
    local puerto="$1"
    ss -ltnp 2>/dev/null | grep -q ":$puerto "
}

estado_puerto() {
    local puerto="$1"
    if tcp_on "$puerto"; then
        echo -e "${VERDE}ON${RESET}"
    else
        echo -e "${GRIS}OFF${RESET}"
    fi
}

imprimir_fila_puerto() {
    local puerto="$1"
    local servicio="$2"
    local destino="$3"
    local estado
    estado="$(estado_puerto "$puerto")"

    printf "${DORADO}%-8s${RESET} ${BLANCO}%-13s${RESET} ${NARANJA}%-21s${RESET} %b\n" \
        "$puerto" "$servicio" "$destino" "$estado"
}

mostrar_puertas_reales() {
    echo -e "${CYAN}✦ ESTADO PREMIUM DE PUERTOS ✦${RESET}"
    echo -e "${CYAN}────────────────────────────────────────────${RESET}"
    printf "${CYAN}%-8s %-13s %-21s %-8s${RESET}\n" "PUERTO" "SERVICIO" "DESTINO" "ESTADO"
    echo -e "${CYAN}────────────────────────────────────────────${RESET}"

    imprimir_fila_puerto "22"   "OpenSSH"     "SSH directo"
    imprimir_fila_puerto "443"  "SSL/Stunnel" "443 -> WS 80"
    imprimir_fila_puerto "80"   "WS SSH"      "80 -> SSH 22"
    imprimir_fila_puerto "90"   "WS SSH"      "90 -> SSH 22"
    imprimir_fila_puerto "8080" "WS SSH"      "8080 -> SSH 22"
    imprimir_fila_puerto "8082" "WS SSH"      "8082 -> SSH 22"
    imprimir_fila_puerto "8084" "WS SSH"      "8084 -> SSH 22"
    imprimir_fila_puerto "8086" "WS SSH"      "8086 -> SSH 22"

    echo -e "${CYAN}────────────────────────────────────────────${RESET}"
}
