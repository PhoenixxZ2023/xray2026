#!/bin/bash

# Xray2026 - Gerenciador de Usuários
# Autor: PhoenixxZ2023
# GitHub: https://github.com/PhoenixxZ2023/xray2026

# Diretórios e arquivos
USERS_DIR="/etc/xray/users"
USERS_DB="$USERS_DIR/users.json"
CONFIG_JSON="/etc/xray/config.json"

# Garantir que o banco de dados existe
ensure_db() {
    [[ ! -d $USERS_DIR ]] && mkdir -p $USERS_DIR
    [[ ! -f $USERS_DB ]] && echo "[]" > $USERS_DB
}

# Gerar UUID único
generate_uuid() {
    if command -v uuidgen &>/dev/null; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    else
        cat /proc/sys/kernel/random/uuid
    fi
}

# Adicionar novo usuário
add_user() {
    local username="$1"
    local days="$2"
    local protocol="${3:-vless}"
    
    # Validações
    [[ -z $username ]] && {
        echo "ERRO: Nome de usuário não pode ser vazio"
        return 1
    }
    
    [[ -z $days ]] && {
        echo "ERRO: Dias de validade não pode ser vazio"
        return 1
    }
    
    # Verificar se usuário já existe
    if jq -e ".[] | select(.username == \"$username\")" $USERS_DB &>/dev/null; then
        echo "ERRO: Usuário '$username' já existe!"
        return 1
    fi
    
    # Gerar UUID
    local uuid=$(generate_uuid)
    
    # Calcular data de expiração
    local created_date=$(date +%s)
    local expiration_date=$(date -d "+${days} days" +%s)
    local expiration_readable=$(date -d "+${days} days" "+%d/%m/%Y %H:%M:%S")
    
    # Criar objeto do usuário
    local user_data=$(jq -n \
        --arg username "$username" \
        --arg uuid "$uuid" \
        --arg protocol "$protocol" \
        --arg created "$created_date" \
        --arg expires "$expiration_date" \
        --arg expires_readable "$expiration_readable" \
        --arg status "active" \
        '{
            username: $username,
            uuid: $uuid,
            protocol: $protocol,
            created_at: $created,
            expires_at: $expires,
            expires_readable: $expires_readable,
            status: $status,
            traffic_used: 0,
            last_connection: null
        }')
    
    # Adicionar ao banco de dados
    jq ". += [$user_data]" $USERS_DB > $USERS_DB.tmp && mv $USERS_DB.tmp $USERS_DB
    
    # Adicionar ao config.json do Xray
    add_user_to_xray_config "$uuid" "$protocol"
    
    # Reiniciar Xray
    systemctl restart xray
    
    echo "✓ Usuário criado com sucesso!"
    echo ""
    echo "═══════════════════════════════════════"
    echo "  INFORMAÇÕES DO USUÁRIO"
    echo "═══════════════════════════════════════"
    echo "Nome: $username"
    echo "UUID: $uuid"
    echo "Protocolo: $protocol"
    echo "Criado em: $(date -d @$created_date '+%d/%m/%Y %H:%M:%S')"
    echo "Expira em: $expiration_readable"
    echo "Dias de validade: $days dias"
    echo "Status: Ativo"
    echo "═══════════════════════════════════════"
    
    return 0
}

# Adicionar usuário ao config.json do Xray
add_user_to_xray_config() {
    local uuid="$1"
    local protocol="$2"
    
    # Backup do config
    cp $CONFIG_JSON ${CONFIG_JSON}.bak
    
    # Adicionar cliente ao inbound VLESS
    if [[ $protocol == "vless" ]]; then
        jq ".inbounds[] |= if .protocol == \"vless\" then .settings.clients += [{\"id\": \"$uuid\", \"flow\": \"xtls-rprx-vision\", \"level\": 0}] else . end" \
            $CONFIG_JSON > ${CONFIG_JSON}.tmp && mv ${CONFIG_JSON}.tmp $CONFIG_JSON
    fi
    
    # Adicionar cliente ao inbound VMess
    if [[ $protocol == "vmess" ]]; then
        jq ".inbounds[] |= if .protocol == \"vmess\" then .settings.clients += [{\"id\": \"$uuid\", \"alterId\": 0, \"level\": 0}] else . end" \
            $CONFIG_JSON > ${CONFIG_JSON}.tmp && mv ${CONFIG_JSON}.tmp $CONFIG_JSON
    fi
}

