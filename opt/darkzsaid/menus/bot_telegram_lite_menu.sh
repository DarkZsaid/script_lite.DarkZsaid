#!/usr/bin/env bash

AZUL="\033[1;36m"
BLANCO="\033[1;37m"
DORADO="\033[1;33m"
ROSA="\033[1;95m"
VERDE="\033[1;32m"
ROJO="\033[1;31m"
RESET="\033[0m"

BOT_DIR="/opt/darkzsaid-lite-bot"
SERVICE="darkzsaid-lite-bot"

pausa() {
    echo
    read -rp "Presiona ENTER para continuar..."
}

configurar_bot() {
    clear
    echo -e "${AZUL}╔════════════════════════════════════════════╗${RESET}"
    echo -e "${BLANCO}        ⚡ DARKZSAID TELEGRAM BOT ⚡${RESET}"
    echo -e "${DORADO}          SSH • WS • SSL • USERS${RESET}"
    echo -e "${AZUL}╚════════════════════════════════════════════╝${RESET}"
    echo
    echo -e "${BLANCO}CONFIGURAR TOKEN E ID ADMINISTRADOR${RESET}"
    echo

    mkdir -p "$BOT_DIR"

    read -rp "Token del bot: " TOKEN
    read -rp "ID Telegram administrador: " ADMIN_ID
    read -rp "Usuario admin Telegram (@DarkZsaid): " ADMIN_USER

    [ -z "$ADMIN_USER" ] && ADMIN_USER="@DarkZsaid"

    python3 - <<PY
import json, os

cfg_path = "$BOT_DIR/config.json"

cfg = {
    "token": "$TOKEN",
    "admin_id": int("$ADMIN_ID") if "$ADMIN_ID".isdigit() else 0,
    "admin_username": "$ADMIN_USER",
    "authorized": {}
}

if os.path.exists(cfg_path):
    try:
        old = json.load(open(cfg_path))
        cfg["authorized"] = old.get("authorized", {})
    except Exception:
        pass

with open(cfg_path, "w") as f:
    json.dump(cfg, f, indent=2)

os.chmod(cfg_path, 0o600)
print("Configuración guardada correctamente.")
PY

    pausa
}

while true; do
    clear
    echo -e "${AZUL}╔════════════════════════════════════════════╗${RESET}"
    echo -e "${BLANCO}        ⚡ DARKZSAID TELEGRAM BOT ⚡${RESET}"
    echo -e "${DORADO}          SSH • WS • SSL • USERS${RESET}"
    echo -e "${AZUL}╚════════════════════════════════════════════╝${RESET}"
    echo
    echo -e "${BLANCO}MENÚ BOT TELEGRAM${RESET}"
    echo
    echo -e "${DORADO}[01]${RESET} ${BLANCO}Configurar token e ID administrador${RESET}"
    echo -e "${DORADO}[02]${RESET} ${BLANCO}Iniciar bot${RESET}"
    echo -e "${DORADO}[03]${RESET} ${BLANCO}Detener bot${RESET}"
    echo -e "${DORADO}[04]${RESET} ${BLANCO}Reiniciar bot${RESET}"
    echo -e "${DORADO}[00]${RESET} ${ROSA}Volver${RESET}"
    echo
    read -rp "Seleccione una opción: " opc

    case "$opc" in
        1|01)
            configurar_bot
        ;;
        2|02)
            systemctl start "$SERVICE" 2>/dev/null || true
            echo -e "${VERDE}Bot iniciado.${RESET}"
            pausa
        ;;
        3|03)
            systemctl stop "$SERVICE" 2>/dev/null || true
            echo -e "${ROJO}Bot detenido.${RESET}"
            pausa
        ;;
        4|04)
            systemctl restart "$SERVICE" 2>/dev/null || true
            echo -e "${VERDE}Bot reiniciado.${RESET}"
            pausa
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
