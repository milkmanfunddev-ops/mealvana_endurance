-- ============================================================================
-- COACH MODE SCHEMA MIGRATION (Simplified)
-- ============================================================================
-- Created: 2025-12-25
-- Updated: 2026-01-07
-- Purpose: Add coach-athlete relationship and messaging functionality
-- Tables: coach_athlete_relationships, coach_messages
-- Modifications: users (is_coach flag)
-- ============================================================================

-- ============================================================================
-- PHASE 1: ADD IS_COACH FLAG TO USERS
-- ============================================================================

-- Add is_coach flag to users table (set by admin only via Supabase dashboard)
DO $$ BEGIN
  ALTER TABLE users ADD COLUMN is_coach BOOLEAN DEFAULT false;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

COMMENT ON COLUMN users.is_coach IS 'Flag indicating user has coach privileges. Set by admin only.';

-- Index for quick coach lookups
CREATE INDEX IF NOT EXISTS idx_users_is_coach ON users(is_coach) WHERE is_coach = true;

-- ============================================================================
-- PHASE 2: CREATE COACH-ATHLETE RELATIONSHIPS TABLE
-- ============================================================================

-- Tracks which coaches are connected to which athletes
CREATE TABLE IF NOT EXISTS coach_athlete_relationships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  coach_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  athlete_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  -- Status: pending, active, declined, archived
  status TEXT NOT NULL DEFAULT 'pending',

  -- Who initiated the connection
  requested_by TEXT NOT NULL,

  -- Timestamps
  requested_at TIMESTAMPTZ DEFAULT now(),
  accepted_at TIMESTAMPTZ,
  declined_at TIMESTAMPTZ,
  archived_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),

  -- One relationship per coach-athlete pair
  UNIQUE(coach_user_id, athlete_user_id),

  CONSTRAINT check_status CHECK (status IN ('pending', 'active', 'declined', 'archived')),
  CONSTRAINT check_requested_by CHECK (requested_by IN ('coach', 'athlete')),
  CONSTRAINT check_different_users CHECK (coach_user_id != athlete_user_id)
);

-- ============================================================================
-- PHASE 3: CREATE COACH MESSAGES TABLE
-- ============================================================================

-- Bidirectional messaging between coaches and athletes
-- Also used for comments on activities
CREATE TABLE IF NOT EXISTS coach_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- The coach-athlete pair (for easy filtering)
  coach_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  athlete_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  -- Who sent this message
  sender_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  -- Message content
  message_text TEXT NOT NULL,

  -- Optional: link to activity for contextual comments
  -- Note: nutrition_plan_id stored as TEXT (no FK - plans stored in activity.nutrition_plan_data JSON)
  nutrition_plan_id TEXT,
  activity_id TEXT REFERENCES activities(id) ON DELETE SET NULL,

  -- Read status
  is_read BOOLEAN DEFAULT false,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),

  CONSTRAINT check_sender CHECK (sender_user_id IN (coach_user_id, athlete_user_id)),
  CONSTRAINT message_not_empty CHECK (char_length(trim(message_text)) > 0)
);

-- ============================================================================
-- PHASE 4: CREATE INDEXES
-- ============================================================================

-- Relationships indexes
CREATE INDEX IF NOT EXISTS idx_car_coach ON coach_athlete_relationships(coach_user_id);
CREATE INDEX IF NOT EXISTS idx_car_athlete ON coach_athlete_relationships(athlete_user_id);
CREATE INDEX IF NOT EXISTS idx_car_status ON coach_athlete_relationships(status);
CREATE INDEX IF NOT EXISTS idx_car_active ON coach_athlete_relationships(coach_user_id, status) WHERE status = 'active';

