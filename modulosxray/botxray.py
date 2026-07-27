"""
botxray.py - TURBONET XRAY V1.4 (PRO + HÍBRIDO)
Correções e Integrações:
  - save_config(): escrita atômica via tmpfile + os.replace() + chmod 0o640
  - core_delete_user(): USER_DB atômico via tmpfile + os.replace()
  - restart_xray(): retorna bool, loga stderr em caso de falha
  - nick normalizado para minúsculas em input_handler
  - generate_link(): sem fallback para inbounds[0] — erro explícito se inbound não encontrado
  - Backup Python gera SHA256 em blocos para evitar estouro de memória
  - useradd, userdel, passwd -l, passwd -u nativos no Python (Sincronia Híbrida SSH).
  - GUILHOTINA SSH: pkill e chage implementados no block, unblock e renew.
  - RELATÓRIO DE CONSUMO: Integração nativa lendo as bases do limiterxray.sh.
"""

import os
import json
import uuid
import hashlib
import logging
import subprocess
import asyncio
import re
import urllib.request
from datetime import datetime, timedelta
import tempfile
import shutil
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import (
    Application, CommandHandler, ContextTypes, ConversationHandler,
    MessageHandler, filters, CallbackQueryHandler
)
import io

# --- CONFIGURACAO VIA VARIAVEIS DE AMBIENTE ---
_token = os.environ.get("BOT_TOKEN", "")
_admin = os.environ.get("ADMIN_ID", "")
if not _token or not _admin:
    raise EnvironmentError(
        "BOT_TOKEN e ADMIN_ID devem estar definidos.\n"
        "Verifique /opt/XrayTools/.bot_env e EnvironmentFile= no botxray.service."
    )
BOT_TOKEN = _token
try:
    ADMIN_ID = int(_admin)
except ValueError:
    raise EnvironmentError(f"ADMIN_ID deve ser inteiro, obtido: '{_admin}'")

CONFIG_PATH  = "/usr/local/etc/xray/config.json"
USER_DB      = "/opt/XrayTools/users.db"
USAGE_DB     = "/opt/XrayTools/usage.db"
LIMITS_DB    = "/opt/XrayTools/limits.db"
XRAY_SERVICE = "xray"

logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)

(
    SELECTING_ACTION,
    GET_USERNAME_CREATE,
    GET_EXPIRY_DAYS_CREATE,
    GET_USER_TO_DELETE,
    GET_USER_TO_BLOCK,
    GET_USER_TO_UNBLOCK,
    GET_USER_TO_RENEW,
    GET_DAYS_TO_RENEW,
) = range(8)


# =============================================================
# FUNÇÕES DE SISTEMA
# =============================================================

def reload_xray_user(action: str, nick: str, user_uuid: str, inbound_tag: str = "inbound-turbonet") -> bool:
    try:
        data = load_config()
        if not data:
            return False
        api_port = None
        for inb in data.get("inbounds", []):
            if inb.get("tag") == "api":
                api_port = str(inb.get("port", ""))
                break
        if not api_port:
            logger.warning("reload_xray_user: inbound api não encontrado")
            return False

        xray_bin = "/usr/local/bin/xray"
        if not os.path.exists(xray_bin):
            logger.warning("reload_xray_user: xray binário não encontrado")
            return False

        if action == "add":
            user_json = json.dumps({
                "id": user_uuid,
                "email": nick,
                "level": 0
            })
            cmd = [xray_bin, "api", "adduser",
                   f"-server=127.0.0.1:{api_port}",
                   f"-inboundTag={inbound_tag}",
                   f"-user={user_json}"]
        elif action == "remove":
            cmd = [xray_bin, "api", "removeuser",
                   f"-server=127.0.0.1:{api_port}",
                   f"-inboundTag={inbound_tag}",
                   f"-email={nick}"]
        else:
            return False

        result = subprocess.run(cmd, check=False, capture_output=True, timeout=5)
        if result.returncode == 0:
            logger.info("reload_xray_user: %s '%s' via API OK", action, nick)
            return True
        else:
            logger.warning("reload_xray_user %s falhou: %s",
                          action, result.stderr.decode(errors="replace").strip())
            return False
    except Exception as e:
        logger.error("reload_xray_user erro: %s", e)
        return False