# Listar todos os usuários
list_users() {
    local total=$(jq 'length' $USERS_DB)
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "  LISTA DE USUÁRIOS CADASTRADOS - Total: $total"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    
    if [[ $total -eq 0 ]]; then
        echo "Nenhum usuário cadastrado."
        return
    fi
    
    jq -r '.[] | "[\(.status | if . == "active" then "ATIVO" else "EXPIRADO" end)] \(.username)\n  UUID: \(.uuid)\n  Protocolo: \(.protocol)\n  Expira: \(.expires_readable)\n  Tráfego: \(.traffic_used) MB\n"' $USERS_DB
    
    echo "═══════════════════════════════════════════════════════════════════"
}

# Deletar usuário
delete_user() {
    local username="$1"
    
    [[ -z $username ]] && {
        echo "ERRO: Nome de usuário não pode ser vazio"
        return 1
    }
    
    # Verificar se usuário existe
    if ! jq -e ".[] | select(.username == \"$username\")" $USERS_DB &>/dev/null; then
        echo "ERRO: Usuário '$username' não encontrado!"
        return 1
    fi
    
    # Obter UUID antes de deletar
    local uuid=$(jq -r ".[] | select(.username == \"$username\") | .uuid" $USERS_DB)
    
    # Remover do banco de dados
    jq "del(.[] | select(.username == \"$username\"))" $USERS_DB > $USERS_DB.tmp && mv $USERS_DB.tmp $USERS_DB
    
    # Remover do config.json do Xray
    remove_user_from_xray_config "$uuid"
    
    # Reiniciar Xray
    systemctl restart xray
    
    echo "✓ Usuário '$username' deletado com sucesso!"
}

# Remover usuário do config.json do Xray
remove_user_from_xray_config() {
    local uuid="$1"
    
    # Backup do config
    cp $CONFIG_JSON ${CONFIG_JSON}.bak
    
    # Remover de todos os inbounds
    jq ".inbounds[].settings.clients |= map(select(.id != \"$uuid\"))" \
        $CONFIG_JSON > ${CONFIG_JSON}.tmp && mv ${CONFIG_JSON}.tmp $CONFIG_JSON
}

