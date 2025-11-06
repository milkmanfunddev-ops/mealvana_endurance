-- Migration: Add feature_survey_responses table
-- Date: 2025-01-05
-- Description: Add table to track user votes for feature requests (one vote per device)
-- Target: Both dev and prod Supabase instances

-- Create feature_survey_responses table
CREATE TABLE IF NOT EXISTS feature_survey_responses (
    id TEXT PRIMARY KEY NOT NULL,
    device_id TEXT NOT NULL UNIQUE,
    selected_features TEXT NOT NULL,
    voted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Ensure one vote per device
    CONSTRAINT unique_device_vote UNIQUE (device_id)
);

-- Create index for faster device_id lookups
CREATE INDEX IF NOT EXISTS idx_feature_survey_responses_device_id
    ON feature_survey_responses(device_id);

-- Create index for timestamp queries
CREATE INDEX IF NOT EXISTS idx_feature_survey_responses_voted_at
    ON feature_survey_responses(voted_at);

-- Add comments for documentation
COMMENT ON TABLE feature_survey_responses IS 'Stores user votes for feature requests. One vote per device.';
COMMENT ON COLUMN feature_survey_responses.id IS 'Primary key - UUID';
COMMENT ON COLUMN feature_survey_responses.device_id IS 'Device ID of the user who voted';
COMMENT ON COLUMN feature_survey_responses.selected_features IS 'JSON array of selected feature IDs (exactly 3). Example: ["shopping_list", "coach_sharing", "recipes"]';
COMMENT ON COLUMN feature_survey_responses.voted_at IS 'Timestamp of when the vote was cast';

-- Row Level Security (RLS) Policies
-- Note: Adjust these based on your auth requirements

-- Enable RLS
ALTER TABLE feature_survey_responses ENABLE ROW LEVEL SECURITY;

-- Policy: Users can read their own votes
CREATE POLICY "Users can read their own feature survey votes"
    ON feature_survey_responses
    FOR SELECT
    USING (device_id = current_setting('app.device_id', true));

-- Policy: Users can insert their own votes (if they haven't voted yet)
CREATE POLICY "Users can insert their own feature survey votes"
    ON feature_survey_responses
    FOR INSERT
    WITH CHECK (device_id = current_setting('app.device_id', true));

-- Policy: Users can update their own votes
CREATE POLICY "Users can update their own feature survey votes"
    ON feature_survey_responses
    FOR UPDATE
    USING (device_id = current_setting('app.device_id', true))
    WITH CHECK (device_id = current_setting('app.device_id', true));

-- Policy: Admin/service role can read all votes (for analytics)
CREATE POLICY "Service role can read all feature survey votes"
    ON feature_survey_responses
    FOR SELECT
    USING (current_setting('role', true) = 'service_role');

-- Grant permissions to authenticated users
GRANT SELECT, INSERT, UPDATE ON feature_survey_responses TO authenticated;

-- Grant full permissions to service role (for analytics/admin)
GRANT ALL ON feature_survey_responses TO service_role;

-- Verification queries (run these after applying migration to verify)
-- SELECT COUNT(*) FROM feature_survey_responses;
-- SELECT * FROM pg_indexes WHERE tablename = 'feature_survey_responses';
-- SELECT * FROM pg_policies WHERE tablename = 'feature_survey_responses';
