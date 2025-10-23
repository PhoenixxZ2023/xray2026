#!/bin/bash

# MODIFICADO: Mantenha o autor original para crédito, se desejar.
author=233boy
# github=https://github.com/233boy/xray (Link original para referência)

# Cores e fontes do Bash
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

# MODIFICADO: Traduzido
is_err=$(_red_bg Erro!)
is_warn=$(_red_bg Aviso!)

err() {
    echo -e "\n$is_err $@\n" && exit 1
}

warn() {
    echo -e "\n$is_warn $@\n"
}

# root
# MODIFICADO: Traduzido
[[ $EUID != 0 ]] && err "Este script deve ser executado como ${yellow}usuário ROOT.${none}"

# yum or apt-get, ubuntu/debian/centos
cmd=$(type -P apt-get || type -P yum)
# MODIFICADO: Traduzido
[[ ! $cmd ]] && err "Este script suporta apenas ${yellow}(Ubuntu, Debian ou CentOS)${none}."

# systemd
[[ ! $(type -P systemctl) ]] && {
    # MODIFICADO: Traduzido
    err "Seu sistema não possui ${yellow}(systemctl)${none}, por favor, tente executar:${yellow} ${cmd} update -y;${cmd} install systemd -y ${none} para corrigir."
}

# wget installed or none
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
    # MODIFICADO: Traduzido
    err "Este script suporta apenas sistemas de 64 bits..."
    ;;
esac

# Variáveis principais - NÃO MUDE "is_core=xray"
# Isso quebraria os caminhos /etc/xray, /var/log/xray, etc.
is_core=xray
is_core_name=Xray
is_core_dir=/etc/$is_core
is_core_bin=$is_core_dir/bin/$is_core
is_core_repo=xtls/$is_core-core # Repositório do programa Xray (Não mude)
is_conf_dir=$is_core_dir/conf
is_log_dir=/var/log/$is_core
is_sh_bin=/usr/local/bin/$is_core
is_sh_dir=$is_core_dir/sh

# MODIFICADO: Aponta para o SEU repositório de scripts
is_sh_repo=https://github.com/PhoenixxZ2023/xray2026 # <--- MUDE "SEU_USUARIO" AQUI

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

# tmp dir
tmpdir=$(mktemp -u)
[[ ! $tmpdir ]] && {
    tmpdir=/tmp/tmp-$RANDOM
}

# set up var
for i in ${tmp_var_lists[*]}; do
    export $i=$tmpdir/$i
done

# load bash script.
load() {
    . $is_sh_dir/src/$1
}

# wget add --no-check-certificate
_wget() {
    [[ $proxy ]] && export https_proxy=$proxy
    wget --no-check-certificate $*
}

# print a mesage
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

# show help msg
show_help() {
    # MODIFICADO: Traduzido
    echo -e "Uso: $0 [-f xxx | -l | -p xxx | -v xxx | -h]"
    echo -e "  -f, --core-file <path>   Caminho para um arquivo $is_core_name personalizado, ex: -f /root/${is_core}-linux-64.zip"
    echo -e "  -l, --local-install      Instalação local, usando o diretório atual"
    echo -e "  -p, --proxy <addr>       Usar um proxy para download, ex: -p http://127.0.0.1:2333"
    echo -e "  -v, --core-version <ver> Definir uma versão personalizada do $is_core_name, ex: -v v1.8.1"
    echo -e "  -h, --help               Exibir esta mensagem de ajuda\n"

    exit 0
}

# install dependent pkg
install_pkg() {
    cmd_not_found=
    for i in $*; do
        [[ ! $(type -P $i) ]] && cmd_not_found="$cmd_not_found,$i"
    done
    if [[ $cmd_not_found ]]; then
        pkg=$(echo $cmd_not_found | sed 's/,/ /g')
        # MODIFICADO: Traduzido
        msg warn "Instalando dependências >${pkg}"
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

# download file
download() {
    case $1 in
    core)
        link=https://github.com/${is_core_repo}/releases/latest/download/${is_core}-linux-${is_core_arch}.zip
        [[ $is_core_ver ]] && link="https://github.com/${is_core_repo}/releases/download/${is_core_ver}/${is_core}-linux-${is_core_arch}.zip"
        name=$is_core_name
        tmpfile=$tmpcore
        is_ok=$is_core_ok
        ;;
    # A função "sh" não é mais usada, foi substituída por download_scripts()
    # sh)
    #     link=https://github.com/${is_sh_repo}/releases/latest/download/code.zip
    #     name="$is_core_name 脚本" # MODIFICADO: Traduzido -> "Scripts $is_core_name"
    #     tmpfile=$tmpsh
    #     is_ok=$is_sh_ok
    #     ;;
    jq)
        link=https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-$is_jq_arch
        name="jq"
        tmpfile=$tmpjq
        is_ok=$is_jq_ok
        ;;
    esac

    # MODIFICADO: Traduzido
    msg warn "Baixando ${name} > ${link}"
    if _wget -t 3 -q -c $link -O $tmpfile; then
        mv -f $tmpfile $is_ok
    fi
}

