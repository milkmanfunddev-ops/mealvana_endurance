-- Migration: Repair Existing Tables for Base Schema  
-- Date: 2025-09-30 (runs before base schema)
-- Description: Adds missing columns to existing tables in prod before base migration

-- ============================================================================
-- 1. NUTRITION_PLANS TABLE
-- ============================================================================
DO $$ 
BEGIN
    -- Add activity_id column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'nutrition_plans' AND column_name = 'activity_id') THEN
        ALTER TABLE public.nutrition_plans ADD COLUMN activity_id TEXT;
    END IF;
    
    -- Add user_id column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'nutrition_plans' AND column_name = 'user_id') THEN
        ALTER TABLE public.nutrition_plans ADD COLUMN user_id TEXT;
    END IF;
END $$;

-- ============================================================================
-- 2. USERS TABLE - Add multi-sport columns
-- ============================================================================
DO $$ 
BEGIN
    -- Cycling columns
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'cycling_ftp_watts') THEN
        ALTER TABLE public.users ADD COLUMN cycling_ftp_watts INTEGER;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'prefers_cycling_power') THEN
        ALTER TABLE public.users ADD COLUMN prefers_cycling_power BOOLEAN DEFAULT false;
    END IF;
    
    -- Swimming columns
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'swimming_css_seconds_per_100m') THEN
        ALTER TABLE public.users ADD COLUMN swimming_css_seconds_per_100m INTEGER;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'prefers_swimming_pace') THEN
        ALTER TABLE public.users ADD COLUMN prefers_swimming_pace BOOLEAN DEFAULT false;
    END IF;
    
    -- Sport preferences
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'preferred_sports') THEN
        ALTER TABLE public.users ADD COLUMN preferred_sports TEXT[] DEFAULT ARRAY['running'];
    END IF;
END $$;

-- ============================================================================
-- 3. FOODS TABLE - Add cycling/swimming suitability
-- ============================================================================
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'foods' AND column_name = 'cycling_suitable') THEN
        ALTER TABLE public.foods ADD COLUMN cycling_suitable BOOLEAN DEFAULT true;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'foods' AND column_name = 'swimming_suitable') THEN
        ALTER TABLE public.foods ADD COLUMN swimming_suitable BOOLEAN DEFAULT true;
    END IF;
END $$;

-- ============================================================================
-- 4. USER_FOODS TABLE - Add cycling/swimming suitability
-- ============================================================================
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'user_foods' AND column_name = 'cycling_suitable') THEN
        ALTER TABLE public.user_foods ADD COLUMN cycling_suitable BOOLEAN DEFAULT true;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'user_foods' AND column_name = 'swimming_suitable') THEN
        ALTER TABLE public.user_foods ADD COLUMN swimming_suitable BOOLEAN DEFAULT true;
    END IF;
END $$;

-- ============================================================================
-- 5. Add indexes that will be referenced later
-- ============================================================================
DO $$
BEGIN
    -- Index for nutrition_plans.activity_id
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'public' AND tablename = 'nutrition_plans' AND indexname = 'idx_nutrition_plans_activity_id') THEN
        CREATE INDEX idx_nutrition_plans_activity_id ON public.nutrition_plans(activity_id);
    END IF;
END $$;

