# Production Schema Sync - October 30, 2025

## Issue
User encountered error when creating an event in production:
```
Could not find the 'actual_finish_time_minutes' column of 'events' in the schema cache
```

This indicated schema mismatches between dev and production databases.

## Migrations Applied

### 1. Migration 20251030000000 - Add Missing Events Columns
**Status:** ✅ Applied Successfully

Added the following columns to the `events` table:
- `event_type` (TEXT) - Event classification (marathon, half_marathon, 10k, 5k, ultra variants, custom)
- `event_subtype` (TEXT) - Custom categorization
- `location` (TEXT) - Event location
- `registration_url` (TEXT) - Registration URL
- `start_time` (TEXT) - Race start time
- `goal_time_minutes` (INTEGER) - Goal finish time
- `goal_pace_minutes_per_mile` (REAL) - Target pace
- `predicted_finish_time_minutes` (INTEGER) - Predicted time
- `carb_loading_days` (INTEGER) - Number of carb loading days (1, 2, 3, or 7)
- `carb_loading_start_date` (TIMESTAMPTZ) - Start date for carb loading
- `bib_number` (TEXT) - Race bib number
- `wave_start_time` (TEXT) - Wave start time
- `packet_pickup_info` (TEXT) - Packet pickup details
- **`actual_finish_time_minutes`** (INTEGER) - **The column that was causing the error**
- `final_placement` (INTEGER) - Overall placement
- `age_group_placement` (INTEGER) - Age group placement

Added constraints:
- CHECK for event_type values
- CHECK for carb_loading_days values

### 2. Migration 20251030000001 - Add Missing Activities Columns
**Status:** ✅ Applied Successfully

Added the following columns to the `activities` table:
- `title` (TEXT) - Activity title
- `scheduled_date_time` (TIMESTAMPTZ) - Scheduled date/time
- `pace_target_minutes_per_mile` (REAL) - Target pace
- `intensity_level` (TEXT) - Intensity level (easy, moderate, hard, race)
- `completed_at` (TIMESTAMPTZ) - Completion timestamp
- `completion_rating` (INTEGER) - Rating 1-5
- `completion_notes` (TEXT) - Notes after completion
- `actual_distance_miles` (NUMERIC) - Actual distance completed
- `actual_duration_minutes` (INTEGER) - Actual duration
- `reminder_enabled` (BOOLEAN) - Whether reminder is enabled
- `reminder_days_before` (INTEGER) - Days before to remind
- `reminder_time_of_day` (TEXT) - Time of day for reminder
- `reminder_recurring` (BOOLEAN) - Whether reminder recurs
- `deleted_at` (TIMESTAMPTZ) - Soft delete timestamp
- `notes` (TEXT) - General notes

Added constraints:
- CHECK for intensity_level values
- CHECK for completion_rating range (1-5)

## Current Status

### ✅ Fixed Tables
- `events` - All missing columns added, constraints in place
- `activities` - All missing columns added, constraints in place

### ⚠️ Potential Schema Differences Still Present

Based on the analysis, the following tables may still have schema differences between Drift (local) and Supabase (production):

#### Activities Table - Naming Differences
The production `activities` table uses different column names for some fields:
- Production: `scheduled_date` vs Drift: `scheduled_date_time`
- Production: `pace_minutes_per_mile` vs Drift: `pace_target_minutes_per_mile`

**Recommendation:** Create a follow-up migration to align these column names, or update the Drift schema to match production naming conventions.

#### Other Tables to Audit
The following critical tables should be audited for schema parity:
- `nutrition_plans` - Check if `activity_id`, `plan_type`, `sport_type` columns exist
- `foods_table` - Verify all columns match
- `user_foods_table` - Check sync columns
- `carb_loading_*` tables - Verify all relationships are correct

## Edge Function Fixes Applied

### Issue #2: Missing device_id in Edge Functions
After applying the schema migrations, a second error appeared:
```
null value in column "device_id" of relation "events" violates not-null constraint
```

**Root Cause:** Multiple edge functions were not including the `device_id` field when inserting records, even though the production tables require it as NOT NULL.

### Fixed Edge Functions:

#### 1. save-calendar-event ✅
- **Added:** `device_id: device_id` to insert statement
- **Added:** `needs_upload: false` and `local_updated_at` for sync tracking
- **Status:** Deployed to production

#### 2. save-calendar-activity ✅
- **Added:** `device_id: device_id` to insert statement
- **Added:** `needs_upload: false` and `local_updated_at` for sync tracking
- **Status:** Deployed to production

#### 3. save-activity-completion ✅
- **Added:** `device_id: device_id` to insert statement
- **Added:** `needs_upload: false`, `local_updated_at`, `created_at`, `updated_at` for sync tracking
- **Status:** Deployed to production

#### 4. save-carb-loading-plan ✅
- **Added:** `device_id: device_id` to insert statement
- **Added:** `needs_upload: false`, `local_updated_at`, `created_at`, `updated_at` for sync tracking
- **Status:** Deployed to production

## Next Steps

1. **Test the complete fix:** Try creating an event in production mode again - both errors should be resolved
2. **Complete schema audit:** Run a comprehensive comparison between Drift schema and production to identify all remaining differences
3. **Audit remaining edge functions:** Check all other edge functions (get-*, generate-*, sync-*) for similar issues
4. **Create alignment plan:** Decide whether to:
   - Update production to match Drift schema (recommended)
   - Update Drift to match production (only if production schema is correct)
5. **Add schema validation tests:** Create automated tests to detect schema drift in the future
6. **Add edge function tests:** Test all edge functions with production-like data to catch issues before deployment

## Commands Used

```bash
# Link to production
supabase link --project-ref wvmvsodrvbkxfydabqed

# Check applied migrations
supabase migration list

# Dump production schema
supabase db dump --linked -s public

# Push migrations
supabase db push --linked

# Deploy edge functions
supabase functions deploy save-calendar-event
supabase functions deploy save-calendar-activity
supabase functions deploy save-activity-completion save-carb-loading-plan
```

## Files Modified

### Migration Files Created
- `/supabase/migrations/20251030000000_add_missing_events_columns.sql`
- `/supabase/migrations/20251030000001_add_missing_activities_columns.sql`

### Edge Functions Fixed
- `/supabase/functions/save-calendar-event/index.ts`
- `/supabase/functions/save-calendar-activity/index.ts`
- `/supabase/functions/save-activity-completion/index.ts`
- `/supabase/functions/save-carb-loading-plan/index.ts`
