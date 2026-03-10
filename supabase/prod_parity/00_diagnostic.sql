-- ============================================================================
-- DIAGNOSTIC: Run this on PROD first to understand current state
-- ============================================================================
-- Run on: PRODUCTION Supabase SQL Editor
-- Purpose: Check what exists before making changes
-- ============================================================================

-- 1. Check if enum value already exists
SELECT enumlabel FROM pg_enum
WHERE enumtypid = 'activity_status_enum'::regtype
ORDER BY enumlabel;

-- 2. Check which columns exist on users
SELECT column_name FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'users'
AND column_name IN ('unit_system', 'default_running_pace_min_per_mile',
    'default_cycling_speed_mph', 'default_swimming_pace_per_100_sec',
    'nutrition_target_overrides')
ORDER BY column_name;

-- 3. Check if template_foods and templates tables exist
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN ('template_foods', 'templates')
ORDER BY table_name;

-- 4. Check RLS status on key tables (CRITICAL - tells us if we can safely change policies)
SELECT c.relname AS table_name,
       c.relrowsecurity AS rls_enabled,
       c.relforcerowsecurity AS rls_forced
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
AND c.relname IN ('activities', 'events', 'carb_loading_plans',
                   'carb_loading_days', 'carb_loading_day_meals',
                   'template_foods', 'templates')
ORDER BY c.relname;

-- 5. Check existing RLS policies on these tables
SELECT tablename, policyname, permissive, roles, cmd
FROM pg_policies
WHERE schemaname = 'public'
AND tablename IN ('activities', 'events', 'carb_loading_plans',
                   'carb_loading_days', 'carb_loading_day_meals')
ORDER BY tablename, policyname;

-- 6. Check current food_preferences values that need normalization
SELECT DISTINCT food_name, count(*) as user_count
FROM food_preferences
WHERE food_name ~ '[A-Z /()]'
GROUP BY food_name
ORDER BY food_name;
