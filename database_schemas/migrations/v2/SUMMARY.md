# Phase 0 Complete - Ready to Execute! 🚀

## What I've Created for You

### 1. Complete SQL Migration File ⭐
**File:** `PHASE_0_ALL_MIGRATIONS.sql`

This is your **ONE-STOP** migration file. Just copy/paste into Supabase SQL Editor and run.

- ✅ All 9 migration steps in one file
- ✅ Idempotent (safe to re-run)
- ✅ Transaction-wrapped (all-or-nothing)
- ✅ Built-in verification
- ✅ Clear success messages

### 2. Drift Update Instructions
**File:** `DRIFT_UPDATES_PHASE_0.md`

Step-by-step instructions to update your Flutter/Drift schema after SQL migrations complete.

### 3. Individual Migration Files (Optional)
**Files:** `000_*.sql` through `009_*.sql`

If you prefer to run migrations one-by-one, these are available.

### 4. Quick Reference
**File:** `README.md`

Quick reference guide for the entire Phase 0 process.

## Your Action Items

### Step 1: Run SQL on Dev (YOU DO THIS)
1. Open Supabase Dashboard → Dev project
2. Go to SQL Editor
3. Copy/paste **entire contents** of `PHASE_0_ALL_MIGRATIONS.sql`
4. Click "Run"
5. Check for success messages

### Step 2: Test in Dev (2+ days)
- Create activities with new schema
- Verify IDs are integers
- Test app functionality
- Check for errors

### Step 3: Update Drift Schema (AFTER SQL)
Follow instructions in `DRIFT_UPDATES_PHASE_0.md`:
1. Update table classes (`lib/shared/database/tables/*.dart`)
2. Change `text()` → `integer().autoIncrement()` for IDs
3. Update domain models (`id: int` instead of `id: String`)
4. Regenerate code: `dart run build_runner build --delete-conflicting-outputs`
5. Update schema: `dart run drift_dev schema dump lib/shared/database/app_database.dart database_schemas/v1/`

### Step 4: Run SQL on Prod (AFTER DEV TESTING)
Same process as Step 1, but on Prod project

### Step 5: Mark as Complete
When done, let me know and we'll move to Phase 1!

## What Changes in the Database

### Primary Keys Converted
| Table | BEFORE | AFTER |
|-------|--------|-------|
| `activities.id` | TEXT | BIGSERIAL (auto-increment) |
| `events.id` | TEXT | BIGSERIAL |
| `carb_loading_plans.id` | TEXT | BIGSERIAL |
| `carb_loading_days.id` | TEXT | BIGSERIAL |
| `workout_notes.id` | TEXT | BIGSERIAL |
| `feature_survey_responses.id` | TEXT | BIGSERIAL |

### User Identity
| Table | BEFORE | AFTER |
|-------|--------|-------|
| `users.id` | UUID ✓ | UUID ✓ (no change) |
| `activities.user_id` | TEXT (device_id) | UUID (users.id FK) |
| `events.user_id` | TEXT | UUID |
| All user-scoped tables | TEXT | UUID FK |

### Categories System
| BEFORE | AFTER |
|--------|-------|
| `food_categories` join table | DROPPED ❌ |
| `categories` table | DROPPED ❌ |
| `meal_types` table | DROPPED ❌ |
| 3 more join tables | DROPPED ❌ |
| `foods.categories` | ✅ `category_enum[]` array |

### Security (Dev Posture)
| Feature | Status |
|---------|--------|
| RLS (Row Level Security) | DISABLED ⚠️ |
| RLS Policies | DROPPED ⚠️ |
| Update Triggers | DROPPED ⚠️ |
| Permissions | WIDE OPEN ⚠️ |

**Note:** Security will be re-added before production launch

## Breaking Changes ⚠️

### For Your App
1. **IDs are now `int` not `String`**
   - Update all ID references in Dart code
   - Update API calls expecting string IDs

2. **user_id is now UUID not device_id**
   - Update user lookups
   - Foreign keys now reference `users.id` not text device_id

3. **Local database will be reset**
   - Users will need to re-sync data
   - Fresh install recommended

### Not Breaking
- ✅ `users.id` already was UUID (no change)
- ✅ `device_id` still exists for current auth
- ✅ All data structures preserved
- ✅ API contracts preserved (just ID types changed)

## Verification Queries

Run these in Supabase SQL Editor after migration:

```sql
-- ✓ Check activities.id is BIGINT
SELECT data_type FROM information_schema.columns
WHERE table_name = 'activities' AND column_name = 'id';
-- Expected: bigint

-- ✓ Check user_id is UUID
SELECT data_type FROM information_schema.columns
WHERE table_name = 'activities' AND column_name = 'user_id';
-- Expected: uuid

-- ✓ Check join tables dropped
SELECT tablename FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('food_categories', 'categories', 'meal_types');
-- Expected: 0 rows

-- ✓ Check RLS disabled
SELECT COUNT(*) FROM pg_tables t
JOIN pg_class c ON c.relname = t.tablename
WHERE t.schemaname = 'public' AND c.relrowsecurity = true;
-- Expected: 0

-- ✓ Check enums created
SELECT typname FROM pg_type WHERE typname LIKE '%_enum';
-- Expected: 12+ rows
```

## Files Summary

| File | Size | Purpose |
|------|------|---------|
| `PHASE_0_ALL_MIGRATIONS.sql` | ~850 lines | **RUN THIS** - Complete migration |
| `DRIFT_UPDATES_PHASE_0.md` | ~400 lines | **READ THIS** - Drift updates |
| `README.md` | ~200 lines | Quick reference |
| `SUMMARY.md` | This file | Overview |
| `000-009_*.sql` | 10 files | Individual migrations (optional) |
| `run_all_migrations.sh` | Bash script | Alternative to SQL file |

## Timeline

- **Phase 0 Creation**: ✅ COMPLETE (today)
- **Phase 0 SQL Execution**: ⏳ YOU DO THIS (30 minutes)
- **Dev Testing**: ⏳ YOU DO THIS (2+ days)
- **Drift Updates**: ⏳ YOU DO THIS (2-3 hours)
- **Prod Execution**: ⏳ YOU DO THIS (after Dev testing)
- **Phase 1**: Coming next!

## Questions?

If you run into issues:
1. Check the migration output for error messages
2. Run verification queries above
3. Check Supabase logs
4. Review `/docs/refactoring/complete-migration-roadmap.md` for full context

## Ready to Go! 🎉

You have everything you need:
- ✅ SQL migrations ready to run
- ✅ Drift update instructions ready
- ✅ Verification queries ready
- ✅ Documentation complete

**Next:** Run `PHASE_0_ALL_MIGRATIONS.sql` in Dev Supabase SQL Editor!
