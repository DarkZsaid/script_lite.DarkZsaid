#!/usr/bin/env bash

USERDIR="/etc/adm-lite/userDIR"
DELETED_DIR="/etc/adm-lite/userDIR_eliminados"
mkdir -p "$USERDIR" "$DELETED_DIR"

get_field() {
    local file="$1"
    local key="$2"
    grep -i "^${key}:" "$file" 2>/dev/null | head -1 | cut -d':' -f2- | xargs
}

set_field() {
    local file="$1"
    local key="$2"
    local value="$3"

    if grep -qi "^${key}:" "$file" 2>/dev/null; then
        sed -i "s|^${key}:.*|${key}: ${value}|I" "$file"
    else
        echo "${key}: ${value}" >> "$file"
    fi
}

quota_mb() {
    local file="$1"
    local consumo unidad

    consumo="$(get_field "$file" Consumo)"
    unidad="$(get_field "$file" Unidad)"

    [ -z "$consumo" ] && consumo="0"
    [ -z "$unidad" ] && unidad="GB"

    unidad="$(echo "$unidad" | tr '[:lower:]' '[:upper:]')"

    case "$unidad" in
        MB) echo "$consumo" ;;
        GB) echo $((consumo * 1024)) ;;
        *) echo "0" ;;
    esac
}

mark_user() {
    local uid="$1"
    echo $((200000 + uid))
}

tag_base() {
    local user="$1"
    local uid="$2"
    echo "DZQ2:${user}:${uid}"
}

remove_old_rules() {
    local user="$1"
    local uid="$2"
    local mark="$3"
    local oldtag="DZQ:${user}:${uid}"
    local tag
    tag="$(tag_base "$user" "$uid")"

    while iptables -D OUTPUT -m owner --uid-owner "$uid" -m comment --comment "$oldtag" 2>/dev/null; do :; done

    while iptables -t mangle -D OUTPUT -m owner --uid-owner "$uid" -m connmark --mark 0 -m comment --comment "${tag}:SET" -j CONNMARK --set-mark "$mark" 2>/dev/null; do :; done
    while iptables -t mangle -D OUTPUT -m connmark --mark "$mark" -m comment --comment "${tag}:OUT" 2>/dev/null; do :; done
    while iptables -t mangle -D INPUT -m connmark --mark "$mark" -m comment --comment "${tag}:IN" 2>/dev/null; do :; done
}

ensure_rules() {
    local user="$1"

    id "$user" >/dev/null 2>&1 || return 1

    local uid mark tag
    uid="$(id -u "$user")"
    mark="$(mark_user "$uid")"
    tag="$(tag_base "$user" "$uid")"

    # Marca las conexiones creadas por el usuario.
    iptables -t mangle -C OUTPUT -m owner --uid-owner "$uid" -m connmark --mark 0 -m comment --comment "${tag}:SET" -j CONNMARK --set-mark "$mark" 2>/dev/null || \
    iptables -t mangle -A OUTPUT -m owner --uid-owner "$uid" -m connmark --mark 0 -m comment --comment "${tag}:SET" -j CONNMARK --set-mark "$mark"

    # Cuenta bajada/salida hacia el cliente o destinos.
    iptables -t mangle -C OUTPUT -m connmark --mark "$mark" -m comment --comment "${tag}:OUT" 2>/dev/null || \
    iptables -t mangle -A OUTPUT -m connmark --mark "$mark" -m comment --comment "${tag}:OUT"

    # Cuenta entrada/respuesta de internet.
    iptables -t mangle -C INPUT -m connmark --mark "$mark" -m comment --comment "${tag}:IN" 2>/dev/null || \
    iptables -t mangle -A INPUT -m connmark --mark "$mark" -m comment --comment "${tag}:IN"

    echo "$uid|$mark|$tag"
}

current_bytes() {
    local tag="$1"

    iptables-save -c -t mangle 2>/dev/null | awk -v tag="$tag" '
    index($0, tag ":OUT") > 0 || index($0, tag ":IN") > 0 {
        field=$1
        gsub(/\[/, "", field)
        gsub(/\]/, "", field)
        split(field, a, ":")
        bytes += a[2]
    }
    END {
        print bytes + 0
    }'
}

