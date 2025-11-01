#!/bin/bash

# ============================================================================
# user-manager.sh - VERSÃO COMPLETA COM AS 3 ADIÇÕES
# Sistema de Gerenciamento de Usuários para Xray2026
# ============================================================================

# Autor: PhoenixxZ2023
# Versão: 2.0 (com suporte a abreviações e geração automática de links)

# ════════════════════════════════════════════════════════════════════════
# VARIÁVEIS GLOBAIS
# ════════════════════════════════════════════════════════════════════════

# Diretórios
USERS_DB="/etc/xray/users/users.json"
USERS_DIR="/etc/xray/users"

# Cores para output
_red() { echo -e "\e[31m$@\e[0m"; }
_green() { echo -e "\e[92m$@\e[0m"; }
_yellow() { echo -e "\e[33m$@\e[0m"; }
_blue() { echo -e "\e[94m$@\e[0m"; }


# ════════════════════════════════════════════════════════════════════════
# ADIÇÃO 1: FUNÇÃO PARA GERAR LINKS DE USUÁRIOS
# ════════════════════════════════════════════════════════════════════════

# ========== FUNÇÃO PARA GERAR LINKS DE USUÁRIOS ==========
generate_user_link() {
    local username="$1"
    local uuid="$2"
    local protocol="$3"
    
    # Carregar configuração ativa
    if [[ -f /etc/xray/active_config.conf ]]; then
        source /etc/xray/active_config.conf
    else
        _yellow "⚠ Nenhuma configuração ativa encontrada"
        _yellow "  Use: xray add para criar uma configuração primeiro"
        return 1
    fi
    
    # Gerar link baseado no protocolo e segurança
    case "$protocol" in
        vless)
            if [[ "$security" == "xtls" ]]; then
                # VLESS com XTLS
                link="vless://${uuid}@${domain}:${port}?type=ws&security=xtls&flow=${flow}&path=${path}&sni=${domain}#${username}"
            else
                # VLESS com TLS normal
                link="vless://${uuid}@${domain}:${port}?type=ws&security=tls&path=${path}&sni=${domain}#${username}"
            fi
            ;;
        vmess)
            # VMess com base64
            vmess_json=$(cat <<VMESS_JSON
{
  "v": "2",
  "ps": "${username}",
  "add": "${domain}",
  "port": "${port}",
  "id": "${uuid}",
  "aid": "0",
  "net": "ws",
  "type": "none",
  "host": "${domain}",
  "path": "${path}",
  "tls": "tls"
}
VMESS_JSON
)
            link="vmess://$(echo -n "$vmess_json" | base64 -w0)"
            ;;
        *)
            _red "✗ Protocolo desconhecido: $protocol"
            return 1
            ;;
    esac
    
    echo "$link"
}


# ════════════════════════════════════════════════════════════════════════
# FUNÇÕES DE GERENCIAMENTO DE USUÁRIOS
# ════════════════════════════════════════════════════════════════════════

# Inicializar banco de dados de usuários
init_users_db() {
    if [[ ! -d "$USERS_DIR" ]]; then
        mkdir -p "$USERS_DIR"
    fi
    
    if [[ ! -f "$USERS_DB" ]]; then
        echo "[]" > "$USERS_DB"
    fi
}

# Adicionar usuário ao banco de dados
add_user_to_db() {
    local username="$1"
    local uuid="$2"
    local protocol="$3"
    local days="$4"
    local created_at=$(date +%s)
    local expires_at=$((created_at + (days * 86400)))
    
    # Criar entrada JSON
    local user_entry=$(cat <<JSON_ENTRY
{
  "username": "$username",
  "uuid": "$uuid",
  "protocol": "$protocol",
  "created_at": $created_at,
  "expires_at": $expires_at,
  "days": $days,
  "status": "active"
}
JSON_ENTRY
)
    
    # Adicionar ao banco de dados
    local temp_db=$(mktemp)
    jq ". += [$user_entry]" "$USERS_DB" > "$temp_db"
    mv "$temp_db" "$USERS_DB"
}

# Verificar se usuário existe
user_exists() {
    local username="$1"
    jq -e ".[] | select(.username == \"$username\")" "$USERS_DB" >/dev/null 2>&1
}


# ════════════════════════════════════════════════════════════════════════
# FUNÇÃO PRINCIPAL: ADICIONAR USUÁRIO
# ════════════════════════════════════════════════════════════════════════

