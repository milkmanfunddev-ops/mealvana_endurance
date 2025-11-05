-- Migration: Add user_id to events and activity_completions tables
-- Date: 2025-11-04
-- Description: Adds user_id column to events and activity_completions tables for RLS and sync
-- Context: These columns exist in the Drift schema but were missing in Supabase

DO $$
BEGIN
    -- Add user_id to events table
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'events'
        AND column_name = 'user_id'
    ) THEN
        ALTER TABLE public.events ADD COLUMN user_id TEXT NOT NULL DEFAULT '';
        RAISE NOTICE 'Added user_id column to events table';
    ELSE
        RAISE NOTICE 'user_id column already exists in events table';
    END IF;

    -- Add user_id to activity_completions table
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'activity_completions'
        AND column_name = 'user_id'
    ) THEN
        ALTER TABLE public.activity_completions ADD COLUMN user_id TEXT NOT NULL DEFAULT '';
        RAISE NOTICE 'Added user_id column to activity_completions table';
    ELSE
        RAISE NOTICE 'user_id column already exists in activity_completions table';
    END IF;

    -- Optionally, if there's existing data, we could populate user_id from related tables
    -- For events: populate from activities.user_id where activity_id is not null
    IF EXISTS (SELECT 1 FROM public.events WHERE user_id = '' AND activity_id IS NOT NULL) THEN
        UPDATE public.events e
        SET user_id = a.user_id
        FROM public.activities a
        WHERE e.activity_id = a.id AND e.user_id = '';
        RAISE NOTICE 'Populated user_id in events from activities';
    END IF;

    -- For activity_completions: populate from activities.user_id
    IF EXISTS (SELECT 1 FROM public.activity_completions WHERE user_id = '') THEN
        UPDATE public.activity_completions ac
        SET user_id = a.user_id
        FROM public.activities a
        WHERE ac.activity_id = a.id AND ac.user_id = '';
        RAISE NOTICE 'Populated user_id in activity_completions from activities';
    END IF;
END $$;
