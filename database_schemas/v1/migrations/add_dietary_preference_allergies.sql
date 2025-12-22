-- Migration: Add dietary_preference and allergies columns to users table
-- Part of the December 2025 onboarding revamp
--
-- This migration adds two new columns to support the dietary preference and allergies
-- selection during onboarding and in settings.
--
-- Run this migration on existing Supabase databases:
-- 1. Go to Supabase Dashboard > SQL Editor
-- 2. Paste this script and run
--
-- Note: This is safe to run multiple times (idempotent) due to IF NOT EXISTS checks

-- Add dietary_preference column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'users'
        AND column_name = 'dietary_preference'
    ) THEN
        ALTER TABLE public.users
        ADD COLUMN dietary_preference text
        CONSTRAINT users_dietary_preference_check
        CHECK (dietary_preference IN ('omnivore', 'vegetarian', 'pescatarian', 'vegan', 'mediterranean', 'paleo', 'keto', 'low_carb') OR dietary_preference IS NULL);

        COMMENT ON COLUMN public.users.dietary_preference IS 'User dietary preference (omnivore, vegetarian, vegan, etc.) - nullable for users who skip during onboarding';

        RAISE NOTICE 'Added dietary_preference column to users table';
    ELSE
        RAISE NOTICE 'dietary_preference column already exists';
    END IF;
END $$;

-- Add allergies column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'users'
        AND column_name = 'allergies'
    ) THEN
        ALTER TABLE public.users
        ADD COLUMN allergies text DEFAULT '{}'::text;

        COMMENT ON COLUMN public.users.allergies IS 'User food allergies stored as PostgreSQL text array format (e.g., {dairy,gluten,peanuts})';

        RAISE NOTICE 'Added allergies column to users table';
    ELSE
        RAISE NOTICE 'allergies column already exists';
    END IF;
END $$;

-- Verify the changes
SELECT column_name, data_type, column_default, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'users'
AND column_name IN ('dietary_preference', 'allergies');
