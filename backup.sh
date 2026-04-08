#!/bin/bash
# ============================================
# Chatwoot - Backup automatico
# Adicionar no cron: 0 2 * * * /opt/chatwoot/backup.sh
# ============================================

cd "$(dirname "$0")"
DATE=$(date +%Y%m%d_%H%M%S)
DIR="./backups"

mkdir -p "$DIR"

echo "[$DATE] Iniciando backup..."

# Backup do banco
docker compose exec -T postgres pg_dump \
  -U postgres chatwoot_production \
  | gzip > "$DIR/db_$DATE.sql.gz"

echo "[$DATE] Banco exportado: db_$DATE.sql.gz"

# Backup dos arquivos de upload
docker compose exec -T rails tar -czf - /app/storage \
  > "$DIR/storage_$DATE.tar.gz" 2>/dev/null

echo "[$DATE] Storage exportado: storage_$DATE.tar.gz"

# Remover backups com mais de 7 dias
find "$DIR" -name "*.gz" -mtime +7 -delete

echo "[$DATE] Backup concluido!"
