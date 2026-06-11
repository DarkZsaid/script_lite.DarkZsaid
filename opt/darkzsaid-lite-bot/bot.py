#!/usr/bin/env python3
import os
import re
import json
import glob
import time
import html
import shutil
import urllib.parse
import urllib.request
import subprocess
import threading
from datetime import datetime, timedelta

BASE = "/opt/darkzsaid-lite-bot"
CONFIG = f"{BASE}/config.json"
USERDIR = "/etc/adm-lite/userDIR"
DELETED_DIR = "/etc/adm-lite/userDIR_eliminados"
QUOTA = "/usr/local/bin/darkzsaid_quota_check.sh"
AUTO_DELETE_SECONDS = 80

os.makedirs(BASE, exist_ok=True)
os.makedirs(USERDIR, exist_ok=True)
os.makedirs(DELETED_DIR, exist_ok=True)

states = {}

DEFAULT_CONFIG = {
    "token": "",
    "admin_id": 0,
    "admin_username": "@DarkZsaid",
    "authorized": {}
}

def esc(x):
    return html.escape(str(x))

def run(cmd, input_text=None, timeout=20):
    try:
        p = subprocess.run(
            cmd,
            input=input_text,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout
        )
        return p.returncode, p.stdout.strip(), p.stderr.strip()
    except Exception as e:
        return 1, "", str(e)

def load_config():
    if not os.path.exists(CONFIG):
        save_config(DEFAULT_CONFIG)

    try:
        with open(CONFIG, "r") as f:
            cfg = json.load(f)
    except Exception:
        cfg = DEFAULT_CONFIG.copy()

    for key, value in DEFAULT_CONFIG.items():
        cfg.setdefault(key, value)

    cfg.setdefault("authorized", {})
    return cfg

def save_config(cfg):
    tmp = CONFIG + ".tmp"
    with open(tmp, "w") as f:
        json.dump(cfg, f, indent=2)
    os.replace(tmp, CONFIG)
    os.chmod(CONFIG, 0o600)

def api(method, data=None):
    cfg = load_config()
    token = cfg.get("token", "")

    if not token:
        raise RuntimeError("Token vacío")

    url = f"https://api.telegram.org/bot{token}/{method}"
    payload = urllib.parse.urlencode(data or {}).encode()

    req = urllib.request.Request(url, payload)

    with urllib.request.urlopen(req, timeout=70) as r:
        return json.loads(r.read().decode())

def register_bot_commands():
    commands = [
        {"command": "menu", "description": "Abrir panel principal"},
        {"command": "crear", "description": "Crear usuario SSH"},
        {"command": "usuarios", "description": "Ver usuarios registrados"},
        {"command": "online", "description": "Ver usuarios conectados"},
        {"command": "eliminar", "description": "Eliminar usuario"},
        {"command": "puertos", "description": "Ver puertos activos"}
    ]

    try:
        api("setMyCommands", {"commands": json.dumps(commands)})
    except Exception as e:
        print("setMyCommands error:", repr(e), flush=True)

def should_keep_message(text):
    text = str(text)
    keep_words = [
        "MENÚ PRINCIPAL",
        "MENU PRINCIPAL",
        "ACCESO RESTRINGIDO"
    ]

    for word in keep_words:
        if word in text:
            return True

    return False

def delete_message(chat_id, message_id):
    if not message_id:
        return

    try:
        api("deleteMessage", {
            "chat_id": str(chat_id),
            "message_id": str(message_id)
        })
    except Exception as e:
        print("delete message error:", repr(e), flush=True)

def delete_later(chat_id, message_id, seconds=None):
    if not message_id:
        return

    if seconds is None:
        seconds = AUTO_DELETE_SECONDS

    try:
        t = threading.Timer(seconds, delete_message, args=(chat_id, message_id))
        t.daemon = True
        t.start()
    except Exception as e:
        print("timer delete error:", repr(e), flush=True)

def send(chat_id, text, keyboard=None, auto_delete=None):
    data = {
        "chat_id": str(chat_id),
        "text": text,
        "parse_mode": "HTML",
        "disable_web_page_preview": "true"
    }

    if keyboard:
        data["reply_markup"] = json.dumps(keyboard)

    try:
        res = api("sendMessage", data)
        msg_id = res.get("result", {}).get("message_id") if isinstance(res, dict) else None

        if auto_delete is None:
            auto_delete = not should_keep_message(text)

        if auto_delete:
            delete_later(chat_id, msg_id, AUTO_DELETE_SECONDS)

        return res

    except Exception as e:
        print("send error:", repr(e), flush=True)
        return None

def is_admin(uid):
    cfg = load_config()
    return str(uid) == str(cfg.get("admin_id", 0))

def is_authorized(uid):
    cfg = load_config()

    if is_admin(uid):
        return True

    return str(uid) in cfg.get("authorized", {})

def get_credits(uid):
    cfg = load_config()

    if is_admin(uid):
        return 999999

    data = cfg.get("authorized", {}).get(str(uid), {})
    return int(data.get("credits", 0))

