-- Migration: Sync Production to Dev Schema (Accurate with RLS)
-- Date: 2025-10-30
-- Description: Drop all policies, remove columns, recreate user_id-based policies

-- ============================================================================
-- STEP 1: Drop ALL existing RLS policies from these tables
-- ============================================================================

-- Drop all activities policies
DROP POLICY IF EXISTS "Users can access their own activities" ON "public"."activities";
DROP POLICY IF EXISTS "activities_select_policy" ON "public"."activities";
DROP POLICY IF EXISTS "activities_insert_policy" ON "public"."activities";
DROP POLICY IF EXISTS "activities_update_policy" ON "public"."activities";
DROP POLICY IF EXISTS "activities_delete_policy" ON "public"."activities";

-- Drop all events policies
DROP POLICY IF EXISTS "Users can access their own events" ON "public"."events";
DROP POLICY IF EXISTS "Users can view their own events" ON "public"."events";
DROP POLICY IF EXISTS "Users can insert their own events" ON "public"."events";
DROP POLICY IF EXISTS "Users can update their own events" ON "public"."events";
DROP POLICY IF EXISTS "Users can delete their own events" ON "public"."events";

-- Drop all activity_completions policies
DROP POLICY IF EXISTS "Users can access their own completions" ON "public"."activity_completions";

-- Drop all carb_loading_plans policies
DROP POLICY IF EXISTS "Users can access their own carb plans" ON "public"."carb_loading_plans";
DROP POLICY IF EXISTS "carb_loading_plans_user_policy" ON "public"."carb_loading_plans";

-- Drop all macro_targets_table policies
DROP POLICY IF EXISTS "Users can access their own macro targets" ON "public"."macro_targets_table";
DROP POLICY IF EXISTS "macro_targets_device_policy" ON "public"."macro_targets_table";

-- Drop all carb_loading_user_foods policies
DROP POLICY IF EXISTS "Users can access their own user foods" ON "public"."carb_loading_user_foods";
DROP POLICY IF EXISTS "carb_loading_user_foods_device_read" ON "public"."carb_loading_user_foods";
DROP POLICY IF EXISTS "carb_loading_user_foods_device_insert" ON "public"."carb_loading_user_foods";
DROP POLICY IF EXISTS "carb_loading_user_foods_device_update" ON "public"."carb_loading_user_foods";
DROP POLICY IF EXISTS "carb_loading_user_foods_device_delete" ON "public"."carb_loading_user_foods";

-- Drop all workout_notes policies
DROP POLICY IF EXISTS "Users can access their own workout notes" ON "public"."workout_notes";
DROP POLICY IF EXISTS "workout_notes_device_policy" ON "public"."workout_notes";

-- ============================================================================
-- STEP 2: Remove PROD-only columns
-- ============================================================================

-- Activities
ALTER TABLE "public"."activities" DROP COLUMN IF EXISTS "device_id";
ALTER TABLE "public"."activities" DROP COLUMN IF EXISTS "pace_minutes_per_mile";
ALTER TABLE "public"."activities" DROP COLUMN IF EXISTS "reminder_enabled";
ALTER TABLE "public"."activities" DROP COLUMN IF EXISTS "reminder_days_before";
ALTER TABLE "public"."activities" DROP COLUMN IF EXISTS "reminder_recurring";
ALTER TABLE "public"."activities" DROP COLUMN IF EXISTS "reminder_time_of_day";
ALTER TABLE "public"."activities" DROP COLUMN IF EXISTS "scheduled_date";

-- Events
ALTER TABLE "public"."events" DROP COLUMN IF EXISTS "device_id";
ALTER TABLE "public"."events" DROP COLUMN IF EXISTS "event_date";

-- Users
ALTER TABLE "public"."users" DROP COLUMN IF EXISTS "preferred_sports";

-- Nutrition Plans
ALTER TABLE "public"."nutrition_plans" DROP COLUMN IF EXISTS "user_id";

