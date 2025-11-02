# Xray2026 - Sistema Completo de Gerenciamento

**Autor:** PhoenixxZ2023  
**Repositório:** https://github.com/PhoenixxZ2023/xray2026  
**Versão:** 2.0

---

## 📋 Sobre o Projeto

Xray2026 é uma versão melhorada e traduzida do script Xray com funcionalidades avançadas de gerenciamento de usuários, monitoramento de tráfego e controle automático de vencimento.

### 🎯 Funcionalidades Principais

✅ **Gerenciamento Completo de Usuários**
- Adicionar usuários com UUID único
- Sistema de data de vencimento automático
- Renovação e alteração de validade
- Deletar e listar usuários

✅ **Monitoramento de Tráfego em Tempo Real**
- Estatísticas via API Stats do Xray
- Visualização por usuário
- Monitoramento em tempo real
- Exportação de relatórios

✅ **Verificação Automática de Vencimento**
- Desativação automática de usuários expirados
- Avisos de vencimento próximo
- Limpeza de usuários antigos
- Cron automático configurável

✅ **Geração de Links**
- Links VLESS-REALITY com QR Code
- Suporte a VMess e Trojan
- Links compartilháveis

✅ **Protocolos Suportados**
- VLESS-REALITY (recomendado)
- VLESS-WS-TLS / gRPC / XHTTP
- VMess-TCP / mKCP / WS / gRPC
- Trojan-WS-TLS / gRPC
- Shadowsocks 2022
- Socks / Dokodemo-Door

---

## 🚀 Instalação Rápida

```
bash <(curl -Ls https://raw.githubusercontent.com/PhoenixxZ2023/xray2026/main/install.sh)
```

### Opções de Instalação

```bash
# Com proxy
bash install.sh -p http://127.0.0.1:2333

# Versão específica do Xray
bash install.sh -v v1.8.1

# Instalação local
bash install.sh -l

# Arquivo customizado
bash install.sh -f /root/xray-linux-64.zip
```

---

## 📁 Estrutura de Arquivos

```
/etc/xray/
├── bin/
│   ├── xray                    # Binário do Xray-core
│   ├── geoip.dat
│   └── geosite.dat
├── conf/
│   └── [arquivos de config]    # Configurações dos protocolos
├── sh/
│   ├── xray.sh                 # Script principal
│   └── src/
│       ├── init.sh             # Inicialização
│       ├── core.sh             # Funções principais
│       ├── user-manager.sh     # ✨ Gerenciamento de usuários
│       ├── traffic-monitor.sh  # ✨ Monitoramento de tráfego
│       ├── expiration-checker.sh # ✨ Verificação de vencimento
│       ├── systemd.sh
│       ├── help.sh
│       ├── bbr.sh
│       ├── caddy.sh
│       ├── dns.sh
│       ├── download.sh
│       └── log.sh
├── users/
│   ├── users.json              # Banco de dados de usuários
│   ├── traffic.log             # Log de tráfego
│   └── expiration.log          # Log de expirações
└── config.json                 # Configuração principal do Xray

/var/log/xray/
└── [arquivos de log]

/usr/local/bin/xray             # Comando global
```

---

## 💻 Uso do Sistema

### Menu Principal

```bash
xray
```

Opções do menu:
1. **Gerenciar Usuários** - Submenu de gerenciamento
2. **Monitorar Tráfego** - Submenu de monitoramento
3. **Verificar Vencimentos** - Submenu de expiração
4. **Adicionar Configuração** - Criar novo protocolo
5. **Alterar Configuração** - Modificar existente
6. **Ver Configuração** - Ver info e links
7. **Deletar Configuração** - Remover protocolo
8. **Gerenciar Serviços** - Start/Stop/Restart
9. **Atualizar** - Atualizar Xray/Script
10. **Desinstalar** - Remover sistema
11. **Ajuda** - Ver documentação
12. **Outros** - BBR, Logs, DNS, etc.
13. **Sobre** - Informações do sistema

### Comandos Rápidos (CLI)

#### Gerenciamento de Usuários