def remove_one_credit(uid):
    if is_admin(uid):
        return True

    cfg = load_config()
    uid = str(uid)
    current = int(cfg.get("authorized", {}).get(uid, {}).get("credits", 0))

    if current <= 0:
        return False

    cfg["authorized"][uid]["credits"] = current - 1
    save_config(cfg)
    return True

def blocked_message(uid):
    cfg = load_config()
    admin_user = cfg.get("admin_username", "@DarkZsaid")

    return (
        "\U000026A1 <b>DARKZSAID PREMIUM BOT</b> \U000026A1\n"
        "<b>SSH | WS | SSL | USERS</b>\n"
        "━━━━━━━━━━━━━━━━━━━━━━\n\n"
        "\U000026D4 <b>ACCESO RESTRINGIDO</b>\n\n"
        "Tu cuenta Telegram no está autorizada para usar este panel.\n\n"
        "\U0001F194 <b>ID Telegram:</b>\n"
        f"<code>{uid}</code>\n\n"
        "\U0001F510 <b>Estado:</b>\n"
        "<b>No autorizado</b>\n\n"
        "\U0001F4E9 <b>Solicita acceso al administrador:</b>\n"
        f"{esc(admin_user)}\n\n"
        "Envíale tu ID Telegram para que pueda agregarte créditos o autorizar tu acceso.\n\n"
        "━━━━━━━━━━━━━━━━━━━━━━\n"
        "<b>DarkZsaid Premium Bot</b>\n"
        "<i>Control remoto SSH | WS | SSL</i>"
    )

def server_ip():
    code, out, _ = run(["bash", "-lc", "hostname -I | awk '{print $1}'"], timeout=3)
    return out.strip() or "-"

def server_system():
    try:
        if os.path.exists("/etc/os-release"):
            with open("/etc/os-release", "r") as f:
                for line in f:
                    if line.startswith("PRETTY_NAME="):
                        return line.split("=", 1)[1].strip().strip('"')
    except Exception:
        pass

    return "Linux"

def send_menu(chat_id, uid):
    if not is_authorized(uid):
        send(chat_id, blocked_message(uid), auto_delete=False)
        return

    ip = server_ip()
    sistema = server_system()
    fecha = datetime.now().strftime("%d/%m/%Y")
    hora = datetime.now().strftime("%H:%M:%S")

    acceso = "SUPER ADMIN" if is_admin(uid) else "RESELLER"
    creditos = "ILIMITADO" if is_admin(uid) else str(get_credits(uid))

    if is_admin(uid):
        opciones = (
            "\U00002699\ufe0f /crear      ➜ Crear usuario SSH\n"
            "\U0001F4CB /usuarios   ➜ Ver usuarios registrados\n"
            "\U0001F7E2 /online     ➜ Ver usuarios conectados\n"
            "\U0001F5D1\ufe0f /eliminar   ➜ Eliminar usuario por lista\n"
            "\U0001F504 /renovar    ➜ Añadir o quitar días\n"
            "\U0001F310 /puertos    ➜ Estado de puertos activos\n"
            "\U0001F48E /creditos   ➜ Panel de créditos\n"
            "\U0001F194 /id         ➜ Ver tu ID Telegram\n"
            "\U0001F501 /menu       ➜ Recargar panel"
        )
    else:
        opciones = (
            "\U00002699\ufe0f /crear      ➜ Crear usuario con crédito\n"
            "\U0001F4CB /usuarios   ➜ Ver mis usuarios registrados\n"
            "\U0001F7E2 /online     ➜ Ver usuarios conectados\n"
            "\U0001F5D1\ufe0f /eliminar   ➜ Eliminar mis usuarios\n"
            "\U0001F310 /puertos    ➜ Estado de puertos activos\n"
            "\U0001F501 /menu       ➜ Recargar panel"
        )

    text = (
        "\U00002728 <b>BIENVENIDO A DARKZSAID PREMIUM</b> \U00002728\n"
        "<b>SSH | WS | SSL | USERS</b>\n"
        "━━━━━━━━━━━━━━━━━━━━━━\n\n"
        "\U0001F537 <b>PANEL REMOTO DE CONTROL</b>\n"
        "Bienvenido al sistema premium de administración SSH.\n\n"
        "\U0001F4BB <b>INFORMACIÓN VPS</b>\n"
        f"\U0001F539 <b>IP VPS:</b> <b>{esc(ip)}</b>\n"
        f"\U0001F539 <b>Sistema:</b> <b>{esc(sistema)}</b>\n"
        f"\U0001F539 <b>Fecha:</b> <b>{fecha}</b>\n"
        f"\U0001F539 <b>Hora:</b> <b>{hora}</b>\n\n"
        "\U0001F510 <b>ACCESO TELEGRAM</b>\n"
        f"\U0001F539 <b>Rango:</b> <b>{acceso}</b>\n"
        f"\U0001F539 <b>Créditos:</b> <b>{creditos}</b>\n"
        f"\U0001F539 <b>Estado:</b> <b>ACCESO ACTIVO</b>\n\n"
        "━━━━━━━━━━━━━━━━━━━━━━\n"
        "\U0001F3AE <b>MENÚ PRINCIPAL</b>\n"
        "━━━━━━━━━━━━━━━━━━━━━━\n"
        f"{opciones}\n"
        "━━━━━━━━━━━━━━━━━━━━━━\n\n"
        "<b>DarkZsaid Premium Bot</b>\n"
        "<i>Control seguro de usuarios SSH | WS | SSL</i>"
    )

    send(chat_id, text, auto_delete=False)

