#!/bin/bash

author=PhoenixxZ2023
# github=https://github.com/PhoenixxZ2023/xray2026

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

is_err=$(_red_bg ERRO!)
is_warn=$(_red_bg AVISO!)

err() {
    echo -e "\n$is_err $@\n" && exit 1
}

warn() {
    echo -e "\n$is_warn $@\n"
}

# Verificar root
[[ $EUID != 0 ]] && err "Você não está executando como ${yellow}ROOT${none}."

# yum ou apt-get, ubuntu/debian/centos
cmd=$(type -P apt-get || type -P yum)
[[ ! $cmd ]] && err "Este script suporta apenas ${yellow}(Ubuntu, Debian ou CentOS)${none}."

# systemd
[[ ! $(type -P systemctl) ]] && {
    err "Este sistema não possui ${yellow}(systemctl)${none}, tente executar: ${yellow}${cmd} update -y; ${cmd} install systemd -y${none} para corrigir."
}

# wget instalado ou não
is_wget=$(type -P wget)

# x64
case $(uname -m) in
amd64 | x86_64)
    is_jq_arch=amd64
    is_core_arch="64"
    ;;
*aarch64* | *armv8*)
    is_jq_arch=arm64
    is_core_arch="arm64-v8a"
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
is_pkg="wget unzip"
is_config_json=$is_core_dir/config.json
tmp_var_lists=(
    tmpcore
    tmpsh
    tmpjq
    is_core_ok
    is_sh_ok
    is_jq_ok
    is_pkg_ok
)

# Diretório temporário
tmpdir=$(mktemp -u)
[[ ! $tmpdir ]] && {
    tmpdir=/tmp/tmp-$RANDOM
}

# Configurar variáveis
for i in ${tmp_var_lists[*]}; do
    export $i=$tmpdir/$i
done

# Carregar script bash
load() {
    . $is_sh_dir/src/$1
}

# wget adicionar --no-check-certificate
_wget() {
    [[ $proxy ]] && export https_proxy=$proxy
    wget --no-check-certificate $*
}

# Imprimir mensagem
msg() {
    case $1 in
    warn)
        local color=$yellow
        ;;
    err)
        local color=$red
        ;;
    ok)
        local color=$green
        ;;
    esac

    echo -e "${color}$(date +'%T')${none}) ${2}"
}

# Mostrar mensagem de ajuda
show_help() {
    echo -e "Uso: $0 [-f xxx | -l | -p xxx | -v xxx | -h]"
    echo -e "  -f, --core-file <caminho>       Caminho personalizado do arquivo $is_core_name, ex: -f /root/${is_core}-linux-64.zip"
    echo -e "  -l, --local-install             Instalação local do script, usando diretório atual"
    echo -e "  -p, --proxy <endereço>          Usar proxy para download, ex: -p http://127.0.0.1:2333"
    echo -e "  -v, --core-version <versão>     Versão personalizada do $is_core_name, ex: -v v1.8.1"
    echo -e "  -h, --help                      Mostrar esta mensagem de ajuda\n"

    exit 0
}

# Instalar pacotes dependentes
install_pkg() {
    cmd_not_found=
    for i in $*; do
        [[ ! $(type -P $i) ]] && cmd_not_found="$cmd_not_found,$i"
    done
    if [[ $cmd_not_found ]]; then
        pkg=$(echo $cmd_not_found | sed 's/,/ /g')
        msg warn "Instalando pacotes dependentes > ${pkg}"
        $cmd install -y $pkg &>/dev/null
        if [[ $? != 0 ]]; then
            [[ $cmd =~ yum ]] && yum install epel-release -y &>/dev/null
            $cmd update -y &>/dev/null
            $cmd install -y $pkg &>/dev/null
            [[ $? == 0 ]] && >$is_pkg_ok
        else
            >$is_pkg_ok
        fi
    else
        >$is_pkg_ok
    fi
}

# Baixar arquivo
download() {
    case $1 in
    core)
        link=https://github.com/${is_core_repo}/releases/latest/download/${is_core}-linux-${is_core_arch}.zip
        [[ $is_core_ver ]] && link="https://github.com/${is_core_repo}/releases/download/${is_core_ver}/${is_core}-linux-${is_core_arch}.zip"
        name=$is_core_name
        tmpfile=$tmpcore
        is_ok=$is_core_ok
        ;;
    sh)
        link=https://github.com/${is_sh_repo}/releases/latest/download/code.zip
        name="Script $is_core_name"
        tmpfile=$tmpsh
        is_ok=$is_sh_ok
        ;;
    jq)
        link=https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-$is_jq_arch
        name="jq"
        tmpfile=$tmpjq
        is_ok=$is_jq_ok
        ;;
    esac

    msg warn "Baixando ${name} > ${link}"
    if _wget -t 3 -q -c $link -O $tmpfile; then
        mv -f $tmpfile $is_ok
    fi
}

