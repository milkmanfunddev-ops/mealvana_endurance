# Phase 0 Schema Simplification - Execution Log

**Date:** 2025-01-07
**Status:** SQL Ready - Awaiting Execution
**Version:** v1 (schema update, NOT v2)

---

## Summary

This document captures the creation and execution plan for Phase 0 of the complete schema simplification migration outlined in [complete-migration-roadmap.md](./complete-migration-roadmap.md).

### What Was Created

A single, destructive SQL migration file that:
- Drops and recreates tables with BIGSERIAL primary keys
- Converts user_id columns from TEXT to UUID foreign keys
- Drops join tables and replaces with PostgreSQL arrays
- Removes all RLS policies and triggers (dev posture)
- Drops the `edge_functions` metadata table

**Key Decision:** This is a **destructive migration** with **NO data migration**. All data in affected tables will be lost and recreated fresh.

---

## Migration File

**Location:** [/database_schemas/migrations/PHASE_0_SCHEMA_SIMPLIFICATION.sql](/database_schemas/migrations/PHASE_0_SCHEMA_SIMPLIFICATION.sql)

**Important:** We are **staying on v1 schema**. This migration updates the v1 baseline, does NOT create a v2.

---

## What Phase 0 Does

### Tables Dropped and Recreated (BIGSERIAL PKs)

All data in these tables will be **LOST**:

| Table | Old PK | New PK | Old user_id | New user_id |
|-------|--------|--------|-------------|-------------|
| `activities` | TEXT | BIGSERIAL | TEXT (device_id) | UUID FK |
| `events` | TEXT | BIGSERIAL | TEXT | UUID FK |
| `carb_loading_plans` | TEXT | BIGSERIAL | TEXT | UUID FK |
| `carb_loading_days` | TEXT | BIGSERIAL | TEXT | BIGINT FK (to plans) |
| `workout_notes` | TEXT | BIGSERIAL | TEXT | UUID FK |
| `feature_survey_responses` | TEXT | BIGSERIAL | TEXT | UUID FK |

### Tables Dropped Completely

These tables are **permanently removed**:
- `food_categories` (join table)
- `user_food_categories` (join table)
- `categories` (join table)
- `meal_types` (join table)
- `carb_loading_food_meal_types` (join table)
- `carb_loading_user_food_meal_types` (join table)
- `edge_functions` (metadata table - not needed)

### Array Columns Added

| Table | New Columns |
|-------|-------------|
| `foods` | `categories category_enum[]`, `activity_types sport_enum[]` |
| `user_foods` | `categories category_enum[]`, `activity_types sport_enum[]` |
| `carb_loading_foods` | `meal_types TEXT[]` |
| `carb_loading_user_foods` | `meal_types TEXT[]` |

### Existing Tables Modified (user_id → UUID)

| Table | Change |
|-------|--------|
| `user_foods` | Drop old user_id, add UUID FK to users.id |
| `user_hidden_foods` | Drop old user_id, add UUID FK to users.id |
| `carb_loading_user_foods` | Drop old user_id, add UUID FK to users.id |

### Enums Created

12+ PostgreSQL enums for type safety:
- `gender_enum`
- `distance_unit_enum`
- `pace_unit_enum`
- `gut_training_enum`
- `sport_enum`
- `activity_status_enum`
- `intensity_enum`
- `cycling_terrain_enum`
- `cycling_indoor_outdoor_enum`
- `cycling_session_goal_enum`
- `swimming_pool_open_water_enum`
- `category_enum`

### Security Changes (Dev Posture)

⚠️ **All security removed for fast iteration:**
- RLS disabled on all tables
- All RLS policies dropped
- All update triggers dropped
- Permissive grants to anon/authenticated/service_role

**Note:** Security will be re-added before production launch

---

## Execution Steps

### Step 1: Run SQL on Dev

