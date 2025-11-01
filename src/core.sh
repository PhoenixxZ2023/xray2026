#!/bin/bash

# ============================================================================
# Xray2026 - Core Script Principal
# Autor: PhoenixxZ2023
# GitHub: https://github.com/PhoenixxZ2023/xray2026
# Versão: 2.0
# Baseado no script original de 233boy
# ============================================================================

# ========== INICIALIZAÇÃO DE VARIÁVEIS GLOBAIS ==========

# Versão do script
is_sh_ver="2.0"

# Diretórios principais
is_core="xray"
is_core_name="Xray"
is_core_dir="/etc/xray"
is_conf_dir="/etc/xray/conf"
is_config_json="/etc/xray/config.json"
is_sh_dir="/etc/xray"
is_log_dir="/var/log/xray"

# Binários
is_core_bin="/usr/local/bin/xray"
is_sh_bin="/usr/local/bin/xray"

# Caddy (se instalado)
is_caddy="caddy"
is_caddy_bin="/usr/local/bin/caddy"
is_caddy_dir="/etc/caddy"
is_caddy_conf="/etc/caddy/conf"
is_caddyfile="/etc/caddy/Caddyfile"

# Portas padrão
is_http_port=80
is_https_port=443

# Repositórios
is_core_repo="XTLS/Xray-core"
is_sh_repo="PhoenixxZ2023/xray2026"
is_caddy_repo="caddyserver/caddy"

# Arquitetura
is_core_arch=$(uname -m)
case $is_core_arch in
    x86_64 | amd64)
        is_core_arch="64"
        caddy_arch="amd64"
        ;;
    aarch64 | arm64)
        is_core_arch="arm64-v8a"
        caddy_arch="arm64"
        ;;
    armv7l)
        is_core_arch="arm32-v7a"
        caddy_arch="armv7"
        ;;
    *)
        echo "ERRO: Arquitetura não suportada: $is_core_arch"
        exit 1
        ;;
esac

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

# ========== MÉTODOS DE CRIPTOGRAFIA SHADOWSOCKS ==========
ss_method_list=(
    aes-128-gcm
    aes-256-gcm
    chacha20-ietf-poly1305
    xchacha20-ietf-poly1305
    2022-blake3-aes-128-gcm
    2022-blake3-aes-256-gcm
    2022-blake3-chacha20-poly1305
)

# ========== TIPOS DE DISFARCE mKCP ==========
header_type_list=(
    none
    srtp
    utp
    wechat-video
    dtls
    wireguard
)

# ========== MENU PRINCIPAL ==========
mainmenu=(
    "Gerenciar Usuários"
    "Monitorar Tráfego"
    "Verificar Vencimentos"
    "Adicionar Configuração"
    "Alterar Configuração"
    "Ver Configuração"
    "Deletar Configuração"
    "Gerenciar Serviços"
    "Atualizar"
    "Desinstalar"
    "Ajuda"
    "Outros"
    "Sobre"
)

# ========== LISTA DE INFORMAÇÕES ==========
info_list=(
    "Protocolo (protocol)"
    "Endereço (address)"
    "Porta (port)"
    "ID de Usuário (id)"
    "Rede de Transporte (network)"
    "Tipo de Disfarce (type)"
    "Domínio de Disfarce (host)"
    "Caminho (path)"
    "Segurança TLS"
    "mKCP seed"
    "Senha (password)"
    "Método de Criptografia (encryption)"
    "Link (URL)"
    "Endereço de Destino (remote addr)"
    "Porta de Destino (remote port)"
    "Controle de Fluxo (flow)"
    "SNI (serverName)"
    "Impressão Digital (Fingerprint)"
    "Chave Pública (Public key)"
    "Nome de Usuário (Username)"
)

# ========== LISTA DE MUDANÇAS ==========
change_list=(
    "Alterar Protocolo"
    "Alterar Porta"
    "Alterar Domínio"
    "Alterar Caminho"
    "Alterar Senha"
    "Alterar UUID"
    "Alterar Método de Criptografia"
    "Alterar Tipo de Disfarce"
    "Alterar Endereço de Destino"
    "Alterar Porta de Destino"
    "Alterar Chave"
    "Alterar SNI (serverName)"
    "Alterar Porta Dinâmica"
    "Alterar Site de Disfarce"
    "Alterar mKCP seed"
    "Alterar Nome de Usuário"
)

# ========== VARIÁVEIS GLOBAIS DO SISTEMA ==========
USERS_DB="/etc/xray/users/users.json"
TRAFFIC_LOG="/etc/xray/users/traffic.log"
EXPIRATION_LOG="/etc/xray/users/expiration.log"

# ========== FUNÇÕES DE MENSAGENS COLORIDAS ==========

msg() {
    echo -e "$@"
}

msg_ul() {
    echo -e "\e[4m$@\e[0m"
}

_green() {
    echo -e "\e[32m$@\e[0m"
}

_red() {
    echo -e "\e[31m$@\e[0m"
}

_yellow() {
    echo -e "\e[33m$@\e[0m"
}

_blue() {
    echo -e "\e[34m$@\e[0m"
}

_cyan() {
    echo -e "\e[36m$@\e[0m"
}

err() {
    _red "ERRO: $@"
    exit 1
}

warn() {
    _yellow "AVISO: $@"
}

# ========== FUNÇÕES AUXILIARES BÁSICAS ==========

pause() {
    read -rsp $'Pressione qualquer tecla para continuar...\n' -n1
}

get_uuid() {
    if [[ $(type -P uuidgen) ]]; then
        uuidgen
    else
        cat /proc/sys/kernel/random/uuid
    fi
}

get_ip() {
    if [[ -z $ip ]]; then
        local tmp_ip=$(curl -s https://api.ipify.org)
        if [[ $tmp_ip ]]; then
            ip=$tmp_ip
        else
            ip=$(hostname -I | awk '{print $1}')
        fi
    fi
}

get_port() {
    local port
    while :; do
        port=$(shuf -i 10000-65000 -n1)
        if ! ss -tlnp | grep -q ":$port "; then
            echo $port
            return 0
        fi
    done
}

get_ss2022_password() {
    local method=$1
    case $method in
        *aes-128*)
            openssl rand -base64 16
            ;;
        *aes-256* | *chacha20*)
            openssl rand -base64 32
            ;;
        *)
            openssl rand -base64 32
            ;;
    esac
}

check_root() {
    [[ $EUID != 0 ]] && err "Este script deve ser executado como root (use sudo)"
}

check_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        os_name=$ID
        os_ver=$VERSION_ID
    else
        err "Sistema operacional não suportado"
    fi
}

check_dependencies() {
    local deps=(curl wget jq systemctl)
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v $dep &>/dev/null; then
            missing+=($dep)
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        warn "Dependências faltando: ${missing[*]}"
        msg "Instalando dependências..."
        
        if command -v apt-get &>/dev/null; then
            apt-get update &>/dev/null
            apt-get install -y ${missing[*]}
        elif command -v yum &>/dev/null; then
            yum install -y ${missing[*]}
        else
            err "Gerenciador de pacotes não suportado. Instale manualmente: ${missing[*]}"
        fi
    fi
}

load() {
    local file=$1
    local path="$is_sh_dir/src/$file"
    
    if [[ -f $path ]]; then
        . $path
    else
        err "Arquivo não encontrado: $file"
    fi
}

# Gerar caminho aleatório
_get_random_path() {
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1
}

# ============================================================================
# FUNÇÕES AUXILIARES PARA CORE.SH
# Adicione estas funções no início do seu core.sh (após as variáveis globais)
# ============================================================================

# Gerar UUID automaticamente
generate_uuid() {
    if command -v uuidgen >/dev/null 2>&1; then
        uuidgen
    else
        cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "$(cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 32 | head -n 1 | sed 's/\(.\{8\}\)\(.\{4\}\)\(.\{4\}\)\(.\{4\}\)\(.\{12\}\)/\1-\2-\3-\4-\5/')"
    fi
}

# Gerar caminho (path) aleatório
generate_path() {
    # Gera caminho aleatório com 8-12 caracteres (letras e números)
    local length=$((8 + RANDOM % 5))
    echo "/$(tr -dc 'a-zA-Z0-9' </dev/urandom | head -c $length)"
}

# Obter IP público do servidor
get_server_ip() {
    local ip
    # Tentar obter IPv4
    ip=$(curl -4 -s --max-time 5 https://api.ipify.org 2>/dev/null || \
         curl -4 -s --max-time 5 https://icanhazip.com 2>/dev/null || \
         curl -4 -s --max-time 5 https://ifconfig.me 2>/dev/null)
    
    # Se não conseguir IPv4, tentar IPv6
    if [[ -z "$ip" ]]; then
        ip=$(curl -6 -s --max-time 5 https://api6.ipify.org 2>/dev/null || \
             curl -6 -s --max-time 5 https://icanhazip.com 2>/dev/null)
    fi
    
    echo "$ip"
}

# Verificar se domínio aponta para o IP do servidor
verify_domain_ip() {
    local domain="$1"
    local expected_ip="$2"
    
    # Remover http:// ou https:// se existir
    domain="${domain#http://}"
    domain="${domain#https://}"
    domain="${domain%%/*}"
    
    # Tentar resolver com dig primeiro
    if command -v dig >/dev/null 2>&1; then
        local resolved_ip=$(dig +short "$domain" A | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n1)
        
        # Se não encontrou IPv4, tentar IPv6
        if [[ -z "$resolved_ip" ]]; then
            resolved_ip=$(dig +short "$domain" AAAA | head -n1)
        fi
    # Se dig não estiver disponível, usar nslookup
    elif command -v nslookup >/dev/null 2>&1; then
        local resolved_ip=$(nslookup "$domain" 2>/dev/null | grep -A1 "Name:" | grep "Address:" | awk '{print $2}' | head -n1)
    # Se nslookup não estiver disponível, usar host
    elif command -v host >/dev/null 2>&1; then
        local resolved_ip=$(host "$domain" 2>/dev/null | grep "has address" | awk '{print $4}' | head -n1)
        
        # Se não encontrou IPv4, tentar IPv6
        if [[ -z "$resolved_ip" ]]; then
            resolved_ip=$(host "$domain" 2>/dev/null | grep "has IPv6 address" | awk '{print $5}' | head -n1)
        fi
    else
        echo "ERRO: Nenhuma ferramenta de DNS disponível (dig, nslookup, host)"
        return 2
    fi
    
    # Verificar se conseguiu resolver
    if [[ -z "$resolved_ip" ]]; then
        return 1
    fi
    
    # Comparar IPs
    if [[ "$resolved_ip" == "$expected_ip" ]]; then
        return 0
    else
        return 1
    fi
}

# Solicitar domínio com verificação automática
ask_domain() {
    local server_ip=$(get_server_ip)
    local domain
    local attempts=0
    local max_attempts=3
    
    if [[ -z "$server_ip" ]]; then
        _yellow "⚠ Não foi possível obter o IP do servidor automaticamente"
        read -p "Digite o IP do servidor manualmente: " server_ip
    else
        _green "✓ IP do servidor detectado: $server_ip"
    fi
    
    echo ""
    
    while [[ $attempts -lt $max_attempts ]]; do
        read -p "Digite o domínio (ex: www.exemplo.com): " domain
        
        # Verificar se domínio não está vazio
        if [[ -z "$domain" ]]; then
            _red "✗ Domínio não pode estar vazio"
            ((attempts++))
            continue
        fi
        
        # Verificar se domínio aponta para IP do servidor
        _yellow "⏳ Verificando DNS do domínio..."
        
        if verify_domain_ip "$domain" "$server_ip"; then
            _green "✓ Domínio aponta corretamente para $server_ip"
            echo "$domain"
            return 0
        else
            _red "✗ Domínio NÃO aponta para $server_ip"
            _yellow "  Configure o DNS antes de continuar ou use outro domínio"
            ((attempts++))
            
            if [[ $attempts -lt $max_attempts ]]; then
                echo ""
                read -p "Tentar outro domínio? (s/N): " retry
                if [[ "$retry" != "s" && "$retry" != "S" ]]; then
                    echo "$domain"
                    return 1
                fi
            fi
        fi
    done
    
    _red "✗ Número máximo de tentativas atingido"
    read -p "Deseja continuar mesmo assim? (s/N): " force
    if [[ "$force" == "s" || "$force" == "S" ]]; then
        echo "$domain"
        return 1
    else
        return 2
    fi
}
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

# ============================================================================
# COMO USAR NAS FUNÇÕES DE CRIAÇÃO DE CONFIGURAÇÃO
# ============================================================================

# Exemplo de uso na função que cria VLESS-WS-TLS:
#
# # Gerar UUID automaticamente
# uuid=$(generate_uuid)
# echo "UUID gerado: $uuid"
#
# # Gerar caminho automaticamente
# path=$(generate_path)
# echo "Caminho gerado: $path"
#
# # Solicitar domínio com verificação
# domain=$(ask_domain)
# if [[ $? -ne 0 ]]; then
#     _yellow "⚠ Continuando sem verificação de DNS"
# fi
#
# # Solicitar porta (com valor padrão)
# read -p "Digite a porta [443]: " port
# port=${port:-443}
#
# # Usar os valores gerados/solicitados
# echo "Configuração:"
# echo "  UUID: $uuid"
# echo "  Caminho: $path"
# echo "  Domínio: $domain"
# echo "  Porta: $port"

# ========== FUNÇÕES ADICIONAIS CORRIGIDAS ==========

# Função _wget com fallback para curl
_wget() {
    if command -v wget &>/dev/null; then
        wget "$@"
    elif command -v curl &>/dev/null; then
        # Traduzir opções wget para curl
        local url=""
        local output=""
        local args=()
        
        while [[ $# -gt 0 ]]; do
            case $1 in
                -O)
                    output="$2"
                    shift 2
                    ;;
                -qO-)
                    args+=(-s)
                    shift
                    ;;
                -t)
                    # Ignorar tentativas do wget
                    shift 2
                    ;;
                -c)
                    # Continue: curl não precisa
                    shift
                    ;;
                *)
                    url="$1"
                    shift
                    ;;
            esac
        done
        
        if [[ $output ]]; then
            curl -L "${args[@]}" -o "$output" "$url"
        else
            curl -L "${args[@]}" "$url"
        fi
    else
        err "wget ou curl não encontrado. Instale um deles."
    fi
}

