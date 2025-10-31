#!/bin/bash

# Xray2026 - Gerenciador de Serviços Systemd
# Autor: PhoenixxZ2023
# GitHub: https://github.com/PhoenixxZ2023/xray2026
# Baseado no script original de 233boy

# Função para instalar/criar serviços systemd
install_service() {
    case $1 in
    xray | v2ray)
        # Definir site de documentação
        is_doc_site=https://xtls.github.io/
        [[ $1 == 'v2ray' ]] && is_doc_site=https://www.v2fly.org/
        
        # Criar arquivo de serviço do Xray/V2Ray
        cat >/lib/systemd/system/$is_core.service <<EOF
[Unit]
Description=$is_core_name Service
Documentation=$is_doc_site
After=network.target nss-lookup.target

[Service]
# Execução como root (necessário para portas < 1024)
User=root
NoNewPrivileges=true
ExecStart=$is_core_bin run -config $is_config_json -confdir $is_conf_dir
Restart=on-failure
RestartPreventExitStatus=23

# Limites de recursos
LimitNPROC=10000
LimitNOFILE=1048576

# Segurança
PrivateTmp=true
ProtectSystem=full

# Capabilities (descomente se necessário)
#CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
#AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF
        
        msg "Serviço $is_core_name criado com sucesso!"
        ;;
        
    caddy)
        # Criar arquivo de serviço do Caddy
        # Baseado em: https://github.com/caddyserver/dist/blob/master/init/caddy.service
        cat >/lib/systemd/system/caddy.service <<EOF
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=notify
User=root
Group=root
ExecStart=$is_caddy_bin run --environ --config $is_caddyfile --adapter caddyfile
ExecReload=$is_caddy_bin reload --config $is_caddyfile --adapter caddyfile
TimeoutStopSec=5s

# Limites de recursos
LimitNPROC=10000
LimitNOFILE=1048576

# Segurança
PrivateTmp=true
ProtectSystem=full

# Capabilities (descomente se necessário)
#AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF
        
        msg "Serviço Caddy criado com sucesso!"
        ;;
        
    *)
        err "Serviço desconhecido: $1"
        return 1
        ;;
    esac

    # Habilitar e recarregar daemon
    systemctl enable $1 &>/dev/null
    systemctl daemon-reload &>/dev/null
    
    msg "✓ Serviço $1 habilitado e registrado no systemd"
}

# Função para remover serviço
remove_service() {
    local service_name=$1
    
    if [[ -f /lib/systemd/system/${service_name}.service ]]; then
        # Parar serviço
        systemctl stop $service_name &>/dev/null
        
        # Desabilitar serviço
        systemctl disable $service_name &>/dev/null
        
        # Remover arquivo de serviço
        rm -f /lib/systemd/system/${service_name}.service
        
        # Recarregar daemon
        systemctl daemon-reload &>/dev/null
        
        msg "✓ Serviço $service_name removido com sucesso"
    else
        warn "Serviço $service_name não encontrado"
    fi
}

# Função para verificar status do serviço
check_service_status() {
    local service_name=$1
    
    if systemctl is-active --quiet $service_name; then
        _green "✓ $service_name está em execução"
        return 0
    else
        _red "✗ $service_name está parado"
        return 1
    fi
}

# Função para gerenciar serviços (start/stop/restart/status)
manage_service() {
    local action=$1
    local service_name=$2
    
    case $action in
        start)
            systemctl start $service_name
            if [[ $? -eq 0 ]]; then
                msg "✓ Serviço $service_name iniciado"
            else
                err "Falha ao iniciar $service_name"
            fi
            ;;
        stop)
            systemctl stop $service_name
            if [[ $? -eq 0 ]]; then
                msg "✓ Serviço $service_name parado"
            else
                err "Falha ao parar $service_name"
            fi
            ;;
        restart)
            systemctl restart $service_name
            if [[ $? -eq 0 ]]; then
                msg "✓ Serviço $service_name reiniciado"
            else
                err "Falha ao reiniciar $service_name"
            fi
            ;;
        status)
            systemctl status $service_name
            ;;
        enable)
            systemctl enable $service_name
            msg "✓ Serviço $service_name habilitado para iniciar com o sistema"
            ;;
        disable)
            systemctl disable $service_name
            msg "✓ Serviço $service_name desabilitado"
            ;;
        reload)
            systemctl reload $service_name
            if [[ $? -eq 0 ]]; then
                msg "✓ Configuração do serviço $service_name recarregada"
            else
                err "Falha ao recarregar $service_name"
            fi
            ;;
        *)
            err "Ação desconhecida: $action"
            return 1
            ;;
    esac
}

# Função para recarregar arquivo de serviço
reload_service_file() {
    local service_name=$1
    
    msg "Recriando serviço $service_name..."
    install_service $service_name
    
    msg "Recarregando daemon do systemd..."
    systemctl daemon-reload
    
    msg "Reiniciando serviço..."
    systemctl restart $service_name
    
    if check_service_status $service_name; then
        msg "✓ Serviço $service_name recarregado com sucesso!"
    else
        err "Falha ao recarregar serviço $service_name"
    fi
}

