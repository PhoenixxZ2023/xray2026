#!/bin/bash

# Xray2026 - Verificador Automático de Vencimento
# Autor: PhoenixxZ2023
# GitHub: https://github.com/PhoenixxZ2023/xray2026

# Diretórios e arquivos
USERS_DIR="/etc/xray/users"
USERS_DB="$USERS_DIR/users.json"
CONFIG_JSON="/etc/xray/config.json"
LOG_FILE="$USERS_DIR/expiration.log"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Registrar no log
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> $LOG_FILE
}

# Verificar e processar usuários expirados
check_expired_users() {
    local current_timestamp=$(date +%s)
    local expired_count=0
    local warned_count=0
    
    echo -e "${BLUE}Verificando usuários expirados...${NC}"
    log_message "Iniciando verificação de expiração"
    
    # Verificar cada usuário
    while read -r username; do
        local expires_at=$(jq -r ".[] | select(.username == \"$username\") | .expires_at" $USERS_DB)
        local status=$(jq -r ".[] | select(.username == \"$username\") | .status" $USERS_DB)
        local uuid=$(jq -r ".[] | select(.username == \"$username\") | .uuid" $USERS_DB)
        
        # Converter para número
        expires_at=$(echo $expires_at | sed 's/"//g')
        
        # Verificar se expirou
        if [[ $current_timestamp -gt $expires_at ]]; then
            if [[ $status != "expired" ]]; then
                echo -e "${RED}✗ Usuário '$username' EXPIRADO!${NC}"
                
                # Marcar como expirado
                jq "(.[] | select(.username == \"$username\") | .status) = \"expired\"" \
                    $USERS_DB > $USERS_DB.tmp && mv $USERS_DB.tmp $USERS_DB
                
                # Remover do Xray
                disable_user_in_xray "$uuid"
                
                log_message "Usuário '$username' (UUID: $uuid) EXPIRADO e desativado"
                ((expired_count++))
            fi
        else
            # Verificar se está próximo do vencimento (3 dias)
            local days_remaining=$(( (expires_at - current_timestamp) / 86400 ))
            
            if [[ $days_remaining -le 3 && $days_remaining -gt 0 ]]; then
                echo -e "${YELLOW}⚠ Usuário '$username' expira em $days_remaining dia(s)${NC}"
                log_message "AVISO: Usuário '$username' expira em $days_remaining dia(s)"
                ((warned_count++))
            fi
        fi
    done < <(jq -r '.[].username' $USERS_DB)
    
    if [[ $expired_count -eq 0 && $warned_count -eq 0 ]]; then
        echo -e "${GREEN}✓ Todos os usuários estão dentro da validade${NC}"
        log_message "Todos os usuários válidos"
    else
        echo ""
        echo "Resumo da verificação:"
        echo "  Usuários expirados: $expired_count"
        echo "  Avisos de vencimento: $warned_count"
        
        # Reiniciar Xray se houver usuários expirados
        if [[ $expired_count -gt 0 ]]; then
            echo -e "${BLUE}Reiniciando Xray...${NC}"
            systemctl restart xray
            log_message "Xray reiniciado após desativar $expired_count usuário(s)"
        fi
    fi
}

# Desabilitar usuário no Xray (remover do config.json)
disable_user_in_xray() {
    local uuid="$1"
    
    # Backup
    cp $CONFIG_JSON ${CONFIG_JSON}.bak
    
    # Remover usuário de todos os inbounds
    jq ".inbounds[].settings.clients |= map(select(.id != \"$uuid\"))" \
        $CONFIG_JSON > ${CONFIG_JSON}.tmp && mv ${CONFIG_JSON}.tmp $CONFIG_JSON
}

# Listar usuários expirados
list_expired_users() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "  USUÁRIOS EXPIRADOS"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    
    local expired_users=$(jq -r '.[] | select(.status == "expired") | .username' $USERS_DB)
    
    if [[ -z $expired_users ]]; then
        echo "Nenhum usuário expirado."
        return
    fi
    
    printf "%-20s %-40s %-20s\n" "USUÁRIO" "UUID" "EXPIROU EM"
    echo "───────────────────────────────────────────────────────────────────"
    
    jq -r '.[] | select(.status == "expired") | "\(.username)|\(.uuid)|\(.expires_readable)"' $USERS_DB | \
    while IFS='|' read -r user uuid expires; do
        printf "%-20s %-40s %-20s\n" "$user" "$uuid" "$expires"
    done
    
    echo "═══════════════════════════════════════════════════════════════════"
}

