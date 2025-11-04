# Production vs Development Schema Differences

**Date**: 2025-10-30
**Status**: Migration created - ready to apply
**Migration File**: `/supabase/migrations/20251030000010_sync_prod_to_dev_complete.sql`

## Executive Summary

PROD and DEV schemas have **significantly diverged**. The DEV schema is much more sophisticated with better normalization, detailed tracking, and user-based RLS. This migration will:

- ✅ Preserve existing data where possible
- ⚠️ **DESTRUCTIVE**: Some tables will be dropped and recreated
- 🔧 Requires edge function updates after migration

---

## Critical Breaking Changes

### 1. **`activities` Table**
**IMPACT**: 🔴 **HIGH** - Edge functions need updates

| What Changed | PROD | DEV | Action |
|-------------|------|-----|--------|
| Primary user identifier | `device_id` | `user_id` | Backfilled from users table |
| Date column | `scheduled_date` | `scheduled_date_time` | Data migrated |
| Pace column | `pace_minutes_per_mile` | `pace_target_minutes_per_mile` | Data migrated |
| Intensity | `intensity_target` | `intensity_level` | Data migrated |
| New columns | N/A | `title`, completion tracking, reminders, `notes`, `deleted_at` | Added |
| Cycling/Swimming columns | ✅ Present | ❌ Missing | **PROD has extra columns!** |

**Required Edge Function Updates**:
- `save-calendar-activity`: Change `device_id` → `user_id`
- Update all INSERT statements to use new column names

### 2. **`events` Table**
**IMPACT**: 🔴 **HIGH** - Complete restructure

| Aspect | PROD | DEV |
|--------|------|-----|
| Columns | 8 (simple) | 21 (detailed) |
| Structure | Standalone with `device_id` | Linked to `activities` via FK |
| RLS | device-based | activity-based (cascading) |
| Race details | Minimal | Rich (goals, logistics, results) |

**Migration Strategy**: Drop & recreate, migrate basic data only

### 3. **Carb Loading System**
**IMPACT**: 🟡 **MEDIUM** - ID type changes

**Key Changes**:
- `meal_types.id`: `text` → `integer`
- `carb_loading_foods.id`: `text` → `uuid`
- `carb_loading_user_foods.id`: `text` → `uuid`
- `carb_loading_days`: Added meal split percentages (breakfast 25%, lunch 25%, etc.)

### 4. **`macro_targets_table`**
**IMPACT**: 🟡 **MEDIUM** - Complete column set change

| Aspect | PROD | DEV |
|--------|------|-----|
| Columns | 14 (basic) | 26 (detailed) |
| Purpose | Simple macro storage | Detailed pre/during/post run targets |
| Constraints | Minimal | Extensive CHECK constraints on every numeric field |

---

## Tables Modified

### ✅ **Additive Changes** (Safe)

1. **`users`**
   - Added: `preferred_sports`, `cycling_ftp_watts`, `prefers_cycling_power`, `swimming_css_seconds_per_100m`, `prefers_swimming_pace`

2. **`foods`**
   - Added: `cycling_suitable`, `swimming_suitable`, `suitable_for_activities`

3. **`user_foods`**
   - Added: `cycling_suitable`, `swimming_suitable`, `suitable_for_activities`

4. **`nutrition_plans`**
   - Added: FK constraint to `activities.id`
   - Removed: `user_id` column (not in DEV)

### ⚠️ **Destructive Changes** (Data Loss Possible)

Tables that will be **dropped and recreated**:

1. **`events`** - Complete restructure, basic data migrated
2. **`carb_loading_plans`** - ID type changes, data migrated with estimates
3. **`carb_loading_days`** - Structure changes, data migrated
4. **`carb_loading_foods`** - ID type change (text → uuid), **data lost**
5. **`carb_loading_user_foods`** - ID type change, **data lost**
6. **`meal_types`** - ID type change, reseeded with standard meals
7. **`carb_loading_food_meal_types`** - Junction table recreated
8. **`carb_loading_user_food_meal_types`** - Junction table recreated
9. **`carb_loading_day_meals`** - Structure changes
10. **`activity_completions`** - Simplified, made 1:1 with activities
11. **`macro_targets_table`** - Complete restructure
12. **`workout_notes`** - Changed to reference `users.id` (UUID) instead of `device_id`

