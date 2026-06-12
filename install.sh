#!/usr/bin/env bash
set -Eeuo pipefail

LOG="/var/log/darkzsaid-panelito-install.log"
: > "$LOG"

RESET="\033[0m"
BLANCO="\033[1;37m"
CYAN="\033[1;36m"
DORADO="\033[1;33m"
VERDE="\033[1;32m"
ROJO="\033[1;31m"

trap 'echo -e "\n${ROJO}ERROR instalando.${RESET}"; echo "Log: $LOG"; tail -50 "$LOG"; exit 1' ERR

paso() {
    echo -e "${CYAN}◆${RESET} ${BLANCO}$1${RESET}"
}

ok() {
    echo -e "${VERDE}✓${RESET} $1"
    echo
}

clear
echo -e "${CYAN}╔════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║${RESET}       ${BLANCO}DARKZSAID LITE PREMIUM${RESET}           ${CYAN}║${RESET}"
echo -e "${CYAN}║${RESET}          ${DORADO}SSH • WS • SSL${RESET}                 ${CYAN}║${RESET}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${RESET}"
echo

[ "$(id -u)" = "0" ] || { echo "Ejecuta como root"; exit 1; }

paso "Instalando dependencias"
apt update -y >>"$LOG" 2>&1
apt install -y python3 python3-pip python3-venv openssh-server dropbear stunnel4 openssl curl wget git net-tools iproute2 iptables >>"$LOG" 2>&1
ok "Dependencias instaladas"

paso "Instalando panelito"
rm -rf /opt/darkzsaid
mkdir -p /opt
cp -a opt/darkzsaid /opt/darkzsaid
chmod -R +x /opt/darkzsaid 2>/dev/null || true

mkdir -p /etc/adm-lite/userDIR
mkdir -p /etc/adm-lite/userDIR_eliminados
ok "Panelito instalado"

paso "Instalando banner SSH"
mkdir -p /etc/ssh /etc/profile.d

[ -f etc/ssh/sshrc ] && cp -f etc/ssh/sshrc /etc/ssh/sshrc
[ -f etc/profile.d/darkzsaid_banner.sh ] && cp -f etc/profile.d/darkzsaid_banner.sh /etc/profile.d/darkzsaid_banner.sh

chmod +x /etc/ssh/sshrc 2>/dev/null || true
chmod +x /etc/profile.d/darkzsaid_banner.sh 2>/dev/null || true

sed -i 's/^#\?PrintMotd .*/PrintMotd no/' /etc/ssh/sshd_config 2>/dev/null || true
sed -i 's/^#\?PrintLastLog .*/PrintLastLog no/' /etc/ssh/sshd_config 2>/dev/null || true
grep -q '^PrintMotd no' /etc/ssh/sshd_config || echo 'PrintMotd no' >> /etc/ssh/sshd_config
grep -q '^PrintLastLog no' /etc/ssh/sshd_config || echo 'PrintLastLog no' >> /etc/ssh/sshd_config
ok "Banner SSH instalado"


paso "Configurando Dropbear 109"
mkdir -p /etc/dropbear

# Ubuntu/Debian usan /etc/default/dropbear
cat > /etc/default/dropbear <<'DROPBEARCONF'
NO_START=0
DROPBEAR_PORT=109
DROPBEAR_EXTRA_ARGS="-p 109"
DROPBEAR_BANNER=""
DROPBEAR_RECEIVE_WINDOW=65536
DROPBEARCONF

systemctl enable dropbear >>"$LOG" 2>&1 || true
systemctl restart dropbear >>"$LOG" 2>&1 || true

ok "Dropbear 109 configurado"

paso "Configurando SSL 443 hacia WS 80"
mkdir -p /etc/stunnel

openssl req -new -x509 -days 3650 -nodes \
  -out /etc/stunnel/stunnel.pem \
  -keyout /etc/stunnel/stunnel.pem \
  -subj "/C=US/ST=DarkZsaid/L=DarkZsaid/O=DarkZsaid/OU=Lite/CN=darkzsaid.local" >>"$LOG" 2>&1

chmod 600 /etc/stunnel/stunnel.pem

