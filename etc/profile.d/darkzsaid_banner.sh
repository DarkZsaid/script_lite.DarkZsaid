#!/usr/bin/env bash
if [ "$(id -u)" != "0" ] && [ -z "$DARKZSAID_BANNER_SHOWN" ]; then
    export DARKZSAID_BANNER_SHOWN=1
    [ -x /opt/darkzsaid/menus/banner_conexion.sh ] && /opt/darkzsaid/menus/banner_conexion.sh 2>/dev/null || true
fi