# Função show_version
show_version() {
    echo ""
    echo "Xray2026 Script: $is_sh_ver"
    [[ -f $is_core_bin ]] && echo "Xray Core: $($is_core_bin version | head -n1 | awk '{print $2}')"
    echo "Autor: PhoenixxZ2023"
    echo "GitHub: https://github.com/PhoenixxZ2023/xray2026"
    echo ""
}
# ============================================================================
# SEÇÃO 2: FUNÇÕES AUXILIARES AVANÇADAS
# Funções de manipulação de JSON, validação e gerenciamento de configurações
# ============================================================================

# ========== FUNÇÕES DE SUBMENU (NOVAS) ==========

# Submenu de Gerenciamento de Usuários
user_management_menu() {
    while :; do
        clear
        msg "\n═══════════════════════════════════════"
        msg "  GERENCIAMENTO DE USUÁRIOS - XRAY2026"
        msg "═══════════════════════════════════════"
        msg "  1) Adicionar novo usuário"
        msg "  2) Listar todos os usuários"
        msg "  3) Ver detalhes de um usuário"
        msg "  4) Deletar usuário"
        msg "  5) Alterar data de vencimento"
        msg "  6) Renovar usuário (adicionar dias)"
        msg "  7) Gerar link VLESS com QR Code"
        msg ""
        msg "  0) Voltar ao menu principal"
        msg "═══════════════════════════════════════\n"
        
        read -p "Escolha uma opção: " user_option
        
        case $user_option in
            1)
                read -p "Nome do usuário: " username
                read -p "Dias de validade: " days
                read -p "Protocolo (vless/vmess) [vless]: " protocol
                protocol=${protocol:-vless}
                bash $is_sh_dir/src/user-manager.sh add "$username" "$days" "$protocol"
                ;;
            2)
                bash $is_sh_dir/src/user-manager.sh list
                ;;
            3)
                read -p "Nome do usuário: " username
                bash $is_sh_dir/src/user-manager.sh view "$username"
                ;;
            4)
                read -p "Nome do usuário para deletar: " username
                read -p "Tem certeza? (s/N): " confirm
                [[ $confirm =~ ^[Ss]$ ]] && bash $is_sh_dir/src/user-manager.sh delete "$username"
                ;;
            5)
                read -p "Nome do usuário: " username
                read -p "Nova quantidade de dias: " days
                bash $is_sh_dir/src/user-manager.sh change-expiration "$username" "$days"
                ;;
            6)
                read -p "Nome do usuário: " username
                read -p "Dias para adicionar: " days
                bash $is_sh_dir/src/user-manager.sh renew "$username" "$days"
                ;;
            7)
                read -p "Nome do usuário: " username
                generate_vless_link_advanced "$username"
                ;;
            0)
                break
                ;;
            *)
                warn "Opção inválida!"
                ;;
        esac
        
        read -p "Pressione ENTER para continuar..."
    done
}

# Submenu de Monitoramento de Tráfego
traffic_monitoring_menu() {
    while :; do
        clear
        msg "\n═══════════════════════════════════════"
        msg "  MONITORAMENTO DE TRÁFEGO - XRAY2026"
        msg "═══════════════════════════════════════"
        msg "  1) Atualizar estatísticas de tráfego"
        msg "  2) Ver tráfego de um usuário"
        msg "  3) Listar tráfego de todos"
        msg "  4) Monitoramento em tempo real"
        msg "  5) Resetar tráfego de um usuário"
        msg "  6) Resetar tráfego de todos"
        msg "  7) Exportar relatório"
        msg "  8) Habilitar API Stats do Xray"
        msg ""
        msg "  0) Voltar ao menu principal"
        msg "═══════════════════════════════════════\n"
        
        read -p "Escolha uma opção: " traffic_option
        
        case $traffic_option in
            1) bash $is_sh_dir/src/traffic-monitor.sh update ;;
            2)
                read -p "Nome do usuário: " username
                bash $is_sh_dir/src/traffic-monitor.sh view "$username"
                ;;
            3) bash $is_sh_dir/src/traffic-monitor.sh list ;;
            4) bash $is_sh_dir/src/traffic-monitor.sh monitor ;;
            5)
                read -p "Nome do usuário: " username
                bash $is_sh_dir/src/traffic-monitor.sh reset "$username"
                ;;
            6) bash $is_sh_dir/src/traffic-monitor.sh reset-all ;;
            7) bash $is_sh_dir/src/traffic-monitor.sh export ;;
            8) bash $is_sh_dir/src/traffic-monitor.sh enable-api ;;
            0) break ;;
            *) warn "Opção inválida!" ;;
        esac
        
        read -p "Pressione ENTER para continuar..."
    done
}

# Submenu de Verificação de Vencimentos
expiration_check_menu() {
    while :; do
        clear
        msg "\n═══════════════════════════════════════"
        msg "  VERIFICAÇÃO DE VENCIMENTOS - XRAY2026"
        msg "═══════════════════════════════════════"
        msg "  1) Verificar usuários expirados agora"
        msg "  2) Listar usuários expirados"
        msg "  3) Listar próximos a expirar (7 dias)"
        msg "  4) Listar próximos a expirar (personalizado)"
        msg "  5) Limpar usuários expirados antigos"
        msg "  6) Reativar usuário expirado"
        msg "  7) Configurar verificação automática"
        msg "  8) Remover verificação automática"
        msg "  9) Ver log de expirações"
        msg ""
        msg "  0) Voltar ao menu principal"
        msg "═══════════════════════════════════════\n"
        
        read -p "Escolha uma opção: " exp_option
        
        case $exp_option in
            1) bash $is_sh_dir/src/expiration-checker.sh check ;;
            2) bash $is_sh_dir/src/expiration-checker.sh list-expired ;;
            3) bash $is_sh_dir/src/expiration-checker.sh list-expiring 7 ;;
            4)
                read -p "Quantos dias? " days
                bash $is_sh_dir/src/expiration-checker.sh list-expiring "$days"
                ;;
            5)
                read -p "Remover expirados há quantos dias? [30]: " days
                days=${days:-30}
                bash $is_sh_dir/src/expiration-checker.sh clean "$days"
                ;;
            6)
                read -p "Nome do usuário: " username
                read -p "Nova validade em dias: " days
                bash $is_sh_dir/src/expiration-checker.sh reactivate "$username" "$days"
                ;;
            7) bash $is_sh_dir/src/expiration-checker.sh setup-auto ;;
            8) bash $is_sh_dir/src/expiration-checker.sh remove-auto ;;
            9)
                read -p "Quantas linhas exibir? [50]: " lines
                bash $is_sh_dir/src/expiration-checker.sh log "${lines:-50}"
                ;;
            0) break ;;
            *) warn "Opção inválida!" ;;
        esac
        
        read -p "Pressione ENTER para continuar..."
    done
}

# ========== FUNÇÕES DE MANIPULAÇÃO DE JSON ==========

# Adicionar ou atualizar campo no JSON
json_add() {
    local json_file=$1
    local jq_path=$2
    local value=$3
    
    if [[ -f $json_file ]]; then
        cat <<<$(jq "$jq_path = $value" $json_file) >$json_file
    else
        err "Arquivo JSON não encontrado: $json_file"
    fi
}

# Remover campo do JSON
json_del() {
    local json_file=$1
    local jq_path=$2
    
    if [[ -f $json_file ]]; then
        cat <<<$(jq "del($jq_path)" $json_file) >$json_file
    else
        err "Arquivo JSON não encontrado: $json_file"
    fi
}

# Obter valor do JSON
json_get() {
    local json_file=$1
    local jq_path=$2
    
    if [[ -f $json_file ]]; then
        jq -r "$jq_path" $json_file
    else
        err "Arquivo JSON não encontrado: $json_file"
    fi
}

# Validar sintaxe do JSON
json_validate() {
    local json_file=$1
    
    if [[ ! -f $json_file ]]; then
        err "Arquivo não encontrado: $json_file"
        return 1
    fi
    
    if jq empty $json_file 2>/dev/null; then
        return 0
    else
        _red "✗ JSON inválido: $json_file"
        jq empty $json_file
        return 1
    fi
}

# ========== FUNÇÕES DE GERENCIAMENTO DE CONFIGURAÇÃO ==========

# Obter lista de configurações
get_config_list() {
    if [[ -d $is_conf_dir ]]; then
        ls $is_conf_dir/*.json 2>/dev/null | sed 's|.*/||; s|\.json$||'
    fi
}

# Verificar se configuração existe
config_exists() {
    local name=$1
    [[ -f $is_conf_dir/${name}.json ]] && return 0 || return 1
}

# Obter configuração por nome
get_config() {
    local name=$1
    if config_exists "$name"; then
        cat $is_conf_dir/${name}.json
    else
        err "Configuração não encontrada: $name"
    fi
}

# Salvar configuração
save_config() {
    local name=$1
    local content=$2
    
    mkdir -p $is_conf_dir
    echo "$content" > $is_conf_dir/${name}.json
    
    # Validar JSON
    if json_validate $is_conf_dir/${name}.json; then
        _green "✓ Configuração salva: $name"
    else
        rm -f $is_conf_dir/${name}.json
        err "Falha ao salvar configuração (JSON inválido)"
    fi
}

# Deletar configuração
delete_config() {
    local name=$1
    
    if config_exists "$name"; then
        rm -f $is_conf_dir/${name}.json
        _green "✓ Configuração deletada: $name"
    else
        warn "Configuração não encontrada: $name"
    fi
}

# Listar todas as configurações
list_configs() {
    local configs=$(get_config_list)
    
    if [[ -z $configs ]]; then
        msg "Nenhuma configuração encontrada."
        return 0
    fi
    
    msg "\n═══════════════════════════════════════"
    msg "  CONFIGURAÇÕES DISPONÍVEIS"
    msg "═══════════════════════════════════════\n"
    
    local count=0
    for config in $configs; do
        ((count++))
        local protocol=$(json_get $is_conf_dir/${config}.json '.protocol')
        local port=$(json_get $is_conf_dir/${config}.json '.port')
        printf "  %2d) %-20s %-15s Porta: %s\n" $count "$config" "$protocol" "$port"
    done
    
    msg "\n═══════════════════════════════════════\n"
}

