#!/bin/bash

# ============================================================================
# install.sh - INSTALADOR COMPLETO XRAY2026
# Script de Instalação do Gerenciador Xray com Interface de Gerenciamento
# ============================================================================

# Autor: PhoenixxZ2023
# Versão: 2.0 - Com correções automáticas e suporte completo
# Repositório: https://github.com/PhoenixxZ2023/xray2026

# ════════════════════════════════════════════════════════════════════════
# VARIÁVEIS GLOBAIS
# ════════════════════════════════════════════════════════════════════════

REPO="PhoenixxZ2023/xray2026"
XRAY_REPO="XTLS/Xray-core"

# Diretórios
INSTALL_DIR="/etc/xray"
SH_DIR="/etc/xray/sh"
CONF_DIR="/etc/xray/conf"
LOG_DIR="/var/log/xray"
USERS_DIR="/etc/xray/users"

# Binários
XRAY_BIN="/usr/local/bin/xray"
SH_BIN="/usr/local/bin/xray"

# Cores
RED='\e[31m'
GREEN='\e[92m'
YELLOW='\e[33m'
BLUE='\e[94m'
CYAN='\e[36m'
NONE='\e[0m'

# Funções de cores
_red() { echo -e "${RED}$@${NONE}"; }
_green() { echo -e "${GREEN}$@${NONE}"; }
_yellow() { echo -e "${YELLOW}$@${NONE}"; }
_blue() { echo -e "${BLUE}$@${NONE}"; }
_cyan() { echo -e "${CYAN}$@${NONE}"; }

msg() {
    case "$1" in
        ok) _green "$2" ;;
        error) _red "$2" ;;
        warn) _yellow "$2" ;;
        info) _blue "$2" ;;
        *) echo "$1" ;;
    esac
}

# ════════════════════════════════════════════════════════════════════════
# VERIFICAÇÕES INICIAIS
# ════════════════════════════════════════════════════════════════════════

check_root() {
    if [[ $EUID -ne 0 ]]; then
        msg error "Este script deve ser executado como root (use sudo)"
        exit 1
    fi
}

check_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        OS_VER=$VERSION_ID
    else
        msg error "Sistema operacional não suportado"
        exit 1
    fi
}

check_arch() {
    ARCH=$(uname -m)
    case $ARCH in
        x86_64|amd64)
            ARCH="64"
            ;;
        aarch64|arm64)
            ARCH="arm64-v8a"
            ;;
        armv7l)
            ARCH="arm32-v7a"
            ;;
        *)
            msg error "Arquitetura não suportada: $ARCH"
            exit 1
            ;;
    esac
}

check_dependencies() {
    msg info "Verificando dependências..."
    
    local deps=("curl" "wget" "jq" "systemctl" "unzip")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        msg warn "Instalando dependências: ${missing[*]}"
        
        if command -v apt-get &>/dev/null; then
            apt-get update -qq
            apt-get install -y "${missing[@]}"
        elif command -v yum &>/dev/null; then
            yum install -y "${missing[@]}"
        elif command -v dnf &>/dev/null; then
            dnf install -y "${missing[@]}"
        else
            msg error "Gerenciador de pacotes não suportado"
            exit 1
        fi
    fi
    
    msg ok "Dependências verificadas"
}

# ════════════════════════════════════════════════════════════════════════
# FUNÇÕES DE DOWNLOAD
# ════════════════════════════════════════════════════════════════════════

get_latest_version() {
    local repo="$1"
    local version=$(curl -sL "https://api.github.com/repos/$repo/releases/latest" | jq -r '.tag_name')
    
    if [[ -z "$version" || "$version" == "null" ]]; then
        msg error "Falha ao obter versão mais recente de $repo"
        exit 1
    fi
    
    echo "$version"
}

download_xray() {
    msg info "Baixando Xray-core..."
    
    local version=$(get_latest_version "$XRAY_REPO")
    local download_url="https://github.com/$XRAY_REPO/releases/download/${version}/Xray-linux-${ARCH}.zip"
    
    msg info "Versão: $version"
    msg info "URL: $download_url"
    
    local tmp_dir=$(mktemp -d)
    cd "$tmp_dir"
    
    if ! wget -q --show-progress "$download_url"; then
        msg error "Falha ao baixar Xray-core"
        rm -rf "$tmp_dir"
        exit 1
    fi
    
    if ! unzip -q "Xray-linux-${ARCH}.zip"; then
        msg error "Falha ao extrair Xray-core"
        rm -rf "$tmp_dir"
        exit 1
    fi
    
    # Instalar binário
    install -m 755 xray "$XRAY_BIN"
    
    cd - > /dev/null
    rm -rf "$tmp_dir"
    
    msg ok "Xray-core instalado: $version"
}

