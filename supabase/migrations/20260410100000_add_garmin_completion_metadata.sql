ALTER TABLE activities
ADD COLUMN IF NOT EXISTS garmin_summary_id TEXT;

ALTER TABLE activities
ADD COLUMN IF NOT EXISTS garmin_last_synced_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_activities_user_garmin_summary
  ON activities(user_id, garmin_summary_id)
  WHERE garmin_summary_id IS NOT NULL;