# Listar usuários próximos do vencimento
list_expiring_soon() {
    local days="${1:-7}"
    local current_timestamp=$(date +%s)
    local future_timestamp=$(date -d "+${days} days" +%s)
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "  USUÁRIOS QUE EXPIRAM NOS PRÓXIMOS $days DIAS"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    
    local found=0
    
    printf "%-20s %-15s %-20s\n" "USUÁRIO" "DIAS RESTANTES" "EXPIRA EM"
    echo "───────────────────────────────────────────────────────────────────"
    
    while read -r username; do
        local expires_at=$(jq -r ".[] | select(.username == \"$username\") | .expires_at" $USERS_DB)
        local expires_readable=$(jq -r ".[] | select(.username == \"$username\") | .expires_readable" $USERS_DB)
        local status=$(jq -r ".[] | select(.username == \"$username\") | .status" $USERS_DB)
        
        expires_at=$(echo $expires_at | sed 's/"//g')
        
        # Verificar se está ativo e dentro do período
        if [[ $status == "active" && $expires_at -le $future_timestamp && $expires_at -gt $current_timestamp ]]; then
            local days_remaining=$(( (expires_at - current_timestamp) / 86400 ))
            
            local color="${GREEN}"
            [[ $days_remaining -le 3 ]] && color="${YELLOW}"
            [[ $days_remaining -le 1 ]] && color="${RED}"
            
            printf "%-20s ${color}%-15s${NC} %-20s\n" "$username" "$days_remaining" "$expires_readable"
            found=1
        fi
    done < <(jq -r '.[].username' $USERS_DB)
    
    if [[ $found -eq 0 ]]; then
        echo "Nenhum usuário expira nos próximos $days dias."
    fi
    
    echo "═══════════════════════════════════════════════════════════════════"
}

# Limpar usuários expirados (remover do banco)
clean_expired_users() {
    local days_old="${1:-30}"
    
    read -p "Deseja remover usuários expirados há mais de $days_old dias? (s/N): " confirm
    
    if [[ ! $confirm =~ ^[Ss]$ ]]; then
        echo "Operação cancelada."
        return
    fi
    
    local current_timestamp=$(date +%s)
    local threshold_timestamp=$(date -d "-${days_old} days" +%s)
    local removed_count=0
    
    # Encontrar usuários para remover
    while read -r username; do
        local expires_at=$(jq -r ".[] | select(.username == \"$username\") | .expires_at" $USERS_DB)
        local status=$(jq -r ".[] | select(.username == \"$username\") | .status" $USERS_DB)
        
        expires_at=$(echo $expires_at | sed 's/"//g')
        
        # Remover se expirou há mais de X dias
        if [[ $status == "expired" && $expires_at -lt $threshold_timestamp ]]; then
            echo -e "${YELLOW}Removendo usuário '$username'...${NC}"
            
            jq "del(.[] | select(.username == \"$username\"))" \
                $USERS_DB > $USERS_DB.tmp && mv $USERS_DB.tmp $USERS_DB
            
            log_message "Usuário '$username' removido (expirado há mais de $days_old dias)"
            ((removed_count++))
        fi
    done < <(jq -r '.[].username' $USERS_DB)
    
    echo -e "${GREEN}✓ $removed_count usuário(s) removido(s)${NC}"
}