def load_config() -> 'Optional[dict]':
    if not os.path.exists(CONFIG_PATH):
        return None
    try:
        with open(CONFIG_PATH, "r", encoding="utf-8") as f:
            return json.load(f)
    except json.JSONDecodeError as e:
        logger.error("JSON corrompido: %s", e)
        return None


def save_config(data: dict) -> bool:
    tmp_path = CONFIG_PATH + f".tmp.{os.getpid()}"
    try:
        with open(tmp_path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
        os.replace(tmp_path, CONFIG_PATH)
        os.chmod(CONFIG_PATH, 0o660)
        try:
            import grp
            gid = grp.getgrnam("nogroup").gr_gid
            os.chown(CONFIG_PATH, 0, gid)
        except Exception as e:
            logger.warning("save_config: não foi possível restaurar chown root:nogroup: %s", e)
        return True
    except PermissionError as e:
        logger.error("save_config: sem permissão: %s", e)
        return False
    except Exception as e:
        logger.error("Erro ao salvar config: %s", e)
        return False
    finally:
        try:
            os.remove(tmp_path)
        except OSError:
            pass


def get_ip() -> str:
    for url in ("https://icanhazip.com", "https://api.ipify.org"):
        try:
            with urllib.request.urlopen(url, timeout=8) as resp:
                return resp.read().decode("utf-8").strip()
        except Exception as e:
            logger.warning("get_ip falhou em %s: %s", url, e)
    return "127.0.0.1"


def bytes_to_human(b: int) -> str:
    if b >= 1073741824:
        return f"{b / 1073741824:.2f} GB"
    elif b >= 1048576:
        return f"{b / 1048576:.2f} MB"
    else:
        return f"{b / 1024:.2f} KB"

# =============================================================
# GERADOR DE LINKS E RELATÓRIOS
# =============================================================

def generate_link(client_uuid: str, client_email: str) -> str:
    try:
        data = load_config()
        if not data:
            return "❌ Erro ao ler config."

        inbound = next(
            (i for i in data.get("inbounds", []) if i.get("tag") == "inbound-turbonet"),
            None,
        )
        if not inbound:
            return "❌ inbound-turbonet não encontrado no config."

        port     = inbound["port"]
        stream   = inbound["streamSettings"]
        network  = stream["network"]
        security = stream["security"]

        sni = ""
        host = ""
        if security == "tls":
            tls = stream.get("tlsSettings", {})
            sni  = tls.get("serverName", "")
            host = sni

        if not host:
            host = get_ip()
            sni  = ""

        if network == "tcp":
            clients = inbound.get("settings", {}).get("clients", [])
            client  = next((c for c in clients if c.get("id") == client_uuid), {})
            flow    = client.get("flow", "")
            if flow == "xtls-rprx-vision":
                return (
                    f"vless://{client_uuid}@{host}:{port}"
                    f"?security=tls&encryption=none&type=tcp"
                    f"&headerType=none&flow={flow}&sni={sni}#{client_email}"
                )
            sec_param = "security=tls" if security == "tls" else "security=none"
            return (
                f"vless://{client_uuid}@{host}:{port}"
                f"?{sec_param}&encryption=none&type=tcp&headerType=none&sni={sni}#{client_email}"
            )

        if network == "ws":
            path      = stream.get("wsSettings", {}).get("path", "/")
            sec_param = "security=tls" if security == "tls" else "security=none"
            ws_host   = sni if sni else host
            return (
                f"vless://{client_uuid}@{host}:{port}"
                f"?{sec_param}&encryption=none&type=ws"
                f"&host={ws_host}&path={path}&sni={sni}#{client_email}"
            )

        if network == "grpc":
            service   = stream.get("grpcSettings", {}).get("serviceName", "gRPC")
            sec_param = "security=tls" if security == "tls" else "security=none"
            return (
                f"vless://{client_uuid}@{host}:{port}"
                f"?{sec_param}&encryption=none&type=grpc"
                f"&serviceName={service}&sni={sni}#{client_email}"
            )

        if network == "xhttp":
            path      = stream.get("xhttpSettings", {}).get("path", "/")
            sec_param = "security=tls" if security == "tls" else "security=none"
            return (
                f"vless://{client_uuid}@{host}:{port}"
                f"?mode=auto&{sec_param}&encryption=none&type=xhttp"
                f"&host={host}&path={path}&sni={sni}#{client_email}"
            )

        return "❌ Protocolo não suportado para geração de link."

    except Exception as e:
        return f"Erro Link: {e}"


def core_list_usage_text() -> str:
    """Lê os bancos de dados do limiterxray.sh e formata o consumo."""
    usages = {}
    if os.path.exists(USAGE_DB):
        with open(USAGE_DB, 'r') as f:
            for line in f:
                parts = line.strip().split('|')
                if len(parts) >= 2 and parts[1].isdigit():
                    usages[parts[0]] = int(parts[1])

    limits = {}
    if os.path.exists(LIMITS_DB):
        with open(LIMITS_DB, 'r') as f:
            for line in f:
                parts = line.strip().split('|')
                if len(parts) >= 2 and parts[1].isdigit():
                    limits[parts[0]] = int(parts[1])

    all_nicks = set(usages.keys()).union(set(limits.keys()))
    if os.path.exists(USER_DB):
        with open(USER_DB, 'r') as f:
            for line in f:
                parts = line.strip().split('|')
                if parts[0]:
                    all_nicks.add(parts[0])

    if not all_nicks:
        return "Nenhum dado de consumo ou usuário registrado."

    sep = "-" * 60
    header = (
        "📊 RELATÓRIO DE CONSUMO DE DADOS\n"
        + sep + "\n"
        + f"{'USUÁRIO':<14} | {'USADO':<12} | {'LIMITE':<12} | STATUS\n"
        + sep + "\n"
    )
    rows = []
    
    for nick in sorted(all_nicks):
        use_bytes = usages.get(nick, 0)
        lim_bytes = limits.get(nick, None)
        
        use_str = bytes_to_human(use_bytes)
        
        if lim_bytes is None:
            lim_str = "Sem limite"
            status = "Livre"
        else:
            lim_str = bytes_to_human(lim_bytes)
            if use_bytes >= lim_bytes:
                status = "EXCEDIDO"
            else:
                pct = int((use_bytes * 100) / lim_bytes)
                status = f"{pct}%"

        rows.append(f"{nick:<14} | {use_str:<12} | {lim_str:<12} | {status}")

    return header + "\n".join(rows) + "\n" + sep


def core_list_users_text() -> str:
    if not os.path.exists(USER_DB):
        return "Nenhum usuário cadastrado."

    data         = load_config()
    locked_users = set()
    if data:
        for inbound in data.get("inbounds", []):
            if inbound.get("tag") == "inbound-turbonet":
                for c in inbound["settings"]["clients"]:
                    email = c.get("email", "")
                    if email.startswith("LOCKED_"):
                        locked_users.add(email.replace("LOCKED_", "", 1))

    sep = "-" * 65
    header = (
        "📋 LISTA DE USUÁRIOS - TURBONET XRAY\n"
        + sep + "\n"
        + f"{'NOME':<12} | {'VENCIMENTO':<11} | {'UUID (resumido)':<20} | STATUS\n"
        + sep + "\n"
    )
    rows = []
    with open(USER_DB, "r") as f:
        for line in f:
            parts = line.strip().split("|")
            if len(parts) >= 3:
                nick_r, uuid_r, expiry_r = parts[0], parts[1], parts[2]
                status = "⛔" if nick_r in locked_users else "✅"
                uuid_short = uuid_r[:8] + "..." + uuid_r[-4:] if len(uuid_r) >= 12 else uuid_r
                rows.append(f"{nick_r:<12} | {expiry_r:<11} | {uuid_short:<20} | {status}")

    footer = "\n" + sep + f"\nTotal: {len(rows)} usuário(s)"
    return header + "\n".join(rows) + footer if rows else header + "(vazio)"


# =============================================================
# FUNÇÕES CORE DE GERENCIAMENTO (CRIAR, BLOQUEAR, RESTAURAR)
# =============================================================

def core_create_user(nick: str, days: str) -> 'Tuple[bool, str]':
    if os.path.exists(USER_DB):
        with open(USER_DB, "r") as f:
            if any(line.startswith(f"{nick}|") for line in f):
                return False, "❌ Usuário já existe!"
    else:
        open(USER_DB, "a").close()

    user_uuid   = str(uuid.uuid4())
    expiry_date = (datetime.now() + timedelta(days=int(days))).strftime("%Y-%m-%d")

    data = load_config()
    if not data:
        return False, "❌ Erro ao ler config.json"

    inbound = next(
        (i for i in data.get("inbounds", []) if i.get("tag") == "inbound-turbonet"),
        None,
    )
    if not inbound:
        return False, "❌ inbound-turbonet não encontrado."

    inbound["settings"]["clients"].append(
        {"id": user_uuid, "email": nick, "level": 0}
    )

    if not save_config(data):
        return False, "❌ Falha ao salvar config.json."

    with open(USER_DB, "a") as f:
        f.write(f"{nick}|{user_uuid}|{expiry_date}|{nick}|0\n")

    # Integração Híbrida SSH/SOCKS5
    subprocess.run(["useradd", "-M", "-s", "/bin/false", nick], check=False, stderr=subprocess.DEVNULL)
    chp = subprocess.Popen(["chpasswd"], stdin=subprocess.PIPE, stderr=subprocess.DEVNULL)
    chp.communicate(f"{nick}:{nick}".encode('utf-8'))

    reload_xray_user("add", nick, user_uuid)
    link = generate_link(user_uuid, nick)

    return True, (
        f"✅ *Usuário Criado!*\n\n"
        f"👤 Nome:    `{nick}`\n"
        f"🔑 UUID:    `{user_uuid}`\n"
        f"📅 Expira: `{expiry_date}`\n"
        f"🔐 Senha App: `{nick}`\n\n"
        f"🔗 *Link:*\n`{link}`"
    )


def core_delete_user(nick: str) -> str:
    data  = load_config()
    found = False

    if data:
        for inbound in data.get("inbounds", []):
            if inbound.get("tag") == "inbound-turbonet":
                clients     = inbound["settings"]["clients"]
                new_clients = [
                    c for c in clients
                    if c.get("email") not in (nick, f"LOCKED_{nick}")
                ]
                if len(clients) != len(new_clients):
                    found = True
                inbound["settings"]["clients"] = new_clients
        if not save_config(data):
            return "❌ Falha ao salvar config.json."

    if os.path.exists(USER_DB):
        with open(USER_DB, "r") as f:
            lines = f.readlines()
        new_lines = []
        for line in lines:
            if line.startswith(f"{nick}|"):
                found = True
            else:
                new_lines.append(line)
        tmp_db = USER_DB + ".tmp"
        with open(tmp_db, "w") as f:
            f.writelines(new_lines)
        os.replace(tmp_db, USER_DB)

    if not found:
        return "❌ Usuário não encontrado no sistema."

    subprocess.run(["userdel", "-r", "-f", nick], check=False, stderr=subprocess.DEVNULL)
    reload_xray_user("remove", nick, "")
    reload_xray_user("remove", f"LOCKED_{nick}", "")
    return "✅ Usuário removido do sistema."


def core_block_user(nick: str) -> str:
    data = load_config()
    if not data:
        return "❌ Erro config."

    found = False
    for inbound in data.get("inbounds", []):
        if inbound.get("tag") == "inbound-turbonet":
            for client in inbound["settings"]["clients"]:
                if client.get("email") == f"LOCKED_{nick}":
                    return "⚠️ Usuário já está bloqueado."
                if client.get("email") == nick:
                    client["email"] = f"LOCKED_{nick}"
                    client["id"]    = str(uuid.uuid4())
                    found = True
                    break

    if not found:
        return "❌ Usuário não encontrado no Config."

    if not save_config(data):
        return "❌ Falha ao salvar config.json."

    # GUILHOTINA DE SESSÕES SSH (Derruba e trava)
    subprocess.run(["usermod", "-L", nick], check=False, stderr=subprocess.DEVNULL)
    subprocess.run(["chage", "-E", "0", nick], check=False, stderr=subprocess.DEVNULL)
    subprocess.run(["pkill", "-u", nick], check=False, stderr=subprocess.DEVNULL)

    reload_xray_user("remove", nick, "")
    locked_nick = f"LOCKED_{nick}"
    fake_uuid_str = str(uuid.uuid4())
    reload_xray_user("add", locked_nick, fake_uuid_str)
    return f"⛔ Usuário `{nick}` foi SUSPENSO e desconectado."


def core_unblock_user(nick: str) -> str:
    real_uuid = None
    if os.path.exists(USER_DB):
        with open(USER_DB, "r") as f:
            for line in f:
                if line.startswith(f"{nick}|"):
                    parts = line.strip().split("|")
                    if len(parts) >= 2:
                        real_uuid = parts[1]
                    break

    if not real_uuid:
        return "❌ Erro: UUID original não encontrado no DB."

    data = load_config()
    if not data:
        return "❌ Erro ao ler config."

    found = False
    for inbound in data.get("inbounds", []):
        if inbound.get("tag") == "inbound-turbonet":
            for client in inbound["settings"]["clients"]:
                if client.get("email") == f"LOCKED_{nick}":
                    client["email"] = nick
                    client["id"]    = real_uuid
                    found = True
                    break

    if not found:
        return "❌ Usuário não estava bloqueado no sistema."

    if not save_config(data):
        return "❌ Falha ao salvar config.json."

    # RESTAURAÇÃO SSH/SOCKS5
    subprocess.run(["usermod", "-U", nick], check=False, stderr=subprocess.DEVNULL)
    subprocess.run(["chage", "-E", "-1", nick], check=False, stderr=subprocess.DEVNULL)
    subprocess.run(["passwd", "-u", nick], check=False, stderr=subprocess.DEVNULL)

    reload_xray_user("remove", f"LOCKED_{nick}", "")
    reload_xray_user("add", nick, real_uuid)
    return f"✅ Usuário `{nick}` REATIVADO com sucesso."


def core_renew_user(nick: str, days_to_add: str) -> str:
    real_uuid = None
    current_expiry = None
    found = False
    lines = []

    if os.path.exists(USER_DB):
        with open(USER_DB, "r") as f:
            lines = f.readlines()

    for i, line in enumerate(lines):
        if line.startswith(f"{nick}|"):
            parts = line.strip().split("|")
            if len(parts) >= 3:
                real_uuid = parts[1]
                current_expiry = parts[2]
                try:
                    exp_date = datetime.strptime(current_expiry, "%Y-%m-%d")
                    if exp_date < datetime.now():
                        exp_date = datetime.now()
                    new_expiry = (exp_date + timedelta(days=int(days_to_add))).strftime("%Y-%m-%d")
                except:
                    new_expiry = (datetime.now() + timedelta(days=int(days_to_add))).strftime("%Y-%m-%d")

                parts[2] = new_expiry
                lines[i] = "|".join(parts) + "\n"
                found = True
            break

    if not found:
        return "❌ Usuário não encontrado no banco de dados."

    tmp_db = USER_DB + ".tmp"
    with open(tmp_db, "w") as f:
        f.writelines(lines)
    os.replace(tmp_db, USER_DB)

    # GARANTE DESTRANCAMENTO DO SSH SE RENOVAR
    subprocess.run(["usermod", "-U", nick], check=False, stderr=subprocess.DEVNULL)
    subprocess.run(["chage", "-E", "-1", nick], check=False, stderr=subprocess.DEVNULL)
    subprocess.run(["passwd", "-u", nick], check=False, stderr=subprocess.DEVNULL)

    data = load_config()
    was_locked = False
    if data:
        for inbound in data.get("inbounds", []):
            if inbound.get("tag") == "inbound-turbonet":
                for client in inbound["settings"]["clients"]:
                    if client.get("email") == f"LOCKED_{nick}":
                        client["email"] = nick
                        client["id"] = real_uuid
                        was_locked = True
                        break
    if was_locked:
        save_config(data)
        reload_xray_user("remove", f"LOCKED_{nick}", "")
        reload_xray_user("add", nick, real_uuid)

    return f"🔄 Usuário `{nick}` RENOVADO com sucesso!\nNova data: {new_expiry}"


# =============================================================
# FUNÇÕES DO TELEGRAM
# =============================================================

def is_admin(update: Update) -> bool:
    return update.effective_user is not None and update.effective_user.id == ADMIN_ID


def build_menu() -> InlineKeyboardMarkup:
    keyboard = [
        [
            InlineKeyboardButton("👤 CRIAR",     callback_data="create_start"),
            InlineKeyboardButton("🗑️ REMOVER",   callback_data="delete_start"),
        ],
        [
            InlineKeyboardButton("⛔ SUSPENDER", callback_data="block_start"),
            InlineKeyboardButton("✅ REATIVAR",  callback_data="unblock_start"),
        ],
        [
            InlineKeyboardButton("🔄 RENOVAR",   callback_data="renew_start"),
            InlineKeyboardButton("📋 LISTAR (TXT)", callback_data="list_users"),
        ],
        [
            InlineKeyboardButton("📊 VER CONSUMO", callback_data="usage_list"),
            InlineKeyboardButton("📥 BACKUP",      callback_data="backup_start"),
        ],
        [
            InlineKeyboardButton("❌ SAIR", callback_data="cancel"),
        ],
    ]
    return InlineKeyboardMarkup(keyboard)


async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update):
        return
    context.user_data.clear()
    await update.message.reply_text(
        "🐉 *PAINEL TURBONET XRAY V1.4 (PRO)*\n_Integração Híbrida SSH Ativa_",
        reply_markup=build_menu(),
        parse_mode="Markdown",
    )
    return SELECTING_ACTION


