#!/bin/bash

# ============================================================================
# Xray2026 - Script Principal de Execução
# Autor: PhoenixxZ2023
# Versão: 2.0 (v1.31)
# ============================================================================

# Versão do script
args=$@
is_sh_ver=v1.31

# Carregar módulo de inicialização
if [[ -f /etc/xray/sh/src/init.sh ]]; then
    . /etc/xray/sh/src/init.sh
else
    echo "ERRO: Arquivo init.sh não encontrado em /etc/xray/sh/src/"
    echo "Reinstale o Xray2026"
    exit 1
fi

# ========== FIM DO XRAY.SH ==========