def valid_username(username):
    return re.fullmatch(r"[A-Za-z0-9_.-]{3,24}", username or "") is not None

def user_exists(username):
    code, _, _ = run(["id", username], timeout=5)
    return code == 0

def read_field(file, key):
    try:
        with open(file, "r") as f:
            for line in f:
                if line.lower().startswith(key.lower() + ":"):
                    return line.split(":", 1)[1].strip()
    except Exception:
        pass

    return ""

def set_field(file, key, value):
    lines = []
    found = False

    if os.path.exists(file):
        with open(file, "r") as f:
            lines = f.read().splitlines()

    out = []

    for line in lines:
        if line.lower().startswith(key.lower() + ":"):
            out.append(f"{key}: {value}")
            found = True
        else:
            out.append(line)

    if not found:
        out.append(f"{key}: {value}")

    with open(file, "w") as f:
        f.write("\n".join(out) + "\n")

def days_left(exp):
    try:
        end = datetime.strptime(exp, "%Y-%m-%d")
        return max((end - datetime.now()).days, 0)
    except Exception:
        return "-"

def list_users_raw():
    users = []

    for file in sorted(glob.glob(USERDIR + "/*")):
        if not os.path.isfile(file):
            continue

        username = os.path.basename(file)

        users.append({
            "user": username,
            "file": file,
            "pass": read_field(file, "senha") or "-",
            "limit": read_field(file, "Limite") or "0",
            "exp": read_field(file, "data") or "-",
            "consumo": read_field(file, "Consumo") or "0",
            "unidad": read_field(file, "Unidad") or "GB",
            "usado": read_field(file, "UsadoMB") or "0",
            "owner": read_field(file, "OwnerID") or ""
        })

    return users

def visible_users(uid):
    users = list_users_raw()

    if is_admin(uid):
        return users

    return [u for u in users if str(u.get("owner", "")) == str(uid)]

def users_text(uid):
    users = visible_users(uid)

    if not users:
        return (
            "\U0001F4CB <b>USUARIOS REGISTRADOS</b>\n"
            "━━━━━━━━━━━━━━━━━━━━━━\n\n"
            "No hay usuarios registrados."
        )

    text = (
        "\U0001F4CB <b>USUARIOS REGISTRADOS</b>\n"
        "━━━━━━━━━━━━━━━━━━━━━━\n\n"
    )

    for i, u in enumerate(users, 1):
        consumo_limite = "Ilimitado" if u["consumo"] == "0" else f'{u["consumo"]} {u["unidad"]}'

        text += (
            f"<b>[{i}] {esc(u['user'])}</b>\n"
            f"\U0001F510 Clave: <code>{esc(u['pass'])}</code>\n"
            f"\U0001F465 Límite: <b>{esc(u['limit'])}</b>\n"
            f"\U0001F4C5 Caduca: <b>{esc(u['exp'])}</b> ({days_left(u['exp'])} días)\n"
            f"\U0001F4CA Consumo: <b>{esc(u['usado'])} MB / {esc(consumo_limite)}</b>\n\n"
        )

    text += "━━━━━━━━━━━━━━━━━━━━━━"
    return text

