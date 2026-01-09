-- Enable Realtime for coach_messages table
-- Run this in Supabase SQL Editor

-- 1. Enable realtime for the table (skip if already enabled)
-- If you get error "already member", that's GOOD - realtime is enabled!
-- ALTER PUBLICATION supabase_realtime ADD TABLE coach_messages;

-- 2. Verify RLS policies allow SELECT (required for realtime)
-- Check existing policies
SELECT
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual
FROM pg_policies
WHERE tablename = 'coach_messages';

-- 3. If no SELECT policy exists, create one
-- This allows users to receive realtime updates for their own messages
-- Drop existing policy if it exists (ignore errors if it doesn't)
DROP POLICY IF EXISTS "Users can view their conversation messages" ON coach_messages;

-- Create the policy
CREATE POLICY "Users can view their conversation messages"
ON coach_messages
FOR SELECT
USING (
  auth.uid() = coach_user_id
  OR auth.uid() = athlete_user_id
);

-- 4. Verify realtime is enabled
SELECT
  schemaname,
  tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
  AND tablename = 'coach_messages';

-- Expected result: Should show one row with coach_messages
-- If no rows returned, realtime is NOT enabled for this table