# Obter IP do servidor
get_ip() {
    export "$(_wget -4 -qO- https://one.one.one.one/cdn-cgi/trace | grep ip=)" &>/dev/null
    [[ -z $ip ]] && export "$(_wget -6 -qO- https://one.one.one.one/cdn-cgi/trace | grep ip=)" &>/dev/null
}

# Verificar status das tarefas em segundo plano
check_status() {
    # Falha na instalação de pacotes dependentes
    [[ ! -f $is_pkg_ok ]] && {
        msg err "Falha ao instalar pacotes dependentes"
        msg err "Tente instalar manualmente: $cmd update -y; $cmd install -y $is_pkg"
        is_fail=1
    }

    # Status do download de arquivos
    if [[ $is_wget ]]; then
        [[ ! -f $is_core_ok ]] && {
            msg err "Falha ao baixar ${is_core_name}"
            is_fail=1
        }
        [[ ! -f $is_sh_ok ]] && {
            msg err "Falha ao baixar script ${is_core_name}"
            is_fail=1
        }
        [[ ! -f $is_jq_ok ]] && {
            msg err "Falha ao baixar jq"
            is_fail=1
        }
    else
        [[ ! $is_fail ]] && {
            is_wget=1
            [[ ! $is_core_file ]] && download core &
            [[ ! $local_install ]] && download sh &
            [[ $jq_not_found ]] && download jq &
            get_ip
            wait
            check_status
        }
    fi

    # Encontrou falha, remover diretório temporário e sair
    [[ $is_fail ]] && {
        exit_and_del_tmpdir
    }
}

# Verificação de parâmetros
pass_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
        -f | --core-file)
            [[ -z $2 ]] && {
                err "($1) parâmetro obrigatório ausente, uso correto: [$1 /root/$is_core-linux-64.zip]"
            } || [[ ! -f $2 ]] && {
                err "($2) não é um arquivo válido."
            }
            is_core_file=$2
            shift 2
            ;;
        -l | --local-install)
            [[ ! -f ${PWD}/src/core.sh || ! -f ${PWD}/$is_core.sh ]] && {
                err "Diretório atual (${PWD}) não é um diretório de script completo."
            }
            local_install=1
            shift 1
            ;;
        -p | --proxy)
            [[ -z $2 ]] && {
                err "($1) parâmetro obrigatório ausente, uso correto: [$1 http://127.0.0.1:2333 ou -p socks5://127.0.0.1:2333]"
            }
            proxy=$2
            shift 2
            ;;
        -v | --core-version)
            [[ -z $2 ]] && {
                err "($1) parâmetro obrigatório ausente, uso correto: [$1 v1.8.1]"
            }
            is_core_ver=v${2#v}
            shift 2
            ;;
        -h | --help)
            show_help
            ;;
        *)
            echo -e "\n${is_err} ($@) parâmetro desconhecido...\n"
            show_help
            ;;
        esac
    done
    [[ $is_core_ver && $is_core_file ]] && {
        err "Não é possível personalizar versão e arquivo do ${is_core_name} ao mesmo tempo."
    }
}

# Sair e remover tmpdir
exit_and_del_tmpdir() {
    rm -rf $tmpdir
    [[ ! $1 ]] && {
        msg err "Oops..."
        msg err "Erro durante a instalação..."
        echo -e "Reportar problema: https://github.com/${is_sh_repo}/issues"
        echo
        exit 1
    }
    exit
}

