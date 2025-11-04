-- Migration: Add user_id to activities table
-- Date: 2025-09-30
-- Description: Adds user_id column needed for the sync migration backfill

DO $$ 
BEGIN
    -- Add user_id column to activities if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'activities' 
        AND column_name = 'user_id'
    ) THEN
        ALTER TABLE public.activities ADD COLUMN user_id TEXT;
    END IF;
END $$;

