#!/bin/bash

limpiar_pantalla() {
    printf '\033[H\033[2J\033[3J'
}


[[ -f /opt/darkzsaid/lib/estilo_original.sh ]] && source /opt/darkzsaid/lib/estilo_original.sh

USERDIR="/etc/adm-lite/userDIR"

bar() {
    echo -e "\033[1;33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
}

titulo() {
    limpiar_pantalla
    if declare -F header >/dev/null 2>&1; then
        header
    fi
    bar
    echo -e "\033[1;36m              USUARIOS REGISTRADOS\033[0m"
    echo -e "\033[1;33m              SSH / WS / SSL\033[0m"
    bar
}

dias_restantes() {
    local user="$1"
    local exp exp_sec now_sec diff dias

    exp=$(chage -l "$user" 2>/dev/null | grep -i "Account expires" | awk -F: '{print $2}' | xargs)

    if [[ -z "$exp" || "$exp" == "never" ]]; then
        echo "Null"
        return
    fi

    exp_sec=$(date -d "$exp" +%s 2>/dev/null)
    now_sec=$(date +%s)

    if [[ -z "$exp_sec" ]]; then
        echo "Null"
        return
    fi

    diff=$((exp_sec - now_sec))
    dias=$((diff / 86400))

    if [[ "$dias" -lt 0 ]]; then
        echo "CADUCADO"
    else
        echo "$dias"
    fi
}

fecha_expira() {
    local user="$1"
    local exp

    exp=$(chage -l "$user" 2>/dev/null | grep -i "Account expires" | awk -F: '{print $2}' | xargs)

    if [[ -z "$exp" || "$exp" == "never" ]]; then
        echo "Null"
        return
    fi

    date -d "$exp" "+%Y-%m-%d" 2>/dev/null || echo "$exp"
}

estado_usuario() {
    local user="$1"
    local estado dias

    estado=$(passwd -S "$user" 2>/dev/null | awk '{print $2}')
    dias=$(dias_restantes "$user")

    if [[ "$estado" == "L" ]]; then
        echo "BLOQUEADO"
    elif [[ "$dias" == "CADUCADO" ]]; then
        echo "CADUCADO"
    else
        echo "ACTIVO"
    fi
}

senha_usuario() {
    local user="$1"
    local file="$USERDIR/$user"
    local senha

    if [[ -f "$file" ]]; then
        senha=$(grep -Ei "^(senha|clave|pass):" "$file" | head -1 | awk '{print $2}')
    fi

    [[ -z "$senha" ]] && senha="$user"
    echo "$senha"
}

limite_usuario() {
    local user="$1"
    local file="$USERDIR/$user"
    local lim

    if [[ -f "$file" ]]; then
        lim=$(grep -i "^limite:" "$file" | awk '{print $2}')
    fi

    if [[ -z "$lim" ]]; then
        lim=$(getent passwd "$user" | awk -F: '{split($5,a,","); print a[1]}')
    fi

    [[ -z "$lim" ]] && lim="1"
    echo "$lim"
}

listar_usuarios() {
    awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd | sort
}

titulo

total=0

while read -r user; do
    [[ -z "$user" ]] && continue

    total=$((total + 1))

    senha=$(senha_usuario "$user")
    limite=$(limite_usuario "$user")
    expira=$(fecha_expira "$user")
    dias=$(dias_restantes "$user")
    estado=$(estado_usuario "$user")

    echo -e "\033[0;35m[$(printf "%02d" "$total")]\033[0m ➜ \033[1;37m$user\033[0m"
    echo -e "     Nombre: \033[1;32m$user\033[0m   Límite: \033[1;33m$limite\033[0m   Estado: \033[1;32m$estado\033[0m"
    echo -e "     Expira: \033[1;36m$expira\033[0m   Días restantes: \033[1;33m$dias\033[0m"
    echo -e "     Pass: \033[1;32m$senha\033[0m"
    bar
done < <(listar_usuarios)

if [[ "$total" -eq 0 ]]; then
    echo -e "\033[1;31mNo hay usuarios registrados.\033[0m"
    bar
fi

echo -e "\033[1;33mTotal de usuarios registrados:\033[0m \033[1;32m$total\033[0m"
bar
read -rp "Presiona ENTER para volver..."
