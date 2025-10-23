#!/bin/bash

protocol_list=(
    VMess-TCP
    VMess-mKCP
    # VMess-QUIC
    # VMess-H2-TLS
    VMess-WS-TLS
    VMess-gRPC-TLS
    # VLESS-H2-TLS
    VLESS-WS-TLS
    VLESS-gRPC-TLS
    VLESS-XHTTP-TLS
    VLESS-REALITY
    # Trojan-H2-TLS
    Trojan-WS-TLS
    Trojan-gRPC-TLS
    Shadowsocks
    # Dokodemo-Door
    VMess-TCP-dynamic-port
    VMess-mKCP-dynamic-port
    # VMess-QUIC-dynamic-port
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

# MODIFICADO: Traduzido
mainmenu=(
    "Criar Usuário"
    "Alterar Usuário"
    "Ver Usuários"
    "Deletar Usuário"
    "Gerenciar Serviços"
    "Atualizar Script"
    "Desinstalar"
    "Ajuda"
    "Outros"
    "Sobre"
)
# MODIFICADO: Traduzido
info_list=(
    "Protocolo (protocol)"
    "Endereço (address)"
    "Porta (port)"
    "ID de Usuário (id)"
    "Rede (network)"
    "Tipo de Header (type)"
    "Domínio (host)"
    "Caminho (path)"
    "Segurança (TLS)"
    "mKCP seed"
    "Senha (password)"
    "Criptografia (encryption)"
    "Link (URL)"
    "Endereço de Destino"
    "Porta de Destino"
    "Controle de Fluxo (flow)"
    "SNI (serverName)"
    "Impressão Digital (Fingerprint)"
    "Chave Pública (Public key)"
    "Usuário (Username)"
    "Data de Vencimento"
)
# MODIFICADO: Traduzido
change_list=(
    "Alterar Protocolo"
    "Alterar Porta"
    "Alterar Domínio"
    "Alterar Caminho (path)"
    "Alterar Senha"
    "Alterar UUID"
    "Alterar Criptografia"
    "Alterar Tipo de Header"
    "Alterar Endereço de Destino"
    "Alterar Porta de Destino"
    "Alterar Chave (REALITY)"
    "Alterar SNI (serverName)"
    "Alterar Porta Dinâmica"
    "Alterar Site de Camuflagem"
    "Alterar mKCP seed"
    "Alterar Usuário (Socks)"
)
servername_list=(
    www.amazon.com
    www.ebay.com
    www.paypal.com
    www.cloudflare.com
    dash.cloudflare.com
    aws.amazon.com
)

is_random_ss_method=${ss_method_list[$(shuf -i 4-6 -n1)]}    # random only use ss2022
is_random_header_type=${header_type_list[$(shuf -i 1-5 -n1)]} # random dont use none
is_random_servername=${servername_list[$(shuf -i 0-${#servername_list[@]} -n1) - 1]}

msg() {
    echo -e "$@"
}

msg_ul() {
    echo -e "\e[4m$@\e[0m"
}

# pause
pause() {
    echo
    # MODIFICADO: Traduzido
    echo -ne "Pressione $(_green Enter) para continuar, ou $(_red Ctrl + C) para cancelar."
    read -rs -d $'\n'
    echo
}

get_uuid() {
    tmp_uuid=$(cat /proc/sys/kernel/random/uuid)
}

get_ip() {
    [[ $ip || $is_no_auto_tls || $is_gen || $is_dont_get_ip ]] && return
    export "$(_wget -4 -qO- https://one.one.one.one/cdn-cgi/trace | grep ip=)" &>/dev/null
    [[ ! $ip ]] && export "$(_wget -6 -qO- https://one.one.one.one/cdn-cgi/trace | grep ip=)" &>/dev/null
    [[ ! $ip ]] && {
        # MODIFICADO: Traduzido
        err "Falha ao obter o IP do servidor.."
    }
}

get_port() {
    is_count=0
    while :; do
        ((is_count++))
        if [[ $is_count -ge 233 ]]; then
            # MODIFICADO: Traduzido
            err "Falha ao obter porta disponível após 233 tentativas. Verifique o uso das portas."
        fi
        tmp_port=$(shuf -i 445-65535 -n 1)
        [[ ! $(is_test port_used $tmp_port) && $tmp_port != $port ]] && break
    done
}

get_pbk() {
    is_tmp_pbk=($($is_core_bin x25519 | sed 's/.*://'))
    is_private_key=${is_tmp_pbk[0]}
    is_public_key=${is_tmp_pbk[1]}
}

show_list() {
    PS3=''
    COLUMNS=1
    select i in "$@"; do echo; done &
    wait
}

is_test() {
    case $1 in
    number)
        echo $2 | grep -E '^[1-9][0-9]?+$'
        ;;
    port)
        if [[ $(is_test number $2) ]]; then
            [[ $2 -le 65535 ]] && echo ok
        fi
        ;;
    port_used)
        [[ $(is_port_used $2) && ! $is_cant_test_port ]] && echo ok
        ;;
    domain)
        echo $2 | grep -E -i '^\w(\w|\-|\.)?+\.\w+$'
        ;;
    path)
        echo $2 | grep -E -i '^\/\w(\w|\-|\/)?+\w$'
        ;;
    uuid)
        echo $2 | grep -E -i '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
        ;;
    esac

}

is_port_used() {
    if [[ $(type -P netstat) ]]; then
        [[ ! $is_used_port ]] && is_used_port="$(netstat -tunlp | sed -n 's/.*:\([0-9]\+\).*/\1/p' | sort -nu)"
        echo $is_used_port | sed 's/ /\n/g' | grep ^${1}$
        return
    fi
    if [[ $(type -P ss) ]]; then
        [[ ! $is_used_port ]] && is_used_port="$(ss -tunlp | sed -n 's/.*:\([0-9]\+\).*/\1/p' | sort -nu)"
        echo $is_used_port | sed 's/ /\n/g' | grep ^${1}$
        return
    fi
    is_cant_test_port=1
    # MODIFICADO: Traduzido
    msg "$is_warn Não foi possível detectar se a porta está em uso."
    msg "Por favor, execute: $(_yellow "${cmd} update -y; ${cmd} install net-tools -y") para corrigir isso."
}

