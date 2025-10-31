#!/bin/bash

# ============================================================================
# Xray2026 - Core Script Completo
# Autor: PhoenixxZ2023  
# GitHub: https://github.com/PhoenixxZ2023/xray2026
# Versão: 2.0
# Descrição: Sistema completo de gerenciamento Xray com suporte a usuários,
#            monitoramento de tráfego e controle de vencimento
# ============================================================================

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
    Trojan-WS-TLS
    Trojan-gRPC-TLS
    Shadowsocks
    VMess-TCP-dynamic-port
    VMess-mKCP-dynamic-port
    Socks
)

ss_method_list=(
    aes-128-gcm
    aes-256-gcm
    chacha20-ietf-poly1305
    xchacha20-ietf-poly1305
    2022-blake3-aes-128-gcm
    2022-blake3-aes-256-gcm
    2022-blake3-chacha20-poly1305
)

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

# ========== LISTAS DE INFORMAÇÕES ==========
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

# ========== LISTA DE ALTERAÇÕES ==========
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

# ========== VARIÁVEIS GLOBAIS ==========
USERS_DB="/etc/xray/users/users.json"
TRAFFIC_LOG="/etc/xray/users/traffic.log"

# ========== FUNÇÕES AUXILIARES ==========

# Mensagens coloridas
msg() {
    echo -e "$@"
}

msg_ul() {
    echo -e "\e[4m$@\e[0m"
}

# Perguntar opções ao usuário
ask() {
    local type=$1
    local var_name=$2
    shift 2
    local options=("$@")
    
    if [[ $type == "list" ]]; then
        echo ""
        for i in "${!options[@]}"; do
            echo "  $((i+1))) ${options[$i]}"
        done
        echo ""
        read -p "Escolha uma opção: " REPLY
        eval "$var_name='${options[$((REPLY-1))]}'"
    elif [[ $type == "mainmenu" ]]; then
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
    fi
}

# ========== SUBMENU: GERENCIAMENTO DE USUÁRIOS ==========
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

# ========== FUNÇÃO: GERAR LINK VLESS ==========
generate_vless_link_advanced() {
    local username="$1"
    
    # Obter dados do usuário do banco
    local uuid=$(jq -r ".[] | select(.username == \"$username\") | .uuid" $USERS_DB 2>/dev/null)
    local protocol=$(jq -r ".[] | select(.username == \"$username\") | .protocol" $USERS_DB 2>/dev/null)
    local status=$(jq -r ".[] | select(.username == \"$username\") | .status" $USERS_DB 2>/dev/null)
    local expires=$(jq -r ".[] | select(.username == \"$username\") | .expires_readable" $USERS_DB 2>/dev/null)
    
    [[ -z $uuid || $uuid == "null" ]] && {
        _red "Usuário '$username' não encontrado!"
        return 1
    }
    
    # Obter IP do servidor
    get_ip
    local server_ip=$ip
    
    # Obter porta VLESS do config
    local vless_port=$(jq -r '.inbounds[] | select(.protocol == "vless") | .port' $is_config_json 2>/dev/null | head -n1)
    [[ -z $vless_port ]] && vless_port=443
    
    # Construir link VLESS-REALITY
    local vless_link="vless://${uuid}@${server_ip}:${vless_port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.google.com&fp=chrome&type=tcp&headerType=none#Xray2026-${username}"
    
    msg "\n═══════════════════════════════════════════════════════════════════"
    msg "  LINK VLESS - ${username}"
    msg "═══════════════════════════════════════════════════════════════════"
    msg ""
    _green "Nome: $username"
    _green "UUID: $uuid"
    _green "Protocolo: $protocol"
    _green "Status: $status"
    _green "Expira em: $expires"
    msg ""
    msg "Link de Conexão:"
    _cyan "$vless_link"
    msg ""
    msg "QR Code:"
    if command -v qrencode &>/dev/null; then
        qrencode -t ansiutf8 "$vless_link"
    else
        _yellow "Instale qrencode para gerar QR Code: $cmd install qrencode -y"
    fi
    msg ""
    msg "═══════════════════════════════════════════════════════════════════\n"
}

# ========== SUBMENU: MONITORAMENTO DE TRÁFEGO ==========
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

# ========== SUBMENU: VERIFICAÇÃO DE VENCIMENTOS ==========
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

