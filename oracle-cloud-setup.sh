#!/bin/bash
# ============================================
# Chatwoot - Iga Tecnologia
# Preparar VM Ubuntu no Oracle Cloud Free (Ampere A1 ARM)
# ============================================
# Rode apos criar a VM e fazer o primeiro SSH:
#   wget -O - https://raw.githubusercontent.com/Igatecnologia/Ticket/main/oracle-cloud-setup.sh | bash
# OU (recomendado): git clone + inspecionar antes
#   git clone https://github.com/Igatecnologia/Ticket.git
#   cd Ticket && chmod +x oracle-cloud-setup.sh && ./oracle-cloud-setup.sh
# ============================================

set -e

echo "============================================"
echo "  Chatwoot - Preparacao Oracle Cloud Free"
echo "  Ubuntu em Ampere A1 ARM"
echo "============================================"
echo ""

# Garantir sudo
if [ "$EUID" -eq 0 ]; then
    echo "[ERRO] Rode como usuario normal (ubuntu), nao como root."
    echo "       O script usa sudo quando precisa."
    exit 1
fi

# Detectar arquitetura - confirmar ARM
ARCH=$(uname -m)
echo "[INFO] Arquitetura: $ARCH"
if [ "$ARCH" != "aarch64" ]; then
    echo "[AVISO] Essa instancia nao parece ser ARM. O script segue, mas foi"
    echo "        desenhado para Ampere A1 (aarch64)."
fi

# ============================================
# 1. Atualizar sistema
# ============================================
echo ""
echo "[1/6] Atualizando pacotes..."
sudo apt update
sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y
sudo apt install -y curl git ca-certificates gnupg lsb-release iptables-persistent netfilter-persistent

# ============================================
# 2. Swap (4GB, defensivo)
# ============================================
echo ""
echo "[2/6] Configurando swap de 4GB..."
if ! swapon --show | grep -q "/swapfile"; then
    sudo fallocate -l 4G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    if ! grep -q "/swapfile" /etc/fstab; then
        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    fi
    echo "[OK] Swap criado"
else
    echo "[OK] Swap ja existe"
fi

# ============================================
# 3. Docker + Compose
# ============================================
echo ""
echo "[3/6] Instalando Docker..."
if ! command -v docker &>/dev/null; then
    curl -fsSL https://get.docker.com | sudo bash
fi
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
echo "[OK] Docker $(docker --version 2>/dev/null || echo 'instalado')"

# ============================================
# 4. iptables - GOTCHA Oracle Cloud
# ============================================
# Imagens Ubuntu do Oracle vem com /etc/iptables/rules.v4 que DROP/REJECT
# tudo exceto porta 22. Mesmo abrindo a Security List da VCN, o iptables
# interno bloqueia. Precisamos inserir regras para 80 e 443.
echo ""
echo "[4/6] Liberando portas 80 e 443 no iptables..."

# Insere no topo da chain INPUT (posicao 1) - garantido antes de qualquer REJECT
sudo iptables -C INPUT -p tcp -m state --state NEW -m tcp --dport 80 -j ACCEPT 2>/dev/null || \
    sudo iptables -I INPUT 1 -p tcp -m state --state NEW -m tcp --dport 80 -j ACCEPT

sudo iptables -C INPUT -p tcp -m state --state NEW -m tcp --dport 443 -j ACCEPT 2>/dev/null || \
    sudo iptables -I INPUT 1 -p tcp -m state --state NEW -m tcp --dport 443 -j ACCEPT

# Persistir
sudo netfilter-persistent save
echo "[OK] Regras iptables salvas"

# ============================================
# 5. Clonar o repositorio
# ============================================
echo ""
echo "[5/6] Clonando repositorio Chatwoot..."
if [ ! -d /opt/ticket ]; then
    sudo git clone https://github.com/Igatecnologia/Ticket.git /opt/ticket
    sudo chown -R "$USER:$USER" /opt/ticket
    cd /opt/ticket
    chmod +x setup.sh backup.sh nginx-setup.sh oracle-cloud-setup.sh
    echo "[OK] Repo clonado em /opt/ticket"
else
    echo "[OK] /opt/ticket ja existe - fazendo git pull"
    cd /opt/ticket && git pull
fi

# ============================================
# 6. Resumo
# ============================================
echo ""
echo "[6/6] Tudo pronto!"
echo ""
echo "============================================"
echo "  VM preparada com sucesso"
echo "============================================"
echo ""
free -h
echo ""
echo "IMPORTANTE: o grupo docker foi adicionado ao usuario '$USER'."
echo "Faca logout e login de novo (ou rode 'newgrp docker') antes"
echo "de continuar, para usar docker sem sudo."
echo ""
echo "ANTES de subir o Chatwoot, confirme no console do Oracle Cloud:"
echo "  1. Networking > Virtual Cloud Networks > sua VCN > Security List"
echo "  2. Ingress Rules - libere:"
echo "     - TCP 80  de 0.0.0.0/0"
echo "     - TCP 443 de 0.0.0.0/0"
echo "  (isso NAO e feito pelo script - e pela web do OCI)"
echo ""
echo "Depois rode:"
echo "  cd /opt/ticket"
echo "  ./setup.sh"
echo ""
echo "Editar .env:"
echo "  FRONTEND_URL=https://suporte.igatech.com.br"
echo "  FORCE_SSL=true"
echo "  docker compose restart"
echo ""
echo "Com DNS ja apontando para o IP publico da VM:"
echo "  sudo ./nginx-setup.sh"
echo ""