# Principal
main() {

    # Verificar versão antiga
    [[ -f $is_sh_bin && -d $is_core_dir/bin && -d $is_sh_dir && -d $is_conf_dir ]] && {
        err "Script já instalado detectado. Para reinstalar use o comando: ${green}${is_core} reinstall${none}"
    }

    # Verificar parâmetros
    [[ $# -gt 0 ]] && pass_args $@

    # Mostrar mensagem de boas-vindas
    clear
    echo
    echo "........... $is_core_name 2026 - Script Avançado by $author .........."
    echo "........... Instalação do Xray-core Oficial (XTLS) .........."
    echo
    msg ok "Repositório: https://github.com/${is_sh_repo}"
    echo

    # Iniciar instalação...
    msg warn "Iniciando instalação..."
    [[ $is_core_ver ]] && msg warn "Versão do ${is_core_name}: ${yellow}$is_core_ver${none}"
    [[ $proxy ]] && msg warn "Usando proxy: ${yellow}$proxy${none}"
    
    # Criar tmpdir
    mkdir -p $tmpdir
    
    # Se is_core_file, copiar arquivo
    [[ $is_core_file ]] && {
        cp -f $is_core_file $is_core_ok
        msg warn "${yellow}Usando arquivo ${is_core_name} > $is_core_file${none}"
    }
    
    # Instalação local do diretório sh script
    [[ $local_install ]] && {
        >$is_sh_ok
        msg warn "${yellow}Instalação local do script > $PWD${none}"
    }

    timedatectl set-ntp true &>/dev/null
    [[ $? != 0 ]] && {
        msg warn "${yellow}\e[4mAVISO!!! Não foi possível configurar sincronização automática de horário. Isso pode afetar o uso do protocolo VMess.${none}"
    }

    # Instalar pacotes dependentes
    install_pkg $is_pkg &

    # jq
    if [[ $(type -P jq) ]]; then
        >$is_jq_ok
    else
        jq_not_found=1
    fi
    
    # Se wget instalado, baixar core, sh, jq, obter ip
    [[ $is_wget ]] && {
        [[ ! $is_core_file ]] && download core &
        [[ ! $local_install ]] && download sh &
        [[ $jq_not_found ]] && download jq &
        get_ip
    }

    # Aguardar conclusão das tarefas em segundo plano
    wait

    # Verificar status das tarefas em segundo plano
    check_status

    # Testar $is_core_file
    if [[ $is_core_file ]]; then
        unzip -qo $is_core_ok -d $tmpdir/testzip &>/dev/null
        [[ $? != 0 ]] && {
            msg err "Arquivo ${is_core_name} não passou no teste."
            exit_and_del_tmpdir
        }
        for i in ${is_core} geoip.dat geosite.dat; do
            [[ ! -f $tmpdir/testzip/$i ]] && is_file_err=1 && break
        done
        [[ $is_file_err ]] && {
            msg err "Arquivo ${is_core_name} não passou no teste."
            exit_and_del_tmpdir
        }
    fi

    # Obter IP do servidor
    [[ ! $ip ]] && {
        msg err "Falha ao obter IP do servidor."
        exit_and_del_tmpdir
    }

    # Criar diretório sh...
    mkdir -p $is_sh_dir

    # Copiar arquivo sh ou extrair zip sh
    if [[ $local_install ]]; then
        cp -rf $PWD/* $is_sh_dir
    else
        unzip -qo $is_sh_ok -d $is_sh_dir
    fi

    # Criar diretório bin do core
    mkdir -p $is_core_dir/bin
    
    # Copiar arquivo core ou extrair zip core
    if [[ $is_core_file ]]; then
        cp -rf $tmpdir/testzip/* $is_core_dir/bin
    else
        unzip -qo $is_core_ok -d $is_core_dir/bin
    fi

    # Adicionar alias
    echo "alias $is_core=$is_sh_bin" >>/root/.bashrc

    # Comando core
    ln -sf $is_sh_dir/$is_core.sh $is_sh_bin

    # jq
    [[ $jq_not_found ]] && mv -f $is_jq_ok /usr/bin/jq

    # chmod
    chmod +x $is_core_bin $is_sh_bin /usr/bin/jq

    # Criar diretório de log
    mkdir -p $is_log_dir

    # Criar diretório de dados de usuários
    mkdir -p $is_core_dir/users
    
    # Criar arquivo de banco de dados de usuários
    echo "[]" > $is_core_dir/users/users.json

    # Mostrar mensagem de dica
    msg ok "Gerando arquivo de configuração..."

    # Criar serviço systemd
    load systemd.sh
    is_new_install=1
    install_service $is_core &>/dev/null

    # Criar diretório conf
    mkdir -p $is_conf_dir

    load core.sh
    
    # Criar configuração TCP com VLESS-REALITY
    add reality
    
    # Mostrar informações de instalação concluída
    echo
    echo "=========================================="
    msg ok "Instalação concluída com sucesso!"
    echo "=========================================="
    echo
    msg ok "Execute o comando: ${green}xray${none} para gerenciar"
    msg ok "Execute o comando: ${green}xray help${none} para ajuda"
    echo
    msg ok "Gerenciamento de usuários disponível!"
    msg ok "Monitoramento de tráfego habilitado!"
    msg ok "Protocolo VLESS-REALITY ativo!"
    echo
    echo "=========================================="
    
    # Remover diretório tmp e sair
    exit_and_del_tmpdir ok
}

# Iniciar
main $@
