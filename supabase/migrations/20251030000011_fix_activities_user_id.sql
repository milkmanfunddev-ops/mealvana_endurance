-- ============================================================================
-- Migration: Fix activities table - Add user_id column
-- Date: 2025-10-30
-- Purpose: Add missing user_id column to activities table (PROD doesn't have device_id)
-- ============================================================================

-- Check current structure
DO $$
BEGIN
  RAISE NOTICE 'Current activities columns:';
  FOR r IN
    SELECT column_name, data_type
    FROM information_schema.columns
    WHERE table_name = 'activities' AND table_schema = 'public'
    ORDER BY ordinal_position
  LOOP
    RAISE NOTICE '  - %: %', r.column_name, r.data_type;
  END LOOP;
END $$;

-- ============================================================================
-- PART 1: Add user_id column if it doesn't exist
-- ============================================================================

ALTER TABLE public.activities
  ADD COLUMN IF NOT EXISTS user_id text;

COMMENT ON COLUMN public.activities.user_id IS 'User ID from users.id (UUID cast to text)';

-- ============================================================================
-- PART 2: Backfill user_id (if we have a way to determine it)
-- ============================================================================

-- If activities has device_id, use it for backfill
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'activities'
    AND column_name = 'device_id'
  ) THEN
    RAISE NOTICE 'Found device_id column - using for backfill';

    UPDATE public.activities a
    SET user_id = u.id::text
    FROM public.users u
    WHERE a.device_id = u.device_id
    AND a.user_id IS NULL;

    RAISE NOTICE 'Backfilled user_id for % rows', (SELECT COUNT(*) FROM activities WHERE user_id IS NOT NULL);
  ELSE
    RAISE NOTICE 'No device_id column found - skipping backfill';
    RAISE NOTICE 'user_id will need to be set by application or manually';
  END IF;
END $$;

-- ============================================================================
-- PART 3: Add other missing columns from DEV schema
-- ============================================================================

-- Core columns
ALTER TABLE public.activities
  ADD COLUMN IF NOT EXISTS title text,
  ADD COLUMN IF NOT EXISTS scheduled_date_time timestamp,
  ADD COLUMN IF NOT EXISTS pace_target_minutes_per_mile real,
  ADD COLUMN IF NOT EXISTS intensity_level text;

-- Completion tracking
ALTER TABLE public.activities
  ADD COLUMN IF NOT EXISTS completed_at timestamp,
  ADD COLUMN IF NOT EXISTS completion_rating integer,
  ADD COLUMN IF NOT EXISTS completion_notes text,
  ADD COLUMN IF NOT EXISTS actual_distance_miles real,
  ADD COLUMN IF NOT EXISTS actual_duration_minutes integer;

-- Reminder settings
ALTER TABLE public.activities
  ADD COLUMN IF NOT EXISTS reminder_enabled boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS reminder_days_before integer,
  ADD COLUMN IF NOT EXISTS reminder_time_of_day text,
  ADD COLUMN IF NOT EXISTS reminder_recurring boolean DEFAULT false;

-- Soft delete and notes
ALTER TABLE public.activities
  ADD COLUMN IF NOT EXISTS deleted_at timestamp,
  ADD COLUMN IF NOT EXISTS notes text;

-- ============================================================================
-- PART 4: Migrate data from old column names (if they exist)
-- ============================================================================

DO $$
BEGIN
  -- Migrate scheduled_date to scheduled_date_time
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'activities' AND column_name = 'scheduled_date'
  ) THEN
    UPDATE public.activities
    SET scheduled_date_time = scheduled_date
    WHERE scheduled_date_time IS NULL AND scheduled_date IS NOT NULL;

    RAISE NOTICE 'Migrated scheduled_date to scheduled_date_time';
  END IF;

  -- Migrate pace_minutes_per_mile to pace_target_minutes_per_mile
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'activities' AND column_name = 'pace_minutes_per_mile'
  ) THEN
    UPDATE public.activities
    SET pace_target_minutes_per_mile = pace_minutes_per_mile
    WHERE pace_target_minutes_per_mile IS NULL AND pace_minutes_per_mile IS NOT NULL;

    RAISE NOTICE 'Migrated pace_minutes_per_mile to pace_target_minutes_per_mile';
  END IF;

  -- Migrate intensity_target to intensity_level
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'activities' AND column_name = 'intensity_target'
  ) THEN
    UPDATE public.activities
    SET intensity_level = intensity_target
    WHERE intensity_level IS NULL AND intensity_target IS NOT NULL;

    RAISE NOTICE 'Migrated intensity_target to intensity_level';
  END IF;
