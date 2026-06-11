#!/usr/bin/env bash

ROOT="/opt/darkzsaid-lite"
USERDIR="/etc/adm-lite/userDIR"
WS_DIR="$ROOT/ws"

WS_OPENSSH_PORTS="80 8084 8086"
WS_SSH_PORTS="90 8080 8082"
WS_PORTS="$WS_OPENSSH_PORTS $WS_SSH_PORTS"

OPENSSH_PORTS="22"
OPENSSH_TARGET="22"
SSH_TARGET="22"

SSL_PORT="443"
SSL_TARGET="80"

VERDE="[1;95m"
ROJO="\033[1;31m"
CYAN="\033[1;96m"
AMARILLO="\033[1;33m"
BLANCO="\033[1;97m"
RESET="\033[0m"
DORADO="\033[1;38;5;220m"
NARANJA="\033[1;38;5;208m"
AZUL="\033[1;94m"
GRIS="\033[1;90m"
MORADO="\033[1;95m"
PLATA="\033[1;37m"
ONCOLOR="\033[1;38;5;220m"
OFFCOLOR="\033[1;38;5;203m"


mkdir -p "$ROOT" "$USERDIR" "$WS_DIR"

pause() {
    echo
    read -rp "Presiona ENTER para continuar..."
}

titulo() {
    clear

    UBUNTU_VER="$(lsb_release -ds 2>/dev/null | sed 's/"//g')"
    [ -z "$UBUNTU_VER" ] && UBUNTU_VER="$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')"
    [ -z "$UBUNTU_VER" ] && UBUNTU_VER="Ubuntu"

    IP_VPS="$(hostname -I 2>/dev/null | awk '{print $1}')"
    [ -z "$IP_VPS" ] && IP_VPS="$(curl -s --max-time 3 ifconfig.me 2>/dev/null)"
    [ -z "$IP_VPS" ] && IP_VPS="No detectada"

    HORA_ACTUAL="$(date '+%H:%M:%S')"
    FECHA_ACTUAL="$(date '+%d/%m/%Y')"

    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}        ${BLANCO}⚡ DARKZSAID LITE PREMIUM ⚡${RESET}        ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}             ${DORADO}SSH  •  WS  •  SSL${RESET}             ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${RESET}"
    echo
    echo -e "${AZUL} VPS INFO${RESET} ${GRIS}────────────────────────────────────${RESET}"
    echo -e " ${BLANCO}Sistema:${RESET} ${DORADO}${UBUNTU_VER}${RESET}"
    echo -e " ${BLANCO}IP VPS:${RESET}   ${CYAN}${IP_VPS}${RESET}"
    echo -e " ${BLANCO}Fecha:${RESET}    ${DORADO}${FECHA_ACTUAL}${RESET}     ${BLANCO}Hora:${RESET} ${DORADO}${HORA_ACTUAL}${RESET}"
    echo
    echo -e "${AZUL} MAPEO DE PUERTOS${RESET} ${GRIS}────────────────────────────${RESET}"
    echo -e " ${BLANCO}WS:${RESET}  ${DORADO}80${RESET} ${GRIS}|${RESET} ${DORADO}90${RESET} ${GRIS}|${RESET} ${DORADO}8080${RESET} ${GRIS}|${RESET} ${DORADO}8082${RESET} ${GRIS}|${RESET} ${DORADO}8084${RESET} ${GRIS}|${RESET} ${DORADO}8086${RESET}"
    echo -e " ${CYAN}➜${RESET} ${NARANJA}80 / 8084 / 8086${RESET} ${BLANCO}→${RESET} ${MORADO}OpenSSH 22${RESET}"
    echo -e " ${CYAN}➜${RESET} ${NARANJA}90 / 8080 / 8082${RESET} ${BLANCO}→${RESET} ${MORADO}OpenSSH 22${RESET}"
    echo -e " ${CYAN}➜${RESET} ${DORADO}SSL 443${RESET} ${BLANCO}→${RESET} ${NARANJA}WS 80${RESET} ${BLANCO}→${RESET} ${MORADO}OpenSSH 22${RESET}"
    echo
}


