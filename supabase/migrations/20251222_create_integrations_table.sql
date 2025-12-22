-- =============================================================================
-- Final Surge Integration Schema - Phase 1
-- Migration: Create integrations table and add sync columns to activities
-- Date: December 22, 2025
-- =============================================================================

-- =============================================================================
-- PART 1: Create integrations table
-- Stores OAuth tokens and metadata for external training platform integrations
-- =============================================================================

CREATE TABLE IF NOT EXISTS integrations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider TEXT NOT NULL CHECK (provider IN ('final_surge', 'training_peaks', 'strava', 'garmin')),

  -- OAuth tokens (encrypted at rest by Supabase)
  access_token TEXT NOT NULL,
  refresh_token TEXT,
  token_expires_at TIMESTAMPTZ,

  -- Provider-specific athlete data (displayed in Settings)
  provider_athlete_id TEXT NOT NULL,
  provider_athlete_name TEXT,
  provider_athlete_email TEXT,

  -- Sync metadata
  is_active BOOLEAN DEFAULT true,
  last_sync_at TIMESTAMPTZ,
  last_sync_status TEXT CHECK (last_sync_status IS NULL OR last_sync_status IN ('success', 'error', 'pending')),
  last_sync_error TEXT,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- One integration per provider per user
  UNIQUE(user_id, provider)
);

-- Indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_integrations_user_provider ON integrations(user_id, provider);
CREATE INDEX IF NOT EXISTS idx_integrations_active ON integrations(is_active) WHERE is_active = true;

-- =============================================================================
-- PART 2: Add sync columns to activities table
-- Tracks which activities came from external providers
-- =============================================================================

-- External sync tracking
ALTER TABLE activities ADD COLUMN IF NOT EXISTS synced_from_provider TEXT;
ALTER TABLE activities ADD COLUMN IF NOT EXISTS provider_workout_id TEXT;
ALTER TABLE activities ADD COLUMN IF NOT EXISTS provider_workout_url TEXT;
ALTER TABLE activities ADD COLUMN IF NOT EXISTS last_synced_at TIMESTAMPTZ;

-- Workout subtype (e.g., "Long Run", "Walk", "Recovery", "Intervals", "Tempo")
ALTER TABLE activities ADD COLUMN IF NOT EXISTS workout_subtype TEXT;

-- Pace ranges (for workouts with "8:30-9:30" style paces)
ALTER TABLE activities ADD COLUMN IF NOT EXISTS pace_min_minutes_per_mile REAL;
ALTER TABLE activities ADD COLUMN IF NOT EXISTS pace_max_minutes_per_mile REAL;

-- Swimming distance in meters (industry standard for swimming)
ALTER TABLE activities ADD COLUMN IF NOT EXISTS distance_meters REAL;

-- Index for finding synced activities by provider and workout ID
CREATE INDEX IF NOT EXISTS idx_activities_provider_sync
  ON activities(synced_from_provider, provider_workout_id)
  WHERE synced_from_provider IS NOT NULL;

-- =============================================================================
-- PART 3: Row Level Security for integrations table
-- =============================================================================

ALTER TABLE integrations ENABLE ROW LEVEL SECURITY;

-- Users can only access their own integrations
-- Supports both authenticated users and device-based access
CREATE POLICY "Users can view own integrations"
  ON integrations FOR SELECT
  USING (
    auth.uid() = user_id
    OR user_id IN (
      SELECT id FROM users
      WHERE device_id = current_setting('request.headers', true)::json->>'x-device-id'
    )
  );

CREATE POLICY "Users can insert own integrations"
  ON integrations FOR INSERT
  WITH CHECK (
    auth.uid() = user_id
    OR user_id IN (
      SELECT id FROM users
      WHERE device_id = current_setting('request.headers', true)::json->>'x-device-id'
    )
  );

CREATE POLICY "Users can update own integrations"
  ON integrations FOR UPDATE
  USING (
    auth.uid() = user_id
    OR user_id IN (
      SELECT id FROM users
      WHERE device_id = current_setting('request.headers', true)::json->>'x-device-id'
    )
  );

CREATE POLICY "Users can delete own integrations"
  ON integrations FOR DELETE
  USING (
    auth.uid() = user_id
    OR user_id IN (
      SELECT id FROM users
      WHERE device_id = current_setting('request.headers', true)::json->>'x-device-id'
    )
  );

-- =============================================================================
-- PART 4: Updated_at trigger for integrations table
-- =============================================================================

CREATE OR REPLACE FUNCTION update_integrations_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER integrations_updated_at_trigger
  BEFORE UPDATE ON integrations
  FOR EACH ROW
  EXECUTE FUNCTION update_integrations_updated_at();
