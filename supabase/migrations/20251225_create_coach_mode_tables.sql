-- ============================================================================
-- COACH MODE SCHEMA MIGRATION
-- ============================================================================
-- Created: 2025-12-25
-- Purpose: Add coach-athlete relationship functionality
-- Tables: coaches, coach_athlete_relationships, coach_feedback
-- Modifications: nutrition_plans, activities, workout_notes
-- ============================================================================

-- ============================================================================
-- PHASE 1: CREATE ENUMS
-- ============================================================================

DO $$ BEGIN
  CREATE TYPE relationship_status_enum AS ENUM ('pending', 'active', 'declined', 'archived');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE permission_level_enum AS ENUM ('view_only', 'full_access', 'custom');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- ============================================================================
-- PHASE 2: CREATE TABLES
-- ============================================================================

-- Table 1: coaches
CREATE TABLE IF NOT EXISTS coaches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  device_id TEXT NOT NULL UNIQUE REFERENCES users(device_id) ON DELETE CASCADE,
  coach_name TEXT NOT NULL,
  bio TEXT,
  certifications TEXT[],
  specializations TEXT[],
  business_name TEXT,
  website_url TEXT,
  email TEXT,
  phone TEXT,
  is_active BOOLEAN DEFAULT true,
  is_verified BOOLEAN DEFAULT false,
  max_athletes INTEGER DEFAULT 50,
  auto_accept_requests BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT coach_name_length CHECK (char_length(coach_name) >= 2),
  CONSTRAINT email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$' OR email IS NULL)
);

-- Table 2: coach_athlete_relationships
CREATE TABLE IF NOT EXISTS coach_athlete_relationships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  coach_id UUID NOT NULL REFERENCES coaches(id) ON DELETE CASCADE,
  athlete_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  athlete_device_id TEXT NOT NULL REFERENCES users(device_id) ON DELETE CASCADE,
  status relationship_status_enum DEFAULT 'pending' NOT NULL,
  permission_level permission_level_enum DEFAULT 'view_only' NOT NULL,
  custom_permissions JSONB DEFAULT '{
    "view_activities": true,
    "view_nutrition_plans": true,
    "view_completions": true,
    "view_notes": true,
    "view_food_preferences": false,
    "create_activities": false,
    "create_nutrition_plans": false,
    "modify_activities": false,
    "modify_nutrition_plans": false,
    "delete_activities": false,
    "delete_nutrition_plans": false,
    "add_notes": true
  }'::jsonb,
  requested_by TEXT NOT NULL,
  requested_at TIMESTAMPTZ DEFAULT now(),
  accepted_at TIMESTAMPTZ,
  declined_at TIMESTAMPTZ,
  archived_at TIMESTAMPTZ,
  coach_notes TEXT,
  athlete_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(coach_id, athlete_user_id),
  CONSTRAINT check_requested_by CHECK (requested_by IN ('coach', 'athlete')),
  CONSTRAINT check_status_dates CHECK (
    (status = 'active' AND accepted_at IS NOT NULL) OR
    (status = 'declined' AND declined_at IS NOT NULL) OR
    (status = 'archived' AND archived_at IS NOT NULL) OR
    (status = 'pending')
  )
);

-- Table 3: coach_feedback
CREATE TABLE IF NOT EXISTS coach_feedback (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  relationship_id UUID NOT NULL REFERENCES coach_athlete_relationships(id) ON DELETE CASCADE,
  coach_id UUID NOT NULL REFERENCES coaches(id) ON DELETE CASCADE,
  athlete_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  activity_id TEXT REFERENCES activities(id) ON DELETE SET NULL,
  nutrition_plan_id UUID REFERENCES nutrition_plans(id) ON DELETE SET NULL,
  feedback_text TEXT NOT NULL,
  feedback_type TEXT DEFAULT 'general',
  is_visible_to_athlete BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT check_feedback_type CHECK (
    feedback_type IN ('general', 'activity', 'nutrition', 'progress', 'goal')
  ),
  CONSTRAINT check_linked_entity CHECK (
    (activity_id IS NOT NULL AND nutrition_plan_id IS NULL) OR
    (activity_id IS NULL AND nutrition_plan_id IS NOT NULL) OR
    (activity_id IS NULL AND nutrition_plan_id IS NULL)
  ),
  CONSTRAINT feedback_text_length CHECK (char_length(feedback_text) >= 1)
);

