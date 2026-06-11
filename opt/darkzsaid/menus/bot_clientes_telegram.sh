
limpiar_pantalla() {
    printf '\033[H\033[2J\033[3J'
}


estado_botssh_real() {
    if systemctl is-active --quiet darkzsaid-bot.service; then
        echo "ON"
    else
        echo "OFF"
    fi
}

#!/bin/bash

source /opt/darkzsaid/lib/estilo_original.sh

BOT_DIR="/opt/darkzsaid/bot"
BOT_CONF="/etc/darkzsaid/bot/bot.conf"
BOT_FILE="$BOT_DIR/darkzsaid_bot.sh"
BOT_PID="/var/run/darkzsaid_bot.pid"

mkdir -p "$BOT_DIR" /etc/darkzsaid/bot /bin/ejecutar

status_botssh() {
    if systemctl is-active --quiet darkzsaid-bot.service; then
        echo -e "[0;32m[ON][0m"
    else
        echo -e "[1;31m[OFF][0m"
    fi
}

status_whatsapp() {
    if [[ -e /etc/systemd/system/BotWASSH.service ]]; then
        echo -e "\033[0;31m[\033[0;32mON\033[0;31m]"
    else
        echo -e "\033[1;31m[OFF]"
    fi
}


toggle_botssh() {
    limpiar_pantalla
    print_center -azu "ACTIVAR / DETENER BOT TELEGRAM"

    if systemctl is-active --quiet darkzsaid-bot.service; then
        echo -e "${col[5]}Bot Telegram está ON. Deteniendo...${col[0]}"
        systemctl stop darkzsaid-bot.service >/dev/null 2>&1
        pkill -f "darkzsaid_bot.py" >/dev/null 2>&1 || true
        pkill -f "darkzsaid_bot.sh" >/dev/null 2>&1 || true
        sleep 2

        if systemctl is-active --quiet darkzsaid-bot.service; then
            msg -ama "No se pudo detener el bot."
        else
            msg -verd "Bot Telegram detenido correctamente. [OFF]"
        fi

        read -rp "Presiona ENTER para volver..."
        return
    fi

    echo -e "${col[5]}Bot Telegram está OFF. Para activar configura el acceso.${col[0]}"
    echo

    read -rp "Token del bot de Telegram: " BOT_TOKEN
    read -rp "ID Telegram SuperAdmin: " ADMIN_ID
    read -rp "Contraseña del bot/login: " BOT_PASS

    if [[ -z "$BOT_TOKEN" || -z "$ADMIN_ID" ]]; then
        msg -ama "Token o ID vacío. No se activó el bot."
        read -rp "Presiona ENTER para volver..."
        return
    fi

    mkdir -p /etc/darkzsaid/bot

    cat > /etc/darkzsaid/bot/bot.conf <<EOF
BOT_TOKEN="$BOT_TOKEN"
ADMIN_ID="$ADMIN_ID"
BOT_LOGIN="$ADMIN_ID"
BOT_PASS="${BOT_PASS:-DarkZsaid}"
EOF

    chmod 600 /etc/darkzsaid/bot/bot.conf

    echo -e "${col[5]}Configuración guardada. Iniciando bot...${col[0]}"

    systemctl daemon-reload >/dev/null 2>&1
    systemctl enable darkzsaid-bot.service >/dev/null 2>&1
    systemctl restart darkzsaid-bot.service >/dev/null 2>&1

    sleep 2

    if systemctl is-active --quiet darkzsaid-bot.service; then
        msg -verd "Bot Telegram iniciado correctamente. [ON]"
        echo -e "${col[3]}Ahora prueba en Telegram: /start${col[0]}"
    else
        msg -ama "No se pudo iniciar el bot. Revisa logs."
        journalctl -u darkzsaid-bot.service -n 20 --no-pager -l
    fi

    read -rp "Presiona ENTER para volver..."
}

