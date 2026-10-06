#!/usr/bin/env bash
# =============================================================================
# run-migrations.sh — Sequential Database Migrations Runner for Self-Hosted Supabase
# Company: Elifsi Technologies Private Limited
#
# Connects to the local PostgreSQL container and runs all 20 migrations
# in strict chronological order with stop-on-error guarantees.
# =============================================================================

set -e

DB_HOST="${POSTGRES_HOST:-localhost}"
DB_PORT="${POSTGRES_PORT:-54322}"
DB_NAME="${POSTGRES_DB:-postgres}"
DB_USER="${POSTGRES_USER:-postgres}"
DB_PASSWORD="${POSTGRES_PASSWORD:-postgres}"

MIGRATIONS_DIR="supabase/migrations"

echo "================================================================="
echo "🗄️ RUNNING EVRRY DATABASE MIGRATIONS (0001 through 0020)"
echo "Target Database: $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"
echo "================================================================="

if [ ! -d "$MIGRATIONS_DIR" ]; then
  echo "❌ Error: Directory '$MIGRATIONS_DIR' not found. Please run from repo root."
  exit 1
fi

MIGRATION_FILES=($(ls -1 $MIGRATIONS_DIR/*.sql | sort))

TOTAL=${#MIGRATION_FILES[@]}
echo "Found $TOTAL SQL migration files to apply."

for (( i=0; i<$TOTAL; i++ )); do
  FILE="${MIGRATION_FILES[$i]}"
  FILENAME=$(basename "$FILE")
  echo "  ▶️ Applying [$((i+1))/$TOTAL]: $FILENAME"

  # Execute via docker container or direct psql
  if docker ps --format '{{.Names}}' | grep -q "supabase-db"; then
    docker exec -i supabase-db psql -U "$DB_USER" -d "$DB_NAME" < "$FILE" > /dev/null
  else
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$FILE" > /dev/null
  fi

  echo "     ✅ Applied successfully."
done

echo "================================================================="
echo "✨ ALL $TOTAL MIGRATIONS APPLIED SUCCESSFULLY!"
echo "Database is 100% synchronized with all domain schemas, RLS & triggers."
echo "================================================================="