-- ============================================================================
-- PHASE 3: MODIFY EXISTING TABLES (with idempotent checks)
-- ============================================================================

-- Modify nutrition_plans
DO $$ BEGIN
  ALTER TABLE nutrition_plans ADD COLUMN created_by_coach_id UUID REFERENCES coaches(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE nutrition_plans ADD COLUMN last_modified_by_coach_id UUID REFERENCES coaches(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE nutrition_plans ADD COLUMN coach_notes TEXT;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE nutrition_plans ADD COLUMN is_coach_created BOOLEAN DEFAULT false;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

-- Modify activities
DO $$ BEGIN
  ALTER TABLE activities ADD COLUMN created_by_coach_id UUID REFERENCES coaches(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE activities ADD COLUMN assigned_by_coach_id UUID REFERENCES coaches(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE activities ADD COLUMN coach_notes TEXT;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE activities ADD COLUMN is_coach_assigned BOOLEAN DEFAULT false;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

-- Modify workout_notes
DO $$ BEGIN
  ALTER TABLE workout_notes ADD COLUMN created_by_coach_id UUID REFERENCES coaches(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE workout_notes ADD COLUMN is_coach_note BOOLEAN DEFAULT false;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE workout_notes ADD COLUMN is_visible_to_athlete BOOLEAN DEFAULT true;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

-- ============================================================================
-- PHASE 4: CREATE INDEXES
-- ============================================================================

-- Coaches table indexes
CREATE INDEX IF NOT EXISTS idx_coaches_user_id ON coaches(user_id);
CREATE INDEX IF NOT EXISTS idx_coaches_device_id ON coaches(device_id);
CREATE INDEX IF NOT EXISTS idx_coaches_is_active ON coaches(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_coaches_specializations ON coaches USING GIN(specializations);

-- Coach-athlete relationships indexes
CREATE INDEX IF NOT EXISTS idx_coach_athlete_rel_coach ON coach_athlete_relationships(coach_id);
CREATE INDEX IF NOT EXISTS idx_coach_athlete_rel_athlete_user ON coach_athlete_relationships(athlete_user_id);
CREATE INDEX IF NOT EXISTS idx_coach_athlete_rel_athlete_device ON coach_athlete_relationships(athlete_device_id);
CREATE INDEX IF NOT EXISTS idx_coach_athlete_rel_status ON coach_athlete_relationships(status);
CREATE INDEX IF NOT EXISTS idx_coach_athlete_rel_active ON coach_athlete_relationships(coach_id, status) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_coach_athlete_rel_custom_perms ON coach_athlete_relationships USING GIN(custom_permissions);

-- Coach feedback indexes
CREATE INDEX IF NOT EXISTS idx_coach_feedback_relationship ON coach_feedback(relationship_id);
CREATE INDEX IF NOT EXISTS idx_coach_feedback_coach ON coach_feedback(coach_id);
CREATE INDEX IF NOT EXISTS idx_coach_feedback_athlete ON coach_feedback(athlete_user_id);
CREATE INDEX IF NOT EXISTS idx_coach_feedback_activity ON coach_feedback(activity_id) WHERE activity_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_coach_feedback_nutrition_plan ON coach_feedback(nutrition_plan_id) WHERE nutrition_plan_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_coach_feedback_created ON coach_feedback(created_at DESC);

-- Modified table indexes
CREATE INDEX IF NOT EXISTS idx_nutrition_plans_created_by_coach ON nutrition_plans(created_by_coach_id) WHERE created_by_coach_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_activities_created_by_coach ON activities(created_by_coach_id) WHERE created_by_coach_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_activities_assigned_by_coach ON activities(assigned_by_coach_id) WHERE assigned_by_coach_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_workout_notes_coach ON workout_notes(created_by_coach_id) WHERE created_by_coach_id IS NOT NULL;

-- ============================================================================
-- PHASE 5: ENABLE RLS AND CREATE POLICIES
-- ============================================================================

-- Enable RLS on new tables
ALTER TABLE coaches ENABLE ROW LEVEL SECURITY;
ALTER TABLE coach_athlete_relationships ENABLE ROW LEVEL SECURITY;
ALTER TABLE coach_feedback ENABLE ROW LEVEL SECURITY;

-- Coaches table policies
DROP POLICY IF EXISTS "Coaches can read own profile" ON coaches;
CREATE POLICY "Coaches can read own profile" ON coaches
  FOR SELECT
  USING (device_id = current_setting('app.device_id', true));

DROP POLICY IF EXISTS "Coaches can update own profile" ON coaches;
CREATE POLICY "Coaches can update own profile" ON coaches
  FOR UPDATE
  USING (device_id = current_setting('app.device_id', true));

DROP POLICY IF EXISTS "Anyone can read active coaches" ON coaches;
CREATE POLICY "Anyone can read active coaches" ON coaches
  FOR SELECT
  USING (is_active = true);

DROP POLICY IF EXISTS "Users can create coach profile" ON coaches;
CREATE POLICY "Users can create coach profile" ON coaches
  FOR INSERT
  WITH CHECK (device_id = current_setting('app.device_id', true));

-- Coach-athlete relationships policies
DROP POLICY IF EXISTS "Coaches can view their relationships" ON coach_athlete_relationships;
CREATE POLICY "Coaches can view their relationships" ON coach_athlete_relationships
  FOR SELECT
  USING (
    coach_id IN (SELECT id FROM coaches WHERE device_id = current_setting('app.device_id', true))
  );

DROP POLICY IF EXISTS "Athletes can view their relationships" ON coach_athlete_relationships;
CREATE POLICY "Athletes can view their relationships" ON coach_athlete_relationships
  FOR SELECT
  USING (
    athlete_device_id = current_setting('app.device_id', true)
  );

DROP POLICY IF EXISTS "Coaches can insert relationship requests" ON coach_athlete_relationships;
CREATE POLICY "Coaches can insert relationship requests" ON coach_athlete_relationships
  FOR INSERT
  WITH CHECK (
    coach_id IN (SELECT id FROM coaches WHERE device_id = current_setting('app.device_id', true))
    AND requested_by = 'coach'
  );

DROP POLICY IF EXISTS "Athletes can insert relationship requests" ON coach_athlete_relationships;
CREATE POLICY "Athletes can insert relationship requests" ON coach_athlete_relationships
  FOR INSERT
  WITH CHECK (
    athlete_device_id = current_setting('app.device_id', true)
    AND requested_by = 'athlete'
  );

DROP POLICY IF EXISTS "Coaches can update their relationships" ON coach_athlete_relationships;
CREATE POLICY "Coaches can update their relationships" ON coach_athlete_relationships
  FOR UPDATE
  USING (
    coach_id IN (SELECT id FROM coaches WHERE device_id = current_setting('app.device_id', true))
  );

DROP POLICY IF EXISTS "Athletes can update their relationships" ON coach_athlete_relationships;
CREATE POLICY "Athletes can update their relationships" ON coach_athlete_relationships
  FOR UPDATE
  USING (
    athlete_device_id = current_setting('app.device_id', true)
  );

DROP POLICY IF EXISTS "Both parties can delete relationships" ON coach_athlete_relationships;
CREATE POLICY "Both parties can delete relationships" ON coach_athlete_relationships
  FOR DELETE
  USING (
    coach_id IN (SELECT id FROM coaches WHERE device_id = current_setting('app.device_id', true))
    OR athlete_device_id = current_setting('app.device_id', true)
  );

-- Coach feedback policies
DROP POLICY IF EXISTS "Coaches can manage their feedback" ON coach_feedback;
CREATE POLICY "Coaches can manage their feedback" ON coach_feedback
  FOR ALL
  USING (
    coach_id IN (SELECT id FROM coaches WHERE device_id = current_setting('app.device_id', true))
  );

DROP POLICY IF EXISTS "Athletes can view feedback for them" ON coach_feedback;
CREATE POLICY "Athletes can view feedback for them" ON coach_feedback
  FOR SELECT
  USING (
    athlete_user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.device_id', true))
    AND is_visible_to_athlete = true
  );

-- ============================================================================
-- PHASE 6: GRANTS
-- ============================================================================

GRANT SELECT, INSERT, UPDATE, DELETE ON coaches TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON coaches TO authenticated;
GRANT ALL ON coaches TO service_role;

GRANT SELECT, INSERT, UPDATE, DELETE ON coach_athlete_relationships TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON coach_athlete_relationships TO authenticated;
GRANT ALL ON coach_athlete_relationships TO service_role;

GRANT SELECT, INSERT, UPDATE, DELETE ON coach_feedback TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON coach_feedback TO authenticated;
GRANT ALL ON coach_feedback TO service_role;

-- ============================================================================
-- PHASE 7: HELPER FUNCTIONS
-- ============================================================================

-- Function to check if a coach has permission for an athlete
CREATE OR REPLACE FUNCTION has_coach_permission(
  p_coach_device_id TEXT,
  p_athlete_device_id TEXT,
  p_permission TEXT DEFAULT 'view_activities'
)
RETURNS BOOLEAN AS $$
DECLARE
  v_relationship coach_athlete_relationships%ROWTYPE;
BEGIN
  SELECT * INTO v_relationship
  FROM coach_athlete_relationships car
  JOIN coaches c ON car.coach_id = c.id
  WHERE c.device_id = p_coach_device_id
    AND car.athlete_device_id = p_athlete_device_id
    AND car.status = 'active';

  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;

  -- Check permission level
  IF v_relationship.permission_level = 'full_access' THEN
    RETURN TRUE;
  ELSIF v_relationship.permission_level = 'view_only' THEN
    RETURN p_permission LIKE 'view_%';
  ELSE
    -- Custom permissions
    RETURN (v_relationship.custom_permissions ->> p_permission)::BOOLEAN;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get all athletes for a coach
CREATE OR REPLACE FUNCTION get_coach_athletes(p_coach_device_id TEXT)
RETURNS TABLE (
  athlete_id UUID,
  athlete_device_id TEXT,
  relationship_status relationship_status_enum,
  permission_level permission_level_enum,
  connected_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    car.athlete_user_id,
    car.athlete_device_id,
    car.status,
    car.permission_level,
    car.accepted_at
  FROM coach_athlete_relationships car
  JOIN coaches c ON car.coach_id = c.id
  WHERE c.device_id = p_coach_device_id
    AND car.status = 'active'
  ORDER BY car.accepted_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get all coaches for an athlete
CREATE OR REPLACE FUNCTION get_athlete_coaches(p_athlete_device_id TEXT)
RETURNS TABLE (
  coach_id UUID,
  coach_name TEXT,
  coach_device_id TEXT,
  relationship_status relationship_status_enum,
  permission_level permission_level_enum,
  connected_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    c.id,
    c.coach_name,
    c.device_id,
    car.status,
    car.permission_level,
    car.accepted_at
  FROM coach_athlete_relationships car
  JOIN coaches c ON car.coach_id = c.id
  WHERE car.athlete_device_id = p_athlete_device_id
    AND car.status = 'active'
  ORDER BY car.accepted_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- PHASE 8: COMMENTS
-- ============================================================================

COMMENT ON TABLE coaches IS 'Coach profiles for users who provide coaching services';
COMMENT ON COLUMN coaches.user_id IS 'References users.id - one-to-one relationship';
COMMENT ON COLUMN coaches.device_id IS 'References users.device_id - for device-based auth';
COMMENT ON COLUMN coaches.max_athletes IS 'Maximum number of athletes this coach can manage';
COMMENT ON COLUMN coaches.is_verified IS 'Admin verification flag for trusted coaches';

COMMENT ON TABLE coach_athlete_relationships IS 'Tracks coach-athlete relationships with status and permissions';
COMMENT ON COLUMN coach_athlete_relationships.status IS 'Relationship lifecycle: pending -> active/declined/archived';
COMMENT ON COLUMN coach_athlete_relationships.permission_level IS 'Permission tier: view_only, full_access, or custom';
COMMENT ON COLUMN coach_athlete_relationships.custom_permissions IS 'Granular JSON permissions when permission_level = custom';
COMMENT ON COLUMN coach_athlete_relationships.requested_by IS 'Who initiated: coach or athlete';

COMMENT ON TABLE coach_feedback IS 'Coach feedback/notes for athletes on activities, plans, and progress';
COMMENT ON COLUMN coach_feedback.activity_id IS 'Optional link to specific activity';
COMMENT ON COLUMN coach_feedback.nutrition_plan_id IS 'Optional link to specific nutrition plan';
COMMENT ON COLUMN coach_feedback.is_visible_to_athlete IS 'Controls whether athlete can see this feedback';

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================