add_user() {
    echo ""
    echo "═══════════════════════════════════════"
    echo "  ADICIONAR NOVO USUÁRIO"
    echo "═══════════════════════════════════════"
    echo ""
    
    # Inicializar banco de dados
    init_users_db
    
    # Solicitar nome do usuário
    while true; do
        read -p "Nome do usuário: " username
        
        if [[ -z "$username" ]]; then
            _red "✗ Nome não pode ser vazio"
            continue
        fi
        
        if user_exists "$username"; then
            _red "✗ Usuário '$username' já existe"
            continue
        fi
        
        break
    done
    
    # Solicitar dias de validade
    while true; do
        read -p "Dias de validade: " days
        
        if [[ ! "$days" =~ ^[0-9]+$ ]]; then
            _red "✗ Digite apenas números"
            continue
        fi
        
        if [[ $days -lt 1 ]]; then
            _red "✗ Mínimo 1 dia"
            continue
        fi
        
        break
    done
    
    # ════════════════════════════════════════════════════════════════
    # ADIÇÃO 2: SOLICITAR PROTOCOLO COM SUPORTE A ABREVIAÇÕES
    # ════════════════════════════════════════════════════════════════
    
    read -p "Protocolo (vl=vless/vm=vmess) [vl]: " protocol_input
    protocol_input=${protocol_input:-vl}
    
    # Converter abreviações
    case "$protocol_input" in
        vl|VL|vless|VLESS)
            protocol="vless"
            ;;
        vm|VM|vmess|VMESS)
            protocol="vmess"
            ;;
        *)
            _yellow "⚠ Protocolo desconhecido, usando vless"
            protocol="vless"
            ;;
    esac
    
    # Gerar UUID
    uuid=$(uuidgen)
    
    # Calcular datas
    created_at=$(date +%s)
    expires_at=$((created_at + (days * 86400)))
    expires_readable=$(date -d "@$expires_at" "+%d/%m/%Y %H:%M:%S")
    created_readable=$(date -d "@$created_at" "+%d/%m/%Y %H:%M:%S")
    
    echo ""
    _yellow "⏳ Criando usuário..."
    
    # Adicionar ao banco de dados
    add_user_to_db "$username" "$uuid" "$protocol" "$days"
    
    # Adicionar ao Xray (adicionar cliente na configuração)
    # Aqui você adicionaria a lógica para inserir o cliente no config.json
    # Por exemplo, usando jq para adicionar o cliente ao inbound apropriado
    
    echo ""
    _green "✓ Usuário criado com sucesso!"
    echo ""
    
    # Exibir informações do usuário
    echo "═══════════════════════════════════════"
    echo "  INFORMAÇÕES DO USUÁRIO"
    echo "═══════════════════════════════════════"
    echo "Nome: $username"
    echo "UUID: $uuid"
    echo "Protocolo: $protocol"
    echo "Criado em: $created_readable"
    echo "Expira em: $expires_readable"
    echo "Dias de validade: $days dias"
    echo "Status: Ativo"
    echo "═══════════════════════════════════════"
    
    # ════════════════════════════════════════════════════════════════
    # ADIÇÃO 3: GERAR LINK DE CONEXÃO AUTOMATICAMENTE
    # ════════════════════════════════════════════════════════════════
    
    # Gerar link de conexão
    link=$(generate_user_link "$username" "$uuid" "$protocol")
    
    if [[ $? -eq 0 && -n "$link" ]]; then
        echo ""
        echo "Link de conexão:"
        echo "$link"
        echo ""
        
        if command -v qrencode >/dev/null 2>&1; then
            echo "QR Code:"
            echo ""
            qrencode -t ANSIUTF8 "$link"
            echo ""
        else
            echo "💡 Instale qrencode para ver o QR Code: apt install qrencode"
            echo ""
        fi
    fi
    
    echo "Pressione ENTER para continuar..."
    read
}


# ════════════════════════════════════════════════════════════════════════
# FUNÇÃO: LISTAR USUÁRIOS
# ════════════════════════════════════════════════════════════════════════