-- Carb Loading Plans
ALTER TABLE "public"."carb_loading_plans" DROP COLUMN IF EXISTS "device_id";
ALTER TABLE "public"."carb_loading_plans" DROP COLUMN IF EXISTS "target_carbs_g_per_kg";
ALTER TABLE "public"."carb_loading_plans" DROP COLUMN IF EXISTS "created_at";
ALTER TABLE "public"."carb_loading_plans" DROP COLUMN IF EXISTS "updated_at";

-- ============================================================================
-- STEP 3: Add DEV-only columns
-- ============================================================================

ALTER TABLE "public"."carb_loading_plans" ADD COLUMN IF NOT EXISTS "total_days" INTEGER;
ALTER TABLE "public"."carb_loading_plans" ADD COLUMN IF NOT EXISTS "daily_carb_target_grams" INTEGER;
ALTER TABLE "public"."carb_loading_plans" ADD COLUMN IF NOT EXISTS "daily_calorie_target" INTEGER;
ALTER TABLE "public"."carb_loading_plans" ADD COLUMN IF NOT EXISTS "generated_at" timestamp without time zone;
ALTER TABLE "public"."carb_loading_plans" ADD COLUMN IF NOT EXISTS "algorithm_version" TEXT DEFAULT 'v1.0';
ALTER TABLE "public"."carb_loading_plans" ADD COLUMN IF NOT EXISTS "completed_at" timestamp without time zone;

-- ============================================================================
-- STEP 4: Recreate RLS policies using user_id (matching DEV)
-- ============================================================================

-- Activities - use user_id with app.user_id setting
CREATE POLICY "activities_select_policy" ON "public"."activities"
  FOR SELECT USING (user_id = current_setting('app.user_id', true));

CREATE POLICY "activities_insert_policy" ON "public"."activities"
  FOR INSERT WITH CHECK (user_id = current_setting('app.user_id', true));

CREATE POLICY "activities_update_policy" ON "public"."activities"
  FOR UPDATE USING (user_id = current_setting('app.user_id', true));

CREATE POLICY "activities_delete_policy" ON "public"."activities"
  FOR DELETE USING (user_id = current_setting('app.user_id', true));

-- Events - use user_id with auth.uid()
CREATE POLICY "Users can view their own events" ON "public"."events"
  FOR SELECT USING (user_id = (auth.uid())::text);

CREATE POLICY "Users can insert their own events" ON "public"."events"
  FOR INSERT WITH CHECK (user_id = (auth.uid())::text);

CREATE POLICY "Users can update their own events" ON "public"."events"
  FOR UPDATE USING (user_id = (auth.uid())::text);

CREATE POLICY "Users can delete their own events" ON "public"."events"
  FOR DELETE USING (user_id = (auth.uid())::text);

-- Carb Loading Plans - use user_id
CREATE POLICY "carb_loading_plans_user_policy" ON "public"."carb_loading_plans"
  USING (user_id = current_setting('app.user_id', true));

-- Macro Targets - use device_id (this table still has device_id in DEV)
CREATE POLICY "macro_targets_device_policy" ON "public"."macro_targets_table"
  USING (device_id = current_setting('app.device_id', true));

-- Carb Loading User Foods - use device_id (this table still has device_id in DEV)
CREATE POLICY "carb_loading_user_foods_device_read" ON "public"."carb_loading_user_foods"
  FOR SELECT USING (device_id = current_setting('app.device_id', true));

CREATE POLICY "carb_loading_user_foods_device_insert" ON "public"."carb_loading_user_foods"
  FOR INSERT WITH CHECK (device_id = current_setting('app.device_id', true));

CREATE POLICY "carb_loading_user_foods_device_update" ON "public"."carb_loading_user_foods"
  FOR UPDATE USING (device_id = current_setting('app.device_id', true));

CREATE POLICY "carb_loading_user_foods_device_delete" ON "public"."carb_loading_user_foods"
  FOR DELETE USING (device_id = current_setting('app.device_id', true));

-- Workout Notes - use device_id (this table still has device_id in DEV)
CREATE POLICY "workout_notes_device_policy" ON "public"."workout_notes"
  USING (device_id = current_setting('app.device_id', true));