# ask input a string or pick a option for list.
ask() {
    case $1 in
    set_ss_method)
        is_tmp_list=(${ss_method_list[@]})
        is_default_arg=$is_random_ss_method
        # MODIFICADO: Traduzido
        is_opt_msg="\nSelecione o método de criptografia:\n"
        is_opt_input_msg="(Padrão \e[92m $is_default_arg\e[0m):"
        is_ask_set=ss_method
        ;;
    set_header_type)
        is_tmp_list=(${header_type_list[@]})
        is_default_arg=$is_random_header_type
        [[ $(grep -i tcp <<<"$is_new_protocol-$net") ]] && {
            is_tmp_list=(none http)
            is_default_arg=none
        }
        # MODIFICADO: Traduzido
        is_opt_msg="\nSelecione o tipo de header (camuflagem):\n"
        is_opt_input_msg="(Padrão \e[92m $is_default_arg\e[0m):"
        is_ask_set=header_type
        [[ $is_use_header_type ]] && return
        ;;
    set_protocol)
        is_tmp_list=(${protocol_list[@]})
        [[ $is_no_auto_tls ]] && {
            unset is_tmp_list
            for v in ${protocol_list[@]}; do
                [[ $(grep -i tls$ <<<$v) ]] && is_tmp_list=(${is_tmp_list[@]} $v)
            done
        }
        # MODIFICADO: Traduzido
        is_opt_msg="\nSelecione o protocolo:\n"
        is_ask_set=is_new_protocol
        ;;
    set_change_list)
        is_tmp_list=()
        for v in ${is_can_change[@]}; do
            is_tmp_list+=("${change_list[$v]}")
        done
        # MODIFICADO: Traduzido
        is_opt_msg="\nSelecione o que deseja alterar:\n"
        is_ask_set=is_change_str
        is_opt_input_msg=$3
        ;;
    string)
        is_ask_set=$2
        is_opt_input_msg=$3
        ;;
    list)
        is_ask_set=$2
        [[ ! $is_tmp_list ]] && is_tmp_list=($3)
        is_opt_msg=$4
        is_opt_input_msg=$5
        ;;
    get_config_file)
        is_tmp_list=("${is_all_json[@]}")
        # MODIFICADO: Traduzido
        is_opt_msg="\nSelecione a configuração (usuário):\n"
        is_ask_set=is_config_file
        ;;
    mainmenu)
        is_tmp_list=("${mainmenu[@]}")
        is_ask_set=is_main_pick
        is_emtpy_exit=1
        ;;
    esac
    msg $is_opt_msg
    # MODIFICADO: Traduzido
    [[ ! $is_opt_input_msg ]] && is_opt_input_msg="Selecione [\e[91m1-${#is_tmp_list[@]}\e[0m]:"
    [[ $is_tmp_list ]] && show_list "${is_tmp_list[@]}"
    while :; do
        echo -ne $is_opt_input_msg
        read REPLY
        [[ ! $REPLY && $is_emtpy_exit ]] && exit
        [[ ! $REPLY && $is_default_arg ]] && export $is_ask_set=$is_default_arg && break
        # Easter egg mantido
        [[ "$REPLY" == "${is_str}2${is_get}3${is_opt}3" && $is_ask_set == 'is_main_pick' ]] && {
            msg "\n${is_get}2${is_str}3${is_msg}3b${is_tmp}o${is_opt}y\n" && exit
        }
        if [[ ! $is_tmp_list ]]; then
            [[ $(grep port <<<$is_ask_set) ]] && {
                [[ ! $(is_test port "$REPLY") ]] && {
                    # MODIFICADO: Traduzido
                    msg "$is_err Por favor, digite uma porta válida (1-65535)"
                    continue
                }
                if [[ $(is_test port_used $REPLY) && $is_ask_set != 'door_port' ]]; then
                    # MODIFICADO: Traduzido
                    msg "$is_err Não é possível usar a porta ($REPLY)."
                    continue
                fi
            }
            [[ $(grep path <<<$is_ask_set) && ! $(is_test path "$REPLY") ]] && {
                [[ ! $tmp_uuid ]] && get_uuid
                # MODIFICADO: Traduzido
                msg "$is_err Por favor, digite um caminho válido, ex: /$tmp_uuid"
                continue
            }
            [[ $(grep uuid <<<$is_ask_set) && ! $(is_test uuid "$REPLY") ]] && {
                [[ ! $tmp_uuid ]] && get_uuid
                # MODIFICADO: Traduzido
                msg "$is_err Por favor, digite um UUID válido, ex: $tmp_uuid"
                continue
            }
            # MODIFICADO: Traduzido de 'y' para 's' (sim)
            [[ $(grep ^s$ <<<$is_ask_set) ]] && {
                [[ $(grep -i ^s$ <<<"$REPLY") ]] && break
                msg "Por favor, digite (s)"
                continue
            }
            [[ $REPLY ]] && export $is_ask_set=$REPLY && msg "Usando: ${!is_ask_set}" && break
        else
            [[ $(is_test number "$REPLY") ]] && is_ask_result=${is_tmp_list[$REPLY - 1]}
            [[ $is_ask_result ]] && export $is_ask_set="$is_ask_result" && msg "Selecionado: ${!is_ask_set}" && break
        fi

        # MODIFICADO: Traduzido
        msg "Entrada ${is_err} inválida"
    done
    unset is_opt_msg is_opt_input_msg is_tmp_list is_ask_result is_default_arg is_emtpy_exit
}

# create file
create() {
    case $1 in
    server)
        get new

        # file name
        if [[ $host ]]; then
            is_config_name=$2-${host}.json
        else
            is_config_name=$2-${port}.json
        fi
        is_json_file=$is_conf_dir/$is_config_name
        # get json
        [[ $is_change || ! $json_str ]] && get protocol $2
        is_listen='listen:"0.0.0.0"'
        [[ $host ]] && is_listen=${is_listen/0.0.0.0/127.0.0.1}
        is_sniffing='sniffing:{enabled:true,destOverride:["http","tls"]}'
        [[ $is_reality ]] && is_sniffing='sniffing:{enabled:true,destOverride:["http","tls"],routeOnly:true}'
        is_new_json=$(jq '{inbounds:[{tag:"'$is_config_name'",port:'"$port"','"$is_listen"',protocol:"'$is_protocol'",'"$json_str"','"$is_sniffing"'}]}' <<<{})
        if [[ $is_dynamic_port ]]; then
            [[ ! $is_dynamic_port_range ]] && get dynamic-port
            is_new_dynamic_port_json=$(jq '{inbounds:[{tag:"'$is_config_name-link.json'",port:"'$is_dynamic_port_range'",'"$is_listen"',protocol:"vmess",'"$is_stream"','"$is_sniffing"',allocate:{strategy:"random"}}]}' <<<{})
        fi
        [[ $is_test_json ]] && return # tmp test
        # only show json, dont save to file.
        [[ $is_gen ]] && {
            msg
            jq <<<$is_new_json
            msg
            [[ $is_new_dynamic_port_json ]] && jq <<<$is_new_dynamic_port_json && msg
            return
        }
        # del old file
        [[ $is_config_file ]] && is_no_del_msg=1 && del $is_config_file
        # save json to file
        cat <<<$is_new_json >$is_json_file
        [[ $is_new_dynamic_port_json ]] && {
            is_dynamic_port_link_file=$is_json_file-link.json
            cat <<<$is_new_dynamic_port_json >$is_dynamic_port_link_file
        }
        if [[ $is_new_install ]]; then
            # config.json
            create config.json
        else
            # use api add config
            api add $is_json_file $is_dynamic_port_link_file &>/dev/null
        fi

        # INÍCIO DA MODIFICAÇÃO DE DATA DE VENCIMENTO
        if [[ ! $is_change && $uuid ]]; then # Só pergunta na criação, não na alteração
            # Garante que o arquivo exista
            touch $is_core_dir/expirations.db
            
            msg "\n${yellow}Configuração de Data de Vencimento (Opcional)${none}"
            ask string is_exp_date "Digite uma data de vencimento (Formato: AAAA-MM-DD), ou pressione Enter para pular:"
            
            if [[ $is_exp_date ]]; then
                if date -d "$is_exp_date" "+%Y-%m-%d" &>/dev/null; then
                    sed -i "/^${uuid}:/d" $is_core_dir/expirations.db
                    echo "${uuid}:${is_exp_date}" >> $is_core_dir/expirations.db
                    msg ok "Usuário $uuid configurado para expirar em $is_exp_date."
                else
                    warn "Formato de data inválido. Usuário não terá data de vencimento."
                    sed -i "/^${uuid}:/d" $is_core_dir/expirations.db # Remove em caso de data inválida
                fi
            else
                sed -i "/^${uuid}:/d" $is_core_dir/expirations.db # Remove se o usuário pular
                msg ok "Usuário não terá data de vencimento."
            fi
        fi
        # FIM DA MODIFICAÇÃO

        # caddy auto tls
        [[ $is_caddy && $host && ! $is_no_auto_tls ]] && {
            create caddy $net
        }
        # restart core
        [[ $is_api_fail ]] && manage restart &
        ;;
    client)
        is_tls=tls
        is_client=1
        get info $2
        # MODIFICADO: Traduzido
        [[ ! $is_client_id_json ]] && err "($is_config_name) não suporta geração de config de cliente."
        [[ $host ]] && is_stream="${is_stream/network:\"$net\"/network:\"$net\",security:\"tls\"}"
        is_new_json=$(jq '{outbounds:[{tag:"'$is_config_name'",protocol:"'$is_protocol'",'"$is_client_id_json"','"$is_stream"'}]}' <<<{})
        if [[ $is_full_client ]]; then
            is_dns='dns:{servers:[{address:"223.5.5.5",domain:["geosite:cn","geosite:geolocation-cn"],expectIPs:["geoip:cn"]},"1.1.1.1","8.8.8.8"]}'
            is_route='routing:{rules:[{type:"field",outboundTag:"direct",ip:["geoip:cn","geoip:private"]},{type:"field",outboundTag:"direct",domain:["geosite:cn","geosite:geolocation-cn"]}]}'
            is_inbounds='inbounds:[{port:2333,listen:"127.0.0.1",protocol:"socks",settings:{udp:true},sniffing:{enabled:true,destOverride:["http","tls"]}}]'
            is_outbounds='outbounds:[{tag:"'$is_config_name'",protocol:"'$is_protocol'",'"$is_client_id_json"','"$is_stream"'},{tag:"direct",protocol:"freedom"}]'
            is_new_json=$(jq '{'$is_dns,$is_route,$is_inbounds,$is_outbounds'}' <<<{})
        fi
        msg
        jq <<<$is_new_json
        msg
        ;;
    caddy)
        load caddy.sh
        [[ $is_install_caddy ]] && caddy_config new
        [[ ! $(grep "$is_caddy_conf" $is_caddyfile) ]] && {
            msg "import $is_caddy_conf/*.conf" >>$is_caddyfile
        }
        [[ ! -d $is_caddy_conf ]] && mkdir -p $is_caddy_conf
        caddy_config $2
        manage restart caddy &
        ;;
    config.json)
        get_port
        is_log='log:{access:"/var/log/'"$is_core"'/access.log",error:"/var/log/'"$is_core"'/error.log",loglevel:"warning"}'
        is_dns='dns:{}'
        is_api='api:{tag:"api",services:["HandlerService","LoggerService","StatsService"]}'
        is_stats='stats:{}'
        is_policy_system='system:{statsInboundUplink:true,statsInboundDownlink:true,statsOutboundUplink:true,statsOutboundDownlink:true}'
        is_policy='policy:{levels:{"0":{handshake:'"$((${tmp_port:0:1} + 1))"',connIdle:'"${tmp_port:0:3}"',uplinkOnly:'"$((${tmp_port:2:1} + 1))"',downlinkOnly:'"$((${tmp_port:3:1} + 3))"',statsUserUplink:true,statsUserDownlink:true}},'"$is_policy_system"'}'
        is_ban_ad='{type:"field",domain:["geosite:category-ads-all"],marktag:"ban_ad",outboundTag:"block"}'
        is_ban_bt='{type:"field",protocol:["bittorrent"],marktag:"ban_bt",outboundTag:"block"}'
        is_ban_cn='{type:"field",ip:["geoip:cn"],marktag:"ban_geoip_cn",outboundTag:"block"}'
        is_openai='{type:"field",domain:["geosite:openai"],marktag:"fix_openai",outboundTag:"direct"}'
        is_routing='routing:{domainStrategy:"IPIfNonMatch",rules:[{type:"field",inboundTag:["api"],outboundTag:"api"},'"$is_ban_bt"','"$is_ban_cn"','"$is_openai"',{type:"field",ip:["geoip:private"],outboundTag:"block"}]}'
        is_inbounds='inbounds:[{tag:"api",port:'"$tmp_port"',listen:"127.0.0.1",protocol:"dokodemo-door",settings:{address:"127.0.0.1"}}]'
        is_outbounds='outbounds:[{tag:"direct",protocol:"freedom"},{tag:"block",protocol:"blackhole"}]'
        is_server_config_json=$(jq '{'"$is_log"','"$is_dns"','"$is_api"','"$is_stats"','"$is_policy"','"$is_routing"','"$is_inbounds"','"$is_outbounds"'}' <<<{})
        cat <<<$is_server_config_json >$is_config_json
        manage restart &
        ;;
    esac
}

