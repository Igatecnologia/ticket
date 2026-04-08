#!/bin/bash
# ============================================
# Chatwoot - Iga Tecnologia
# Script de instalacao automatica
# Suporte Tecnico com menu de setores
# ============================================

set -e

echo "============================================"
echo "  Iga Tecnologia - Sistema de Suporte"
echo "  Instalacao automatica via Docker"
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

    SECRET=$(openssl rand -hex 64)
    PGPASS=$(openssl rand -base64 20 | tr -d "=+/")
    REDISPASS=$(openssl rand -base64 16 | tr -d "=+/")

    sed -i "s|SECRET_KEY_BASE=TROCAR_AQUI|SECRET_KEY_BASE=$SECRET|" .env
    sed -i "s|POSTGRES_PASSWORD=TROCAR_AQUI|POSTGRES_PASSWORD=$PGPASS|" .env
    sed -i "s|REDIS_PASSWORD=|REDIS_PASSWORD=$REDISPASS|" .env

    echo "[OK] Senhas geradas automaticamente"
    echo ""
    echo "IMPORTANTE: Edite o .env para configurar:"
    echo "  - FRONTEND_URL (seu dominio ou IP)"
    echo "  - SMTP (para envio de e-mails)"
    echo ""
    read -p "Deseja editar o .env agora? (s/n): " EDIT_ENV
    if [ "$EDIT_ENV" = "s" ]; then
        ${EDITOR:-nano} .env
    fi
else
    echo "[OK] Arquivo .env encontrado"
fi

echo ""
echo "[1/4] Subindo PostgreSQL e Redis..."
docker compose up -d postgres redis
echo "Aguardando banco de dados (20s)..."
sleep 20

echo ""
echo "[2/4] Inicializando banco de dados..."
docker compose run --rm rails bundle exec rails db:chatwoot_prepare

echo ""
echo "[3/4] Subindo todos os servicos..."
docker compose up -d

echo ""
echo "Aguardando aplicacao iniciar (60s)..."
sleep 60

# Configurar conta e admin
echo ""
echo "============================================"
echo "  Configuracao da conta"
echo "============================================"
read -p "Nome da empresa [Iga Tecnologia]: " EMPRESA
EMPRESA=${EMPRESA:-Iga Tecnologia}
read -p "E-mail do admin: " EMAIL_ADMIN
read -sp "Senha do admin (min 8 caracteres): " SENHA_ADMIN
echo ""

echo ""
echo "[4/4] Configurando sistema..."
docker compose exec rails bundle exec rails runner "
account = Account.find_or_create_by!(name: '$EMPRESA') do |a|
  a.locale = 'pt_BR'
  a.auto_resolve_duration = 7
  a.support_email = '$EMAIL_ADMIN'
end

# Admin
user = User.new(name: 'Administrador', email: '$EMAIL_ADMIN', password: '$SENHA_ADMIN', password_confirmation: '$SENHA_ADMIN')
user.skip_confirmation!
user.save!
AccountUser.find_or_create_by!(account: account, user: user) { |au| au.role = :administrator }
puts '[OK] Admin criado'

