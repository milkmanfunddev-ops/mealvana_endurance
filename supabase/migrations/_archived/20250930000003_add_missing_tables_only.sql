-- Migration: Add Missing Tables Only
-- Date: 2025-09-30
-- Description: Creates only the 13 missing tables without touching existing ones

-- ============================================================================
-- NEW TABLES THAT DON'T EXIST IN PROD (13 tables)
-- ============================================================================

-- 1. MACRO_TARGETS_TABLE
CREATE TABLE IF NOT EXISTS "public"."macro_targets_table" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "device_id" TEXT NOT NULL,
    "activity_id" TEXT,
    "carbs_grams" INTEGER,
    "protein_grams" INTEGER,
    "fat_grams" INTEGER,
    "sodium_mg" INTEGER,
    "hydration_oz" INTEGER,
    "calculation_rule" TEXT,
    "is_user_modified" BOOLEAN DEFAULT false,
    "modified_fields" TEXT[],
    "created_at" TIMESTAMPTZ DEFAULT NOW(),
    "updated_at" TIMESTAMPTZ DEFAULT NOW()
);

-- 2. WORKOUT_NOTES
CREATE TABLE IF NOT EXISTS "public"."workout_notes" (
    "id" UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    "device_id" TEXT NOT NULL,
    "user_id" TEXT,
    "plan_id" TEXT,
    "activity_id" TEXT,
    "rating" INTEGER,
    "notes" TEXT,
    "created_at" TIMESTAMPTZ DEFAULT NOW(),
    "updated_at" TIMESTAMPTZ DEFAULT NOW()
);

-- 3. ACTIVITIES
CREATE TABLE IF NOT EXISTS "public"."activities" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "device_id" TEXT NOT NULL,
    "activity_type" TEXT NOT NULL,
    "sport_type" TEXT DEFAULT 'running',
    "distance_miles" NUMERIC(5,2),
    "pace_minutes_per_mile" NUMERIC(5,2),
    "duration_minutes" INTEGER,
    "scheduled_date" TIMESTAMPTZ,
    "time_before_minutes" INTEGER,
    "intensity_target" TEXT,
    "status" TEXT DEFAULT 'scheduled',
    "cycling_power_watts" INTEGER,
    "cycling_speed_mph" NUMERIC(5,2),
    "cycling_ftp_watts" INTEGER,
    "cycling_terrain" TEXT,
    "cycling_elevation_gain_ft" INTEGER,
    "cycling_indoor_outdoor" TEXT,
    "cycling_session_goal" TEXT,
    "swimming_pace_per_100m_seconds" INTEGER,
    "swimming_speed_per_100m" NUMERIC(5,2),
    "swimming_css_seconds_per_100m" INTEGER,
    "swimming_pool_or_open_water" TEXT,
    "swimming_water_temp_c" NUMERIC(4,1),
    "created_at" TIMESTAMPTZ DEFAULT NOW(),
    "updated_at" TIMESTAMPTZ DEFAULT NOW()
);

-- 4. EVENTS
CREATE TABLE IF NOT EXISTS "public"."events" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "device_id" TEXT NOT NULL,
    "event_name" TEXT NOT NULL,
    "event_date" TIMESTAMPTZ NOT NULL,
    "activity_id" TEXT,
    "has_nutrition_plan" BOOLEAN DEFAULT false,
    "has_carb_loading" BOOLEAN DEFAULT false,
    "created_at" TIMESTAMPTZ DEFAULT NOW(),
    "updated_at" TIMESTAMPTZ DEFAULT NOW()
);

-- 5. ACTIVITY_COMPLETIONS
CREATE TABLE IF NOT EXISTS "public"."activity_completions" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "device_id" TEXT NOT NULL,
    "user_id" TEXT,
    "activity_id" TEXT NOT NULL,
    "completed_at" TIMESTAMPTZ DEFAULT NOW(),
    "actual_duration_minutes" INTEGER,
    "actual_distance_miles" NUMERIC(5,2),
    "notes" TEXT,
    "created_at" TIMESTAMPTZ DEFAULT NOW(),
    "updated_at" TIMESTAMPTZ DEFAULT NOW()
);

-- 6. CARB_LOADING_PLANS
CREATE TABLE IF NOT EXISTS "public"."carb_loading_plans" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "device_id" TEXT NOT NULL,
    "event_id" TEXT NOT NULL,
    "start_date" TIMESTAMPTZ NOT NULL,
    "end_date" TIMESTAMPTZ NOT NULL,
    "target_carbs_g_per_kg" NUMERIC(5,2),
    "adherence_score" NUMERIC(5,2),
    "created_at" TIMESTAMPTZ DEFAULT NOW(),
    "updated_at" TIMESTAMPTZ DEFAULT NOW()
);