# change config file
change() {
    is_change=1
    is_dont_show_info=1
    if [[ $2 ]]; then
        case ${2,,} in
        full)
            is_change_id=full
            ;;
        new)
            is_change_id=0
            ;;
        port)
            is_change_id=1
            ;;
        host)
            is_change_id=2
            ;;
        path)
            is_change_id=3
            ;;
        pass | passwd | password)
            is_change_id=4
            ;;
        id | uuid)
            is_change_id=5
            ;;
        ssm | method | ss-method | ss_method)
            is_change_id=6
            ;;
        type | header | header-type | header_type)
            is_change_id=7
            ;;
        dda | door-addr | door_addr)
            is_change_id=8
            ;;
        ddp | door-port | door_port)
            is_change_id=9
            ;;
        key | publickey | privatekey)
            is_change_id=10
            ;;
        sni | servername | servernames)
            is_change_id=11
            ;;
        dp | dyp | dynamic | dynamicport | dynamic-port)
            is_change_id=12
            ;;
        web | proxy-site)
            is_change_id=13
            ;;
        seed | kcpseed | kcp-seed | kcp_seed)
            is_change_id=14
            ;;
        user | username) # MODIFICADO: Adicionado 'user'
            is_change_id=15
            ;;
        *)
            [[ $is_try_change ]] && return
            # MODIFICADO: Traduzido
            err "Não foi possível reconhecer o tipo de alteração ($2)."
            ;;
        esac
    fi
    [[ $is_try_change ]] && return
    [[ $is_dont_auto_exit ]] && {
        get info $1
    } || {
        [[ $is_change_id ]] && {
            is_change_msg=${change_list[$is_change_id]}
            [[ $is_change_id == 'full' ]] && {
                # MODIFICADO: Traduzido
                [[ $3 ]] && is_change_msg="Alterar múltiplos parâmetros" || is_change_msg=
            }
            # MODIFICADO: Traduzido
            [[ $is_change_msg ]] && _green "\nExecução rápida: $is_change_msg"
        }
        info $1
        # MODIFICADO: Traduzido
        [[ $is_auto_get_config ]] && msg "\nSeleção automática: $is_config_file"
    }
    is_old_net=$net
    [[ $host ]] && net=$is_protocol-$net-tls
    [[ $is_reality ]] && net=reality
    [[ $is_dynamic_port ]] && net=${net}d
    [[ $3 == 'auto' ]] && is_auto=1
    # if is_dont_show_info exist, cant show info.
    is_dont_show_info=
    # if not prefer args, show change list and then get change id.
    [[ ! $is_change_id ]] && {
        ask set_change_list
        is_change_id=${is_can_change[$REPLY - 1]}
    }
    case $is_change_id in
    full)
        add $net ${@:3}
        ;;
    0)
        # new protocol
        is_set_new_protocol=1
        add ${@:3}
        ;;
    1)
        # new port
        is_new_port=$3
        # MODIFICADO: Traduzido
        [[ $host && ! $is_caddy || $is_no_auto_tls ]] && err "($is_config_file) não suporta alteração de porta, não faz sentido."
        if [[ $is_new_port && ! $is_auto ]]; then
            # MODIFICADO: Traduzido
            [[ ! $(is_test port $is_new_port) ]] && err "Por favor, digite uma porta válida (1-65535)"
            [[ $is_new_port != 443 && $(is_test port_used $is_new_port) ]] && err "Não é possível usar a porta ($is_new_port)"
        fi
        [[ $is_auto ]] && get_port && is_new_port=$tmp_port
        # MODIFICADO: Traduzido
        [[ ! $is_new_port ]] && ask string is_new_port "Digite a nova porta:"
        if [[ $is_caddy && $host ]]; then
            net=$is_old_net
            is_https_port=$is_new_port
            load caddy.sh
            caddy_config $net
            manage restart caddy &
            info
        else
            add $net $is_new_port
        fi
        ;;
    2)
        # new host
        is_new_host=$3
        # MODIFICADO: Traduzido
        [[ ! $host ]] && err "($is_config_file) não suporta alteração de domínio."
        [[ ! $is_new_host ]] && ask string is_new_host "Digite o novo domínio:"
        old_host=$host # del old host
        add $net $is_new_host
        ;;
    3)
        # new path
        is_new_path=$3
        # MODIFICADO: Traduzido
        [[ ! $path ]] && err "($is_config_file) não suporta alteração de caminho."
        [[ $is_auto ]] && get_uuid && is_new_path=/$tmp_uuid
        # MODIFICADO: Traduzido
        [[ ! $is_new_path ]] && ask string is_new_path "Digite o novo caminho:"
        add $net auto auto $is_new_path
        ;;
    4)
        # new password
        is_new_pass=$3
        if [[ $net == 'ss' || $is_trojan || $is_socks_pass ]]; then
            [[ $is_auto ]] && get_uuid && is_new_pass=$tmp_uuid
        else
            # MODIFICADO: Traduzido
            err "($is_config_file) não suporta alteração de senha."
        fi
        # MODIFICADO: Traduzido
        [[ ! $is_new_pass ]] && ask string is_new_pass "Digite a nova senha:"
        trojan_password=$is_new_pass
        ss_password=$is_new_pass
        is_socks_pass=$is_new_pass
        add $net
        ;;
    5)
        # new uuid
        is_new_uuid=$3
        # MODIFICADO: Traduzido
        [[ ! $uuid ]] && err "($is_config_file) não suporta alteração de UUID."
        [[ $is_auto ]] && get_uuid && is_new_uuid=$tmp_uuid
        # MODIFICADO: Traduzido
        [[ ! $is_new_uuid ]] && ask string is_new_uuid "Digite o novo UUID:"
        add $net auto $is_new_uuid
        ;;
    6)
        # new method
        is_new_method=$3
        # MODIFICADO: Traduzido
        [[ $net != 'ss' ]] && err "($is_config_file) não suporta alteração de método de criptografia."
        [[ $is_auto ]] && is_new_method=$is_random_ss_method
        [[ ! $is_new_method ]] && {
            ask set_ss_method
            is_new_method=$ss_method
        }
        add $net auto auto $is_new_method
        ;;
    7)
        # new header type
        is_new_header_type=$3
        # MODIFICADO: Traduzido
        [[ ! $header_type ]] && err "($is_config_file) não suporta alteração de tipo de header."
        [[ $is_auto ]] && {
            is_new_header_type=$is_random_header_type
            if [[ $net == 'tcp' ]]; then
                is_tmp_header_type=(none http)
                is_new_header_type=${is_tmp_header_type[$(shuf -i 0-1 -n1)]}
            fi
        }
        [[ ! $is_new_header_type ]] && {
            ask set_header_type
            is_new_header_type=$header_type
        }
        add $net auto auto $is_new_header_type
        ;;
    8)
        # new remote addr
        is_new_door_addr=$3
        # MODIFICADO: Traduzido
        [[ $net != 'door' ]] && err "($is_config_file) não suporta alteração de endereço de destino."
        [[ ! $is_new_door_addr ]] && ask string is_new_door_addr "Digite o novo endereço de destino:"
        door_addr=$is_new_door_addr
        add $net
        ;;
    9)
        # new remote port
        is_new_door_port=$3
        # MODIFICADO: Traduzido
        [[ $net != 'door' ]] && err "($is_config_file) não suporta alteração de porta de destino."
        [[ ! $is_new_door_port ]] && {
            # MODIFICADO: Traduzido
            ask string door_port "Digite a nova porta de destino:"
            is_new_door_port=$door_port
        }
        add $net auto auto $is_new_door_port
        ;;
    10)
        # new is_private_key is_public_key
        is_new_private_key=$3
        is_new_public_key=$4
        # MODIFICADO: Traduzido
        [[ ! $is_reality ]] && err "($is_config_file) não suporta alteração de chaves."
        if [[ $is_auto ]]; then
            get_pbk
            add $net
        else
            # MODIFICADO: Traduzido
            [[ $is_new_private_key && ! $is_new_public_key ]] && {
                err "Chave pública (Public key) não encontrada."
            }
            [[ ! $is_new_private_key ]] && ask string is_new_private_key "Digite a nova Chave Privada (Private key):"
            [[ ! $is_new_public_key ]] && ask string is_new_public_key "Digite a nova Chave Pública (Public key):"
            if [[ $is_new_private_key == $is_new_public_key ]]; then
                err "Chave Privada e Chave Pública não podem ser iguais."
            fi
            is_private_key=$is_new_private_key
            is_test_json=1
            create server $is_protocol-$net
            $is_core_bin -test <<<"$is_new_json" &>/dev/null
            if [[ $? != 0 ]]; then
                err "Chave Privada (Private key) falhou no teste."
            fi
            is_private_key=$is_new_public_key
            create server $is_protocol-$net
            $is_core_bin -test <<<"$is_new_json" &>/dev/null
            if [[ $? != 0 ]]; then
                err "Chave Pública (Public key) falhou no teste."
            fi
            is_private_key=$is_new_private_key
            is_public_key=$is_new_public_key
            is_test_json=
            add $net
        fi
        ;;
    11)
        # new serverName
        is_new_servername=$3
        # MODIFICADO: Traduzido
        [[ ! $is_reality ]] && err "($is_config_file) não suporta alteração de serverName (SNI)."
        [[ $is_auto ]] && is_new_servername=$is_random_servername
        # MODIFICADO: Traduzido
        [[ ! $is_new_servername ]] && ask string is_new_servername "Digite o novo serverName (SNI):"
        is_servername=$is_new_servername
        [[ $(grep -i "^233boy.com$" <<<$is_servername) ]] && {
            err "Você está de brincadeira?"
        }
        add $net
        ;;
    12)
        # new dynamic-port
        is_new_dynamic_port_start=$3
        is_new_dynamic_port_end=$4
        # MODIFICADO: Traduzido
        [[ ! $is_dynamic_port ]] && err "($is_config_file) não suporta alteração de porta dinâmica."
        if [[ $is_auto ]]; then
            get dynamic-port
            add $net
        else
            # MODIFICADO: Traduzido
            [[ $is_new_dynamic_port_start && ! $is_new_dynamic_port_end ]] && {
                err "Porta final da faixa dinâmica não encontrada."
            }
            [[ ! $is_new_dynamic_port_start ]] && ask string is_new_dynamic_port_start "Digite a nova porta dinâmica inicial:"
            [[ ! $is_new_dynamic_port_end ]] && ask string is_new_dynamic_port_end "Digite a nova porta dinâmica final:"
            add $net auto auto auto $is_new_dynamic_port_start $is_new_dynamic_port_end
        fi
        ;;
    13)
        # new proxy site
        is_new_proxy_site=$3
        [[ ! $is_caddy && ! $host ]] && {
            # MODIFICADO: Traduzido
            err "($is_config_file) não suporta alteração de site de camuflagem."
        }
        # MODIFICADO: Traduzido
        [[ ! -f $is_caddy_conf/${host}.conf.add ]] && err "Não é possível configurar o site de camuflagem."
        [[ ! $is_new_proxy_site ]] && ask string is_new_proxy_site "Digite o novo site de camuflagem (ex: example.com):"
        proxy_site=$(sed 's#^.*//##;s#/$##' <<<$is_new_proxy_site)
        [[ $(grep -i "^233boy.com$" <<<$proxy_site) ]] && {
            err "Você está de brincadeira?"
        } || {
            load caddy.sh
            caddy_config proxy
            manage restart caddy &
        }
        # MODIFICADO: Traduzido
        msg "\nSite de camuflagem atualizado para: $(_green $proxy_site) \n"
        ;;
    14)
        # new kcp seed
        is_new_kcp_seed=$3
        # MODIFICADO: Traduzido
        [[ ! $kcp_seed ]] && err "($is_config_file) não suporta alteração de mKCP seed."
        [[ $is_auto ]] && get_uuid && is_new_kcp_seed=$tmp_uuid
        # MODIFICADO: Traduzido
        [[ ! $is_new_kcp_seed ]] && ask string is_new_kcp_seed "Digite o novo mKCP seed:"
        kcp_seed=$is_new_kcp_seed
        add $net
        ;;
    15)
        # new socks user
        # MODIFICADO: Traduzido
        [[ ! $is_socks_user ]] && err "($is_config_file) não suporta alteração de nome de usuário (Username)."
        ask string is_socks_user "Digite o novo nome de usuário (Username):"
        add $net
        ;;
    esac
}