cat > /etc/stunnel/stunnel.conf <<'STUNNELCONF'
pid = /var/run/stunnel4/stunnel.pid
cert = /etc/stunnel/stunnel.pem
client = no
foreground = no

[sshws]
accept = 0.0.0.0:443
connect = 127.0.0.1:80
STUNNELCONF

sed -i 's/^ENABLED=.*/ENABLED=1/' /etc/default/stunnel4 2>/dev/null || true
grep -q '^ENABLED=1' /etc/default/stunnel4 2>/dev/null || echo 'ENABLED=1' >> /etc/default/stunnel4
systemctl enable stunnel4 >>"$LOG" 2>&1 || true
ok "SSL 443 configurado"



paso "Instalando Server Message real"
mkdir -p /usr/local/bin

cp -f usr/local/bin/darkzsaid_pam_banner.sh /usr/local/bin/darkzsaid_pam_banner.sh
cp -f usr/local/bin/darkzsaid_banner.sh /usr/local/bin/darkzsaid_banner.sh
cp -f usr/local/bin/darkzsaid_quota_check.sh /usr/local/bin/darkzsaid_quota_check.sh

chmod +x /usr/local/bin/darkzsaid_pam_banner.sh
chmod +x /usr/local/bin/darkzsaid_banner.sh
chmod +x /usr/local/bin/darkzsaid_quota_check.sh

# Limpiar pruebas viejas del banner
rm -f /usr/local/bin/darkzsaid_pam_test.sh /usr/local/bin/darkzsaid_generate_message.sh 2>/dev/null || true

# Limpiar intentos anteriores en PAM
sed -i '/# DARKZSAID_AUTH_BANNER_BEGIN/,/# DARKZSAID_AUTH_BANNER_END/d' /etc/pam.d/sshd 2>/dev/null || true
sed -i '/darkzsaid_pam_banner.sh/d' /etc/pam.d/sshd 2>/dev/null || true
sed -i '/darkzsaid_pam_test.sh/d' /etc/pam.d/sshd 2>/dev/null || true
sed -i '/darkzsaid_generate_message.sh/d' /etc/pam.d/sshd 2>/dev/null || true
sed -i '/banner_auth.sh/d' /etc/pam.d/sshd 2>/dev/null || true

# Dejar PAM igual que la VPS buena Ubuntu 24:
# @include common-account
# account optional pam_exec.so stdout /usr/local/bin/darkzsaid_pam_banner.sh
# @include common-session
python3 - <<'PAMPY'
from pathlib import Path

pam = Path("/etc/pam.d/sshd")
txt = pam.read_text()

linea = "account optional pam_exec.so stdout /usr/local/bin/darkzsaid_pam_banner.sh"

if linea not in txt:
    if "@include common-account" not in txt:
        raise SystemExit("ERROR: no encontré @include common-account en /etc/pam.d/sshd")
    txt = txt.replace("@include common-account", "@include common-account\n" + linea, 1)

pam.write_text(txt)
PAMPY

# SSH igual que la VPS buena
sed -i 's/^#\?UsePAM .*/UsePAM yes/' /etc/ssh/sshd_config 2>/dev/null || true
sed -i 's/^#\?PrintMotd .*/PrintMotd no/' /etc/ssh/sshd_config 2>/dev/null || true
sed -i 's/^#\?PrintLastLog .*/PrintLastLog yes/' /etc/ssh/sshd_config 2>/dev/null || true
sed -i 's/^#\?Banner .*/Banner none/' /etc/ssh/sshd_config 2>/dev/null || true

grep -q '^UsePAM yes' /etc/ssh/sshd_config || echo 'UsePAM yes' >> /etc/ssh/sshd_config
grep -q '^PrintMotd no' /etc/ssh/sshd_config || echo 'PrintMotd no' >> /etc/ssh/sshd_config
grep -q '^PrintLastLog yes' /etc/ssh/sshd_config || echo 'PrintLastLog yes' >> /etc/ssh/sshd_config
grep -q '^Banner none' /etc/ssh/sshd_config || echo 'Banner none' >> /etc/ssh/sshd_config

ok "Server Message real instalado"
echo

