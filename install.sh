#!/bin/bash

# ============================================================================
# core.sh - VERSÃO COMPLETA COM AS 4 ADIÇÕES
# Sistema Principal de Gerenciamento Xray2026
# ============================================================================

# Autor: PhoenixxZ2023
# Versão: 2.0 (com suporte a VLESS-XTLS e configuração ativa)

# ════════════════════════════════════════════════════════════════════════
# VARIÁVEIS GLOBAIS
# ════════════════════════════════════════════════════════════════════════

is_sh_ver=2.0
is_core=xray
is_core_name=Xray
is_core_dir=/etc/xray
is_conf_dir=/etc/xray/conf
is_config_json=/etc/xray/config.json
is_sh_dir=/etc/xray/sh
is_log_dir=/var/log/xray

# Binários
is_core_bin=/usr/local/bin/xray
is_sh_bin=/usr/local/bin/xray

# Portas padrão
is_http_port=80
is_https_port=443

# Repositórios
is_core_repo=XTLS/Xray-core
is_sh_repo=PhoenixxZ2023/xray2026


# ════════════════════════════════════════════════════════════════════════
# SEÇÃO 2: LISTAS DE PROTOCOLOS (ADIÇÃO 2 AQUI)
# ════════════════════════════════════════════════════════════════════════

# ========== LISTAS DE PROTOCOLOS ==========
protocol_list=(
    VMess-TCP
    VMess-mKCP
    VMess-WS-TLS
    VMess-gRPC-TLS
    VLESS-WS-TLS
    VLESS-gRPC-TLS
    VLESS-XHTTP-TLS
    VLESS-REALITY
    VLESS-XTLS
    Trojan-WS-TLS
    Trojan-gRPC-TLS
    Shadowsocks
    VMess-TCP-dynamic-port
    VMess-mKCP-dynamic-port
    Socks
)

# Métodos de criptografia Shadowsocks
ss_method_list=(
    aes-128-gcm
    aes-256-gcm
    chacha20-ietf-poly1305
    xchacha20-ietf-poly1305
    2022-blake3-aes-128-gcm
    2022-blake3-aes-256-gcm
    2022-blake3-chacha20-poly1305
)


# ════════════════════════════════════════════════════════════════════════
# FUNÇÕES DE CORES E MENSAGENS
# ════════════════════════════════════════════════════════════════════════

_red() { echo -e "\e[31m$@\e[0m"; }
_green() { echo -e "\e[92m$@\e[0m"; }
_yellow() { echo -e "\e[33m$@\e[0m"; }
_blue() { echo -e "\e[94m$@\e[0m"; }
_cyan() { echo -e "\e[36m$@\e[0m"; }


# ════════════════════════════════════════════════════════════════════════
# SEÇÃO 3: FUNÇÕES AUXILIARES (ADIÇÃO 1 AQUI)
# ════════════════════════════════════════════════════════════════════════

# Gerar UUID automaticamente
generate_uuid() {
    if command -v uuidgen >/dev/null 2>&1; then
        uuidgen
    else
        cat /proc/sys/kernel/random/uuid 2>/dev/null || \
        echo "$(cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 32 | head -n 1 | sed 's/\(.\{8\}\)\(.\{4\}\)\(.\{4\}\)\(.\{4\}\)\(.\{12\}\)/\1-\2-\3-\4-\5/')"
    fi
}

# Gerar caminho aleatório
generate_path() {
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1
}

# Perguntar porta
ask_port() {
    local default_port=${1:-443}
    read -p "Digite a porta [$default_port]: " port
    port=${port:-$default_port}
}

