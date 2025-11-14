#!/bin/bash

# ============================================================================
# Run All Phase 0 Migrations
# ============================================================================
# Description: Execute all Phase 0 migrations in order
# Date: 2025-01-07
# Usage: ./run_all_migrations.sh [dev|prod]
# ============================================================================

set -e  # Exit on error

# Get environment argument
ENV="${1:-dev}"

# Set database URL based on environment
if [ "$ENV" = "prod" ]; then
  if [ -z "$PROD_DATABASE_URL" ]; then
    echo "❌ Error: PROD_DATABASE_URL environment variable not set"
    exit 1
  fi
  DATABASE_URL="$PROD_DATABASE_URL"
  echo "🚨 WARNING: Running migrations on PRODUCTION database!"
  echo "Press Ctrl+C within 10 seconds to cancel..."
  sleep 10
elif [ "$ENV" = "dev" ]; then
  if [ -z "$DEV_DATABASE_URL" ]; then
    echo "❌ Error: DEV_DATABASE_URL environment variable not set"
    exit 1
  fi
  DATABASE_URL="$DEV_DATABASE_URL"
  echo "✅ Running migrations on DEV database"
else
  echo "❌ Error: Invalid environment. Use 'dev' or 'prod'"
  exit 1
fi

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo ""
echo "================================================================================
Phase 0: Schema Simplification Migrations
================================================================================
"

# Run migrations in order
MIGRATIONS=(
  "000_create_enums.sql"
  "001_convert_users_to_uuid_pk.sql"
  "002_add_user_id_uuid_to_all_tables.sql"
  "003_convert_text_pks_to_bigserial.sql"
  "004_add_array_based_categories.sql"
  "005_drop_join_tables.sql"
  "006_convert_timestamps_to_naive.sql"
  "007_drop_rls_and_triggers.sql"
  "008_permissive_grants.sql"
  "009_verification_and_summary.sql"
)

for migration in "${MIGRATIONS[@]}"; do
  echo ""
  echo "────────────────────────────────────────────────────────────────────────────"
  echo "Running: $migration"
  echo "────────────────────────────────────────────────────────────────────────────"

  if psql "$DATABASE_URL" -f "$SCRIPT_DIR/$migration"; then
    echo "✅ $migration completed successfully"
  else
    echo "❌ $migration failed!"
    exit 1
  fi
done

echo ""
echo "================================================================================
🎉 All Phase 0 migrations completed successfully!
================================================================================
"

# Show final table list
echo "Final table structure:"
psql "$DATABASE_URL" -c "\dt"

echo ""
echo "To verify schema:"
echo "  psql \$${ENV^^}_DATABASE_URL -c '\d activities'"
echo "  psql \$${ENV^^}_DATABASE_URL -c '\d events'"
echo ""
