-- Garmin user mapping table
-- Maps Garmin userIds to our internal user_profiles.id
-- Required because Garmin push/ping notifications identify users
-- by their Garmin userId, not our userId.

CREATE TABLE IF NOT EXISTS garmin_user_mappings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  garmin_user_id TEXT NOT NULL,
  access_token TEXT,
  refresh_token TEXT,
  token_expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(garmin_user_id)
);

-- Index for reverse lookup (our userId → Garmin mapping)
CREATE INDEX IF NOT EXISTS idx_garmin_user_mappings_user_id
  ON garmin_user_mappings(user_id);

-- Garmin health data table (wellness, sleep, body comp, stress, epochs)
-- Stores all non-activity health data from Garmin push notifications.
CREATE TABLE IF NOT EXISTS garmin_health_data (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  garmin_user_id TEXT NOT NULL,
  summary_id TEXT NOT NULL,
  data_type TEXT NOT NULL, -- 'daily', 'sleep', 'body_composition', 'stress', 'epoch', 'user_metrics'
  calendar_date DATE NOT NULL,
  data JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(summary_id)
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_garmin_health_data_user_date
  ON garmin_health_data(user_id, calendar_date);

CREATE INDEX IF NOT EXISTS idx_garmin_health_data_type
  ON garmin_health_data(user_id, data_type, calendar_date);

-- Enable RLS
ALTER TABLE garmin_user_mappings ENABLE ROW LEVEL SECURITY;
ALTER TABLE garmin_health_data ENABLE ROW LEVEL SECURITY;

-- RLS policies: users can only see their own data
CREATE POLICY "Users can view own garmin mappings"
  ON garmin_user_mappings FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can view own garmin health data"
  ON garmin_health_data FOR SELECT
  USING (auth.uid() = user_id);

-- Service role needs full access for push/ping handlers
CREATE POLICY "Service role full access on garmin_user_mappings"
  ON garmin_user_mappings FOR ALL
  USING (auth.role() = 'service_role');

CREATE POLICY "Service role full access on garmin_health_data"
  ON garmin_health_data FOR ALL
  USING (auth.role() = 'service_role');