# delete config.
del() {
    # dont get ip
    is_dont_get_ip=1
    [[ $is_conf_dir_empty ]] && return # not found any json file.
    # get a config file
    [[ ! $is_config_file ]] && get info $1
    if [[ $is_config_file ]]; then
        if [[ $is_main_start && ! $is_no_del_msg ]]; then
            # MODIFICADO: Traduzido
            msg "\nDeseja deletar este arquivo de configuração? (usuário): $is_config_file"
            pause
        fi
        api del $is_conf_dir/"$is_config_file" $is_dynamic_port_file &>/dev/null
        
        # MODIFICADO: Remove do banco de dados de expiração
        if [[ $uuid && -f $is_core_dir/expirations.db ]]; then
            sed -i "/^${uuid}:/d" $is_core_dir/expirations.db
        fi

        rm -rf $is_conf_dir/"$is_config_file" $is_dynamic_port_file
        [[ $is_api_fail && ! $is_new_json ]] && manage restart &
        # MODIFICADO: Traduzido
        [[ ! $is_no_del_msg ]] && _green "\nDeletado: $is_config_file\n"

        [[ $is_caddy ]] && {
            is_del_host=$host
            [[ $is_change ]] && {
                [[ ! $old_host ]] && return # no host exist or not set new host;
                is_del_host=$old_host
            }
            [[ $is_del_host && $host != $old_host && -f $is_caddy_conf/$is_del_host.conf ]] && {
                rm -rf $is_caddy_conf/$is_del_host.conf $is_caddy_conf/$is_del_host.conf.add
                [[ ! $is_new_json ]] && manage restart caddy &
            }
        }
    fi
    if [[ ! $(ls $is_conf_dir | grep .json) && ! $is_change ]]; then
        # MODIFICADO: Traduzido
        warn "O diretório de configurações está vazio! Você acabou de deletar o último usuário."
        is_conf_dir_empty=1
    fi
    unset is_dont_get_ip
    [[ $is_dont_auto_exit ]] && unset is_config_file
}