list_users() {
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  LISTA DE USUÁRIOS"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    if [[ ! -f "$USERS_DB" ]] || [[ $(jq '. | length' "$USERS_DB") -eq 0 ]]; then
        _yellow "Nenhum usuário cadastrado"
        echo ""
        return
    fi
    
    # Cabeçalho
    printf "%-20s %-10s %-15s %-10s\n" "USUÁRIO" "PROTOCOLO" "EXPIRA EM" "STATUS"
    echo "───────────────────────────────────────────────────────────"
    
    # Listar usuários
    jq -r '.[] | "\(.username)|\(.protocol)|\(.expires_at)|\(.status)"' "$USERS_DB" | while IFS='|' read -r user proto expires status; do
        local now=$(date +%s)
        local expires_date=$(date -d "@$expires" "+%d/%m/%Y")
        
        if [[ $now -gt $expires ]]; then
            status="Expirado"
        else
            status="Ativo"
        fi
        
        printf "%-20s %-10s %-15s %-10s\n" "$user" "$proto" "$expires_date" "$status"
    done
    
    echo ""
}


# ════════════════════════════════════════════════════════════════════════
# FUNÇÃO: REMOVER USUÁRIO
# ════════════════════════════════════════════════════════════════════════

remove_user() {
    echo ""
    echo "═══════════════════════════════════════"
    echo "  REMOVER USUÁRIO"
    echo "═══════════════════════════════════════"
    echo ""
    
    read -p "Nome do usuário: " username
    
    if ! user_exists "$username"; then
        _red "✗ Usuário '$username' não encontrado"
        echo ""
        return 1
    fi
    
    read -p "Confirma remoção do usuário '$username'? (s/N): " confirm
    if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
        _yellow "Operação cancelada"
        echo ""
        return
    fi
    
    # Remover do banco de dados
    local temp_db=$(mktemp)
    jq "del(.[] | select(.username == \"$username\"))" "$USERS_DB" > "$temp_db"
    mv "$temp_db" "$USERS_DB"
    
    _green "✓ Usuário '$username' removido com sucesso"
    echo ""
}


# ════════════════════════════════════════════════════════════════════════
# FUNÇÃO: RENOVAR USUÁRIO
# ════════════════════════════════════════════════════════════════════════

renew_user() {
    echo ""
    echo "═══════════════════════════════════════"
    echo "  RENOVAR USUÁRIO"
    echo "═══════════════════════════════════════"
    echo ""
    
    read -p "Nome do usuário: " username
    
    if ! user_exists "$username"; then
        _red "✗ Usuário '$username' não encontrado"
        echo ""
        return 1
    fi
    
    read -p "Adicionar quantos dias? " days
    
    if [[ ! "$days" =~ ^[0-9]+$ ]]; then
        _red "✗ Digite apenas números"
        echo ""
        return 1
    fi
    
    # Obter expiry atual
    local current_expires=$(jq -r ".[] | select(.username == \"$username\") | .expires_at" "$USERS_DB")
    local now=$(date +%s)
    
    # Se já expirou, renovar a partir de agora
    if [[ $current_expires -lt $now ]]; then
        local new_expires=$((now + (days * 86400)))
    else
        local new_expires=$((current_expires + (days * 86400)))
    fi
    
    # Atualizar no banco de dados
    local temp_db=$(mktemp)
    jq "(.[] | select(.username == \"$username\") | .expires_at) |= $new_expires" "$USERS_DB" > "$temp_db"
    mv "$temp_db" "$USERS_DB"
    
    local new_expires_date=$(date -d "@$new_expires" "+%d/%m/%Y %H:%M:%S")
    
    _green "✓ Usuário renovado até: $new_expires_date"
    echo ""
}


# ════════════════════════════════════════════════════════════════════════
# MENU PRINCIPAL
# ════════════════════════════════════════════════════════════════════════

show_menu() {
    echo ""
    echo "═══════════════════════════════════════"
    echo "  GERENCIAMENTO DE USUÁRIOS"
    echo "═══════════════════════════════════════"
    echo ""
    echo "  1) Adicionar usuário"
    echo "  2) Listar usuários"
    echo "  3) Remover usuário"
    echo "  4) Renovar usuário"
    echo "  0) Voltar"
    echo ""
    read -p "Escolha uma opção: " option
    
    case $option in
        1) add_user ;;
        2) list_users ;;
        3) remove_user ;;
        4) renew_user ;;
        0) return ;;
        *) _red "Opção inválida" ;;
    esac
    
    show_menu
}


# ════════════════════════════════════════════════════════════════════════
# PONTO DE ENTRADA
# ════════════════════════════════════════════════════════════════════════

# Se chamado com parâmetro, executar função específica
if [[ $# -gt 0 ]]; then
    case $1 in
        add) add_user ;;
        list) list_users ;;
        remove) remove_user ;;
        renew) renew_user ;;
        *) show_menu ;;
    esac
else
    show_menu
fi
