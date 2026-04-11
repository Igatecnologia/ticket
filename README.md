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

Dominio oficial: **suporte.igatech.com.br**

### 1. Pre-requisitos no servidor
- Docker e Docker Compose instalados
- Portas 80 e 443 liberadas
- DNS `suporte.igatech.com.br` apontando para o IP do servidor

### 2. Clonar o repositorio
```bash
sudo mkdir -p /opt
cd /opt
sudo git clone https://github.com/Igatecnologia/Ticket.git ticket
sudo chown -R $USER:$USER /opt/ticket
cd /opt/ticket
```

### 3. Subir o Chatwoot
```bash
chmod +x setup.sh backup.sh nginx-setup.sh
./setup.sh
```
O script gera senhas automaticas, sobe os containers e cria a conta admin.

Depois, edite o `.env` gerado e confirme:
```
FRONTEND_URL=https://suporte.igatech.com.br
FORCE_SSL=true
```
E reinicie: `docker compose restart`

### 4. Nginx + SSL (Let's Encrypt)
```bash
sudo ./nginx-setup.sh
```
Isto instala Nginx, publica o vhost em `/etc/nginx/sites-available/chatwoot`,
emite o certificado via Certbot e ativa o redirect 80 -> 443.

Para usar outro dominio: `sudo DOMINIO=ticket.igatech.com.br ./nginx-setup.sh`

### 5. SMTP (quando for configurar)
Edite o `.env` com as credenciais do provedor e rode `docker compose restart`.
Ex. Gmail/Workspace:
```
SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=suporte@igatech.com.br
SMTP_PASSWORD=xxxx-xxxx-xxxx-xxxx
SMTP_AUTHENTICATION=plain
SMTP_ENABLE_STARTTLS_AUTO=true
```

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