```bash
# Adicionar usuário
xray add-user joao 30 vless
xray adduser maria 60 vmess

# Listar usuários
xray list-users
xray users

# Ver detalhes
xray view-user joao

# Deletar usuário
xray del-user joao
xray deluser maria

# Renovar (adicionar mais dias)
xray renew-user joao 30
```

#### Monitoramento de Tráfego

```bash
# Ver tráfego de todos
xray traffic
xray traf

# Ver tráfego de um usuário
xray traffic-user joao

# Atualizar estatísticas
xray traffic-update

# Monitoramento em tempo real
xray traffic-monitor
xray monitor
```

#### Verificação de Vencimentos

```bash
# Verificar expirados agora
xray check-expired
xray expired

# Listar expirados
xray list-expired

# Listar que expiram em breve
xray expiring-soon
xray expiring-soon 3

# Limpar expirados antigos
xray clean-expired
xray clean-expired 60

# Reativar usuário
xray reactivate-user joao 30

# Configurar verificação automática
xray setup-auto-check
```

#### Gerenciamento do Sistema

```bash
# Iniciar/Parar/Reiniciar
xray start
xray stop
xray restart
xray status

# Ver logs
xray log
xray logerr

# Atualizar
xray update

# Desinstalar
xray uninstall

# Ajuda
xray help
```

---

## 📖 Exemplos Práticos

### Exemplo 1: Criar novo usuário

```bash
# Via menu interativo
xray
> 1 (Gerenciar Usuários)
> 1 (Adicionar novo usuário)
> Nome: joao_silva
> Dias: 30
> Protocolo: vless

# Via CLI
xray add-user joao_silva 30 vless
```

**Resultado:**
```
✓ Usuário criado com sucesso!

═══════════════════════════════════════
  INFORMAÇÕES DO USUÁRIO
═══════════════════════════════════════
Nome: joao_silva
UUID: 4d6e0338-f67a-4187-bca3-902e232466bc
Protocolo: vless
Criado em: 31/10/2025 19:30:00
Expira em: 30/11/2025 19:30:00
Dias de validade: 30 dias
Status: Ativo
═══════════════════════════════════════
```

### Exemplo 2: Gerar link VLESS

```bash
xray
> 1 (Gerenciar Usuários)
> 7 (Gerar link VLESS com QR Code)
> Nome: joao_silva
```

**Resultado:**
```
═══════════════════════════════════════════════════════════════════
  LINK VLESS - joao_silva
═══════════════════════════════════════════════════════════════════

Link de Conexão:
vless://4d6e0338-f67a-4187-bca3-902e232466bc@SEU_IP:443?
encryption=none&flow=xtls-rprx-vision&security=reality&
sni=www.google.com&fp=chrome&type=tcp&headerType=none#joao_silva

QR Code:
[QR CODE AQUI]

═══════════════════════════════════════════════════════════════════
```

### Exemplo 3: Monitorar tráfego

```bash
xray traffic
```

**Resultado:**
```
═══════════════════════════════════════════════════════════════════
  ESTATÍSTICAS DE TRÁFEGO - Total de usuários: 5
═══════════════════════════════════════════════════════════════════

USUÁRIO              TRÁFEGO (MB)    STATUS          EXPIRA EM
───────────────────────────────────────────────────────────────────
joao_silva           1250.45         active          30/11/2025
maria_souza          890.23          active          15/12/2025
pedro_santos         2450.67         expired         10/10/2025
ana_lima             340.12          active          05/01/2026
carlos_rocha         1567.89         active          20/11/2025

═══════════════════════════════════════════════════════════════════
```

### Exemplo 4: Verificar vencimentos

```bash
xray expiring-soon 7
```

**Resultado:**
```
═══════════════════════════════════════════════════════════════════
  USUÁRIOS QUE EXPIRAM NOS PRÓXIMOS 7 DIAS
═══════════════════════════════════════════════════════════════════

USUÁRIO              DIAS RESTANTES  EXPIRA EM
───────────────────────────────────────────────────────────────────
joao_silva           3               30/11/2025
carlos_rocha         6               20/11/2025

═══════════════════════════════════════════════════════════════════
```