# uninstall
uninstall() {
    if [[ $is_caddy ]]; then
        # MODIFICADO: Traduzido
        is_tmp_list=("Desinstalar $is_core_name" "Desinstalar ${is_core_name} & Caddy")
        ask list is_do_uninstall
    else
        # MODIFICADO: Traduzido (y -> s)
        ask string s "Deseja desinstalar ${is_core_name}? [s]:"
    fi
    manage stop &>/dev/null
    manage disable &>/dev/null
    rm -rf $is_core_dir $is_log_dir $is_sh_bin /lib/systemd/system/$is_core.service
    sed -i "/alias $is_core=/d" /root/.bashrc
    # uninstall caddy; 2 is ask result
    if [[ $REPLY == '2' ]]; then
        manage stop caddy &>/dev/null
        manage disable caddy &>/dev/null
        rm -rf $is_caddy_dir $is_caddy_bin /lib/systemd/system/caddy.service
    fi
    [[ $is_install_sh ]] && return # reinstall
    # MODIFICADO: Traduzido e link atualizado
    _green "\nDesinstalação completa!"
    msg "Onde o script pode melhorar? Por favor, envie seu feedback."
    msg "Reportar problemas) $(msg_ul https://github.com/${is_sh_repo}/issues)\n"
}

# manage run status
manage() {
    [[ $is_dont_auto_exit ]] && return
    case $1 in
    1 | start)
        is_do=start
        # MODIFICADO: Traduzido
        is_do_msg=Iniciar
        is_test_run=1
        ;;
    2 | stop)
        is_do=stop
        # MODIFICADO: Traduzido
        is_do_msg=Parar
        ;;
    3 | r | restart)
        is_do=restart
        # MODIFICADO: Traduzido
        is_do_msg=Reiniciar
        is_test_run=1
        ;;
    *)
        is_do=$1
        is_do_msg=$1
        ;;
    esac
    case $2 in
    caddy)
        is_do_name=$2
        is_run_bin=$is_caddy_bin
        is_do_name_msg=Caddy
        ;;
    *)
        is_do_name=$is_core
        is_run_bin=$is_core_bin
        is_do_name_msg=$is_core_name
        ;;
    esac
    systemctl $is_do $is_do_name
    [[ $is_test_run && ! $is_new_install ]] && {
        sleep 2
        if [[ ! $(pgrep -f $is_run_bin) ]]; then
            is_run_fail=${is_do_name_msg,,}
            [[ ! $is_no_manage_msg ]] && {
                msg
                # MODIFICADO: Traduzido
                warn "Falha ao ($is_do_msg) $is_do_name_msg"
                _yellow "Falha detectada, executando teste de diagnóstico."
                get test-run
                _yellow "Teste finalizado, pressione Enter para sair."
            }
        fi
    }
}

# use api add or del inbounds
api() {
    # MODIFICADO: Traduzido
    [[ ! $1 ]] && err "Parâmetros da API não reconhecidos."
    [[ $is_core_stop ]] && {
        warn "$is_core_name está parado no momento."
        is_api_fail=1
        return
    }
    case $1 in
    add)
        is_api_do=adi
        ;;
    del)
        is_api_do=rmi
        ;;
    s)
        is_api_do=stats
        ;;
    t | sq)
        is_api_do=statsquery
        ;;
    esac
    [[ ! $is_api_do ]] && is_api_do=$1
    [[ ! $is_api_port ]] && {
        is_api_port=$(jq '.inbounds[] | select(.tag == "api") | .port' $is_config_json)
        [[ $? != 0 ]] && {
            # MODIFICADO: Traduzido
            warn "Falha ao ler a porta da API. Não é possível usar operações da API."
            return
        }
    }
    $is_core_bin api $is_api_do --server=127.0.0.1:$is_api_port ${@:2}
    [[ $? != 0 ]] && {
        is_api_fail=1
    }
}

