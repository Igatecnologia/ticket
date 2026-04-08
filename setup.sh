#!/bin/bash
# ============================================
# Chatwoot - Iga Tecnologia
# Script de instalacao automatica
# ============================================

set -e

echo "============================================"
echo " Chatwoot - Iga Tecnologia"
echo " Instalacao automatica"
echo "============================================"
echo ""

# Verificar Docker
if ! command -v docker &> /dev/null; then
    echo "Docker nao encontrado. Instalando..."
    curl -fsSL https://get.docker.com | bash
    systemctl enable --now docker
fi

if ! docker compose version &> /dev/null; then
    echo "Docker Compose nao encontrado. Instalando..."
    apt install -y docker-compose-plugin
fi

echo "[OK] Docker $(docker --version)"
echo "[OK] $(docker compose version)"
echo ""

# Verificar .env
if [ ! -f .env ]; then
    echo "Criando arquivo .env a partir do exemplo..."
    cp .env.example .env

    # Gerar senhas automaticamente
    SECRET=$(openssl rand -hex 64)
    PGPASS=$(openssl rand -base64 20 | tr -d "=+/")
    REDISPASS=$(openssl rand -base64 16 | tr -d "=+/")

    sed -i "s|SECRET_KEY_BASE=TROCAR_AQUI|SECRET_KEY_BASE=$SECRET|" .env
    sed -i "s|POSTGRES_PASSWORD=TROCAR_AQUI|POSTGRES_PASSWORD=$PGPASS|" .env
    sed -i "s|REDIS_PASSWORD=|REDIS_PASSWORD=$REDISPASS|" .env

    echo "[OK] Senhas geradas automaticamente"
    echo ""
    echo "IMPORTANTE: Edite o .env para configurar:"
    echo "  - FRONTEND_URL (seu dominio)"
    echo "  - SMTP (para envio de e-mails)"
    echo ""
    read -p "Deseja editar o .env agora? (s/n): " EDIT_ENV
    if [ "$EDIT_ENV" = "s" ]; then
        nano .env
    fi
else
    echo "[OK] Arquivo .env encontrado"
fi

echo ""
echo "Subindo PostgreSQL e Redis..."
docker compose up -d postgres redis
echo "Aguardando banco de dados (20s)..."
sleep 20

echo ""
echo "Inicializando banco de dados..."
docker compose run --rm rails bundle exec rails db:chatwoot_prepare

echo ""
echo "Subindo todos os servicos..."
docker compose up -d

echo ""
echo "Aguardando aplicacao iniciar (60s)..."
sleep 60

# Configurar conta e admin
echo ""
echo "============================================"
echo " Configuracao da conta"
echo "============================================"
read -p "Nome da empresa: " EMPRESA
read -p "E-mail do admin: " EMAIL_ADMIN
read -p "Senha do admin (min 8 caracteres): " SENHA_ADMIN

docker compose exec rails bundle exec rails runner "
account = Account.find_or_create_by!(name: '$EMPRESA') { |a| a.locale = 'pt_BR' }
user = User.new(name: 'Administrador', email: '$EMAIL_ADMIN', password: '$SENHA_ADMIN', password_confirmation: '$SENHA_ADMIN')
user.skip_confirmation!
user.save!
AccountUser.find_or_create_by!(account: account, user: user) { |au| au.role = :administrator }
puts 'Admin criado!'
"

# Configurar equipes
echo ""
echo "Criando equipes e automacoes..."
docker compose exec rails bundle exec rails runner "
account = Account.first
admin = User.first