# Reativar usuário expirado
reactivate_user() {
    local username="$1"
    local new_days="$2"
    
    [[ -z $username ]] && {
        echo -e "${RED}ERRO: Nome de usuário não pode ser vazio${NC}"
        return 1
    }
    
    [[ -z $new_days ]] && {
        echo -e "${RED}ERRO: Quantidade de dias não pode ser vazia${NC}"
        return 1
    }
    
    # Verificar se usuário existe
    if ! jq -e ".[] | select(.username == \"$username\")" $USERS_DB &>/dev/null; then
        echo -e "${RED}ERRO: Usuário '$username' não encontrado!${NC}"
        return 1
    fi
    
    local uuid=$(jq -r ".[] | select(.username == \"$username\") | .uuid" $USERS_DB)
    local protocol=$(jq -r ".[] | select(.username == \"$username\") | .protocol" $USERS_DB)
    
    # Calcular nova data de expiração
    local new_expiration=$(date -d "+${new_days} days" +%s)
    local new_expiration_readable=$(date -d "+${new_days} days" "+%d/%m/%Y %H:%M:%S")
    
    # Atualizar status e data
    jq "(.[] | select(.username == \"$username\") | .expires_at) = \"$new_expiration\" | 
        (.[] | select(.username == \"$username\") | .expires_readable) = \"$new_expiration_readable\" |
        (.[] | select(.username == \"$username\") | .status) = \"active\"" \
        $USERS_DB > $USERS_DB.tmp && mv $USERS_DB.tmp $USERS_DB
    
    # Adicionar de volta ao Xray
    reactivate_user_in_xray "$uuid" "$protocol"
    
    # Reiniciar Xray
    systemctl restart xray
    
    echo -e "${GREEN}✓ Usuário '$username' reativado!${NC}"
    echo "Nova data de expiração: $new_expiration_readable"
    log_message "Usuário '$username' reativado com validade de $new_days dias"
}

# Reativar usuário no Xray
reactivate_user_in_xray() {
    local uuid="$1"
    local protocol="$2"
    
    # Backup
    cp $CONFIG_JSON ${CONFIG_JSON}.bak
    
    # Adicionar de volta aos inbounds
    if [[ $protocol == "vless" ]]; then
        jq ".inbounds[] |= if .protocol == \"vless\" then .settings.clients += [{\"id\": \"$uuid\", \"flow\": \"xtls-rprx-vision\", \"level\": 0}] else . end" \
            $CONFIG_JSON > ${CONFIG_JSON}.tmp && mv ${CONFIG_JSON}.tmp $CONFIG_JSON
    fi
    
    if [[ $protocol == "vmess" ]]; then
        jq ".inbounds[] |= if .protocol == \"vmess\" then .settings.clients += [{\"id\": \"$uuid\", \"alterId\": 0, \"level\": 0}] else . end" \
            $CONFIG_JSON > ${CONFIG_JSON}.tmp && mv ${CONFIG_JSON}.tmp $CONFIG_JSON
    fi
}

# Configurar verificação automática (cron)
setup_auto_check() {
    local cron_file="/etc/cron.d/xray2026-expiration"
    
    echo "Configurando verificação automática diária..."
    
    # Criar arquivo cron
    cat > $cron_file <<EOF
# Xray2026 - Verificação Automática de Expiração
# Executar todos os dias às 00:00
0 0 * * * root /etc/xray/sh/src/expiration-checker.sh check >> $LOG_FILE 2>&1

# Executar a cada 6 horas
0 */6 * * * root /etc/xray/sh/src/expiration-checker.sh check >> $LOG_FILE 2>&1
EOF
    
    chmod 644 $cron_file
    
    echo -e "${GREEN}✓ Verificação automática configurada!${NC}"
    echo "O sistema verificará expiração:"
    echo "  - Todos os dias às 00:00"
    echo "  - A cada 6 horas"
    log_message "Verificação automática configurada via cron"
}

# Remover verificação automática
remove_auto_check() {
    local cron_file="/etc/cron.d/xray2026-expiration"
    
    if [[ -f $cron_file ]]; then
        rm -f $cron_file
        echo -e "${GREEN}✓ Verificação automática removida${NC}"
        log_message "Verificação automática removida"
    else
        echo "Verificação automática não está configurada."
    fi
}

# Ver log de expiração
view_log() {
    local lines="${1:-50}"
    
    if [[ ! -f $LOG_FILE ]]; then
        echo "Nenhum log encontrado."
        return
    fi
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "  LOG DE EXPIRAÇÃO (últimas $lines linhas)"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    
    tail -n $lines $LOG_FILE
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
}

# Menu de ajuda
show_help() {
    echo "Uso: $0 {comando} [argumentos]"
    echo ""
    echo "Comandos disponíveis:"
    echo "  check                      Verificar usuários expirados"
    echo "  list-expired               Listar usuários expirados"
    echo "  list-expiring [dias]       Listar usuários expirando em X dias (padrão: 7)"
    echo "  clean [dias]               Limpar usuários expirados há X dias (padrão: 30)"
    echo "  reactivate <user> <dias>   Reativar usuário com nova validade"
    echo "  setup-auto                 Configurar verificação automática (cron)"
    echo "  remove-auto                Remover verificação automática"
    echo "  log [linhas]               Ver log de expiração (padrão: 50 linhas)"
    echo ""
    echo "Exemplos:"
    echo "  $0 check"
    echo "  $0 list-expired"
    echo "  $0 list-expiring 3"
    echo "  $0 clean 60"
    echo "  $0 reactivate joao 30"
    echo "  $0 setup-auto"
}

# Executar comando
case "$1" in
    check)
        check_expired_users
        ;;
    list-expired)
        list_expired_users
        ;;
    list-expiring)
        list_expiring_soon "$2"
        ;;
    clean)
        clean_expired_users "$2"
        ;;
    reactivate)
        reactivate_user "$2" "$3"
        ;;
    setup-auto)
        setup_auto_check
        ;;
    remove-auto)
        remove_auto_check
        ;;
    log)
        view_log "$2"
        ;;
    *)
        show_help
        exit 1
        ;;
esac