# Perguntar domínio
ask_domain() {
    while true; do
        read -p "Digite o domínio: " domain
        
        if [[ -z "$domain" ]]; then
            _red "✗ Domínio não pode ser vazio"
            continue
        fi
        
        # Verificar DNS se dnsutils estiver instalado
        if command -v dig >/dev/null 2>&1; then
            _yellow "⏳ Verificando DNS..."
            local domain_ip=$(dig +short "$domain" | head -n1)
            
            if [[ -n "$domain_ip" ]]; then
                _green "✓ DNS verificado: $domain → $domain_ip"
                break
            else
                _yellow "⚠ Domínio não resolve"
                read -p "Continuar mesmo assim? (s/N): " continue_anyway
                if [[ "$continue_anyway" == "s" || "$continue_anyway" == "S" ]]; then
                    break
                fi
            fi
        else
            break
        fi
    done
    
    echo "$domain"
}


# ════════════════════════════════════════════════════════════════════════
# ADIÇÃO 1: FUNÇÃO save_active_config()
# ════════════════════════════════════════════════════════════════════════

# ========== SALVAR CONFIGURAÇÃO ATIVA ==========
save_active_config() {
    local config_name="$1"
    local protocol="$2"
    local security="$3"
    local flow="$4"
    local port="$5"
    local domain="$6"
    local path="$7"
    
    cat > /etc/xray/active_config.conf <<ACTIVE_CONFIG
# Configuração Ativa do Xray2026
# Gerado automaticamente em: $(date '+%d/%m/%Y %H:%M:%S')

config_name=$config_name
protocol=$protocol
security=$security
flow=$flow
port=$port
domain=$domain
path=$path
ACTIVE_CONFIG
    
    _green "✓ Configuração '$config_name' definida como ativa"
    _green "  Novos usuários herdarão esta configuração"
}


# ════════════════════════════════════════════════════════════════════════
# SEÇÃO 4: FUNÇÕES DE CRIAÇÃO DE PROTOCOLOS (ADIÇÃO 3 AQUI)
# ════════════════════════════════════════════════════════════════════════

# ========== CRIAR VLESS-WS-TLS ==========
create_vless_ws_tls() {
    local config_name="$1"
    
    _blue "Criando configuração VLESS-WS-TLS..."
    
    local uuid=$(generate_uuid)
    local path=$(generate_path)
    ask_port 443
    local domain=$(ask_domain)
    
    cat > "$is_conf_dir/$config_name.json" <<JSON_EOF
{
  "protocol": "vless",
  "port": $port,
  "settings": {
    "clients": [{
      "id": "$uuid",
      "email": "$config_name@vless"
    }],
    "decryption": "none"
  },
  "streamSettings": {
    "network": "ws",
    "security": "tls",
    "tlsSettings": {
      "serverName": "$domain",
      "alpn": ["http/1.1"],
      "certificates": [{
        "certificateFile": "/etc/letsencrypt/live/$domain/fullchain.pem",
        "keyFile": "/etc/letsencrypt/live/$domain/privkey.pem"
      }]
    },
    "wsSettings": {
      "path": "/$path",
      "headers": {"Host": "$domain"}
    }
  }
}
JSON_EOF
    
    save_active_config "$config_name" "vless" "tls" "" "$port" "$domain" "/$path"
    systemctl restart xray
    _green "✓ VLESS-WS-TLS criado com sucesso!"
}

# ========== CRIAR VLESS-REALITY ==========
create_vless_reality() {
    local config_name="$1"
    
    _blue "Criando configuração VLESS-REALITY..."
    
    local uuid=$(generate_uuid)
    ask_port 443
    read -p "SNI (domínio destino) [www.google.com]: " sni
    sni=${sni:-www.google.com}
    
    # Gerar chaves
    local keys=$($is_core_bin x25519)
    local private_key=$(echo "$keys" | grep "Private key" | awk '{print $3}')
    local public_key=$(echo "$keys" | grep "Public key" | awk '{print $3}')
    
    cat > "$is_conf_dir/$config_name.json" <<JSON_EOF
{
  "protocol": "vless",
  "port": $port,
  "settings": {
    "clients": [{
      "id": "$uuid",
      "flow": "xtls-rprx-vision"
    }],
    "decryption": "none"
  },
  "streamSettings": {
    "network": "tcp",
    "security": "reality",
    "realitySettings": {
      "dest": "$sni:443",
      "serverNames": ["$sni"],
      "privateKey": "$private_key",
      "shortIds": [""]
    }
  }
}
JSON_EOF
    
    save_active_config "$config_name" "vless" "reality" "xtls-rprx-vision" "$port" "$sni" ""
    systemctl restart xray
    
    _green "✓ VLESS-REALITY criado!"
    _green "Chave pública: $public_key"
}


