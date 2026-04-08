# Iga Tecnologia - Sistema de Suporte

Sistema de atendimento ao cliente com suporte a WhatsApp, e-mail e chat.
Baseado no [Chatwoot](https://github.com/chatwoot/chatwoot) (open source).

## Recursos

### Equipes
- Suporte Tecnico
- Financeiro
- Comercial

### Menu automatico
Cliente recebe menu ao iniciar conversa e e direcionado para o setor correto.

### Respostas prontas (digite `/` no chat)

| Gerais | Suporte TI |
|--------|-----------|
| `/ola` - Saudacao | `/reiniciar` - Pedir para reiniciar PC |
| `/aguarde` - Pedir espera | `/senha` - Reset de senha |
| `/resolvido` - Encerrar | `/acesso` - Liberar acesso |
| `/horario` - Horario | `/vpn` - Instrucoes VPN |
| `/obrigado` - Agradecimento | `/print` - Pedir screenshot |
| `/dados` - Pedir informacoes | `/escalar` - Escalar nivel 2 |
| `/remoto` - Acesso remoto | `/finalizar` - Resumo e encerramento |
| `/atualizar` - Status do ticket | |
| `/boleto` - Encaminhar financeiro | |
| `/orcamento` - Encaminhar comercial | |

### Labels

| Label | Cor | Uso |
|-------|-----|-----|
| `urgente` | Vermelho | Prioridade maxima |
| `bug` | Amarelo | Erro tecnico |
| `duvida` | Azul | Duvida geral |
| `hardware` | Vermelho escuro | Problema de hardware |
| `software` | Azul escuro | Problema de software |
| `rede` | Roxo | Rede/internet |
| `acesso` | Dourado | Senha/acesso |
| `impressora` | Verde agua | Impressora |
| `aguardando-cliente` | Roxo claro | Esperando retorno |
| `em-andamento` | Laranja | Sendo trabalhado |
| `novo-cliente` | Ciano | Primeiro contato |
| `retorno-agendado` | Indigo | Retorno marcado |

### Atributos customizados

**Por conversa (ticket):**
- Tipo de Problema (Hardware, Software, Rede, Impressora, Email, Acesso/Senha, ERP, Outro)
- Prioridade (Baixa, Media, Alta, Critica)
- Numero do Patrimonio
- Sistema Operacional

**Por contato (cliente):**
- Empresa
- Setor
- Contrato Ativo (Sim, Nao, Em negociacao)

### Automacoes
- Menu de boas-vindas (ativa)
- Direcionamento por setor: Suporte, Financeiro, Comercial (ativas)
- Pesquisa de satisfacao ao resolver (ativa)
- Mensagem fora do horario (desativada - ativar em producao)

## Requisitos

- Docker e Docker Compose
- 4 GB RAM minimo
- 20 GB disco

## Instalacao rapida

```bash
git clone https://github.com/Igatecnologia/Ticket.git
cd Ticket
chmod +x setup.sh
./setup.sh
```

## Instalacao manual

```bash
cp .env.example .env
# Editar .env com suas configuracoes

docker compose up -d postgres redis
sleep 20
docker compose run --rm rails bundle exec rails db:chatwoot_prepare
docker compose up -d
```

## Logo da empresa

Apos o primeiro login, va em:
**Configuracoes > Configuracoes da conta > Logo da conta**

Recomendacoes:
- Formato: PNG com fundo transparente
- Tamanho: 256x256px
- Peso: menos de 1MB

O logo aparece no painel, no chat widget e nos e-mails.

## Producao (com dominio e SSL)

1. Edite `.env`: `FRONTEND_URL=https://suporte.seudominio.com` e `FORCE_SSL=true`
2. Configure SMTP no `.env`
3. Instale Nginx + Certbot
4. Aponte o dominio para o IP do servidor

## Comandos uteis

```bash
docker compose ps                    # Status
docker compose logs -f rails         # Logs
docker compose restart               # Reiniciar
docker compose down                  # Parar
docker compose up -d                 # Subir
./backup.sh                          # Backup manual
docker compose exec rails bundle exec rails console  # Console
```

## Atualizar

```bash
docker compose pull
docker compose run --rm rails bundle exec rails db:chatwoot_prepare
docker compose up -d --force-recreate
```

## Backup automatico

```bash
chmod +x backup.sh
(crontab -l 2>/dev/null; echo "0 2 * * * $(pwd)/backup.sh >> $(pwd)/backups/backup.log 2>&1") | crontab -
```

## Estrutura

```
.
├── .env.example          # Modelo de configuracao (sem senhas)
├── .env                  # Configuracao real (NAO versionado)
├── .gitignore            # Protege .env e backups
├── docker-compose.yaml   # Containers Docker
├── setup.sh              # Instalacao automatica
├── backup.sh             # Backup do banco e arquivos
└── README.md             # Documentacao
```

## Licenca

Chatwoot e licenciado sob [MIT License](https://github.com/chatwoot/chatwoot/blob/develop/LICENSE).
