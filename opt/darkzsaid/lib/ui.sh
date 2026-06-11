#!/bin/bash

ROJO="${ROJO:-\e[31m}"
VERDE="${VERDE:-\e[32m}"
AMARILLO="${AMARILLO:-\e[33m}"
AZUL="${AZUL:-\e[34m}"
CYAN="${CYAN:-\e[36m}"
BLANCO="${BLANCO:-\e[97m}"
RESET="${RESET:-\e[0m}"

limpiar_terminal() {
    stty sane 2>/dev/null || true
    tput cnorm 2>/dev/null || true
}

pausa_bonita() {
    limpiar_terminal
    echo ""
    read -r -p "Presiona ENTER para continuar..."
}

leer_opcion() {
    limpiar_terminal
    local __var="$1"
    local __prompt="${2:-⚡ Opción: }"
    local __valor=""

    echo ""
    read -r -p "$__prompt" __valor
    __valor="$(echo "$__valor" | xargs 2>/dev/null)"
    printf -v "$__var" "%s" "$__valor"
}

opcion_invalida() {
    limpiar_terminal
    echo ""
    echo -e "${ROJO}✖ Opción inválida.${RESET}"
    echo -e "${AMARILLO}Intenta nuevamente o presiona 0 para volver.${RESET}"
    sleep 1
}

ok_msg() {
    echo -e "${VERDE}✔ $1${RESET}"
}

info_msg() {
    echo -e "${CYAN}➜ $1${RESET}"
}

warn_msg() {
    echo -e "${AMARILLO}⚠ $1${RESET}"
}

error_msg() {
    echo -e "${ROJO}✖ $1${RESET}"
}

cargando() {
    local mensaje="$1"
    echo -ne "${CYAN}➜ ${mensaje}${RESET}"
    for i in 1 2 3; do
        echo -ne "${CYAN}.${RESET}"
        sleep 0.25
    done
    echo ""
}

trap limpiar_terminal EXIT INT TERM