# MODIFICADO: Nova lista de arquivos baseada na sua captura de tela da pasta src/
SCRIPT_FILES=(
    "xray.sh"
    "src/bbr.sh"
    "src/caddy.sh"
    "src/core.sh"
    "src/dns.sh"
    "src/download.sh"
    "src/help.sh"
    "src/init.sh"
    "src/log.sh"
    "src/systemd.sh"
)

# MODIFICADO: Nova função para baixar os scripts individualmente do seu repo
download_scripts() {
    msg warn "Baixando scripts de ${is_sh_repo}..."
    
    # Criar os diretórios necessários
    mkdir -p $is_sh_dir/src
    
    local base_url="https://raw.githubusercontent.com/${is_sh_repo}/main"
    
    for file in "${SCRIPT_FILES[@]}"; do
        # O caminho de destino no servidor
        local dest_path="$is_sh_dir/$file"
        # A URL de origem no GitHub
        local url="$base_url/$file"
        
        msg warn "Baixando > $file"
        if !_wget -t 3 -q -c "$url" -O "$dest_path"; then
            msg err "Falha ao baixar $file"
            is_fail=1 # Sinaliza falha
            return 1
        fi
    done
    
    # Se tudo correu bem, crie o arquivo de status 'is_sh_ok'
    >$is_sh_ok
    msg ok "Scripts baixados com sucesso."
}


# get server ip
get_ip() {
    export "$(_wget -4 -qO- https://one.one.one.one/cdn-cgi/trace | grep ip=)" &>/dev/null
    [[ -z $ip ]] && export "$(_wget -6 -qO- https://one.one.one.one/cdn-cgi/trace | grep ip=)" &>/dev/null
}

# check background tasks status
check_status() {
    # dependent pkg install fail
    [[ ! -f $is_pkg_ok ]] && {
        # MODIFICADO: Traduzido
        msg err "Falha ao instalar dependências"
        msg err "Por favor, tente instalar manualmente: $cmd update -y; $cmd install -y $is_pkg"
        is_fail=1
    }

    # download file status
    if [[ $is_wget ]]; then
        [[ ! -f $is_core_ok ]] && {
            # MODIFICADO: Traduzido
            msg err "Falha ao baixar ${is_core_name}"
            is_fail=1
        }
        [[ ! -f $is_sh_ok ]] && {
            # MODIFICADO: Traduzido
            msg err "Falha ao baixar um ou mais scripts do ${is_core_name}"
            is_fail=1
        }
        [[ ! -f $is_jq_ok ]] && {
            # MODIFICADO: Traduzido
            msg err "Falha ao baixar jq"
            is_fail=1
        }
    else
        [[ ! $is_fail ]] && {
            is_wget=1
            [[ ! $is_core_file ]] && download core &
            # MODIFICADO: Chama a nova função
            [[ ! $local_install ]] && download_scripts &
            [[ $jq_not_found ]] && download jq &
            get_ip
            wait
            check_status
        }
    fi

    # found fail status, remove tmp dir and exit.
    [[ $is_fail ]] && {
        exit_and_del_tmpdir
    }
}

# parameters check
pass_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
        -f | --core-file)
            [[ -z $2 ]] && {
                # MODIFICADO: Traduzido
                err "($1) Faltando argumento obrigatório, ex: [$1 /root/$is_core-linux-64.zip]"
            } || [[ ! -f $2 ]] && {
                # MODIFICADO: Traduzido
                err "($2) não é um arquivo válido."
            }
            is_core_file=$2
            shift 2
            ;;
        -l | --local-install)
            [[ ! -f ${PWD}/src/core.sh || ! -f ${PWD}/$is_core.sh ]] && {
                # MODIFICADO: Traduzido
                err "O diretório atual (${PWD}) não é um diretório de script completo."
            }
            local_install=1
            shift 1
            ;;
        -p | --proxy)
            [[ -z $2 ]] && {
                # MODIFICADO: Traduzido
                err "($1) Faltando argumento obrigatório, ex: [$1 http://127.0.0.1:2333 or -p socks5://127.0.0.1:2333]"
            }
            proxy=$2
            shift 2
            ;;
        -v | --core-version)
            [[ -z $2 ]] && {
                # MODIFICADO: Traduzido
                err "($1) Faltando argumento obrigatório, ex: [$1 v1.8.1]"
            }
            is_core_ver=v${2#v}
            shift 2
            ;;
        -h | --help)
            show_help
            ;;
        *)
            # MODIFICADO: Traduzido
            echo -e "\n${is_err} ($@) é um parâmetro desconhecido...\n"
            show_help
            ;;
        esac
    done
    [[ $is_core_ver && $is_core_file ]] && {
        # MODIFICADO: Traduzido
        err "Não é possível definir uma versão e um arquivo personalizado do ${is_core_name} ao mesmo tempo."
    }
}

# exit and remove tmpdir
exit_and_del_tmpdir() {
    rm -rf $tmpdir
    [[ ! $1 ]] && {
        # MODIFICADO: Traduzido
        msg err "Opa.."
        msg err "Ocorreu um erro durante a instalação..."
        # MODIFICADO: Aponta para o SEU repositório de issues
        echo -e "Reportar problemas) https://github.com/${is_sh_repo}/issues"
        echo
        exit 1
    }
    exit
}

