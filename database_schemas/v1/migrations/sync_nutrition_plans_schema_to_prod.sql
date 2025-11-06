-- ============================================================================
-- PRODUCTION SYNC SCRIPT: Add missing columns to nutrition_plans table
-- Purpose: Ensure PROD has all the calendar integration columns from DEV/Drift
-- Date: 2025-11-06
--
-- IMPORTANT: Run verification script first to check current state!
-- Run: verify_nutrition_plans_schema.sql
--
-- This script is IDEMPOTENT - safe to run multiple times
-- ============================================================================

BEGIN;

-- ============================================================================
-- Add calendar integration columns (if they don't exist)
-- ============================================================================

DO $$
BEGIN
    -- Add activity_id (if not exists) - links to activities table
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'nutrition_plans'
        AND column_name = 'activity_id'
    ) THEN
        ALTER TABLE public.nutrition_plans ADD COLUMN activity_id TEXT;
        RAISE NOTICE '✓ Added activity_id column to nutrition_plans';
    ELSE
        RAISE NOTICE 'ℹ activity_id column already exists in nutrition_plans';
    END IF;

    -- Add plan_type - distinguishes between different plan types
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'nutrition_plans'
        AND column_name = 'plan_type'
    ) THEN
        ALTER TABLE public.nutrition_plans ADD COLUMN plan_type TEXT DEFAULT 'standard';
        RAISE NOTICE '✓ Added plan_type column to nutrition_plans';
    ELSE
        RAISE NOTICE 'ℹ plan_type column already exists in nutrition_plans';
    END IF;

    -- Add sport_type - placeholder for future multi-sport support
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'nutrition_plans'
        AND column_name = 'sport_type'
    ) THEN
        ALTER TABLE public.nutrition_plans ADD COLUMN sport_type TEXT DEFAULT 'running';
        RAISE NOTICE '✓ Added sport_type column to nutrition_plans';
    ELSE
        RAISE NOTICE 'ℹ sport_type column already exists in nutrition_plans';
    END IF;

    -- Add needs_upload - offline-first sync flag
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'nutrition_plans'
        AND column_name = 'needs_upload'
    ) THEN
        ALTER TABLE public.nutrition_plans ADD COLUMN needs_upload BOOLEAN DEFAULT false;
        RAISE NOTICE '✓ Added needs_upload column to nutrition_plans';
    ELSE
        RAISE NOTICE 'ℹ needs_upload column already exists in nutrition_plans';
    END IF;

    -- Add local_updated_at - for conflict resolution
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'nutrition_plans'
        AND column_name = 'local_updated_at'
    ) THEN
        ALTER TABLE public.nutrition_plans ADD COLUMN local_updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
        RAISE NOTICE '✓ Added local_updated_at column to nutrition_plans';
    ELSE
        RAISE NOTICE 'ℹ local_updated_at column already exists in nutrition_plans';
    END IF;
END $$;

-- ============================================================================
-- Add constraints
-- ============================================================================

DO $$
BEGIN
    -- Add check constraint for plan_type values
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'nutrition_plans_plan_type_check'
    ) THEN
        ALTER TABLE public.nutrition_plans
        ADD CONSTRAINT nutrition_plans_plan_type_check
        CHECK (plan_type IN ('standard', 'carb_loading', 'recovery'));
        RAISE NOTICE '✓ Added plan_type check constraint';
    ELSE
        RAISE NOTICE 'ℹ plan_type check constraint already exists';
    END IF;

    -- Add foreign key constraint to activities table
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'fk_nutrition_plans_activity_id'
    ) THEN
        ALTER TABLE public.nutrition_plans
        ADD CONSTRAINT fk_nutrition_plans_activity_id
        FOREIGN KEY (activity_id)
        REFERENCES public.activities(id)
        ON DELETE SET NULL;
        RAISE NOTICE '✓ Added foreign key constraint to activities';
    ELSE
        RAISE NOTICE 'ℹ Foreign key constraint to activities already exists';
    END IF;
END $$;

-- ============================================================================
-- Add indexes
-- ============================================================================

-- Index for activity_id lookups
CREATE INDEX IF NOT EXISTS idx_nutrition_plans_activity_id
  ON public.nutrition_plans(activity_id);

-- Partial index for sync queries (only indexes dirty records)
CREATE INDEX IF NOT EXISTS idx_nutrition_plans_needs_upload
  ON public.nutrition_plans(needs_upload, device_id)
  WHERE needs_upload = true;

-- ============================================================================
-- Add column comments
-- ============================================================================

COMMENT ON COLUMN public.nutrition_plans.activity_id IS 'Links nutrition plan to a calendar activity/event. Nullable to support standalone plans.';
COMMENT ON COLUMN public.nutrition_plans.plan_type IS 'Type of nutrition plan: standard, carb_loading, or recovery';
COMMENT ON COLUMN public.nutrition_plans.sport_type IS 'Sport type for the nutrition plan (currently only running, placeholder for future multi-sport)';
COMMENT ON COLUMN public.nutrition_plans.needs_upload IS 'Flag indicating record needs upload to Supabase (offline-first sync)';
COMMENT ON COLUMN public.nutrition_plans.local_updated_at IS 'Timestamp of last local modification (for conflict resolution)';

COMMENT ON INDEX idx_nutrition_plans_needs_upload IS 'Partial index for efficient sync queries (only indexes dirty records)';

-- ============================================================================
-- Final verification
-- ============================================================================

DO $$
DECLARE
    missing_columns TEXT[];
    col_name TEXT;
BEGIN
    -- Check for all required columns
    SELECT ARRAY_AGG(required_col)
    INTO missing_columns
    FROM (
        SELECT unnest(ARRAY['activity_id', 'plan_type', 'sport_type', 'needs_upload', 'local_updated_at']) AS required_col
    ) required
    WHERE NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'nutrition_plans'
        AND column_name = required_col
    );

    IF missing_columns IS NOT NULL AND array_length(missing_columns, 1) > 0 THEN
        RAISE EXCEPTION 'Migration incomplete! Missing columns: %', array_to_string(missing_columns, ', ');
    ELSE
        RAISE NOTICE '✓ All required columns verified successfully!';
    END IF;
END $$;

COMMIT;

-- ============================================================================
-- Success message
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✓ nutrition_plans schema sync completed';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'All calendar integration columns added:';
    RAISE NOTICE '  • activity_id (links to activities)';
    RAISE NOTICE '  • plan_type (standard/carb_loading/recovery)';
    RAISE NOTICE '  • sport_type (running, future: cycling/swimming)';
    RAISE NOTICE '  • needs_upload (offline-first sync)';
    RAISE NOTICE '  • local_updated_at (conflict resolution)';
    RAISE NOTICE '';
    RAISE NOTICE 'Next step: Refresh PostgREST schema cache';
    RAISE NOTICE '  Method 1: Wait 10 seconds (auto-refresh)';
    RAISE NOTICE '  Method 2: NOTIFY pgrst, ''reload schema'';';
    RAISE NOTICE '';
END $$;