def create_account(username, password, limit, days, consumo, unidad):
    if not valid_username(username):
        return False, (
            "\U000026A0 <b>USUARIO INVÁLIDO</b>\n"
            "━━━━━━━━━━━━━━━━━━━━━━\n\n"
            "Use de 3 a 24 caracteres: letras, números, punto, guion o guion bajo."
        )

    if user_exists(username):
        return False, (
            "\U000026A0 <b>USUARIO YA EXISTE</b>\n"
            "━━━━━━━━━━━━━━━━━━━━━━\n\n"
            f"El usuario <b>{esc(username)}</b> ya está registrado."
        )

    try:
        limit = int(limit)
        days = int(days)
        consumo = int(consumo)
    except Exception:
        return False, (
            "\U000026A0 <b>DATOS INVÁLIDOS</b>\n"
            "━━━━━━━━━━━━━━━━━━━━━━\n\n"
            "Revise límite, días o consumo."
        )

    if limit < 1:
        limit = 1

    if days < 1:
        days = 1

    unidad = (unidad or "GB").upper()

    if unidad not in ("MB", "GB"):
        unidad = "GB"

    exp = (datetime.now() + timedelta(days=days)).strftime("%Y-%m-%d")

    code, out, err = run(["useradd", "-M", "-s", "/bin/bash", username])

    if code != 0:
        return False, (
            "\U0000274C <b>ERROR AL CREAR USUARIO</b>\n"
            "━━━━━━━━━━━━━━━━━━━━━━\n\n"
            f"<code>{esc(err or out)}</code>"
        )

    code, out, err = run(["chpasswd"], input_text=f"{username}:{password}\n")

    if code != 0:
        run(["userdel", "-f", username])
        return False, (
            "\U0000274C <b>ERROR AL ASIGNAR CLAVE</b>\n"
            "━━━━━━━━━━━━━━━━━━━━━━\n\n"
            f"<code>{esc(err or out)}</code>"
        )

    run(["chage", "-E", exp, username])

    file = os.path.join(USERDIR, username)

    with open(file, "w") as f:
        f.write(
            f"usuario: {username}\n"
            f"senha: {password}\n"
            f"Limite: {limit}\n"
            f"data: {exp}\n"
            f"Consumo: {consumo}\n"
            f"Unidad: {unidad}\n"
            f"UsadoMB: 0\n"
            f"Estado: ACTIVO\n"
        )

    if os.path.exists(QUOTA):
        run([QUOTA, "--setup", username], timeout=15)

    consumo_texto = "Ilimitado" if consumo == 0 else f"{consumo} {unidad}"

    msg = (
        "\U0001F48E <b>USUARIO CREADO CORRECTAMENTE</b>\n"
        "━━━━━━━━━━━━━━━━━━━━━━\n\n"
        f"\U0001F464 <b>Usuario:</b> <code>{esc(username)}</code>\n"
        f"\U0001F510 <b>Clave:</b> <code>{esc(password)}</code>\n"
        f"\U0001F465 <b>Límite:</b> <b>{limit}</b>\n"
        f"\U0001F4C5 <b>Días:</b> <b>{days}</b>\n"
        f"\U000023F3 <b>Caduca:</b> <b>{exp}</b>\n"
        f"\U0001F4CA <b>Consumo:</b> <b>{esc(consumo_texto)}</b>\n\n"
        "━━━━━━━━━━━━━━━━━━━━━━\n"
        "\U000026A1 <b>DARKZSAID PREMIUM BOT</b> \U000026A1"
    )

    return True, msg

def delete_account(username):
    file = os.path.join(USERDIR, username)

    run(["pkill", "-u", username], timeout=5)
    run(["pkill", "-f", f"sshd: {username}"], timeout=5)
    run(["userdel", "-f", username], timeout=10)

    if os.path.exists(file):
        dest = os.path.join(
            DELETED_DIR,
            f"{username}_eliminado_bot_{datetime.now().strftime('%Y-%m-%d_%H-%M-%S')}"
        )

        try:
            shutil.move(file, dest)
        except Exception:
            try:
                os.remove(file)
            except Exception:
                pass

    return True, (
        "\U0001F5D1 <b>USUARIO ELIMINADO</b>\n"
        "━━━━━━━━━━━━━━━━━━━━━━\n\n"
        f"Usuario: <b>{esc(username)}</b>"
    )

def begin_create(chat_id, uid):
    if not is_admin(uid) and get_credits(uid) <= 0:
        send(
            chat_id,
            "\U0000274C <b>SIN CRÉDITOS DISPONIBLES</b>\n"
            "━━━━━━━━━━━━━━━━━━━━━━\n\n"
            "Cada crédito permite crear una cuenta de 30 días."
        )
        return

    states[str(uid)] = {
        "flow": "create",
        "step": "username",
        "data": {}
    }

    if is_admin(uid):
        msg = (
            "\U0001F4DD <b>CREAR USUARIO SSH</b>\n"
            "━━━━━━━━━━━━━━━━━━━━━━\n\n"
            "\U0001F539 Envíe el nombre del usuario:"
        )
    else:
        msg = (
            "\U0001F4DD <b>CREAR USUARIO CON CRÉDITO</b>\n"
            "━━━━━━━━━━━━━━━━━━━━━━\n\n"
            "Cada crédito crea una cuenta de <b>30 días</b>.\n\n"
            "\U0001F539 Envíe el nombre del usuario:"
        )

    send(chat_id, msg)