# ========== FUNÇÕES DE VALIDAÇÃO ==========

# Validar nome de configuração
validate_config_name() {
    local name=$1
    
    # Não pode ser vazio
    [[ -z $name ]] && {
        err "Nome da configuração não pode ser vazio"
        return 1
    }
    
    # Não pode conter caracteres especiais
    [[ ! $name =~ ^[a-zA-Z0-9_-]+$ ]] && {
        err "Nome inválido. Use apenas letras, números, - e _"
        return 1
    }
    
    return 0
}

# Validar porta
validate_port() {
    local port=$1
    
    # Verificar se é número
    [[ ! $port =~ ^[0-9]+$ ]] && {
        err "Porta inválida: $port"
        return 1
    }
    
    # Verificar range
    [[ $port -lt 1 || $port -gt 65535 ]] && {
        err "Porta fora do range válido (1-65535): $port"
        return 1
    }
    
    # Verificar se porta está em uso
    if ss -tlnp | grep -q ":$port "; then
        warn "Porta $port já está em uso"
        return 1
    fi
    
    return 0
}

# Validar UUID
validate_uuid() {
    local uuid=$1
    local uuid_regex='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    
    [[ $uuid =~ $uuid_regex ]] && return 0 || {
        err "UUID inválido: $uuid"
        return 1
    }
}

# Validar domínio
validate_domain() {
    local domain=$1
    local domain_regex='^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$'
    
    [[ $domain =~ $domain_regex ]] && return 0 || {
        err "Domínio inválido: $domain"
        return 1
    }
}

# ========== FUNÇÕES DE GERENCIAMENTO DE SERVIÇOS ==========

# Gerenciar serviço (start/stop/restart/status)
manage() {
    local action=$1
    local service=${2:-$is_core}
    
    case $action in
        start)
            systemctl start $service
            [[ $? -eq 0 ]] && _green "✓ Serviço iniciado: $service" || _red "✗ Falha ao iniciar: $service"
            ;;
        stop)
            systemctl stop $service
            [[ $? -eq 0 ]] && _green "✓ Serviço parado: $service" || _red "✗ Falha ao parar: $service"
            ;;
        restart)
            systemctl restart $service
            [[ $? -eq 0 ]] && _green "✓ Serviço reiniciado: $service" || _red "✗ Falha ao reiniciar: $service"
            ;;
        status)
            systemctl status $service
            ;;
        *)
            err "Ação inválida: $action (use: start, stop, restart, status)"
            ;;
    esac
}

# Verificar status do serviço
is_running() {
    systemctl is-active --quiet $is_core && return 0 || return 1
}
# ============================================================================
# SEÇÃO 3: FUNÇÕES DE INTERAÇÃO (ask) E CRIAÇÃO (create)
# Funções para perguntar ao usuário e criar arquivos de configuração
# ============================================================================

# ========== FUNÇÃO ASK - PERGUNTAR AO USUÁRIO ==========

# Função principal para fazer perguntas ao usuário
ask() {
    local type=$1
    local var_name=$2
    shift 2
    local options=("$@")
    
    case $type in
        list)
            # Mostrar lista de opções
            echo ""
            for i in "${!options[@]}"; do
                echo "  $((i+1))) ${options[$i]}"
            done
            echo ""
            read -p "Escolha uma opção [1-${#options[@]}]: " REPLY
            
            # Validar entrada
            if [[ ! $REPLY =~ ^[0-9]+$ ]] || [[ $REPLY -lt 1 ]] || [[ $REPLY -gt ${#options[@]} ]]; then
                err "Opção inválida!"
            fi
            
            # Atribuir valor à variável
            eval "$var_name='${options[$((REPLY-1))]}'"
            ;;
            
        string)
            # Perguntar string
            local prompt=${options[0]:-"Digite: "}
            read -p "$prompt" input
            
            # Validar se não está vazio
            [[ -z $input ]] && {
                err "Entrada não pode ser vazia!"
            }
            
            eval "$var_name='$input'"
            ;;
            
        number)
            # Perguntar número
            local prompt=${options[0]:-"Digite um número: "}
            read -p "$prompt" input
            
            # Validar se é número
            [[ ! $input =~ ^[0-9]+$ ]] && {
                err "Digite apenas números!"
            }
            
            eval "$var_name='$input'"
            ;;
            
        yn)
            # Pergunta sim/não
            local prompt=${options[0]:-"Confirmar? (s/N): "}
            read -p "$prompt" input
            
            [[ $input =~ ^[Ss]$ ]] && eval "$var_name=1" || eval "$var_name=0"
            ;;
            
        mainmenu)
            # Menu principal
            echo ""
            echo "═══════════════════════════════════════"
            echo "  XRAY2026 - MENU PRINCIPAL"
            echo "═══════════════════════════════════════"
            for i in "${!mainmenu[@]}"; do
                echo "  $((i+1))) ${mainmenu[$i]}"
            done
            echo ""
            echo "  0) Sair"
            echo "═══════════════════════════════════════"
            echo ""
            read -p "Escolha uma opção: " REPLY
            ;;
            
        *)
            err "Tipo de pergunta desconhecido: $type"
            ;;
    esac
}

# Perguntar protocolo
ask_protocol() {
    msg "\nEscolha o protocolo:\n"
    ask list protocol_choice "${protocol_list[@]}"
    protocol=${protocol_list[$((REPLY-1))]}
}

# Perguntar porta
ask_port() {
    local default_port=$(get_port)
    read -p "Digite a porta [$default_port]: " port
    port=${port:-$default_port}
    
    # Validar porta
    if ! validate_port "$port"; then
        err "Porta inválida ou em uso: $port"
    fi
}

# Perguntar UUID
ask_uuid() {
    local default_uuid=$(get_uuid)
    read -p "Digite o UUID [$default_uuid]: " uuid
    uuid=${uuid:-$default_uuid}
    
    # Validar UUID
    if ! validate_uuid "$uuid"; then
        err "UUID inválido: $uuid"
    fi
}

# Perguntar domínio
ask_domain() {
    read -p "Digite o domínio: " host
    
    # Validar domínio
    if ! validate_domain "$host"; then
        err "Domínio inválido: $host"
    fi
}

# Perguntar caminho (path)
ask_path() {
    local default_path="/$(_get_random_path)"
    read -p "Digite o caminho [$default_path]: " path
    path=${path:-$default_path}
    
    # Garantir que começa com /
    [[ ! $path =~ ^/ ]] && path="/$path"
}

# Gerar caminho aleatório
_get_random_path() {
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1
}

# Perguntar método de criptografia Shadowsocks
ask_ss_method() {
    msg "\nEscolha o método de criptografia:\n"
    ask list ss_method_choice "${ss_method_list[@]}"
    ss_method=${ss_method_list[$((REPLY-1))]}
}

# Perguntar senha
ask_password() {
    local default_pass=$(openssl rand -base64 16)
    read -p "Digite a senha [$default_pass]: " password
    password=${password:-$default_pass}
}

# Perguntar tipo de disfarce mKCP
ask_header_type() {
    msg "\nEscolha o tipo de disfarce:\n"
    ask list header_choice "${header_type_list[@]}"
    header_type=${header_type_list[$((REPLY-1))]}
}

# ========== FUNÇÕES CREATE - CRIAR CONFIGURAÇÕES ==========

# Criar configuração VLESS-REALITY
create_vless_reality() {
    local name=$1
    
    msg "Criando configuração VLESS-REALITY..."
    
    # Gerar chaves
    local keys=$($is_core_bin x25519)
    local private_key=$(echo "$keys" | grep "Private key:" | awk '{print $3}')
    local public_key=$(echo "$keys" | grep "Public key:" | awk '{print $3}')
    
    # Perguntar dados
    ask_port
    ask_uuid
    read -p "SNI (domínio de destino) [www.google.com]: " sni
    sni=${sni:-www.google.com}
    
    # Criar JSON
    local config=$(cat <<EOF
{
  "protocol": "vless",
  "port": $port,
  "settings": {
    "clients": [
      {
        "id": "$uuid",
        "flow": "xtls-rprx-vision"
      }
    ],
    "decryption": "none"
  },
  "streamSettings": {
    "network": "tcp",
    "security": "reality",
    "realitySettings": {
      "dest": "${sni}:443",
      "serverNames": ["${sni}"],
      "privateKey": "${private_key}",
      "shortIds": [""]
    }
  }
}
EOF
)
    
    # Salvar configuração
    save_config "$name" "$config"
    
    # Adicionar ao config principal
    add_inbound_to_main "$name"
    
    msg "\n✓ VLESS-REALITY criado com sucesso!"
    msg "Chave pública: $public_key"
    msg "Porta: $port"
}

# Criar configuração VLESS-WS-TLS
create_vless_ws_tls() {
    local name=$1
    
    msg "Criando configuração VLESS-WS-TLS..."
    
    # Perguntar dados
    ask_port
    ask_uuid
    ask_domain
    ask_path
    
    # Criar JSON
    local config=$(cat <<EOF
{
  "protocol": "vless",
  "port": $port,
  "settings": {
    "clients": [
      {
        "id": "$uuid"
      }
    ],
    "decryption": "none"
  },
  "streamSettings": {
    "network": "ws",
    "wsSettings": {
      "path": "$path"
    }
  }
}
EOF
)
    
    # Salvar configuração
    save_config "$name" "$config"
    
    # Configurar Caddy se necessário
    if [[ -f $is_caddy_bin ]]; then
        load caddy.sh
        caddy_config ws
        manage restart caddy
    fi
    
    # Adicionar ao config principal
    add_inbound_to_main "$name"
    
    msg "\n✓ VLESS-WS-TLS criado com sucesso!"
    msg "Domínio: $host"
    msg "Caminho: $path"
    msg "Porta: $port"
}

# Criar configuração VMess-TCP
create_vmess_tcp() {
    local name=$1
    
    msg "Criando configuração VMess-TCP..."
    
    # Perguntar dados
    ask_port
    ask_uuid
    
    # Criar JSON
    local config=$(cat <<EOF
{
  "protocol": "vmess",
  "port": $port,
  "settings": {
    "clients": [
      {
        "id": "$uuid",
        "alterId": 0
      }
    ]
  },
  "streamSettings": {
    "network": "tcp"
  }
}
EOF
)
    
    # Salvar configuração
    save_config "$name" "$config"
    
    # Adicionar ao config principal
    add_inbound_to_main "$name"
    
    msg "\n✓ VMess-TCP criado com sucesso!"
    msg "Porta: $port"
}

# Criar configuração Shadowsocks
create_shadowsocks() {
    local name=$1
    
    msg "Criando configuração Shadowsocks..."
    
    # Perguntar dados
    ask_port
    ask_ss_method
    
    # Gerar senha baseada no método
    local ss_password=$(get_ss2022_password "$ss_method")
    read -p "Senha [$ss_password]: " password
    password=${password:-$ss_password}
    
    # Criar JSON
    local config=$(cat <<EOF
{
  "protocol": "shadowsocks",
  "port": $port,
  "settings": {
    "method": "$ss_method",
    "password": "$password",
    "network": "tcp,udp"
  }
}
EOF
)
    
    # Salvar configuração
    save_config "$name" "$config"
    
    # Adicionar ao config principal
    add_inbound_to_main "$name"
    
    msg "\n✓ Shadowsocks criado com sucesso!"
    msg "Método: $ss_method"
    msg "Porta: $port"
}

# Criar configuração Trojan-WS-TLS
create_trojan_ws_tls() {
    local name=$1
    
    msg "Criando configuração Trojan-WS-TLS..."
    
    # Perguntar dados
    ask_port
    ask_password
    ask_domain
    ask_path
    
    # Criar JSON
    local config=$(cat <<EOF
{
  "protocol": "trojan",
  "port": $port,
  "settings": {
    "clients": [
      {
        "password": "$password"
      }
    ]
  },
  "streamSettings": {
    "network": "ws",
    "wsSettings": {
      "path": "$path"
    }
  }
}
EOF
)
    
    # Salvar configuração
    save_config "$name" "$config"
    
    # Configurar Caddy se necessário
    if [[ -f $is_caddy_bin ]]; then
        load caddy.sh
        caddy_config ws
        manage restart caddy
    fi
    
    # Adicionar ao config principal
    add_inbound_to_main "$name"
    
    msg "\n✓ Trojan-WS-TLS criado com sucesso!"
    msg "Domínio: $host"
    msg "Caminho: $path"
    msg "Porta: $port"
}