async def button_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update):
        return

    query = update.callback_query
    await query.answer()

    if query.data == "close_file":
        await query.message.delete()
        return SELECTING_ACTION

    if query.data == "cancel":
        await query.edit_message_text("Painel Fechado.", reply_markup=None)
        return ConversationHandler.END

    if query.data == "create_start":
        await query.edit_message_text(
            "Nome do usuário (5-9 letras/num):", parse_mode="Markdown"
        )
        return GET_USERNAME_CREATE

    if query.data == "delete_start":
        await query.edit_message_text("Nome para remover:", parse_mode="Markdown")
        return GET_USER_TO_DELETE

    if query.data == "block_start":
        await query.edit_message_text(
            "Nome para ⛔ SUSPENDER:", parse_mode="Markdown"
        )
        return GET_USER_TO_BLOCK

    if query.data == "unblock_start":
        await query.edit_message_text(
            "Nome para ✅ REATIVAR:", parse_mode="Markdown"
        )
        return GET_USER_TO_UNBLOCK

    if query.data == "renew_start":
        await query.edit_message_text(
            "Nome para 🔄 RENOVAR:", parse_mode="Markdown"
        )
        return GET_USER_TO_RENEW

    if query.data == "list_users":
        report = core_list_users_text()
        f = io.BytesIO(report.encode("utf-8"))
        f.name = "usuarios.txt"
        close_btn = InlineKeyboardMarkup(
            [[InlineKeyboardButton("🗑 Fechar Lista", callback_data="close_file")]]
        )
        await context.bot.send_document(
            chat_id=update.effective_chat.id,
            document=f,
            caption="📂 *Lista gerada*",
            parse_mode="Markdown",
            reply_markup=close_btn,
        )
        await query.edit_message_text(
            "✅ *Lista enviada abaixo!*\nEscolha outra opção:",
            parse_mode="Markdown",
            reply_markup=build_menu(),
        )
        return SELECTING_ACTION

    if query.data == "usage_list":
        report = core_list_usage_text()
        f = io.BytesIO(report.encode("utf-8"))
        f.name = "consumo.txt"
        close_btn = InlineKeyboardMarkup(
            [[InlineKeyboardButton("🗑 Fechar Relatório", callback_data="close_file")]]
        )
        await context.bot.send_document(
            chat_id=update.effective_chat.id,
            document=f,
            caption="📊 *Relatório de Consumo de Dados gerado*",
            parse_mode="Markdown",
            reply_markup=close_btn,
        )
        await query.edit_message_text(
            "✅ *Relatório de consumo enviado!*",
            parse_mode="Markdown",
            reply_markup=build_menu(),
        )
        return SELECTING_ACTION

    if query.data == "backup_start":
        await query.edit_message_text("📦 Gerando Backup...", parse_mode="Markdown")

        date_str = datetime.now().strftime("%Y%m%d_%H%M")
        bkp_file = f"/tmp/backup_{date_str}.tar.gz"
        sha_file = bkp_file + ".sha256"

        tmpdir = tempfile.mkdtemp()
        try:
            os.makedirs(f"{tmpdir}/opt/XrayTools", exist_ok=True)
            for fname in ["users.db", "limits.db", "usage.db", "session.db", "active_domain"]:
                src = f"/opt/XrayTools/{fname}"
                if os.path.exists(src):
                    shutil.copy2(src, f"{tmpdir}/opt/XrayTools/{fname}")
            if os.path.isdir("/usr/local/etc/xray"):
                shutil.copytree(
                    "/usr/local/etc/xray",
                    f"{tmpdir}/usr/local/etc/xray",
                    dirs_exist_ok=True,
                )
            if os.path.isdir("/opt/TurbonetCoreSSL"):
                shutil.copytree(
                    "/opt/TurbonetCoreSSL",
                    f"{tmpdir}/opt/TurbonetCoreSSL",
                    dirs_exist_ok=True,
                )
            subprocess.run(
                ["tar", "-czf", bkp_file, "-C", tmpdir, "."],
                check=False,
                capture_output=True,
            )
        finally:
            shutil.rmtree(tmpdir, ignore_errors=True)

        if os.path.exists(bkp_file) and os.path.getsize(bkp_file) > 0:
            sha256_hash = hashlib.sha256()
            with open(bkp_file, "rb") as f_hash:
                for byte_block in iter(lambda: f_hash.read(4096), b""):
                    sha256_hash.update(byte_block)
            digest = sha256_hash.hexdigest()

            with open(sha_file, "w") as sf:
                sf.write(f"{digest}  {os.path.basename(bkp_file)}\n")

            close_btn = InlineKeyboardMarkup(
                [[InlineKeyboardButton("🗑 Fechar Backup", callback_data="close_file")]]
            )
            # Envia o tar.gz
            with open(bkp_file, "rb") as f:
                await context.bot.send_document(
                    chat_id=update.effective_chat.id,
                    document=f,
                    filename=os.path.basename(bkp_file),
                    caption=(
                        "🔐 *Backup do Sistema*\n\n"
                        "_Inclui Xray, Banco de Dados e SSL_\n"
                        f"SHA256: `{digest[:16]}...`"
                    ),
                    parse_mode="Markdown",
                    reply_markup=close_btn,
                )
            # Envia o .sha256
            with open(sha_file, "rb") as f:
                await context.bot.send_document(
                    chat_id=update.effective_chat.id,
                    document=f,
                    filename=os.path.basename(sha_file),
                    caption="🔑 Hash SHA256 do backup acima",
                )
            os.remove(bkp_file)
            os.remove(sha_file)
            await query.edit_message_text(
                "✅ *Backup enviado abaixo!*",
                parse_mode="Markdown",
                reply_markup=build_menu(),
            )
        else:
            await query.edit_message_text(
                "❌ Falha ao criar backup. Verifique os logs.",
                reply_markup=build_menu(),
            )
        return SELECTING_ACTION

    await query.edit_message_text("Reiniciando...", reply_markup=build_menu())
    return SELECTING_ACTION


