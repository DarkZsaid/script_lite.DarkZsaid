#!/bin/bash

PROXY="/opt/darkzsaid/protocolos_hostpa/proxy_status_200.py"
PIDDIR="/var/run/darkzsaid_ssh_ws_puro"
LOGDIR="/var/log/darkzsaid_ssh_ws_puro"
PORTS="80 90 8080 8082 8084 8086"

mkdir -p "$PIDDIR" "$LOGDIR"

abrir_firewall() {
  for p in $PORTS; do
    iptables -C INPUT -p tcp --dport "$p" -j ACCEPT 2>/dev/null || iptables -I INPUT -p tcp --dport "$p" -j ACCEPT 2>/dev/null || true
  done
}

stop_port() {
  p="$1"
  if [ -f "$PIDDIR/$p.pid" ]; then
    PID="$(cat "$PIDDIR/$p.pid" 2>/dev/null)"
    [ -n "$PID" ] && kill "$PID" 2>/dev/null || true
    sleep 0.2
    [ -n "$PID" ] && kill -9 "$PID" 2>/dev/null || true
    rm -f "$PIDDIR/$p.pid"
  fi
  pkill -f "$PROXY $p" 2>/dev/null || true
}

start_port() {
  p="$1"

  if ss -tulnp 2>/dev/null | grep -q ":$p "; then
    echo "Puerto $p ya ocupado:"
    ss -tulnp 2>/dev/null | grep ":$p " | head -1
    return
  fi

  nohup python3 "$PROXY" "$p" > "$LOGDIR/ws_$p.log" 2>&1 &
  echo $! > "$PIDDIR/$p.pid"
  sleep 0.5

  if ss -tulnp 2>/dev/null | grep -q ":$p "; then
    PID="$(cat "$PIDDIR/$p.pid" 2>/dev/null)"
    echo "Puerto $p: ACTIVO PID $PID"
  else
    echo "Puerto $p: ERROR"
    cat "$LOGDIR/ws_$p.log" 2>/dev/null | tail -5
  fi
}

abrir_firewall

for p in $PORTS; do
  stop_port "$p"
done

sleep 1

for p in $PORTS; do
  start_port "$p"
done