crear_motor_ws() {
    mkdir -p "$WS_DIR"

    cat > "$WS_DIR/ws_ssh_proxy.py" <<'PY'
#!/usr/bin/env python3
import socket
import threading
import sys

LISTEN_HOST = "0.0.0.0"
LISTEN_PORT = int(sys.argv[1])
TARGET_HOST = "127.0.0.1"
TARGET_PORT = int(sys.argv[2])

def pipe(src, dst):
    try:
        while True:
            data = src.recv(8192)
            if not data:
                break
            dst.sendall(data)
    except Exception:
        pass
    finally:
        try:
            src.close()
        except Exception:
            pass
        try:
            dst.close()
        except Exception:
            pass

def handle(client):
    try:
        client.settimeout(10)
        first = client.recv(8192)

        is_http = first.startswith(b"GET ") or first.startswith(b"POST ") or first.startswith(b"CONNECT ")

        if is_http:
            low = first.lower()

            if b"upgrade: websocket" in low:
                client.sendall(
                    b"HTTP/1.1 101 Switching Protocols\r\n"
                    b"Upgrade: websocket\r\n"
                    b"Connection: Upgrade\r\n\r\n"
                )
            elif first.startswith(b"CONNECT "):
                client.sendall(b"HTTP/1.1 200 Connection established\r\n\r\n")
            else:
                client.sendall(b"HTTP/1.1 200 OK\r\n\r\n")

        ssh = socket.create_connection((TARGET_HOST, TARGET_PORT), timeout=10)

        if not is_http:
            ssh.sendall(first)

        threading.Thread(target=pipe, args=(client, ssh), daemon=True).start()
        threading.Thread(target=pipe, args=(ssh, client), daemon=True).start()

    except Exception:
        try:
            client.close()
        except Exception:
            pass

def main():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind((LISTEN_HOST, LISTEN_PORT))
    server.listen(500)

    while True:
        client, _ = server.accept()
        threading.Thread(target=handle, args=(client,), daemon=True).start()

if __name__ == "__main__":
    main()
PY

    chmod +x "$WS_DIR/ws_ssh_proxy.py"
}

crear_servicio_ws() {
    local PORT="$1"
    local TARGET="$2"

    cat > "/etc/systemd/system/darkzsaid-lite-ws-${PORT}.service" <<EOD
[Unit]
Description=DarkZsaid Lite WS Port ${PORT} to ${TARGET}
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 ${WS_DIR}/ws_ssh_proxy.py ${PORT} ${TARGET}
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOD

    systemctl daemon-reload
    systemctl enable "darkzsaid-lite-ws-${PORT}" >/dev/null 2>&1 || true
}

instalar_protocolo() {
    titulo
    echo -e "${BLANCO}Abriendo panel real SSH WS de DarkZsaid...${RESET}"
    echo

    if [ -f "/opt/darkzsaid/menus/ssh_ws_puro_menu.sh" ]; then
        bash /opt/darkzsaid/menus/ssh_ws_puro_menu.sh
    else
        echo -e "${ROJO}No existe el panel real SSH WS:${RESET}"
        echo "/opt/darkzsaid/menus/ssh_ws_puro_menu.sh"
        echo
        echo "Primero instala o clona DarkZsaid en /opt/darkzsaid"
        pause
    fi
}


crear_usuario() {
    titulo
    echo -e "${BLANCO}✦ CREAR USUARIO SSH ✦${RESET}"
    echo -e "${CYAN}────────────────────────────────────────────────────${RESET}"
    echo

    echo -ne "${BLANCO}Usuario: "; read -r usuario; echo -ne "${RESET}"
    [ -z "$usuario" ] && echo "Usuario vacío." && pause && return

    if id "$usuario" >/dev/null 2>&1; then
        echo -e "${ROJO}Ese usuario ya existe.${RESET}"
        pause
        return
    fi

    echo -ne "${BLANCO}Contraseña: "; read -r clave; echo -ne "${RESET}"
    echo -ne "${BLANCO}Límite de conexiones: "; read -r limite; echo -ne "${RESET}"
    echo -ne "${BLANCO}Validez en días: "; read -r dias; echo -ne "${RESET}"

    echo
    echo -e "${BLANCO}Unidad de consumo:${RESET}"
    echo -e "${DORADO}[1]${RESET} ${BLANCO}MB${RESET}"
    echo -e "${DORADO}[2]${RESET} ${BLANCO}GB${RESET}"
    echo -ne "${BLANCO}Seleccione unidad [1/2 o MB/GB]: "; read -r unidad_opc; echo -ne "${RESET}"

    unidad_opc="$(echo "$unidad_opc" | tr '[:lower:]' '[:upper:]')"

    case "$unidad_opc" in
        1|MB) unidad="MB" ;;
        2|GB|"") unidad="GB" ;;
        *) unidad="GB" ;;
    esac

    echo -ne "${BLANCO}Cantidad de consumo en ${unidad}: "; read -r consumo; echo -ne "${RESET}"

    [ -z "$clave" ] && clave="1234"
    [ -z "$limite" ] && limite="1"
    [ -z "$dias" ] && dias="30"
    [ -z "$consumo" ] && consumo="0"

    if ! echo "$consumo" | grep -Eq '^[0-9]+$'; then
        echo -e "${ROJO}Cantidad inválida. Se usará 0 $unidad.${RESET}"
        consumo="0"
    fi

    if [ "$consumo" = "0" ]; then
        consumo_texto="Ilimitado"
    else
        consumo_texto="$consumo $unidad"
    fi

    fecha_fin="$(date -d "+$dias days" +%Y-%m-%d)"

    useradd -M -s /bin/bash "$usuario"
    echo "$usuario:$clave" | chpasswd
    chage -E "$fecha_fin" "$usuario"

    mkdir -p "$USERDIR"

    cat > "$USERDIR/$usuario" <<EOD
