-- Migration: Repair Users Table - Add Missing Sport Columns
-- Date: 2025-09-30 (補完 repair)
-- Description: Adds remaining missing columns to users table

-- ============================================================================
-- USERS TABLE - Add all missing multi-sport columns
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
END $$;

