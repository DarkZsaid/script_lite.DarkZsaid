#!/usr/bin/env bash

RESET="\033[0m"
BLANCO="\033[1;97m"
DORADO="\033[1;38;5;220m"
NARANJA="\033[1;38;5;208m"
CYAN="\033[1;96m"
AZUL="\033[1;94m"
ROJO="\033[1;91m"
VERDE="\033[1;92m"
GRIS="\033[1;90m"

START="/opt/darkzsaid/bin/ssh_ws_puro_start.sh"
STOP="/opt/darkzsaid/bin/ssh_ws_puro_stop.sh"
STATUS="/opt/darkzsaid/bin/ssh_ws_puro_status.sh"

pausa() {
    echo
    echo -ne "${CYAN}➤${RESET} ${BLANCO}Presiona ENTER para continuar...${RESET}"
    read -r
}

limpiar() {
    clear
}

puerto_on() {
    local puerto="$1"
    ss -ltn 2>/dev/null | awk '{print $4}' | grep -Eq "(:|\\])${puerto}$"
}

estado_texto() {
    local puerto="$1"
    if puerto_on "$puerto"; then
        echo -e "${VERDE}ON${RESET}"
    else
        echo -e "${ROJO}OFF${RESET}"
    fi
}

titulo() {
    limpiar

    local ip sistema fecha hora
    ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
    [ -z "$ip" ] && ip="$(curl -s --max-time 2 ifconfig.me 2>/dev/null || echo '-')"

    sistema="$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')"
    [ -z "$sistema" ] && sistema="Linux"

    fecha="$(date +%d/%m/%Y)"
    hora="$(date +%H:%M:%S)"

    echo -e "${AZUL}╔════════════════════════════════════════════════════╗${RESET}"
    echo -e "${AZUL}║${RESET}              ${BLANCO}⚡ DARKZSAID SSH WS PREMIUM ⚡${RESET}              ${AZUL}║${RESET}"
    echo -e "${AZUL}║${RESET}                  ${DORADO}SSH  •  WS  •  SSL${RESET}                   ${AZUL}║${RESET}"
    echo -e "${AZUL}╚════════════════════════════════════════════════════╝${RESET}"
    echo
    echo -e "${CYAN} VPS INFO ${GRIS}────────────────────────────────────${RESET}"
    echo -e "${BLANCO} Sistema:${RESET} ${DORADO}$sistema${RESET}"
    echo -e "${BLANCO} IP VPS:${RESET}   ${CYAN}$ip${RESET}"
    echo -e "${BLANCO} Fecha:${RESET}    ${DORADO}$fecha${RESET}    ${BLANCO}Hora:${RESET} ${DORADO}$hora${RESET}"
    echo
    echo -e "${CYAN} MAPEO DE PUERTOS ${GRIS}────────────────────────────${RESET}"
    echo -e "${BLANCO} WS:${RESET}      ${DORADO}80${RESET} | ${DORADO}90${RESET} | ${DORADO}8080${RESET} | ${DORADO}8082${RESET} | ${DORADO}8084${RESET} | ${DORADO}8086${RESET}"
    echo -e "${CYAN} ➜${RESET} ${NARANJA}80 / 8084 / 8086${RESET} ${BLANCO}->${RESET} ${MORADO:-$CYAN}OpenSSH 22${RESET}"
    echo -e "${CYAN} ➜${RESET} ${NARANJA}90 / 8080 / 8082${RESET} ${BLANCO}->${RESET} ${MORADO:-$CYAN}OpenSSH 22${RESET}"
    echo -e "${CYAN} ➜${RESET} ${DORADO}SSL 443${RESET} ${BLANCO}->${RESET} ${NARANJA}WS 80${RESET} ${BLANCO}->${RESET} ${MORADO:-$CYAN}OpenSSH 22${RESET}"
    echo
}

