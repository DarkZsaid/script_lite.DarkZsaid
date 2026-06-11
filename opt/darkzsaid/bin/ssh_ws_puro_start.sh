#!/bin/bash
# DarkZsaid - lanzador SSH WS PURO
# La instalación real está separada en core/install_ssh_ws_puro_motor.sh

MOTOR="/opt/darkzsaid/core/install_ssh_ws_puro_motor.sh"

if [[ ! -f "$MOTOR" ]]; then
    echo "No existe el motor: $MOTOR"
    exit 1
fi

bash "$MOTOR"