-- 7. CARB_LOADING_DAYS
CREATE TABLE IF NOT EXISTS "public"."carb_loading_days" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "plan_id" TEXT NOT NULL,
    "day_number" INTEGER NOT NULL,
    "date" TIMESTAMPTZ NOT NULL,
    "target_carbs_grams" INTEGER,
    "carb_protocol_g_per_kg" NUMERIC(5,2),
    "meal_count" INTEGER DEFAULT 0,
    "created_at" TIMESTAMPTZ DEFAULT NOW(),
    "updated_at" TIMESTAMPTZ DEFAULT NOW()
);

-- 8. MEAL_TYPES
CREATE TABLE IF NOT EXISTS "public"."meal_types" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "name" TEXT NOT NULL UNIQUE,
    "display_name" TEXT NOT NULL,
    "sort_order" INTEGER DEFAULT 0
);

-- 9. CARB_LOADING_FOODS
CREATE TABLE IF NOT EXISTS "public"."carb_loading_foods" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "name" TEXT NOT NULL,
    "display_name" TEXT,
    "carbs_per_serving" NUMERIC(6,2),
    "serving_size" TEXT,
    "serving_unit" TEXT,
    "is_default" BOOLEAN DEFAULT true,
    "created_at" TIMESTAMPTZ DEFAULT NOW()
);

-- 10. CARB_LOADING_USER_FOODS
CREATE TABLE IF NOT EXISTS "public"."carb_loading_user_foods" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "device_id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "display_name" TEXT,
    "carbs_per_serving" NUMERIC(6,2),
    "serving_size" TEXT,
    "serving_unit" TEXT,
    "barcode" TEXT,
    "source_food_id" TEXT,
    "source_user_food_id" TEXT,
    "is_deleted" BOOLEAN DEFAULT false,
    "created_at" TIMESTAMPTZ DEFAULT NOW(),
    "updated_at" TIMESTAMPTZ DEFAULT NOW()
);

-- 11. CARB_LOADING_FOOD_MEAL_TYPES
CREATE TABLE IF NOT EXISTS "public"."carb_loading_food_meal_types" (
    "food_id" TEXT NOT NULL,
    "meal_type_id" TEXT NOT NULL,
    PRIMARY KEY ("food_id", "meal_type_id")
);

-- 12. CARB_LOADING_USER_FOOD_MEAL_TYPES
CREATE TABLE IF NOT EXISTS "public"."carb_loading_user_food_meal_types" (
    "user_food_id" TEXT NOT NULL,
    "meal_type_id" TEXT NOT NULL,
    PRIMARY KEY ("user_food_id", "meal_type_id")
);

-- 13. CARB_LOADING_DAY_MEALS
CREATE TABLE IF NOT EXISTS "public"."carb_loading_day_meals" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "day_id" TEXT NOT NULL,
    "meal_type_id" TEXT NOT NULL,
    "food_id" TEXT,
    "user_food_id" TEXT,
    "quantity" NUMERIC(6,2),
    "carbs_consumed" NUMERIC(6,2),
    "created_at" TIMESTAMPTZ DEFAULT NOW(),
    "updated_at" TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- Enable RLS on new tables
-- ============================================================================
ALTER TABLE "public"."macro_targets_table" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."workout_notes" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."activities" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."events" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."activity_completions" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."carb_loading_plans" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."carb_loading_days" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."meal_types" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."carb_loading_foods" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."carb_loading_user_foods" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."carb_loading_food_meal_types" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."carb_loading_user_food_meal_types" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."carb_loading_day_meals" ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- Basic RLS policies (device_id based)
-- ============================================================================
CREATE POLICY "Users can access their own macro targets" ON "public"."macro_targets_table" FOR ALL USING (device_id = current_setting('request.jwt.claims', true)::json->>'device_id');
CREATE POLICY "Users can access their own workout notes" ON "public"."workout_notes" FOR ALL USING (device_id = current_setting('request.jwt.claims', true)::json->>'device_id');
CREATE POLICY "Users can access their own activities" ON "public"."activities" FOR ALL USING (device_id = current_setting('request.jwt.claims', true)::json->>'device_id');
CREATE POLICY "Users can access their own events" ON "public"."events" FOR ALL USING (device_id = current_setting('request.jwt.claims', true)::json->>'device_id');
CREATE POLICY "Users can access their own completions" ON "public"."activity_completions" FOR ALL USING (device_id = current_setting('request.jwt.claims', true)::json->>'device_id');
CREATE POLICY "Users can access their own carb plans" ON "public"."carb_loading_plans" FOR ALL USING (device_id = current_setting('request.jwt.claims', true)::json->>'device_id');
CREATE POLICY "Users can access their own user foods" ON "public"."carb_loading_user_foods" FOR ALL USING (device_id = current_setting('request.jwt.claims', true)::json->>'device_id');
CREATE POLICY "All users can read meal types" ON "public"."meal_types" FOR SELECT USING (true);
CREATE POLICY "All users can read default carb foods" ON "public"."carb_loading_foods" FOR SELECT USING (true);

