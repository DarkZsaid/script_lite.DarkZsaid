#!/bin/bash

PROXY="/opt/darkzsaid/protocolos_hostpa/proxy_status_200.py"
PIDDIR="/var/run/darkzsaid_ssh_ws_puro"
PORTS="80 90 8080 8082 8084 8086"

for p in $PORTS; do
  if [ -f "$PIDDIR/$p.pid" ]; then
    PID="$(cat "$PIDDIR/$p.pid" 2>/dev/null)"
    [ -n "$PID" ] && kill "$PID" 2>/dev/null || true
    sleep 0.2
    [ -n "$PID" ] && kill -9 "$PID" 2>/dev/null || true
    rm -f "$PIDDIR/$p.pid"
  fi
  pkill -f "$PROXY $p" 2>/dev/null || true
done

echo "SSH WS PURO detenido."
