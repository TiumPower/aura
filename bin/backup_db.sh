#!/usr/bin/env bash
# Daily Postgres backup for loyalty_production. Dumps + gzips to the Capistrano
# shared dir and prunes old files. Run via cron (see deploy notes).
set -euo pipefail

APP_DIR="/var/www/loyalty/current"
BACKUP_DIR="/var/www/loyalty/shared/backups"
RETAIN_DAYS="${BACKUP_RETAIN_DAYS:-14}"
mkdir -p "$BACKUP_DIR"

# DB password from the app's .env (LOYALTY_DATABASE_PASSWORD=...)
PGPASSWORD="$(grep -E '^LOYALTY_DATABASE_PASSWORD=' "$APP_DIR/.env" | head -1 | cut -d= -f2- | sed -e 's/^["'\'']//' -e 's/["'\'']$//' -e 's/\r$//')"
export PGPASSWORD

STAMP="$(date +%Y%m%d-%H%M)"
FILE="$BACKUP_DIR/loyalty_production-$STAMP.sql.gz"

pg_dump -h localhost -U loyalty -d loyalty_production --no-owner --no-privileges | gzip -9 > "$FILE"
find "$BACKUP_DIR" -name 'loyalty_production-*.sql.gz' -mtime "+$RETAIN_DAYS" -delete

echo "[backup] $(date '+%F %T') -> $FILE ($(du -h "$FILE" | cut -f1)); kept $(ls -1 "$BACKUP_DIR" | wc -l) files"
