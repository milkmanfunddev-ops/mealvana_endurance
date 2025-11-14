-- ============================================================================
-- Migration 007: Drop RLS and Triggers
-- ============================================================================
-- Description: Remove Row Level Security and update triggers (dev posture)
-- Date: 2025-01-07
-- WARNING: This removes security! Only for development/early stage
-- ============================================================================

BEGIN;

-- ============================================================================
-- Drop RLS from all tables
-- ============================================================================

DO $$
DECLARE
  r RECORD;
BEGIN
  -- Disable RLS on all tables in public schema
  FOR r IN (
    SELECT tablename
    FROM pg_tables
    WHERE schemaname = 'public'
  ) LOOP
    EXECUTE format('ALTER TABLE public.%I DISABLE ROW LEVEL SECURITY', r.tablename);
    RAISE NOTICE 'Disabled RLS on table: %', r.tablename;
  END LOOP;
END $$;

-- ============================================================================
-- Drop all RLS policies
-- ============================================================================

DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (
    SELECT schemaname, tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public'
  ) LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', r.policyname, r.tablename);
    RAISE NOTICE 'Dropped policy: % on table: %', r.policyname, r.tablename;
  END LOOP;
END $$;

-- ============================================================================
-- Drop update_updated_at triggers (we'll manage timestamps in application)
-- ============================================================================

DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (
    SELECT trigger_name, event_object_table
    FROM information_schema.triggers
    WHERE trigger_schema = 'public'
      AND trigger_name LIKE '%update_updated_at%'
  ) LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS %I ON public.%I', r.trigger_name, r.event_object_table);
    RAISE NOTICE 'Dropped trigger: % on table: %', r.trigger_name, r.event_object_table;
  END LOOP;
END $$;

-- ============================================================================
-- Drop the update_updated_at_column function if it exists
-- ============================================================================

DROP FUNCTION IF EXISTS public.update_updated_at_column() CASCADE;

COMMIT;

SELECT 'RLS policies and triggers dropped successfully' AS status;