# Função para listar todos os serviços relacionados
list_services() {
    echo ""
    echo "═══════════════════════════════════════"
    echo "  SERVIÇOS DO SISTEMA"
    echo "═══════════════════════════════════════"
    echo ""
    
    # Verificar Xray
    if [[ -f /lib/systemd/system/$is_core.service ]]; then
        echo -n "  $is_core_name: "
        check_service_status $is_core
    fi
    
    # Verificar Caddy
    if [[ -f /lib/systemd/system/caddy.service ]]; then
        echo -n "  Caddy: "
        check_service_status caddy
    fi
    
    echo ""
    echo "═══════════════════════════════════════"
    echo ""
}

# Função para testar configuração do serviço
test_service_config() {
    local service_name=$1
    
    case $service_name in
        xray | v2ray)
            # Testar configuração do Xray
            msg "Testando configuração do $is_core_name..."
            if $is_core_bin test -config $is_config_json -confdir $is_conf_dir; then
                _green "✓ Configuração válida!"
                return 0
            else
                _red "✗ Configuração inválida!"
                return 1
            fi
            ;;
        caddy)
            # Testar configuração do Caddy
            msg "Testando configuração do Caddy..."
            if $is_caddy_bin validate --config $is_caddyfile --adapter caddyfile; then
                _green "✓ Configuração válida!"
                return 0
            else
                _red "✗ Configuração inválida!"
                return 1
            fi
            ;;
        *)
            warn "Serviço desconhecido: $service_name"
            return 1
            ;;
    esac
}

# Função para ver logs do serviço
view_service_logs() {
    local service_name=$1
    local lines=${2:-50}
    
    echo ""
    echo "═══════════════════════════════════════"
    echo "  LOGS DO SERVIÇO: $service_name"
    echo "  (Últimas $lines linhas)"
    echo "═══════════════════════════════════════"
    echo ""
    
    journalctl -u $service_name -n $lines --no-pager
    
    echo ""
    echo "═══════════════════════════════════════"
    echo ""
    echo "Para ver logs em tempo real, use:"
    echo "  journalctl -u $service_name -f"
    echo ""
}

# Função para corrigir permissões do serviço
fix_service_permissions() {
    msg "Corrigindo permissões dos arquivos de serviço..."
    
    # Xray/V2Ray
    if [[ -f /lib/systemd/system/$is_core.service ]]; then
        chmod 644 /lib/systemd/system/$is_core.service
        msg "✓ Permissões do $is_core_name corrigidas"
    fi
    
    # Caddy
    if [[ -f /lib/systemd/system/caddy.service ]]; then
        chmod 644 /lib/systemd/system/caddy.service
        msg "✓ Permissões do Caddy corrigidas"
    fi
    
    systemctl daemon-reload
    msg "✓ Daemon recarregado"
}

# Ajuda para uso do systemd.sh
show_systemd_help() {
    cat <<EOF

═══════════════════════════════════════════════════════════════════
  Gerenciador de Serviços Systemd - Xray2026
═══════════════════════════════════════════════════════════════════

Uso: systemd.sh [comando] [serviço] [opções]

COMANDOS:
  install <serviço>           Instalar/criar serviço
  remove <serviço>            Remover serviço
  start <serviço>             Iniciar serviço
  stop <serviço>              Parar serviço
  restart <serviço>           Reiniciar serviço
  status <serviço>            Ver status do serviço
  enable <serviço>            Habilitar início automático
  disable <serviço>           Desabilitar início automático
  reload <serviço>            Recarregar configuração
  test <serviço>              Testar configuração
  logs <serviço> [linhas]     Ver logs (padrão: 50 linhas)
  list                        Listar todos os serviços
  fix-permissions             Corrigir permissões

SERVIÇOS DISPONÍVEIS:
  xray                        Serviço Xray-core
  v2ray                       Serviço V2Ray-core
  caddy                       Serviço Caddy server

EXEMPLOS:
  systemd.sh install xray
  systemd.sh restart xray
  systemd.sh logs xray 100
  systemd.sh test xray
  systemd.sh list

═══════════════════════════════════════════════════════════════════

EOF
}

# Processar comandos da linha de comando
if [[ $1 ]]; then
    case $1 in
        install)
            install_service $2
            ;;
        remove)
            remove_service $2
            ;;
        start | stop | restart | status | enable | disable | reload)
            manage_service $1 $2
            ;;
        test)
            test_service_config $2
            ;;
        logs)
            view_service_logs $2 $3
            ;;
        list)
            list_services
            ;;
        fix-permissions)
            fix_service_permissions
            ;;
        help | --help | -h)
            show_systemd_help
            ;;
        *)
            err "Comando desconhecido: $1"
            show_systemd_help
            exit 1
            ;;
    esac
fi
