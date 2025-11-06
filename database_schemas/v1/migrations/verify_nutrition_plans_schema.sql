-- ============================================================================
-- Verification Script: Check nutrition_plans table schema
-- Purpose: Verify that nutrition_plans has all required columns in DEV and PROD
-- Run this against both environments to check column status
-- ============================================================================

-- Check which columns exist in nutrition_plans table
SELECT
    column_name,
    data_type,
    column_default,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'nutrition_plans'
ORDER BY ordinal_position;

-- Check specifically for the calendar integration columns
SELECT
    CASE
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public'
            AND table_name = 'nutrition_plans'
            AND column_name = 'activity_id'
        ) THEN '✓ activity_id exists'
        ELSE '✗ activity_id MISSING'
    END as activity_id_status,

    CASE
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public'
            AND table_name = 'nutrition_plans'
            AND column_name = 'plan_type'
        ) THEN '✓ plan_type exists'
        ELSE '✗ plan_type MISSING'
    END as plan_type_status,

    CASE
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public'
            AND table_name = 'nutrition_plans'
            AND column_name = 'sport_type'
        ) THEN '✓ sport_type exists'
        ELSE '✗ sport_type MISSING'
    END as sport_type_status,

    CASE
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public'
            AND table_name = 'nutrition_plans'
            AND column_name = 'needs_upload'
        ) THEN '✓ needs_upload exists'
        ELSE '✗ needs_upload MISSING'
    END as needs_upload_status,

    CASE
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public'
            AND table_name = 'nutrition_plans'
            AND column_name = 'local_updated_at'
        ) THEN '✓ local_updated_at exists'
        ELSE '✗ local_updated_at MISSING'
    END as local_updated_at_status;

-- Check constraints
SELECT
    constraint_name,
    constraint_type
FROM information_schema.table_constraints
WHERE table_schema = 'public'
  AND table_name = 'nutrition_plans'
ORDER BY constraint_type, constraint_name;

-- Check indexes
SELECT
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'nutrition_plans'
ORDER BY indexname;
