#!/usr/bin/env bash

INSTALL_LOG="/var/log/darkzsaid-panelito-install.log"

log_install() {
    echo "$*" >> "$INSTALL_LOG" 2>/dev/null || true
}

run_silent() {
    "$@" >> "$INSTALL_LOG" 2>&1
}
