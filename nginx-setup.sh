#!/bin/bash
# ============================================
# Chatwoot - Iga Tecnologia
# Instala Nginx + Certbot e publica o vhost
# Uso: sudo ./nginx-setup.sh
# ============================================

set -e

DOMINIO="${DOMINIO:-suporte.igatech.com.br}"
EMAIL_SSL="${EMAIL_SSL:-suporte@igatech.com.br}"

echo "============================================"
echo "  Nginx + SSL para Chatwoot"
echo "  Dominio: $DOMINIO"
echo "============================================"

if [ "$EUID" -ne 0 ]; then
    echo "[ERRO] Rode como root: sudo ./nginx-setup.sh"
    exit 1
fi

# 1) Instalar pacotes
echo ""
echo "[1/5] Instalando Nginx e Certbot..."
apt update
apt install -y nginx certbot python3-certbot-nginx

# 2) Copiar vhost
echo ""
echo "[2/5] Publicando vhost do Chatwoot..."
cp nginx/chatwoot.conf /etc/nginx/sites-available/chatwoot

# Substituir dominio no vhost caso tenha sido passado via DOMINIO=
sed -i "s|suporte.igatech.com.br|$DOMINIO|g" /etc/nginx/sites-available/chatwoot

# 3) Ativar site e desativar default
ln -sf /etc/nginx/sites-available/chatwoot /etc/nginx/sites-enabled/chatwoot
rm -f /etc/nginx/sites-enabled/default

# 4) Testar e recarregar
echo ""
echo "[3/5] Validando configuracao do Nginx..."
nginx -t
systemctl reload nginx
systemctl enable nginx

# 5) Emitir certificado SSL
echo ""
echo "[4/5] Emitindo certificado SSL via Let's Encrypt..."
echo "IMPORTANTE: o dominio $DOMINIO precisa estar apontado para o IP deste servidor."
read -p "O DNS ja esta propagado? (s/n): " DNS_OK
if [ "$DNS_OK" = "s" ]; then
    certbot --nginx -d "$DOMINIO" --non-interactive --agree-tos -m "$EMAIL_SSL" --redirect
else
    echo "[AVISO] Pulando Certbot. Rode depois:"
    echo "  certbot --nginx -d $DOMINIO"
fi

# 6) Firewall (se ufw estiver ativo)
echo ""
echo "[5/5] Liberando portas 80 e 443 no firewall (se aplicavel)..."
if command -v ufw &>/dev/null; then
    ufw allow 'Nginx Full' || true
fi

echo ""
echo "============================================"
echo "  Nginx configurado!"
echo "  URL: https://$DOMINIO"
echo "============================================"
echo ""
echo "Proximo passo: edite o .env e ajuste"
echo "  FRONTEND_URL=https://$DOMINIO"
echo "  FORCE_SSL=true"
echo "Depois: docker compose restart"
