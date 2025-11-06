# Nutrition Plans Schema Sync Instructions

This directory contains SQL scripts to verify and sync the `nutrition_plans` table schema between DEV and PROD Supabase environments.

## Background

The local Drift database has these columns in `nutrition_plans`:
- `activity_id` - Links to calendar activities
- `plan_type` - Type of plan (standard/carb_loading/recovery)
- `sport_type` - Sport type (running, future: cycling/swimming)
- `needs_upload` - Offline-first sync flag
- `local_updated_at` - Conflict resolution timestamp

These columns must exist in both DEV and PROD Supabase for sync to work.

## Scripts

### 1. `verify_nutrition_plans_schema.sql`
**Purpose**: Check current state of the nutrition_plans table

**Run on both DEV and PROD** to see which columns exist.

```bash
# DEV
psql "$SUPABASE_DEV_DB_URL" -f database_schemas/v1/migrations/verify_nutrition_plans_schema.sql

# PROD
psql "$SUPABASE_PROD_DB_URL" -f database_schemas/v1/migrations/verify_nutrition_plans_schema.sql
```

**Output**: Shows all columns, constraints, and indexes. Look for ✓ or ✗ markers.

### 2. `sync_nutrition_plans_schema_to_prod.sql`
**Purpose**: Add missing columns to PROD (or DEV)

**IMPORTANT**:
- ✅ **Safe to run multiple times** (idempotent)
- ✅ Uses `IF NOT EXISTS` checks
- ✅ Wrapped in transaction (BEGIN/COMMIT)
- ✅ Includes verification at the end

```bash
# Apply to PROD (if columns are missing)
psql "$SUPABASE_PROD_DB_URL" -f database_schemas/v1/migrations/sync_nutrition_plans_schema_to_prod.sql

# Or apply to DEV (if needed)
psql "$SUPABASE_DEV_DB_URL" -f database_schemas/v1/migrations/sync_nutrition_plans_schema_to_prod.sql
```

## Step-by-Step Process

### Option 1: Using Supabase CLI (Recommended)

```bash
# 1. Verify current state
supabase db dump --linked --schema public --table nutrition_plans > /tmp/nutrition_plans_before.sql

# 2. Push migrations (this applies 20251106000000_add_plan_type_sport_type_to_nutrition_plans.sql)
supabase db push --include-all

# 3. Verify columns were added
supabase db execute "
  SELECT column_name, data_type, column_default
  FROM information_schema.columns
  WHERE table_name = 'nutrition_plans'
  ORDER BY ordinal_position;
"

# 4. Schema cache usually auto-refreshes in ~10 seconds
# Or force refresh with:
supabase db execute "NOTIFY pgrst, 'reload schema';"
```

### Option 2: Using Direct SQL (If CLI unavailable)

```bash
# 1. Run verification script
psql "$SUPABASE_PROD_DB_URL" -f database_schemas/v1/migrations/verify_nutrition_plans_schema.sql > /tmp/verify_output.txt

# 2. Check output for missing columns
cat /tmp/verify_output.txt

# 3. If columns are missing, run sync script
psql "$SUPABASE_PROD_DB_URL" -f database_schemas/v1/migrations/sync_nutrition_plans_schema_to_prod.sql

# 4. Force schema cache refresh
psql "$SUPABASE_PROD_DB_URL" -c "NOTIFY pgrst, 'reload schema';"

# 5. Verify again
psql "$SUPABASE_PROD_DB_URL" -f database_schemas/v1/migrations/verify_nutrition_plans_schema.sql
```

## What Gets Added

### Columns
| Column | Type | Default | Purpose |
|--------|------|---------|---------|
| `activity_id` | TEXT | NULL | Foreign key to activities.id |
| `plan_type` | TEXT | 'standard' | Plan type (standard/carb_loading/recovery) |
| `sport_type` | TEXT | 'running' | Sport type (future multi-sport support) |
| `needs_upload` | BOOLEAN | false | Offline-first sync flag |
| `local_updated_at` | TIMESTAMP | CURRENT_TIMESTAMP | Conflict resolution timestamp |

### Constraints
- `nutrition_plans_plan_type_check` - Ensures plan_type is valid
- `fk_nutrition_plans_activity_id` - Foreign key to activities table

### Indexes
- `idx_nutrition_plans_activity_id` - Fast activity_id lookups
- `idx_nutrition_plans_needs_upload` - Partial index for sync queries

## Verification

After running the sync script, verify:

```sql
-- Check column count (should have these 5 new columns + existing columns)
SELECT COUNT(*)
FROM information_schema.columns
WHERE table_name = 'nutrition_plans';

-- Check specific columns exist
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'nutrition_plans'
  AND column_name IN ('activity_id', 'plan_type', 'sport_type', 'needs_upload', 'local_updated_at')
ORDER BY column_name;

-- Should return 5 rows
```

## Troubleshooting

### PostgREST Schema Cache Issues

If you still get "Could not find column" errors after running migrations:

```sql
-- Force PostgREST to reload schema
NOTIFY pgrst, 'reload schema';
```

Or wait 10 seconds (PostgREST auto-refreshes every 10s by default).

### Rollback (If needed)

The sync script is wrapped in a transaction. If it fails, it will automatically rollback.

To manually remove columns (⚠️ DESTRUCTIVE):

```sql
BEGIN;

ALTER TABLE nutrition_plans DROP COLUMN IF EXISTS activity_id CASCADE;
ALTER TABLE nutrition_plans DROP COLUMN IF EXISTS plan_type;
ALTER TABLE nutrition_plans DROP COLUMN IF EXISTS sport_type;
ALTER TABLE nutrition_plans DROP COLUMN IF EXISTS needs_upload;
ALTER TABLE nutrition_plans DROP COLUMN IF EXISTS local_updated_at;

COMMIT;
```

## Environment Variables

Make sure you have these set:

```bash
# DEV
export SUPABASE_DEV_DB_URL="postgresql://postgres:[PASSWORD]@db.[DEV-PROJECT-ID].supabase.co:5432/postgres"

# PROD
export SUPABASE_PROD_DB_URL="postgresql://postgres:[PASSWORD]@db.[PROD-PROJECT-ID].supabase.co:5432/postgres"
```

Or use the Supabase CLI which handles this automatically with `--linked`.

## Next Steps After Sync

1. ✅ Restart your Flutter app
2. ✅ Test nutrition plan sync
3. ✅ Check logs for any remaining errors
4. ✅ Verify data syncs correctly between Drift and Supabase

## Support

If you encounter issues:
1. Check the verification script output
2. Look for error messages in the sync script output
3. Check Supabase logs in the dashboard
4. Verify migrations were applied: `supabase migration list`
