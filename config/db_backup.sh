#!/usr/bin/env bash
set -uo pipefail

backup_dir="${BACKUP_DIR:-/backups}"
retention_days="${BACKUP_RETENTION_DAYS:-14}"
file="$backup_dir/$(date -u +%Y-%m-%d).sql.gz"

if pg_dump --no-owner --no-acl "$DATABASE_URL" | gzip > "$file.partial"; then
  mv "$file.partial" "$file"
  find "$backup_dir" -name '*.sql.gz' -mtime "+$((retention_days - 1))" -delete
  echo "database backup written: $(basename "$file")"
else
  rm -f "$file.partial"
  echo "database backup failed" >&2
  exit 1
fi
