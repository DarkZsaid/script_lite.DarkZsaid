#!/usr/bin/env bash

clear

VERDE="\033[1;32m"
ROJO="\033[1;31m"
AMARILLO="\033[1;33m"
CYAN="\033[1;36m"
BLANCO="\033[1;37m"
RESET="\033[0m"

DATA_DIR="/opt/darkzsaid/data"
USER_DB="$DATA_DIR/usuarios_ssh.db"
USERDIR="/etc/adm-lite/userDIR"

mkdir -p "$DATA_DIR"
touch "$USER_DB"

mkdir -p /etc/adm-lite

if [ -e "$USERDIR" ] && [ ! -d "$USERDIR" ]; then
    mv "$USERDIR" "$USERDIR.malo_$(date +%F_%H-%M-%S)"
fi

mkdir -p "$USERDIR"
chmod 755 /etc/adm-lite "$USERDIR"

echo -e "${CYAN}======>>> ⚡ DarkZsaid 💥 Plus ⚡ <<<======${RESET}"
echo
echo -e "${AMARILLO}        CREAR USUARIO SSH${RESET}"
echo -e "${AMARILLO}────────────────────────────────────${RESET}"
echo

read -rp "USUARIO: " usuario
if [ -z "$usuario" ]; then
    echo -e "${ROJO}Usuario vacío.${RESET}"
    read -rp "Enter para volver..."
    exit 0
fi

if ! echo "$usuario" | grep -Eq '^[a-zA-Z0-9._-]+$'; then
    echo -e "${ROJO}Usuario inválido. Usa solo letras, números, punto, guion o guion bajo.${RESET}"
    read -rp "Enter para volver..."
    exit 0
fi

read -rp "CONTRASEÑA: " clave
if [ -z "$clave" ]; then
    echo -e "${ROJO}Contraseña vacía.${RESET}"
    read -rp "Enter para volver..."
    exit 0
fi

read -rp "LÍMITE DE CONEXIONES: " limite
[ -z "$limite" ] && limite="1"

if ! echo "$limite" | grep -Eq '^[0-9]+$'; then
    echo -e "${ROJO}Límite inválido.${RESET}"
    read -rp "Enter para volver..."
    exit 0
fi

read -rp "VALIDEZ EN DÍAS: " dias
[ -z "$dias" ] && dias="1"

if ! echo "$dias" | grep -Eq '^[0-9]+$'; then
    echo -e "${ROJO}Días inválidos.${RESET}"
    read -rp "Enter para volver..."
    exit 0
fi

caduca=$(date -d "+$dias days" +%Y-%m-%d 2>/dev/null)
creado=$(date +%Y-%m-%d)

if [ -z "$caduca" ]; then
    echo -e "${ROJO}No pude calcular la fecha de caducidad.${RESET}"
    read -rp "Enter para volver..."
    exit 1
fi

if id "$usuario" >/dev/null 2>&1; then
    echo "$usuario:$clave" | chpasswd
    usermod -s /bin/bash "$usuario" 2>/dev/null || true
else
    useradd -M -s /bin/bash "$usuario"
    echo "$usuario:$clave" | chpasswd
fi

passwd -u "$usuario" 2>/dev/null || true
chage -E "$caduca" "$usuario" 2>/dev/null || true

cat > "$USERDIR/$usuario" <<EOF
senha: $clave
limite: $limite
data: $caduca
EOF

chmod 644 "$USERDIR/$usuario"

grep -v "^$usuario|" "$USER_DB" > "$USER_DB.tmp" 2>/dev/null || true
mv "$USER_DB.tmp" "$USER_DB"

echo "$usuario|$clave|$caduca|$limite|SSH|$usuario|$creado" >> "$USER_DB"
chmod 644 "$USER_DB"

clear
echo -e "${VERDE}CUENTA SSH CREADA${RESET}"
echo
echo -e "${BLANCO}USUARIO    :${RESET} $usuario"
echo -e "${BLANCO}CONTRASEÑA :${RESET} $clave"
echo -e "${BLANCO}LÍMITE     :${RESET} $limite"
echo -e "${BLANCO}CADUCA     :${RESET} $caduca"
echo -e "${BLANCO}DÍAS       :${RESET} $dias"
echo
read -rp "Enter para volver..."