def handle_create(chat_id, uid, text):
    st = states[str(uid)]
    data = st["data"]
    step = st["step"]

    if step == "username":
        username = text.strip()

        if not valid_username(username):
            send(chat_id, "\U000026A0 Usuario inválido. Use letras, números, punto, guion o guion bajo.")
            return

        if user_exists(username):
            send(chat_id, "\U000026A0 Ese usuario ya existe. Envíe otro nombre:")
            return

        data["username"] = username
        st["step"] = "password"

        send(
            chat_id,
            "\U0001F511 <b>CLAVE DE ACCESO</b>\n"
            "━━━━━━━━━━━━━━━━━━━━━━\n\n"
            "\U0001F539 Envíe la contraseña:"
        )
        return

    if step == "password":
        data["password"] = text.strip() or "1234"
        st["step"] = "limit"

        send(
            chat_id,
            "\U0001F465 <b>LÍMITE DE CONEXIONES</b>\n"
            "━━━━━━━━━━━━━━━━━━━━━━\n\n"
            "\U0001F539 Envíe el límite permitido:"
        )
        return

    if step == "limit":
        value = text.strip()

        if not value.isdigit():
            send(chat_id, "\U000026A0 Límite inválido. Envíe un número:")
            return

        data["limit"] = value

        if is_admin(uid):
            st["step"] = "days"

            send(
                chat_id,
                "\U0001F4C5 <b>TIEMPO DE DURACIÓN</b>\n"
                "━━━━━━━━━━━━━━━━━━━━━━\n\n"
                "\U0001F539 Envíe la cantidad de días:"
            )
        else:
            data["days"] = "30"
            st["step"] = "unit"

            send(
                chat_id,
                "\U0001F4CA <b>CONTROL DE CONSUMO</b>\n"
                "━━━━━━━━━━━━━━━━━━━━━━\n\n"
                "\U0001F539 Envíe <b>MB</b>, <b>GB</b> o <b>0</b> para ilimitado:"
            )
        return

    if step == "days":
        value = text.strip()

        if not value.isdigit():
            send(chat_id, "\U000026A0 Días inválidos. Envíe un número:")
            return

        data["days"] = value
        st["step"] = "unit"

        send(
            chat_id,
            "\U0001F4CA <b>CONTROL DE CONSUMO</b>\n"
            "━━━━━━━━━━━━━━━━━━━━━━\n\n"
            "\U0001F539 Envíe <b>MB</b>, <b>GB</b> o <b>0</b> para ilimitado:"
        )
        return

    if step == "unit":
        value = text.strip().upper()

        if value in ("0", "ILIMITADO", "SIN LIMITE", "SIN LÍMITE"):
            data["unit"] = "GB"
            data["consumo"] = "0"

            ok, msg = finish_create(uid, data)
            states.pop(str(uid), None)

            send(chat_id, msg)
            send_menu(chat_id, uid)
            return

        if value not in ("MB", "GB"):
            send(chat_id, "\U000026A0 Unidad inválida. Envíe MB, GB o 0 para ilimitado:")
            return

        data["unit"] = value
        st["step"] = "consumo"

        send(
            chat_id,
            f"\U0001F4CA <b>CANTIDAD DE CONSUMO</b>\n"
            "━━━━━━━━━━━━━━━━━━━━━━\n\n"
            f"\U0001F539 Envíe la cantidad en <b>{value}</b>:"
        )
        return

    if step == "consumo":
        value = text.strip()

        if not value.isdigit():
            send(chat_id, "\U000026A0 Cantidad inválida. Envíe un número:")
            return

        data["consumo"] = value

        ok, msg = finish_create(uid, data)
        states.pop(str(uid), None)

        send(chat_id, msg)
        send_menu(chat_id, uid)
        return

def finish_create(uid, data):
    if not is_admin(uid) and get_credits(uid) <= 0:
        return False, "\U0000274C No tienes créditos disponibles."

    ok, msg = create_account(
        data["username"],
        data["password"],
        data["limit"],
        data["days"],
        data["consumo"],
        data["unit"]
    )

    if ok:
        user_file = os.path.join(USERDIR, data["username"])
        set_field(user_file, "OwnerID", str(uid))

    if ok and not is_admin(uid):
        remove_one_credit(uid)
        msg += f"\n\n\U0001F48E Créditos restantes: <b>{get_credits(uid)}</b>"

    return ok, msg

def begin_delete(chat_id, uid):
    users = visible_users(uid)

    if not users:
        send(chat_id, "No hay usuarios disponibles para eliminar.")
        return

    states[str(uid)] = {"flow": "delete", "step": "number"}

    text = (
        "\U0001F5D1 <b>ELIMINAR USUARIO</b>\n"
        "━━━━━━━━━━━━━━━━━━━━━━\n\n"
    )

    for i, u in enumerate(users, 1):
        text += f"[{i}] {esc(u['user'])} ➜ caduca {esc(u['exp'])}\n"

    text += "\nEnvíe el número del usuario a eliminar:"
    send(chat_id, text)

def handle_delete(chat_id, uid, text):
    users = visible_users(uid)

    if not text.strip().isdigit():
        send(chat_id, "Número inválido.")
        return

    idx = int(text.strip())

    if idx < 1 or idx > len(users):
        send(chat_id, "Número fuera de rango.")
        return

    username = users[idx - 1]["user"]

    ok, msg = delete_account(username)

    states.pop(str(uid), None)

    send(chat_id, msg)
    send_menu(chat_id, uid)