# Adicionar inbound ao config principal
add_inbound_to_main() {
    local config_name=$1
    local config_file="$is_conf_dir/${config_name}.json"
    
    if [[ ! -f $config_file ]]; then
        err "Arquivo de configuração não encontrado: $config_file"
    fi
    
    # Adicionar ao array de inbounds no config.json principal
    local inbound=$(cat $config_file)
    
    # Usar jq para adicionar ao array
    cat <<<$(jq ".inbounds += [$inbound]" $is_config_json) >$is_config_json
    
    # Validar JSON final
    if ! json_validate $is_config_json; then
        err "Erro ao adicionar inbound ao config.json"
    fi
}
# ============================================================================
# SEÇÃO 4: FUNÇÃO CHANGE - ALTERAR CONFIGURAÇÕES
# Funções para modificar configurações existentes
# ============================================================================

# ========== FUNÇÃO PRINCIPAL CHANGE ==========

# Função para alterar configurações
change() {
    local config_name=$1
    local change_type=$2
    shift 2
    local args=("$@")
    
    # Se não especificou config, listar e perguntar
    if [[ -z $config_name ]]; then
        list_configs
        read -p "Digite o nome da configuração: " config_name
    fi
    
    # Verificar se configuração existe
    if ! config_exists "$config_name"; then
        err "Configuração não encontrada: $config_name"
    fi
    
    # Se não especificou tipo de mudança, mostrar menu
    if [[ -z $change_type ]]; then
        msg "\nO que deseja alterar?\n"
        ask list change_choice "${change_list[@]}"
        change_type=$REPLY
    fi
    
    # Executar alteração baseada no tipo
    case $change_type in
        1)  change_protocol "$config_name" ;;
        2)  change_port "$config_name" "${args[@]}" ;;
        3)  change_domain "$config_name" "${args[@]}" ;;
        4)  change_path "$config_name" "${args[@]}" ;;
        5)  change_password "$config_name" "${args[@]}" ;;
        6)  change_uuid "$config_name" "${args[@]}" ;;
        7)  change_method "$config_name" "${args[@]}" ;;
        8)  change_header_type "$config_name" "${args[@]}" ;;
        9)  change_remote_addr "$config_name" "${args[@]}" ;;
        10) change_remote_port "$config_name" "${args[@]}" ;;
        11) change_key "$config_name" "${args[@]}" ;;
        12) change_sni "$config_name" "${args[@]}" ;;
        13) change_dynamic_port "$config_name" "${args[@]}" ;;
        14) change_proxy_site "$config_name" "${args[@]}" ;;
        15) change_mkcp_seed "$config_name" "${args[@]}" ;;
        16) change_username "$config_name" "${args[@]}" ;;
        *)
            err "Opção inválida!"
            ;;
    esac
    
    # Reiniciar serviço após mudança
    manage restart
}

# ========== FUNÇÕES DE ALTERAÇÃO ESPECÍFICAS ==========

# Alterar porta
change_port() {
    local config_name=$1
    local new_port=$2
    
    # Se não forneceu porta, perguntar
    if [[ -z $new_port ]]; then
        ask_port
        new_port=$port
    else
        # Validar porta fornecida
        if ! validate_port "$new_port"; then
            err "Porta inválida: $new_port"
        fi
    fi
    
    # Atualizar no JSON
    local config_file="$is_conf_dir/${config_name}.json"
    cat <<<$(jq ".port = $new_port" $config_file) >$config_file
    
    # Atualizar no config principal
    update_main_config "$config_name"
    
    _green "✓ Porta alterada para: $new_port"
}

# Alterar UUID
change_uuid() {
    local config_name=$1
    local new_uuid=$2
    
    # Se não forneceu UUID, perguntar
    if [[ -z $new_uuid ]]; then
        ask_uuid
        new_uuid=$uuid
    else
        # Validar UUID fornecido
        if ! validate_uuid "$new_uuid"; then
            err "UUID inválido: $new_uuid"
        fi
    fi
    
    # Atualizar no JSON
    local config_file="$is_conf_dir/${config_name}.json"
    cat <<<$(jq ".settings.clients[0].id = \"$new_uuid\"" $config_file) >$config_file
    
    # Atualizar no config principal
    update_main_config "$config_name"
    
    _green "✓ UUID alterado para: $new_uuid"
}

# Alterar domínio
change_domain() {
    local config_name=$1
    local new_domain=$2
    
    # Se não forneceu domínio, perguntar
    if [[ -z $new_domain ]]; then
        ask_domain
        new_domain=$host
    else
        # Validar domínio fornecido
        if ! validate_domain "$new_domain"; then
            err "Domínio inválido: $new_domain"
        fi
    fi
    
    # Atualizar configuração do Caddy
    if [[ -f $is_caddy_bin ]]; then
        load caddy.sh
        
        # Remover configuração antiga
        local old_domain=$(json_get "$is_conf_dir/${config_name}.json" '.domain')
        [[ -f $is_caddy_conf/${old_domain}.conf ]] && rm -f $is_caddy_conf/${old_domain}.conf
        
        # Criar nova configuração
        host=$new_domain
        caddy_config $(json_get "$is_conf_dir/${config_name}.json" '.protocol')
        
        # Recarregar Caddy
        manage restart caddy
    fi
    
    # Atualizar no JSON
    local config_file="$is_conf_dir/${config_name}.json"
    cat <<<$(jq ".domain = \"$new_domain\"" $config_file) >$config_file
    
    _green "✓ Domínio alterado para: $new_domain"
}

# Alterar caminho (path)
change_path() {
    local config_name=$1
    local new_path=$2
    
    # Se não forneceu path, perguntar
    if [[ -z $new_path ]]; then
        ask_path
        new_path=$path
    fi
    
    # Garantir que começa com /
    [[ ! $new_path =~ ^/ ]] && new_path="/$new_path"
    
    # Atualizar no JSON
    local config_file="$is_conf_dir/${config_name}.json"
    cat <<<$(jq ".streamSettings.wsSettings.path = \"$new_path\"" $config_file) >$config_file
    
    # Atualizar configuração do Caddy se necessário
    if [[ -f $is_caddy_bin ]]; then
        load caddy.sh
        path=$new_path
        host=$(json_get "$config_file" '.domain')
        port=$(json_get "$config_file" '.port')
        caddy_config $(json_get "$config_file" '.protocol')
        manage restart caddy
    fi
    
    # Atualizar no config principal
    update_main_config "$config_name"
    
    _green "✓ Caminho alterado para: $new_path"
}

# Alterar senha (Shadowsocks/Trojan)
change_password() {
    local config_name=$1
    local new_password=$2
    
    # Se não forneceu senha, perguntar
    if [[ -z $new_password ]]; then
        ask_password
        new_password=$password
    fi
    
    # Verificar protocolo
    local config_file="$is_conf_dir/${config_name}.json"
    local protocol=$(json_get "$config_file" '.protocol')
    
    case $protocol in
        shadowsocks)
            cat <<<$(jq ".settings.password = \"$new_password\"" $config_file) >$config_file
            ;;
        trojan)
            cat <<<$(jq ".settings.clients[0].password = \"$new_password\"" $config_file) >$config_file
            ;;
        *)
            err "Este protocolo não usa senha"
            ;;
    esac
    
    # Atualizar no config principal
    update_main_config "$config_name"
    
    _green "✓ Senha alterada"
}

# Alterar método de criptografia (Shadowsocks)
change_method() {
    local config_name=$1
    local new_method=$2
    
    # Verificar se é Shadowsocks
    local config_file="$is_conf_dir/${config_name}.json"
    local protocol=$(json_get "$config_file" '.protocol')
    
    [[ $protocol != "shadowsocks" ]] && err "Esta configuração não é Shadowsocks"
    
    # Se não forneceu método, perguntar
    if [[ -z $new_method ]]; then
        ask_ss_method
        new_method=$ss_method
    fi
    
    # Validar método
    local valid=0
    for method in "${ss_method_list[@]}"; do
        [[ $method == $new_method ]] && valid=1 && break
    done
    [[ $valid -eq 0 ]] && err "Método inválido: $new_method"
    
    # Atualizar no JSON
    cat <<<$(jq ".settings.method = \"$new_method\"" $config_file) >$config_file
    
    # Atualizar no config principal
    update_main_config "$config_name"
    
    _green "✓ Método de criptografia alterado para: $new_method"
}

# Alterar tipo de disfarce (mKCP)
change_header_type() {
    local config_name=$1
    local new_type=$2
    
    # Se não forneceu tipo, perguntar
    if [[ -z $new_type ]]; then
        ask_header_type
        new_type=$header_type
    fi
    
    # Validar tipo
    local valid=0
    for type in "${header_type_list[@]}"; do
        [[ $type == $new_type ]] && valid=1 && break
    done
    [[ $valid -eq 0 ]] && err "Tipo inválido: $new_type"
    
    # Atualizar no JSON
    local config_file="$is_conf_dir/${config_name}.json"
    cat <<<$(jq ".streamSettings.kcpSettings.header.type = \"$new_type\"" $config_file) >$config_file
    
    # Atualizar no config principal
    update_main_config "$config_name"
    
    _green "✓ Tipo de disfarce alterado para: $new_type"
}

# Alterar SNI (Server Name Indication)
change_sni() {
    local config_name=$1
    local new_sni=$2
    
    # Se não forneceu SNI, perguntar
    if [[ -z $new_sni ]]; then
        read -p "Digite o novo SNI: " new_sni
    fi
    
    # Atualizar no JSON
    local config_file="$is_conf_dir/${config_name}.json"
    cat <<<$(jq ".streamSettings.realitySettings.serverNames = [\"$new_sni\"]" $config_file) >$config_file
    cat <<<$(jq ".streamSettings.realitySettings.dest = \"${new_sni}:443\"" $config_file) >$config_file
    
    # Atualizar no config principal
    update_main_config "$config_name"
    
    _green "✓ SNI alterado para: $new_sni"
}

# Alterar chave privada (REALITY)
change_key() {
    local config_name=$1
    local new_key=$2
    
    # Se especificou "auto", gerar nova chave
    if [[ $new_key == "auto" || -z $new_key ]]; then
        msg "Gerando novo par de chaves..."
        local keys=$($is_core_bin x25519)
        new_key=$(echo "$keys" | grep "Private key:" | awk '{print $3}')
        local public_key=$(echo "$keys" | grep "Public key:" | awk '{print $3}')
    fi
    
    # Atualizar no JSON
    local config_file="$is_conf_dir/${config_name}.json"
    cat <<<$(jq ".streamSettings.realitySettings.privateKey = \"$new_key\"" $config_file) >$config_file
    
    # Atualizar no config principal
    update_main_config "$config_name"
    
    _green "✓ Chave privada alterada"
    [[ $public_key ]] && msg "Nova chave pública: $public_key"
}

# Alterar protocolo (recria configuração)
change_protocol() {
    local config_name=$1
    
    msg "Para alterar o protocolo, a configuração será recriada."
    read -p "Continuar? (s/N): " confirm
    
    [[ ! $confirm =~ ^[Ss]$ ]] && {
        msg "Operação cancelada."
        return 0
    }
    
    # Deletar configuração antiga
    delete_config "$config_name"
    
    # Criar nova configuração
    msg "\nCriando nova configuração..."
    ask_protocol
    
    case $protocol in
        *REALITY*)
            create_vless_reality "$config_name"
            ;;
        *WS*)
            create_vless_ws_tls "$config_name"
            ;;
        VLESS-XTLS)
            create_vless_xtls "$config_name"
            ;;
        VMess-TCP)
            create_vmess_tcp "$config_name"
            ;;
        Shadowsocks)
            create_shadowsocks "$config_name"
            ;;
        Trojan*)
            create_trojan_ws_tls "$config_name"
            ;;
        *)
            err "Protocolo não suportado: $protocol"
            ;;
    esac
}

# ========== FUNÇÕES AUXILIARES DE CHANGE ==========