---

## ⚙️ Configuração Avançada

### Habilitar API Stats do Xray

```bash
xray
> 2 (Monitorar Tráfego)
> 8 (Habilitar API Stats do Xray)
```

Ou via CLI:
```bash
bash /etc/xray/sh/src/traffic-monitor.sh enable-api
```

### Configurar Verificação Automática de Vencimentos

```bash
xray setup-auto-check
```

Isso criará um cron job que verifica usuários expirados:
- Todos os dias às 00:00
- A cada 6 horas

### Exportar Relatório de Tráfego

```bash
xray
> 2 (Monitorar Tráfego)
> 7 (Exportar relatório)
```

Relatório salvo em: `/etc/xray/users/traffic_report_YYYYMMDD_HHMMSS.txt`

---

## 🔧 Configuração do Banco de Dados

O banco de dados de usuários está em: `/etc/xray/users/users.json`

### Estrutura do JSON

```json
[
  {
    "username": "joao_silva",
    "uuid": "4d6e0338-f67a-4187-bca3-902e232466bc",
    "protocol": "vless",
    "created_at": "1730409000",
    "expires_at": "1733087400",
    "expires_readable": "30/11/2025 19:30:00",
    "status": "active",
    "traffic_used": 1250.45,
    "last_connection": null
  }
]
```

---

## 🐛 Troubleshooting

### Problema: API Stats não funciona

**Solução:**
```bash
bash /etc/xray/sh/src/traffic-monitor.sh enable-api
systemctl restart xray
```

### Problema: Usuários não expiram automaticamente

**Solução:**
```bash
# Verificar se cron está ativo
crontab -l

# Configurar verificação automática
xray setup-auto-check

# Verificar manualmente
xray check-expired
```

### Problema: Link VLESS não funciona

**Solução:**
```bash
# Verificar se usuário existe
xray view-user nome_do_usuario

# Verificar configuração do Xray
cat /etc/xray/config.json | jq '.inbounds[]'

# Testar conexão
xray test-run
```

### Problema: QR Code não aparece

**Solução:**
```bash
# Instalar qrencode
apt-get install qrencode -y  # Debian/Ubuntu
yum install qrencode -y      # CentOS/RHEL
```

---

## 📚 Documentação Adicional

### Arquivos de Log

```bash
# Log principal do Xray
tail -f /var/log/xray/access.log
tail -f /var/log/xray/error.log

# Log de tráfego
tail -f /etc/xray/users/traffic.log

# Log de expirações
tail -f /etc/xray/users/expiration.log
```

### Backup do Sistema

```bash
# Backup completo
tar -czf xray2026-backup-$(date +%Y%m%d).tar.gz /etc/xray /var/log/xray

# Restaurar
tar -xzf xray2026-backup-YYYYMMDD.tar.gz -C /
systemctl restart xray
```

### Atualização do Sistema

```bash
# Atualizar Xray-core
xray update
> 1 (Atualizar Xray)

# Atualizar scripts
xray update
> 2 (Atualizar Script)
```

---

## 🤝 Contribuindo

Contribuições são bem-vindas! Por favor:

1. Fork o projeto
2. Crie uma branch para sua feature (`git checkout -b feature/NovaFuncionalidade`)
3. Commit suas mudanças (`git commit -m 'Adiciona nova funcionalidade'`)
4. Push para a branch (`git push origin feature/NovaFuncionalidade`)
5. Abra um Pull Request

---

## 📄 Licença

Este projeto está sob a licença GPL-3.0. Veja o arquivo [LICENSE](LICENSE) para mais detalhes.

---

## 🙏 Agradecimentos

- [XTLS/Xray-core](https://github.com/XTLS/Xray-core) - Core do projeto
- [233boy/Xray](https://github.com/233boy/Xray) - Script original

---

## 📞 Suporte

- **Issues:** https://github.com/PhoenixxZ2023/xray2026/issues
- **Discussões:** https://github.com/PhoenixxZ2023/xray2026/discussions

---

**Desenvolvido com ❤️ por PhoenixxZ2023**
