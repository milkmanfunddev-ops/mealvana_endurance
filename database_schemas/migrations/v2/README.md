# Phase 0 Schema Simplification Migrations

## Quick Start

### Run SQL Migrations

1. **Open Supabase SQL Editor** for Dev environment
2. **Copy and paste** `PHASE_0_ALL_MIGRATIONS.sql` into SQL Editor
3. **Execute** the entire file
4. **Verify** completion messages
5. **Wait 2+ days** and test thoroughly in Dev
6. **Repeat steps 1-4** for Prod environment

### Update Drift Schema

After SQL migrations are complete:

1. **Follow instructions** in `DRIFT_UPDATES_PHASE_0.md`
2. **Update table definitions** in `lib/shared/database/tables/`
3. **Update domain models** to use `int` IDs
4. **Regenerate code**: `dart run build_runner build --delete-conflicting-outputs`
5. **Update schema snapshot**: `dart run drift_dev schema dump lib/shared/database/app_database.dart database_schemas/v1/`
6. **Test**: `flutter analyze`

## Files in this Directory

| File | Purpose |
|------|---------|
| `PHASE_0_ALL_MIGRATIONS.sql` | **RUN THIS** - Complete Phase 0 SQL in one file |
| `DRIFT_UPDATES_PHASE_0.md` | **READ THIS** - Drift schema update instructions |
| `README.md` | This file - quick reference |
| `000_create_enums.sql` | Individual migration: Create enums |
| `001_convert_users_to_uuid_pk.sql` | Individual migration: Verify users.id UUID |
| `002_add_user_id_uuid_to_all_tables.sql` | Individual migration: Add UUID user_id |
| `003_convert_text_pks_to_bigserial.sql` | Individual migration: TEXT → BIGSERIAL |
| `004_add_array_based_categories.sql` | Individual migration: Array categories |
| `005_drop_join_tables.sql` | Individual migration: Drop join tables |
| `006_convert_timestamps_to_naive.sql` | Individual migration: TIMESTAMPTZ → TIMESTAMP |
| `007_drop_rls_and_triggers.sql` | Individual migration: Drop security |
| `008_permissive_grants.sql` | Individual migration: Grant permissions |
| `009_verification_and_summary.sql` | Individual migration: Verify changes |
| `run_all_migrations.sh` | **ALTERNATIVE** - Bash script to run via psql |

## What Phase 0 Does

### Schema Changes

- ✅ Creates PostgreSQL enums for type safety
- ✅ Verifies `users.id` is UUID primary key
- ✅ Adds `user_id (UUID)` foreign keys to all user-scoped tables
- ✅ Converts `activities.id` from TEXT → BIGSERIAL
- ✅ Converts `events.id` from TEXT → BIGSERIAL
- ✅ Converts `carb_loading_plans.id` from TEXT → BIGSERIAL
- ✅ Converts `carb_loading_days.id` from TEXT → BIGSERIAL
- ✅ Adds array-based categories to `foods` (no more join tables!)
- ✅ Drops 6 join tables (`food_categories`, `categories`, `meal_types`, etc.)
- ✅ Converts TIMESTAMPTZ → naive TIMESTAMP (UTC)

### Security Changes (Dev Posture)

- ⚠️ Disables RLS on all tables
- ⚠️ Drops all RLS policies
- ⚠️ Drops update triggers
- ⚠️ Grants broad permissions to anon/authenticated/service_role

**NOTE:** Security will be re-added before production launch

## Verification

After running migrations, verify:

```sql
-- Check activities.id is BIGINT
SELECT data_type FROM information_schema.columns
WHERE table_name = 'activities' AND column_name = 'id';
-- Should return: bigint

-- Check activities.user_id is UUID
SELECT data_type FROM information_schema.columns
WHERE table_name = 'activities' AND column_name = 'user_id';
-- Should return: uuid

-- Check join tables are dropped
SELECT COUNT(*) FROM pg_tables
WHERE schemaname = 'public' AND tablename IN (
  'food_categories', 'categories', 'meal_types'
);
-- Should return: 0

-- Check RLS is disabled
SELECT COUNT(*) FROM pg_tables t
JOIN pg_class c ON c.relname = t.tablename
WHERE t.schemaname = 'public' AND c.relrowsecurity = true;
-- Should return: 0
```

## Rollback Plan

If something goes wrong:

1. **Restore from backup** taken before migration
2. **Or** use Supabase dashboard to restore to point-in-time before migration
3. **Wait** for Phase 1 before making Drift changes (keep old schema)

## Next Steps

After Phase 0 is complete and tested:

1. **Phase 1**: Embed nutrition data in activities (see `/docs/refactoring/complete-migration-roadmap.md`)
2. **Phase 2**: Batch sync architecture
3. **Phase 3**: Client refactoring
4. **Phase 4**: Cleanup

## Support

If you encounter issues:

1. Check migration output for error messages
2. Review verification queries above
3. Consult `/docs/refactoring/complete-migration-roadmap.md` for detailed context
4. Check Supabase logs for detailed error messages