paso "Instalando bot Telegram"
rm -rf /opt/darkzsaid-lite-bot
mkdir -p /opt/darkzsaid-lite-bot
cp -a opt/darkzsaid-lite-bot/* /opt/darkzsaid-lite-bot/

if [ ! -f /opt/darkzsaid-lite-bot/config.json ]; then
    cp -f /opt/darkzsaid-lite-bot/config.example.json /opt/darkzsaid-lite-bot/config.json
    chmod 600 /opt/darkzsaid-lite-bot/config.json
fi

python3 -m venv /opt/darkzsaid-lite-bot/venv >>"$LOG" 2>&1

if [ -f /opt/darkzsaid-lite-bot/requirements.txt ]; then
    /opt/darkzsaid-lite-bot/venv/bin/pip install --upgrade pip >>"$LOG" 2>&1
    /opt/darkzsaid-lite-bot/venv/bin/pip install -r /opt/darkzsaid-lite-bot/requirements.txt >>"$LOG" 2>&1
fi

cat > /etc/systemd/system/darkzsaid-lite-bot.service <<SERVICE
[Unit]
Description=DarkZsaid Lite Telegram Bot
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/darkzsaid-lite-bot
ExecStart=/opt/darkzsaid-lite-bot/venv/bin/python /opt/darkzsaid-lite-bot/bot.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload >>"$LOG" 2>&1
systemctl enable darkzsaid-lite-bot >>"$LOG" 2>&1 || true
ok "Bot Telegram instalado"

paso "Creando comandos lite y dzlite"
cat > /usr/local/bin/lite <<'CMD'
#!/usr/bin/env bash
bash /opt/darkzsaid/darkzsaid_lite.sh
CMD

chmod +x /usr/local/bin/lite
cp -f /usr/local/bin/lite /usr/local/bin/dzlite
chmod +x /usr/local/bin/dzlite
ok "Comandos creados"

paso "Configurando autoinicio del panel"
sed -i '/# DARKZSAID_LITE_AUTO_START_BEGIN/,/# DARKZSAID_LITE_AUTO_START_END/d' /root/.bashrc 2>/dev/null || true

cat >> /root/.bashrc <<'AUTOSTART'

# DARKZSAID_LITE_AUTO_START_BEGIN
if [ -t 1 ] && [ -n "$SSH_CONNECTION" ] && [ -z "$DARKZSAID_LITE_OPENED" ]; then
    export DARKZSAID_LITE_OPENED=1
    if command -v lite >/dev/null 2>&1; then
        lite
    fi
fi
# DARKZSAID_LITE_AUTO_START_END
AUTOSTART
ok "Autoinicio configurado"

paso "Validando instalación"
bash -n /opt/darkzsaid/darkzsaid_lite.sh
find /opt/darkzsaid -type f -name "*.sh" -exec bash -n {} \; >>"$LOG" 2>&1 || true
find /opt/darkzsaid -type f -name "*.py" -exec python3 -m py_compile {} \; >>"$LOG" 2>&1 || true
python3 -m py_compile /opt/darkzsaid-lite-bot/bot.py >>"$LOG" 2>&1 || true
sshd -t
ok "Validación correcta"

paso "Reiniciando servicios"
systemctl enable ssh >>"$LOG" 2>&1 || systemctl enable sshd >>"$LOG" 2>&1 || true
systemctl restart ssh >>"$LOG" 2>&1 || systemctl restart sshd >>"$LOG" 2>&1 || true
systemctl restart stunnel4 >>"$LOG" 2>&1 || true
systemctl restart darkzsaid-lite-bot >>"$LOG" 2>&1 || true

if [ -x /opt/darkzsaid/bin/ssh_ws_puro_start.sh ]; then
    bash /opt/darkzsaid/bin/ssh_ws_puro_start.sh >>"$LOG" 2>&1 || true
fi

ok "Servicios reiniciados"

echo -e "${VERDE}INSTALACIÓN TERMINADA.${RESET}"
echo -e "Abrir panel: ${DORADO}lite${RESET} o ${DORADO}dzlite${RESET}"
echo "Log: $LOG"