END $$;

-- ============================================================================
-- PART 5: Set default titles for existing activities
-- ============================================================================

UPDATE public.activities
SET title = CASE
  WHEN activity_type = 'running' THEN
    'Run - ' || COALESCE(
      CAST(distance_miles AS text) || ' mi',
      CAST(duration_minutes AS text) || ' min',
      'Workout'
    )
  WHEN activity_type = 'event' THEN 'Event'
  ELSE COALESCE(activity_type, 'Activity')
END
WHERE title IS NULL;

-- ============================================================================
-- PART 6: Add constraints
-- ============================================================================

-- Drop old constraints if they exist
ALTER TABLE public.activities
  DROP CONSTRAINT IF EXISTS activity_type_check,
  DROP CONSTRAINT IF EXISTS status_check,
  DROP CONSTRAINT IF EXISTS intensity_check,
  DROP CONSTRAINT IF EXISTS rating_check;

-- Add new constraints
ALTER TABLE public.activities
  ADD CONSTRAINT activity_type_check
    CHECK (activity_type IN ('running', 'event'));

ALTER TABLE public.activities
  ADD CONSTRAINT status_check
    CHECK (status IS NULL OR status IN ('planned', 'in_progress', 'completed', 'skipped'));

ALTER TABLE public.activities
  ADD CONSTRAINT intensity_check
    CHECK (intensity_level IS NULL OR intensity_level IN ('easy', 'moderate', 'hard', 'race'));

ALTER TABLE public.activities
  ADD CONSTRAINT rating_check
    CHECK (completion_rating IS NULL OR (completion_rating >= 1 AND completion_rating <= 5));

-- ============================================================================
-- PART 7: Update RLS policies to use user_id
-- ============================================================================

-- Drop old policies
DROP POLICY IF EXISTS "Users can access their own activities" ON public.activities;
DROP POLICY IF EXISTS activities_select_policy ON public.activities;
DROP POLICY IF EXISTS activities_insert_policy ON public.activities;
DROP POLICY IF EXISTS activities_update_policy ON public.activities;
DROP POLICY IF EXISTS activities_delete_policy ON public.activities;

-- Create new user_id-based policies
CREATE POLICY activities_select_policy ON public.activities
  AS PERMISSIVE FOR SELECT
  USING (user_id = current_setting('app.user_id', true));

CREATE POLICY activities_insert_policy ON public.activities
  AS PERMISSIVE FOR INSERT
  WITH CHECK (user_id = current_setting('app.user_id', true));

CREATE POLICY activities_update_policy ON public.activities
  AS PERMISSIVE FOR UPDATE
  USING (user_id = current_setting('app.user_id', true));

CREATE POLICY activities_delete_policy ON public.activities
  AS PERMISSIVE FOR DELETE
  USING (user_id = current_setting('app.user_id', true));

-- ============================================================================
-- PART 8: Create indexes
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_activities_user ON public.activities(user_id);
CREATE INDEX IF NOT EXISTS idx_activities_scheduled ON public.activities(scheduled_date_time);
CREATE INDEX IF NOT EXISTS idx_activities_type ON public.activities(activity_type);
CREATE INDEX IF NOT EXISTS idx_activities_status ON public.activities(status);

-- ============================================================================
-- PART 9: Update table comments
-- ============================================================================

COMMENT ON TABLE public.activities IS 'All calendar entries including workouts and events';
COMMENT ON COLUMN public.activities.activity_type IS 'Type: running (workout) or event (race)';
COMMENT ON COLUMN public.activities.status IS 'Current status: planned, in_progress, completed, skipped';

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Activities table migration complete!';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Summary:';
  RAISE NOTICE '  - Added user_id column';
  RAISE NOTICE '  - Added title, completion, reminder columns';
  RAISE NOTICE '  - Updated RLS policies to use user_id';
  RAISE NOTICE '  - Created indexes';
  RAISE NOTICE '';
  RAISE NOTICE 'NEXT STEPS:';
  RAISE NOTICE '  1. Update edge function save-calendar-activity';
  RAISE NOTICE '     - Change device_id to user_id';
  RAISE NOTICE '     - Use new column names (scheduled_date_time, etc)';
  RAISE NOTICE '  2. Deploy updated edge function';
  RAISE NOTICE '  3. Test activity creation';
  RAISE NOTICE '========================================';
END $$;
