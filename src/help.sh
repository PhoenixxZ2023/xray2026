#!/bin/bash

# Xray2026 - Sistema de Ajuda
# Autor: PhoenixxZ2023
# GitHub: https://github.com/PhoenixxZ2023/xray2026
# Baseado no script original de 233boy

show_help() {
    cat <<EOF

═══════════════════════════════════════════════════════════════════
  Xray2026 Script $is_sh_ver by PhoenixxZ2023
═══════════════════════════════════════════════════════════════════

Uso: xray [opções]... [argumentos]...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 BÁSICO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  v, version               Exibe a versão atual
  ip                       Retorna o endereço IP do servidor
  pbk                      Equivalente a xray x25519
  get-port                 Retorna uma porta disponível
  ss2022                   Retorna uma senha para Shadowsocks 2022

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GERENCIAMENTO DE USUÁRIOS (NOVO)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  add-user <nome> <dias> [protocolo]    Adicionar usuário
  list-users                             Listar todos os usuários
  view-user <nome>                       Ver detalhes do usuário
  del-user <nome>                        Deletar usuário
  renew-user <nome> <dias>               Renovar usuário (adicionar dias)
  
  Exemplos:
    xray add-user joao 30 vless
    xray list-users
    xray renew-user joao 15

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 MONITORAMENTO DE TRÁFEGO (NOVO)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  traffic                                Ver tráfego de todos
  traffic-user <nome>                    Ver tráfego de um usuário
  traffic-update                         Atualizar estatísticas
  traffic-monitor                        Monitoramento em tempo real
  
  Exemplos:
    xray traffic
    xray traffic-user joao
    xray monitor

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 VERIFICAÇÃO DE VENCIMENTOS (NOVO)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  check-expired                          Verificar usuários expirados
  list-expired                           Listar usuários expirados
  expiring-soon [dias]                   Listar próximos a expirar (padrão: 7)
  clean-expired [dias]                   Limpar expirados antigos (padrão: 30)
  reactivate-user <nome> <dias>          Reativar usuário expirado
  setup-auto-check                       Configurar verificação automática
  
  Exemplos:
    xray check-expired
    xray expiring-soon 3
    xray reactivate-user joao 30

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GERAL
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  a, add [protocolo] [args... | auto]   Adicionar configuração
  c, change [nome] [opção] [args...]     Alterar configuração
  d, del [nome]                          Deletar configuração
  i, info [nome]                         Ver informações da configuração
  qr [nome]                              Informações em QR Code
  url [nome]                             Informações em URL
  log                                    Ver log
  logerr                                 Ver log de erros

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 ALTERAÇÕES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  dp, dynamicport [nome] [início] [fim]  Alterar porta dinâmica
  full [nome] [...]                      Alterar múltiplos parâmetros
  id [nome] [uuid | auto]                Alterar UUID
  host [nome] [domínio]                  Alterar domínio
  port [nome] [porta | auto]             Alterar porta
  path [nome] [caminho | auto]           Alterar caminho
  passwd [nome] [senha | auto]           Alterar senha
  key [nome] [chave_privada | auto]      Alterar chave
  type [nome] [tipo | auto]              Alterar tipo de disfarce
  method [nome] [método | auto]          Alterar método de criptografia
  sni [nome] [ip | domínio]              Alterar serverName
  seed [nome] [seed | auto]              Alterar mKCP seed
  new [nome] [...]                       Alterar protocolo
  web [nome] [domínio]                   Alterar site de disfarce

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 AVANÇADO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  dns [...]                              Configurar DNS
  dd, ddel [nome...]                     Deletar múltiplas configurações
  fix [nome]                             Corrigir uma configuração
  fix-all                                Corrigir todas as configurações
  fix-caddyfile                          Corrigir Caddyfile
  fix-config.json                        Corrigir config.json

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 GERENCIAMENTO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  un, uninstall                          Desinstalar
  u, update [core | sh | dat | caddy]    Atualizar componentes
  U, update.sh                           Atualizar script
  s, status                              Status de execução
  start, stop, restart [caddy]           Iniciar, parar, reiniciar
  t, test                                Testar execução
  reinstall                              Reinstalar script

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 TESTES E DEBUG
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  client [nome]                          Exibe JSON para o cliente
  debug [nome]                           Exibe informações de debug
  gen [...]                              Gera JSON sem criar arquivos
  genc [nome]                            Exibe JSON do cliente
  no-auto-tls [...]                      Desabilita TLS automático
  xapi [...]                             Equivalente a xray api

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 OUTROS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  bbr                                    Ativar BBR (se suportado)
  bin [...]                              Executar comandos Xray
  api, x25519, tls, run, uuid [...]      Comandos compatíveis com Xray
  h, help                                Exibir esta ajuda

═══════════════════════════════════════════════════════════════════
  CUIDADO
═══════════════════════════════════════════════════════════════════

  Ao usar 'del' e 'ddel', as configurações serão deletadas diretamente
  sem confirmação. Use com cuidado!

═══════════════════════════════════════════════════════════════════
  LINKS ÚTEIS
═══════════════════════════════════════════════════════════════════

  Reportar problemas: https://github.com/PhoenixxZ2023/xray2026/issues
  Documentação:       https://github.com/PhoenixxZ2023/xray2026
  Telegram:           [Seu canal/grupo]

═══════════════════════════════════════════════════════════════════

EOF
}