# Atualizar configuração no config.json principal
update_main_config() {
    local config_name=$1
    local config_file="$is_conf_dir/${config_name}.json"
    
    if [[ ! -f $config_file ]]; then
        err "Arquivo de configuração não encontrado: $config_file"
    fi
    
    # Remover inbound antigo
    cat <<<$(jq "del(.inbounds[] | select(.tag == \"$config_name\"))" $is_config_json) >$is_config_json
    
    # Adicionar inbound atualizado
    local inbound=$(cat $config_file)
    cat <<<$(jq ".inbounds += [$inbound]" $is_config_json) >$is_config_json
    
    # Validar JSON
    if ! json_validate $is_config_json; then
        err "Erro ao atualizar config.json"
    fi
}

# Alterar múltiplos parâmetros de uma vez
change_full() {
    local config_name=$1
    shift
    local params=("$@")
    
    msg "Alterando múltiplos parâmetros de: $config_name"
    
    # Processar cada parâmetro
    for param in "${params[@]}"; do
        case $param in
            port=*)
                change_port "$config_name" "${param#*=}"
                ;;
            uuid=*)
                change_uuid "$config_name" "${param#*=}"
                ;;
            domain=*)
                change_domain "$config_name" "${param#*=}"
                ;;
            path=*)
                change_path "$config_name" "${param#*=}"
                ;;
            password=*)
                change_password "$config_name" "${param#*=}"
                ;;
            *)
                warn "Parâmetro desconhecido: $param"
                ;;
        esac
    done
    
    _green "✓ Todas as alterações aplicadas!"
}
# ============================================================================
# SEÇÃO 5: FUNÇÕES DEL, UNINSTALL E API
# Funções para deletar, desinstalar e gerenciar API
# ============================================================================

# ========== FUNÇÃO DEL - DELETAR CONFIGURAÇÕES ==========

# Deletar uma configuração
del() {
    local config_name=$1
    
    # Se não especificou config, listar e perguntar
    if [[ -z $config_name ]]; then
        list_configs
        read -p "Digite o nome da configuração para deletar: " config_name
    fi
    
    # Verificar se configuração existe
    if ! config_exists "$config_name"; then
        err "Configuração não encontrada: $config_name"
    fi
    
    # Confirmar deleção
    read -p "Tem certeza que deseja deletar '$config_name'? (s/N): " confirm
    [[ ! $confirm =~ ^[Ss]$ ]] && {
        msg "Operação cancelada."
        return 0
    }
    
    msg "\nDeletando configuração: $config_name"
    
    # Remover do config.json principal
    cat <<<$(jq "del(.inbounds[] | select(.tag == \"$config_name\"))" $is_config_json) >$is_config_json
    
    # Deletar arquivo de configuração
    rm -f "$is_conf_dir/${config_name}.json"
    
    # Remover configuração do Caddy se existir
    if [[ -d $is_caddy_conf ]]; then
        local domain=$(json_get "$is_conf_dir/${config_name}.json" '.domain' 2>/dev/null)
        if [[ $domain ]]; then
            rm -f "$is_caddy_conf/${domain}.conf"
            rm -f "$is_caddy_conf/${domain}.conf.add"
            [[ -f $is_caddy_bin ]] && manage restart caddy
        fi
    fi
    
    # Reiniciar serviço
    manage restart
    
    _green "✓ Configuração deletada: $config_name"
}

# Deletar múltiplas configurações
ddel() {
    local configs=("$@")
    
    if [[ ${#configs[@]} -eq 0 ]]; then
        list_configs
        msg "\nDigite os nomes das configurações para deletar (separados por espaço):"
        read -a configs
    fi
    
    msg "\nSerão deletadas ${#configs[@]} configurações:"
    for config in "${configs[@]}"; do
        echo "  • $config"
    done
    
    read -p "\nConfirmar? (s/N): " confirm
    [[ ! $confirm =~ ^[Ss]$ ]] && {
        msg "Operação cancelada."
        return 0
    }
    
    local deleted=0
    local failed=0
    
    for config in "${configs[@]}"; do
        if config_exists "$config"; then
            del "$config" <<< "s"  # Passar 's' automaticamente
            ((deleted++))
        else
            warn "Configuração não encontrada: $config"
            ((failed++))
        fi
    done
    
    msg "\n═══════════════════════════════════════"
    _green "✓ Deletadas: $deleted"
    [[ $failed -gt 0 ]] && _red "✗ Falhas: $failed"
    msg "═══════════════════════════════════════\n"
}

# ========== FUNÇÃO UNINSTALL - DESINSTALAR SISTEMA ==========

# Desinstalar Xray2026 completamente
uninstall() {
    msg "\n═══════════════════════════════════════"
    msg "  DESINSTALAÇÃO DO XRAY2026"
    msg "═══════════════════════════════════════\n"
    
    _red "ATENÇÃO: Esta ação irá:"
    msg "  • Parar todos os serviços"
    msg "  • Remover binários do Xray"
    msg "  • Deletar todas as configurações"
    msg "  • Remover scripts do sistema"
    msg "  • Deletar banco de dados de usuários"
    [[ -f $is_caddy_bin ]] && msg "  • Remover Caddy (opcional)"
    msg ""
    
    read -p "Tem certeza que deseja desinstalar? (digite 'sim' para confirmar): " confirm
    
    [[ $confirm != "sim" ]] && {
        msg "\nOperação cancelada."
        return 0
    }
    
    msg "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    msg "Iniciando desinstalação..."
    msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
    
    # Parar serviços
    msg "1. Parando serviços..."
    systemctl stop $is_core &>/dev/null
    systemctl disable $is_core &>/dev/null
    [[ -f $is_caddy_bin ]] && {
        systemctl stop caddy &>/dev/null
        systemctl disable caddy &>/dev/null
    }
    _green "   ✓ Serviços parados"
    
    # Remover arquivos de serviço
    msg "2. Removendo serviços do systemd..."
    rm -f /lib/systemd/system/$is_core.service
    rm -f /lib/systemd/system/caddy.service
    systemctl daemon-reload &>/dev/null
    _green "   ✓ Serviços removidos"
    
    # Remover diretórios principais
    msg "3. Removendo arquivos do sistema..."
    rm -rf $is_core_dir
    rm -rf $is_sh_dir
    rm -rf /var/log/$is_core
    _green "   ✓ Arquivos removidos"
    
    # Remover link simbólico
    msg "4. Removendo comando global..."
    rm -f /usr/local/bin/$is_core
    rm -f /usr/local/bin/xray
    _green "   ✓ Comando removido"
    
    # Perguntar sobre Caddy
    if [[ -f $is_caddy_bin ]]; then
        read -p "5. Remover Caddy também? (s/N): " remove_caddy
        if [[ $remove_caddy =~ ^[Ss]$ ]]; then
            rm -rf $is_caddy_dir
            rm -f $is_caddy_bin
            _green "   ✓ Caddy removido"
        else
            _yellow "   ⊙ Caddy mantido"
        fi
    fi
    
    # Perguntar sobre banco de usuários
    read -p "6. Remover banco de dados de usuários? (s/N): " remove_users
    if [[ $remove_users =~ ^[Ss]$ ]]; then
        rm -rf /etc/xray/users
        _green "   ✓ Banco de usuários removido"
    else
        _yellow "   ⊙ Banco de usuários mantido em /etc/xray/users"
    fi
    
    msg "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    _green "✓ Desinstalação concluída!"
    msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
    
    msg "Obrigado por usar o Xray2026!"
    msg "GitHub: https://github.com/PhoenixxZ2023/xray2026\n"
}

# Desinstalar apenas o script (manter Xray)
uninstall_script() {
    msg "Removendo apenas scripts do Xray2026..."
    
    read -p "Continuar? (s/N): " confirm
    [[ ! $confirm =~ ^[Ss]$ ]] && return 0
    
    rm -rf $is_sh_dir
    rm -f /usr/local/bin/$is_core
    rm -f /usr/local/bin/xray
    
    _green "✓ Scripts removidos. Xray-core mantido."
}

# ========== FUNÇÃO API - GERENCIAR API DO XRAY ==========

# Gerenciar API do Xray
api() {
    local command=$1
    shift
    local args=("$@")
    
    # Verificar se API está habilitada
    local api_port=$(json_get $is_config_json '.api.services[] | select(. == "HandlerService") | 10085' 2>/dev/null)
    
    if [[ -z $api_port ]]; then
        warn "API não está habilitada"
        read -p "Deseja habilitar a API agora? (s/N): " enable_api
        if [[ $enable_api =~ ^[Ss]$ ]]; then
            enable_xray_api
        else
            return 1
        fi
    fi
    
    case $command in
        stats)
            api_get_stats "${args[@]}"
            ;;
        user)
            api_manage_user "${args[@]}"
            ;;
        online)
            api_get_online_users
            ;;
        reset)
            api_reset_stats "${args[@]}"
            ;;
        *)
            show_api_help
            ;;
    esac
}

# Habilitar API Stats do Xray
enable_xray_api() {
    msg "Habilitando API Stats do Xray..."
    
    # Adicionar configuração de API
    cat <<<$(jq '.api = {
        "tag": "api",
        "services": ["HandlerService", "StatsService"]
    }' $is_config_json) >$is_config_json
    
    # Adicionar inbound da API
    cat <<<$(jq '.inbounds += [{
        "tag": "api",
        "port": 10085,
        "listen": "127.0.0.1",
        "protocol": "dokodemo-door",
        "settings": {
            "address": "127.0.0.1"
        }
    }]' $is_config_json) >$is_config_json
    
    # Adicionar routing para API
    cat <<<$(jq '.routing.rules += [{
        "type": "field",
        "inboundTag": ["api"],
        "outboundTag": "api"
    }]' $is_config_json) >$is_config_json
    
    # Adicionar stats
    cat <<<$(jq '.stats = {}' $is_config_json) >$is_config_json
    
    # Adicionar policy para stats
    cat <<<$(jq '.policy = {
        "levels": {
            "0": {
                "statsUserUplink": true,
                "statsUserDownlink": true
            }
        },
        "system": {
            "statsInboundUplink": true,
            "statsInboundDownlink": true
        }
    }' $is_config_json) >$is_config_json
    
    # Reiniciar serviço
    manage restart
    
    _green "✓ API Stats habilitada na porta 10085"
}

# Obter estatísticas via API
api_get_stats() {
    local pattern=${1:-""}
    
    msg "Obtendo estatísticas..."
    
    local stats=$($is_core_bin api stats --server=127.0.0.1:10085 2>/dev/null)
    
    if [[ -z $stats ]]; then
        err "Falha ao obter estatísticas. Verifique se a API está habilitada."
    fi
    
    if [[ $pattern ]]; then
        echo "$stats" | grep "$pattern"
    else
        echo "$stats"
    fi
}

# Obter usuários online
api_get_online_users() {
    msg "\n═══════════════════════════════════════"
    msg "  USUÁRIOS ONLINE"
    msg "═══════════════════════════════════════\n"
    
    local stats=$(api_get_stats "user")
    
    if [[ -z $stats ]]; then
        msg "Nenhum usuário online no momento."
        return 0
    fi
    
    echo "$stats" | while read line; do
        local user=$(echo "$line" | grep -oP 'user>>>\K[^>]+')
        local traffic=$(echo "$line" | grep -oP 'value:\s*\K\d+')
        
        if [[ $user && $traffic -gt 0 ]]; then
            printf "  • %-30s %10s MB\n" "$user" "$((traffic / 1024 / 1024))"
        fi
    done
    
    msg "\n═══════════════════════════════════════\n"
}

# Resetar estatísticas
api_reset_stats() {
    local pattern=${1:-""}
    
    read -p "Resetar estatísticas? (s/N): " confirm
    [[ ! $confirm =~ ^[Ss]$ ]] && return 0
    
    msg "Resetando estatísticas..."
    
    $is_core_bin api statsreset --server=127.0.0.1:10085 $pattern
    
    _green "✓ Estatísticas resetadas"
}

# Ajuda da API
show_api_help() {
    cat <<EOF

═══════════════════════════════════════════════════════════════════
  API do Xray - Xray2026
═══════════════════════════════════════════════════════════════════

Uso: xray api [comando] [opções]

COMANDOS:
  stats [pattern]          Obter estatísticas
  online                   Listar usuários online
  reset [pattern]          Resetar estatísticas
  user [add|remove] [email] Gerenciar usuários

EXEMPLOS:
  xray api stats
  xray api stats user
  xray api online
  xray api reset

═══════════════════════════════════════════════════════════════════

EOF
}