instalar_botssh() {
    header
    msg -bar3
    print_center -azu "ACTIVAR / DETENER BotSSH"
    msg -bar3

    [[ -e /bin/ejecutar/TKBot ]] && read -p " TELEGRAM BOT TOKEN: " -e -i "$(cat /bin/ejecutar/TKBot)" tokenxx || read -p " TELEGRAM BOT TOKEN: " tokenxx
    [[ -e /etc/darkzsaid/bot/bottokens ]] && read -p " TELEGRAM BOT LOGIN: " -e -i "$(cut -d ':' -f1 /etc/darkzsaid/bot/bottokens)" loguin || read -p " TELEGRAM BOT LOGIN: " loguin
    [[ -e /etc/darkzsaid/bot/bottokens ]] && read -p " TELEGRAM BOT PASS: " -e -i "$(cut -d ':' -f2 /etc/darkzsaid/bot/bottokens)" pass || read -p " TELEGRAM BOT PASS: " pass
    read -p " IDIOMA DEL BOT [ES]: " lang
    [[ -z "$lang" ]] && lang="ES"

    [[ -z "$tokenxx" ]] && {
        msg -verm "Token vacío."
        sleep 2
        return
    }

    echo -e "${loguin}:${pass}" > /etc/darkzsaid/bot/bottokens
    echo -e "${tokenxx}" > /bin/ejecutar/TKBot

    cat > "$BOT_CONF" <<EOC
BOT_TOKEN="$tokenxx"
BOT_LOGIN="$loguin"
BOT_PASS="$pass"
BOT_LANG="$lang"
ADMIN_ID=""
EOC

    msg -verd "Configuración BotSSH guardada."
    echo
    echo -e "${cor[5]}Falta conectar el motor DarkZsaid Bot con los mensajes reales"
    echo -e "${cor[5]}después de revisar ultimatebot_original.sh"
    msg -bar3
    read -rp "Presiona ENTER para volver..."
}

reiniciar_botssh() {
    if [[ -f "$BOT_PID" ]]; then
        kill "$(cat "$BOT_PID")" 2>/dev/null
        rm -f "$BOT_PID"
    fi

    pkill -f "darkzsaid_bot.sh" 2>/dev/null

    if [[ -x "$BOT_FILE" ]]; then
        nohup bash "$BOT_FILE" >/opt/darkzsaid/logs/bot.log 2>&1 &
        echo $! > "$BOT_PID"
        msg -verd "BotSSH reiniciado."
    else
        msg -verm "Motor darkzsaid_bot.sh todavía no creado."
    fi

    sleep 2
}

actualizar_binario() {
    header
    msg -bar3
    print_center -azu "ACTUALIZAR BINARIO"
    msg -bar3

    echo -e "${cor[5]}Originalmente esta opción actualiza /etc/adm-lite/ultimatebot."
    echo -e "${cor[3]}En DarkZsaid actualizará:"
    echo -e "${cor[2]}$BOT_FILE"
    echo
    echo -e "${cor[5]}Pendiente: conectar a tu repo cuando tengamos el bot final."
    msg -bar3
    read -rp "Presiona ENTER para volver..."
}

notificar_creados() {
    header
    msg -bar3
    print_center -azu "Notificar CREADOS"
    msg -bar3

    echo -e "${cor[5]}Original: activa/desactiva notificación de cuentas creadas."
    echo -e "${cor[3]}DarkZsaid usará:"
    echo -e "${cor[2]}/etc/darkzsaid/bot/notificar_creados.on"
    msg -bar3

    if [[ -e /etc/darkzsaid/bot/notificar_creados.on ]]; then
        rm -f /etc/darkzsaid/bot/notificar_creados.on
        msg -ama "Notificar creados: OFF"
    else
        touch /etc/darkzsaid/bot/notificar_creados.on
        msg -verd "Notificar creados: ON"
    fi

    sleep 2
}

mostrar_creados_reseller() {
    header
    msg -bar3
    print_center -azu "Mostrar Creados Reseller"
    msg -bar3

    if [[ -f /etc/darkzsaid/bot/creados_reseller.log ]]; then
        cat /etc/darkzsaid/bot/creados_reseller.log
    else
        msg -verm "No hay registros reseller todavía."
    fi

    msg -bar3
    read -rp "Presiona ENTER para volver..."
}