1. Open [Supabase Dashboard](https://supabase.com/dashboard) → Dev Project
2. Navigate to SQL Editor
3. Copy entire contents of `PHASE_0_SCHEMA_SIMPLIFICATION.sql`
4. Paste into SQL Editor
5. Click "Run"
6. Verify success messages

**Expected Output:**
```
✓ Step 1: Enums created
✓ Step 2: Join tables and edge_functions dropped
✓ Step 3: Activities table recreated with BIGSERIAL PK
✓ Step 4: Events table recreated
✓ Step 5: Carb loading plans table recreated
✓ Step 6: Carb loading days table recreated
✓ Step 7: Workout notes table recreated
✓ Step 8: Feature survey responses table recreated
✓ Step 9: Array-based categories added to foods tables
✓ Step 10: user_id (UUID) added to remaining tables
✓ Step 11: RLS and triggers dropped
✓ Step 12: Permissive grants applied
✓ Enums verified
✓ activities.id is BIGINT
✓ activities.user_id is UUID
✓ All join tables and edge_functions dropped
🎉 PHASE 0 MIGRATION COMPLETE!
```

### Step 2: Verify Schema

Run these verification queries in Supabase SQL Editor:

```sql
-- Check activities table
\d activities

-- Verify BIGINT PK
SELECT data_type FROM information_schema.columns
WHERE table_name = 'activities' AND column_name = 'id';
-- Expected: bigint

-- Verify UUID FK
SELECT data_type FROM information_schema.columns
WHERE table_name = 'activities' AND column_name = 'user_id';
-- Expected: uuid

-- Check join tables dropped
SELECT COUNT(*) FROM pg_tables
WHERE schemaname = 'public' AND tablename IN (
  'food_categories', 'categories', 'meal_types', 'edge_functions'
);
-- Expected: 0

-- Check RLS disabled
SELECT COUNT(*) FROM pg_tables t
JOIN pg_class c ON c.relname = t.tablename
WHERE t.schemaname = 'public' AND c.relrowsecurity = true;
-- Expected: 0
```

### Step 3: Update Drift Schema

Follow instructions in [DRIFT_UPDATES_PHASE_0.md](/database_schemas/migrations/v2/DRIFT_UPDATES_PHASE_0.md)

**Key changes in Drift:**
```dart
// BEFORE
TextColumn get id => text().primaryKey()();
TextColumn get userId => text().named('user_id')();

// AFTER
IntColumn get id => integer().autoIncrement()();  // BIGSERIAL
TextColumn get userId => text().named('user_id')();  // UUID as string
```

**Files to update:**
- `lib/shared/database/tables/activities_table.dart`
- `lib/shared/database/tables/events_table.dart`
- `lib/shared/database/tables/carb_loading_plans_table.dart`
- `lib/shared/database/tables/carb_loading_days_table.dart`
- `lib/shared/database/tables/workout_notes_table.dart`
- `lib/shared/database/tables/feature_survey_responses_table.dart`

### Step 4: Update Domain Models

**Change IDs from String to int:**

```dart
// BEFORE
class Activity {
  final String id;
  final String userId;
  // ...
}

// AFTER
class Activity {
  final int id;  // ← Changed
  final String userId;  // ← Still String (UUID stored as text)
  // ...
}
```

**Files to update:**
- `lib/features/activities/domain/activity.dart`
- `lib/features/events/domain/event.dart`
- `lib/features/carb_loading/domain/carb_loading_plan.dart`
- All repository methods that accept IDs

### Step 5: Regenerate Code

```bash
# Clean old generated files
rm lib/shared/database/app_database.g.dart
rm lib/shared/database/tables/*.g.dart

# Regenerate
dart run build_runner build --delete-conflicting-outputs

# Update v1 schema snapshot (OVERWRITES v1, NOT creating v2)
dart run drift_dev schema dump lib/shared/database/app_database.dart database_schemas/v1/

# Verify no errors
flutter analyze
```

### Step 6: Test in Dev

**Test checklist:**
- [ ] App launches without errors
- [ ] Can create new activities (expect empty state)
- [ ] Activities have integer IDs
- [ ] No data from before migration (expected)
- [ ] Sync works (to empty state)

**Expected:** All local data will be cleared. Users will see empty state and need to create new activities.

### Step 7: Run on Prod (After 2+ Days Dev Testing)

1. Repeat Steps 1-2 on **Prod** Supabase project
2. Monitor for issues
3. Verify app works with new schema

---

## Breaking Changes

### For Flutter App

1. **All IDs are now `int` not `String`**
   - Update all domain models
   - Update all repository methods
   - Update all UI code that references IDs

2. **user_id is now UUID not device_id**
   - Foreign keys now reference `users.id` (UUID)
   - `device_id` still exists on users table for auth

3. **Local database will be cleared**
   - All Drift data will be reset
   - Users will see empty state
   - Need to re-sync from server (which is also empty)

### For Edge Functions

1. **Update request/response types:**
   ```typescript
   // BEFORE
   interface SaveActivityRequest {
     id: string;  // TEXT
     user_id: string;  // device_id
   }

   // AFTER
   interface SaveActivityRequest {
     id: number;  // BIGINT
     user_id: string;  // UUID
   }
   ```

2. **Update Supabase queries:**
   ```typescript
   // BEFORE
   const { data } = await supabase
     .from('activities')
     .select('*')
     .eq('id', activityId);  // activityId is string

   // AFTER
   const { data } = await supabase
     .from('activities')
     .select('*')
     .eq('id', activityId);  // activityId is number
   ```

---

## What Was NOT Done (Future Phases)

Phase 0 does **NOT** include:

- ❌ Embedding nutrition data in activities (Phase 1)
- ❌ Dropping nutrition_plans table (Phase 1)
- ❌ Batch sync Edge Function (Phase 2)
- ❌ Client refactoring to remove NutritionPlanController (Phase 3)
- ❌ Cleanup of deprecated Edge Functions (Phase 4)

These are coming in future phases.

---

## Issues Encountered During Creation

### Issue 1: edge_functions Table Confusion

**Problem:** Initial migration tried to convert timestamps on `edge_functions.last_called_at` column that doesn't exist.

**Root Cause:** The migration script incorrectly assumed `edge_functions` had a `last_called_at` column when it only has `created_at` and `updated_at`.

**Resolution:** Removed `edge_functions` table entirely. It was a metadata table for storing Edge Function info and not needed for the migration goals.

### Issue 2: v2 vs v1 Confusion

**Problem:** Initially created migrations in a `v2` folder, implying schema version bump.

**Root Cause:** Misunderstanding - this is a **schema simplification** that updates v1, not a version bump to v2.

**Resolution:**
- Moved migration to `/database_schemas/migrations/PHASE_0_SCHEMA_SIMPLIFICATION.sql`
- After running, will regenerate v1 snapshot (overwrites existing v1)
- No v2 schema needed - we're updating the v1 baseline

### Issue 3: Data Migration Expectations

**Problem:** Initial script tried to migrate data from old tables to new tables.

**Root Cause:** Unclear whether we wanted to preserve data or do fresh start.

**Resolution:** Decided on **destructive migration** - drop tables, recreate fresh, no data preservation. Simpler and cleaner for this stage of development.

---

## Files Created

| File | Purpose | Keep? |
|------|---------|-------|
| `/database_schemas/migrations/PHASE_0_SCHEMA_SIMPLIFICATION.sql` | **Main migration file** | ✅ USE THIS |
| `/database_schemas/migrations/README.md` | Migration instructions | ✅ Keep |
| `/database_schemas/migrations/v2/PHASE_0_ALL_MIGRATIONS.sql` | Old version with data migration | ❌ Ignore |
| `/database_schemas/migrations/v2/000-009_*.sql` | Individual migration files | ❌ Ignore |
| `/database_schemas/migrations/v2/DRIFT_UPDATES_PHASE_0.md` | Drift update instructions | ✅ Keep (still valid) |
| `/database_schemas/migrations/v2/README.md` | Old readme | ❌ Ignore |
| `/database_schemas/migrations/v2/SUMMARY.md` | Old summary | ❌ Ignore |
| `/database_schemas/migrations/v2/run_all_migrations.sh` | Bash script | ❌ Ignore |

---

## Next Steps After Phase 0

Once Phase 0 is complete and tested:

1. **Phase 1: Embed & Simplify Nutrition** (3-4 days)
   - Add nutrition columns to activities table
   - Drop nutrition_plans table
   - Update client to use embedded nutrition

2. **Phase 2: Batch Sync Architecture** (3-4 days)
   - Create sync-push-changes Edge Function
   - Replace individual save-* functions with batch upload

3. **Phase 3: Client Refactoring** (5-7 days)
   - Delete NutritionPlanController
   - Refactor ActivityDetailController
   - Update all UI screens

4. **Phase 4: Cleanup & Optimization** (2-3 days)
   - Delete deprecated Edge Functions
   - Clean up old nutrition files
   - Update documentation

See [complete-migration-roadmap.md](./complete-migration-roadmap.md) for full details.

---

## Success Criteria

Phase 0 is complete when:

- ✅ SQL migration runs successfully on Dev
- ✅ Schema verified (BIGINT PKs, UUID FKs, arrays, no join tables)
- ✅ Drift schema updated and code regenerated
- ✅ v1 schema snapshot regenerated
- ✅ App runs with new schema (empty state expected)
- ✅ Dev testing passes (2+ days)
- ✅ SQL migration runs successfully on Prod
- ✅ Prod app works with new schema

---

## Rollback Plan

If something goes wrong:

### Option 1: Restore from Backup
```bash
# Supabase Dashboard → Database → Backups
# Restore to point-in-time before migration
```

### Option 2: Revert Code Changes
```bash
# Restore old Drift schema
git checkout HEAD~1 -- lib/shared/database/tables/

# Restore old domain models
git checkout HEAD~1 -- lib/features/activities/domain/activity.dart
git checkout HEAD~1 -- lib/features/events/domain/event.dart

# Regenerate
dart run build_runner build --delete-conflicting-outputs
```

### Option 3: Re-run Old Schema
Keep a copy of the old v1 schema SQL and re-run if needed.

---

## Timeline

- **Phase 0 Creation:** ✅ Complete (2025-01-07)
- **Dev Execution:** ⏳ Awaiting (you do this, ~30 minutes)
- **Dev Testing:** ⏳ Awaiting (you do this, 2+ days)
- **Drift Updates:** ⏳ Awaiting (you do this, 2-3 hours)
- **Prod Execution:** ⏳ Awaiting (after Dev passes)
- **Phase 1 Start:** ⏳ After Phase 0 complete

**Total Estimated Time:** 3-4 days for complete Phase 0

---

## Contact & Questions

If issues arise:
1. Check Supabase logs for detailed error messages
2. Run verification queries (see Step 2)
3. Review [complete-migration-roadmap.md](./complete-migration-roadmap.md) for context
4. Check [DRIFT_UPDATES_PHASE_0.md](/database_schemas/migrations/v2/DRIFT_UPDATES_PHASE_0.md) for Dart/Drift changes

---

**Last Updated:** 2025-01-07
**Status:** Ready for execution
**Risk Level:** High (destructive migration, data loss expected)
**Reversible:** Yes (via backup restore)