# ========== FUNÇÕES AUXILIARES ==========

# Fazer backup antes de operações destrutivas
backup_config() {
    local backup_dir="/tmp/xray_backup_$(date +%Y%m%d_%H%M%S)"
    
    mkdir -p $backup_dir
    
    cp -r $is_core_dir $backup_dir/ 2>/dev/null
    cp -r $is_conf_dir $backup_dir/ 2>/dev/null
    cp $is_config_json $backup_dir/ 2>/dev/null
    
    _green "✓ Backup criado em: $backup_dir"
    echo "$backup_dir" > /tmp/xray_last_backup
}

# Restaurar último backup
restore_backup() {
    if [[ ! -f /tmp/xray_last_backup ]]; then
        warn "Nenhum backup encontrado"
        return 1
    fi
    
    local backup_dir=$(cat /tmp/xray_last_backup)
    
    if [[ ! -d $backup_dir ]]; then
        err "Diretório de backup não existe: $backup_dir"
    fi
    
    msg "Restaurando backup de: $backup_dir"
    
    cp -rf $backup_dir/* /
    
    manage restart
    
    _green "✓ Backup restaurado com sucesso!"
}
show_backup_menu() {
    while :; do
        clear
        msg "\n═══════════════════════════════════════"
        msg "  BACKUP E RESTAURAÇÃO"
        msg "═══════════════════════════════════════"
        msg "  1) Fazer backup completo"
        msg "  2) Restaurar último backup"
        msg "  3) Listar backups disponíveis"
        msg "  4) Deletar backups antigos"
        msg ""
        msg "  0) Voltar"
        msg "═══════════════════════════════════════\n"
        
        read -p "Escolha uma opção: " option
        
        case $option in
            1) backup_config ;;
            2) restore_backup ;;
            3) ls -lh /tmp/xray_backup_* 2>/dev/null || msg "Nenhum backup encontrado" ;;
            4) 
                read -p "Deletar backups com mais de quantos dias? [7]: " days
                find /tmp -name "xray_backup_*" -mtime +${days:-7} -exec rm -rf {} \;
                _green "✓ Backups antigos removidos"
                ;;
            0) break ;;
            *) warn "Opção inválida!" ;;
        esac
        
        read -p "Pressione ENTER para continuar..."
    done
}

show_caddy_menu() {
    while :; do
        clear
        msg "\n═══════════════════════════════════════"
        msg "  GERENCIAMENTO DO CADDY"
        msg "═══════════════════════════════════════"
        msg "  1) Iniciar Caddy"
        msg "  2) Parar Caddy"
        msg "  3) Reiniciar Caddy"
        msg "  4) Ver Status do Caddy"
        msg "  5) Ver Logs do Caddy"
        msg "  6) Validar Configuração"
        msg "  7) Listar Sites"
        msg ""
        msg "  0) Voltar"
        msg "═══════════════════════════════════════\n"
        
        read -p "Escolha uma opção: " option
        
        case $option in
            1) manage start caddy ;;
            2) manage stop caddy ;;
            3) manage restart caddy ;;
            4) manage status caddy ;;
            5) journalctl -u caddy -n 50 --no-pager ;;
            6) $is_caddy_bin validate --config $is_caddyfile --adapter caddyfile ;;
            7) load caddy.sh && list_caddy_sites ;;
            0) break ;;
            *) warn "Opção inválida!" ;;
        esac
        
        read -p "Pressione ENTER para continuar..."
    done
}

# ============================================================================
# SEÇÃO 6: FUNÇÃO ADD - ADICIONAR CONFIGURAÇÕES
# Wrapper principal para criar novas configurações
# ============================================================================

# ========== FUNÇÃO PRINCIPAL ADD ==========

# Adicionar nova configuração
add() {
    local protocol=$1
    shift
    local args=("$@")
    
    # Se não especificou protocolo, perguntar
    if [[ -z $protocol ]]; then
        msg "\n═══════════════════════════════════════"
        msg "  ADICIONAR NOVA CONFIGURAÇÃO"
        msg "═══════════════════════════════════════\n"
        ask_protocol
    else
        # Buscar protocolo no array
        for i in "${!protocol_list[@]}"; do
            if [[ ${protocol_list[$i]} == "$protocol" ]]; then
                protocol=${protocol_list[$i]}
                break
            fi
        done
    fi
    
    # Perguntar nome da configuração
    read -p "\nDigite um nome para esta configuração: " config_name
    
    # Validar nome
    if ! validate_config_name "$config_name"; then
        err "Nome inválido: $config_name"
    fi
    
    # Verificar se já existe
    if config_exists "$config_name"; then
        err "Já existe uma configuração com este nome: $config_name"
    fi
    
    msg "\nCriando configuração: $config_name"
    msg "Protocolo: $protocol\n"
    
    # Criar configuração baseada no protocolo
    case $protocol in
        VLESS-REALITY)
            create_vless_reality "$config_name"
            ;;
        VLESS-WS-TLS)
            create_vless_ws_tls "$config_name"
            ;;
        VLESS-gRPC-TLS)
            create_vless_grpc_tls "$config_name"
            ;;
        VLESS-XHTTP-TLS)
            create_vless_xhttp_tls "$config_name"
            ;;
        VLESS-XTLS)
            create_vless_xtls "$config_name"
            ;;
        VMess-TCP)
            create_vmess_tcp "$config_name"
            ;;
        VMess-mKCP)
            create_vmess_mkcp "$config_name"
            ;;
        VMess-WS-TLS)
            create_vmess_ws_tls "$config_name"
            ;;
        VMess-gRPC-TLS)
            create_vmess_grpc_tls "$config_name"
            ;;
        Trojan-WS-TLS)
            create_trojan_ws_tls "$config_name"
            ;;
        Trojan-gRPC-TLS)
            create_trojan_grpc_tls "$config_name"
            ;;
        Shadowsocks)
            create_shadowsocks "$config_name"
            ;;
        Socks)
            create_socks "$config_name"
            ;;
        VMess-TCP-dynamic-port)
            create_vmess_tcp_dynamic "$config_name"
            ;;
        VMess-mKCP-dynamic-port)
            create_vmess_mkcp_dynamic "$config_name"
            ;;
        *)
            err "Protocolo não suportado: $protocol"
            ;;
    esac
    
    # Exibir informações da configuração criada
    msg "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    _green "✓ Configuração criada com sucesso!"
    msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
    
    # Mostrar informações
    info "$config_name"
}

# ========== FUNÇÕES CREATE ADICIONAIS ==========

# Criar configuração VLESS-gRPC-TLS
create_vless_grpc_tls() {
    local name=$1
    
    msg "Criando configuração VLESS-gRPC-TLS..."
    
    # Perguntar dados
    ask_port
    ask_uuid
    ask_domain
    
    # Gerar service name aleatório
    local service_name=$(_get_random_path)
    read -p "Service Name [$service_name]: " input_service
    service_name=${input_service:-$service_name}
    
    # Criar JSON
    local config=$(cat <<EOF
{
  "protocol": "vless",
  "port": $port,
  "settings": {
    "clients": [
      {
        "id": "$uuid"
      }
    ],
    "decryption": "none"
  },
  "streamSettings": {
    "network": "grpc",
    "grpcSettings": {
      "serviceName": "$service_name"
    }
  }
}
EOF
)
    
    # Salvar configuração
    save_config "$name" "$config"
    
    # Configurar Caddy
    if [[ -f $is_caddy_bin ]]; then
        load caddy.sh
        host=$host
        path=$service_name
        caddy_config grpc
        manage restart caddy
    fi
    
    # Adicionar ao config principal
    add_inbound_to_main "$name"
    
    msg "\n✓ VLESS-gRPC-TLS criado com sucesso!"
}

# Criar configuração VLESS-XHTTP-TLS
create_vless_xhttp_tls() {
    local name=$1
    
    msg "Criando configuração VLESS-XHTTP-TLS..."
    
    # Perguntar dados
    ask_port
    ask_uuid
    ask_domain
    ask_path
    
    # Criar JSON
    local config=$(cat <<EOF
{
  "protocol": "vless",
  "port": $port,
  "settings": {
    "clients": [
      {
        "id": "$uuid"
      }
    ],
    "decryption": "none"
  },
  "streamSettings": {
    "network": "xhttp",
    "xhttpSettings": {
      "path": "$path"
    }
  }
}
EOF
)
    
    # Salvar configuração
    save_config "$name" "$config"
    
    # Configurar Caddy
    if [[ -f $is_caddy_bin ]]; then
        load caddy.sh
        caddy_config xhttp
        manage restart caddy
    fi
    
    # Adicionar ao config principal
    add_inbound_to_main "$name"
    
    msg "\n✓ VLESS-XHTTP-TLS criado com sucesso!"
}

# Criar configuração VMess-mKCP
create_vmess_mkcp() {
    local name=$1
    
    msg "Criando configuração VMess-mKCP..."
    
    # Perguntar dados
    ask_port
    ask_uuid
    ask_header_type
    
    # Gerar seed aleatório
    local seed=$(_get_random_path)
    read -p "mKCP Seed [$seed]: " input_seed
    seed=${input_seed:-$seed}
    
    # Criar JSON
    local config=$(cat <<EOF
{
  "protocol": "vmess",
  "port": $port,
  "settings": {
    "clients": [
      {
        "id": "$uuid",
        "alterId": 0
      }
    ]
  },
  "streamSettings": {
    "network": "kcp",
    "kcpSettings": {
      "header": {
        "type": "$header_type"
      },
      "seed": "$seed"
    }
  }
}
EOF
)
    
    # Salvar configuração
    save_config "$name" "$config"
    
    # Adicionar ao config principal
    add_inbound_to_main "$name"
    
    msg "\n✓ VMess-mKCP criado com sucesso!"
}
# ========== CRIAR VLESS-XTLS ==========
create_vless_xtls() {
    local config_name="$1"
    
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  CRIAR CONFIGURAÇÃO VLESS-XTLS"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    # Gerar UUID automaticamente
    local uuid=$(uuidgen)
    _green "✓ UUID gerado: $uuid"
    
    # Gerar caminho automaticamente (8 caracteres aleatórios)
    local path=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
    _green "✓ Caminho gerado: /$path"
    
    echo ""
    
    # Solicitar porta
    read -p "Digite a porta [443]: " port
    port=${port:-443}
    
    # Solicitar domínio
    while true; do
        read -p "Digite o domínio (ex: example.com): " domain
        
        if [[ -z "$domain" ]]; then
            _red "✗ Domínio não pode ser vazio"
            continue
        fi
        
        # Verificar DNS (se dnsutils estiver instalado)
        if command -v dig >/dev/null 2>&1; then
            _yellow "⏳ Verificando DNS do domínio..."
            domain_ip=$(dig +short "$domain" | head -n1)
            
            if [[ -n "$domain_ip" ]]; then
                _green "✓ DNS verificado: $domain → $domain_ip"
                break
            else
                _yellow "⚠ Domínio não resolve para nenhum IP"
                read -p "Deseja continuar mesmo assim? (s/N): " continue_anyway
                if [[ "$continue_anyway" == "s" || "$continue_anyway" == "S" ]]; then
                    break
                fi
            fi
        else
            break
        fi
    done
    
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
        _yellow "💡 Instale qrencode para gerar QR Code: apt install qrencode"
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

# Criar configuração VMess-WS-TLS
create_vmess_ws_tls() {
    local name=$1
    
    msg "Criando configuração VMess-WS-TLS..."
    
    # Perguntar dados
    ask_port
    ask_uuid
    ask_domain
    ask_path
    
    # Criar JSON
    local config=$(cat <<EOF
{
  "protocol": "vmess",
  "port": $port,
  "settings": {
    "clients": [
      {
        "id": "$uuid",
        "alterId": 0
      }
    ]
  },
  "streamSettings": {
    "network": "ws",
    "wsSettings": {
      "path": "$path"
    }
  }
}
EOF
)
    
    # Salvar configuração
    save_config "$name" "$config"
    
    # Configurar Caddy
    if [[ -f $is_caddy_bin ]]; then
        load caddy.sh
        caddy_config ws
        manage restart caddy
    fi
    
    # Adicionar ao config principal
    add_inbound_to_main "$name"
    
    msg "\n✓ VMess-WS-TLS criado com sucesso!"
}

# Criar configuração VMess-gRPC-TLS
create_vmess_grpc_tls() {
    local name=$1
    
    msg "Criando configuração VMess-gRPC-TLS..."
    
    # Perguntar dados
    ask_port
    ask_uuid
    ask_domain
    
    # Gerar service name aleatório
    local service_name=$(_get_random_path)
    read -p "Service Name [$service_name]: " input_service
    service_name=${input_service:-$service_name}
    
    # Criar JSON
    local config=$(cat <<EOF
{
  "protocol": "vmess",
  "port": $port,
  "settings": {
    "clients": [
      {
        "id": "$uuid",
        "alterId": 0
      }
    ]
  },
  "streamSettings": {
    "network": "grpc",
    "grpcSettings": {
      "serviceName": "$service_name"
    }
  }
}
EOF
)
    
    # Salvar configuração
    save_config "$name" "$config"
    
    # Configurar Caddy
    if [[ -f $is_caddy_bin ]]; then
        load caddy.sh
        path=$service_name
        caddy_config grpc
        manage restart caddy
    fi
    
    # Adicionar ao config principal
    add_inbound_to_main "$name"
    
    msg "\n✓ VMess-gRPC-TLS criado com sucesso!"
}

# Criar configuração Trojan-gRPC-TLS
create_trojan_grpc_tls() {
    local name=$1
    
    msg "Criando configuração Trojan-gRPC-TLS..."
    
    # Perguntar dados
    ask_port
    ask_password
    ask_domain
    
    # Gerar service name aleatório
    local service_name=$(_get_random_path)
    read -p "Service Name [$service_name]: " input_service
    service_name=${input_service:-$service_name}
    
    # Criar JSON
    local config=$(cat <<EOF
{
  "protocol": "trojan",
  "port": $port,
  "settings": {
    "clients": [
      {
        "password": "$password"
      }
    ]
  },
  "streamSettings": {
    "network": "grpc",
    "grpcSettings": {
      "serviceName": "$service_name"
    }
  }
}
EOF
)
    
    # Salvar configuração
    save_config "$name" "$config"
    
    # Configurar Caddy
    if [[ -f $is_caddy_bin ]]; then
        load caddy.sh
        path=$service_name
        caddy_config grpc
        manage restart caddy
    fi
    
    # Adicionar ao config principal
    add_inbound_to_main "$name"
    
    msg "\n✓ Trojan-gRPC-TLS criado com sucesso!"
}

# Criar configuração Socks
create_socks() {
    local name=$1
    
    msg "Criando configuração Socks..."
    
    # Perguntar dados
    ask_port
    
    read -p "Requer autenticação? (s/N): " auth_required
    
    local auth_settings=""
    if [[ $auth_required =~ ^[Ss]$ ]]; then
        read -p "Nome de usuário: " username
        ask_password
        auth_settings="\"accounts\": [{\"user\": \"$username\", \"pass\": \"$password\"}],"
    fi
    
    # Criar JSON
    local config=$(cat <<EOF
{
  "protocol": "socks",
  "port": $port,
  "settings": {
    $auth_settings
    "udp": true
  }
}
EOF
)
    
    # Salvar configuração
    save_config "$name" "$config"
    
    # Adicionar ao config principal
    add_inbound_to_main "$name"
    
    msg "\n✓ Socks criado com sucesso!"
}

# Criar configuração VMess-TCP com porta dinâmica
create_vmess_tcp_dynamic() {
    local name=$1
    
    msg "Criando configuração VMess-TCP com porta dinâmica..."
    
    # Perguntar dados
    ask_port
    ask_uuid
    
    read -p "Porta inicial do range [20000]: " port_start
    port_start=${port_start:-20000}
    
    read -p "Porta final do range [30000]: " port_end
    port_end=${port_end:-30000}
    
    # Criar JSON
    local config=$(cat <<EOF
{
  "protocol": "vmess",
  "port": $port,
  "settings": {
    "clients": [
      {
        "id": "$uuid",
        "alterId": 0
      }
    ]
  },
  "streamSettings": {
    "network": "tcp"
  },
  "allocate": {
    "strategy": "random",
    "refresh": 5,
    "concurrency": 3
  },
  "portRange": "${port_start}-${port_end}"
}
EOF
)
    
    # Salvar configuração
    save_config "$name" "$config"
    
    # Adicionar ao config principal
    add_inbound_to_main "$name"
    
    msg "\n✓ VMess-TCP com porta dinâmica criado com sucesso!"
    msg "Range de portas: $port_start-$port_end"
}

# Criar configuração VMess-mKCP com porta dinâmica
create_vmess_mkcp_dynamic() {
    local name=$1
    
    msg "Criando configuração VMess-mKCP com porta dinâmica..."
    
    # Perguntar dados
    ask_port
    ask_uuid
    ask_header_type
    
    read -p "Porta inicial do range [20000]: " port_start
    port_start=${port_start:-20000}
    
    read -p "Porta final do range [30000]: " port_end
    port_end=${port_end:-30000}
    
    # Gerar seed aleatório
    local seed=$(_get_random_path)
    
    # Criar JSON
    local config=$(cat <<EOF
{
  "protocol": "vmess",
  "port": $port,
  "settings": {
    "clients": [
      {
        "id": "$uuid",
        "alterId": 0
      }
    ]
  },
  "streamSettings": {
    "network": "kcp",
    "kcpSettings": {
      "header": {
        "type": "$header_type"
      },
      "seed": "$seed"
    }
  },
  "allocate": {
    "strategy": "random",
    "refresh": 5,
    "concurrency": 3
  },
  "portRange": "${port_start}-${port_end}"
}
EOF
)
    
    # Salvar configuração
    save_config "$name" "$config"
    
    # Adicionar ao config principal
    add_inbound_to_main "$name"
    
    msg "\n✓ VMess-mKCP com porta dinâmica criado com sucesso!"
    msg "Range de portas: $port_start-$port_end"
}
# ============================================================================
# SEÇÃO 7 e 8: FUNÇÕES GET, INFO, UPDATE e MAIN
# Funções finais: obter informações, exibir, atualizar e loop principal
# ============================================================================

# ========== SEÇÃO 7: FUNÇÕES GET E INFO ==========

# Obter informações de uma configuração
get() {
    local config_name=$1
    local field=$2
    
    if [[ -z $config_name ]]; then
        list_configs
        read -p "Digite o nome da configuração: " config_name
    fi
    
    if ! config_exists "$config_name"; then
        err "Configuração não encontrada: $config_name"
    fi
    
    local config_file="$is_conf_dir/${config_name}.json"
    
    # Se especificou campo, retornar apenas esse campo
    if [[ $field ]]; then
        json_get "$config_file" ".$field"
    else
        # Retornar configuração completa
        cat "$config_file"
    fi
}

# Exibir informações detalhadas de uma configuração
info() {
    local config_name=$1
    
    if [[ -z $config_name ]]; then
        list_configs
        read -p "Digite o nome da configuração: " config_name
    fi
    
    if ! config_exists "$config_name"; then
        err "Configuração não encontrada: $config_name"
    fi
    
    local config_file="$is_conf_dir/${config_name}.json"
    
    # Obter dados
    local protocol=$(json_get "$config_file" '.protocol')
    local port=$(json_get "$config_file" '.port')
    local network=$(json_get "$config_file" '.streamSettings.network // "tcp"')
    
    # Obter IP
    get_ip
    
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  INFORMAÇÕES DA CONFIGURAÇÃO: $config_name"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "  Protocolo:     $protocol"
    echo "  Endereço:      $ip"
    echo "  Porta:         $port"
    echo "  Rede:          $network"
    
    # Informações específicas por protocolo
    case $protocol in
        vless)
            local uuid=$(json_get "$config_file" '.settings.clients[0].id')
            local flow=$(json_get "$config_file" '.settings.clients[0].flow // "none"')
            echo "  UUID:          $uuid"
            [[ $flow != "none" ]] && echo "  Flow:          $flow"
            
            # Se for REALITY
            if [[ $(json_get "$config_file" '.streamSettings.security') == "reality" ]]; then
                local public_key=$(json_get "$config_file" '.streamSettings.realitySettings.publicKey // "N/A"')
                local sni=$(json_get "$config_file" '.streamSettings.realitySettings.serverNames[0]')
                echo "  Chave Pública: $public_key"
                echo "  SNI:           $sni"
            fi
            ;;
        vmess)
            local uuid=$(json_get "$config_file" '.settings.clients[0].id')
            echo "  UUID:          $uuid"
            ;;
        trojan)
            local password=$(json_get "$config_file" '.settings.clients[0].password')
            echo "  Senha:         $password"
            ;;
        shadowsocks)
            local method=$(json_get "$config_file" '.settings.method')
            local password=$(json_get "$config_file" '.settings.password')
            echo "  Método:        $method"
            echo "  Senha:         $password"
            ;;
        socks)
            local accounts=$(json_get "$config_file" '.settings.accounts[0].user // "sem autenticação"')
            echo "  Usuário:       $accounts"
            ;;
    esac
    
    # Informações de rede
    case $network in
        ws)
            local path=$(json_get "$config_file" '.streamSettings.wsSettings.path')
            echo "  Caminho:       $path"
            ;;
        grpc)
            local service=$(json_get "$config_file" '.streamSettings.grpcSettings.serviceName')
            echo "  Service:       $service"
            ;;
        kcp)
            local header=$(json_get "$config_file" '.streamSettings.kcpSettings.header.type')
            local seed=$(json_get "$config_file" '.streamSettings.kcpSettings.seed // "N/A"')
            echo "  Disfarce:      $header"
            [[ $seed != "N/A" ]] && echo "  Seed:          $seed"
            ;;
    esac
    
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    # Perguntar se quer gerar link/QR
    read -p "Gerar link de compartilhamento? (s/N): " generate_link
    if [[ $generate_link =~ ^[Ss]$ ]]; then
        url_qr "$config_name"
    fi
}

# Gerar URL e QR Code
url_qr() {
    local config_name=$1
    
    if [[ -z $config_name ]]; then
        list_configs
        read -p "Digite o nome da configuração: " config_name
    fi
    
    if ! config_exists "$config_name"; then
        err "Configuração não encontrada: $config_name"
    fi
    
    local config_file="$is_conf_dir/${config_name}.json"
    local protocol=$(json_get "$config_file" '.protocol')
    
    # Gerar link baseado no protocolo
    local link=""
    
    case $protocol in
        vless)
            link=$(generate_vless_link "$config_name")
            ;;
        vmess)
            link=$(generate_vmess_link "$config_name")
            ;;
        trojan)
            link=$(generate_trojan_link "$config_name")
            ;;
        shadowsocks)
            link=$(generate_ss_link "$config_name")
            ;;
        *)
            warn "Geração de link não suportada para: $protocol"
            return 1
            ;;
    esac
    
    if [[ $link ]]; then
        echo ""
        echo "═══════════════════════════════════════════════════════════"
        echo "  LINK DE COMPARTILHAMENTO"
        echo "═══════════════════════════════════════════════════════════"
        echo ""
        echo "$link"
        echo ""
        
        # Gerar QR Code se qrencode estiver disponível
        if command -v qrencode &>/dev/null; then
            echo "QR Code:"
            echo ""
            qrencode -t ansiutf8 "$link"
            echo ""
        else
            msg "Instale qrencode para gerar QR Code: apt install qrencode"
        fi
        
        echo "═══════════════════════════════════════════════════════════"
        echo ""
    fi
}

# Gerar link VLESS
generate_vless_link() {
    local config_name=$1
    local config_file="$is_conf_dir/${config_name}.json"
    
    get_ip
    local uuid=$(json_get "$config_file" '.settings.clients[0].id')
    local port=$(json_get "$config_file" '.port')
    local network=$(json_get "$config_file" '.streamSettings.network // "tcp"')
    local security=$(json_get "$config_file" '.streamSettings.security // "none"')
    
    local params="type=$network"
    
    # Adicionar parâmetros específicos
    if [[ $network == "ws" ]]; then
        local path=$(json_get "$config_file" '.streamSettings.wsSettings.path')
        params="$params&path=$path"
    elif [[ $network == "grpc" ]]; then
        local service=$(json_get "$config_file" '.streamSettings.grpcSettings.serviceName')
        params="$params&serviceName=$service"
    fi
    
    if [[ $security == "reality" ]]; then
        local sni=$(json_get "$config_file" '.streamSettings.realitySettings.serverNames[0]')
        local public_key=$(json_get "$config_file" '.streamSettings.realitySettings.publicKey // ""')
        params="$params&security=reality&sni=$sni&pbk=$public_key"
    fi
    
    echo "vless://$uuid@$ip:$port?$params#$config_name"
}

# Gerar link VMess
generate_vmess_link() {
    local config_name=$1
    local config_file="$is_conf_dir/${config_name}.json"
    
    get_ip
    local uuid=$(json_get "$config_file" '.settings.clients[0].id')
    local port=$(json_get "$config_file" '.port')
    local network=$(json_get "$config_file" '.streamSettings.network // "tcp"')
    
    # Criar JSON para VMess
    local vmess_json=$(cat <<EOF
{
  "v": "2",
  "ps": "$config_name",
  "add": "$ip",
  "port": "$port",
  "id": "$uuid",
  "aid": "0",
  "net": "$network",
  "type": "none",
  "host": "",
  "path": "",
  "tls": ""
}
EOF
)
    
    # Codificar em base64
    local encoded=$(echo -n "$vmess_json" | base64 -w 0)
    echo "vmess://$encoded"
}

# Gerar link Trojan
generate_trojan_link() {
    local config_name=$1
    local config_file="$is_conf_dir/${config_name}.json"
    
    get_ip
    local password=$(json_get "$config_file" '.settings.clients[0].password')
    local port=$(json_get "$config_file" '.port')
    
    echo "trojan://$password@$ip:$port#$config_name"
}

# Gerar link Shadowsocks
generate_ss_link() {
    local config_name=$1
    local config_file="$is_conf_dir/${config_name}.json"
    
    get_ip
    local method=$(json_get "$config_file" '.settings.method')
    local password=$(json_get "$config_file" '.settings.password')
    local port=$(json_get "$config_file" '.port')
    
    # Codificar method:password em base64
    local encoded=$(echo -n "$method:$password" | base64 -w 0)
    
    echo "ss://$encoded@$ip:$port#$config_name"
}

# ========== SEÇÃO 8: FUNÇÕES UPDATE E MAIN ==========

# Atualizar componentes do sistema
update() {
    local component=${1:-menu}
    
    case $component in
        core)
            update_core
            ;;
        sh | script)
            update_script
            ;;
        dat | geodata)
            update_geodata
            ;;
        caddy)
            update_caddy
            ;;
        all)
            update_core
            update_script
            update_geodata
            [[ -f $is_caddy_bin ]] && update_caddy
            ;;
        menu)
            show_update_menu
            ;;
        *)
            err "Componente desconhecido: $component"
            ;;
    esac
}

# Menu de atualização
show_update_menu() {
    while :; do
        clear
        msg "\n═══════════════════════════════════════"
        msg "  MENU DE ATUALIZAÇÃO"
        msg "═══════════════════════════════════════"
        msg "  1) Atualizar Xray Core"
        msg "  2) Atualizar Scripts"
        msg "  3) Atualizar Geodata (geoip/geosite)"
        msg "  4) Atualizar Caddy"
        msg "  5) Atualizar Tudo"
        msg ""
        msg "  0) Voltar"
        msg "═══════════════════════════════════════\n"
        
        read -p "Escolha uma opção: " option
        
        case $option in
            1) update_core ;;
            2) update_script ;;
            3) update_geodata ;;
            4) update_caddy ;;
            5) update all ;;
            0) break ;;
            *) warn "Opção inválida!" ;;
        esac
        
        read -p "Pressione ENTER para continuar..."
    done
}

# Atualizar Xray Core
update_core() {
    msg "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    msg "  ATUALIZAR XRAY CORE"
    msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
    
    load download.sh
    
    # Verificar versão atual
    local current_ver=$($is_core_bin version | head -n1 | awk '{print $2}')
    msg "Versão atual: $current_ver"
    
    # Obter versão mais recente
    get_latest_version core
    msg "Versão mais recente: $latest_ver"
    
    if [[ $current_ver == $latest_ver ]]; then
        _green "\n✓ Você já está usando a versão mais recente!"
        return 0
    fi
    
    read -p "\nDeseja atualizar? (s/N): " confirm
    [[ ! $confirm =~ ^[Ss]$ ]] && return 0
    
    # Fazer backup
    backup_config
    
    # Parar serviço
    manage stop
    
    # Download e instalação
    download core
    
    # Reiniciar serviço
    manage start
    
    _green "\n✓ Xray Core atualizado com sucesso!"
    msg "Nova versão: $latest_ver\n"
}

# Atualizar scripts
update_script() {
    msg "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    msg "  ATUALIZAR SCRIPTS"
    msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
    
    load download.sh
    
    # Obter versão mais recente
    get_latest_version sh
    msg "Versão mais recente: $latest_ver"
    
    read -p "\nDeseja atualizar? (s/N): " confirm
    [[ ! $confirm =~ ^[Ss]$ ]] && return 0
    
    # Download e instalação
    download sh
    
    _green "\n✓ Scripts atualizados com sucesso!"
    msg "Nova versão: $latest_ver\n"
    msg "Execute 'xray' novamente para usar a nova versão."
}

# Atualizar geodata
update_geodata() {
    msg "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    msg "  ATUALIZAR GEODATA"
    msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
    
    load download.sh
    
    msg "Baixando geoip.dat e geosite.dat..."
    download dat
    
    _green "\n✓ Geodata atualizado com sucesso!\n"
    
    # Reiniciar para aplicar
    manage restart
}

# Atualizar Caddy
update_caddy() {
    if [[ ! -f $is_caddy_bin ]]; then
        warn "Caddy não está instalado"
        return 1
    fi
    
    msg "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    msg "  ATUALIZAR CADDY"
    msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
    
    load download.sh
    
    # Verificar versão atual
    local current_ver=$($is_caddy_bin version | head -n1 | awk '{print $1}')
    msg "Versão atual: $current_ver"
    
    # Obter versão mais recente
    get_latest_version caddy
    msg "Versão mais recente: $latest_ver"
    
    if [[ $current_ver == $latest_ver ]]; then
        _green "\n✓ Você já está usando a versão mais recente!"
        return 0
    fi
    
    read -p "\nDeseja atualizar? (s/N): " confirm
    [[ ! $confirm =~ ^[Ss]$ ]] && return 0
    
    # Parar serviço
    manage stop caddy
    
    # Download e instalação
    download caddy
    
    # Reiniciar serviço
    manage start caddy
    
    _green "\n✓ Caddy atualizado com sucesso!"
    msg "Nova versão: $latest_ver\n"
}

# ========== FUNÇÃO MAIN - LOOP PRINCIPAL ==========

# Função principal do script
main() {
    # Verificar se é root
    check_root
    
    # Verificar sistema operacional
    check_os
    
    # ⚠️ ADICIONAR ESTA LINHA:
    check_dependencies
    
    # Carregar variáveis de ambiente
    [[ -f /etc/xray/env.conf ]] && source /etc/xray/env.conf
    
    # Se passou argumentos, executar comando direto
    if [[ $1 ]]; then
        case $1 in
            add | a)
                shift
                add "$@"
                ;;
            change | c)
                shift
                change "$@"
                ;;
            del | d)
                shift
                del "$@"
                ;;
            ddel)
                shift
                ddel "$@"
                ;;
            info | i)
                shift
                info "$@"
                ;;
            url | qr)
                shift
                url_qr "$@"
                ;;
            list | ls)
                list_configs
                ;;
            update | u)
                shift
                update "$@"
                ;;
            uninstall | un)
                uninstall
                ;;
            start | stop | restart | status)
                manage "$@"
                ;;
            log)
                shift
                load log.sh
                log_set log "$@"
                ;;
            logerr)
                shift
                load log.sh
                log_set error "$@"
                ;;
            api)
                shift
                api "$@"
                ;;
            bbr)
                load bbr.sh
                _try_enable_bbr
                ;;
            dns)
                shift
                load dns.sh
                dns_set "$@"
                ;;
            version | v)
                show_version
                ;;
            help | h)
                load help.sh
                show_help
                ;;
            about)
                load help.sh
                about
                ;;
            # Comandos novos de gerenciamento de usuários
            add-user)
                shift
                bash $is_sh_dir/src/user-manager.sh add "$@"
                ;;
            list-users)
                bash $is_sh_dir/src/user-manager.sh list
                ;;
            del-user)
                shift
                bash $is_sh_dir/src/user-manager.sh delete "$@"
                ;;
            traffic)
                shift
                bash $is_sh_dir/src/traffic-monitor.sh "$@"
                ;;
            check-expired)
                bash $is_sh_dir/src/expiration-checker.sh check
                ;;
            *)
                err "Comando desconhecido: $1\nUse 'xray help' para ver todos os comandos."
                ;;
        esac
    else
        # Sem argumentos: mostrar menu principal
        show_main_menu
    fi
}

# Menu principal interativo
show_main_menu() {
    while :; do
        clear
        msg "\n╔═══════════════════════════════════════════════════════════╗"
        msg "║                    XRAY2026 v$is_sh_ver                      ║"
        msg "║              by PhoenixxZ2023                           ║"
        msg "╚═══════════════════════════════════════════════════════════╝"
        msg ""
        
        ask mainmenu menu_choice
        
        case $REPLY in
            1)  user_management_menu ;;
            2)  traffic_monitoring_menu ;;
            3)  expiration_check_menu ;;
            4)  add ;;
            5)  change ;;
            6)  info ;;
            7)  del ;;
            8)  show_service_management_menu ;;
            9)  update menu ;;
            10) uninstall ;;
            11) load help.sh && show_help ;;
            12) show_others_menu ;;
            13) load help.sh && about ;;
            0)
                msg "\nAté logo!"
                exit 0
                ;;
            *)
                warn "Opção inválida!"
                ;;
        esac
        
        read -p "Pressione ENTER para continuar..."
    done
}

# Menu de gerenciamento de serviços
show_service_management_menu() {
    while :; do
        clear
        msg "\n═══════════════════════════════════════"
        msg "  GERENCIAMENTO DE SERVIÇOS"
        msg "═══════════════════════════════════════"
        msg "  1) Iniciar Xray"
        msg "  2) Parar Xray"
        msg "  3) Reiniciar Xray"
        msg "  4) Ver Status"
        msg "  5) Ver Logs"
        [[ -f $is_caddy_bin ]] && msg "  6) Gerenciar Caddy"
        msg ""
        msg "  0) Voltar"
        msg "═══════════════════════════════════════\n"
        
        read -p "Escolha uma opção: " option
        
        case $option in
            1) manage start ;;
            2) manage stop ;;
            3) manage restart ;;
            4) manage status ;;
            5) load log.sh && log_set log ;;
            6) [[ -f $is_caddy_bin ]] && show_caddy_menu ;;
            0) break ;;
            *) warn "Opção inválida!" ;;
        esac
        
        read -p "Pressione ENTER para continuar..."
    done
}

# Menu outros
show_others_menu() {
    while :; do
        clear
        msg "\n═══════════════════════════════════════"
        msg "  OUTROS"
        msg "═══════════════════════════════════════"
        msg "  1) Configurar DNS"
        msg "  2) Ativar BBR"
        msg "  3) Gerenciar API"
        msg "  4) Backup/Restaurar"
        msg "  5) Testar Configuração"
        msg ""
        msg "  0) Voltar"
        msg "═══════════════════════════════════════\n"
        
        read -p "Escolha uma opção: " option
        
        case $option in
            1) load dns.sh && dns_set ;;
            2) load bbr.sh && _try_enable_bbr ;;
            3) api ;;
            4) show_backup_menu ;;
            5) $is_core_bin test -config $is_config_json -confdir $is_conf_dir ;;
            0) break ;;
            *) warn "Opção inválida!" ;;
        esac
        
        read -p "Pressione ENTER para continuar..."
    done
}

# ========== INICIALIZAR SCRIPT ==========
