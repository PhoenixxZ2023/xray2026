#!/bin/bash

# ============================================================================
# Xray2026 - Módulo Systemd
# Gerenciamento de serviços via systemd
# Autor: PhoenixxZ2023
# ============================================================================

# Criar serviço systemd do Xray
create_systemd_service() {
    local service_name=${1:-xray}
    local service_file="/lib/systemd/system/${service_name}.service"
    
    msg "Criando serviço systemd: $service_name"
    
    cat > $service_file <<EOF
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
ExecStart=$is_core_bin run -config $is_config_json -confdir $is_conf_dir
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF

    # Recarregar systemd
    systemctl daemon-reload
    
    # Habilitar serviço
    systemctl enable $service_name
    
    _green "✓ Serviço $service_name criado e habilitado"
}

# Criar serviço systemd do Caddy
create_caddy_service() {
    local service_file="/lib/systemd/system/caddy.service"
    
    msg "Criando serviço systemd do Caddy..."
    
    cat > $service_file <<EOF
[Unit]
Description=Caddy Web Server
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=notify
User=root
Group=root
ExecStart=$is_caddy_bin run --config $is_caddyfile --adapter caddyfile
ExecReload=$is_caddy_bin reload --config $is_caddyfile --adapter caddyfile
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

    # Recarregar systemd
    systemctl daemon-reload
    
    # Habilitar serviço
    systemctl enable caddy
    
    _green "✓ Serviço Caddy criado e habilitado"
}

# Iniciar serviço
start_service() {
    local service=${1:-xray}
    
    msg "Iniciando serviço: $service"
    
    if systemctl start $service; then
        _green "✓ Serviço $service iniciado"
        return 0
    else
        _red "✗ Falha ao iniciar $service"
        return 1
    fi
}

# Parar serviço
stop_service() {
    local service=${1:-xray}
    
    msg "Parando serviço: $service"
    
    if systemctl stop $service; then
        _green "✓ Serviço $service parado"
        return 0
    else
        _red "✗ Falha ao parar $service"
        return 1
    fi
}

# Reiniciar serviço
restart_service() {
    local service=${1:-xray}
    
    msg "Reiniciando serviço: $service"
    
    if systemctl restart $service; then
        _green "✓ Serviço $service reiniciado"
        return 0
    else
        _red "✗ Falha ao reiniciar $service"
        return 1
    fi
}

# Verificar status do serviço
status_service() {
    local service=${1:-xray}
    
    systemctl status $service
}

# Verificar se serviço está ativo
is_service_active() {
    local service=${1:-xray}
    
    systemctl is-active --quiet $service && return 0 || return 1
}

# Verificar se serviço está habilitado
is_service_enabled() {
    local service=${1:-xray}
    
    systemctl is-enabled --quiet $service && return 0 || return 1
}

# Habilitar serviço
enable_service() {
    local service=${1:-xray}
    
    msg "Habilitando serviço: $service"
    
    if systemctl enable $service; then
        _green "✓ Serviço $service habilitado"
        return 0
    else
        _red "✗ Falha ao habilitar $service"
        return 1
    fi
}

# Desabilitar serviço
disable_service() {
    local service=${1:-xray}
    
    msg "Desabilitando serviço: $service"
    
    if systemctl disable $service; then
        _green "✓ Serviço $service desabilitado"
        return 0
    else
        _red "✗ Falha ao desabilitar $service"
        return 1
    fi
}

# Ver logs do serviço
view_service_logs() {
    local service=${1:-xray}
    local lines=${2:-50}
    
    journalctl -u $service -n $lines --no-pager
}

# Ver logs em tempo real
follow_service_logs() {
    local service=${1:-xray}
    
    msg "Seguindo logs de $service (Ctrl+C para sair)..."
    journalctl -u $service -f
}

# Recarregar daemon do systemd
reload_systemd() {
    msg "Recarregando systemd daemon..."
    systemctl daemon-reload
    _green "✓ Systemd daemon recarregado"
}

# Remover serviço
remove_service() {
    local service=${1:-xray}
    local service_file="/lib/systemd/system/${service}.service"
    
    msg "Removendo serviço: $service"
    
    # Parar e desabilitar
    systemctl stop $service 2>/dev/null
    systemctl disable $service 2>/dev/null
    
    # Remover arquivo
    if [[ -f $service_file ]]; then
        rm -f $service_file
        _green "✓ Serviço $service removido"
    else
        warn "Arquivo de serviço não encontrado: $service_file"
    fi
    
    # Recarregar
    reload_systemd
}

# Verificar se systemd está disponível
check_systemd() {
    if ! command -v systemctl &>/dev/null; then
        err "systemd não está disponível neste sistema"
        return 1
    fi
    return 0
}

# Listar todos os serviços relacionados
list_xray_services() {
    echo ""
    echo "═══════════════════════════════════════"
    echo "  SERVIÇOS DO XRAY2026"
    echo "═══════════════════════════════════════"
    echo ""
    
    local services=(xray caddy)
    
    for service in "${services[@]}"; do
        if systemctl list-units --full -all | grep -q "$service.service"; then
            local status=$(systemctl is-active $service 2>/dev/null)
            local enabled=$(systemctl is-enabled $service 2>/dev/null)
            
            printf "  %-15s " "$service:"
            
            case $status in
                active)
                    _green "✓ Ativo"
                    ;;
                inactive)
                    _yellow "○ Inativo"
                    ;;
                failed)
                    _red "✗ Falhou"
                    ;;
                *)
                    echo "? Desconhecido"
                    ;;
            esac
            
            case $enabled in
                enabled)
                    echo -n " (habilitado)"
                    ;;
                disabled)
                    echo -n " (desabilitado)"
                    ;;
            esac
            echo ""
        fi
    done
    
    echo ""
    echo "═══════════════════════════════════════"
    echo ""
}

# ========== FIM DO MÓDULO SYSTEMD ==========
