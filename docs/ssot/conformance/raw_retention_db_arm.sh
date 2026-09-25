#!/usr/bin/env bash
# raw-retention local-db conformance arm (real-payload-corpus@v1, recon W1).
#
# The slice's engine is a Postgres table + the callable sweep function — so the
# arm runs the REAL migrations in a local supabase Postgres and drives
# public.raw_retention_sweep(p_now) at synthetic clocks from the vectors.
# This is the codebase's first pg_cron job's local-CI story: the sweep BODY is
# exercised here with `now` injected; only the cron.schedule wrapper carries
# the wall clock, and it is not under test.
#
# Requirements: supabase CLI (`supabase db start`), docker, python3, psql.
# The database runs in an EPHEMERAL project dir so the app's full migration
# history is not replayed — the arm applies ONLY:
#   1. a stub schema (auth.uid/role stand-ins + the minimal neighbour tables
#      the migrations/function reference: users, integrations,
#      garmin_user_mappings, garmin_health_data)
#   2. the two bundle migrations, VERBATIM from the app checkout
#      (provider_raw_payloads + raw_retention_sweep)
# so the SQL under test is byte-identical to what ships.
#
# Invoked by run_dart.sh with:
#   $1 = absolute path to the ratified raw-retention vector file
#   $2 = APP_ROOT

set -euo pipefail
VECTORS="$1"
APP_ROOT="$2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

command -v supabase >/dev/null || { echo "ABORT: supabase CLI required"; exit 1; }
command -v python3  >/dev/null || { echo "ABORT: python3 required"; exit 1; }

MIG1="$APP_ROOT/supabase/migrations/20260920100000_provider_raw_payloads.sql"
MIG2="$APP_ROOT/supabase/migrations/20260920140000_raw_retention_sweep.sql"
[ -f "$MIG1" ] || { echo "ABORT: migration missing: $MIG1"; exit 1; }
[ -f "$MIG2" ] || { echo "ABORT: migration missing: $MIG2"; exit 1; }

WORKDIR="$(mktemp -d /tmp/qa-raw-retention.XXXXXX)"
cleanup() {
  (cd "$WORKDIR" && supabase stop --no-backup >/dev/null 2>&1) || true
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

echo "   arm:     local-db (supabase db start, ephemeral project)"
cd "$WORKDIR"
supabase init --force >/dev/null 2>&1 || supabase init >/dev/null
# Distinct project_id so containers never collide with the app's local stack.
sed -i '' 's/^project_id = .*/project_id = "qa-raw-retention"/' supabase/config.toml 2>/dev/null || \
  sed -i 's/^project_id = .*/project_id = "qa-raw-retention"/' supabase/config.toml
supabase db start >/dev/null

DB_URL="postgresql://postgres:postgres@127.0.0.1:54322/postgres"
PSQL=(psql "$DB_URL" -v ON_ERROR_STOP=1 -q)

"${PSQL[@]}" <<'SQL'
-- Stub schema: just enough for the real migrations to apply. The supabase
-- image ships auth.uid/auth.role (owned by supabase_admin — never touch
-- them); create stand-ins only on a bare Postgres where they are missing.
DO $do$
BEGIN
  IF to_regprocedure('auth.uid()') IS NULL THEN
    CREATE SCHEMA IF NOT EXISTS auth;
    CREATE FUNCTION auth.uid() RETURNS uuid
      LANGUAGE sql STABLE AS $f$ SELECT NULL::uuid $f$;
  END IF;
  IF to_regprocedure('auth.role()') IS NULL THEN
    CREATE FUNCTION auth.role() RETURNS text
      LANGUAGE sql STABLE AS $f$ SELECT 'service_role'::text $f$;
  END IF;
END;
$do$;
CREATE TABLE IF NOT EXISTS public.users (id UUID PRIMARY KEY);
CREATE TABLE IF NOT EXISTS public.integrations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider TEXT NOT NULL, is_active BOOLEAN NOT NULL DEFAULT true);
CREATE TABLE IF NOT EXISTS public.garmin_user_mappings (
  user_id UUID PRIMARY KEY);
CREATE TABLE IF NOT EXISTS public.garmin_health_data (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID, data_type TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  data JSONB NOT NULL DEFAULT '{}');
INSERT INTO public.users (id)
  VALUES ('00000000-0000-0000-0000-000000000001')
  ON CONFLICT DO NOTHING;
SQL

"${PSQL[@]}" -f "$MIG1"
"${PSQL[@]}" -f "$MIG2"
echo "   schema:  real migrations applied verbatim"

DB_URL="$DB_URL" VECTORS="$VECTORS" python3 "$SCRIPT_DIR/raw_retention_vectors.py"
