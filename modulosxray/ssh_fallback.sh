#!/bin/bash
# ssh_fallback.sh - TURBONET XRAY V2.0 (OpenSSH Nativo)
# Integração total do Xray XHTTP com o OpenSSH da VPS:
#   - Sem Dropbear! Usa o OpenSSH nativo da VPS na porta 22 (mais leve e rápido).
#   - Xray Fallback (Porta 443 -> 22)
#   - Proxy Unificado Porta 80 (TCP Direto e WebSocket -> 22).
#   - Roteamento inteligente na porta 80 ideal para Azion e Vercel.

set -Eeuo pipefail
trap 'echo -e "\n\033[1;31m[ERRO]\033[0m Falha na linha $LINENO"; sleep 2' ERR

CONFIG_PATH="/usr/local/etc/xray/config.json"
USER_DB="/opt/XrayTools/users.db"
SSH_PORT=22
LOG_FILE="/tmp/ssh_fallback.log"

TXT_GREEN='\033[1;32m'
TXT_RED='\033[1;31m'
TXT_CYAN='\033[1;36m'
TXT_YELLOW='\033[1;33m'
TITLE_BAR='\033[1;47;34m'
RESET='\033[0m'

[ "${EUID:-$(id -u)}" -ne 0 ] && { echo -e "${TXT_RED}❌ Execute como root!${RESET}"; exit 1; }

export DEBIAN_FRONTEND=noninteractive

_PKG_MANAGER=""
_APT_UPDATED=0
_detect_pkg_manager() {
    [ -n "$_PKG_MANAGER" ] && return
    if   command -v apt-get &>/dev/null; then _PKG_MANAGER="apt"
    elif command -v dnf     &>/dev/null; then _PKG_MANAGER="dnf"
    elif command -v yum     &>/dev/null; then _PKG_MANAGER="yum"
    else echo -e "${TXT_RED}❌ Gerenciador não detectado.${RESET}"; exit 1; fi
}

ensure_pkg() {
    local bin="$1" pkg="$2"
    command -v "$bin" &>/dev/null && return 0
    _detect_pkg_manager
    case "$_PKG_MANAGER" in
        apt)
            [ "$_APT_UPDATED" -eq 0 ] && {
                apt-get update -y >>"$LOG_FILE" 2>&1 || true
                _APT_UPDATED=1
            }
            apt-get install -y "$pkg" >>"$LOG_FILE" 2>&1 ;;
        dnf|yum) "$_PKG_MANAGER" install -y "$pkg" >>"$LOG_FILE" 2>&1 ;;
    esac
}

_apply_config_perms() {
    chmod 0640 "$CONFIG_PATH"
    chown root:nogroup "$CONFIG_PATH"
}

_wait_xray_active() {
    local tries=5
    while [ "$tries" -gt 0 ]; do
        systemctl is-active --quiet xray 2>/dev/null && return 0
        sleep 1; tries=$(( tries - 1 ))
    done
    return 1
}

# --- STATUS ---
_openssh_status() {
    if systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null; then
        echo -e "${TXT_GREEN}ATIVO (OpenSSH na porta 22)${RESET}"
    else
        echo -e "${TXT_RED}INATIVO (Verifique seu serviço SSH)${RESET}"
    fi
}