def begin_renew(chat_id, uid):
    if not is_admin(uid):
        send(chat_id, "Renovar usuarios solo está disponible para el Super Admin.")
        return

    users = visible_users(uid)

    if not users:
        send(chat_id, "No hay usuarios para renovar.")
        return

    states[str(uid)] = {
        "flow": "renew",
        "step": "number",
        "data": {}
    }

    text = (
        "\U0001F504 <b>RENOVAR USUARIO</b>\n"
        "━━━━━━━━━━━━━━━━━━━━━━\n\n"
    )

    for i, u in enumerate(users, 1):
        text += f"[{i}] {esc(u['user'])} ➜ caduca {esc(u['exp'])}\n"

    text += "\nEnvíe el número del usuario:"
    send(chat_id, text)

def renew_account(username, mode, days):
    file = os.path.join(USERDIR, username)

    if not os.path.exists(file):
        return False, "No existe registro del usuario."

    try:
        days = int(days)
    except Exception:
        return False, "Cantidad de días inválida."

    if days < 1:
        return False, "La cantidad debe ser mayor a 0."

    exp = read_field(file, "data")

    try:
        current = datetime.strptime(exp, "%Y-%m-%d")
    except Exception:
        current = datetime.now()

    if mode == "add":
        if current < datetime.now():
            current = datetime.now()
        new_exp = current + timedelta(days=days)
        accion = "añadidos"
    else:
        new_exp = current - timedelta(days=days)
        accion = "quitados"

    new_exp_str = new_exp.strftime("%Y-%m-%d")

    set_field(file, "data", new_exp_str)
    set_field(file, "Estado", "ACTIVO")
    run(["chage", "-E", new_exp_str, username])

    return True, (
        "\U0001F504 <b>USUARIO ACTUALIZADO</b>\n"
        "━━━━━━━━━━━━━━━━━━━━━━\n\n"
        f"\U0001F464 Usuario: <b>{esc(username)}</b>\n"
        f"\U0001F4C5 Días {accion}: <b>{days}</b>\n"
        f"\U000023F3 Nueva expiración: <b>{new_exp_str}</b>"
    )

def handle_renew(chat_id, uid, text):
    st = states[str(uid)]
    data = st["data"]
    step = st["step"]

    if step == "number":
        users = visible_users(uid)

        if not text.strip().isdigit():
            send(chat_id, "Número inválido.")
            return

        idx = int(text.strip())

        if idx < 1 or idx > len(users):
            send(chat_id, "Número fuera de rango.")
            return

        data["user"] = users[idx - 1]["user"]
        st["step"] = "mode"

        send(
            chat_id,
            "Escriba:\n\n"
            "<b>sumar</b> ➜ añadir días\n"
            "<b>quitar</b> ➜ quitar días"
        )
        return

    if step == "mode":
        value = text.strip().lower()

        if value in ("sumar", "añadir", "agregar", "+"):
            data["mode"] = "add"
        elif value in ("quitar", "restar", "-"):
            data["mode"] = "remove"
        else:
            send(chat_id, "Opción inválida. Escriba sumar o quitar:")
            return

        st["step"] = "days"
        send(chat_id, "\U0001F4C5 Envíe la cantidad de días:")
        return

    if step == "days":
        if not text.strip().isdigit():
            send(chat_id, "Cantidad inválida.")
            return

        ok, msg = renew_account(data["user"], data["mode"], text.strip())

        states.pop(str(uid), None)

        send(chat_id, msg)
        send_menu(chat_id, uid)

def get_user_from_pid(pid):
    code, args, _ = run(["ps", "-o", "args=", "-p", str(pid)], timeout=3)
    match = re.search(r"sshd:\s*([A-Za-z0-9_.-]+)", args or "")

    if match:
        username = match.group(1)

        if username in ("root", "sshd"):
            return ""

        if os.path.exists(os.path.join(USERDIR, username)):
            return username

    code, out, _ = run(["pgrep", "-P", str(pid)], timeout=3)

    if code == 0 and out:
        for child in out.split():
            user = get_user_from_pid(child)

            if user:
                return user

    return ""

def online_text(uid):
    """
    /online premium:
    Cuenta usuarios SSH únicos, no sockets repetidos.
    Si steven abre 2 conexiones internas, se muestra steven una sola vez.
    """
    import subprocess
    import re
    from pathlib import Path

    try:
        procesos = subprocess.check_output(
            "ps -eo args | grep 'sshd:' | grep -v grep",
            shell=True,
            text=True,
            stderr=subprocess.DEVNULL
        )
    except Exception:
        procesos = ""

    usuarios = set()

    for line in procesos.splitlines():
        match = re.search(r"sshd:\s*([A-Za-z0-9_.-]+)", line)
        if not match:
            continue

        usuario = match.group(1).strip()

        if not usuario:
            continue
        if usuario in ("root", "sshd"):
            continue
        if usuario.startswith("["):
            continue

        usuarios.add(usuario)

    texto = "◇ <b>USUARIOS EN LÍNEA</b>\n"
    texto += "━━━━━━━━━━━━━━━━━━━━\n\n"

    if not usuarios:
        texto += "No hay usuarios conectados.\n"
        texto += "\n━━━━━━━━━━━━━━━━━━━━\n"
        texto += "Total conectados: <b>0</b>"
        return texto

    total = 0

    for usuario in sorted(usuarios):
        limite = "1"
        archivo = Path(f"/etc/adm-lite/userDIR/{usuario}")

        if archivo.exists():
            try:
                data = archivo.read_text(errors="ignore")
                m_limite = re.search(r"(?im)^Limite:\s*(\S+)", data)
                if m_limite:
                    limite = m_limite.group(1)
            except Exception:
                pass

        total += 1
        texto += f"◆ <b>{usuario}</b> ➜ 1/{limite}\n"

    texto += "\n━━━━━━━━━━━━━━━━━━━━\n"
    texto += f"Total conectados: <b>{total}</b>"
    return texto