estado_premium() {
    titulo

    echo -e "${BLANCO}✦ ESTADO PREMIUM DE PUERTOS ✦${RESET}"
    echo -e "${CYAN}────────────────────────────────────────────────────${RESET}"
    printf "${CYAN}%-8s %-16s %-20s %-8s${RESET}\n" "PUERTO" "SERVICIO" "DESTINO" "ESTADO"
    echo -e "${CYAN}────────────────────────────────────────────────────${RESET}"

    printf "${DORADO}%-8s${RESET} ${BLANCO}%-16s${RESET} ${NARANJA}%-20s${RESET} %b\n" "22"   "OpenSSH"     "SSH directo"        "$(estado_texto 22)"
    printf "${DORADO}%-8s${RESET} ${BLANCO}%-16s${RESET} ${NARANJA}%-20s${RESET} %b\n" "443"  "SSL/Stunnel" "443 -> WS 80"      "$(estado_texto 443)"
    printf "${DORADO}%-8s${RESET} ${BLANCO}%-16s${RESET} ${NARANJA}%-20s${RESET} %b\n" "80"   "WS SSH"      "80 -> SSH 22"      "$(estado_texto 80)"
    printf "${DORADO}%-8s${RESET} ${BLANCO}%-16s${RESET} ${NARANJA}%-20s${RESET} %b\n" "90"   "WS SSH"      "90 -> SSH 22"      "$(estado_texto 90)"
    printf "${DORADO}%-8s${RESET} ${BLANCO}%-16s${RESET} ${NARANJA}%-20s${RESET} %b\n" "8080" "WS SSH"      "8080 -> SSH 22"    "$(estado_texto 8080)"
    printf "${DORADO}%-8s${RESET} ${BLANCO}%-16s${RESET} ${NARANJA}%-20s${RESET} %b\n" "8082" "WS SSH"      "8082 -> SSH 22"    "$(estado_texto 8082)"
    printf "${DORADO}%-8s${RESET} ${BLANCO}%-16s${RESET} ${NARANJA}%-20s${RESET} %b\n" "8084" "WS SSH"      "8084 -> SSH 22"    "$(estado_texto 8084)"
    printf "${DORADO}%-8s${RESET} ${BLANCO}%-16s${RESET} ${NARANJA}%-20s${RESET} %b\n" "8086" "WS SSH"      "8086 -> SSH 22"    "$(estado_texto 8086)"

    echo -e "${CYAN}────────────────────────────────────────────────────${RESET}"
    pausa
}

while true; do
    titulo

    echo -e "${CYAN} MENÚ SSH WS ${GRIS}────────────────────────────────${RESET}"
    echo -e " ${DORADO}[01]${RESET} ${BLANCO}Encender protocolos SSH WS${RESET}"
    echo -e " ${DORADO}[02]${RESET} ${BLANCO}Apagar protocolos SSH WS${RESET}"
    echo -e " ${DORADO}[03]${RESET} ${BLANCO}Reiniciar protocolos SSH WS${RESET}"
    echo -e " ${DORADO}[04]${RESET} ${BLANCO}Ver estado premium de puertos${RESET}"
    echo -e " ${DORADO}[00]${RESET} ${ROJO}Volver al menú principal${RESET}"
    echo
    echo -ne "${CYAN}➤${RESET} ${BLANCO}Seleccione una opción:${RESET} ${DORADO} "
    read -r opc
    echo -ne "${RESET}"

    case "$opc" in
        1|01)
            titulo
            echo -e "${BLANCO}Encendiendo protocolos SSH WS...${RESET}"
            echo
            bash "$START"
            pausa
        ;;
        2|02)
            titulo
            echo -e "${BLANCO}Apagando protocolos SSH WS...${RESET}"
            echo
            bash "$STOP"
            pausa
        ;;
        3|03)
            titulo
            echo -e "${BLANCO}Reiniciando protocolos SSH WS...${RESET}"
            echo
            bash "$STOP" 2>/dev/null || true
            sleep 2
            bash "$START"
            pausa
        ;;
        4|04)
            estado_premium
        ;;
        0|00)
            exit 0
        ;;
        *)
            echo -e "${ROJO}Opción inválida.${RESET}"
            sleep 1
        ;;
    esac
done