# ========== MENU PRINCIPAL ==========
is_main_menu() {
    msg "\n------------- Xray2026 script $is_sh_ver by PhoenixxZ2023 -------------"
    msg "$is_core_ver: $is_core_status"
    [[ $is_caddy ]] && msg "Caddy $is_caddy_ver: $is_caddy_status"
    msg "GitHub: $(msg_ul https://github.com/PhoenixxZ2023/xray2026)"
    is_main_start=1
    ask mainmenu
    
    case $REPLY in
    1) user_management_menu ;;
    2) traffic_monitoring_menu ;;
    3) expiration_check_menu ;;
    4) add ;;
    5) change ;;
    6) info ;;
    7) del ;;
    8)
        ask list is_do_manage "Iniciar Parar Reiniciar"
        manage $REPLY &
        msg "\nGerenciamento executado: $(_green $is_do_manage)\n"
        ;;
    9)
        is_tmp_list=("Atualizar $is_core_name" "Atualizar Script")
        [[ $is_caddy ]] && is_tmp_list+=("Atualizar Caddy")
        ask list is_do_update null "\nEscolha o que atualizar:\n"
        update $REPLY
        ;;
    10) uninstall ;;
    11)
        msg
        load help.sh
        show_help
        ;;
    12)
        ask list is_do_other "Ativar BBR Ver Logs Ver Erros Testar Execução Reinstalar Configurar DNS"
        case $REPLY in
        1) load bbr.sh ; _try_enable_bbr ;;
        2) get log ;;
        3) get logerr ;;
        4) get test-run ;;
        5) get reinstall ;;
        6) load dns.sh ; dns_set ;;
        esac
        ;;
    13)
        load help.sh
        about
        ;;
    0)
        msg "\nSaindo...\n"
        exit 0
        ;;
    esac
}

# ========== FUNÇÃO PRINCIPAL ==========
main() {
    case $1 in
    # ========== NOVOS COMANDOS CLI ==========
    add-user | adduser)
        bash $is_sh_dir/src/user-manager.sh add "${@:2}"
        ;;
    list-users | users)
        bash $is_sh_dir/src/user-manager.sh list
        ;;
    del-user | deluser)
        bash $is_sh_dir/src/user-manager.sh delete "$2"
        ;;
    view-user)
        bash $is_sh_dir/src/user-manager.sh view "$2"
        ;;
    renew-user)
        bash $is_sh_dir/src/user-manager.sh renew "$2" "$3"
        ;;
    traffic | traf)
        bash $is_sh_dir/src/traffic-monitor.sh list
        ;;
    traffic-user)
        bash $is_sh_dir/src/traffic-monitor.sh view "$2"
        ;;
    traffic-update)
        bash $is_sh_dir/src/traffic-monitor.sh update
        ;;
    traffic-monitor | monitor)
        bash $is_sh_dir/src/traffic-monitor.sh monitor
        ;;
    check-expired | expired)
        bash $is_sh_dir/src/expiration-checker.sh check
        ;;
    list-expired)
        bash $is_sh_dir/src/expiration-checker.sh list-expired
        ;;
    expiring-soon)
        bash $is_sh_dir/src/expiration-checker.sh list-expiring "${2:-7}"
        ;;
    clean-expired)
        bash $is_sh_dir/src/expiration-checker.sh clean "${2:-30}"
        ;;
    reactivate-user)
        bash $is_sh_dir/src/expiration-checker.sh reactivate "$2" "$3"
        ;;
    setup-auto-check)
        bash $is_sh_dir/src/expiration-checker.sh setup-auto
        ;;
    
    # ========== COMANDOS ORIGINAIS ==========
    add) add ;;
    change) change ;;
    info | url) info ;;
    del) del ;;
    start) manage start ;;
    stop) manage stop ;;
    restart) manage restart ;;
    status) manage status ;;
    log) get log ;;
    logerr) get logerr ;;
    test-run) get test-run ;;
    update) update ;;
    uninstall) uninstall ;;
    reinstall) get reinstall ;;
    help) load help.sh ; show_help ;;
    about) load help.sh ; about ;;
    
    # ========== MENU PRINCIPAL ==========
    main | "")
        while :; do
            is_main_menu
        done
        ;;
    
    *)
        _red "\nComando desconhecido: $1\n"
        _yellow "Use 'xray help' para ver os comandos disponíveis\n"
        ;;
    esac
}

# NOTA: Este é um arquivo simplificado com as partes essenciais
# As funções add, change, info, del, manage, update, uninstall, etc.
# devem ser carregadas do arquivo core.sh original ou implementadas
# conforme necessário. Este arquivo foca na estrutura do menu e
# integração com os novos módulos.