usuario: $usuario
senha: $clave
Limite: $limite
data: $fecha_fin
Consumo: $consumo
Unidad: $unidad
UsadoMB: 0
EOD

    /usr/local/bin/darkzsaid_quota_check.sh --setup "$usuario" >/dev/null 2>&1 || true

    echo
    echo -e "${CYAN}────────────────────────────────────────────────────${RESET}"
    echo -e "${MORADO}Usuario creado correctamente.${RESET}"
    echo -e "${CYAN}────────────────────────────────────────────────────${RESET}"
    echo -e "${BLANCO}Usuario:${RESET}  ${DORADO}$usuario${RESET}"
    echo -e "${BLANCO}Clave:${RESET}    ${DORADO}$clave${RESET}"
    echo -e "${BLANCO}Límite:${RESET}   ${DORADO}$limite${RESET}"
    echo -e "${BLANCO}Caduca:${RESET}   ${DORADO}$fecha_fin${RESET}"
    echo -e "${BLANCO}Consumo:${RESET}  ${DORADO}$consumo_texto${RESET}"
    echo
    pause
}


seleccionar_usuario_numero() {
    local titulo_accion="$1"
    local archivos=()
    local total=0
    local file usuario clave limite caduca dias hoy fin num

    titulo
    echo -e "${BLANCO}✦ ${titulo_accion} ✦${RESET}"
    echo -e "${CYAN}────────────────────────────────────────────────────${RESET}"
    printf "${CYAN}%-4s %-14s %-12s %-6s %-12s %-5s${RESET}\n" "N" "USUARIO" "CLAVE" "LIM" "CADUCA" "DIA"
    echo -e "${CYAN}────────────────────────────────────────────────────${RESET}"

    for file in "$USERDIR"/*; do
        [ -f "$file" ] || continue

        usuario="$(basename "$file")"
        clave="$(grep -i '^senha:' "$file" 2>/dev/null | head -1 | cut -d':' -f2- | xargs)"
        limite="$(grep -i '^Limite:' "$file" 2>/dev/null | head -1 | cut -d':' -f2- | xargs)"
        caduca="$(grep -i '^data:' "$file" 2>/dev/null | head -1 | cut -d':' -f2- | xargs)"

        [ -z "$clave" ] && clave="-"
        [ -z "$limite" ] && limite="0"
        [ -z "$caduca" ] && caduca="-"

        dias="-"
        if echo "$caduca" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
            hoy="$(date +%s)"
            fin="$(date -d "$caduca" +%s 2>/dev/null)"
            dias=$(( (fin - hoy) / 86400 ))
            [ "$dias" -lt 0 ] && dias="0"
        fi

        total=$((total + 1))
        archivos[$total]="$file"

        printf "${DORADO}%-4s${RESET} ${MORADO}%-14s${RESET} ${NARANJA}%-12s${RESET} ${DORADO}%-6s${RESET} ${CYAN}%-12s${RESET} ${DORADO}%-5s${RESET}\n" \
        "[$total]" "$usuario" "$clave" "$limite" "$caduca" "$dias"
    done

    echo -e "${CYAN}────────────────────────────────────────────────────${RESET}"

    if [ "$total" -eq 0 ]; then
        echo -e "${ROJO}No hay usuarios registrados.${RESET}"
        pause
        return 1
    fi

    echo
    read -rp "Seleccione número de usuario: " num

    if ! echo "$num" | grep -Eq '^[0-9]+$'; then
        echo -e "${ROJO}Número inválido.${RESET}"
        pause
        return 1
    fi

    if [ "$num" -lt 1 ] || [ "$num" -gt "$total" ]; then
        echo -e "${ROJO}Número fuera de rango.${RESET}"
        pause
        return 1
    fi

    SELECTED_USER_FILE="${archivos[$num]}"
    SELECTED_USER_NAME="$(basename "$SELECTED_USER_FILE")"
    return 0
}

limpiar_reglas_cuota_usuario() {
    local usuario="$1"
    local uid="$2"
    local rule=""

    [ -z "$usuario" ] && return 0
    [ -z "$uid" ] && return 0

    iptables -t mangle -S 2>/dev/null | grep -E "DZQ2:${usuario}:${uid}|DZQ:${usuario}:${uid}" | while read -r rule; do
        rule="${rule/-A /-D }"
        iptables -t mangle $rule 2>/dev/null || true
    done

    iptables -S 2>/dev/null | grep -E "DZQ2:${usuario}:${uid}|DZQ:${usuario}:${uid}" | while read -r rule; do
        rule="${rule/-A /-D }"
        iptables $rule 2>/dev/null || true
    done
}

eliminar_usuario() {
    local usuario file uid deleted_dir

    seleccionar_usuario_numero "ELIMINAR USUARIO SSH" || return

    usuario="$SELECTED_USER_NAME"
    file="$SELECTED_USER_FILE"
    uid=""

    if id "$usuario" >/dev/null 2>&1; then
        uid="$(id -u "$usuario")"
    fi

    echo
    echo -e "${ROJO}Eliminando usuario:${RESET} ${DORADO}$usuario${RESET}"

    pkill -u "$usuario" 2>/dev/null || true
    pkill -f "sshd: $usuario" 2>/dev/null || true

    if [ -n "$uid" ]; then
        limpiar_reglas_cuota_usuario "$usuario" "$uid"
    fi

    userdel -f "$usuario" 2>/dev/null || true

    deleted_dir="/etc/adm-lite/userDIR_eliminados"
    mkdir -p "$deleted_dir"

    if [ -f "$file" ]; then
        mv "$file" "$deleted_dir/${usuario}_eliminado_manual_$(date +%F_%H-%M-%S)" 2>/dev/null || rm -f "$file"
    fi

    echo
    echo -e "${CYAN}────────────────────────────────────────────────────${RESET}"
    echo -e "${BLANCO}Usuario eliminado correctamente:${RESET} ${DORADO}$usuario${RESET}"
    echo -e "${CYAN}────────────────────────────────────────────────────${RESET}"
    pause
}

renovar_usuario() {
    local usuario file caduca actual_sec hoy_sec dias modo nueva_sec nueva_fecha signo texto

    seleccionar_usuario_numero "RENOVAR / AJUSTAR DÍAS" || return

    usuario="$SELECTED_USER_NAME"
    file="$SELECTED_USER_FILE"

    caduca="$(grep -i '^data:' "$file" 2>/dev/null | head -1 | cut -d':' -f2- | xargs)"
    hoy_sec="$(date +%s)"

    if echo "$caduca" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
        actual_sec="$(date -d "$caduca" +%s 2>/dev/null)"
    else
        actual_sec="$hoy_sec"
        caduca="$(date +%F)"
    fi

    [ -z "$actual_sec" ] && actual_sec="$hoy_sec"

    titulo
    echo -e "${BLANCO}✦ RENOVAR USUARIO ✦${RESET}"
    echo -e "${CYAN}────────────────────────────────────────────────────${RESET}"
    echo -e "${BLANCO}Usuario:${RESET} ${DORADO}$usuario${RESET}"
    echo -e "${BLANCO}Caduca:${RESET}  ${DORADO}$caduca${RESET}"
    echo -e "${CYAN}────────────────────────────────────────────────────${RESET}"
    echo
    echo -e "${DORADO}[01]${RESET} ${BLANCO}Añadir días${RESET}"
    echo -e "${DORADO}[02]${RESET} ${BLANCO}Quitar días${RESET}"
    echo -e "${DORADO}[00]${RESET} ${ROJO}Cancelar${RESET}"
    echo
    read -rp "Seleccione opción: " modo

    case "$modo" in
        1|01) signo="+"; texto="añadidos" ;;
        2|02) signo="-"; texto="quitados" ;;
        0|00) echo "Cancelado."; pause; return ;;
        *) echo -e "${ROJO}Opción inválida.${RESET}"; pause; return ;;
    esac

    read -rp "Cantidad de días: " dias

    if ! echo "$dias" | grep -Eq '^[0-9]+$'; then
        echo -e "${ROJO}Cantidad inválida.${RESET}"
        pause
        return
    fi

    if [ "$signo" = "+" ]; then
        if [ "$actual_sec" -lt "$hoy_sec" ]; then
            actual_sec="$hoy_sec"
        fi
        nueva_sec=$((actual_sec + dias * 86400))
    else
        nueva_sec=$((actual_sec - dias * 86400))
    fi

    nueva_fecha="$(date -d "@$nueva_sec" +%F)"

    chage -E "$nueva_fecha" "$usuario" 2>/dev/null || true

    if grep -qi '^data:' "$file" 2>/dev/null; then
        sed -i "s|^data:.*|data: $nueva_fecha|I" "$file"
    else
        echo "data: $nueva_fecha" >> "$file"
    fi

    echo
    echo -e "${CYAN}────────────────────────────────────────────────────${RESET}"
    echo -e "${BLANCO}Usuario actualizado:${RESET} ${DORADO}$usuario${RESET}"
    echo -e "${BLANCO}Días $texto:${RESET} ${DORADO}$dias${RESET}"
    echo -e "${BLANCO}Nueva expiración:${RESET} ${DORADO}$nueva_fecha${RESET}"
    echo -e "${CYAN}────────────────────────────────────────────────────${RESET}"
    pause
}

menu_usuarios() {
    while true; do
        titulo
        echo -e "${AZUL} GESTIÓN DE USUARIOS${RESET} ${GRIS}──────────────────────────${RESET}"
        echo -e " ${DORADO}[01]${RESET} ${BLANCO}Crear usuario SSH${RESET}"
        echo -e " ${DORADO}[02]${RESET} ${BLANCO}Eliminar usuario por número${RESET}"
        echo -e " ${DORADO}[03]${RESET} ${BLANCO}Renovar usuario / añadir o quitar días${RESET}"
        echo -e " ${DORADO}[00]${RESET} ${ROJO}Volver${RESET}"
        echo
    echo
    # DARKZSAID_FOOTER_COMANDOS_BEGIN
    echo -e "${DORADO}lite${RESET} ${BLANCO}o${RESET} ${DORADO}dzlite${RESET}"
    # DARKZSAID_FOOTER_COMANDOS_END
    echo
        echo -ne "${CYAN}➤${RESET} ${BLANCO}Seleccione una opción:${RESET} ${DORADO} "
        read -r opc_user
        echo -ne "${RESET}"

        case "$opc_user" in
            1|01) crear_usuario ;;
            2|02) eliminar_usuario ;;
            3|03) renovar_usuario ;;
            0|00) return ;;
            *) echo -e "${ROJO}Opción inválida.${RESET}"; sleep 1 ;;
        esac
    done
}

mostrar_usuarios() {
    titulo
    echo -e "${BLANCO}✦ USUARIOS REGISTRADOS ✦${RESET}"
    echo -e "${CYAN}────────────────────────────────────────────────────${RESET}"
    printf "${CYAN}%-4s %-14s %-12s %-6s %-12s %-5s${RESET}\n" "N" "USUARIO" "CLAVE" "LIM" "CADUCA" "DIA"
    echo -e "${CYAN}────────────────────────────────────────────────────${RESET}"

    total=0

    for file in "$USERDIR"/*; do
        [ -f "$file" ] || continue

        usuario="$(basename "$file")"
        clave="$(grep -i '^senha:' "$file" 2>/dev/null | head -1 | cut -d':' -f2- | xargs)"
        limite="$(grep -i '^Limite:' "$file" 2>/dev/null | head -1 | cut -d':' -f2- | xargs)"
        caduca="$(grep -i '^data:' "$file" 2>/dev/null | head -1 | cut -d':' -f2- | xargs)"

        [ -z "$clave" ] && clave="-"
        [ -z "$limite" ] && limite="0"
        [ -z "$caduca" ] && caduca="-"

        dias="-"
        if echo "$caduca" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
            hoy=$(date +%s)
            fin=$(date -d "$caduca" +%s 2>/dev/null)
            dias=$(( (fin - hoy) / 86400 ))
            [ "$dias" -lt 0 ] && dias="0"
        fi

        total=$((total + 1))

        printf "${DORADO}%-4s${RESET} ${MORADO}%-14s${RESET} ${NARANJA}%-12s${RESET} ${DORADO}%-6s${RESET} ${CYAN}%-12s${RESET} ${DORADO}%-5s${RESET}\n" \
        "[$total]" "$usuario" "$clave" "$limite" "$caduca" "$dias"
    done

    echo -e "${CYAN}────────────────────────────────────────────────────${RESET}"
    echo -e "${BLANCO}TOTAL USUARIOS:${RESET} ${DORADO}$total${RESET}"
    pause
}


usuarios_online() {
    titulo
    echo -e "${BLANCO}✦ USUARIOS EN LÍNEA SSH / OPENSSH / WS ✦${RESET}"
    echo -e "${CYAN}────────────────────────────────────────────────────${RESET}"

    echo -ne "${CYAN}PROTOCOLOS ACTIVOS:${RESET} "
    ss -ltnp 2>/dev/null | grep -q ':22' && echo -ne "${DORADO}SSH:22 ${RESET}"
    ss -ltnp 2>/dev/null | grep -q ':443' && echo -ne "${DORADO}SSL:443 ${RESET}"
    ss -ltnp 2>/dev/null | grep -qi 'openssh' && echo -ne "${MORADO}OPENSSH ${RESET}"
    echo

    echo -e "${CYAN}────────────────────────────────────────────────────${RESET}"
    printf "${CYAN}%-16s %-10s %-12s${RESET}\n" "USUARIO" "USO" "TIEMPO"
    echo -e "${CYAN}────────────────────────────────────────────────────${RESET}"

    declare -A CONN
    declare -A LIMITE
    declare -A TIEMPO

    usuario_registrado() {
        local usuario="$1"
        [ -n "$usuario" ] && [ -f "$USERDIR/$usuario" ]
    }

    segundos_a_tiempo() {
        local t="$1"
        local h=$((t/3600))
        local m=$(((t%3600)/60))
        local s=$((t%60))
        printf "%02d:%02d:%02d" "$h" "$m" "$s"
    }

    obtener_limite() {
        local usuario="$1"
        local file="$USERDIR/$usuario"

        if [ -f "$file" ]; then
            local lim
            lim="$(grep -i '^Limite:' "$file" 2>/dev/null | head -1 | cut -d':' -f2- | xargs)"
            [ -n "$lim" ] && echo "$lim" && return
        fi

        echo "0"
    }

    unico_usuario_registrado() {
        local count=0
        local unico=""

        for file in "$USERDIR"/*; do
            [ -f "$file" ] || continue
            unico="$(basename "$file")"
            count=$((count + 1))
        done

        [ "$count" -eq 1 ] && echo "$unico" || echo ""
    }

    sumar_usuario() {
        local usuario="$1"
        local segundos="$2"

        usuario="$(echo "$usuario" | xargs)"

        if ! usuario_registrado "$usuario"; then
            return
        fi

        CONN["$usuario"]=$(( ${CONN["$usuario"]:-0} + 1 ))

        if [ -z "${LIMITE["$usuario"]}" ]; then
            LIMITE["$usuario"]="$(obtener_limite "$usuario")"
        fi

        if [ -z "${TIEMPO["$usuario"]}" ] || [ "$segundos" -gt "${TIEMPO["$usuario"]}" ]; then
            TIEMPO["$usuario"]="$segundos"
        fi
    }

    buscar_hijo_usuario() {
        local parent="$1"
        local frontier="$parent"
        local next=""
        local child=""
        local user=""

        for depth in 1 2 3 4 5 6; do
            next=""

            for pp in $frontier; do
                for child in $(pgrep -P "$pp" 2>/dev/null); do
                    user="$(ps -o user= -p "$child" 2>/dev/null | xargs)"

                    if usuario_registrado "$user"; then
                        echo "$user"
                        return
                    fi

                    next="$next $child"
                done
            done

            frontier="$next"
            [ -z "$frontier" ] && break
        done

        echo ""
    }

    obtener_etime_pid() {
        local pid="$1"
        ps -o etimes= -p "$pid" 2>/dev/null | xargs
    }

    # OpenSSH 22:
    # Solo cuenta usuarios reales registrados.
    # No convierte sesiones root/admin en usuarios VPN.
    ssh_pids="$(ss -tnp state established 2>/dev/null | grep -E '(:22[[:space:]])' | grep -o 'pid=[0-9]*' | cut -d= -f2 | sort -u)"

    for pid in $ssh_pids; do
        args="$(ps -o args= -p "$pid" 2>/dev/null)"
        user="$(echo "$args" | sed -n 's/.*sshd: \([A-Za-z0-9_.-]*\).*/\1/p')"

        if ! usuario_registrado "$user"; then
            user="$(buscar_hijo_usuario "$pid")"
        fi

        if usuario_registrado "$user"; then
            segundos="$(obtener_etime_pid "$pid")"
            [ -z "$segundos" ] && segundos=0
            sumar_usuario "$user" "$segundos"
        fi
    done

    # OpenSSH 22/22:
    # Solo cuenta conexiones TCP ESTABLISHED reales.
    openssh_pids="$(ss -tnp state established 2>/dev/null | grep -E '(:22[[:space:]]|:22[[:space:]])' | grep -o 'pid=[0-9]*' | cut -d= -f2 | sort -u)"

    for pid in $openssh_pids; do
        args="$(ps -o args= -p "$pid" 2>/dev/null)"
        echo "$args" | grep -q "/usr/sbin/openssh" || continue

        user="$(buscar_hijo_usuario "$pid")"

        # Solo en OpenSSH usamos el único usuario registrado como respaldo,
        # porque algunas sesiones no muestran el usuario en ps.
        if ! usuario_registrado "$user"; then
            user="$(unico_usuario_registrado)"
        fi

        if usuario_registrado "$user"; then
            segundos="$(obtener_etime_pid "$pid")"
            [ -z "$segundos" ] && segundos=0
            sumar_usuario "$user" "$segundos"
        fi
    done

    total=0

    if [ "${#CONN[@]}" -eq 0 ]; then
        echo -e "${ROJO}No hay usuarios conectados.${RESET}"
    else
        for usuario in $(printf "%s\n" "${!CONN[@]}" | sort); do
            conexiones="${CONN["$usuario"]}"
            limite="${LIMITE["$usuario"]}"
            tiempo="$(segundos_a_tiempo "${TIEMPO["$usuario"]}")"

            [ -z "$limite" ] && limite="0"

            # Mostrar usuario único, no sockets internos duplicados.
            conexiones_visibles=1
            total=$((total + 1))

            printf "${MORADO}%-16s${RESET} ${DORADO}%-10s${RESET} ${CYAN}%-12s${RESET}\n" "$usuario" "${conexiones_visibles}/${limite}" "$tiempo"
        done
    fi

    echo -e "${CYAN}────────────────────────────────────────────────────${RESET}"
    echo -e "${BLANCO}TOTAL CONECTADOS:${RESET} ${DORADO}$total${RESET}"
    pause
}


