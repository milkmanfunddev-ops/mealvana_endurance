-- Migration: Add sync tracking columns for offline-first architecture
-- Created: 2025-10-29
-- Purpose: Enable bidirectional sync with dirty flag tracking

-- ============================================================================
-- STEP 1: Add user_id to events table
-- ============================================================================

-- Add user_id column (nullable initially for backfill)
ALTER TABLE events ADD COLUMN user_id text;

-- Backfill user_id from activities table
UPDATE events e
SET user_id = a.user_id
FROM activities a
WHERE e.activity_id = a.id;

-- Make user_id NOT NULL after backfill
ALTER TABLE events ALTER COLUMN user_id SET NOT NULL;

-- Add index for faster queries by user_id
CREATE INDEX idx_events_user_id ON events(user_id);

-- Add comment
COMMENT ON COLUMN events.user_id IS 'User ID for direct filtering (eliminates need for joins with activities)';

-- ============================================================================
-- STEP 2: Add sync tracking columns to all user-editable tables
-- ============================================================================

-- Activities table
ALTER TABLE activities
  ADD COLUMN needs_upload BOOLEAN DEFAULT false,
  ADD COLUMN local_updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

COMMENT ON COLUMN activities.needs_upload IS 'Flag indicating record needs upload to Supabase (offline-first sync)';
COMMENT ON COLUMN activities.local_updated_at IS 'Timestamp of last local modification (for conflict resolution)';

-- Events table
ALTER TABLE events
  ADD COLUMN needs_upload BOOLEAN DEFAULT false,
  ADD COLUMN local_updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

COMMENT ON COLUMN events.needs_upload IS 'Flag indicating record needs upload to Supabase (offline-first sync)';
COMMENT ON COLUMN events.local_updated_at IS 'Timestamp of last local modification (for conflict resolution)';

-- Carb loading plans table
ALTER TABLE carb_loading_plans
  ADD COLUMN needs_upload BOOLEAN DEFAULT false,
  ADD COLUMN local_updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

COMMENT ON COLUMN carb_loading_plans.needs_upload IS 'Flag indicating record needs upload to Supabase (offline-first sync)';
COMMENT ON COLUMN carb_loading_plans.local_updated_at IS 'Timestamp of last local modification (for conflict resolution)';

-- Carb loading days table
ALTER TABLE carb_loading_days
  ADD COLUMN needs_upload BOOLEAN DEFAULT false,
  ADD COLUMN local_updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

COMMENT ON COLUMN carb_loading_days.needs_upload IS 'Flag indicating record needs upload to Supabase (offline-first sync)';
COMMENT ON COLUMN carb_loading_days.local_updated_at IS 'Timestamp of last local modification (for conflict resolution)';

-- Activity completions table
ALTER TABLE activity_completions
  ADD COLUMN needs_upload BOOLEAN DEFAULT false,
  ADD COLUMN local_updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

COMMENT ON COLUMN activity_completions.needs_upload IS 'Flag indicating record needs upload to Supabase (offline-first sync)';
COMMENT ON COLUMN activity_completions.local_updated_at IS 'Timestamp of last local modification (for conflict resolution)';

-- User foods table
ALTER TABLE user_foods
  ADD COLUMN needs_upload BOOLEAN DEFAULT false,
  ADD COLUMN local_updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

COMMENT ON COLUMN user_foods.needs_upload IS 'Flag indicating record needs upload to Supabase (offline-first sync)';
COMMENT ON COLUMN user_foods.local_updated_at IS 'Timestamp of last local modification (for conflict resolution)';

-- ============================================================================
-- STEP 3: Add partial indexes for efficient sync queries
-- ============================================================================
-- Partial indexes only index rows where needs_upload = true for faster queries

CREATE INDEX idx_activities_needs_upload ON activities(needs_upload, user_id) WHERE needs_upload = true;
CREATE INDEX idx_events_needs_upload ON events(needs_upload, user_id) WHERE needs_upload = true;
CREATE INDEX idx_carb_loading_plans_needs_upload ON carb_loading_plans(needs_upload, user_id) WHERE needs_upload = true;
CREATE INDEX idx_carb_loading_days_needs_upload ON carb_loading_days(needs_upload) WHERE needs_upload = true;
CREATE INDEX idx_activity_completions_needs_upload ON activity_completions(needs_upload, user_id) WHERE needs_upload = true;
CREATE INDEX idx_user_foods_needs_upload ON user_foods(needs_upload, device_id) WHERE needs_upload = true;

-- ============================================================================
-- STEP 4: Update RLS policies for events table (now has user_id)
-- ============================================================================

-- Drop old policy if exists
DROP POLICY IF EXISTS "Users can view their own events" ON events;
DROP POLICY IF EXISTS "Users can insert their own events" ON events;
DROP POLICY IF EXISTS "Users can update their own events" ON events;
DROP POLICY IF EXISTS "Users can delete their own events" ON events;

-- Create new RLS policies using user_id directly
CREATE POLICY "Users can view their own events"
  ON events FOR SELECT
  USING (user_id = auth.uid()::text);

CREATE POLICY "Users can insert their own events"
  ON events FOR INSERT
  WITH CHECK (user_id = auth.uid()::text);

CREATE POLICY "Users can update their own events"
  ON events FOR UPDATE
  USING (user_id = auth.uid()::text);

CREATE POLICY "Users can delete their own events"
  ON events FOR DELETE
  USING (user_id = auth.uid()::text);

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================

-- Verify migration success
DO $$
BEGIN
  -- Check that user_id was added and backfilled
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'events' AND column_name = 'user_id'
  ) THEN
    RAISE EXCEPTION 'Migration failed: user_id column not added to events table';
  END IF;

  -- Check that sync columns were added
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'activities' AND column_name = 'needs_upload'
  ) THEN
    RAISE EXCEPTION 'Migration failed: needs_upload column not added to activities table';
  END IF;

  RAISE NOTICE 'Migration completed successfully!';
  RAISE NOTICE 'Added user_id to events table';
  RAISE NOTICE 'Added needs_upload and local_updated_at to 6 tables';
  RAISE NOTICE 'Created 6 partial indexes for sync queries';
  RAISE NOTICE 'Updated RLS policies for events table';
END $$;
