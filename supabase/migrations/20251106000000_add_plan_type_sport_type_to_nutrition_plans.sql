-- Migration: Add plan_type, sport_type, and activity_id to nutrition_plans table
-- Date: 2025-11-06
-- Description: Adds calendar integration fields to nutrition_plans table
-- Context: These columns exist in the Drift schema but were missing in Supabase

-- ============================================================================
-- Add calendar integration columns
-- ============================================================================

-- Add activity_id (if not exists) - links to activities table
ALTER TABLE public.nutrition_plans
  ADD COLUMN IF NOT EXISTS activity_id TEXT;

-- Add plan_type - distinguishes between different plan types
ALTER TABLE public.nutrition_plans
  ADD COLUMN IF NOT EXISTS plan_type TEXT DEFAULT 'standard';

-- Add sport_type - placeholder for future multi-sport support
ALTER TABLE public.nutrition_plans
  ADD COLUMN IF NOT EXISTS sport_type TEXT DEFAULT 'running';

-- ============================================================================
-- Add constraints
-- ============================================================================

-- Add check constraint for plan_type values
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'nutrition_plans_plan_type_check'
    ) THEN
        ALTER TABLE public.nutrition_plans
        ADD CONSTRAINT nutrition_plans_plan_type_check
        CHECK (plan_type IN ('standard', 'carb_loading', 'recovery'));
    END IF;
END $$;

-- ============================================================================
-- Add foreign key and indexes
-- ============================================================================

-- Add foreign key constraint to activities table (if not exists)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'fk_nutrition_plans_activity_id'
    ) THEN
        ALTER TABLE public.nutrition_plans
        ADD CONSTRAINT fk_nutrition_plans_activity_id
        FOREIGN KEY (activity_id)
        REFERENCES public.activities(id)
        ON DELETE SET NULL;
    END IF;
END $$;

-- Add index for faster lookups (if not exists)
CREATE INDEX IF NOT EXISTS idx_nutrition_plans_activity_id
  ON public.nutrition_plans(activity_id);

-- ============================================================================
-- Add column comments
-- ============================================================================

COMMENT ON COLUMN public.nutrition_plans.activity_id IS 'Links nutrition plan to a calendar activity/event. Nullable to support standalone plans.';
COMMENT ON COLUMN public.nutrition_plans.plan_type IS 'Type of nutrition plan: standard, carb_loading, or recovery';
COMMENT ON COLUMN public.nutrition_plans.sport_type IS 'Sport type for the nutrition plan (currently only running, placeholder for future multi-sport)';