estado_puertos() {
    titulo

    linea="${CYAN}════════════════════════════════════════════════════${RESET}"

    puerto_on() {
        local puerto="$1"
        ss -ltn 2>/dev/null | awk '{print $4}' | grep -Eq "(:|\\])${puerto}$"
    }

    imprimir_fila() {
        local puerto="$1"
        local servicio="$2"
        local destino="$3"
        local estado="${OFFCOLOR}[OFF]${RESET}"

        if puerto_on "$puerto"; then
            estado="${ONCOLOR}[ON]${RESET}"
        fi

        printf " ${DORADO}%-8s${RESET} ${MORADO}%-15s${RESET} ${NARANJA}%-22s${RESET} %b\n" "$puerto" "$servicio" "$destino" "$estado"
    }

    echo -e "$linea"
    echo -e "${BLANCO}             ✦ ESTADO PREMIUM DE PUERTOS ✦${RESET}"
    echo -e "$linea"
    echo
    printf " ${CYAN}%-8s${RESET} ${CYAN}%-15s${RESET} ${CYAN}%-22s${RESET} ${CYAN}%s${RESET}\n" "PUERTO" "SERVICIO" "DESTINO" "ESTADO"
    echo -e "${CYAN}────────────────────────────────────────────────────${RESET}"

    imprimir_fila "22"   "OpenSSH"     "SSH directo"
    imprimir_fila "22"  "OpenSSH"    "OpenSSH directo"
    imprimir_fila "22"  "OpenSSH"    "OpenSSH directo"
    imprimir_fila "443"  "SSL/Stunnel" "443 -> WS 80"
    imprimir_fila "80"   "WS OpenSSH" "80 -> OpenSSH 22"
    imprimir_fila "8084" "WS OpenSSH" "8084 -> OpenSSH 22"
    imprimir_fila "8086" "WS OpenSSH" "8086 -> OpenSSH 22"
    imprimir_fila "90"   "WS SSH"      "90 -> OpenSSH 22"
    imprimir_fila "8080" "WS SSH"      "8080 -> OpenSSH 22"
    imprimir_fila "8082" "WS SSH"      "8082 -> OpenSSH 22"

    echo -e "$linea"
    echo
    echo -e "${BLANCO}Resumen:${RESET}"

    total_on=0
    total_off=0

    for puerto in 22 443 80 8084 8086 90 8080 8082; do
        if puerto_on "$puerto"; then
            total_on=$((total_on + 1))
        else
            total_off=$((total_off + 1))
        fi
    done

    echo -e " ${BLANCO}Puertos encendidos:${RESET} ${ONCOLOR}[$total_on]${RESET}"
    echo -e " ${BLANCO}Puertos apagados:${RESET}   ${OFFCOLOR}[$total_off]${RESET}"
    echo
    pause
}


