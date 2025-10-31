#!/bin/bash

# Xray2026 - Configurador do Caddy
# Autor: PhoenixxZ2023
# GitHub: https://github.com/PhoenixxZ2023/xray2026
# Baseado no script original de 233boy

caddy_config() {
    is_caddy_site_file=$is_caddy_conf/${host}.conf
    case $1 in
    new)
        mkdir -p $is_caddy_dir $is_caddy_dir/sites $is_caddy_conf
        cat >$is_caddyfile <<-EOF
# Não edite este arquivo #
# Para mais informações, visite: https://github.com/PhoenixxZ2023/xray2026
# Documentação do Caddy: https://caddyserver.com/docs/caddyfile/options
{
  admin off
  http_port $is_http_port
  https_port $is_https_port
}
import $is_caddy_conf/*.conf
import $is_caddy_dir/sites/*.conf
EOF
        ;;
    *ws*)
        cat >${is_caddy_site_file} <<<"
${host}:${is_https_port} {
    reverse_proxy ${path} 127.0.0.1:${port}
    import ${is_caddy_site_file}.add
}"
        ;;
    *h2*)
        cat >${is_caddy_site_file} <<<"
${host}:${is_https_port} {
    reverse_proxy ${path} h2c://127.0.0.1:${port}
    import ${is_caddy_site_file}.add
}"
        ;;
    *grpc*)
        cat >${is_caddy_site_file} <<<"
${host}:${is_https_port} {
    reverse_proxy /${path}/* h2c://127.0.0.1:${port}
    import ${is_caddy_site_file}.add
}"
        ;;
    xhttp)
        cat >${is_caddy_site_file} <<<"
${host}:${is_https_port} {
    reverse_proxy ${path}/* h2c://127.0.0.1:${port}
    import ${is_caddy_site_file}.add
}"
        ;;
    proxy)
        cat >${is_caddy_site_file}.add <<<"
reverse_proxy https://$proxy_site {
        header_up Host {upstream_hostport}
}"
        ;;
    esac
    [[ $1 != "new" && $1 != 'proxy' ]] && {
        [[ ! -f ${is_caddy_site_file}.add ]] && echo "# Visite: https://github.com/PhoenixxZ2023/xray2026" >${is_caddy_site_file}.add
    }
}

# Função para validar configuração do Caddy
validate_caddy_config() {
    msg "Validando configuração do Caddy..."
    
    if [[ ! -f $is_caddyfile ]]; then
        err "Arquivo Caddyfile não encontrado: $is_caddyfile"
        return 1
    fi
    
    if $is_caddy_bin validate --config $is_caddyfile --adapter caddyfile &>/dev/null; then
        _green "✓ Configuração do Caddy válida!"
        return 0
    else
        _red "✗ Configuração do Caddy inválida!"
        $is_caddy_bin validate --config $is_caddyfile --adapter caddyfile
        return 1
    fi
}

# Função para recarregar configuração do Caddy
reload_caddy_config() {
    msg "Recarregando configuração do Caddy..."
    
    if validate_caddy_config; then
        $is_caddy_bin reload --config $is_caddyfile --adapter caddyfile
        if [[ $? -eq 0 ]]; then
            _green "✓ Configuração do Caddy recarregada com sucesso!"
        else
            _red "✗ Falha ao recarregar configuração do Caddy"
        fi
    else
        err "Configuração inválida. Não foi possível recarregar."
    fi
}

# Função para listar sites configurados
list_caddy_sites() {
    echo ""
    echo "═══════════════════════════════════════"
    echo "  SITES CONFIGURADOS NO CADDY"
    echo "═══════════════════════════════════════"
    echo ""
    
    if [[ -d $is_caddy_conf ]]; then
        local count=0
        for conf_file in $is_caddy_conf/*.conf; do
            if [[ -f $conf_file ]]; then
                local site_name=$(basename $conf_file .conf)
                echo "  • $site_name"
                ((count++))
            fi
        done
        
        if [[ $count -eq 0 ]]; then
            echo "  Nenhum site configurado"
        else
            echo ""
            echo "Total: $count site(s)"
        fi
    else
        echo "  Diretório de configuração não encontrado"
    fi
    
    echo ""
    echo "═══════════════════════════════════════"
    echo ""
}

# Função para remover configuração de site
remove_caddy_site() {
    local site_name=$1
    
    if [[ -z $site_name ]]; then
        err "Nome do site não especificado"
        return 1
    fi
    
    local site_file="$is_caddy_conf/${site_name}.conf"
    
    if [[ ! -f $site_file ]]; then
        err "Site não encontrado: $site_name"
        return 1
    fi
    
    rm -f $site_file
    [[ -f ${site_file}.add ]] && rm -f ${site_file}.add
    
    _green "✓ Site removido: $site_name"
    
    reload_caddy_config
}

# Função para visualizar configuração de um site
view_caddy_site() {
    local site_name=$1
    
    if [[ -z $site_name ]]; then
        err "Nome do site não especificado"
        return 1
    fi
    
    local site_file="$is_caddy_conf/${site_name}.conf"
    
    if [[ ! -f $site_file ]]; then
        err "Site não encontrado: $site_name"
        return 1
    fi
    
    echo ""
    echo "═══════════════════════════════════════"
    echo "  CONFIGURAÇÃO: $site_name"
    echo "═══════════════════════════════════════"
    echo ""
    cat $site_file
    echo ""
    
    if [[ -f ${site_file}.add ]]; then
        echo "─────────────────────────────────────"
        echo "  Configurações adicionais:"
        echo "─────────────────────────────────────"
        echo ""
        cat ${site_file}.add
        echo ""
    fi
    
    echo "═══════════════════════════════════════"
    echo ""
}

# Função para testar configuração de TLS
test_caddy_tls() {
    local domain=$1
    
    if [[ -z $domain ]]; then
        err "Domínio não especificado"
        return 1
    fi
    
    msg "Testando certificado TLS para: $domain"
    
    if command -v openssl &>/dev/null; then
        echo | openssl s_client -servername $domain -connect $domain:443 2>/dev/null | \
        openssl x509 -noout -dates 2>/dev/null
        
        if [[ $? -eq 0 ]]; then
            _green "✓ Certificado TLS válido"
        else
            _red "✗ Falha ao verificar certificado TLS"
        fi
    else
        warn "OpenSSL não encontrado. Instale para verificar certificados."
    fi
}

# Função para criar backup do Caddy
backup_caddy_config() {
    local backup_dir="/tmp/caddy_backup_$(date +%Y%m%d_%H%M%S)"
    
    mkdir -p $backup_dir
    
    cp -r $is_caddy_dir $backup_dir/
    cp $is_caddyfile $backup_dir/
    
    _green "✓ Backup do Caddy criado em: $backup_dir"
    echo "$backup_dir" > /tmp/caddy_last_backup
}

# Função para restaurar backup do Caddy
restore_caddy_backup() {
    if [[ ! -f /tmp/caddy_last_backup ]]; then
        warn "Nenhum backup recente encontrado"
        return 1
    fi
    
    local backup_dir=$(cat /tmp/caddy_last_backup)
    
    if [[ ! -d $backup_dir ]]; then
        err "Diretório de backup não encontrado: $backup_dir"
        return 1
    fi
    
    msg "Restaurando backup de: $backup_dir"
    
    cp -rf $backup_dir/* $is_caddy_dir/
    
    _green "✓ Backup do Caddy restaurado com sucesso!"
    
    reload_caddy_config
}

# Ajuda para o módulo Caddy
show_caddy_help() {
    cat <<EOF

═══════════════════════════════════════════════════════════════════
  Configurador do Caddy - Xray2026
═══════════════════════════════════════════════════════════════════

Uso: caddy.sh [comando] [opções]

COMANDOS:
  validate                    Validar configuração
  reload                      Recarregar configuração
  list                        Listar sites configurados
  view <site>                 Ver configuração de um site
  remove <site>               Remover site
  test-tls <dominio>          Testar certificado TLS
  backup                      Fazer backup das configurações
  restore                     Restaurar último backup

PROTOCOLOS SUPORTADOS:
  ws                          WebSocket
  h2                          HTTP/2
  grpc                        gRPC
  xhttp                       XHTTP

EXEMPLOS:
  caddy.sh validate
  caddy.sh reload
  caddy.sh list
  caddy.sh view example.com
  caddy.sh remove example.com
  caddy.sh test-tls example.com
  caddy.sh backup

═══════════════════════════════════════════════════════════════════

EOF
}

# Processar comandos da linha de comando
if [[ $1 ]]; then
    case $1 in
        validate)
            validate_caddy_config
            ;;
        reload)
            reload_caddy_config
            ;;
        list)
            list_caddy_sites
            ;;
        view)
            view_caddy_site $2
            ;;
        remove)
            remove_caddy_site $2
            ;;
        test-tls)
            test_caddy_tls $2
            ;;
        backup)
            backup_caddy_config
            ;;
        restore)
            restore_caddy_backup
            ;;
        help | --help | -h)
            show_caddy_help
            ;;
        *)
            err "Comando desconhecido: $1"
            show_caddy_help
            exit 1
            ;;
    esac
fi