---

## Data Migration Strategy

### ✅ **Preserved Data**

- `users` - All data kept, new columns added
- `foods` - All data kept, new columns added
- `nutrition_plans` - All data kept, FK added
- `activities` - All data kept, columns renamed/added, `user_id` backfilled

### 🔄 **Migrated with Transformations**

- `events` - Basic fields (id, name, dates, flags) migrated
- `carb_loading_plans` - Converted with estimated values for new required fields
- `carb_loading_days` - Migrated with default meal percentages

### ❌ **Data Lost**

- `carb_loading_foods` - Can't convert text IDs to UUIDs
- `carb_loading_user_foods` - Can't convert text IDs to UUIDs
- `macro_targets_table` - Incompatible structure
- Any references to above tables in junction tables

---

## Post-Migration Required Actions

### 1. **Update Edge Functions** (Critical!)

**File: `/supabase/functions/save-calendar-activity/index.ts`**

```typescript
// OLD (PROD):
device_id: device_id,
scheduled_date: activity.scheduledDate,
pace_minutes_per_mile: activity.paceMinutesPerMile,
intensity_target: activity.intensityTarget

// NEW (DEV):
user_id: deviceData.id,  // From users.id, not device_id!
scheduled_date_time: activity.scheduledDateTime,
pace_target_minutes_per_mile: activity.paceTargetMinutesPerMile,
intensity_level: activity.intensityLevel
```

**File: `/supabase/functions/save-calendar-event/index.ts`**
- Completely rewrite to handle new events structure
- Must set `activity_id` FK
- Handle new event detail columns

### 2. **Update RLS Policies**

All RLS policies have changed from `device_id`-based to `user_id`-based:

```sql
-- OLD:
device_id = ((current_setting('request.jwt.claims', true))::json ->> 'device_id')

-- NEW:
user_id = current_setting('app.user_id', true)
```

### 3. **Reseed Reference Data**

After migration, reseed:
- `carb_loading_foods` - Default carb loading food options
- `carb_loading_food_meal_types` - Link foods to meal types

### 4. **Test Critical Paths**

- ✅ Create activity
- ✅ Create event linked to activity
- ✅ Generate nutrition plan for activity
- ✅ Create carb loading plan for event
- ✅ Add meals to carb loading days

---

## Running the Migration

### ⚠️ **IMPORTANT: Backup First!**

```bash
# Dump current PROD data
supabase link --project-ref wvmvsodrvbkxfydabqed
supabase db dump --linked > prod_backup_2025-10-30.sql
```

### Apply Migration

```bash
# Link to PROD
supabase link --project-ref wvmvsodrvbkxfydabqed

# Apply migration
supabase db push --linked

# Check result
supabase migration list --linked
```

### Verify

```bash
# Check table count
supabase db dump --linked --schema public 2>/dev/null | grep -c 'CREATE TABLE'
# Should show 26 tables

# Check activities table structure
psql -h ... -c "\d activities"
```

---

## Rollback Plan

If migration fails:

```bash
# Restore from backup
psql -h ... < prod_backup_2025-10-30.sql

# OR revert migration
supabase migration repair --status reverted <timestamp>
```

---

## Estimated Impact

| Aspect | Impact | Mitigation |
|--------|--------|------------|
| Downtime | 2-5 minutes | Run during low-traffic period |
| Data Loss | Carb loading foods, macro targets | Can be reseeded |
| Edge Functions | Will break | Update before deploying |
| Client Apps | May fail temporarily | Graceful degradation recommended |

---

## Questions?

Contact the development team or check `/docs/schema-sync-2025-10-30.md` for previous sync documentation.