reiniciar_servicios() {
    titulo
    echo -e "${AMARILLO}Reiniciando servicios...${RESET}"

    systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true
    systemctl restart openssh 2>/dev/null || true
    systemctl restart stunnel4 2>/dev/null || true

    for PORT in $WS_PORTS; do
        systemctl restart "darkzsaid-lite-ws-${PORT}" 2>/dev/null || true
    done

    echo -e "${VERDE}Servicios reiniciados.${RESET}"
    pause
}

apagar_puertos() {
    titulo
    echo -e "${AMARILLO}Apagando puertos del protocolo...${RESET}"
    echo

    for PORT in $WS_PORTS; do
        systemctl stop "darkzsaid-lite-ws-${PORT}" 2>/dev/null || true
        echo "WS $PORT apagado"
    done

    systemctl stop stunnel4 2>/dev/null || true
    echo "SSL 443 apagado"

    systemctl stop openssh 2>/dev/null || true
    echo "OpenSSH 22/22 apagado"

    echo
    echo -e "${VERDE}Puertos apagados.${RESET}"
    echo -e "${AMARILLO}SSH 22 queda activo para no perder conexión.${RESET}"
    pause
}

encender_puertos() {
    titulo
    echo -e "${AMARILLO}Encendiendo puertos del protocolo...${RESET}"
    echo

    systemctl start openssh 2>/dev/null || systemctl restart openssh 2>/dev/null || true
    systemctl start stunnel4 2>/dev/null || systemctl restart stunnel4 2>/dev/null || true

    for PORT in $WS_PORTS; do
        systemctl start "darkzsaid-lite-ws-${PORT}" 2>/dev/null || systemctl restart "darkzsaid-lite-ws-${PORT}" 2>/dev/null || true
        echo "WS $PORT encendido"
    done

    echo
    echo -e "${VERDE}Puertos encendidos.${RESET}"
    pause
}