# ════════════════════════════════════════════════════════════════════════
# ADIÇÃO 3: FUNÇÃO create_vless_xtls() COMPLETA
# ════════════════════════════════════════════════════════════════════════

# ========== CRIAR VLESS-XTLS ==========
create_vless_xtls() {
    local config_name="$1"
    
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  CRIAR CONFIGURAÇÃO VLESS-XTLS"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    # Gerar UUID automaticamente
    local uuid=$(generate_uuid)
    _green "✓ UUID gerado: $uuid"
    
    # Gerar caminho automaticamente
    local path=$(generate_path)
    _green "✓ Caminho gerado: /$path"
    
    echo ""
    
    # Solicitar porta
    read -p "Digite a porta [443]: " port
    port=${port:-443}
    
    # Solicitar domínio
    local domain=$(ask_domain)
    
    echo ""
    echo "─────────────────────────────────────────────────────────"
    echo "  RESUMO DA CONFIGURAÇÃO"
    echo "─────────────────────────────────────────────────────────"
    echo "  Nome:      $config_name"
    echo "  Protocolo: VLESS-XTLS"
    echo "  UUID:      $uuid"
    echo "  Porta:     $port"
    echo "  Domínio:   $domain"
    echo "  Caminho:   /$path"
    echo "  Segurança: XTLS"
    echo "  Flow:      xtls-rprx-vision"
    echo "─────────────────────────────────────────────────────────"
    echo ""
    
    read -p "Confirmar criação? (S/n): " confirm
    if [[ "$confirm" == "n" || "$confirm" == "N" ]]; then
        _yellow "Criação cancelada"
        return 1
    fi
    
    echo ""
    _yellow "⏳ Criando configuração VLESS-XTLS..."
    
    # Criar arquivo de configuração JSON
    cat > "$is_conf_dir/$config_name.json" <<JSON_EOF
{
  "protocol": "vless",
  "port": $port,
  "settings": {
    "clients": [
      {
        "id": "$uuid",
        "flow": "xtls-rprx-vision",
        "email": "$config_name@xtls"
      }
    ],
    "decryption": "none"
  },
  "streamSettings": {
    "network": "ws",
    "security": "xtls",
    "xtlsSettings": {
      "serverName": "$domain",
      "alpn": ["http/1.1"],
      "certificates": [
        {
          "certificateFile": "/etc/letsencrypt/live/$domain/fullchain.pem",
          "keyFile": "/etc/letsencrypt/live/$domain/privkey.pem"
        }
      ]
    },
    "wsSettings": {
      "path": "/$path",
      "headers": {
        "Host": "$domain"
      }
    }
  },
  "sniffing": {
    "enabled": true,
    "destOverride": ["http", "tls"]
  }
}
JSON_EOF
    
    # Salvar informações da configuração
    cat > "$is_conf_dir/$config_name.info" <<INFO_EOF
name=$config_name
protocol=vless
uuid=$uuid
address=$domain
port=$port
network=ws
path=/$path
security=xtls
flow=xtls-rprx-vision
sni=$domain
INFO_EOF
    
    # Salvar como configuração ativa
    save_active_config "$config_name" "vless" "xtls" "xtls-rprx-vision" "$port" "$domain" "/$path"
    
    # Reiniciar serviço Xray
    _yellow "⏳ Reiniciando serviço Xray..."
    systemctl restart xray 2>/dev/null
    
    if systemctl is-active --quiet xray; then
        _green "✓ Serviço Xray reiniciado com sucesso"
    else
        _red "✗ Erro ao reiniciar Xray - verifique os logs"
        _yellow "  Execute: journalctl -u xray -n 50"
    fi
    
    echo ""
    _green "✓✓✓ CONFIGURAÇÃO VLESS-XTLS CRIADA COM SUCESSO! ✓✓✓"
    echo ""
    
    # Gerar link de compartilhamento
    local link="vless://${uuid}@${domain}:${port}?type=ws&security=xtls&flow=xtls-rprx-vision&path=/${path}&sni=${domain}#${config_name}"
    
    echo "═══════════════════════════════════════════════════════════"
    echo "  LINK DE COMPARTILHAMENTO VLESS-XTLS"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "$link"
    echo ""
    
    # Gerar QR Code se disponível
    if command -v qrencode >/dev/null 2>&1; then
        echo "QR Code:"
        echo ""
        qrencode -t ANSIUTF8 "$link"
        echo ""
    else
        _yellow "💡 Instale qrencode: apt install qrencode"
        echo ""
    fi
    
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    _green "Agora você pode:"
    echo "  • Criar usuários: xray add-user nome 30 vl"
    echo "  • Ver configuração: xray info"
    echo "  • Listar usuários: xray list-users"
    echo ""
}


