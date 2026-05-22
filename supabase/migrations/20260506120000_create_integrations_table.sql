-- =============================================================================
-- Integrations Table — Server-Side Backup of OAuth Tokens
--
-- Purpose: Persist OAuth credentials and athlete profile data for external
-- training platform integrations (Final Surge, TrainingPeaks, Strava, Garmin)
-- so that they survive Drift schema resyncs and device reinstalls.
--
-- Without this table, integrations live only in the local Drift database.
-- When VersionCheckService.performSchemaResync() deletes the Drift DB, all
-- OAuth tokens are lost and users are forced to reconnect every provider.
--
-- This migration consolidates the three previously-archived integration
-- migrations into a single deployed migration.
-- =============================================================================

CREATE TABLE IF NOT EXISTS integrations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider TEXT NOT NULL CHECK (provider IN ('final_surge', 'training_peaks', 'strava', 'garmin')),

  -- OAuth tokens (encrypted at rest by Supabase)
  access_token TEXT NOT NULL,
  refresh_token TEXT,
  token_expires_at TIMESTAMPTZ,

  -- Provider-specific athlete identity (displayed in Settings)
  provider_athlete_id TEXT NOT NULL,
  provider_athlete_name TEXT,
  provider_athlete_email TEXT,

  -- Provider-supplied profile data used to auto-populate user profile during onboarding
  -- Weight/birth/gender from Training Peaks profile API; weight/body fat from Garmin body comp.
  provider_athlete_weight_kg REAL,
  provider_athlete_birth_month TEXT, -- "YYYY-MM" format (Training Peaks)
  provider_athlete_gender TEXT,      -- 'm' or 'f' (Training Peaks)
  provider_athlete_body_fat_pct REAL,

  -- Athlete training zones (HR / Speed / Power) serialized as JSON
  athlete_zones_json JSONB,

  -- Provider sync metadata (when did we last pull workouts from the provider)
  is_active BOOLEAN DEFAULT true,
  last_sync_at TIMESTAMPTZ,
  last_sync_status TEXT CHECK (last_sync_status IS NULL OR last_sync_status IN ('success', 'error', 'pending')),
  last_sync_error TEXT,

  -- Row timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(user_id, provider)
);

-- Backfill columns added by later archived migrations in case the base table
-- was previously created without them by a partial apply.
ALTER TABLE integrations ADD COLUMN IF NOT EXISTS provider_athlete_weight_kg REAL;
ALTER TABLE integrations ADD COLUMN IF NOT EXISTS provider_athlete_birth_month TEXT;
ALTER TABLE integrations ADD COLUMN IF NOT EXISTS provider_athlete_gender TEXT;
ALTER TABLE integrations ADD COLUMN IF NOT EXISTS provider_athlete_body_fat_pct REAL;
ALTER TABLE integrations ADD COLUMN IF NOT EXISTS athlete_zones_json JSONB;

CREATE INDEX IF NOT EXISTS idx_integrations_user_provider ON integrations(user_id, provider);
CREATE INDEX IF NOT EXISTS idx_integrations_active ON integrations(is_active) WHERE is_active = true;

COMMENT ON COLUMN integrations.provider_athlete_weight_kg IS 'Athlete weight in kilograms from provider profile. Convert to lbs: kg * 2.20462';
COMMENT ON COLUMN integrations.provider_athlete_birth_month IS 'Athlete birth month in YYYY-MM format (Training Peaks does not provide birth day).';
COMMENT ON COLUMN integrations.provider_athlete_gender IS 'Athlete gender: "m" or "f" (Training Peaks format).';
COMMENT ON COLUMN integrations.athlete_zones_json IS 'Serialized HR/Speed/Power zone data from Training Peaks for intensity classification.';

-- =============================================================================
-- Row Level Security
-- =============================================================================

ALTER TABLE integrations ENABLE ROW LEVEL SECURITY;

-- Wrap each policy in a DO block that swallows duplicate_object so the
-- migration is fully idempotent regardless of what state the target DB is
-- in (prior partial apply, manual creation via dashboard, etc).
DO $$ BEGIN
  CREATE POLICY "Users can view own integrations"
    ON integrations FOR SELECT
    USING (
      auth.uid() = user_id
      OR user_id IN (
        SELECT id FROM users
        WHERE device_id = current_setting('request.headers', true)::json->>'x-device-id'
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Users can insert own integrations"
    ON integrations FOR INSERT
    WITH CHECK (
      auth.uid() = user_id
      OR user_id IN (
        SELECT id FROM users
        WHERE device_id = current_setting('request.headers', true)::json->>'x-device-id'
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Users can update own integrations"
    ON integrations FOR UPDATE
    USING (
      auth.uid() = user_id
      OR user_id IN (
        SELECT id FROM users
        WHERE device_id = current_setting('request.headers', true)::json->>'x-device-id'
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Users can delete own integrations"
    ON integrations FOR DELETE
    USING (
      auth.uid() = user_id
      OR user_id IN (
        SELECT id FROM users
        WHERE device_id = current_setting('request.headers', true)::json->>'x-device-id'
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- =============================================================================
-- updated_at trigger
-- =============================================================================

CREATE OR REPLACE FUNCTION update_integrations_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS integrations_updated_at_trigger ON integrations;
CREATE TRIGGER integrations_updated_at_trigger
  BEFORE UPDATE ON integrations
  FOR EACH ROW
  EXECUTE FUNCTION update_integrations_updated_at();