# add a config
add() {
    is_lower=${1,,}
    if [[ $is_lower ]]; then
        case $is_lower in
        # tcp | kcp | quic | tcpd | kcpd | quicd)
        tcp | kcp | tcpd | kcpd)
            is_new_protocol=VMess-$(sed 's/^K/mK/;s/D$/-dynamic-port/' <<<${is_lower^^})
            ;;
        # ws | h2 | grpc | vws | vh2 | vgrpc | tws | th2 | tgrpc)
        ws | grpc | vws | vgrpc | tws | tgrpc)
            is_new_protocol=$(sed -E "s/^V/VLESS-/;s/^T/Trojan-/;/^(W|H|G)/{s/^/VMess-/};s/G/g/" <<<${is_lower^^})-TLS
            ;;
        xhttp)
            is_new_protocol=VLESS-XHTTP-TLS
            ;;
        r | reality)
            is_new_protocol=VLESS-REALITY
            ;;
        ss)
            is_new_protocol=Shadowsocks
            ;;
        door)
            is_new_protocol=Dokodemo-Door
            ;;
        socks)
            is_new_protocol=Socks
            ;;
        *)
            for v in ${protocol_list[@]}; do
                [[ $(grep -E -i "^$is_lower$" <<<$v) ]] && is_new_protocol=$v && break
            done
            
            # MODIFICADO: Traduzido
            [[ ! $is_new_protocol ]] && err "Não foi possível reconhecer ($1), por favor, use: $is_core add [protocolo] [args... | auto]"
            ;;
        esac
    fi

    # no prefer protocol
    [[ ! $is_new_protocol ]] && ask set_protocol

    case ${is_new_protocol,,} in
    *-tls)
        is_use_tls=1
        is_use_host=$2
        is_use_uuid=$3
        is_use_path=$4
        is_add_opts="[host] [uuid] [/path]"
        ;;
    vmess*)
        is_use_port=$2
        is_use_uuid=$3
        is_use_header_type=$4
        is_use_dynamic_port_start=$5
        is_use_dynamic_port_end=$6
        [[ $(grep dynamic-port <<<$is_new_protocol) ]] && is_dynamic_port=1
        if [[ $is_dynamic_port ]]; then
            is_add_opts="[port] [uuid] [type] [porta_inicio] [porta_fim]"
        else
            is_add_opts="[port] [uuid] [type]"
        fi
        ;;
    *reality*)
        is_reality=1
        is_use_port=$2
        is_use_uuid=$3
        is_use_servername=$4
        is_add_opts="[port] [uuid] [sni]"
        ;;
    shadowsocks)
        is_use_port=$2
        is_use_pass=$3
        is_use_method=$4
        is_add_opts="[port] [senha] [metodo]"
        ;;
    *door)
        is_use_port=$2
        is_use_door_addr=$3
        is_use_door_port=$4
        is_add_opts="[port] [ip_destino] [porta_destino]"
        ;;
    socks)
        is_socks=1
        is_use_port=$2
        is_use_socks_user=$3
        is_use_socks_pass=$4
        is_add_opts="[port] [usuario] [senha]"
        ;;
    *http)
        is_use_port=$2
        is_add_opts="[port]"
        ;;
    esac

    [[ $1 && ! $is_change ]] && {
        # MODIFICADO: Traduzido
        msg "\nUsando protocolo: $is_new_protocol"
        is_err_tips="\n\nPor favor, use: $(_green $is_core add $1 $is_add_opts) para adicionar uma configuração $is_new_protocol"
    }

    # remove old protocol args
    if [[ $is_set_new_protocol ]]; then
        case $is_old_net in
        tcp)
            unset header_type net
            ;;
        kcp | quic)
            kcp_seed=
            [[ $(grep -i tcp <<<$is_new_protocol) ]] && header_type=
            ;;
        h2 | ws | grpc | xhttp)
            old_host=$host
            if [[ ! $is_use_tls ]]; then
                unset host is_no_auto_tls
            else
                [[ $is_old_net == 'grpc' ]] && {
                    path=/$path
                }
            fi
            [[ ! $(grep -i trojan <<<$is_new_protocol) ]] && is_trojan=
            ;;
        ss)
            [[ $(is_test uuid $ss_password) ]] && uuid=$ss_password
            ;;
        esac
        [[ $is_dynamic_port && ! $(grep dynamic-port <<<$is_new_protocol) ]] && {
            is_dynamic_port=
        }

        [[ ! $(is_test uuid $uuid) ]] && uuid=
        [[ ! $(grep -i reality <<<$is_new_protocol) ]] && is_reality=
    fi

    # no-auto-tls only use h2,ws,grpc
    if [[ $is_no_auto_tls && ! $is_use_tls ]]; then
        # MODIFICADO: Traduzido
        err "$is_new_protocol não suporta configuração manual de TLS."
    fi

    # prefer args.
    if [[ $2 ]]; then
        for v in is_use_port is_use_uuid is_use_header_type is_use_host is_use_path is_use_pass is_use_method is_use_door_addr is_use_door_port is_use_dynamic_port_start is_use_dynamic_port_end; do
            [[ ${!v} == 'auto' ]] && unset $v
        done

        if [[ $is_use_port ]]; then
            [[ ! $(is_test port ${is_use_port}) ]] && {
                # MODIFICADO: Traduzido
                err "($is_use_port) não é uma porta válida. $is_err_tips"
            }
            [[ $(is_test port_used $is_use_port) ]] && {
                # MODIFICADO: Traduzido
                err "Não é possível usar a porta ($is_use_port). $is_err_tips"
            }
            port=$is_use_port
        fi
        if [[ $is_use_door_port ]]; then
            [[ ! $(is_test port ${is_use_door_port}) ]] && {
                # MODIFICADO: Traduzido
                err "(${is_use_door_port}) não é uma porta de destino válida. $is_err_tips"
            }
            door_port=$is_use_door_port
        fi
        if [[ $is_use_uuid ]]; then
            [[ ! $(is_test uuid $is_use_uuid) ]] && {
                # MODIFICADO: Traduzido
                err "($is_use_uuid) não é um UUID válido. $is_err_tips"
            }
            uuid=$is_use_uuid
        fi
        if [[ $is_use_path ]]; then
            [[ ! $(is_test path $is_use_path) ]] && {
                # MODIFICADO: Traduzido
                err "($is_use_path) não é um caminho válido. $is_err_tips"
            }
            path=$is_use_path
        fi
        if [[ $is_use_header_type || $is_use_method ]]; then
            # MODIFICADO: Traduzido
            is_tmp_use_name=Criptografia
            is_tmp_list=${ss_method_list[@]}
            [[ ! $is_use_method ]] && {
                # MODIFICADO: Traduzido
                is_tmp_use_name="Tipo de Header"
                ask set_header_type
            }
            for v in ${is_tmp_list[@]}; do
                [[ $(grep -E -i "^${is_use_header_type}${is_use_method}$" <<<$v) ]] && is_tmp_use_type=$v && break
            done
            [[ ! ${is_tmp_use_type} ]] && {
                # MODIFICADO: Traduzido
                warn "(${is_use_header_type}${is_use_method}) não é um ${is_tmp_use_name} válido."
                msg "${is_tmp_use_name} disponíveis: "
                for v in ${is_tmp_list[@]}; do
                    msg "\t\t$v"
                done
                msg "$is_err_tips\n"
                exit 1
            }
            ss_method=$is_tmp_use_type
            header_type=$is_tmp_use_type
        fi
        if [[ $is_dynamic_port && $is_use_dynamic_port_start ]]; then
            get dynamic-port-test
        fi
        [[ $is_use_pass ]] && ss_password=$is_use_pass
        [[ $is_use_host ]] && host=$is_use_host
        [[ $is_use_door_addr ]] && door_addr=$is_use_door_addr
        [[ $is_use_servername ]] && is_servername=$is_use_servername
        [[ $is_use_socks_user ]] && is_socks_user=$is_use_socks_user
        [[ $is_use_socks_pass ]] && is_socks_pass=$is_use_socks_pass
    fi

    if [[ $is_use_tls ]]; then
        if [[ ! $is_no_auto_tls && ! $is_caddy && ! $is_gen ]]; then
            # test auto tls
            [[ $(is_test port_used 80) || $(is_test port_used 443) ]] && {
                get_port
                is_http_port=$tmp_port
                get_port
                is_https_port=$tmp_port
                # MODIFICADO: Traduzido e link atualizado
                warn "Porta (80 ou 443) já está em uso, considere usar no-auto-tls"
                msg "\e[41m Ajuda (no-auto-tls)\e[0m: $(msg_ul https://github.com/PhoenixxZ2023/xray2026/wiki)\n"
                msg "\n Caddy usará portas não-padrão para TLS automático, HTTP:$is_http_port HTTPS:$is_https_port\n"
                msg "Tem certeza que deseja continuar???"
                pause
            }
            is_install_caddy=1
        fi
        # set host
        # MODIFICADO: Traduzido
        [[ ! $host ]] && ask string host "Por favor, digite seu domínio:"
        # test host dns
        get host-test
    else
        # for main menu start, dont auto create args
        if [[ $is_main_start ]]; then

            # set port
            # MODIFICADO: Traduzido
            [[ ! $port ]] && ask string port "Por favor, digite a porta:"

            case ${is_new_protocol,,} in
            *tcp* | *kcp* | *quic*)
                [[ ! $header_type ]] && ask set_header_type
                ;;
            socks)
                # set user
                # MODIFICADO: Traduzido
                [[ ! $is_socks_user ]] && ask string is_socks_user "Defina um nome de usuário:"
                # set password
                [[ ! $is_socks_pass ]] && ask string is_socks_pass "Defina uma senha:"
                ;;
            shadowsocks)
                # set method
                [[ ! $ss_method ]] && ask set_ss_method
                # set password
                # MODIFICADO: Traduzido
                [[ ! $ss_password ]] && ask string ss_password "Defina uma senha:"
                ;;
            esac
            # set dynamic port
            [[ $is_dynamic_port && ! $is_dynamic_port_range ]] && {
                # MODIFICADO: Traduzido
                ask string is_use_dynamic_port_start "Digite a porta dinâmica inicial:"
                ask string is_use_dynamic_port_end "Digite a porta dinâmica final:"
                get dynamic-port-test
            }
        fi
    fi

    # Dokodemo-Door
    if [[ $is_new_protocol == 'Dokodemo-Door' ]]; then
        # set remote addr
        # MODIFICADO: Traduzido
        [[ ! $door_addr ]] && ask string door_addr "Digite o endereço de destino:"
        # set remote port
        [[ ! $door_port ]] && ask string door_port "Digite a porta de destino:"
    fi

    # Shadowsocks 2022
    if [[ $(grep 2022 <<<$ss_method) ]]; then
        # test ss2022 password
        [[ $ss_password ]] && {
            is_test_json=1
            create server Shadowsocks
            $is_core_bin -test <<<"$is_new_json" &>/dev/null
            if [[ $? != 0 ]]; then
                # MODIFICADO: Traduzido
                warn "Protocolo Shadowsocks ($ss_method) não suporta a senha ($(_red_bg $ss_password))\n\nVocê pode usar o comando: $(_green $is_core ss2022) para gerar uma senha suportada.\n\nO script criará uma senha válida automaticamente :)"
                ss_password=
                json_str=
            fi
            is_test_json=
        }

    fi

    # install caddy
    if [[ $is_install_caddy ]]; then
        get install-caddy
    fi

    # create json
    create server $is_new_protocol

    # show config info.
    info
}