_xray_fallback_status() {
    [ ! -s "$CONFIG_PATH" ] && { echo -e "${TXT_RED}config não encontrado${RESET}"; return; }
    local fb
    fb=$(jq -r '.inbounds[]? | select(.tag=="inbound-turbonet") |
         .settings.fallbacks[]? | select(.dest==22) | .dest' \
         "$CONFIG_PATH" 2>/dev/null || echo "")
    [ -n "$fb" ] && echo -e "${TXT_GREEN}CONFIGURADO (443→22)${RESET}" || \
                    echo -e "${TXT_RED}NÃO CONFIGURADO${RESET}"
}

_proxy80_status() {
    systemctl is-active --quiet turbonet-proxy80 2>/dev/null && \
        echo -e "${TXT_GREEN}ATIVO (TCP+WS porta 80)${RESET}" || \
        echo -e "${TXT_RED}INATIVO${RESET}"
}

# --- CONFIGURAR FALLBACK NO XRAY (443 → 22) ---
_configure_xray_fallback() {
    echo -e "${TXT_YELLOW}Configurando fallback SSH no Xray (443→22)...${RESET}"

    [ -s "$CONFIG_PATH" ] || { echo -e "${TXT_RED}❌ config.json não encontrado.${RESET}"; return 1; }
    jq empty "$CONFIG_PATH" 2>/dev/null || { echo -e "${TXT_RED}❌ config.json inválido.${RESET}"; return 1; }

    local proto
    proto=$(jq -r '.inbounds[]? | select(.tag=="inbound-turbonet") | .protocol // ""' \
            "$CONFIG_PATH" 2>/dev/null || echo "")

    if [ "$proto" != "vless" ]; then
        echo -e "${TXT_RED}❌ Fallback SSH requer protocolo VLESS.${RESET}"
        return 1
    fi

    cp -f "$CONFIG_PATH" "${CONFIG_PATH}.bak"
    local tmp; tmp=$(mktemp "${CONFIG_PATH}.tmp.XXXXXX")

    jq '(.inbounds[] | select(.tag=="inbound-turbonet") | .settings.fallbacks) =
        [{"name":"","alpn":"","path":"/ssh","dest":22,"xver":0},
         {"name":"","alpn":"","path":"","dest":22,"xver":0}]' \
        "$CONFIG_PATH" > "$tmp" 2>>"$LOG_FILE"

    if ! jq empty "$tmp" 2>/dev/null; then
        echo -e "${TXT_RED}❌ Falha ao gerar config.${RESET}"
        rm -f "$tmp"; return 1
    fi

    mv -f "$tmp" "$CONFIG_PATH"
    _apply_config_perms

    if ! systemctl restart xray >/dev/null 2>&1 || ! _wait_xray_active; then
        echo -e "${TXT_RED}❌ Xray falhou. Revertendo...${RESET}"
        mv -f "${CONFIG_PATH}.bak" "$CONFIG_PATH"
        _apply_config_perms
        systemctl restart xray >/dev/null 2>&1 || true
        return 1
    fi
    echo -e "${TXT_GREEN}✅ Fallback configurado: porta 443 → OpenSSH :22${RESET}"
}

# --- REMOVER FALLBACK DO XRAY ---
_remove_xray_fallback() {
    cp -f "$CONFIG_PATH" "${CONFIG_PATH}.bak"
    local tmp; tmp=$(mktemp "${CONFIG_PATH}.tmp.XXXXXX")

    jq '(.inbounds[] | select(.tag=="inbound-turbonet") | .settings.fallbacks) = []' \
        "$CONFIG_PATH" > "$tmp" 2>/dev/null

    if jq empty "$tmp" 2>/dev/null; then
        mv -f "$tmp" "$CONFIG_PATH"
        _apply_config_perms
        systemctl restart xray >/dev/null 2>&1 || true
        echo -e "${TXT_GREEN}✅ Fallbacks removidos.${RESET}"
    else
        rm -f "$tmp"
        echo -e "${TXT_RED}❌ Falha ao remover fallbacks.${RESET}"
    fi
}

# --- PROXY UNIFICADO PORTA 80 ---
_setup_proxy80() {
    echo -e "${TXT_YELLOW}Configurando proxy SSH na porta 80 (TCP + WebSocket)...${RESET}"

    if ss -tlnp 2>/dev/null | grep -q ":80 "; then
        echo -e "${TXT_YELLOW}⚠  Porta 80 em uso. Liberando...${RESET}"
        systemctl stop nginx   2>/dev/null || true
        systemctl stop apache2 2>/dev/null || true
        fuser -k 80/tcp 2>/dev/null || true
        sleep 1
    fi

    ensure_pkg python3 python3

    cat > /usr/local/bin/turbonet-proxy80.py << 'PYEOF'
#!/usr/bin/env python3
import asyncio, base64, hashlib, os

LISTEN_PORT = 80
SSH_HOST    = "127.0.0.1"
SSH_PORT    = 22
WS_MAGIC    = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

async def pipe(src_r, dst_w):
    try:
        while True:
            data = await src_r.read(4096)
            if not data:
                break
            dst_w.write(data)
            await dst_w.drain()
    except Exception:
        pass

def ws_accept_key(key: bytes) -> str:
    combined = key + WS_MAGIC.encode()
    return base64.b64encode(hashlib.sha1(combined).digest()).decode()

async def handle_client(reader, writer):
    try:
        peek = await reader.read(8)
        if not peek:
            return
        if peek[:3] in (b"GET", b"POS", b"PUT", b"HEA", b"OPT"):
            rest = b""
            if b"\r\n\r\n" not in peek:
                rest = await reader.read(8192)
            full_head = peek + rest
            head_lower = full_head.lower()
            is_ws = b"upgrade: websocket" in head_lower or b"upgrade:websocket" in head_lower
            if is_ws:
                ws_key = b""
                for line in full_head.split(b"\r\n"):
                    if line.lower().startswith(b"sec-websocket-key:"):
                        ws_key = line.split(b":", 1)[1].strip()
                        break
                accept = ws_accept_key(ws_key)
                response = (
                    b"HTTP/1.1 101 Switching Protocols\r\n"
                    b"Upgrade: websocket\r\n"
                    b"Connection: Upgrade\r\n"
                    b"Sec-WebSocket-Accept: " + accept.encode() + b"\r\n\r\n"
                )
                writer.write(response)
                await writer.drain()
                ssh_r, ssh_w = await asyncio.open_connection(SSH_HOST, SSH_PORT)
                await asyncio.gather(ws_to_ssh(reader, ssh_w), ssh_to_ws(ssh_r, writer))
            else:
                ssh_r, ssh_w = await asyncio.open_connection(SSH_HOST, SSH_PORT)
                ssh_w.write(full_head)
                await ssh_w.drain()
                await asyncio.gather(pipe(reader, ssh_w), pipe(ssh_r, writer))
        else:
            ssh_r, ssh_w = await asyncio.open_connection(SSH_HOST, SSH_PORT)
            ssh_w.write(peek)
            await ssh_w.drain()
            await asyncio.gather(pipe(reader, ssh_w), pipe(ssh_r, writer))
    except Exception:
        pass
    finally:
        try:
            writer.close()
        except Exception:
            pass

async def ws_to_ssh(ws_reader, ssh_writer):
    try:
        while True:
            header = await ws_reader.readexactly(2)
            opcode = header[0] & 0x0F
            masked = bool(header[1] & 0x80)
            length = header[1] & 0x7F
            if length == 126:
                ext = await ws_reader.readexactly(2)
                length = int.from_bytes(ext, "big")
            elif length == 127:
                ext = await ws_reader.readexactly(8)
                length = int.from_bytes(ext, "big")
            mask_key = await ws_reader.readexactly(4) if masked else b""
            payload = await ws_reader.readexactly(length)
            if masked:
                payload = bytes(b ^ mask_key[i % 4] for i, b in enumerate(payload))
            if opcode == 0x8:
                break
            if opcode in (0x1, 0x2, 0x0):
                ssh_writer.write(payload)
                await ssh_writer.drain()
    except Exception:
        pass
    finally:
        ssh_writer.close()

async def ssh_to_ws(ssh_reader, ws_writer):
    try:
        while True:
            data = await ssh_reader.read(4096)
            if not data:
                break
            n = len(data)
            if n < 126:
                header = bytes([0x82, n])
            elif n <= 65535:
                header = bytes([0x82, 126]) + n.to_bytes(2, "big")
            else:
                header = bytes([0x82, 127]) + n.to_bytes(8, "big")
            ws_writer.write(header + data)
            await ws_writer.drain()
    except Exception:
        pass

async def main():
    srv = await asyncio.start_server(handle_client, "0.0.0.0", LISTEN_PORT)
    async with srv:
        await srv.serve_forever()

if __name__ == "__main__":
    asyncio.run(main())
PYEOF

    chmod 755 /usr/local/bin/turbonet-proxy80.py

    cat > /etc/systemd/system/turbonet-proxy80.service << 'SVCEOF'
[Unit]
Description=TURBONET XRAY SSH Proxy porta 80 (TCP + WebSocket)
After=network.target ssh.service sshd.service

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/turbonet-proxy80.py
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
SVCEOF

    systemctl daemon-reload
    systemctl enable  turbonet-proxy80 >/dev/null 2>&1
    systemctl restart turbonet-proxy80 >/dev/null 2>&1
    sleep 2

    local pub_ip
    pub_ip=$(curl -4fsSL --max-time 5 https://icanhazip.com 2>/dev/null || echo "SEU_IP")

    if systemctl is-active --quiet turbonet-proxy80 2>/dev/null; then
        echo ""
        echo -e "${TXT_GREEN}================================================${RESET}"
        echo -e "${TXT_GREEN}✅ PROXY SSH PORTA 80 ATIVO (TCP + WebSocket)${RESET}"
        echo -e "${TXT_GREEN}================================================${RESET}"
        echo ""
        echo -e " ${TXT_CYAN}Modos na porta 80:${RESET}"
        echo -e "  TCP direto:   ${TXT_YELLOW}${pub_ip}:80${RESET}"
        echo -e "  WebSocket:    ${TXT_YELLOW}ws://${pub_ip}:80${RESET}"
        echo ""
        echo -e " ${TXT_CYAN}Via Azion CDN:${RESET}"
        echo -e "  ${TXT_YELLOW}ws://turbonet.azion.app:80${RESET} ou ${TXT_YELLOW}turbonet.azion.app:80${RESET}"
        echo -e "${TXT_GREEN}================================================${RESET}"
    else
        echo -e "${TXT_RED}❌ Falha ao iniciar proxy porta 80.${RESET}"
    fi
}

_remove_proxy80() {
    systemctl stop    turbonet-proxy80 >/dev/null 2>&1 || true
    systemctl disable turbonet-proxy80 >/dev/null 2>&1 || true
    rm -f /etc/systemd/system/turbonet-proxy80.service
    rm -f /usr/local/bin/turbonet-proxy80.py
    systemctl daemon-reload
    echo -e "${TXT_GREEN}✅ Proxy porta 80 removido.${RESET}"
}

# --- SINCRONIZAR USERS.DB → SSH ---
_sync_ssh_users() {
    echo -e "${TXT_YELLOW}Sincronizando usuários DB → SSH...${RESET}"
    local count=0
    [ -s "$USER_DB" ] || { echo -e "${TXT_YELLOW}DB vazio.${RESET}"; return; }

    while IFS='|' read -r nick uuid expiry pass limit _rest; do
        [ -n "${nick:-}" ] && [ -n "${pass:-}" ] || continue

        local exp_ts today_ts
        exp_ts=$(date -d "${expiry:-2000-01-01}" +%s 2>/dev/null || echo 0)
        today_ts=$(date +%s)

        if [ "$exp_ts" -lt "$today_ts" ]; then
            id "$nick" &>/dev/null && userdel "$nick" 2>/dev/null || true
            continue
        fi

        local locked=false
        jq -e --arg lock "LOCKED_${nick}" '
            any(.inbounds[]? | select(.tag=="inbound-turbonet").settings.clients[]?;
                .email == $lock)' "$CONFIG_PATH" >/dev/null 2>&1 && locked=true

        if [ "$locked" = "true" ]; then
            id "$nick" &>/dev/null && passwd -l "$nick" >/dev/null 2>&1 || true
            continue
        fi

        id "$nick" &>/dev/null || useradd -M -s /bin/false "$nick" 2>/dev/null || true
        echo "${nick}:${pass}" | chpasswd 2>/dev/null || true
        count=$(( count + 1 ))
    done < "$USER_DB"

    echo -e "${TXT_GREEN}✅ Sincronização concluída: ${count} usuário(s).${RESET}"
}

_show_info() {
    local pub_ip
    pub_ip=$(curl -4fsSL --max-time 5 https://icanhazip.com 2>/dev/null || echo "SEU_IP")
    local preset_domain=""
    [ -f "/usr/local/etc/xray/preset.json" ] && \
        preset_domain=$(jq -r '.domain // ""' /usr/local/etc/xray/preset.json 2>/dev/null || echo "")

    clear
    echo -e "${TITLE_BAR}   INFO DE CONEXÃO SSH XHTTP   ${RESET}"
    echo ""
    echo -e "${TXT_CYAN}━━━━ MODO XHTTP/VLESS (Xray) ━━━━━━━━━━━━━━━${RESET}"
    echo -e " Host: ${TXT_YELLOW}${pub_ip}${RESET} ou ${TXT_YELLOW}${preset_domain:-domínio CDN}${RESET}"
    echo -e " Porta: ${TXT_YELLOW}443${RESET} | Protocolo: XHTTP | UUID do usuário"
    echo ""
    echo -e "${TXT_CYAN}━━━━ MODO SSH DIRETO ━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e " Host: ${TXT_YELLOW}${pub_ip}${RESET}"
    echo -e " Porta: ${TXT_YELLOW}443${RESET} (via Xray fallback)"
    echo -e " Usuário/Senha: Do painel | UDPGW: 127.0.0.1:7300"
    echo ""
    echo -e "${TXT_CYAN}━━━━ MODO SSH PROXY UNIFICADO (porta 80) ━━━${RESET}"
    echo -e " Suporta TCP direto E WebSocket na mesma porta"
    echo -e " Host: ${TXT_YELLOW}${pub_ip}${RESET} | Porta: ${TXT_YELLOW}80${RESET}"
    echo -e " URL WS: ${TXT_YELLOW}ws://${pub_ip}:80${RESET}"
    echo ""
    read -rp "Enter para voltar..."
}

# --- MENU ---
while true; do
    clear
    echo -e "${TITLE_BAR}   SSH FALLBACK + PROXY — TURBONET XRAY   ${RESET}"
    echo ""
    echo -e " Servidor SSH:   $(_openssh_status)"
    echo -e " Xray Fallback:  $(_xray_fallback_status)"
    echo -e " Proxy Unificado: $(_proxy80_status)"
    echo ""
    echo -e "${TXT_GREEN}[1] Instalação completa (recomendado)${RESET}"
    echo "    → Xray fallback + Proxy 80 Unificado (usa o OpenSSH da VPS)"
    echo ""
    echo -e "${TXT_CYAN}[2] Configurar fallback no Xray (443→22)${RESET}"
    echo -e "${TXT_CYAN}[3] Ativar Proxy Unificado (Porta 80 TCP+WS)${RESET}"
    echo -e "${TXT_CYAN}[4] Sincronizar usuários DB → SSH${RESET}"
    echo -e "${TXT_CYAN}[5] Criar usuário SSH manualmente${RESET}"
    echo -e "${TXT_CYAN}[6] Ver info de conexão${RESET}"
    echo -e "${TXT_CYAN}[7] Ver logs OpenSSH${RESET}"
    echo -e "${TXT_RED}[8] Remover Proxy (Porta 80)${RESET}"
    echo -e "${TXT_RED}[9] Remover tudo (fallback + proxy)${RESET}"
    echo -e "${TXT_CYAN}[0] Voltar${RESET}"
    echo "-----------------------------------------"
    read -rp "Opção: " opt

    case "${opt:-0}" in
        1)
            _configure_xray_fallback && \
            _setup_proxy80 && \
            _sync_ssh_users
            read -rp "Enter..."
            ;;
        2) _configure_xray_fallback;   read -rp "Enter..." ;;
        3) _setup_proxy80;             read -rp "Enter..." ;;
        4) _sync_ssh_users;            read -rp "Enter..." ;;
        5)
            read -rp "Nome: " sn; read -rp "Senha: " sp
            sn=$(echo "${sn:-}" | tr -d '[:space:]')
            sp=$(echo "${sp:-}" | tr -d '[:space:]')
            if [ -n "$sn" ] && [ -n "$sp" ]; then
                id "$sn" &>/dev/null || useradd -M -s /bin/false "$sn" 2>/dev/null || true
                echo "${sn}:${sp}" | chpasswd
                echo -e "${TXT_GREEN}✅ Usuário SSH '${sn}' criado/atualizado.${RESET}"
            else
                echo -e "${TXT_RED}Nome ou senha inválidos.${RESET}"
            fi
            read -rp "Enter..."
            ;;
        6) _show_info ;;
        7)
            journalctl -u ssh -u sshd -n 30 --no-pager 2>/dev/null || \
                echo "Sem logs."
            read -rp "Enter..."
            ;;
        8)
            _remove_proxy80
            read -rp "Enter..."
            ;;
        9)
            read -rp "Remover Fallback e Proxy? [s/N]: " conf
            [[ "${conf:-n}" =~ ^[Ss]$ ]] || { echo "Cancelado."; sleep 1; continue; }
            _remove_xray_fallback
            _remove_proxy80
            echo -e "${TXT_GREEN}✅ Tudo removido.${RESET}"
            read -rp "Enter..."
            ;;
        0) exit 0 ;;
        *) echo -e "${TXT_RED}Inválido.${RESET}"; sleep 1 ;;
    esac
done