# Equipes
teams = {}
['Suporte Tecnico', 'Financeiro', 'Comercial'].each do |name|
  team = Team.find_or_create_by!(name: name, account: account) { |t| t.description = \"Equipe #{name}\" }
  TeamMember.find_or_create_by!(team: team, user: user)
  teams[name.downcase] = team
end
puts '[OK] Equipes criadas'

# Labels
[
  { title: 'urgente', description: 'Prioridade maxima', color: '#e63329' },
  { title: 'bug', description: 'Erro tecnico reportado', color: '#f59e0b' },
  { title: 'duvida', description: 'Duvida geral', color: '#3b82f6' },
  { title: 'aguardando-cliente', description: 'Esperando retorno do cliente', color: '#8b5cf6' },
  { title: 'em-andamento', description: 'Ticket sendo trabalhado', color: '#f97316' },
  { title: 'novo-cliente', description: 'Primeiro contato', color: '#06b6d4' },
  { title: 'hardware', description: 'Problema de hardware', color: '#dc2626' },
  { title: 'software', description: 'Problema de software', color: '#2563eb' },
  { title: 'rede', description: 'Problema de rede/internet', color: '#7c3aed' },
  { title: 'acesso', description: 'Problema de senha/acesso', color: '#ca8a04' },
  { title: 'impressora', description: 'Problema com impressora', color: '#0d9488' },
  { title: 'retorno-agendado', description: 'Retorno agendado com o cliente', color: '#4f46e5' }
].each { |l| Label.find_or_create_by!(title: l[:title], account: account) { |lb| lb.description = l[:description]; lb.color = l[:color]; lb.show_on_sidebar = true } }
puts '[OK] Labels criadas'

# Respostas prontas
[
  { short_code: 'ola', content: 'Ola! Obrigado por entrar em contato. Como posso ajudar?' },
  { short_code: 'aguarde', content: 'Estamos verificando sua solicitacao. Por favor, aguarde um momento.' },
  { short_code: 'resolvido', content: 'Sua solicitacao foi resolvida! Caso precise de mais alguma coisa, estamos a disposicao.' },
  { short_code: 'horario', content: 'Nosso horario de atendimento e de segunda a sexta, das 08h as 18h.' },
  { short_code: 'obrigado', content: 'Obrigado pelo contato! Foi um prazer atende-lo. Tenha um otimo dia!' },
  { short_code: 'dados', content: \"Para dar andamento, preciso de algumas informacoes:\n- Nome completo\n- E-mail\n- Descricao detalhada do problema\" },
  { short_code: 'boleto', content: 'Estou encaminhando sua solicitacao para o setor financeiro. Em breve voce recebera o retorno.' },
  { short_code: 'orcamento', content: 'Obrigado pelo interesse! Vou encaminhar para nosso time comercial.' },
  { short_code: 'remoto', content: 'Precisaremos de um acesso remoto. Podemos agendar o melhor horario para voce?' },
  { short_code: 'atualizar', content: 'Sua solicitacao esta em andamento. Assim que houver novidades, entraremos em contato.' },
  { short_code: 'reiniciar', content: 'Por favor, tente reiniciar o computador e verifique se o problema persiste.' },
  { short_code: 'senha', content: 'Vou realizar o reset da sua senha. Em instantes voce recebera as instrucoes de acesso.' },
  { short_code: 'acesso', content: \"Para liberar seu acesso, preciso de:\n- Nome completo\n- E-mail corporativo\n- Sistema que precisa acessar\n- Aprovacao do gestor\" },
  { short_code: 'vpn', content: \"Para conectar na VPN:\n1. Abra o aplicativo de VPN\n2. Use seu usuario e senha corporativos\n3. Selecione o servidor indicado\n4. Se der erro, envie o print da tela\" },
  { short_code: 'print', content: 'Poderia me enviar um print (captura de tela) do erro? Isso ajuda a identificar o problema mais rapido.' },
  { short_code: 'escalar', content: 'Estou encaminhando para o nivel 2 de suporte. Voce sera contatado em breve.' },
  { short_code: 'finalizar', content: \"Problema resolvido! Resumo:\n- Problema: \n- Solucao aplicada: \n\nCaso volte a ocorrer, abra um novo chamado.\" }
].each { |r| CannedResponse.find_or_create_by!(short_code: r[:short_code], account: account) { |cr| cr.content = r[:content] } }
puts '[OK] Respostas prontas criadas'

# Atributos customizados
[
  { attribute_display_name: 'Tipo de Problema', attribute_display_type: 'list', attribute_key: 'tipo_problema', attribute_model: 'conversation_attribute', attribute_values: ['Hardware', 'Software', 'Rede', 'Impressora', 'Email', 'Acesso/Senha', 'Sistema ERP', 'Outro'] },
  { attribute_display_name: 'Prioridade', attribute_display_type: 'list', attribute_key: 'prioridade', attribute_model: 'conversation_attribute', attribute_values: ['Baixa', 'Media', 'Alta', 'Critica'] },
  { attribute_display_name: 'Numero do Patrimonio', attribute_display_type: 'text', attribute_key: 'patrimonio', attribute_model: 'conversation_attribute', attribute_values: [] },
  { attribute_display_name: 'Sistema Operacional', attribute_display_type: 'list', attribute_key: 'sistema_operacional', attribute_model: 'conversation_attribute', attribute_values: ['Windows 10', 'Windows 11', 'macOS', 'Linux', 'Android', 'iOS'] },
  { attribute_display_name: 'Empresa', attribute_display_type: 'text', attribute_key: 'empresa_cliente', attribute_model: 'contact_attribute', attribute_values: [] },
  { attribute_display_name: 'Setor', attribute_display_type: 'text', attribute_key: 'setor_cliente', attribute_model: 'contact_attribute', attribute_values: [] },
  { attribute_display_name: 'Contrato Ativo', attribute_display_type: 'list', attribute_key: 'contrato_ativo', attribute_model: 'contact_attribute', attribute_values: ['Sim', 'Nao', 'Em negociacao'] }
].each do |attr|
  CustomAttributeDefinition.find_or_create_by!(attribute_key: attr[:attribute_key], account: account) do |ca|
    ca.attribute_display_name = attr[:attribute_display_name]
    ca.attribute_display_type = attr[:attribute_display_type]
    ca.attribute_model = attr[:attribute_model]
    ca.attribute_values = attr[:attribute_values]
  end
end
puts '[OK] Atributos customizados criados'

# Automacoes
suporte = Team.find_by(account: account, name: 'suporte tecnico') || Team.find(1)
financeiro = Team.find_by(account: account, name: 'financeiro') || Team.find(2)
comercial = Team.find_by(account: account, name: 'comercial') || Team.find(3)

AutomationRule.find_or_create_by!(account: account, name: 'Menu de Boas-Vindas') do |r|
  r.event_name = 'conversation_created'
  r.conditions = [{ 'attribute_key' => 'status', 'filter_operator' => 'equal_to', 'values' => ['open'], 'query_operator' => nil }]
  r.actions = [{ 'action_name' => 'send_message', 'action_params' => [\"Ola! Bem-vindo a #{account.name}!\nEscolha o setor:\n\n1 - Suporte Tecnico\n2 - Financeiro\n3 - Comercial\n\nDigite o numero ou o nome do setor.\"] }]
  r.active = true
end

AutomationRule.find_or_create_by!(account: account, name: 'Menu - Suporte') do |r|
  r.event_name = 'message_created'
  r.conditions = [{ 'attribute_key' => 'content', 'filter_operator' => 'contains', 'values' => ['1', 'suporte', 'tecnico'], 'query_operator' => nil }]
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

AutomationRule.find_or_create_by!(account: account, name: 'Fora do Horario') do |r|
  r.description = 'Mensagem fora do expediente'
  r.event_name = 'conversation_created'
  r.conditions = [{ 'attribute_key' => 'status', 'filter_operator' => 'equal_to', 'values' => ['open'], 'query_operator' => nil }]
  r.actions = [{ 'action_name' => 'send_message', 'action_params' => [\"Obrigado por entrar em contato!\nNosso horario e de segunda a sexta, 08h as 18h.\nSua mensagem foi registrada e responderemos assim que possivel.\"] }]
  r.active = false
end
puts '[OK] Automacoes criadas'

puts ''
puts '============================================'
puts '  CONFIGURACAO CONCLUIDA!'
puts '============================================'
"

echo ""
echo "============================================"
echo "  INSTALACAO CONCLUIDA!"
echo "============================================"
echo ""
docker compose ps
echo ""
FRONTEND=$(grep FRONTEND_URL .env | head -1 | cut -d= -f2)
echo "Acesse: $FRONTEND"
echo "Email:  $EMAIL_ADMIN"
echo ""
echo "Equipes: Suporte Tecnico, Financeiro, Comercial"
echo ""
echo "Respostas prontas (digite / no chat):"
echo "  /ola /aguarde /resolvido /horario /obrigado"
echo "  /dados /reiniciar /senha /acesso /vpn"
echo "  /print /escalar /finalizar /remoto"
echo ""
echo "Para configurar o logo:"
echo "  Acesse > Configuracoes > Conta > Logo da conta"
echo ""
echo "============================================"