download_scripts() {
    msg info "Baixando scripts de gerenciamento..."
    
    local tmp_dir=$(mktemp -d)
    cd "$tmp_dir"
    
    if ! wget -q "https://github.com/$REPO/archive/refs/heads/main.zip"; then
        msg error "Falha ao baixar scripts"
        rm -rf "$tmp_dir"
        exit 1
    fi
    
    if ! unzip -q main.zip; then
        msg error "Falha ao extrair scripts"
        rm -rf "$tmp_dir"
        exit 1
    fi
    
    # Criar diretórios
    mkdir -p "$SH_DIR/src"
    mkdir -p "$CONF_DIR"
    mkdir -p "$LOG_DIR"
    mkdir -p "$USERS_DIR"
    
    # Copiar arquivos
    cp -r xray2026-main/src/* "$SH_DIR/src/"
    cp xray2026-main/xray.sh "$SH_DIR/"
    
    # Criar link simbólico
    ln -sf "$SH_DIR/xray.sh" "$SH_BIN"
    chmod +x "$SH_DIR/xray.sh"
    chmod +x "$SH_DIR/src/"*.sh
    
    cd - > /dev/null
    rm -rf "$tmp_dir"
    
    msg ok "Scripts instalados"
}

download_geodata() {
    msg info "Baixando geodata (geoip e geosite)..."
    
    local geoip_url="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
    local geosite_url="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"
    
    wget -q --show-progress -O "$INSTALL_DIR/geoip.dat" "$geoip_url"
    wget -q --show-progress -O "$INSTALL_DIR/geosite.dat" "$geosite_url"
    
    msg ok "Geodata instalado"
}

# ════════════════════════════════════════════════════════════════════════
# CONFIGURAÇÃO DO SISTEMA
# ════════════════════════════════════════════════════════════════════════

create_systemd_service() {
    msg info "Criando serviço systemd..."
    
    cat > /etc/systemd/system/xray.service <<EOF
[Unit]
Description=Xray Service
Documentation=https://github.com/xtls
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=$XRAY_BIN run -config $INSTALL_DIR/config.json -confdir $CONF_DIR
Restart=on-failure
RestartPreventExitStatus=23
StandardOutput=journal
StandardError=journal
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable xray
    
    msg ok "Serviço systemd criado"
}

create_initial_config() {
    msg info "Criando configuração inicial..."
    
    cat > "$INSTALL_DIR/config.json" <<EOF
{
  "log": {
    "loglevel": "warning",
    "access": "$LOG_DIR/access.log",
    "error": "$LOG_DIR/error.log"
  },
  "inbounds": [],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {},
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "blocked"
    }
  ],
  "routing": {
    "rules": []
  }
}
EOF
    
    msg ok "Configuração inicial criada"
}

# ════════════════════════════════════════════════════════════════════════
# INSTALAÇÕES ADICIONAIS
# ════════════════════════════════════════════════════════════════════════

install_qrencode() {
    if ! command -v qrencode &>/dev/null; then
        msg info "Instalando qrencode para geração de QR Codes..."
        
        if command -v apt-get &>/dev/null; then
            apt-get install -y qrencode &>/dev/null
        elif command -v yum &>/dev/null; then
            yum install -y qrencode &>/dev/null
        elif command -v dnf &>/dev/null; then
            dnf install -y qrencode &>/dev/null
        fi
        
        msg ok "qrencode instalado"
    fi
}

install_dnsutils() {
    if ! command -v dig &>/dev/null; then
        msg info "Instalando dnsutils para verificação DNS..."
        
        if command -v apt-get &>/dev/null; then
            apt-get install -y dnsutils &>/dev/null
        elif command -v yum &>/dev/null; then
            yum install -y bind-utils &>/dev/null
        elif command -v dnf &>/dev/null; then
            dnf install -y bind-utils &>/dev/null
        fi
        
        msg ok "dnsutils instalado"
    fi
}

install_uuid() {
    if ! command -v uuidgen &>/dev/null; then
        msg info "Instalando uuid-runtime..."
        
        if command -v apt-get &>/dev/null; then
            apt-get install -y uuid-runtime &>/dev/null
        fi
        
        msg ok "uuid-runtime instalado"
    fi
}

# ════════════════════════════════════════════════════════════════════════
# CORREÇÕES AUTOMÁTICAS
# ════════════════════════════════════════════════════════════════════════

apply_automatic_fixes() {
    echo
    msg ok "Aplicando correções automáticas..."
    echo
    
    # Correção 1: Garantir is_sh_dir correto no core.sh
    if grep -q '^is_sh_dir="/etc/xray"$' "$SH_DIR/src/core.sh" 2>/dev/null; then
        sed -i 's|^is_sh_dir="/etc/xray"$|is_sh_dir="/etc/xray/sh"|' "$SH_DIR/src/core.sh"
        msg ok "✓ Variável is_sh_dir corrigida"
    fi
    
    # Correção 2: Remover main "$@" duplicado no core.sh
    if grep -q '^main "\$@"$' "$SH_DIR/src/core.sh" 2>/dev/null; then
        sed -i '/^main "\$@"$/d' "$SH_DIR/src/core.sh"
        msg ok "✓ Linha main duplicada removida do core.sh"
    fi
    
    # Correção 3: Remover main "$@" duplicado no xray.sh
    if grep -q '^main "\$@"$' "$SH_DIR/xray.sh" 2>/dev/null; then
        sed -i '/^main "\$@"$/d' "$SH_DIR/xray.sh"
        msg ok "✓ Linha main duplicada removida do xray.sh"
    fi
    
    # Correção 4: Corrigir chamada main no init.sh
    if grep -q '^main "\$args"$' "$SH_DIR/src/init.sh" 2>/dev/null; then
        sed -i 's/^main "\$args"$/main "$@"/' "$SH_DIR/src/init.sh"
        msg ok "✓ Chamada main corrigida no init.sh"
    fi
    
    # Correção 5: Criar diretório de usuários se não existir
    if [[ ! -d "$USERS_DIR" ]]; then
        mkdir -p "$USERS_DIR"
        echo "[]" > "$USERS_DIR/users.json"
        msg ok "✓ Diretório de usuários criado"
    fi
    
    # Correção 6: Criar arquivo de configuração ativa vazio
    if [[ ! -f "$INSTALL_DIR/active_config.conf" ]]; then
        touch "$INSTALL_DIR/active_config.conf"
        msg ok "✓ Arquivo de configuração ativa criado"
    fi
    
    echo
    msg ok "✓ Correções aplicadas com sucesso!"
    echo
}

# ════════════════════════════════════════════════════════════════════════
# FUNÇÃO PRINCIPAL DE INSTALAÇÃO
# ════════════════════════════════════════════════════════════════════════

main() {
    clear
    echo
    echo "═══════════════════════════════════════════════════════════"
    echo "  INSTALADOR XRAY2026"
    echo "  Gerenciador Completo de Xray com Interface CLI"
    echo "═══════════════════════════════════════════════════════════"
    echo
    
    # Verificações
    check_root
    check_os
    check_arch
    check_dependencies
    
    echo
    msg info "Sistema operacional: $OS $OS_VER"
    msg info "Arquitetura: $ARCH"
    echo
    
    read -p "Deseja continuar com a instalação? (s/N): " confirm
    if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
        msg warn "Instalação cancelada"
        exit 0
    fi
    
    echo
    msg info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    msg info "INICIANDO INSTALAÇÃO"
    msg info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    
    # Download e instalação
    download_xray
    download_scripts
    download_geodata
    
    # Configuração
    create_initial_config
    create_systemd_service
    
    # Instalações adicionais
    install_qrencode
    install_dnsutils
    install_uuid
    
    # Aplicar correções
    apply_automatic_fixes
    
    # Iniciar serviço
    msg info "Iniciando serviço Xray..."
    systemctl start xray
    
    if systemctl is-active --quiet xray; then
        msg ok "✓ Serviço Xray iniciado com sucesso"
    else
        msg warn "⚠ Serviço Xray não iniciou. Verifique os logs."
    fi
    
    echo
    msg ok "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    msg ok "✓✓✓ INSTALAÇÃO CONCLUÍDA COM SUCESSO! ✓✓✓"
    msg ok "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    
    msg info "Para começar a usar, execute:"
    echo
    _cyan "  xray"
    echo
    msg info "Comandos úteis:"
    _cyan "  xray add              # Adicionar configuração de protocolo"
    _cyan "  xray add-user         # Adicionar usuário"
    _cyan "  xray list-users       # Listar usuários"
    _cyan "  xray help             # Ver todos os comandos"
    echo
    
    msg info "Funcionalidades incluídas:"
    echo "  ✓ Suporte a VLESS-XTLS"
    echo "  ✓ Abreviações de protocolo (vl/vm)"
    echo "  ✓ Geração automática de links"
    echo "  ✓ Geração automática de QR Codes"
    echo "  ✓ Sistema de configuração ativa"
    echo "  ✓ Verificação automática de DNS"
    echo
    
    msg info "Repositório: https://github.com/$REPO"
    echo
}

# Executar instalação
main "$@"