abrir_panel_real_ws() {
    titulo
    echo -e "${AMARILLO}Abriendo panel real SSH WS de DarkZsaid...${RESET}"
    echo

    if [ -f "/opt/darkzsaid/menus/ssh_ws_puro_menu.sh" ]; then
        bash /opt/darkzsaid/menus/ssh_ws_puro_menu.sh
    else
        echo -e "${ROJO}No existe el panel real SSH WS:${RESET}"
        echo "/opt/darkzsaid/menus/ssh_ws_puro_menu.sh"
        echo
        echo "Primero instala o clona DarkZsaid en /opt/darkzsaid"
        pause
    fi
}


while true; do
    titulo
    echo -e "${AZUL} MENÚ PRINCIPAL${RESET} ${GRIS}──────────────────────────────${RESET}"
    echo -e " ${DORADO}[01]${RESET} ${BLANCO}Abrir panel real SSH WS${RESET}"
    echo -e " ${DORADO}[02]${RESET} ${BLANCO}Gestionar usuarios SSH${RESET}"
    echo -e " ${DORADO}[03]${RESET} ${BLANCO}Mostrar usuarios registrados${RESET}"
    echo -e " ${DORADO}[04]${RESET} ${BLANCO}Ver usuarios en línea${RESET}"
    echo -e " ${DORADO}[05]${RESET} ${BLANCO}Reiniciar servicios${RESET}"
        echo -e " ${DORADO}[06]${RESET} ${BLANCO}Bot Telegram${RESET}"

    echo -e " ${DORADO}[00]${RESET} ${ROJO}Salir${RESET}"
        echo
        echo -e " ${GRIS}────────────────────────────────────────────${RESET}"
        echo -e " ${BLANCO}Comando para abrir este panel:${RESET} ${DORADO}lite${RESET} ${BLANCO}o${RESET} ${DORADO}dzlite${RESET}"
        echo -e " ${GRIS}────────────────────────────────────────────${RESET}"
    echo
    echo; echo -ne "${CYAN}➤${RESET} ${BLANCO}Seleccione una opción:${RESET} ${DORADO} "; read -r opc; echo -ne "${RESET}"

    case "$opc" in
        1|01) instalar_protocolo ;;
        2|02) menu_usuarios ;;
        3|03) mostrar_usuarios ;;
        4|04) usuarios_online ;;
        5|05) reiniciar_servicios ;;
        6|06) bash /opt/darkzsaid/menus/bot_telegram_lite_menu.sh ;;
        0|00) clear; exit 0 ;;
        *) echo "Opción inválida"; sleep 1 ;;
    esac
done