def ports_text():
    ports = [
        ("22", "OpenSSH", "SSH directo"),
        ("443", "SSL/Stunnel", "443 ➜ WS 80 ➜ OpenSSH 22"),
        ("80", "WS SSH", "80 ➜ OpenSSH 22"),
        ("90", "WS SSH", "90 ➜ OpenSSH 22"),
        ("8080", "WS SSH", "8080 ➜ OpenSSH 22"),
        ("8082", "WS SSH", "8082 ➜ OpenSSH 22"),
        ("8084", "WS SSH", "8084 ➜ OpenSSH 22"),
        ("8086", "WS SSH", "8086 ➜ OpenSSH 22")
    ]

    code, out, _ = run(["bash", "-lc", "ss -ltn 2>/dev/null"], timeout=5)

    text = (
        "\U0001F310 <b>ESTADO PREMIUM DE PUERTOS</b>\n"
        "━━━━━━━━━━━━━━━━━━━━━━\n\n"
    )

    on = 0
    off = 0

    for port, service, dest in ports:
        active = re.search(rf"(:|\]){re.escape(port)}\s", out + "\n") is not None
        status = "\U0001F7E2 ON" if active else "\U0001F534 OFF"

        if active:
            on += 1
        else:
            off += 1

        text += f"<b>{port}</b> | {esc(service)} | {esc(dest)} | <b>{status}</b>\n"

    text += (
        "\n━━━━━━━━━━━━━━━━━━━━━━\n"
        f"\U0001F7E2 Encendidos: <b>{on}</b>\n"
        f"\U0001F534 Apagados: <b>{off}</b>"
    )

    return text

def admin_commands(chat_id):
    text = (
        "\U0001F48E <b>PANEL DE CRÉDITOS</b>\n"
        "━━━━━━━━━━━━━━━━━━━━━━\n\n"
        "<b>Uso exclusivo del Super Admin.</b>\n\n"
        "\U0001F539 <b>Dar créditos:</b>\n"
        "/creditos ID CANTIDAD\n\n"
        "\U0001F539 <b>Ver créditos:</b>\n"
        "/vercreditos ID\n\n"
        "\U0001F539 <b>Bloquear acceso:</b>\n"
        "/bloquear ID\n\n"
        "\U0001F539 <b>Ejemplo:</b>\n"
        "/creditos 5597272695 10\n\n"
        "Cada crédito equivale a una cuenta de 30 días.\n"
        "Al dar créditos, el ID queda autorizado automáticamente.\n\n"
        "━━━━━━━━━━━━━━━━━━━━━━\n"
        "<b>DarkZsaid Premium Bot</b>"
    )

    send(chat_id, text)

def handle_admin_command(chat_id, uid, text):
    if not is_admin(uid):
        send(chat_id, "Esta opción solo está disponible para el Super Admin.")
        return True

    parts = text.split()
    cmd = parts[0].lower()

    cfg = load_config()
    cfg.setdefault("authorized", {})

    if cmd == "/creditos":
        if len(parts) == 1:
            admin_commands(chat_id)
            return True

        if len(parts) != 3 or not parts[1].isdigit() or not parts[2].isdigit():
            send(
                chat_id,
                "<b>Uso correcto:</b>\n"
                "/creditos ID CANTIDAD\n\n"
                "<b>Ejemplo:</b>\n"
                "/creditos 5597272695 10"
            )
            return True

        tid = parts[1]
        amount = int(parts[2])

        cfg["authorized"].setdefault(tid, {"credits": 0})
        cfg["authorized"][tid]["credits"] = int(cfg["authorized"][tid].get("credits", 0)) + amount
        save_config(cfg)

        send(
            chat_id,
            "\U0001F48E <b>CRÉDITOS AGREGADOS</b>\n"
            "━━━━━━━━━━━━━━━━━━━━━━\n\n"
            f"ID Telegram: <code>{tid}</code>\n"
            f"Créditos agregados: <b>{amount}</b>\n"
            f"Total actual: <b>{cfg['authorized'][tid]['credits']}</b>\n\n"
            "El usuario ya puede usar el bot."
        )
        return True

    if cmd == "/vercreditos":
        if len(parts) != 2 or not parts[1].isdigit():
            send(chat_id, "Uso: /vercreditos ID")
            return True

        tid = parts[1]
        credits = cfg["authorized"].get(tid, {}).get("credits", 0)

        send(
            chat_id,
            "\U0001F48E <b>CRÉDITOS DEL USUARIO</b>\n"
            "━━━━━━━━━━━━━━━━━━━━━━\n\n"
            f"ID Telegram: <code>{tid}</code>\n"
            f"Créditos: <b>{credits}</b>"
        )
        return True

    if cmd == "/bloquear":
        if len(parts) != 2 or not parts[1].isdigit():
            send(chat_id, "Uso: /bloquear ID")
            return True

        tid = parts[1]
        cfg["authorized"].pop(tid, None)
        save_config(cfg)

        send(
            chat_id,
            "\U000026D4 <b>ACCESO BLOQUEADO</b>\n"
            "━━━━━━━━━━━━━━━━━━━━━━\n\n"
            f"ID Telegram bloqueado: <code>{tid}</code>"
        )
        return True

    if cmd == "/autorizar":
        if len(parts) != 2 or not parts[1].isdigit():
            send(chat_id, "Uso: /autorizar ID")
            return True

        tid = parts[1]
        cfg["authorized"].setdefault(tid, {"credits": 0})
        save_config(cfg)

        send(chat_id, f"ID autorizado: <code>{tid}</code>")
        return True

    return False

