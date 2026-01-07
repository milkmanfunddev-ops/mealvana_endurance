-- ============================================================================
-- COACHES TABLE MIGRATION
-- ============================================================================
-- Created: 2026-01-07
-- Purpose: Create coaches table to track approved coaches with profiles
-- Replaces: is_coach boolean flag on users table (to be deprecated)
-- ============================================================================

-- ============================================================================
-- PHASE 1: CREATE COACHES TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS coaches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,

  -- Profile Information
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  email TEXT NOT NULL,
  bio TEXT,

  -- Status
  status TEXT NOT NULL DEFAULT 'pending', -- pending, approved, rejected

  -- Admin review
  reviewed_by TEXT, -- admin who reviewed
  reviewed_at TIMESTAMPTZ,
  rejection_reason TEXT,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),

  -- Constraints
  CONSTRAINT check_status CHECK (status IN ('pending', 'approved', 'rejected')),
  CONSTRAINT check_first_name_length CHECK (char_length(trim(first_name)) >= 1),
  CONSTRAINT check_last_name_length CHECK (char_length(trim(last_name)) >= 1),
  CONSTRAINT check_email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$')
);

-- ============================================================================
-- PHASE 2: CREATE INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_coaches_user_id ON coaches(user_id);
CREATE INDEX IF NOT EXISTS idx_coaches_status ON coaches(status);
CREATE INDEX IF NOT EXISTS idx_coaches_approved ON coaches(status) WHERE status = 'approved';
CREATE INDEX IF NOT EXISTS idx_coaches_email ON coaches(email);

-- ============================================================================
-- PHASE 3: ENABLE RLS AND CREATE POLICIES
-- ============================================================================

ALTER TABLE coaches ENABLE ROW LEVEL SECURITY;

-- Users can read their own coach record
DROP POLICY IF EXISTS "Users can read own coach record" ON coaches;
CREATE POLICY "Users can read own coach record" ON coaches
  FOR SELECT USING (
    user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.device_id', true))
  );

-- Users can read all approved coaches (for directory)
DROP POLICY IF EXISTS "Users can read approved coaches" ON coaches;
CREATE POLICY "Users can read approved coaches" ON coaches
  FOR SELECT USING (status = 'approved');

-- Users can insert their own coach application
DROP POLICY IF EXISTS "Users can insert own coach application" ON coaches;
CREATE POLICY "Users can insert own coach application" ON coaches
  FOR INSERT WITH CHECK (
    user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.device_id', true))
  );

-- Users can update their own pending application
DROP POLICY IF EXISTS "Users can update own pending application" ON coaches;
CREATE POLICY "Users can update own pending application" ON coaches
  FOR UPDATE USING (
    user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.device_id', true))
    AND status = 'pending'
  );

-- ============================================================================
-- PHASE 4: GRANTS
-- ============================================================================

GRANT SELECT, INSERT, UPDATE ON coaches TO anon;
GRANT SELECT, INSERT, UPDATE ON coaches TO authenticated;
GRANT ALL ON coaches TO service_role;

-- ============================================================================
-- PHASE 5: COMMENTS
-- ============================================================================

COMMENT ON TABLE coaches IS 'Coach profiles and applications - replaces is_coach flag';
COMMENT ON COLUMN coaches.user_id IS 'References users.id - one-to-one relationship';
COMMENT ON COLUMN coaches.status IS 'Application status: pending (waiting admin approval), approved (can coach), rejected (denied)';
COMMENT ON COLUMN coaches.reviewed_by IS 'Admin user ID who approved/rejected application';
COMMENT ON COLUMN coaches.reviewed_at IS 'Timestamp when application was reviewed';

-- ============================================================================
-- PHASE 6: TRIGGERS
-- ============================================================================

-- Auto-update updated_at timestamp
CREATE TRIGGER update_coaches_updated_at
  BEFORE UPDATE ON coaches
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================