# Alterar data de vencimento
change_expiration() {
    local username="$1"
    local new_days="$2"
    
    [[ -z $username ]] && {
        echo "ERRO: Nome de usuário não pode ser vazio"
        return 1
    }
    
    [[ -z $new_days ]] && {
        echo "ERRO: Nova quantidade de dias não pode ser vazia"
        return 1
    }
    
    # Verificar se usuário existe
    if ! jq -e ".[] | select(.username == \"$username\")" $USERS_DB &>/dev/null; then
        echo "ERRO: Usuário '$username' não encontrado!"
        return 1
    fi
    
    # Calcular nova data de expiração
    local new_expiration=$(date -d "+${new_days} days" +%s)
    local new_expiration_readable=$(date -d "+${new_days} days" "+%d/%m/%Y %H:%M:%S")
    
    # Atualizar no banco de dados
    jq "(.[] | select(.username == \"$username\") | .expires_at) = \"$new_expiration\" | 
        (.[] | select(.username == \"$username\") | .expires_readable) = \"$new_expiration_readable\" |
        (.[] | select(.username == \"$username\") | .status) = \"active\"" \
        $USERS_DB > $USERS_DB.tmp && mv $USERS_DB.tmp $USERS_DB
    
    echo "✓ Data de vencimento atualizada!"
    echo "Usuário: $username"
    echo "Nova data de expiração: $new_expiration_readable"
}

# Ver detalhes de um usuário específico
view_user() {
    local username="$1"
    
    [[ -z $username ]] && {
        echo "ERRO: Nome de usuário não pode ser vazio"
        return 1
    }
    
    local user_data=$(jq ".[] | select(.username == \"$username\")" $USERS_DB)
    
    if [[ -z $user_data ]]; then
        echo "ERRO: Usuário '$username' não encontrado!"
        return 1
    fi
    
    echo ""
    echo "═══════════════════════════════════════"
    echo "  DETALHES DO USUÁRIO"
    echo "═══════════════════════════════════════"
    echo "$user_data" | jq -r '
        "Nome: \(.username)",
        "UUID: \(.uuid)",
        "Protocolo: \(.protocol)",
        "Status: \(.status)",
        "Criado em: \(.created_at | tonumber | strftime("%d/%m/%Y %H:%M:%S"))",
        "Expira em: \(.expires_readable)",
        "Tráfego usado: \(.traffic_used) MB",
        "Última conexão: \(.last_connection // "Nunca")"
    '
    echo "═══════════════════════════════════════"
}

# Renovar usuário (adicionar mais dias)
renew_user() {
    local username="$1"
    local additional_days="$2"
    
    [[ -z $username ]] && {
        echo "ERRO: Nome de usuário não pode ser vazio"
        return 1
    }
    
    [[ -z $additional_days ]] && {
        echo "ERRO: Quantidade de dias não pode ser vazia"
        return 1
    }
    
    # Verificar se usuário existe
    if ! jq -e ".[] | select(.username == \"$username\")" $USERS_DB &>/dev/null; then
        echo "ERRO: Usuário '$username' não encontrado!"
        return 1
    fi
    
    # Obter data de expiração atual
    local current_expiration=$(jq -r ".[] | select(.username == \"$username\") | .expires_at" $USERS_DB)
    
    # Calcular nova data (adicionar dias à data atual de expiração)
    local new_expiration=$(date -d "@$current_expiration +${additional_days} days" +%s)
    local new_expiration_readable=$(date -d "@$new_expiration" "+%d/%m/%Y %H:%M:%S")
    
    # Atualizar no banco de dados
    jq "(.[] | select(.username == \"$username\") | .expires_at) = \"$new_expiration\" | 
        (.[] | select(.username == \"$username\") | .expires_readable) = \"$new_expiration_readable\" |
        (.[] | select(.username == \"$username\") | .status) = \"active\"" \
        $USERS_DB > $USERS_DB.tmp && mv $USERS_DB.tmp $USERS_DB
    
    echo "✓ Usuário renovado com sucesso!"
    echo "Usuário: $username"
    echo "Dias adicionados: $additional_days"
    echo "Nova data de expiração: $new_expiration_readable"
}

# Inicializar
ensure_db

# Chamar função baseada no argumento
case "$1" in
    add)
        add_user "$2" "$3" "$4"
        ;;
    list)
        list_users
        ;;
    delete)
        delete_user "$2"
        ;;
    view)
        view_user "$2"
        ;;
    change-expiration)
        change_expiration "$2" "$3"
        ;;
    renew)
        renew_user "$2" "$3"
        ;;
    *)
        echo "Uso: $0 {add|list|delete|view|change-expiration|renew} [argumentos]"
        echo ""
        echo "Exemplos:"
        echo "  $0 add joao 30 vless         # Adicionar usuário 'joao' válido por 30 dias"
        echo "  $0 list                       # Listar todos os usuários"
        echo "  $0 delete joao                # Deletar usuário 'joao'"
        echo "  $0 view joao                  # Ver detalhes do usuário 'joao'"
        echo "  $0 change-expiration joao 60  # Alterar validade para 60 dias"
        echo "  $0 renew joao 30              # Adicionar 30 dias à validade atual"
        exit 1
        ;;
esac
