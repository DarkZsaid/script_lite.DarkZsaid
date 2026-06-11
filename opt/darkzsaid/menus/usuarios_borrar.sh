#!/bin/bash

limpiar_pantalla() {
    printf '\033[H\033[2J\033[3J'
}


source /opt/darkzsaid/lib/estilo_original.sh

USERDIR="/etc/adm-lite/userDIR"
DZ_USERDIR="/etc/darkzsaid/usuarios"

mkdir -p "$USERDIR" "$DZ_USERDIR"

es_usuario_protegido() {
    local u="$1"
    [[ "$u" =~ ^(root|daemon|bin|sys|sync|games|man|lp|mail|news|uucp|proxy|www-data|list|irc|gnats|nobody|systemd|sshd|messagebus|_apt)$ ]]
}

listar_usuarios_panel() {
    find "$USERDIR" -maxdepth 1 -type f -printf "%f\n" 2>/dev/null | sort
}

matar_sesiones_usuario() {
    local usuario="$1"

    pkill -u "$usuario" 2>/dev/null
    pkill -f "sshd: $usuario" 2>/dev/null
    pkill -f ".*$usuario" 2>/dev/null
}

borrar_usuario_uno() {
    header
    msg -bar3
    print_center -azu "BORRAR USUARIO"
    print_center -ama "SSH / WS / SSL"
    msg -bar3

    usuarios=()
    while IFS= read -r u; do
        [[ -z "$u" ]] && continue
        usuarios+=("$u")
    done < <(listar_usuarios_panel)

    if [[ "${#usuarios[@]}" -eq 0 ]]; then
        msg -verm "No hay usuarios registrados en $USERDIR"
        msg -bar3
        read -rp "Presiona ENTER para volver..."
        return
    fi

    local i=1
    for u in "${usuarios[@]}"; do
        local nombre="$u"
        local limite="?"
        local data="?"

        if [[ -f "$USERDIR/$u" ]]; then
            nombre=$(grep -i "^senha:" "$USERDIR/$u" 2>/dev/null | cut -d: -f2- | xargs)
            limite=$(grep -i "^limite:" "$USERDIR/$u" 2>/dev/null | cut -d: -f2- | xargs)
            data=$(grep -i "^data:" "$USERDIR/$u" 2>/dev/null | cut -d: -f2- | xargs)
            [[ -z "$nombre" ]] && nombre="$u"
        fi

        num=$(printf "%02d" "$i")
        echo -e "\033[0;35m [${cor[2]}${num}\033[0;35m]\033[0;33m ${flech}\033[1;37m ${u}  \033[1;33mLimite:\033[1;32m ${limite}  \033[1;33mExp:\033[1;32m ${data}\033[0m"
        ((i++))
    done

    msg -bar3
    echo -e "\033[0;35m [${cor[2]}0\033[0;35m]\033[0;33m ⇦ \033[1;37m\e[3;33m[ VOLVER ]\e[0m"
    msg -bar3

    read -rp "Seleccione usuario a borrar: " op

    [[ "$op" = "0" ]] && return

    if ! [[ "$op" =~ ^[0-9]+$ ]] || [[ "$op" -lt 1 ]] || [[ "$op" -gt "${#usuarios[@]}" ]]; then
        msg -verm "Opción inválida."
        sleep 2
        return
    fi

    usuario="${usuarios[$((op-1))]}"

    if es_usuario_protegido "$usuario"; then
        msg -verm "Usuario protegido. No se borra: $usuario"
        sleep 2
        return
    fi

    msg -bar3
    echo -e "${cor[5]} Usuario seleccionado:${cor[3]} $usuario"
    read -rp "Escribe SI para confirmar borrado: " conf

    if [[ "$conf" != "SI" ]]; then
        msg -ama "Cancelado."
        sleep 2
        return
    fi

    matar_sesiones_usuario "$usuario"

    userdel "$usuario" 2>/dev/null
    rm -f "$USERDIR/$usuario"
    rm -f "$DZ_USERDIR/$usuario"

    msg -verd "Usuario eliminado: $usuario"
    msg -bar3
    read -rp "Presiona ENTER para volver..."
}

borrar_todos() {
    header
    msg -bar3
    print_center -verm2 "BORRAR TODOS LOS USUARIOS"
    msg -bar3

    usuarios=()
    while IFS= read -r u; do
        [[ -z "$u" ]] && continue
        usuarios+=("$u")
    done < <(listar_usuarios_panel)

    if [[ "${#usuarios[@]}" -eq 0 ]]; then
        msg -verm "No hay usuarios registrados para borrar."
        msg -bar3
        read -rp "Presiona ENTER para volver..."
        return
    fi

    echo -e "${cor[5]}Usuarios encontrados:${cor[3]} ${#usuarios[@]}"
    echo -e "${cor[1]}Esta acción borrará todos los usuarios creados por el panel.${cor[0]}"
    echo
    read -rp "Escribe BORRAR TODO para confirmar: " conf

    if [[ "$conf" != "BORRAR TODO" ]]; then
        msg -ama "Cancelado."
        sleep 2
        return
    fi

    for usuario in "${usuarios[@]}"; do
        if es_usuario_protegido "$usuario"; then
            continue
        fi

        matar_sesiones_usuario "$usuario"
        userdel "$usuario" 2>/dev/null
        rm -f "$USERDIR/$usuario"
        rm -f "$DZ_USERDIR/$usuario"
    done

    msg -verd "Usuarios del panel eliminados."
    msg -bar3
    read -rp "Presiona ENTER para volver..."
}

while true; do
    header
    msg -bar3
    print_center -azu "BORRAR USUARIOS"
    print_center -ama "1 / TODOS LOS USUARIO/s"
    msg -bar3

    echo -e "\033[0;35m [${cor[2]}01\033[0;35m]\033[0;33m ${flech}${cor[3]} BORRAR 1 USUARIO"
    echo -e "\033[0;35m [${cor[2]}02\033[0;35m]\033[0;33m ${flech}${cor[3]} BORRAR TODOS LOS USUARIOS"
    msg -bar3
    echo -e "\033[0;35m [${cor[2]}0\033[0;35m]\033[0;33m ⇦ \033[1;37m\e[3;33m[ VOLVER ]\e[0m"
    msg -bar3

    selection=$(selection_fun 2)

    case "$selection" in
        0) break ;;
        1) borrar_usuario_uno ;;
        2) borrar_todos ;;
    esac
done
