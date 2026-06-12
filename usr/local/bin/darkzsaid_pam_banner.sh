#!/usr/bin/env bash

USERDIR="/etc/adm-lite/userDIR"
U="${PAM_USER:-$USER}"
USERFILE="$USERDIR/$U"

[ "$U" = "root" ] && exit 0
[ ! -f "$USERFILE" ] && exit 0

/usr/local/bin/darkzsaid_quota_check.sh --user "$U" --quiet >/dev/null 2>&1 || true

get_field() {
    grep -i "^$1:" "$USERFILE" 2>/dev/null | head -1 | cut -d':' -f2- | xargs
}

format_used() {
    local usado_mb="$1"

    if [ -z "$usado_mb" ]; then
        echo "0 MB"
        return
    fi

    if [ "$usado_mb" -ge 1024 ] 2>/dev/null; then
        awk -v mb="$usado_mb" 'BEGIN { printf "%.2f GB", mb/1024 }'
    else
        echo "${usado_mb} MB"
    fi
}

usuario="$U"
expira="$(get_field data)"
max_conex="$(get_field Limite)"
limite_consumo="$(get_field Consumo)"
unidad="$(get_field Unidad)"
usado_mb="$(get_field UsadoMB)"

[ -z "$max_conex" ] && max_conex="0"
[ -z "$limite_consumo" ] && limite_consumo="0"
[ -z "$unidad" ] && unidad="GB"
[ -z "$usado_mb" ] && usado_mb="0"

unidad="$(echo "$unidad" | tr '[:lower:]' '[:upper:]')"

dias="-"
if echo "$expira" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
    hoy=$(date +%s)
    fin=$(date -d "$expira" +%s 2>/dev/null)
    dias=$(( (fin - hoy) / 86400 ))
    [ "$dias" -lt 0 ] && dias="0"
fi

velocidad="Sin límite"
consumo_actual="$(format_used "$usado_mb")"
if [ "$limite_consumo" = "0" ]; then
    limite_final="Ilimitado"
else
    limite_final="${limite_consumo} ${unidad}"
fi

# Para el banner de login mostramos mínimo 1 conexión,
# porque si el usuario está viendo el banner, ya autenticó.
conex="1"

cat <<HTML
<font color="#ff0000">[·] ━━━━━━ </font><font color="#ffaa00"><b>I N F O R M A C I Ó N</b></font><font color="#ff0000"> ━━━━━━</font><br>
<br>
<font color="#ffaa00"><b>» Usuario : </b></font><font color="#00eaff">${usuario}</font><br>
<font color="#ffaa00"><b>» Expiración : </b></font><font color="#00eaff">${expira}</font><br>
<font color="#ffaa00"><b>» Duración : </b></font><font color="#00eaff">${dias} días</font><br>
<font color="#ffaa00"><b>» Velocidad : </b></font><font color="#00eaff">${velocidad}</font><br>
<font color="#ffaa00"><b>» Consumo : </b></font><font color="#00eaff">${consumo_actual} / ${limite_final}</font><br>
<font color="#ffaa00"><b>» Conexiones : </b></font><font color="#00eaff">${conex} / ${max_conex}</font><br>
<br>
<font color="#ff0000">[·] ━━━━━━ / / / ━━━━━━</font><br>
<br>
<div style="text-align: center;">
<font color="#ffaa00"><b>DarkZsaid</b></font>
</div>
HTML

exit 0