async def unexpected_button(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    return await button_handler(update, context)


async def input_handler(
    update: Update, context: ContextTypes.DEFAULT_TYPE, mode: str
):
    if not is_admin(update):
        return SELECTING_ACTION
    if not update.message or not update.message.text:
        return SELECTING_ACTION

    text = update.message.text.strip().split()[0].lower()

    if mode == "create_nick":
        if not re.match(r"^[a-zA-Z0-9]{5,9}$", text):
            await update.message.reply_text(
                "❌ *Nome Inválido!*\n\nRegras:\n• Entre 5 e 9 caracteres\n"
                "• Apenas letras e números\n\nTente outro:",
                parse_mode="Markdown",
            )
            return GET_USERNAME_CREATE
        context.user_data["nick"] = text
        await update.message.reply_text(
            f"Validade (dias) para `{text}`:", parse_mode="Markdown"
        )
        return GET_EXPIRY_DAYS_CREATE

    if mode == "create_days":
        if not text.isdigit():
            await update.message.reply_text("Só números.")
            return GET_EXPIRY_DAYS_CREATE
        _ok, msg = core_create_user(context.user_data["nick"], text)
        await update.message.reply_text(msg, parse_mode="Markdown", reply_markup=build_menu())
        return SELECTING_ACTION

    if mode == "delete":
        msg = core_delete_user(text)
        await update.message.reply_text(msg, reply_markup=build_menu())
        return SELECTING_ACTION

    if mode == "block":
        msg = core_block_user(text)
        await update.message.reply_text(msg, parse_mode="Markdown", reply_markup=build_menu())
        return SELECTING_ACTION

    if mode == "unblock":
        msg = core_unblock_user(text)
        await update.message.reply_text(msg, parse_mode="Markdown", reply_markup=build_menu())
        return SELECTING_ACTION

    if mode == "renew_nick":
        context.user_data["renew_nick"] = text
        await update.message.reply_text(
            f"Quantos dias deseja adicionar para `{text}`?", parse_mode="Markdown"
        )
        return GET_DAYS_TO_RENEW

    if mode == "renew_days":
        if not text.isdigit():
            await update.message.reply_text("Só números.")
            return GET_DAYS_TO_RENEW
        msg = core_renew_user(context.user_data["renew_nick"], text)
        await update.message.reply_text(msg, parse_mode="Markdown", reply_markup=build_menu())
        return SELECTING_ACTION

    logger.warning("input_handler: modo desconhecido '%s'", mode)
    await update.message.reply_text("❌ Operação inválida.", reply_markup=build_menu())
    return SELECTING_ACTION


# Wrappers assíncronos
async def h_create_nick(u, c): return await input_handler(u, c, "create_nick")
async def h_create_days(u, c): return await input_handler(u, c, "create_days")
async def h_delete(u, c):      return await input_handler(u, c, "delete")
async def h_block(u, c):       return await input_handler(u, c, "block")
async def h_unblock(u, c):     return await input_handler(u, c, "unblock")
async def h_renew_nick(u, c):  return await input_handler(u, c, "renew_nick")
async def h_renew_days(u, c):  return await input_handler(u, c, "renew_days")

async def cancel_op(u, c):
    await u.message.reply_text("Cancelado.", reply_markup=build_menu())
    return SELECTING_ACTION


# =============================================================
# MAIN
# =============================================================

def main():
    app = Application.builder().token(BOT_TOKEN).build()

    conv = ConversationHandler(
        entry_points=[
            CommandHandler("start", start),
            CommandHandler("menu",  start),
        ],
        states={
            SELECTING_ACTION: [CallbackQueryHandler(button_handler)],
            GET_USERNAME_CREATE: [
                MessageHandler(filters.TEXT & ~filters.COMMAND, h_create_nick),
                CallbackQueryHandler(unexpected_button),
            ],
            GET_EXPIRY_DAYS_CREATE: [
                MessageHandler(filters.TEXT & ~filters.COMMAND, h_create_days),
                CallbackQueryHandler(unexpected_button),
            ],
            GET_USER_TO_DELETE: [
                MessageHandler(filters.TEXT & ~filters.COMMAND, h_delete),
                CallbackQueryHandler(unexpected_button),
            ],
            GET_USER_TO_BLOCK: [
                MessageHandler(filters.TEXT & ~filters.COMMAND, h_block),
                CallbackQueryHandler(unexpected_button),
            ],
            GET_USER_TO_UNBLOCK: [
                MessageHandler(filters.TEXT & ~filters.COMMAND, h_unblock),
                CallbackQueryHandler(unexpected_button),
            ],
            GET_USER_TO_RENEW: [
                MessageHandler(filters.TEXT & ~filters.COMMAND, h_renew_nick),
                CallbackQueryHandler(unexpected_button),
            ],
            GET_DAYS_TO_RENEW: [
                MessageHandler(filters.TEXT & ~filters.COMMAND, h_renew_days),
                CallbackQueryHandler(unexpected_button),
            ],
        },
        fallbacks=[CommandHandler("cancel", cancel_op)],
        allow_reentry=True,
    )
    app.add_handler(conv)
    logger.info("TURBONET XRAY Bot V1.4 iniciado. Admin ID: %d", ADMIN_ID)
    app.run_polling()


if __name__ == "__main__":
    main()
