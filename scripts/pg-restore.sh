#!/bin/sh
# Restore a dump produced by pg-backup.sh into the database at DATABASE_URL.
# Usage: DATABASE_URL=postgresql://... pg-restore.sh /backup/editalis-<stamp>.dump
set -eu

: "${DATABASE_URL:?DATABASE_URL is required}"
dump="${1:?path to the .dump file is required}"
PG_URL=$(printf '%s' "$DATABASE_URL" | sed -E 's#^postgresql\+[a-z0-9]+://#postgresql://#')

# --clean --if-exists makes the restore repeatable; --exit-on-error stops at the
# first problem instead of leaving a half-restored database.
pg_restore --clean --if-exists --no-owner --no-privileges --exit-on-error \
  --dbname="$PG_URL" "$dump"
echo "restored: $dump"