# main
main() {

    # check old version
    [[ -f $is_sh_bin && -d $is_core_dir/bin && -d $is_sh_dir && -d $is_conf_dir ]] && {
        # MODIFICADO: Traduzido
        err "Script já detectado. Para reinstalar, use: ${green}${is_core} reinstall${none}"
    }

    # check parameters
    [[ $# -gt 0 ]] && pass_args $@

    # show welcome msg
    clear
    echo
    # MODIFICADO: Personalizado
    echo "........... Script $is_core_name (Projeto xray2026) .........."
    echo

    # start installing...
    # MODIFICADO: Traduzido
    msg warn "Iniciando a instalação..."
    [[ $is_core_ver ]] && msg warn "Versão ${is_core_name}: ${yellow}$is_core_ver${none}"
    [[ $proxy ]] && msg warn "Usando proxy: ${yellow}$proxy${none}"
    # create tmpdir
    mkdir -p $tmpdir
    # if is_core_file, copy file
    [[ $is_core_file ]] && {
        cp -f $is_core_file $is_core_ok
        # MODIFICADO: Traduzido
        msg warn "${yellow}Arquivo ${is_core_name} usado > $is_core_file${none}"
    }
    # local dir install sh script
    [[ $local_install ]] && {
        >$is_sh_ok
        # MODIFICADO: Traduzido
        msg warn "${yellow}Instalando scripts localmente > $PWD ${none}"
    }

    timedatectl set-ntp true &>/dev/null
    [[ $? != 0 ]] && {
        # MODIFICADO: Traduzido
        msg warn "${yellow}\e[4mAtenção!!! Não foi possível sincronizar o relógio. Isso pode afetar o protocolo VMess.${none}"
    }

    # install dependent pkg
    install_pkg $is_pkg &

    # jq
    if [[ $(type -P jq) ]]; then
        >$is_jq_ok
    else
        jq_not_found=1
    fi
    # if wget installed. download core, sh, jq, get ip
    [[ $is_wget ]] && {
        [[ ! $is_core_file ]] && download core &
        # MODIFICADO: Chama a nova função
        [[ ! $local_install ]] && download_scripts &
        [[ $jq_not_found ]] && download jq &
        get_ip
    }

    # waiting for background tasks is done
    wait

    # check background tasks status
    check_status

    # test $is_core_file
    if [[ $is_core_file ]]; then
        unzip -qo $is_core_ok -d $tmpdir/testzip &>/dev/null
        [[ $? != 0 ]] && {
            # MODIFICADO: Traduzido
            msg err "Arquivo ${is_core_name} falhou no teste de extração."
            exit_and_del_tmpdir
        }
        for i in ${is_core} geoip.dat geosite.dat; do
            [[ ! -f $tmpdir/testzip/$i ]] && is_file_err=1 && break
        done
        [[ $is_file_err ]] && {
            # MODIFICADO: Traduzido
            msg err "Arquivo ${is_core_name} está incompleto."
            exit_and_del_tmpdir
        }
    fi

    # get server ip.
    [[ ! $ip ]] && {
        # MODIFICADO: Traduzido
        msg err "Falha ao obter o IP do servidor."
        exit_and_del_tmpdir
    }

    # create sh dir...
    # MODIFICADO: A função download_scripts() já cria a pasta
    # mkdir -p $is_sh_dir

    # copy sh file or unzip sh zip file.
    if [[ $local_install ]]; then
        cp -rf $PWD/* $is_sh_dir
    fi
    # MODIFICADO: O unzip não é mais necessário, pois os arquivos são baixados individualmente.
    # else
    #     unzip -qo $is_sh_ok -d $is_sh_dir
    # fi

    # create core bin dir
    mkdir -p $is_core_dir/bin
    # copy core file or unzip core zip file
    if [[ $is_core_file ]]; then
        cp -rf $tmpdir/testzip/* $is_core_dir/bin
    else
        unzip -qo $is_core_ok -d $is_core_dir/bin
    fi

    # add alias
    echo "alias $is_core=$is_sh_bin" >>/root/.bashrc

    # core command
    ln -sf $is_sh_dir/$is_core.sh $is_sh_bin

    # jq
    [[ $jq_not_found ]] && mv -f $is_jq_ok /usr/bin/jq

    # chmod
    chmod +x $is_core_bin $is_sh_bin /usr/bin/jq
    chmod +x $is_sh_dir/src/*.sh # Garante que os scripts baixados sejam executáveis

    # create log dir
    mkdir -p $is_log_dir

    # show a tips msg
    # MODIFICADO: Traduzido
    msg ok "Gerando arquivos de configuração..."

    # create systemd service
    load systemd.sh
    is_new_install=1
    install_service $is_core &>/dev/null

    # create condf dir
    mkdir -p $is_conf_dir

    load core.sh
    # create a tcp config
    add reality
    # remove tmp dir and exit.
    exit_and_del_tmpdir ok
}

# start.
main $@