['Suporte Tecnico', 'Financeiro', 'Comercial'].each do |name|
  team = Team.find_or_create_by!(name: name, account: account) { |t| t.description = \"Equipe #{name}\" }
  TeamMember.find_or_create_by!(team: team, user: admin)
end

labels = [
  { title: 'urgente', description: 'Prioridade maxima', color: '#e63329', show_on_sidebar: true },
  { title: 'bug', description: 'Erro tecnico', color: '#f59e0b', show_on_sidebar: true },
  { title: 'duvida', description: 'Duvida geral', color: '#3b82f6', show_on_sidebar: true },
  { title: 'aguardando-cliente', description: 'Esperando retorno', color: '#8b5cf6', show_on_sidebar: true },
  { title: 'em-andamento', description: 'Sendo trabalhado', color: '#f97316', show_on_sidebar: true },
  { title: 'novo-cliente', description: 'Primeiro contato', color: '#06b6d4', show_on_sidebar: true }
]
labels.each { |l| Label.find_or_create_by!(title: l[:title], account: account) { |lb| lb.description = l[:description]; lb.color = l[:color]; lb.show_on_sidebar = l[:show_on_sidebar] } }

respostas = [
  { short_code: 'ola', content: 'Ola! Obrigado por entrar em contato. Como posso ajudar?' },
  { short_code: 'aguarde', content: 'Estamos verificando sua solicitacao. Por favor, aguarde um momento.' },
  { short_code: 'resolvido', content: 'Sua solicitacao foi resolvida! Caso precise de mais alguma coisa, estamos a disposicao.' },
  { short_code: 'horario', content: 'Nosso horario de atendimento e de segunda a sexta, das 08h as 18h.' },
  { short_code: 'obrigado', content: 'Obrigado pelo contato! Foi um prazer atende-lo. Tenha um otimo dia!' },
  { short_code: 'dados', content: \"Para dar andamento, preciso de algumas informacoes:\n- Nome completo\n- E-mail\n- Descricao detalhada do problema\" }
]
respostas.each { |r| CannedResponse.find_or_create_by!(short_code: r[:short_code], account: account) { |cr| cr.content = r[:content] } }

suporte = Team.find_by(name: 'suporte tecnico', account: account)
financeiro = Team.find_by(name: 'financeiro', account: account)
comercial = Team.find_by(name: 'comercial', account: account)

AutomationRule.find_or_create_by!(account: account, name: 'Menu de Boas-Vindas') do |r|
  r.event_name = 'conversation_created'
  r.conditions = [{ 'attribute_key' => 'status', 'filter_operator' => 'equal_to', 'values' => ['open'], 'query_operator' => nil }]
  r.actions = [{ 'action_name' => 'send_message', 'action_params' => [\"Ola! Bem-vindo!\nEscolha o setor:\n\n1 - Suporte Tecnico\n2 - Financeiro\n3 - Comercial\n\nDigite o numero ou o nome do setor.\"] }]
  r.active = true
end

AutomationRule.find_or_create_by!(account: account, name: 'Menu - Suporte') do |r|
  r.event_name = 'message_created'
  r.conditions = [{ 'attribute_key' => 'content', 'filter_operator' => 'contains', 'values' => ['1', 'suporte'], 'query_operator' => nil }]
  r.actions = [{ 'action_name' => 'assign_team', 'action_params' => [suporte.id] }, { 'action_name' => 'send_message', 'action_params' => ['Voce sera atendido pelo Suporte Tecnico. Aguarde...'] }]
  r.active = true
end

AutomationRule.find_or_create_by!(account: account, name: 'Menu - Financeiro') do |r|
  r.event_name = 'message_created'
  r.conditions = [{ 'attribute_key' => 'content', 'filter_operator' => 'contains', 'values' => ['2', 'financeiro', 'boleto', 'pagamento'], 'query_operator' => nil }]
  r.actions = [{ 'action_name' => 'assign_team', 'action_params' => [financeiro.id] }, { 'action_name' => 'send_message', 'action_params' => ['Voce sera atendido pelo Financeiro. Aguarde...'] }]
  r.active = true
end

AutomationRule.find_or_create_by!(account: account, name: 'Menu - Comercial') do |r|
  r.event_name = 'message_created'
  r.conditions = [{ 'attribute_key' => 'content', 'filter_operator' => 'contains', 'values' => ['3', 'comercial', 'orcamento', 'proposta'], 'query_operator' => nil }]
  r.actions = [{ 'action_name' => 'assign_team', 'action_params' => [comercial.id] }, { 'action_name' => 'send_message', 'action_params' => ['Voce sera atendido pelo Comercial. Aguarde...'] }]
  r.active = true
end

AutomationRule.find_or_create_by!(account: account, name: 'Pesquisa de Satisfacao') do |r|
  r.event_name = 'conversation_resolved'
  r.conditions = [{ 'attribute_key' => 'status', 'filter_operator' => 'equal_to', 'values' => ['resolved'], 'query_operator' => nil }]
  r.actions = [{ 'action_name' => 'send_message', 'action_params' => [\"Atendimento finalizado!\nDe 1 a 5, como avalia nosso atendimento?\n1-Pessimo 2-Ruim 3-Regular 4-Bom 5-Excelente\"] }]
  r.active = true
end

account.update!(locale: 'pt_BR', auto_resolve_duration: 7)
account.working_hours.each do |wh|
  if [1,2,3,4,5].include?(wh.day_of_week)
    wh.update!(open_hour: 8, open_minutes: 0, close_hour: 18, close_minutes: 0, closed_all_day: false)
  else
    wh.update!(closed_all_day: true)
  end
end

puts 'Tudo configurado!'
"

echo ""
echo "============================================"
echo " INSTALACAO CONCLUIDA!"
echo "============================================"
echo ""

# Verificar status
docker compose ps
echo ""

FRONTEND=$(grep FRONTEND_URL .env | head -1 | cut -d= -f2)
echo "Acesse: $FRONTEND"
echo "Email:  $EMAIL_ADMIN"
echo "Senha:  (a que voce definiu)"
echo ""
echo "Equipes: Suporte Tecnico, Financeiro, Comercial"
echo "Respostas prontas: /ola /aguarde /resolvido /horario /obrigado /dados"
echo ""
echo "============================================"
