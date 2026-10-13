#!/bin/sh
# Logical backup of the database: a compressed custom-format dump, verified by
# listing its contents, then old dumps are pruned. If S3_BUCKET is set and the
# aws CLI is present, the dump is also copied there.
set -eu

: "${DATABASE_URL:?DATABASE_URL is required}"
BACKUP_DIR="${BACKUP_DIR:-/backup}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"

# SQLAlchemy URLs carry a driver ("postgresql+psycopg://"); libpq does not accept it.
PG_URL=$(printf '%s' "$DATABASE_URL" | sed -E 's#^postgresql\+[a-z0-9]+://#postgresql://#')

stamp=$(date -u +%Y%m%dT%H%M%SZ)
file="$BACKUP_DIR/editalis-$stamp.dump"

pg_dump --format=custom --no-owner --no-privileges --file="$file.partial" "$PG_URL"
# A dump that cannot be listed is not a backup.
pg_restore --list "$file.partial" > /dev/null
mv "$file.partial" "$file"
echo "backup written: $file ($(wc -c < "$file") bytes)"

if [ -n "${S3_BUCKET:-}" ] && command -v aws > /dev/null 2>&1; then
  aws s3 cp "$file" "s3://$S3_BUCKET/postgres/$(basename "$file")" --only-show-errors
  echo "copied to s3://$S3_BUCKET/postgres/"
fi

find "$BACKUP_DIR" -name 'editalis-*.dump' -mtime +"$RETENTION_DAYS" -delete