# get config info
# or somes required args
get() {
    case $1 in
    addr)
        is_addr=$host
        [[ ! $is_addr ]] && {
            get_ip
            is_addr=$ip
            [[ $(grep ":" <<<$ip) ]] && is_addr="[$ip]"
        }
        ;;
    new)
        [[ ! $host ]] && get_ip
        [[ ! $port ]] && get_port && port=$tmp_port
        [[ ! $uuid ]] && get_uuid && uuid=$tmp_uuid
        ;;
    file)
        is_file_str=$2
        [[ ! $is_file_str ]] && is_file_str='.json$'
        readarray -t is_all_json <<<"$(ls $is_conf_dir | grep -E -i "$is_file_str" | sed '/dynamic-port-.*-link/d' | head -233)" # limit max 233 lines for show.
        # MODIFICADO: Traduzido
        [[ ! $is_all_json ]] && err "Não foi possível encontrar arquivos de configuração para: $2"
        [[ ${#is_all_json[@]} -eq 1 ]] && is_config_file=$is_all_json && is_auto_get_config=1
        [[ ! $is_config_file ]] && {
            [[ $is_dont_auto_exit ]] && return
            ask get_config_file
        }
        ;;
    info)
        get file $2
        if [[ $is_config_file ]]; then
            is_json_str=$(cat $is_conf_dir/"$is_config_file")
            # MODIFICADO: Traduzido
            is_json_data_base=$(jq '.inbounds[0]|.protocol,.port,(.settings|(.clients[0]|.id,.password),.method,.password,.address,.port,.detour.to,(.accounts[0]|.user,.pass))' <<<$is_json_str)
            [[ $? != 0 ]] && err "Não é possível ler o arquivo: $is_config_file"
            is_json_data_more=$(jq '.inbounds[0]|.streamSettings|.network,.tcpSettings.header.type,(.kcpSettings|.seed,.header.type),.quicSettings.header.type,.wsSettings.path,.httpSettings.path,.grpcSettings.serviceName,.xhttpSettings.path' <<<$is_json_str)
            is_json_data_host=$(jq '.inbounds[0]|.streamSettings|.grpc_host,.wsSettings.headers.Host,.httpSettings.host[0],.xhttpSettings.host' <<<$is_json_str)
            is_json_data_reality=$(jq '.inbounds[0]|.streamSettings|.security,(.realitySettings|.serverNames[0],.publicKey,.privateKey)' <<<$is_json_str)
            is_up_var_set=(null is_protocol port uuid trojan_password ss_method ss_password door_addr door_port is_dynamic_port is_socks_user is_socks_pass net tcp_type kcp_seed kcp_type quic_type ws_path h2_path grpc_path xhttp_path grpc_host ws_host h2_host xhttp_host is_reality is_servername is_public_key is_private_key)
            [[ $is_debug ]] && msg "\n------------- debug: $is_config_file -------------"
            i=0
            for v in $(sed 's/""/null/g;s/"//g' <<<"$is_json_data_base $is_json_data_more $is_json_data_host $is_json_data_reality"); do
                ((i++))
                [[ $is_debug ]] && msg "$i-${is_up_var_set[$i]}: $v"
                export ${is_up_var_set[$i]}="${v}"
            done
            for v in ${is_up_var_set[@]}; do
                [[ ${!v} == 'null' ]] && unset $v
            done

            # splithttp
            if [[ $net == 'splithttp' ]]; then
                net=xhttp
                xhttp_path=$(jq -r '.inbounds[0]|.streamSettings|.splithttpSettings.path' <<<$is_json_str)
                xhttp_host=$(jq -r '.inbounds[0]|.streamSettings|.splithttpSettings.host' <<<$is_json_str)
            fi
            path="${ws_path}${h2_path}${grpc_path}${xhttp_path}"
            host="${ws_host}${h2_host}${grpc_host}${xhttp_host}"
            header_type="${tcp_type}${kcp_type}${quic_type}"
            if [[ $is_reality == 'reality' ]]; then
                net=reality
            else
                is_reality=
            fi
            [[ ! $kcp_seed ]] && is_no_kcp_seed=1
            is_config_name=$is_config_file
            if [[ $is_dynamic_port ]]; then
                is_dynamic_port_file=$is_conf_dir/$is_dynamic_port
                is_dynamic_port_range=$(jq -r '.inbounds[0].port' $is_dynamic_port_file)
                # MODIFICADO: Traduzido
                [[ $? != 0 ]] && err "Não é possível ler o arquivo de porta dinâmica: $is_dynamic_port"
            fi
            if [[ $is_caddy && $host && -f $is_caddy_conf/$host.conf ]]; then
                is_tmp_https_port=$(grep -E -o "$host:[1-9][0-9]?+" $is_caddy_conf/$host.conf | sed s/.*://)
            fi
            if [[ $host && ! -f $is_caddy_conf/$host.conf ]]; then
                is_no_auto_tls=1
            fi
            [[ $is_tmp_https_port ]] && is_https_port=$is_tmp_https_port
            [[ $is_client && $host ]] && port=$is_https_port
            get protocol $is_protocol-$net
        fi
        ;;
    protocol)
        get addr # get host or server ip
        is_lower=${2,,}
        net=
        case $is_lower in
        vmess*)
            is_protocol=vmess
            if [[ $is_dynamic_port ]]; then
                is_server_id_json='settings:{clients:[{id:"'$uuid'"}],detour:{to:"'$is_config_name-link.json'"}}'
            else
                is_server_id_json='settings:{clients:[{id:"'$uuid'"}]}'
            fi
            is_client_id_json='settings:{vnext:[{address:"'$is_addr'",port:'"$port"',users:[{id:"'$uuid'"}]}]}'
            ;;
        vless*)
            is_protocol=vless
            is_server_id_json='settings:{clients:[{id:"'$uuid'"}],decryption:"none"}'
            is_client_id_json='settings:{vnext:[{address:"'$is_addr'",port:'"$port"',users:[{id:"'$uuid'",encryption:"none"}]}]}'
            if [[ $is_reality ]]; then
                is_server_id_json='settings:{clients:[{id:"'$uuid'",flow:"xtls-rprx-vision"}],decryption:"none"}'
                is_client_id_json='settings:{vnext:[{address:"'$is_addr'",port:'"$port"',users:[{id:"'$uuid'",encryption:"none",flow:"xtls-rprx-vision"}]}]}'
            fi
            ;;
        trojan*)
            is_protocol=trojan
            [[ ! $trojan_password ]] && trojan_password=$uuid
            is_server_id_json='settings:{clients:[{password:"'$trojan_password'"}]}'
            is_client_id_json='settings:{servers:[{address:"'$is_addr'",port:'"$port"',password:"'$trojan_password'"}]}'
            is_trojan=1
            ;;
        shadowsocks*)
            net=ss
            is_protocol=shadowsocks
            [[ ! $ss_method ]] && ss_method=$is_random_ss_method
            [[ ! $ss_password ]] && {
                ss_password=$uuid
                [[ $(grep 2022 <<<$ss_method) ]] && ss_password=$(get ss2022)
            }
            is_client_id_json='settings:{servers:[{address:"'$is_addr'",port:'"$port"',method:"'$ss_method'",password:"'$ss_password'",}]}'
            json_str='settings:{method:"'$ss_method'",password:"'$ss_password'",network:"tcp,udp"}'
            ;;
        dokodemo-door*)
            net=door
            is_protocol=dokodemo-door
            json_str='settings:{port:'"$door_port"',address:"'$door_addr'",network:"tcp,udp"}'
            ;;
        *http*)
            net=http
            is_protocol=http
            json_str='settings:{"timeout": 233}'
            ;;
        *socks*)
            net=socks
            is_protocol=socks
            [[ ! $is_socks_user ]] && is_socks_user=xray2026
            [[ ! $is_socks_pass ]] && is_socks_pass=$uuid
            json_str='settings:{auth:"password",accounts:[{user:"'$is_socks_user'",pass:"'$is_socks_pass'"}],udp:true,ip:"0.0.0.0"}'
            ;;
        *)
            # MODIFICADO: Traduzido
            err "Protocolo não reconhecido: $is_config_file"
            ;;
        esac
        [[ $net ]] && return # if net exist, dont need more json args
        case $is_lower in
        *tcp* | *reality*)
            net=tcp
            [[ ! $header_type ]] && header_type=none
            is_stream='tcpSettings:{header:{type:"'$header_type'"}}'
            if [[ $is_reality ]]; then
                [[ ! $is_servername ]] && is_servername=$is_random_servername
                [[ ! $is_private_key ]] && get_pbk
                is_stream='security:"reality",realitySettings:{dest:"'${is_servername}\:443'",serverNames:["'${is_servername}'",""],publicKey:"'$is_public_key'",privateKey:"'$is_private_key'",shortIds:[""]}'
                if [[ $is_client ]]; then
                    is_stream='security:"reality",realitySettings:{serverName:"'${is_servername}'",fingerprint:"chrome",publicKey:"'$is_public_key'",shortId:"",spiderX:"/"}'
                fi
            fi
            ;;
        *kcp* | *mkcp)
            net=kcp
            [[ ! $header_type ]] && header_type=$is_random_header_type
            [[ ! $is_no_kcp_seed && ! $kcp_seed ]] && kcp_seed=$uuid
            is_stream='kcpSettings:{seed:"'$kcp_seed'",header:{type:"'$header_type'"}}'
            ;;
        *quic*)
            net=quic
            [[ ! $header_type ]] && header_type=$is_random_header_type
            is_stream='quicSettings:{header:{type:"'$header_type'"}}'
            ;;
        *ws* | *websocket)
            net=ws
            [[ ! $path ]] && path="/$uuid"
            is_stream='wsSettings:{path:"'$path'",headers:{Host:"'$host'"}}'
            ;;
        *grpc* | *gun)
            net=grpc
            [[ ! $path ]] && path="$uuid"
            [[ $path ]] && path=$(sed 's#/##g' <<<$path)
            is_stream='grpc_host:"'$host'",grpcSettings:{serviceName:"'$path'"}'
            ;;
        *h2*)
            net=h2
            [[ ! $path ]] && path="/$uuid"
            is_stream='httpSettings:{path:"'$path'",host:["'$host'"]}'
            ;;
        *xhttp*)
            net=xhttp
            [[ ! $path ]] && path="/$uuid"
            is_stream='xhttpSettings:{host:"'$host'",path:"'$path'"}'
            ;;
        *)
            # MODIFICADO: Traduzido
            err "Protocolo de transporte não reconhecido: $is_config_file"
            ;;
        esac
        is_stream="streamSettings:{network:\"$net\",$is_stream}"
        json_str="$is_server_id_json,$is_stream"
        ;;
    dynamic-port) # create random dynamic port
        if [[ $port -ge 60000 ]]; then
            is_dynamic_port_end=$(shuf -i $(($port - 2333))-$port -n1)
            is_dynamic_port_start=$(shuf -i $(($is_dynamic_port_end - 2333))-$is_dynamic_port_end -n1)
        else
            is_dynamic_port_start=$(shuf -i $port-$(($port + 2333)) -n1)
            is_dynamic_port_end=$(shuf -i $is_dynamic_port_start-$(($is_dynamic_port_start + 2333)) -n1)
        fi
        is_dynamic_port_range="$is_dynamic_port_start-$is_dynamic_port_end"
        ;;
    dynamic-port-test) # test dynamic port
        [[ ! $(is_test port ${is_use_dynamic_port_start}) || ! $(is_test port ${is_use_dynamic_port_end}) ]] && {
            # MODIFICADO: Traduzido
            err "Não foi possível processar a faixa de porta dinâmica ($is_use_dynamic_port_start-$is_use_dynamic_port_end)."
        }
        [[ $(is_test port_used $is_use_dynamic_port_start) ]] && {
            # MODIFICADO: Traduzido
            err "Porta dinâmica ($is_use_dynamic_port_start-$is_use_dynamic_port_end), mas a porta ($is_use_dynamic_port_start) não está disponível."
        }
        [[ $(is_test port_used $is_use_dynamic_port_end) ]] && {
            # MODIFICADO: Traduzido
            err "Porta dinâmica ($is_use_dynamic_port_start-$is_use_dynamic_port_end), mas a porta ($is_use_dynamic_port_end) não está disponível."
        }
        [[ $is_use_dynamic_port_end -le $is_use_dynamic_port_start ]] && {
            # MODIFICADO: Traduzido
            err "Não foi possível processar a faixa de porta dinâmica ($is_use_dynamic_port_start-$is_use_dynamic_port_end)."
        }
        [[ $is_use_dynamic_port_start == $port || $is_use_dynamic_port_end == $port ]] && {
            # MODIFICADO: Traduzido
            err "Faixa de porta dinâmica ($is_use_dynamic_port_start-$is_use_dynamic_port_end) conflita com a porta principal ($port)."
        }
        is_dynamic_port_range="$is_use_dynamic_port_start-$is_use_dynamic_port_end"
        ;;
    host-test) # test host dns record; for auto *tls required.
        [[ $is_no_auto_tls || $is_gen ]] && return
        get_ip
        get ping
        if [[ ! $(grep $ip <<<$is_host_dns) ]]; then
            # MODIFICADO: Traduzido
            msg "\nPor favor, aponte o DNS de ($(_red_bg $host)) para ($(_red_bg $ip))"
            msg "\nSe estiver usando Cloudflare, no DNS; desligue (Proxy status), deixe em (DNS only / Apenas DNS)"
            ask string s "Eu já fiz o apontamento [s]:"
            get ping
            if [[ ! $(grep $ip <<<$is_host_dns) ]]; then
                _cyan "\nResultado do teste: $is_host_dns"
                err "Domínio ($host) não está apontando para ($ip)"
            fi
        fi
        ;;
    ssss | ss2022)
        if [[ $(grep 128 <<<$ss_method) ]]; then
            openssl rand -base64 16
        else
            openssl rand -base64 32
        fi
        # MODIFICADO: Traduzido
        [[ $? != 0 ]] && err "Não foi possível gerar a senha do Shadowsocks 2022. Por favor, instale o openssl."
        ;;
    ping)
        is_dns_type="a"
        [[ $(grep ":" <<<$ip) ]] && is_dns_type="aaaa"
        is_host_dns=$(_wget -qO- --header="accept: application/dns-json" "https://one.one.one.one/dns-query?name=$host&type=$is_dns_type")
        ;;
    log | logerr)
        # MODIFICADO: Traduzido
        msg "\n Lembrete: Pressione $(_green Ctrl + C) para sair\n"
        [[ $1 == 'log' ]] && tail -f $is_log_dir/access.log
        [[ $1 == 'logerr' ]] && tail -f $is_log_dir/error.log
        ;;
    install-caddy)
        # MODIFICADO: Traduzido
        _green "\nInstalando Caddy para TLS automático.\n"
        load download.sh
        download caddy
        load systemd.sh
        install_service caddy &>/dev/null
        is_caddy=1
        _green "Caddy instalado com sucesso.\n"
        ;;
    reinstall)
        is_install_sh=$(cat $is_sh_dir/install.sh)
        uninstall
        bash <<<$is_install_sh
        ;;
    test-run)
        systemctl list-units --full -all &>/dev/null
        [[ $? != 0 ]] && {
            # MODIFICADO: Traduzido
            _yellow "\nNão é possível executar o teste, verifique o status do systemctl.\n"
            return
        }
        is_no_manage_msg=1
        if [[ ! $(pgrep -f $is_core_bin) ]]; then
            # MODIFICADO: Traduzido
            _yellow "\nTeste de diagnóstico $is_core_name ..\n"
            manage start &>/dev/null
            if [[ $is_run_fail == $is_core ]]; then
                _red "$is_core_name informação de falha:"
                $is_core_bin run -c $is_config_json -confdir $is_conf_dir
            else
                _green "\nTeste OK, $is_core_name iniciado ..\n"
            fi
        else
            _green "\n$is_core_name já está rodando, pulando teste\n"
        fi
        if [[ $is_caddy ]]; then
            if [[ ! $(pgrep -f $is_caddy_bin) ]]; then
                _yellow "\nTeste de diagnóstico Caddy ..\n"
                manage start caddy &>/dev/null
                if [[ $is_run_fail == 'caddy' ]]; then
                    _red "Caddy informação de falha:"
                    $is_caddy_bin run --config $is_caddyfile
                else
                    _green "\nTeste OK, Caddy iniciado ..\n"
                fi
            else
                _green "\nCaddy já está rodando, pulando teste\n"
            fi
        fi
        ;;
    esac
}

# show info
info() {
    if [[ ! $is_protocol ]]; then
        get info $1
    fi
    is_color=44
    case $net in
    tcp | kcp | quic)
        is_can_change=(0 1 5 7)
        is_info_show=(0 1 2 3 4 5)
        is_vmess_url=$(jq -c '{v:2,ps:"'xray2026-${net}-$is_addr'",add:"'$is_addr'",port:"'$port'",id:"'$uuid'",aid:"0",net:"'$net'",type:"'$header_type'",path:"'$kcp_seed'"}' <<<{})
        is_url=