limitar_creadores() {
    header
    msg -bar3
    print_center -azu "Limitar Creadores"
    msg -bar3

    read -rp "Límite de creaciones por reseller: " limite
    [[ -z "$limite" ]] && limite="10"

    echo "$limite" > /etc/darkzsaid/bot/limite_creadores
    msg -verd "Límite guardado: $limite"
    sleep 2
}

desinstalar_botssh() {
    header
    msg -bar3
    print_center -verm2 "DESACTIVAR / DETENER BotSSH"
    msg -bar3

    read -rp "Escribe SI para desinstalar BotSSH: " conf
    [[ "$conf" != "SI" ]] && {
        msg -ama "Cancelado."
        sleep 2
        return
    }

    systemctl stop BotSSH.service >/dev/null 2>&1
    systemctl disable BotSSH.service >/dev/null 2>&1
    rm -f /etc/systemd/system/BotSSH.service
    rm -f "$BOT_PID"
    pkill -f "darkzsaid_bot.sh" 2>/dev/null

    msg -verd "BotSSH removido."
    sleep 2
}

instalar_whatsapp() {
    header
    msg -bar3
    print_center -azu "INSTALAR BotSSH WHATSAPP"
    msg -bar3

    echo -e "${cor[5]}Original instala NodeJS, handler.sh y BotWASSH."
    echo -e "${cor[3]}Lo dejaremos pendiente para reconstruir limpio."
    msg -bar3
    read -rp "Presiona ENTER para volver..."
}

reactivar_whatsapp() {
    systemctl restart BotWASSH.service >/dev/null 2>&1
    msg -verd "Intento de reactivar BotWASSH realizado."
    sleep 2
}

while true; do
    _pid="$(status_botssh)"
    _wa="$(status_whatsapp)"

    header
    msg -bar3
    msg -ama "         INSTALADOR BotSSH | DarkZsaid Plus"
    msg -bar3

    echo -e "\033[0;35m [${cor[2]}01\033[0;35m]\033[0;33m ${flech}${cor[3]} ACTIVAR / DETENER BotSSH ${_pid}"
    echo -e "\033[0;35m [${cor[2]}02\033[0;35m]\033[0;33m ${flech}${cor[3]} Reiniciar BotSSH"
    echo -e "\033[0;35m [${cor[2]}03\033[0;35m]\033[0;33m ${flech}${cor[3]} ACTUALIZAR BINARIO"
    echo -e "\033[0;35m [${cor[2]}04\033[0;35m]\033[0;33m ${flech}${cor[3]} Notificar CREADOS"
    echo -e "\033[0;35m [${cor[2]}05\033[0;35m]\033[0;33m ${flech}${cor[3]} Mostrar Creados Reseller"
    echo -e "\033[0;35m [${cor[2]}06\033[0;35m]\033[0;33m ${flech}${cor[3]} Limitar Creadores"
    echo -e "\033[0;35m [${cor[2]}07\033[0;35m]\033[0;33m ${flech}\033[1;31m DESACTIVAR / DETENER BotSSH"
    echo -e "\033[0;35m [${cor[2]}08\033[0;35m]\033[0;33m ${flech}${cor[3]} ACTIVAR / DETENER BotSSH  WHATSAPP "
    echo -e "\033[0;35m [${cor[2]}09\033[0;35m]\033[0;33m ${flech}${cor[3]} REACTIVAR BOT WHASTAPP ( ${_wa} )"
    msg -bar3
    echo -e " \033[0;35m [${cor[2]}0\033[0;35m]\033[0;33m ${flech} \033[1;37m\e[3;33m[ REGRESAR ]\e[0m"
    msg -bar3

    selection=$(selection_fun 9)

    case "$selection" in
        0) break ;;
        1) toggle_botssh ;;
        2) reiniciar_botssh ;;
        3) actualizar_binario ;;
        4) notificar_creados ;;
        5) mostrar_creados_reseller ;;
        6) limitar_creadores ;;
        7) desinstalar_botssh ;;
        8) instalar_whatsapp ;;
        9) reactivar_whatsapp ;;
    esac
done
