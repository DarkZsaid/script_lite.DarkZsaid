#!/bin/bash

limpiar_pantalla() {
    printf '\033[H\033[2J\033[3J'
}


source /opt/darkzsaid/lib/estilo_original.sh

USERDIR="/etc/adm-lite/userDIR"
LOG_CNX="$USERDIR/usr_cnx"

mkdir -p "$USERDIR"

mostrar_log_consumo() {
    header
    msg -bar3
    print_center -azu "LOG DE CONSUMO"
    print_center -ama "Artificial"
    msg -bar3

    if [[ ! -e "$LOG_CNX" ]]; then
        echo -e "${cor[5]} ⚠️ VERIFICADOR DE CONSUMO NO ACTIVADO ⚠️${cor[0]}"
        echo
        echo -e "${cor[3]} Esta opción necesita el archivo:"
        echo -e "${cor[2]} $LOG_CNX"
        echo
        echo -e "${cor[5]} Luego conectaremos esta opción con CheckUser/MultiLogin"
        echo -e "${cor[5]} para registrar consumo real por usuario.${cor[0]}"
        msg -bar3
        read -rp "Presiona ENTER para volver..."
        return
    fi

    if [[ ! -s "$LOG_CNX" ]]; then
        echo -e "${cor[5]} ⚠️ LOG VACÍO, SIN DATOS DE CONSUMO ⚠️${cor[0]}"
        msg -bar3
        read -rp "Presiona ENTER para volver..."
        return
    fi

    echo -e "${cor[1]}  ▸ ${cor[3]}USUARIO        ${cor[1]}CONSUMO / REGISTRO${cor[0]}"
    msg -bar3

    nl -w2 -s' ' "$LOG_CNX" | while read -r num resto; do
        printf " \033[0;35m[\033[0;32m%02d\033[0;35m]\033[0;33m ➮ \033[1;37m%s\033[0m\n" "$num" "$resto"
    done

    msg -bar3
    echo -e "${cor[4]} ▼ # LOGS ${cor[5]}[ ${cor[3]}$(wc -l < "$LOG_CNX") ${cor[5]}] ${cor[4]} | REGISTROS EN TU SERVIDOR ${cor[2]}▾${cor[0]}"
    msg -bar3

    read -rp "Presiona ENTER para volver..."
}

crear_log_demo() {
    header
    msg -bar3
    print_center -azu "CREAR LOG DEMO"
    msg -bar3

    echo "steven | CONEXION: 1 | DATA: 0 MB | FECHA: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_CNX"
    msg -verd "Registro demo agregado en $LOG_CNX"
    msg -bar3
    read -rp "Presiona ENTER para volver..."
}

limpiar_log() {
    header
    msg -bar3
    print_center -azu "LIMPIAR LOG DE CONSUMO"
    msg -bar3

    read -rp "Escribe SI para limpiar el log: " conf

    if [[ "$conf" = "SI" ]]; then
        : > "$LOG_CNX"
        msg -verd "Log de consumo limpiado."
    else
        msg -ama "Cancelado."
    fi

    msg -bar3
    read -rp "Presiona ENTER para volver..."
}

while true; do
    header
    msg -bar3
    echo -e "${cor[2]}LOG DE CONSUMO  (Artificial)"
    msg -bar3

    echo -e "\033[0;35m [\033[0;36m01\033[0;35m]\033[0;31m >${cor[3]} VER LOG DE CONSUMO"
    echo -e "\033[0;35m [\033[0;36m02\033[0;35m]\033[0;31m >${cor[3]} CREAR REGISTRO DEMO"
    echo -e "\033[0;35m [\033[0;36m03\033[0;35m]\033[0;31m >${cor[3]} LIMPIAR LOG"
    msg -bar3
    echo -e " \033[0;35m [\033[0;36m0\033[0;35m]\033[0;31m > \033[1;37m\e[3;33m[ REGRESAR ]\e[0m"
    msg -bar3

    selection=$(selection_fun 3)

    case "$selection" in
        0) break ;;
        1) mostrar_log_consumo ;;
        2) crear_log_demo ;;
        3) limpiar_log ;;
    esac
done
