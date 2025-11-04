-- Migration: Add user_id to all user-owned tables
-- Date: 2025-09-30
-- Description: Adds user_id column to tables that need it for RLS and sync

DO $$ 
BEGIN
    -- Add user_id to carb_loading_plans
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'carb_loading_plans' 
        AND column_name = 'user_id'
    ) THEN
        ALTER TABLE public.carb_loading_plans ADD COLUMN user_id TEXT;
    END IF;
    
    -- Add user_id to carb_loading_days  
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'carb_loading_days' 
        AND column_name = 'user_id'
    ) THEN
        ALTER TABLE public.carb_loading_days ADD COLUMN user_id TEXT;
    END IF;
    
    -- Add user_id to carb_loading_user_foods
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'carb_loading_user_foods' 
        AND column_name = 'user_id'
    ) THEN
        ALTER TABLE public.carb_loading_user_foods ADD COLUMN user_id TEXT;
    END IF;
    
    -- Add user_id to carb_loading_day_meals
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'carb_loading_day_meals' 
        AND column_name = 'user_id'
    ) THEN
        ALTER TABLE public.carb_loading_day_meals ADD COLUMN user_id TEXT;
    END IF;
END $$;

