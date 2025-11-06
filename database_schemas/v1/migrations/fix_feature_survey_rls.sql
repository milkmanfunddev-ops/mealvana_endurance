-- Fix Feature Survey RLS Policies
-- Issue: Current policies check for app.device_id session variable which isn't set
-- Solution: Allow anon users to insert/read their own votes (device_id based)

-- Drop existing policies
DROP POLICY IF EXISTS "Users can read their own feature survey votes" ON feature_survey_responses;
DROP POLICY IF EXISTS "Users can insert their own feature survey votes" ON feature_survey_responses;
DROP POLICY IF EXISTS "Users can update their own feature survey votes" ON feature_survey_responses;
DROP POLICY IF EXISTS "Service role can read all feature survey votes" ON feature_survey_responses;

-- Simple policy: Allow anyone to insert (device_id uniqueness enforced by database)
CREATE POLICY "Anyone can insert feature survey votes"
    ON feature_survey_responses
    FOR INSERT
    TO anon, authenticated
    WITH CHECK (true);

-- Allow users to read all votes (non-sensitive survey data)
CREATE POLICY "Anyone can read feature survey votes"
    ON feature_survey_responses
    FOR SELECT
    TO anon, authenticated
    USING (true);

-- Service role has full access
CREATE POLICY "Service role full access to feature survey votes"
    ON feature_survey_responses
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- Verification
SELECT
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd
FROM pg_policies
WHERE tablename = 'feature_survey_responses';