setup_user() {
    local user="$1"
    local file="$USERDIR/$user"

    [ -f "$file" ] || return 1
    id "$user" >/dev/null 2>&1 || return 1

    local data uid mark tag bytes
    data="$(ensure_rules "$user")"
    uid="$(echo "$data" | cut -d'|' -f1)"
    mark="$(echo "$data" | cut -d'|' -f2)"
    tag="$(echo "$data" | cut -d'|' -f3)"

    bytes="$(current_bytes "$tag")"

    set_field "$file" QuotaUID "$uid"
    set_field "$file" QuotaMark "$mark"
    set_field "$file" QuotaBaseBytes "$bytes"
    set_field "$file" UsadoMB "0"
    set_field "$file" Estado "ACTIVO"
}

delete_user_limit() {
    local user="$1"
    local file="$USERDIR/$user"
    local uid="$2"
    local mark="$3"

    mkdir -p "$DELETED_DIR"

    pkill -u "$user" 2>/dev/null || true
    pkill -f "sshd: $user" 2>/dev/null || true

    remove_old_rules "$user" "$uid" "$mark"

    if [ -f "$file" ]; then
        set_field "$file" Estado "ELIMINADO_POR_CONSUMO"
        mv "$file" "$DELETED_DIR/${user}_eliminado_$(date +%F_%H-%M-%S)" 2>/dev/null || true
    fi

    userdel -f "$user" 2>/dev/null || true
}

check_user() {
    local user="$1"
    local quiet="$2"
    local file="$USERDIR/$user"

    [ -f "$file" ] || return 0
    id "$user" >/dev/null 2>&1 || return 0

    local data uid mark tag base bytes used usedmb limitmb limitbytes
    data="$(ensure_rules "$user")"

    uid="$(echo "$data" | cut -d'|' -f1)"
    mark="$(echo "$data" | cut -d'|' -f2)"
    tag="$(echo "$data" | cut -d'|' -f3)"

    base="$(get_field "$file" QuotaBaseBytes)"
    [ -z "$base" ] && base="$(current_bytes "$tag")" && set_field "$file" QuotaBaseBytes "$base"

    bytes="$(current_bytes "$tag")"
    used=$((bytes - base))

    if [ "$used" -lt 0 ]; then
        base="$bytes"
        used=0
        set_field "$file" QuotaBaseBytes "$base"
    fi

    usedmb=$((used / 1024 / 1024))

    set_field "$file" UsadoMB "$usedmb"
    set_field "$file" QuotaUID "$uid"
    set_field "$file" QuotaMark "$mark"

    limitmb="$(quota_mb "$file")"
    limitbytes=$((limitmb * 1024 * 1024))

    if [ "$limitmb" -gt 0 ] && [ "$used" -ge "$limitbytes" ]; then
        [ "$quiet" != "--quiet" ] && echo "Eliminando $user por consumo: ${usedmb}MB / ${limitmb}MB"
        delete_user_limit "$user" "$uid" "$mark"
    else
        [ "$quiet" != "--quiet" ] && echo "$user: ${usedmb}MB / ${limitmb}MB"
    fi
}

case "$1" in
    --setup)
        setup_user "$2"
    ;;
    --user)
        check_user "$2" "$3"
    ;;
    --all)
        for file in "$USERDIR"/*; do
            [ -f "$file" ] || continue
            user="$(basename "$file")"
            check_user "$user" "--quiet"
        done
    ;;
    --all-setup)
        for file in "$USERDIR"/*; do
            [ -f "$file" ] || continue
            user="$(basename "$file")"
            setup_user "$user"
        done
    ;;
    *)
        echo "Uso:"
        echo "  darkzsaid_quota_check.sh --setup usuario"
        echo "  darkzsaid_quota_check.sh --user usuario"
        echo "  darkzsaid_quota_check.sh --all"
    ;;
esac