about() {
    cat <<EOF

═══════════════════════════════════════════════════════════════════
  Sobre o Xray2026
═══════════════════════════════════════════════════════════════════

  Nome:           Xray2026
  Versão:         $is_sh_ver
  Autor:          PhoenixxZ2023
  Baseado em:     233boy/Xray
  
  Xray Core:      $is_core_ver
  Status:         $is_core_status

───────────────────────────────────────────────────────────────────
  NOVIDADES DA VERSÃO 2.0
───────────────────────────────────────────────────────────────────

  ✅ Gerenciamento completo de usuários
     - Adicionar/Deletar/Listar usuários
     - Sistema de data de vencimento
     - Geração automática de UUID
     - Links VLESS com QR Code

  ✅ Monitoramento de tráfego em tempo real
     - Estatísticas via API Stats do Xray
     - Visualização por usuário
     - Exportação de relatórios
     - Monitoramento contínuo

  ✅ Verificação automática de vencimento
     - Desativação automática de expirados
     - Avisos de vencimento próximo
     - Limpeza de usuários antigos
     - Cron job automatizado

  ✅ Interface totalmente em português
     - Tradução completa de menus
     - Mensagens claras e intuitivas
     - Documentação em PT-BR

───────────────────────────────────────────────────────────────────
  PROTOCOLOS SUPORTADOS
───────────────────────────────────────────────────────────────────

  • VLESS-REALITY (recomendado)
  • VLESS-WS-TLS / gRPC / XHTTP
  • VMess-TCP / mKCP / WS / gRPC
  • Trojan-WS-TLS / gRPC
  • Shadowsocks 2022
  • Socks / Dokodemo-Door

───────────────────────────────────────────────────────────────────
  ESTRUTURA DE ARQUIVOS
───────────────────────────────────────────────────────────────────

  Diretório principal:  /etc/xray
  Scripts:              /etc/xray/sh
  Core:                 /etc/xray/bin
  Configurações:        /etc/xray/conf
  Usuários:             /etc/xray/users
  Logs:                 /var/log/xray

───────────────────────────────────────────────────────────────────
  COMANDOS RÁPIDOS
───────────────────────────────────────────────────────────────────

  xray                    - Menu principal
  xray add-user           - Adicionar usuário
  xray list-users         - Listar usuários
  xray traffic            - Ver tráfego
  xray check-expired      - Verificar expirados
  xray help               - Ajuda completa

───────────────────────────────────────────────────────────────────
  SUPORTE
───────────────────────────────────────────────────────────────────

  GitHub:     https://github.com/PhoenixxZ2023/xray2026
  Issues:     https://github.com/PhoenixxZ2023/xray2026/issues
  Wiki:       https://github.com/PhoenixxZ2023/xray2026/wiki

───────────────────────────────────────────────────────────────────
  LICENÇA
───────────────────────────────────────────────────────────────────

  GPL-3.0 License
  Copyright (c) 2025 PhoenixxZ2023
  
  Este projeto é baseado no trabalho de 233boy
  Agradecimentos especiais ao XTLS/Xray-core

═══════════════════════════════════════════════════════════════════
  Desenvolvido com ❤️ por PhoenixxZ2023
═══════════════════════════════════════════════════════════════════

EOF
}

# Funções auxiliares para exibir informações específicas

show_version() {
    echo ""
    echo "Xray2026 Script: $is_sh_ver"
    echo "Xray Core: $is_core_ver"
    echo "Autor: PhoenixxZ2023"
    echo "GitHub: https://github.com/PhoenixxZ2023/xray2026"
    echo ""
}

show_ip() {
    get_ip
    echo ""
    echo "═══════════════════════════════════════"
    echo "  IP DO SERVIDOR"
    echo "═══════════════════════════════════════"
    echo "  IPv4: $ip"
    echo "═══════════════════════════════════════"
    echo ""
}

show_status() {
    echo ""
    echo "═══════════════════════════════════════"
    echo "  STATUS DO SISTEMA"
    echo "═══════════════════════════════════════"
    echo "  Xray Core:    $is_core_status"
    [[ $is_caddy ]] && echo "  Caddy:        $is_caddy_status"
    echo ""
    echo "  Xray Version: $is_core_ver"
    [[ $is_caddy ]] && echo "  Caddy Version: $is_caddy_ver"
    echo "═══════════════════════════════════════"
    echo ""
}

# Atalhos de comando
case "$1" in
    version | v)
        show_version
        ;;
    ip)
        show_ip
        ;;
    status | s)
        show_status
        ;;
    help | h | "")
        show_help
        ;;
    about)
        about
        ;;
esac
