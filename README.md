# Chatwoot - Iga Tecnologia

Sistema de atendimento ao cliente com suporte a WhatsApp, e-mail e chat.
Baseado no [Chatwoot](https://github.com/chatwoot/chatwoot) (open source).

## Recursos configurados

- **3 equipes**: Suporte Tecnico, Financeiro, Comercial
- **Menu automatico**: cliente escolhe o setor ao iniciar conversa
- **Respostas prontas**: `/ola` `/aguarde` `/resolvido` `/horario` `/obrigado` `/dados`
- **Labels**: urgente, bug, duvida, aguardando-cliente, em-andamento, novo-cliente
- **Pesquisa de satisfacao**: enviada automaticamente ao resolver ticket
- **Horario de atendimento**: Seg-Sex 08:00-18:00 (Brasilia)
- **Idioma**: Portugues do Brasil

## Requisitos

- Docker e Docker Compose
- 4 GB RAM minimo
- 20 GB disco

## Instalacao rapida

```bash
# 1. Clonar o repositorio
git clone https://github.com/SEU_USUARIO/chatwoot-iga.git
cd chatwoot-iga

# 2. Executar o script de instalacao
chmod +x setup.sh
./setup.sh
```

O script vai:
1. Verificar/instalar Docker
2. Gerar senhas seguras automaticamente
3. Inicializar o banco de dados
4. Criar conta de administrador
5. Configurar equipes, labels e automacoes

## Instalacao manual

```bash
# 1. Copiar e editar .env
cp .env.example .env
nano .env  # preencher senhas e dominio

# 2. Subir banco e redis
docker compose up -d postgres redis
sleep 20

# 3. Inicializar banco
docker compose run --rm rails bundle exec rails db:chatwoot_prepare

# 4. Subir tudo
docker compose up -d

# 5. Acessar
# http://localhost:3000 (local)
# https://seu-dominio.com (producao)
```

## Producao (com dominio e SSL)

1. Edite o `.env`:
   ```
   FRONTEND_URL=https://suporte.seudominio.com
   FORCE_SSL=true
   ```

2. Configure SMTP no `.env` para envio de e-mails

3. Instale Nginx como proxy reverso:
   ```bash
   apt install -y nginx certbot python3-certbot-nginx
   ```

4. Configure o Nginx apontando para `localhost:3000`

5. Gere o SSL:
   ```bash
   certbot --nginx -d suporte.seudominio.com
   ```

## Comandos uteis

```bash
# Status
docker compose ps

# Logs
docker compose logs -f rails

# Reiniciar
docker compose restart

# Parar (mantem dados)
docker compose down

# Subir novamente
docker compose up -d

# Backup manual
./backup.sh

# Console Rails
docker compose exec rails bundle exec rails console

# Atualizar Chatwoot
docker compose pull
docker compose run --rm rails bundle exec rails db:chatwoot_prepare
docker compose up -d --force-recreate
```

## Backup automatico

Adicione ao cron para backup diario as 02:00:

```bash
chmod +x backup.sh
(crontab -l 2>/dev/null; echo "0 2 * * * $(pwd)/backup.sh >> $(pwd)/backups/backup.log 2>&1") | crontab -
```

## Estrutura

```
.
├── .env.example          # Modelo de configuracao (sem senhas)
├── .env                  # Configuracao real (nao versionado)
├── .gitignore            # Ignora .env e backups
├── docker-compose.yaml   # Definicao dos containers
├── setup.sh              # Script de instalacao automatica
├── backup.sh             # Script de backup
└── README.md             # Este arquivo
```

## Fluxo de atendimento

```
Cliente envia mensagem (WhatsApp/Chat/Email)
    |
    v
Bot: "Escolha o setor: 1-Suporte 2-Financeiro 3-Comercial"
    |
    v
Cliente digita "1"
    |
    v
Bot: "Voce sera atendido pelo Suporte Tecnico. Aguarde..."
    |
    v
Atendente humano responde pelo Chatwoot
    |
    v
Ticket resolvido → Pesquisa de satisfacao
```

## Licenca

Chatwoot e licenciado sob [MIT License](https://github.com/chatwoot/chatwoot/blob/develop/LICENSE).
