#!/bin/bash

# ============================================================================
# systemd.sh - Gerenciamento do Serviço Systemd Xray (CORRIGIDO)
# Remove argumento 'run' incompatível com Xray2026 Script 2.0
# ============================================================================

# Autor: PhoenixxZ2023
# Versão: 2.0 - Corrigido para compatibilidade com Xray2026

# Cores
_red() { echo -e "\e[31m$@\e[0m"; }
_green() { echo -e "\e[92m$@\e[0m"; }
_yellow() { echo -e "\e[33m$@\e[0m"; }
_blue() { echo -e "\e[94m$@\e[0m"; }

# ════════════════════════════════════════════════════════════════════════
# CRIAR SERVIÇO SYSTEMD
# ════════════════════════════════════════════════════════════════════════

create_service() {
    _blue "Criando serviço systemd para Xray..."
    
    # Criar arquivo de serviço (SEM o argumento 'run')
    cat > /etc/systemd/system/xray.service <<'EOF'
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
ExecStart=/usr/local/bin/xray -config /etc/xray/config.json -confdir /etc/xray/conf
Restart=on-failure
RestartPreventExitStatus=23
StandardOutput=journal
StandardError=journal
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF
    
    # Recarregar systemd
    systemctl daemon-reload
    
    # Habilitar serviço
    systemctl enable xray
    
    _green "✓ Serviço systemd criado e habilitado"
}

# ════════════════════════════════════════════════════════════════════════
# RECRIAR SERVIÇO (útil para correções)
# ════════════════════════════════════════════════════════════════════════

recreate_service() {
    _yellow "Recriando serviço systemd..."
    
    # Parar serviço se estiver rodando
    systemctl stop xray 2>/dev/null
    
    # Desabilitar
    systemctl disable xray 2>/dev/null
    
    # Recriar
    create_service
    
    _green "✓ Serviço recriado"
}

# ════════════════════════════════════════════════════════════════════════
# INICIAR SERVIÇO
# ════════════════════════════════════════════════════════════════════════

start_service() {
    _blue "Iniciando serviço Xray..."
    
    systemctl start xray
    
    if systemctl is-active --quiet xray; then
        _green "✓ Xray iniciado com sucesso"
        return 0
    else
        _red "✗ Falha ao iniciar Xray"
        _yellow "Verifique os logs: journalctl -u xray -n 50"
        return 1
    fi
}

# ════════════════════════════════════════════════════════════════════════
# PARAR SERVIÇO
# ════════════════════════════════════════════════════════════════════════

stop_service() {
    _blue "Parando serviço Xray..."
    
    systemctl stop xray
    
    if ! systemctl is-active --quiet xray; then
        _green "✓ Xray parado"
        return 0
    else
        _red "✗ Falha ao parar Xray"
        return 1
    fi
}

# ════════════════════════════════════════════════════════════════════════
# REINICIAR SERVIÇO
# ════════════════════════════════════════════════════════════════════════

restart_service() {
    _blue "Reiniciando serviço Xray..."
    
    systemctl restart xray
    
    sleep 2
    
    if systemctl is-active --quiet xray; then
        _green "✓ Xray reiniciado com sucesso"
        return 0
    else
        _red "✗ Falha ao reiniciar Xray"
        _yellow "Verifique os logs: journalctl -u xray -n 50"
        return 1
    fi
}

# ════════════════════════════════════════════════════════════════════════
# VER STATUS
# ════════════════════════════════════════════════════════════════════════

status_service() {
    systemctl status xray --no-pager -l
}

# ════════════════════════════════════════════════════════════════════════
# HABILITAR/DESABILITAR AUTOSTART
# ════════════════════════════════════════════════════════════════════════

enable_service() {
    systemctl enable xray
    _green "✓ Autostart habilitado"
}

disable_service() {
    systemctl disable xray
    _yellow "⚠ Autostart desabilitado"
}

# ════════════════════════════════════════════════════════════════════════
# REMOVER SERVIÇO
# ════════════════════════════════════════════════════════════════════════

remove_service() {
    _yellow "Removendo serviço systemd..."
    
    # Parar e desabilitar
    systemctl stop xray 2>/dev/null
    systemctl disable xray 2>/dev/null
    
    # Remover arquivo
    rm -f /etc/systemd/system/xray.service
    
    # Recarregar
    systemctl daemon-reload
    systemctl reset-failed
    
    _green "✓ Serviço removido"
}

# ════════════════════════════════════════════════════════════════════════
# VERIFICAR SE SERVIÇO EXISTE
# ════════════════════════════════════════════════════════════════════════

service_exists() {
    systemctl list-unit-files | grep -q "xray.service"
}

# ════════════════════════════════════════════════════════════════════════
# MENU DE GERENCIAMENTO
# ════════════════════════════════════════════════════════════════════════

show_service_menu() {
    while true; do
        clear
        echo ""
        echo "═══════════════════════════════════════"
        echo "  GERENCIAMENTO DO SERVIÇO XRAY"
        echo "═══════════════════════════════════════"
        echo ""
        
        if service_exists; then
            if systemctl is-active --quiet xray; then
                _green "  Status: RODANDO ✓"
            else
                _red "  Status: PARADO ✗"
            fi
        else
            _yellow "  Status: SERVIÇO NÃO CRIADO"
        fi
        
        echo ""
        echo "  1) Iniciar Xray"
        echo "  2) Parar Xray"
        echo "  3) Reiniciar Xray"
        echo "  4) Ver Status"
        echo "  5) Ver Logs"
        echo "  6) Criar/Recriar Serviço"
        echo "  7) Habilitar Autostart"
        echo "  8) Desabilitar Autostart"
        echo ""
        echo "  0) Voltar"
        echo ""
        echo "═══════════════════════════════════════"
        echo ""
        
        read -p "Escolha uma opção: " option
        
        case $option in
            1) start_service ;;
            2) stop_service ;;
            3) restart_service ;;
            4) status_service ;;
            5) journalctl -u xray -f ;;
            6) recreate_service ;;
            7) enable_service ;;
            8) disable_service ;;
            0) break ;;
            *) _red "Opção inválida" ;;
        esac
        
        echo ""
        read -p "Pressione ENTER para continuar..."
    done
}

# ════════════════════════════════════════════════════════════════════════
# PONTO DE ENTRADA
# ════════════════════════════════════════════════════════════════════════

main() {
    case "${1:-}" in
        create)
            create_service
            ;;
        recreate)
            recreate_service
            ;;
        start)
            start_service
            ;;
        stop)
            stop_service
            ;;
        restart)
            restart_service
            ;;
        status)
            status_service
            ;;
        enable)
            enable_service
            ;;
        disable)
            disable_service
            ;;
        remove)
            remove_service
            ;;
        menu)
            show_service_menu
            ;;
        *)
            show_service_menu
            ;;
    esac
}

# Executar se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
