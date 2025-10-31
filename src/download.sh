#!/bin/bash

# Xray2026 - Gerenciador de Downloads
# Autor: PhoenixxZ2023
# GitHub: https://github.com/PhoenixxZ2023/xray2026
# Baseado no script original de 233boy

get_latest_version() {
    case $1 in
    core)
        name=$is_core_name
        url="https://api.github.com/repos/${is_core_repo}/releases/latest?v=$RANDOM"
        ;;
    sh)
        name="Script $is_core_name"
        url="https://api.github.com/repos/$is_sh_repo/releases/latest?v=$RANDOM"
        ;;
    caddy)
        name="Caddy"
        url="https://api.github.com/repos/$is_caddy_repo/releases/latest?v=$RANDOM"
        ;;
    esac
    latest_ver=$(_wget -qO- $url | grep tag_name | grep -E -o 'v([0-9.]+)')
    [[ ! $latest_ver ]] && {
        err "Falha ao obter a versão mais recente de ${name}."
    }
    unset name url
}

download() {
    latest_ver=$2
    [[ ! $latest_ver && $1 != 'dat' ]] && get_latest_version $1
    # Diretório temporário
    tmpdir=$(mktemp -u)
    [[ ! $tmpdir ]] && {
        tmpdir=/tmp/tmp-$RANDOM
    }
    mkdir -p $tmpdir
    case $1 in
    core)
        name=$is_core_name
        tmpfile=$tmpdir/$is_core.zip
        link="https://github.com/${is_core_repo}/releases/download/${latest_ver}/${is_core}-linux-${is_core_arch}.zip"
        download_file
        unzip -qo $tmpfile -d $is_core_dir/bin
        chmod +x $is_core_bin
        ;;
    sh)
        name="Script $is_core_name"
        tmpfile=$tmpdir/sh.zip
        link="https://github.com/${is_sh_repo}/releases/download/${latest_ver}/code.zip"
        download_file
        unzip -qo $tmpfile -d $is_sh_dir
        chmod +x $is_sh_bin
        ;;
    dat)
        name="geoip.dat"
        tmpfile=$tmpdir/geoip.dat
        link="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
        download_file
        name="geosite.dat"
        tmpfile=$tmpdir/geosite.dat
        link="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"
        download_file
        cp -f $tmpdir/*.dat $is_core_dir/bin/
        ;;
    caddy)
        name="Caddy"
        tmpfile=$tmpdir/caddy.tar.gz
        link="https://github.com/${is_caddy_repo}/releases/download/${latest_ver}/caddy_${latest_ver:1}_linux_${caddy_arch}.tar.gz"
        download_file
        [[ ! $(type -P tar) ]] && {
            rm -rf $tmpdir
            err "Por favor, instale o tar"
        }
        tar zxf $tmpfile -C $tmpdir
        cp -f $tmpdir/caddy $is_caddy_bin
        chmod +x $is_caddy_bin
        ;;
    esac
    rm -rf $tmpdir
    unset latest_ver
}

download_file() {
    if ! _wget -t 5 -c $link -O $tmpfile; then
        rm -rf $tmpdir
        err "\nFalha ao baixar ${name}.\n"
    fi
}

# Função auxiliar para download com barra de progresso
download_with_progress() {
    local url=$1
    local output=$2
    local name=${3:-"arquivo"}
    
    msg "Baixando $name..."
    
    if command -v wget &>/dev/null; then
        wget --progress=bar:force -t 5 -c "$url" -O "$output" 2>&1 | \
        grep --line-buffered "%" | \
        sed -u 's/.*\([0-9]\+%\).*$/\1/' | \
        while read line; do
            echo -ne "\r$name: $line"
        done
        echo ""
    elif command -v curl &>/dev/null; then
        curl -L --progress-bar -o "$output" "$url"
    else
        err "wget ou curl não encontrado. Instale um deles para continuar."
        return 1
    fi
    
    if [[ -f $output ]]; then
        _green "✓ Download concluído: $name"
        return 0
    else
        _red "✗ Falha no download: $name"
        return 1
    fi
}

# Função para verificar se há atualizações disponíveis
check_update() {
    local component=$1
    
    case $component in
    core)
        msg "Verificando atualizações do $is_core_name..."
        get_latest_version core
        local current_ver=$($is_core_bin version | head -n1 | cut -d" " -f2)
        ;;
    sh)
        msg "Verificando atualizações do script..."
        get_latest_version sh
        local current_ver=$is_sh_ver
        ;;
    caddy)
        if [[ ! -f $is_caddy_bin ]]; then
            warn "Caddy não está instalado"
            return 1
        fi
        msg "Verificando atualizações do Caddy..."
        get_latest_version caddy
        local current_ver=$($is_caddy_bin version | head -n1 | cut -d" " -f1)
        ;;
    *)
        err "Componente desconhecido: $component"
        return 1
        ;;
    esac
    
    echo ""
    echo "═══════════════════════════════════════"
    echo "  Versão atual:  $current_ver"
    echo "  Versão mais recente: $latest_ver"
    echo "═══════════════════════════════════════"
    echo ""
    
    if [[ $current_ver == $latest_ver ]]; then
        _green "✓ Você já está usando a versão mais recente!"
        return 0
    else
        _yellow "⚠ Nova versão disponível!"
        return 1
    fi
}

# Função para fazer backup antes de atualizar
backup_before_update() {
    local component=$1
    local backup_dir="/tmp/xray2026_backup_$(date +%Y%m%d_%H%M%S)"
    
    mkdir -p $backup_dir
    
    case $component in
    core)
        cp -r $is_core_dir $backup_dir/
        _green "✓ Backup do core criado em: $backup_dir"
        ;;
    sh)
        cp -r $is_sh_dir $backup_dir/
        _green "✓ Backup do script criado em: $backup_dir"
        ;;
    caddy)
        cp $is_caddy_bin $backup_dir/
        cp -r $is_caddy_dir $backup_dir/
        _green "✓ Backup do Caddy criado em: $backup_dir"
        ;;
    esac
    
    echo "$backup_dir" > /tmp/xray2026_last_backup
}

# Função para restaurar backup
restore_backup() {
    if [[ ! -f /tmp/xray2026_last_backup ]]; then
        warn "Nenhum backup recente encontrado"
        return 1
    fi
    
    local backup_dir=$(cat /tmp/xray2026_last_backup)
    
    if [[ ! -d $backup_dir ]]; then
        err "Diretório de backup não encontrado: $backup_dir"
        return 1
    fi
    
    msg "Restaurando backup de: $backup_dir"
    
    # Restaurar arquivos
    cp -rf $backup_dir/* /
    
    _green "✓ Backup restaurado com sucesso!"
}

# Ajuda para o módulo de downloads
show_download_help() {
    cat <<EOF

═══════════════════════════════════════════════════════════════════
  Gerenciador de Downloads - Xray2026
═══════════════════════════════════════════════════════════════════

Uso: download.sh [comando] [componente] [opções]

COMANDOS:
  download <componente>       Baixar e instalar componente
  check <componente>          Verificar atualizações disponíveis
  backup <componente>         Fazer backup antes de atualizar
  restore                     Restaurar último backup

COMPONENTES:
  core                        Xray-core
  sh                          Scripts do sistema
  dat                         Arquivos geoip.dat e geosite.dat
  caddy                       Servidor Caddy

EXEMPLOS:
  download.sh download core
  download.sh check core
  download.sh backup core
  download.sh restore

═══════════════════════════════════════════════════════════════════

EOF
}