# ════════════════════════════════════════════════════════════════════════
# SEÇÃO 5: SWITCH/CASE DE PROTOCOLOS (ADIÇÃO 4 AQUI)
# ════════════════════════════════════════════════════════════════════════

# Função para criar configuração baseada no protocolo
create_config() {
    local protocol="$1"
    local config_name="$2"
    
    case "$protocol" in
        "VLESS-TCP")
            create_vless_tcp "$config_name"
            ;;
        "VLESS-WS-TLS")
            create_vless_ws_tls "$config_name"
            ;;
        "VLESS-gRPC-TLS")
            create_vless_grpc_tls "$config_name"
            ;;
        "VLESS-XHTTP-TLS")
            create_vless_xhttp_tls "$config_name"
            ;;
        "VLESS-REALITY")
            create_vless_reality "$config_name"
            ;;
        "VLESS-XTLS")
            create_vless_xtls "$config_name"
            ;;
        "VMess-TCP")
            create_vmess_tcp "$config_name"
            ;;
        "VMess-WS-TLS")
            create_vmess_ws_tls "$config_name"
            ;;
        "Trojan-WS-TLS")
            create_trojan_ws_tls "$config_name"
            ;;
        "Shadowsocks")
            create_shadowsocks "$config_name"
            ;;
        *)
            _red "✗ Protocolo não suportado: $protocol"
            return 1
            ;;
    esac
}


# ════════════════════════════════════════════════════════════════════════
# MENU PRINCIPAL
# ════════════════════════════════════════════════════════════════════════

show_protocol_menu() {
    echo ""
    echo "═══════════════════════════════════════"
    echo "  ESCOLHA O PROTOCOLO"
    echo "═══════════════════════════════════════"
    echo ""
    
    local i=1
    for protocol in "${protocol_list[@]}"; do
        echo "  $i) $protocol"
        ((i++))
    done
    
    echo ""
    read -p "Escolha uma opção [1-${#protocol_list[@]}]: " choice
    
    if [[ $choice -ge 1 && $choice -le ${#protocol_list[@]} ]]; then
        local selected_protocol="${protocol_list[$((choice-1))]}"
        
        read -p "Nome da configuração: " config_name
        
        if [[ -z "$config_name" ]]; then
            _red "✗ Nome não pode ser vazio"
            return 1
        fi
        
        create_config "$selected_protocol" "$config_name"
    else
        _red "✗ Opção inválida"
    fi
}


# ════════════════════════════════════════════════════════════════════════
# PONTO DE ENTRADA
# ════════════════════════════════════════════════════════════════════════

main() {
    case "${1:-}" in
        add)
            show_protocol_menu
            ;;
        *)
            _yellow "Use: xray add"
            ;;
    esac
}

# Executar se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
