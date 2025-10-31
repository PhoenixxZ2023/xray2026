#!/bin/bash

# Xray2026 - Gerenciador de Logs
# Autor: PhoenixxZ2023
# GitHub: https://github.com/PhoenixxZ2023/xray2026
# Baseado no script original de 233boy

is_log_level_list=(
    debug
    info
    warning
    error
    none
    del
)

log_set() {
    if [[ $2 ]]; then
        for v in ${is_log_level_list[@]}; do
            [[ $(grep -E -i "^${2,,}$" <<<$v) ]] && is_log_level_use=$v && break
        done
        [[ ! $is_log_level_use ]] && {
            err "Não foi possível reconhecer o parâmetro log: $@ \nUse $is_core log [${is_log_level_list[@]}] para configurar.\nObservação: 'del' apenas remove temporariamente os arquivos de log; 'none' desabilita completamente a geração de logs."
        }
        case $is_log_level_use in
        del)
            rm -rf $is_log_dir/*.log
            msg "\n $(_green Arquivos de log removidos temporariamente. Para desabilitar completamente a geração de logs, use: $is_core log none)\n"
            ;;
        none)
            rm -rf $is_log_dir/*.log
            cat <<<$(jq '.log={"loglevel":"none"}' $is_config_json) >$is_config_json
            ;;
        *)
            cat <<<$(jq '.log={access:"/var/log/'$is_core'/access.log",error:"/var/log/'$is_core'/error.log",loglevel:"'$is_log_level_use'"}' $is_config_json) >$is_config_json
            ;;
        esac

        manage restart &
        [[ $2 != 'del' ]] && msg "\nNível de log atualizado para: $(_green $is_log_level_use)\n"
    else
        case $1 in
        log)
            if [[ -f $is_log_dir/access.log ]]; then
                msg "\n Dica: Pressione $(_green Ctrl + C) para sair\n"
                tail -f $is_log_dir/access.log
            else
                err "Arquivo de log não encontrado."
            fi
            ;;
        *)
            if [[ -f $is_log_dir/error.log ]]; then
                msg "\n Dica: Pressione $(_green Ctrl + C) para sair\n"
                tail -f $is_log_dir/error.log
            else
                err "Arquivo de log não encontrado."
            fi
            ;;
        esac

    fi
}

# Função auxiliar para visualizar logs
view_log() {
    local log_type=${1:-access}
    local lines=${2:-50}
    
    local log_file="$is_log_dir/${log_type}.log"
    
    if [[ ! -f $log_file ]]; then
        err "Arquivo de log não encontrado: $log_file"
        return 1
    fi
    
    echo ""
    echo "═══════════════════════════════════════"
    echo "  LOG: $log_type (Últimas $lines linhas)"
    echo "═══════════════════════════════════════"
    echo ""
    
    tail -n $lines $log_file
    
    echo ""
    echo "═══════════════════════════════════════"
    echo ""
}

# Função para visualização em tempo real
view_log_realtime() {
    local log_type=${1:-access}
    
    local log_file="$is_log_dir/${log_type}.log"
    
    if [[ ! -f $log_file ]]; then
        err "Arquivo de log não encontrado: $log_file"
        return 1
    fi
    
    msg "\n═══════════════════════════════════════"
    msg "  LOG EM TEMPO REAL: $log_type"
    msg "  Pressione $(_green Ctrl + C) para sair"
    msg "═══════════════════════════════════════\n"
    
    tail -f $log_file
}

# Função para limpar logs
clear_logs() {
    if [[ -d $is_log_dir ]]; then
        rm -rf $is_log_dir/*.log
        _green "✓ Logs removidos com sucesso"
    else
        warn "Diretório de logs não encontrado"
    fi
}

# Função para listar informações dos logs
show_log_info() {
    echo ""
    echo "═══════════════════════════════════════"
    echo "  INFORMAÇÕES DOS LOGS"
    echo "═══════════════════════════════════════"
    echo ""
    
    if [[ -d $is_log_dir ]]; then
        echo "Diretório de logs: $is_log_dir"
        echo ""
        
        if [[ -f $is_log_dir/access.log ]]; then
            local access_size=$(du -h $is_log_dir/access.log | cut -f1)
            local access_lines=$(wc -l < $is_log_dir/access.log)
            echo "  access.log:"
            echo "    Tamanho: $access_size"
            echo "    Linhas: $access_lines"
        else
            echo "  access.log: Não encontrado"
        fi
        
        echo ""
        
        if [[ -f $is_log_dir/error.log ]]; then
            local error_size=$(du -h $is_log_dir/error.log | cut -f1)
            local error_lines=$(wc -l < $is_log_dir/error.log)
            echo "  error.log:"
            echo "    Tamanho: $error_size"
            echo "    Linhas: $error_lines"
        else
            echo "  error.log: Não encontrado"
        fi
    else
        echo "Diretório de logs não encontrado"
    fi
    
    echo ""
    echo "═══════════════════════════════════════"
    echo ""
}

# Ajuda para o módulo de logs
show_log_help() {
    cat <<EOF

═══════════════════════════════════════════════════════════════════
  Gerenciador de Logs - Xray2026
═══════════════════════════════════════════════════════════════════

Uso: xray log [comando] [opções]

COMANDOS:
  log                         Ver log de acesso em tempo real
  logerr                      Ver log de erros em tempo real
  log [nível]                 Definir nível de log
  view [tipo] [linhas]        Ver últimas N linhas do log
  realtime [tipo]             Ver log em tempo real
  clear                       Limpar todos os logs
  info                        Mostrar informações dos logs

NÍVEIS DE LOG:
  debug                       Modo debug (muito detalhado)
  info                        Informações gerais
  warning                     Apenas avisos e erros
  error                       Apenas erros
  none                        Desabilitar logs
  del                         Deletar logs temporariamente

TIPOS DE LOG:
  access                      Log de acessos
  error                       Log de erros

EXEMPLOS:
  xray log                    Ver log de acesso
  xray logerr                 Ver log de erros
  xray log debug              Definir nível debug
  xray log none               Desabilitar logs
  xray log del                Deletar logs
  xray log view access 100    Ver últimas 100 linhas do access
  xray log clear              Limpar todos os logs
  xray log info               Ver informações dos logs

═══════════════════════════════════════════════════════════════════

EOF
}
