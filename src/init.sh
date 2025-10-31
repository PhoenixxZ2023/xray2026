#!/bin/bash

# Xray2026 - Script de Inicialização
# Autor: PhoenixxZ2023
# GitHub: https://github.com/PhoenixxZ2023/xray2026

author=PhoenixxZ2023

# Cores bash
red='\e[31m'
yellow='\e[33m'
gray='\e[90m'
green='\e[92m'
blue='\e[94m'
magenta='\e[95m'
cyan='\e[96m'
none='\e[0m'

_red() { echo -e ${red}$@${none}; }
_blue() { echo -e ${blue}$@${none}; }
_cyan() { echo -e ${cyan}$@${none}; }
_green() { echo -e ${green}$@${none}; }
_yellow() { echo -e ${yellow}$@${none}; }
_magenta() { echo -e ${magenta}$@${none}; }
_red_bg() { echo -e "\e[41m$@${none}"; }

_rm() {
    rm -rf "$@"
}
_cp() {
    cp -rf "$@"
}
_sed() {
    sed -i "$@"
}
_mkdir() {
    mkdir -p "$@"
}

is_err=$(_red_bg ERRO!)
is_warn=$(_red_bg AVISO!)

err() {
    echo -e "\n$is_err $@\n"
    [[ $is_dont_auto_exit ]] && return
    exit 1
}

warn() {
    echo -e "\n$is_warn $@\n"
}

# Carregar script bash
load() {
    . $is_sh_dir/src/$1
}

# wget adicionar --no-check-certificate
_wget() {
    # [[ $proxy ]] && export https_proxy=$proxy
    wget --no-check-certificate "$@"
}

# yum ou apt-get
cmd=$(type -P apt-get || type -P yum)

# x64
case $(arch) in
amd64 | x86_64)
    is_core_arch="64"
    caddy_arch="amd64"
    ;;
*aarch64* | *armv8*)
    is_core_arch="arm64-v8a"
    caddy_arch="arm64"
    ;;
*)
    err "Este script suporta apenas sistemas 64 bits..."
    ;;
esac

is_core=xray
is_core_name=Xray
is_core_dir=/etc/$is_core
is_core_bin=$is_core_dir/bin/$is_core
is_core_repo=xtls/$is_core-core
is_conf_dir=$is_core_dir/conf
is_log_dir=/var/log/$is_core
is_sh_bin=/usr/local/bin/$is_core
is_sh_dir=$is_core_dir/sh
is_sh_repo=$author/xray2026
is_pkg="wget unzip jq qrencode"
is_config_json=$is_core_dir/config.json
is_caddy_bin=/usr/local/bin/caddy
is_caddy_dir=/etc/caddy
is_caddy_repo=caddyserver/caddy
is_caddyfile=$is_caddy_dir/Caddyfile
is_caddy_conf=$is_caddy_dir/$author
is_caddy_service=$(systemctl list-units --full -all | grep caddy.service)
is_http_port=80
is_https_port=443

# Diretórios e arquivos de gerenciamento de usuários
is_users_dir=$is_core_dir/users
is_users_db=$is_users_dir/users.json
is_traffic_log=$is_users_dir/traffic.log

# Verificar e criar estrutura de usuários se não existir
[[ ! -d $is_users_dir ]] && _mkdir $is_users_dir
[[ ! -f $is_users_db ]] && echo "[]" > $is_users_db
[[ ! -f $is_traffic_log ]] && touch $is_traffic_log

# Versão do core
is_core_ver=$($is_core_bin version 2>/dev/null | head -n1 | cut -d " " -f1-2)
[[ ! $is_core_ver ]] && is_core_ver="Não instalado"

# Status do core
if [[ $(pgrep -f $is_core_bin) ]]; then
    is_core_status=$(_green "em execução")
else
    is_core_status=$(_red_bg "parado")
    is_core_stop=1
fi

# Verificar Caddy
if [[ -f $is_caddy_bin && -d $is_caddy_dir && $is_caddy_service ]]; then
    is_caddy=1
    # Corrigir caddy run; ver >= 2.8.2
    [[ ! $(grep '\-\-adapter caddyfile' /lib/systemd/system/caddy.service) ]] && {
        load systemd.sh
        install_service caddy
        systemctl restart caddy &
    }
    is_caddy_ver=$($is_caddy_bin version | head -n1 | cut -d " " -f1)
    is_tmp_http_port=$(grep -E '^ {2,}http_port|^http_port' $is_caddyfile | grep -E -o [0-9]+)
    is_tmp_https_port=$(grep -E '^ {2,}https_port|^https_port' $is_caddyfile | grep -E -o [0-9]+)
    [[ $is_tmp_http_port ]] && is_http_port=$is_tmp_http_port
    [[ $is_tmp_https_port ]] && is_https_port=$is_tmp_https_port
    if [[ $(pgrep -f $is_caddy_bin) ]]; then
        is_caddy_status=$(_green "em execução")
    else
        is_caddy_status=$(_red_bg "parado")
        is_caddy_stop=1
    fi
fi

# Carregar core.sh e executar main
load core.sh
[[ ! $args ]] && args=main
main $args
