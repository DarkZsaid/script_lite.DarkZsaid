#!/usr/bin/env bash

RESET="\033[0m"
BLANCO="\033[1;37m"
CYAN="\033[1;36m"
DORADO="\033[1;33m"
VERDE="\033[1;32m"
ROJO="\033[1;31m"
GRIS="\033[0;37m"

BASE="/opt/darkzsaid"
MENUS="$BASE/menus"

pausa() {
    echo
    read -rp "Presiona ENTER para continuar..."
}

ejecutar() {
    local archivo="$1"
    if [ -x "$archivo" ]; then
        bash "$archivo"
    elif [ -f "$archivo" ]; then
        bash "$archivo"
    else
        echo -e "${ROJO}No existe:${RESET} $archivo"
        pausa
    fi
}

while true; do
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}       ${BLANCO}DARKZSAID LITE PREMIUM${RESET}           ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}          ${DORADO}GESTIÓN SSH${RESET}                   ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${RESET}"
    echo
    echo -e "${CYAN}MENÚ USUARIOS SSH${RESET} ${GRIS}────────────────────${RESET}"
    echo
    echo -e "${DORADO}[01]${RESET} ${BLANCO}Crear usuario SSH${RESET}"
    echo -e "${DORADO}[02]${RESET} ${BLANCO}Eliminar usuario SSH${RESET}"
    echo -e "${DORADO}[03]${RESET} ${BLANCO}Mostrar usuarios registrados${RESET}"
    echo -e "${DORADO}[04]${RESET} ${BLANCO}Ver usuarios conectados${RESET}"
    echo -e "${DORADO}[05]${RESET} ${BLANCO}Ver consumo / log${RESET}"
    echo -e "${DORADO}[00]${RESET} ${ROJO}Volver${RESET}"
    echo
    echo -ne "${CYAN}➤${RESET} ${BLANCO}Seleccione una opción:${RESET} ${DORADO}"
    read -r opc
    echo -ne "${RESET}"

    case "$opc" in
        1|01) ejecutar "$MENUS/usuarios_agregar.sh" ;;
        2|02) ejecutar "$MENUS/usuarios_borrar.sh" ;;
        3|03) ejecutar "$MENUS/usuarios_mostrar.sh" ;;
        4|04)
            if [ -f "$MENUS/usuarios_conectados.sh" ]; then
                ejecutar "$MENUS/usuarios_conectados.sh"
            else
                ejecutar "$MENUS/ver_conectados_ssh.sh"
            fi
            ;;
        5|05) ejecutar "$MENUS/log_consumo.sh" ;;
        0|00) exit 0 ;;
        *)
            echo -e "${ROJO}Opción inválida.${RESET}"
            sleep 1
            ;;
    esac
done