-- Messages indexes
CREATE INDEX IF NOT EXISTS idx_cm_coach ON coach_messages(coach_user_id);
CREATE INDEX IF NOT EXISTS idx_cm_athlete ON coach_messages(athlete_user_id);
CREATE INDEX IF NOT EXISTS idx_cm_conversation ON coach_messages(coach_user_id, athlete_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_cm_activity ON coach_messages(activity_id) WHERE activity_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_cm_unread ON coach_messages(athlete_user_id, is_read) WHERE is_read = false;
CREATE INDEX IF NOT EXISTS idx_cm_created ON coach_messages(created_at DESC);

-- ============================================================================
-- PHASE 5: ENABLE RLS AND CREATE POLICIES
-- ============================================================================

ALTER TABLE coach_athlete_relationships ENABLE ROW LEVEL SECURITY;
ALTER TABLE coach_messages ENABLE ROW LEVEL SECURITY;

-- Relationships policies
DROP POLICY IF EXISTS "Users can view their relationships" ON coach_athlete_relationships;
CREATE POLICY "Users can view their relationships" ON coach_athlete_relationships
  FOR SELECT USING (
    coach_user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.device_id', true))
    OR athlete_user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.device_id', true))
  );

DROP POLICY IF EXISTS "Users can create relationships" ON coach_athlete_relationships;
CREATE POLICY "Users can create relationships" ON coach_athlete_relationships
  FOR INSERT WITH CHECK (
    coach_user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.device_id', true))
    OR athlete_user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.device_id', true))
  );

DROP POLICY IF EXISTS "Users can update their relationships" ON coach_athlete_relationships;
CREATE POLICY "Users can update their relationships" ON coach_athlete_relationships
  FOR UPDATE USING (
    coach_user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.device_id', true))
    OR athlete_user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.device_id', true))
  );

DROP POLICY IF EXISTS "Users can delete their relationships" ON coach_athlete_relationships;
CREATE POLICY "Users can delete their relationships" ON coach_athlete_relationships
  FOR DELETE USING (
    coach_user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.device_id', true))
    OR athlete_user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.device_id', true))
  );

-- Messages policies
DROP POLICY IF EXISTS "Users can view their messages" ON coach_messages;
CREATE POLICY "Users can view their messages" ON coach_messages
  FOR SELECT USING (
    coach_user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.device_id', true))
    OR athlete_user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.device_id', true))
  );

DROP POLICY IF EXISTS "Users can send messages" ON coach_messages;
CREATE POLICY "Users can send messages" ON coach_messages
  FOR INSERT WITH CHECK (
    sender_user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.device_id', true))
  );

DROP POLICY IF EXISTS "Users can update their messages" ON coach_messages;
CREATE POLICY "Users can update their messages" ON coach_messages
  FOR UPDATE USING (
    coach_user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.device_id', true))
    OR athlete_user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.device_id', true))
  );

DROP POLICY IF EXISTS "Users can delete their sent messages" ON coach_messages;
CREATE POLICY "Users can delete their sent messages" ON coach_messages
  FOR DELETE USING (
    sender_user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.device_id', true))
  );

-- ============================================================================
-- PHASE 6: GRANTS
-- ============================================================================

GRANT SELECT, INSERT, UPDATE, DELETE ON coach_athlete_relationships TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON coach_athlete_relationships TO authenticated;
GRANT ALL ON coach_athlete_relationships TO service_role;

GRANT SELECT, INSERT, UPDATE, DELETE ON coach_messages TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON coach_messages TO authenticated;
GRANT ALL ON coach_messages TO service_role;

-- ============================================================================
-- PHASE 7: COMMENTS
-- ============================================================================

COMMENT ON TABLE coach_athlete_relationships IS 'Tracks connections between coaches and athletes';
COMMENT ON TABLE coach_messages IS 'Bidirectional messaging and comments between coaches and athletes';

COMMENT ON COLUMN coach_messages.nutrition_plan_id IS 'Optional reference to nutrition plan (stored as TEXT, not FK since plans are in activity.nutrition_plan_data JSON)';
COMMENT ON COLUMN coach_messages.activity_id IS 'When set, this message is a comment on an activity';

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================
