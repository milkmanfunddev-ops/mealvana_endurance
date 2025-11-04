-- Migration: Repair Foods Tables - Add suitable_for_activities
-- Date: 2025-09-30
-- Description: Adds suitable_for_activities JSONB column to foods and user_foods tables

-- ============================================================================
-- FOODS TABLE - Add suitable_for_activities
-- ============================================================================
DO $$ 
BEGIN
    -- Add suitable_for_activities column (JSONB)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'foods' AND column_name = 'suitable_for_activities') THEN
        ALTER TABLE public.foods ADD COLUMN suitable_for_activities JSONB;
    END IF;
    
    -- Add is_essential column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'foods' AND column_name = 'is_essential') THEN
        ALTER TABLE public.foods ADD COLUMN is_essential BOOLEAN DEFAULT false;
    END IF;
    
    -- Add show_in_preferences column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'foods' AND column_name = 'show_in_preferences') THEN
        ALTER TABLE public.foods ADD COLUMN show_in_preferences BOOLEAN DEFAULT true;
    END IF;
END $$;

-- ============================================================================
-- USER_FOODS TABLE - Add suitable_for_activities
-- ============================================================================
DO $$ 
BEGIN
    -- Add suitable_for_activities column (JSONB)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'user_foods' AND column_name = 'suitable_for_activities') THEN
        ALTER TABLE public.user_foods ADD COLUMN suitable_for_activities JSONB;
    END IF;
END $$;

