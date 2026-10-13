#!/usr/bin/env bash
# Restore drill: proves that a backup taken by the chart's script can rebuild
# the database. Runs entirely in throwaway Docker containers.
#
#   1. start PostgreSQL and load data
#   2. take a backup with chart/editalis/files/pg-backup.sh
#   3. destroy the data (drop the tables)
#   4. restore with scripts/pg-restore.sh
#   5. compare row counts and a content checksum with the originals
set -euo pipefail

here=$(cd "$(dirname "$0")/.." && pwd)
net=editalis-drill-$$
db=editalis-drill-db-$$
img=postgres:16-alpine
url="postgresql+psycopg://editalis:drill@$db:5432/editalis"
work=$(mktemp -d)
chmod 777 "$work"

cleanup() {
  docker rm -f "$db" > /dev/null 2>&1 || true
  docker network rm "$net" > /dev/null 2>&1 || true
  docker run --rm -v "$work":/backup "$img" sh -c 'rm -f /backup/*' > /dev/null 2>&1 || true
  rmdir "$work" 2> /dev/null || true
}
trap cleanup EXIT

psql() { docker exec -i "$db" psql -U editalis -d editalis -v ON_ERROR_STOP=1 -At "$@"; }
tool() { docker run --rm --network "$net" --user 70:70 -e DATABASE_URL="$url" -e BACKUP_DIR=/backup \
           -v "$work":/backup -v "$here":/repo:ro "$img" "$@"; }
fingerprint() {
  psql -c "select (select count(*) from subscribers) || ':' || (select count(*) from deliveries) || ':' ||
           (select md5(string_agg(id || '|' || phone || '|' || status, ',' order by id)) from subscribers)"
}

echo "1. starting PostgreSQL"
docker network create "$net" > /dev/null
docker run -d --name "$db" --network "$net" -e POSTGRES_DB=editalis -e POSTGRES_USER=editalis \
  -e POSTGRES_PASSWORD=drill "$img" > /dev/null
for _ in $(seq 1 30); do docker exec "$db" pg_isready -U editalis -d editalis > /dev/null 2>&1 && break; sleep 1; done

psql > /dev/null <<'SQL'
create table subscribers (id serial primary key, phone text not null unique, status text not null);
create table deliveries (id serial primary key, subscriber_id int not null references subscribers(id),
                         notice text not null, unique (subscriber_id, notice));
insert into subscribers (phone, status)
  select '+5521' || lpad(g::text, 9, '0'), (array['free','trial','active'])[1 + g % 3] from generate_series(1, 5000) g;
insert into deliveries (subscriber_id, notice)
  select s.id, 'notice-' || n from subscribers s cross join generate_series(1, 4) n;
SQL
before=$(fingerprint)
echo "   loaded: $before  (subscribers:deliveries:checksum)"

echo "2. taking a backup"
tool sh /repo/chart/editalis/files/pg-backup.sh
dump=$(docker run --rm -v "$work":/backup "$img" sh -c 'ls /backup/*.dump')

echo "3. destroying the data"
psql -c "drop table deliveries, subscribers" > /dev/null
[ "$(psql -c "select count(*) from pg_tables where schemaname = 'public'")" = "0" ]

echo "4. restoring"
tool sh /repo/scripts/pg-restore.sh "$dump"

echo "5. comparing"
after=$(fingerprint)
echo "   restored: $after"
# The unique constraint must have come back too: a duplicate insert has to fail.
if psql -c "insert into subscribers (phone, status) select phone, status from subscribers limit 1" > /dev/null 2>&1; then
  echo "FAIL: unique constraint was not restored"; exit 1
fi
if [ "$before" = "$after" ]; then echo "PASS: restored data matches the original"; else echo "FAIL: data differs"; exit 1; fi
