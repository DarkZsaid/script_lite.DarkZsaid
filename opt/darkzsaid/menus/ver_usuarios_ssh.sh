#!/usr/bin/env bash

clear

VERDE="\033[1;32m"
CYAN="\033[1;36m"
AMARILLO="\033[1;33m"
BLANCO="\033[1;37m"
RESET="\033[0m"

USERDIR="/etc/adm-lite/userDIR"

echo -e "${CYAN}=====>>> ⚡ DarkZsaid Plus ⚡ <<<=====${RESET}"
echo
echo -e "${BLANCO}        CLIENTES SSH REGISTRADOS${RESET}"
echo -e "${CYAN}--------------------------------------------------${RESET}"
printf "${AMARILLO}%-3s %-12s %-10s %-4s %-10s %-4s${RESET}\n" "N" "USUARIO" "CLAVE" "LIM" "CADUCA" "DIA"
echo -e "${CYAN}--------------------------------------------------${RESET}"

total=0

if [ -d "$USERDIR" ]; then
    for file in "$USERDIR"/*; do
        [ -f "$file" ] || continue

        usuario="$(basename "$file")"
        clave="$(grep -i '^senha:' "$file" 2>/dev/null | head -1 | cut -d':' -f2- | xargs)"
        limite="$(grep -i '^Limite:' "$file" 2>/dev/null | head -1 | cut -d':' -f2- | xargs)"
        caduca="$(grep -i '^data:' "$file" 2>/dev/null | head -1 | cut -d':' -f2- | xargs)"

        [ -z "$clave" ] && clave="-"
        [ -z "$limite" ] && limite="-"
        [ -z "$caduca" ] && caduca="-"

        dias="-"
        if echo "$caduca" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
            hoy=$(date +%s)
            fin=$(date -d "$caduca" +%s 2>/dev/null)
            if [ -n "$fin" ]; then
                dias=$(( (fin - hoy) / 86400 ))
                [ "$dias" -lt 0 ] && dias="0"
            fi
        fi

        total=$((total + 1))
        printf "${VERDE}%-3s${RESET} %-12s %-10s %-4s %-10s %-4s\n" "[$total]" "$usuario" "$clave" "$limite" "$caduca" "$dias"
    done
fi

echo -e "${CYAN}--------------------------------------------------${RESET}"
echo -e "${VERDE}# TOTAL CLIENTES SSH: [ $total ]${RESET}"
echo
read -rp "Presiona ENTER para continuar..."