def handle_message(msg):
    chat_id = msg.get("chat", {}).get("id")
    uid = msg.get("from", {}).get("id")
    text = msg.get("text", "").strip()
    user_msg_id = msg.get("message_id")

    if not chat_id or not uid:
        return

    cmd = text.lower().split()[0] if text else ""

    if cmd not in ("/start", "/menu", "menu"):
        delete_later(chat_id, user_msg_id, AUTO_DELETE_SECONDS)

    if cmd in ("/start", "/menu", "menu"):
        send_menu(chat_id, uid)
        return

    if cmd == "/id":
        if is_admin(uid):
            send(chat_id, f"Tu ID Telegram es:\n<code>{uid}</code>")
        else:
            send(chat_id, "Este comando solo está disponible para el Super Admin.")
        return

    if cmd in ("/creditos", "/vercreditos", "/bloquear", "/autorizar"):
        handle_admin_command(chat_id, uid, text)
        return

    if not is_authorized(uid):
        send(chat_id, blocked_message(uid), auto_delete=False)
        return

    st = states.get(str(uid))

    if st:
        flow = st.get("flow")

        if cmd in ("/cancelar", "cancelar", "salir"):
            states.pop(str(uid), None)
            send(chat_id, "Operación cancelada.")
            send_menu(chat_id, uid)
            return

        if flow == "create":
            handle_create(chat_id, uid, text)
            return

        if flow == "delete":
            handle_delete(chat_id, uid, text)
            return

        if flow == "renew":
            handle_renew(chat_id, uid, text)
            return

    if cmd == "/crear":
        begin_create(chat_id, uid)
        return

    if cmd == "/usuarios":
        send(chat_id, users_text(uid))
        return

    if cmd == "/online":
        send(chat_id, online_text(uid))
        return

    if cmd == "/puertos":
        send(chat_id, ports_text())
        return

    if cmd == "/eliminar":
        begin_delete(chat_id, uid)
        return

    if cmd == "/renovar":
        begin_renew(chat_id, uid)
        return

    if cmd == "/admin":
        if is_admin(uid):
            admin_commands(chat_id)
        else:
            send(chat_id, "Esta opción solo está disponible para el Super Admin.")
        return

    send(
        chat_id,
        "Comando no reconocido.\n\n"
        "Escriba /menu para volver al menú principal."
    )

def answer_callback(callback_id, text="Usa /menu"):
    try:
        api("answerCallbackQuery", {
            "callback_query_id": callback_id,
            "text": text,
            "show_alert": "false"
        })
    except Exception:
        pass

def handle_callback(cb):
    callback_id = cb.get("id")
    msg = cb.get("message", {})
    chat_id = msg.get("chat", {}).get("id")

    answer_callback(callback_id, "Usa /menu")

    if chat_id:
        send(
            chat_id,
            "Este bot ahora funciona por comandos.\n\n"
            "Escriba /menu para abrir el panel premium."
        )

def main():
    offset = 0
    print("DarkZsaid Telegram Bot iniciado", flush=True)
    register_bot_commands()

    while True:
        cfg = load_config()

        if not cfg.get("token"):
            print("Token vacío. Configure el bot desde el panel.", flush=True)
            time.sleep(10)
            continue

        try:
            res = api("getUpdates", {
                "timeout": "50",
                "offset": str(offset),
                "allowed_updates": json.dumps(["message", "callback_query"])
            })

            for upd in res.get("result", []):
                offset = upd["update_id"] + 1

                if "callback_query" in upd:
                    handle_callback(upd["callback_query"])
                elif "message" in upd:
                    handle_message(upd["message"])

        except Exception as e:
            print("bot error:", repr(e), flush=True)
            time.sleep(5)

if __name__ == "__main__":
    main()
