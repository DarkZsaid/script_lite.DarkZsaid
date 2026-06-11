#!/usr/bin/env bash

RESET="\033[0m"
BLANCO="\033[1;37m"
CYAN="\033[1;36m"
DORADO="\033[1;33m"
ROJO="\033[1;31m"

clear
echo -e "${CYAN}╔════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${RESET}       ${BLANCO}DARKZSAID LITE PREMIUM${RESET}           ${CYAN}║${RESET}"
echo -e "${CYAN}║${RESET}          ${DORADO}CREAR USUARIO SSH${RESET}             ${CYAN}║${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${RESET}"
echo

if [ -x /opt/darkzsaid/menus/usuarios_agregar.sh ]; then
    bash /opt/darkzsaid/menus/usuarios_agregar.sh
else
    echo -e "${ROJO}No existe /opt/darkzsaid/menus/usuarios_agregar.sh${RESET}"
    read -rp "Presiona ENTER para continuar..."
fi
