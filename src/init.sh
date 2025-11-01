#!/bin/bash

# ============================================================================
# Xray2026 - Módulo de Inicialização (init.sh)
# Carrega todos os módulos necessários e executa o core
# Autor: PhoenixxZ2023
# ============================================================================

# Diretório base dos scripts
is_sh_dir="/etc/xray/sh"
is_src_dir="$is_sh_dir/src"

# Função para carregar módulos
load_module() {
    local module=$1
    local module_path="$is_src_dir/$module"
    
    if [[ -f $module_path ]]; then
        . $module_path
    else
        echo "ERRO: Módulo não encontrado: $module"
        echo "Caminho esperado: $module_path"
        echo ""
        echo "Estrutura esperada em $is_src_dir:"
        echo "  • core.sh (principal)"
        echo "  • systemd.sh"
        echo "  • help.sh"
        echo "  • download.sh"
        echo "  • caddy.sh"
        echo "  • dns.sh"
        echo "  • log.sh"
        echo "  • bbr.sh"
        echo "  • user-manager.sh"
        echo "  • traffic-monitor.sh"
        echo "  • expiration-checker.sh"
        echo ""
        echo "Verifique a instalação e tente novamente."
        exit 1
    fi
}

# Verificar se diretório src existe
if [[ ! -d $is_src_dir ]]; then
    echo "ERRO: Diretório de scripts não encontrado: $is_src_dir"
    echo "Reinstale o Xray2026"
    exit 1
fi

# Carregar módulo principal (core.sh)
# Este módulo contém todas as funções principais do sistema
load_module "core.sh"

# Executar função main do core.sh com os argumentos passados
# A função main() está definida dentro do core.sh
main "$args"

# ========== FIM DO INIT.SH ==========
