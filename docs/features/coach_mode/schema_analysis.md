# Coach Mode Database Schema Analysis

**Document Created**: 2025-12-11
**Purpose**: Analyze current schema and recommend changes to support coach-athlete functionality

---

## Executive Summary

This document provides a detailed analysis of schema changes required to implement a coach mode feature where:
- Coaches can have multiple athletes
- Coaches can view their athletes' activities and nutrition plans
- Athletes can be linked to one or more coaches
- We track coach-athlete relationships with granular permissions

---

## 1. Current Schema Analysis

### 1.1 Existing Tables Overview

The current production schema has **27 tables** organized into these categories:

#### Core User Tables
- `users` - User profiles and settings (device-based authentication)
- `food_preferences` - User food preferences (like/dislike/willing_to_try)
- `feedback` - Plan feedback and ratings

#### Activity & Training Tables
- `activities` - Calendar entries for workouts (running/cycling/swimming)
- `events` - Specialized race/competition data
- `activity_completions` - Completion records
- `nutrition_plans` - AI-generated nutrition plans
- `workout_notes` - User journal entries

#### Food Database Tables
- `foods` - Global food database with sport suitability
- `user_foods` - User-created/scanned foods
- `product_types` - Food categories
- `categories` - Timing categories (before/during/after)
- `food_categories` - Food-to-category mappings
- `user_food_categories` - User food timing
- `user_hidden_foods` - Hidden foods per user

#### Carb Loading Feature Tables
- `carb_loading_plans` - Carb loading plans
- `carb_loading_days` - Individual day entries
- `carb_loading_foods` - Global carb loading foods
- `carb_loading_user_foods` - User carb loading foods
- `carb_loading_food_meal_types` - Global food-meal links
- `carb_loading_user_food_meal_types` - User food-meal links
- `carb_loading_day_meals` - Actual food selections
- `meal_types` - Meal categories

#### Other Tables
- `app_content` - Dynamic UI text/parameters
- `edge_functions` - Edge function code
- `macro_targets_table` - Nutrition target calculations
- `feature_survey_responses` - Feature voting

### 1.2 Key Authentication Pattern

**Current Design**: Device-based authentication
- Primary identifier: `device_id` (text, unique per device)
- Secondary identifier: `users.id` (UUID, auto-generated)
- Authentication columns in `users` table:
  ```sql
  auth_user_id              uuid
  auth_provider             auth_provider_enum (anonymous, email, google, apple)
  is_anonymous              boolean (default true)
  auth_skipped_at           timestamp
  ```

**Key Foreign Key Pattern**:
- Most tables use `device_id` for relationships (text-based)
- Some newer tables use `user_id` (text) for filtering
- Examples:
  - `nutrition_plans.device_id` → `users.device_id`
  - `activities.user_id` → stored as text (NOT FK to users table)
  - `food_preferences.device_id` → `users.device_id`

### 1.3 Row Level Security (RLS) Pattern

**Current RLS Pattern**:
```sql
-- Device-based RLS (most common)
CREATE POLICY "policy_name" ON table_name
  FOR SELECT
  USING (device_id = current_setting('app.device_id', true));

-- User ID based RLS (for activities/events)
CREATE POLICY "activities_select_policy" ON activities
  FOR SELECT
  USING (user_id = current_setting('app.user_id', true));

-- Auth-based RLS (for events with auth.uid())
CREATE POLICY "Users can view their own events" ON events
  FOR SELECT
  USING (user_id = auth.uid()::text);
```

**Key Observation**: Mixed RLS patterns indicate transition from device-only to auth-based system.

---

## 2. Coach Mode Requirements

### 2.1 Functional Requirements

1. **Coach Profiles**
   - Coaches are users with elevated permissions
   - Can manage multiple athletes
   - Can view athlete data (activities, nutrition plans, progress)
   - Can leave notes/feedback for athletes

2. **Athlete Management**
   - Athletes can have multiple coaches (1:N relationship)
   - Athletes control which coaches can access their data
   - Athletes can revoke coach access at any time

3. **Coach-Athlete Relationships**
   - Track relationship status (pending, active, archived)
   - Track permission levels (view-only, full-access, custom)
   - Track relationship metadata (start date, notes, etc.)

4. **Data Access Patterns**
   - Coaches need read access to:
     - Activities (planned and completed)
     - Nutrition plans
     - Activity completions
     - Workout notes
     - Food preferences (optional)
   - Coaches may need write access to:
     - Workout notes (coach feedback)
     - Activities (create plans for athletes)
     - Nutrition plans (create/modify plans)

### 2.2 Permission Levels

Three-tier permission model:

1. **View Only** (default)
   - Read access to activities, nutrition plans, completions
   - Cannot modify athlete data
   - Can leave comments/feedback

2. **Full Access**
   - Read and write access to activities and nutrition plans
   - Can create plans for athlete
   - Can modify existing plans
   - Cannot delete athlete data

3. **Custom Permissions** (future)
   - Granular control over specific data types
   - JSON-based permission flags

---

## 3. Schema Design Recommendations

### 3.1 New Tables Required

#### Table 1: `coaches` (Coach Profiles)

```sql
CREATE TABLE coaches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  device_id TEXT NOT NULL UNIQUE REFERENCES users(device_id) ON DELETE CASCADE,

  -- Coach Details
  coach_name TEXT NOT NULL,
  bio TEXT,
  certifications TEXT[], -- Array of certification names
  specializations TEXT[], -- e.g., ["marathon", "triathlon", "nutrition"]

  -- Business Info (optional)
  business_name TEXT,
  website_url TEXT,
  email TEXT,
  phone TEXT,

  -- Status
  is_active BOOLEAN DEFAULT true,
  is_verified BOOLEAN DEFAULT false, -- Admin verification flag

  -- Settings
  max_athletes INTEGER DEFAULT 50, -- Limit number of athletes
  auto_accept_requests BOOLEAN DEFAULT false, -- Auto-accept athlete requests

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),

  -- Constraints
  CONSTRAINT coach_name_length CHECK (char_length(coach_name) >= 2),
  CONSTRAINT email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$' OR email IS NULL)
);

-- Indexes
CREATE INDEX idx_coaches_user_id ON coaches(user_id);
CREATE INDEX idx_coaches_device_id ON coaches(device_id);
CREATE INDEX idx_coaches_is_active ON coaches(is_active) WHERE is_active = true;
CREATE INDEX idx_coaches_specializations ON coaches USING GIN(specializations);

-- RLS Policies
CREATE POLICY "Coaches can read own profile" ON coaches
  FOR SELECT
  USING (device_id = current_setting('app.device_id', true));

CREATE POLICY "Coaches can update own profile" ON coaches
  FOR UPDATE
  USING (device_id = current_setting('app.device_id', true));

CREATE POLICY "Anyone can read active coaches" ON coaches
  FOR SELECT
  USING (is_active = true);

-- Grants
GRANT SELECT, INSERT, UPDATE, DELETE ON coaches TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON coaches TO authenticated;
GRANT ALL ON coaches TO service_role;
```

**Comments**:
```sql
COMMENT ON TABLE coaches IS 'Coach profiles for users who provide coaching services';
COMMENT ON COLUMN coaches.user_id IS 'References users.id - one-to-one relationship';
COMMENT ON COLUMN coaches.device_id IS 'References users.device_id - for device-based auth';
COMMENT ON COLUMN coaches.max_athletes IS 'Maximum number of athletes this coach can manage';
COMMENT ON COLUMN coaches.is_verified IS 'Admin verification flag for trusted coaches';
```

---

#### Table 2: `coach_athlete_relationships` (Core Relationship Table)

```sql
CREATE TYPE relationship_status_enum AS ENUM ('pending', 'active', 'declined', 'archived');
CREATE TYPE permission_level_enum AS ENUM ('view_only', 'full_access', 'custom');

CREATE TABLE coach_athlete_relationships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Relationship Participants
  coach_id UUID NOT NULL REFERENCES coaches(id) ON DELETE CASCADE,
  athlete_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  athlete_device_id TEXT NOT NULL REFERENCES users(device_id) ON DELETE CASCADE,

  -- Relationship Status
  status relationship_status_enum DEFAULT 'pending' NOT NULL,
  permission_level permission_level_enum DEFAULT 'view_only' NOT NULL,

  -- Custom Permissions (JSON for granular control)
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

  -- Request Metadata
  requested_by TEXT NOT NULL, -- 'coach' or 'athlete'
  requested_at TIMESTAMPTZ DEFAULT now(),

  -- Relationship Lifecycle
  accepted_at TIMESTAMPTZ,
  declined_at TIMESTAMPTZ,
  archived_at TIMESTAMPTZ,

  -- Notes
  coach_notes TEXT, -- Private notes from coach
  athlete_notes TEXT, -- Private notes from athlete

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),

  -- Constraints
  UNIQUE(coach_id, athlete_user_id),
  CONSTRAINT check_requested_by CHECK (requested_by IN ('coach', 'athlete')),
  CONSTRAINT check_status_dates CHECK (
    (status = 'active' AND accepted_at IS NOT NULL) OR
    (status = 'declined' AND declined_at IS NOT NULL) OR
    (status = 'archived' AND archived_at IS NOT NULL) OR
    (status = 'pending')
  )
);

-- Indexes
CREATE INDEX idx_coach_athlete_rel_coach ON coach_athlete_relationships(coach_id);
CREATE INDEX idx_coach_athlete_rel_athlete_user ON coach_athlete_relationships(athlete_user_id);
CREATE INDEX idx_coach_athlete_rel_athlete_device ON coach_athlete_relationships(athlete_device_id);
CREATE INDEX idx_coach_athlete_rel_status ON coach_athlete_relationships(status);
CREATE INDEX idx_coach_athlete_rel_active ON coach_athlete_relationships(coach_id, status)
  WHERE status = 'active';
CREATE INDEX idx_coach_athlete_rel_custom_perms ON coach_athlete_relationships USING GIN(custom_permissions);

-- RLS Policies
CREATE POLICY "Coaches can view their relationships" ON coach_athlete_relationships
  FOR SELECT
  USING (
    coach_id IN (SELECT id FROM coaches WHERE device_id = current_setting('app.device_id', true))
  );

CREATE POLICY "Athletes can view their relationships" ON coach_athlete_relationships
  FOR SELECT
  USING (
    athlete_device_id = current_setting('app.device_id', true)
  );

CREATE POLICY "Coaches can insert relationship requests" ON coach_athlete_relationships
  FOR INSERT
  WITH CHECK (
    coach_id IN (SELECT id FROM coaches WHERE device_id = current_setting('app.device_id', true))
    AND requested_by = 'coach'
  );

CREATE POLICY "Athletes can insert relationship requests" ON coach_athlete_relationships
  FOR INSERT
  WITH CHECK (
    athlete_device_id = current_setting('app.device_id', true)
    AND requested_by = 'athlete'
  );

CREATE POLICY "Coaches can update their relationships" ON coach_athlete_relationships
  FOR UPDATE
  USING (
    coach_id IN (SELECT id FROM coaches WHERE device_id = current_setting('app.device_id', true))
  );

CREATE POLICY "Athletes can update their relationships" ON coach_athlete_relationships
  FOR UPDATE
  USING (
    athlete_device_id = current_setting('app.device_id', true)
  );

CREATE POLICY "Both parties can delete relationships" ON coach_athlete_relationships
  FOR DELETE
  USING (
    coach_id IN (SELECT id FROM coaches WHERE device_id = current_setting('app.device_id', true))
    OR athlete_device_id = current_setting('app.device_id', true)
  );

-- Grants
GRANT SELECT, INSERT, UPDATE, DELETE ON coach_athlete_relationships TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON coach_athlete_relationships TO authenticated;
GRANT ALL ON coach_athlete_relationships TO service_role;
```

**Comments**:
```sql
COMMENT ON TABLE coach_athlete_relationships IS 'Tracks coach-athlete relationships with status and permissions';
COMMENT ON COLUMN coach_athlete_relationships.status IS 'Relationship lifecycle: pending → active/declined/archived';
COMMENT ON COLUMN coach_athlete_relationships.permission_level IS 'Permission tier: view_only, full_access, or custom';
COMMENT ON COLUMN coach_athlete_relationships.custom_permissions IS 'Granular JSON permissions when permission_level = custom';
COMMENT ON COLUMN coach_athlete_relationships.requested_by IS 'Who initiated: coach or athlete';
```

---

#### Table 3: `coach_feedback` (Coach Notes & Feedback)

```sql
CREATE TABLE coach_feedback (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Relationship Context
  relationship_id UUID NOT NULL REFERENCES coach_athlete_relationships(id) ON DELETE CASCADE,
  coach_id UUID NOT NULL REFERENCES coaches(id) ON DELETE CASCADE,
  athlete_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  -- Linked Entity (what this feedback is about)
  activity_id TEXT REFERENCES activities(id) ON DELETE SET NULL,
  nutrition_plan_id UUID REFERENCES nutrition_plans(id) ON DELETE SET NULL,

  -- Feedback Content
  feedback_text TEXT NOT NULL,
  feedback_type TEXT DEFAULT 'general', -- 'general', 'activity', 'nutrition', 'progress'

  -- Privacy
  is_visible_to_athlete BOOLEAN DEFAULT true,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),

  -- Constraints
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

-- Indexes
CREATE INDEX idx_coach_feedback_relationship ON coach_feedback(relationship_id);
CREATE INDEX idx_coach_feedback_coach ON coach_feedback(coach_id);
CREATE INDEX idx_coach_feedback_athlete ON coach_feedback(athlete_user_id);
CREATE INDEX idx_coach_feedback_activity ON coach_feedback(activity_id) WHERE activity_id IS NOT NULL;
CREATE INDEX idx_coach_feedback_nutrition_plan ON coach_feedback(nutrition_plan_id) WHERE nutrition_plan_id IS NOT NULL;
CREATE INDEX idx_coach_feedback_created ON coach_feedback(created_at DESC);

-- RLS Policies
CREATE POLICY "Coaches can manage their feedback" ON coach_feedback
  FOR ALL
  USING (
    coach_id IN (SELECT id FROM coaches WHERE device_id = current_setting('app.device_id', true))
  );

CREATE POLICY "Athletes can view feedback for them" ON coach_feedback
  FOR SELECT
  USING (
    athlete_user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.device_id', true))
    AND is_visible_to_athlete = true
  );

-- Grants
GRANT SELECT, INSERT, UPDATE, DELETE ON coach_feedback TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON coach_feedback TO authenticated;
GRANT ALL ON coach_feedback TO service_role;
```

**Comments**:
```sql
COMMENT ON TABLE coach_feedback IS 'Coach feedback/notes for athletes on activities, plans, and progress';
COMMENT ON COLUMN coach_feedback.activity_id IS 'Optional link to specific activity';
COMMENT ON COLUMN coach_feedback.nutrition_plan_id IS 'Optional link to specific nutrition plan';
COMMENT ON COLUMN coach_feedback.is_visible_to_athlete IS 'Controls whether athlete can see this feedback';
```

---

### 3.2 Modifications to Existing Tables

#### Modification 1: `nutrition_plans` Table

**Add coach tracking columns:**

```sql
-- Add columns to track coach involvement
ALTER TABLE nutrition_plans
  ADD COLUMN created_by_coach_id UUID REFERENCES coaches(id) ON DELETE SET NULL,
  ADD COLUMN last_modified_by_coach_id UUID REFERENCES coaches(id) ON DELETE SET NULL,
  ADD COLUMN coach_notes TEXT,
  ADD COLUMN is_coach_created BOOLEAN DEFAULT false;

-- Add index for coach queries
CREATE INDEX idx_nutrition_plans_created_by_coach
  ON nutrition_plans(created_by_coach_id)
  WHERE created_by_coach_id IS NOT NULL;

-- Add comments
COMMENT ON COLUMN nutrition_plans.created_by_coach_id IS 'Coach who created this plan (NULL if athlete-created)';
COMMENT ON COLUMN nutrition_plans.last_modified_by_coach_id IS 'Coach who last modified this plan';
COMMENT ON COLUMN nutrition_plans.coach_notes IS 'Private notes from coach about this plan';
COMMENT ON COLUMN nutrition_plans.is_coach_created IS 'True if plan was created by a coach for the athlete';
```

**Update RLS policies to allow coach access:**

```sql
-- Allow coaches to view their athletes' plans
CREATE POLICY "Coaches can view athlete plans" ON nutrition_plans
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM coach_athlete_relationships r
      JOIN coaches c ON c.id = r.coach_id
      WHERE r.athlete_device_id = nutrition_plans.device_id
        AND r.status = 'active'
        AND c.device_id = current_setting('app.device_id', true)
        AND (
          r.custom_permissions->>'view_nutrition_plans' = 'true'
          OR r.permission_level = 'full_access'
        )
    )
  );

-- Allow coaches to create plans for athletes (if permitted)
CREATE POLICY "Coaches can create athlete plans" ON nutrition_plans
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM coach_athlete_relationships r
      JOIN coaches c ON c.id = r.coach_id
      WHERE r.athlete_device_id = nutrition_plans.device_id
        AND r.status = 'active'
        AND c.device_id = current_setting('app.device_id', true)
        AND (
          r.custom_permissions->>'create_nutrition_plans' = 'true'
          OR r.permission_level = 'full_access'
        )
    )
  );

-- Allow coaches to modify plans (if permitted)
CREATE POLICY "Coaches can update athlete plans" ON nutrition_plans
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM coach_athlete_relationships r
      JOIN coaches c ON c.id = r.coach_id
      WHERE r.athlete_device_id = nutrition_plans.device_id
        AND r.status = 'active'
        AND c.device_id = current_setting('app.device_id', true)
        AND (
          r.custom_permissions->>'modify_nutrition_plans' = 'true'
          OR r.permission_level = 'full_access'
        )
    )
  );
```

---

#### Modification 2: `activities` Table

**Add coach tracking columns:**

```sql
-- Add columns to track coach involvement
ALTER TABLE activities
  ADD COLUMN created_by_coach_id UUID REFERENCES coaches(id) ON DELETE SET NULL,
  ADD COLUMN assigned_by_coach_id UUID REFERENCES coaches(id) ON DELETE SET NULL,
  ADD COLUMN coach_notes TEXT,
  ADD COLUMN is_coach_assigned BOOLEAN DEFAULT false;

-- Add indexes for coach queries
CREATE INDEX idx_activities_created_by_coach
  ON activities(created_by_coach_id)
  WHERE created_by_coach_id IS NOT NULL;

CREATE INDEX idx_activities_assigned_by_coach
  ON activities(assigned_by_coach_id)
  WHERE assigned_by_coach_id IS NOT NULL;

-- Add comments
COMMENT ON COLUMN activities.created_by_coach_id IS 'Coach who created this activity';
COMMENT ON COLUMN activities.assigned_by_coach_id IS 'Coach who assigned this activity to athlete';
COMMENT ON COLUMN activities.coach_notes IS 'Private notes from coach about this activity';
COMMENT ON COLUMN activities.is_coach_assigned IS 'True if activity was assigned by a coach';
```

**Update RLS policies to allow coach access:**

```sql
-- Allow coaches to view their athletes' activities
CREATE POLICY "Coaches can view athlete activities" ON activities
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM coach_athlete_relationships r
      JOIN coaches c ON c.id = r.coach_id
      JOIN users u ON u.device_id = r.athlete_device_id
      WHERE u.id::text = activities.user_id
        AND r.status = 'active'
        AND c.device_id = current_setting('app.device_id', true)
        AND (
          r.custom_permissions->>'view_activities' = 'true'
          OR r.permission_level = 'full_access'
        )
    )
  );

-- Allow coaches to create activities for athletes (if permitted)
CREATE POLICY "Coaches can create athlete activities" ON activities
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM coach_athlete_relationships r
      JOIN coaches c ON c.id = r.coach_id
      JOIN users u ON u.device_id = r.athlete_device_id
      WHERE u.id::text = activities.user_id
        AND r.status = 'active'
        AND c.device_id = current_setting('app.device_id', true)
        AND (
          r.custom_permissions->>'create_activities' = 'true'
          OR r.permission_level = 'full_access'
        )
    )
  );

-- Allow coaches to modify activities (if permitted)
CREATE POLICY "Coaches can update athlete activities" ON activities
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM coach_athlete_relationships r
      JOIN coaches c ON c.id = r.coach_id
      JOIN users u ON u.device_id = r.athlete_device_id
      WHERE u.id::text = activities.user_id
        AND r.status = 'active'
        AND c.device_id = current_setting('app.device_id', true)
        AND (
          r.custom_permissions->>'modify_activities' = 'true'
          OR r.permission_level = 'full_access'
        )
    )
  );
```

---

#### Modification 3: `workout_notes` Table

**Add coach access:**

```sql
-- Add columns to track coach notes
ALTER TABLE workout_notes
  ADD COLUMN created_by_coach_id UUID REFERENCES coaches(id) ON DELETE SET NULL,
  ADD COLUMN is_coach_note BOOLEAN DEFAULT false,
  ADD COLUMN is_visible_to_athlete BOOLEAN DEFAULT true;

-- Add index for coach queries
CREATE INDEX idx_workout_notes_coach
  ON workout_notes(created_by_coach_id)
  WHERE created_by_coach_id IS NOT NULL;

-- Add comments
COMMENT ON COLUMN workout_notes.created_by_coach_id IS 'Coach who created this note (NULL if athlete-created)';
COMMENT ON COLUMN workout_notes.is_coach_note IS 'True if note was created by a coach';
COMMENT ON COLUMN workout_notes.is_visible_to_athlete IS 'Controls visibility to athlete (for coach-only notes)';
```

**Update RLS policies:**

```sql
-- Allow coaches to view athlete notes (if permitted)
CREATE POLICY "Coaches can view athlete notes" ON workout_notes
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM coach_athlete_relationships r
      JOIN coaches c ON c.id = r.coach_id
      WHERE workout_notes.user_id IN (SELECT id FROM users WHERE device_id = r.athlete_device_id)
        AND r.status = 'active'
        AND c.device_id = current_setting('app.device_id', true)
        AND (
          r.custom_permissions->>'view_notes' = 'true'
          OR r.permission_level = 'full_access'
        )
    )
  );

-- Allow coaches to add notes for athletes (if permitted)
CREATE POLICY "Coaches can add athlete notes" ON workout_notes
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM coach_athlete_relationships r
      JOIN coaches c ON c.id = r.coach_id
      WHERE workout_notes.user_id IN (SELECT id FROM users WHERE device_id = r.athlete_device_id)
        AND r.status = 'active'
        AND c.device_id = current_setting('app.device_id', true)
        AND (
          r.custom_permissions->>'add_notes' = 'true'
          OR r.permission_level = 'full_access'
        )
    )
  );

-- Update athlete policy to only show visible notes
CREATE POLICY "Athletes see their own and visible coach notes" ON workout_notes
  FOR SELECT
  USING (
    user_id = (current_setting('app.user_id', true))::uuid
    AND (is_coach_note = false OR is_visible_to_athlete = true)
  );
```

---

#### Modification 4: `activity_completions` Table

**Update RLS to allow coach access:**

```sql
-- Allow coaches to view athlete completions
CREATE POLICY "Coaches can view athlete completions" ON activity_completions
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM coach_athlete_relationships r
      JOIN coaches c ON c.id = r.coach_id
      WHERE activity_completions.user_id = r.athlete_device_id
        AND r.status = 'active'
        AND c.device_id = current_setting('app.device_id', true)
        AND (
          r.custom_permissions->>'view_completions' = 'true'
          OR r.permission_level = 'full_access'
        )
    )
  );
```

---

#### Modification 5: `food_preferences` Table (Optional)

**Update RLS to allow coach access if permitted:**

```sql
-- Allow coaches to view athlete food preferences (if permitted)
CREATE POLICY "Coaches can view athlete food preferences" ON food_preferences
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM coach_athlete_relationships r
      JOIN coaches c ON c.id = r.coach_id
      WHERE food_preferences.device_id = r.athlete_device_id
        AND r.status = 'active'
        AND c.device_id = current_setting('app.device_id', true)
        AND r.custom_permissions->>'view_food_preferences' = 'true'
    )
  );
```

---

### 3.3 Helper Functions

#### Function 1: Check Coach Permission

```sql
CREATE OR REPLACE FUNCTION has_coach_permission(
  p_coach_device_id TEXT,
  p_athlete_device_id TEXT,
  p_permission TEXT
) RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM coach_athlete_relationships r
    JOIN coaches c ON c.id = r.coach_id
    WHERE c.device_id = p_coach_device_id
      AND r.athlete_device_id = p_athlete_device_id
      AND r.status = 'active'
      AND (
        r.permission_level = 'full_access'
        OR (r.permission_level = 'custom' AND r.custom_permissions->>p_permission = 'true')
      )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute
GRANT EXECUTE ON FUNCTION has_coach_permission(TEXT, TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION has_coach_permission(TEXT, TEXT, TEXT) TO authenticated;

-- Example usage:
-- SELECT has_coach_permission('coach_device_123', 'athlete_device_456', 'view_nutrition_plans');
```

**Comments**:
```sql
COMMENT ON FUNCTION has_coach_permission(TEXT, TEXT, TEXT) IS
  'Check if coach has specific permission for athlete. Returns true/false.';
```

---

#### Function 2: Get Coach's Athletes

```sql
CREATE OR REPLACE FUNCTION get_coach_athletes(
  p_coach_device_id TEXT,
  p_status relationship_status_enum DEFAULT 'active'
) RETURNS TABLE (
  athlete_id UUID,
  athlete_device_id TEXT,
  athlete_name TEXT,
  relationship_id UUID,
  permission_level permission_level_enum,
  relationship_status relationship_status_enum,
  relationship_started TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    u.id AS athlete_id,
    u.device_id AS athlete_device_id,
    COALESCE(u.gender::text || ' athlete', 'Athlete') AS athlete_name, -- Placeholder for actual name
    r.id AS relationship_id,
    r.permission_level,
    r.status AS relationship_status,
    r.accepted_at AS relationship_started
  FROM coach_athlete_relationships r
  JOIN coaches c ON c.id = r.coach_id
  JOIN users u ON u.id = r.athlete_user_id
  WHERE c.device_id = p_coach_device_id
    AND r.status = p_status
  ORDER BY r.accepted_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute
GRANT EXECUTE ON FUNCTION get_coach_athletes(TEXT, relationship_status_enum) TO anon;
GRANT EXECUTE ON FUNCTION get_coach_athletes(TEXT, relationship_status_enum) TO authenticated;
```

---

#### Function 3: Get Athlete's Coaches

```sql
CREATE OR REPLACE FUNCTION get_athlete_coaches(
  p_athlete_device_id TEXT,
  p_status relationship_status_enum DEFAULT 'active'
) RETURNS TABLE (
  coach_id UUID,
  coach_name TEXT,
  coach_bio TEXT,
  coach_specializations TEXT[],
  relationship_id UUID,
  permission_level permission_level_enum,
  relationship_status relationship_status_enum,
  relationship_started TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    c.id AS coach_id,
    c.coach_name,
    c.bio AS coach_bio,
    c.specializations,
    r.id AS relationship_id,
    r.permission_level,
    r.status AS relationship_status,
    r.accepted_at AS relationship_started
  FROM coach_athlete_relationships r
  JOIN coaches c ON c.id = r.coach_id
  WHERE r.athlete_device_id = p_athlete_device_id
    AND r.status = p_status
  ORDER BY r.accepted_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute
GRANT EXECUTE ON FUNCTION get_athlete_coaches(TEXT, relationship_status_enum) TO anon;
GRANT EXECUTE ON FUNCTION get_athlete_coaches(TEXT, relationship_status_enum) TO authenticated;
```

---

### 3.4 Triggers

#### Trigger 1: Update `updated_at` timestamp

```sql
-- For coaches table
CREATE TRIGGER update_coaches_updated_at
  BEFORE UPDATE ON coaches
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- For coach_athlete_relationships table
CREATE TRIGGER update_coach_athlete_relationships_updated_at
  BEFORE UPDATE ON coach_athlete_relationships
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- For coach_feedback table
CREATE TRIGGER update_coach_feedback_updated_at
  BEFORE UPDATE ON coach_feedback
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
```

---

#### Trigger 2: Auto-update relationship status

```sql
CREATE OR REPLACE FUNCTION update_relationship_status_dates()
RETURNS TRIGGER AS $$
BEGIN
  -- Set accepted_at when status changes to 'active'
  IF NEW.status = 'active' AND OLD.status != 'active' THEN
    NEW.accepted_at = now();
  END IF;

  -- Set declined_at when status changes to 'declined'
  IF NEW.status = 'declined' AND OLD.status != 'declined' THEN
    NEW.declined_at = now();
  END IF;

  -- Set archived_at when status changes to 'archived'
  IF NEW.status = 'archived' AND OLD.status != 'archived' THEN
    NEW.archived_at = now();
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_relationship_status_dates_trigger
  BEFORE UPDATE ON coach_athlete_relationships
  FOR EACH ROW
  EXECUTE FUNCTION update_relationship_status_dates();
```

---

#### Trigger 3: Enforce max athletes limit

```sql
CREATE OR REPLACE FUNCTION check_coach_athlete_limit()
RETURNS TRIGGER AS $$
DECLARE
  current_athlete_count INTEGER;
  max_athlete_limit INTEGER;
BEGIN
  -- Only check on INSERT or when accepting relationships
  IF (TG_OP = 'INSERT' AND NEW.status = 'active') OR
     (TG_OP = 'UPDATE' AND NEW.status = 'active' AND OLD.status != 'active') THEN

    -- Get coach's max athlete limit
    SELECT max_athletes INTO max_athlete_limit
    FROM coaches
    WHERE id = NEW.coach_id;

    -- Count current active athletes
    SELECT COUNT(*) INTO current_athlete_count
    FROM coach_athlete_relationships
    WHERE coach_id = NEW.coach_id
      AND status = 'active'
      AND id != NEW.id; -- Exclude current record if updating

    -- Check limit
    IF current_athlete_count >= max_athlete_limit THEN
      RAISE EXCEPTION 'Coach has reached maximum athlete limit of %', max_athlete_limit;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER enforce_coach_athlete_limit_trigger
  BEFORE INSERT OR UPDATE ON coach_athlete_relationships
  FOR EACH ROW
  EXECUTE FUNCTION check_coach_athlete_limit();
```

---

## 4. Indexes for Performance

### 4.1 Critical Query Patterns

Based on expected query patterns, these indexes are essential:

```sql
-- Coach dashboard: Get all athletes for a coach
CREATE INDEX idx_coach_ath_rel_coach_status ON coach_athlete_relationships(coach_id, status);

-- Athlete dashboard: Get all coaches for an athlete
CREATE INDEX idx_coach_ath_rel_athlete_status ON coach_athlete_relationships(athlete_device_id, status);

-- Permission checks (most frequent query)
CREATE INDEX idx_coach_ath_rel_permission_lookup
  ON coach_athlete_relationships(coach_id, athlete_device_id, status)
  WHERE status = 'active';

-- Coach viewing athlete activities
CREATE INDEX idx_activities_user_coach_lookup
  ON activities(user_id, created_by_coach_id);

-- Coach viewing athlete nutrition plans
CREATE INDEX idx_nutrition_plans_device_coach_lookup
  ON nutrition_plans(device_id, created_by_coach_id);

-- Coach feedback queries
CREATE INDEX idx_coach_feedback_athlete_created
  ON coach_feedback(athlete_user_id, created_at DESC);

-- Custom permissions JSON queries
CREATE INDEX idx_coach_ath_rel_custom_perms_gin
  ON coach_athlete_relationships USING GIN(custom_permissions);
```

---

## 5. Migration Strategy

### 5.1 Migration Order

1. **Phase 1: Core Tables** (No breaking changes)
   - Create `coaches` table
   - Create `coach_athlete_relationships` table
   - Create `coach_feedback` table
   - Create helper functions

2. **Phase 2: Existing Table Modifications** (Backward compatible)
   - Add coach columns to `nutrition_plans`
   - Add coach columns to `activities`
   - Add coach columns to `workout_notes`
   - All new columns are nullable

3. **Phase 3: RLS Policies** (Additive only)
   - Add new coach-access policies to `nutrition_plans`
   - Add new coach-access policies to `activities`
   - Add new coach-access policies to `workout_notes`
   - Add new coach-access policies to `activity_completions`
   - Add new coach-access policies to `food_preferences`

4. **Phase 4: Triggers & Constraints**
   - Add triggers for status dates
   - Add trigger for athlete limits
   - Add constraints for data integrity

### 5.2 Rollback Plan

Each phase can be rolled back independently:

```sql
-- Rollback Phase 4
DROP TRIGGER IF EXISTS update_relationship_status_dates_trigger ON coach_athlete_relationships;
DROP TRIGGER IF EXISTS enforce_coach_athlete_limit_trigger ON coach_athlete_relationships;
DROP FUNCTION IF EXISTS update_relationship_status_dates();
DROP FUNCTION IF EXISTS check_coach_athlete_limit();

-- Rollback Phase 3
DROP POLICY IF EXISTS "Coaches can view athlete plans" ON nutrition_plans;
DROP POLICY IF EXISTS "Coaches can create athlete plans" ON nutrition_plans;
-- ... (drop all coach policies)

-- Rollback Phase 2
ALTER TABLE nutrition_plans
  DROP COLUMN IF EXISTS created_by_coach_id,
  DROP COLUMN IF EXISTS last_modified_by_coach_id,
  DROP COLUMN IF EXISTS coach_notes,
  DROP COLUMN IF EXISTS is_coach_created;

ALTER TABLE activities
  DROP COLUMN IF EXISTS created_by_coach_id,
  DROP COLUMN IF EXISTS assigned_by_coach_id,
  DROP COLUMN IF EXISTS coach_notes,
  DROP COLUMN IF EXISTS is_coach_assigned;

ALTER TABLE workout_notes
  DROP COLUMN IF EXISTS created_by_coach_id,
  DROP COLUMN IF EXISTS is_coach_note,
  DROP COLUMN IF EXISTS is_visible_to_athlete;

-- Rollback Phase 1
DROP TABLE IF EXISTS coach_feedback CASCADE;
DROP TABLE IF EXISTS coach_athlete_relationships CASCADE;
DROP TABLE IF EXISTS coaches CASCADE;
DROP TYPE IF EXISTS permission_level_enum;
DROP TYPE IF EXISTS relationship_status_enum;
DROP FUNCTION IF EXISTS has_coach_permission(TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS get_coach_athletes(TEXT, relationship_status_enum);
DROP FUNCTION IF EXISTS get_athlete_coaches(TEXT, relationship_status_enum);
```

---

## 6. Security Considerations

### 6.1 RLS Policy Security

**Current Implementation**:
- All coach access is gated by active relationship status
- Permissions are checked at database level via RLS
- Coaches can only see athletes they have active relationships with
- Athletes control visibility via relationship status

**Potential Vulnerabilities**:
1. **Permission Escalation**: Coaches modifying `custom_permissions` JSON
   - **Mitigation**: Use triggers to validate permission changes
   - **Mitigation**: Only allow athletes to modify permissions

2. **Device ID Spoofing**: Malicious actors setting `app.device_id`
   - **Mitigation**: Set `app.device_id` in Edge Functions only (SECURITY DEFINER)
   - **Mitigation**: Validate device_id against JWT claims

3. **Data Leakage via JOIN**: Coaches accessing data through indirect joins
   - **Mitigation**: All coach policies check `coach_athlete_relationships` table
   - **Mitigation**: Policies require `status = 'active'`

### 6.2 Recommended Security Enhancements

```sql
-- 1. Add trigger to prevent coaches from modifying their own permissions
CREATE OR REPLACE FUNCTION prevent_coach_permission_escalation()
RETURNS TRIGGER AS $$
BEGIN
  -- Only athletes can modify custom_permissions
  IF OLD.custom_permissions != NEW.custom_permissions THEN
    IF current_setting('app.device_id', true) != NEW.athlete_device_id THEN
      RAISE EXCEPTION 'Only athletes can modify their coach permissions';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER prevent_coach_permission_escalation_trigger
  BEFORE UPDATE ON coach_athlete_relationships
  FOR EACH ROW
  EXECUTE FUNCTION prevent_coach_permission_escalation();

-- 2. Add function to validate device_id (called from Edge Functions)
CREATE OR REPLACE FUNCTION set_session_device_id(p_device_id TEXT)
RETURNS VOID AS $$
BEGIN
  -- Validate device_id exists
  IF NOT EXISTS (SELECT 1 FROM users WHERE device_id = p_device_id) THEN
    RAISE EXCEPTION 'Invalid device_id';
  END IF;

  -- Set session variable
  PERFORM set_config('app.device_id', p_device_id, false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Add audit logging for coach actions
CREATE TABLE coach_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  coach_id UUID NOT NULL REFERENCES coaches(id),
  athlete_user_id UUID NOT NULL REFERENCES users(id),
  action TEXT NOT NULL, -- 'view', 'create', 'update', 'delete'
  table_name TEXT NOT NULL,
  record_id TEXT,
  timestamp TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_coach_audit_log_coach ON coach_audit_log(coach_id, timestamp DESC);
CREATE INDEX idx_coach_audit_log_athlete ON coach_audit_log(athlete_user_id, timestamp DESC);
```

---

## 7. Performance Considerations

### 7.1 Expected Query Load

**Assumptions**:
- Average coach has 10-20 athletes
- Average athlete has 1-2 coaches
- Coaches check athlete progress 2-3 times per day per athlete
- Athletes view coach feedback 1-2 times per day

**Query Frequency Estimates** (per coach per day):
- `get_coach_athletes()`: 5-10 calls
- `has_coach_permission()`: 100-200 calls (embedded in RLS policies)
- Coach viewing athlete activities: 20-40 queries
- Coach viewing nutrition plans: 10-20 queries
- Coach creating/updating plans: 2-5 queries

### 7.2 Optimization Strategies

1. **Index Coverage**: All critical query paths have supporting indexes
2. **RLS Policy Optimization**: Use `EXISTS` subqueries (faster than JOINs in policies)
3. **JSONB Indexing**: GIN index on `custom_permissions` for permission checks
4. **Partial Indexes**: Only index active relationships (`status = 'active'`)
5. **Caching Strategy**:
   - Cache coach-athlete relationships in app memory (TTL: 5 minutes)
   - Cache custom permissions JSON (TTL: 5 minutes)
   - Invalidate cache on relationship updates

### 7.3 Monitoring Queries

```sql
-- Monitor slow coach-related queries
SELECT
  query,
  calls,
  mean_exec_time,
  max_exec_time
FROM pg_stat_statements
WHERE query LIKE '%coach_athlete_relationships%'
  OR query LIKE '%coaches%'
ORDER BY mean_exec_time DESC
LIMIT 20;

-- Monitor RLS policy overhead
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM nutrition_plans
WHERE device_id = 'test_athlete_device';
```

---

## 8. Data Privacy & Compliance

### 8.1 GDPR Compliance

**Right to Access**:
- Athletes can query all coach relationships: `get_athlete_coaches()`
- Athletes can query all coach feedback: `SELECT * FROM coach_feedback WHERE athlete_user_id = ...`

**Right to Erasure**:
- Cascade deletes from `users` table remove all coach relationships
- Cascade deletes from `coaches` table remove all relationships and feedback
- Soft delete option: Set `status = 'archived'` instead of hard delete

**Right to Portability**:
```sql
-- Export athlete's coach data
CREATE OR REPLACE FUNCTION export_athlete_coach_data(p_athlete_device_id TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN jsonb_build_object(
    'relationships', (
      SELECT jsonb_agg(row_to_json(r))
      FROM coach_athlete_relationships r
      WHERE r.athlete_device_id = p_athlete_device_id
    ),
    'feedback', (
      SELECT jsonb_agg(row_to_json(f))
      FROM coach_feedback f
      JOIN users u ON u.id = f.athlete_user_id
      WHERE u.device_id = p_athlete_device_id
    ),
    'coach_created_plans', (
      SELECT jsonb_agg(row_to_json(n))
      FROM nutrition_plans n
      WHERE n.device_id = p_athlete_device_id
        AND n.is_coach_created = true
    ),
    'coach_created_activities', (
      SELECT jsonb_agg(row_to_json(a))
      FROM activities a
      JOIN users u ON u.id::text = a.user_id
      WHERE u.device_id = p_athlete_device_id
        AND a.is_coach_assigned = true
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## 9. Implementation Checklist

### 9.1 Database Changes

- [ ] Create enum types (`relationship_status_enum`, `permission_level_enum`)
- [ ] Create `coaches` table with indexes and RLS policies
- [ ] Create `coach_athlete_relationships` table with indexes and RLS policies
- [ ] Create `coach_feedback` table with indexes and RLS policies
- [ ] Modify `nutrition_plans` table (add coach columns)
- [ ] Modify `activities` table (add coach columns)
- [ ] Modify `workout_notes` table (add coach columns)
- [ ] Add new RLS policies for coach access
- [ ] Create helper functions (`has_coach_permission`, `get_coach_athletes`, etc.)
- [ ] Create triggers (updated_at, status dates, athlete limits)
- [ ] Create audit logging table (optional)

### 9.2 Edge Functions

- [ ] Create `create-coach-profile` Edge Function
- [ ] Create `send-coach-request` Edge Function (coach → athlete)
- [ ] Create `send-athlete-request` Edge Function (athlete → coach)
- [ ] Create `accept-coach-request` Edge Function
- [ ] Create `decline-coach-request` Edge Function
- [ ] Create `update-coach-permissions` Edge Function
- [ ] Create `archive-coach-relationship` Edge Function
- [ ] Create `get-coach-athletes` Edge Function
- [ ] Create `get-athlete-coaches` Edge Function
- [ ] Modify existing Edge Functions to respect coach permissions

### 9.3 Flutter App Changes

- [ ] Create `Coach` model class
- [ ] Create `CoachAthleteRelationship` model class
- [ ] Create `CoachFeedback` model class
- [ ] Create coach profile UI (coach dashboard)
- [ ] Create athlete list UI (for coaches)
- [ ] Create coach request UI (send/accept/decline)
- [ ] Create permissions management UI (for athletes)
- [ ] Create coach feedback UI (for coaches)
- [ ] Modify activity creation to track `created_by_coach_id`
- [ ] Modify nutrition plan creation to track `created_by_coach_id`
- [ ] Add coach badge/indicator in activities/plans UI
- [ ] Add coach notes display in activity/plan detail screens

### 9.4 Testing

- [ ] Unit tests for RLS policies (coach can/cannot access athlete data)
- [ ] Unit tests for permission checks (`has_coach_permission()`)
- [ ] Unit tests for relationship lifecycle (pending → active → archived)
- [ ] Integration tests for coach creating plans for athletes
- [ ] Integration tests for coach viewing athlete activities
- [ ] Performance tests for coach dashboard queries
- [ ] Security tests for permission escalation attempts
- [ ] GDPR compliance tests (data export, deletion)

---

## 10. Future Enhancements

### 10.1 Planned Features

1. **Team/Group Coaching**
   - Coaches can create teams (e.g., "Marathon Training Group")
   - Bulk assign activities/plans to teams
   - Team leaderboards and progress tracking

2. **Coach Certification Verification**
   - Integration with certification providers (RRCA, USAT, etc.)
   - Badge display for verified coaches
   - Automated verification workflows

3. **Coach Marketplace**
   - Directory of available coaches
   - Search by specialization, location, price
   - Booking and payment integration

4. **Advanced Analytics**
   - Coach dashboard with athlete progress charts
   - Trend analysis across all athletes
   - Performance benchmarking

5. **Communication Features**
   - In-app messaging between coach and athlete
   - Video call integration (Zoom, Google Meet)
   - Automated notifications for plan updates

### 10.2 Additional Tables for Future Features

```sql
-- Teams/Groups
CREATE TABLE coach_teams (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  coach_id UUID NOT NULL REFERENCES coaches(id) ON DELETE CASCADE,
  team_name TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE team_members (
  team_id UUID REFERENCES coach_teams(id) ON DELETE CASCADE,
  athlete_user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (team_id, athlete_user_id)
);

-- Messaging
CREATE TABLE coach_athlete_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  relationship_id UUID NOT NULL REFERENCES coach_athlete_relationships(id) ON DELETE CASCADE,
  sender_type TEXT NOT NULL CHECK (sender_type IN ('coach', 'athlete')),
  message_text TEXT NOT NULL,
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Certifications
CREATE TABLE coach_certifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  coach_id UUID NOT NULL REFERENCES coaches(id) ON DELETE CASCADE,
  certification_name TEXT NOT NULL,
  certification_body TEXT NOT NULL,
  certification_number TEXT,
  issue_date DATE,
  expiry_date DATE,
  is_verified BOOLEAN DEFAULT false,
  verified_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);
```

---

## 11. SQL Migration Files

### 11.1 Complete Migration Script

```sql
-- ============================================================================
-- MIGRATION: Add Coach Mode Support
-- Version: v2.0
-- Created: 2025-12-11
-- Description: Implements coach-athlete relationships, permissions, and feedback
-- ============================================================================

BEGIN;

-- ============================================================================
-- PHASE 1: CREATE ENUMS
-- ============================================================================

CREATE TYPE relationship_status_enum AS ENUM ('pending', 'active', 'declined', 'archived');
CREATE TYPE permission_level_enum AS ENUM ('view_only', 'full_access', 'custom');

-- ============================================================================
-- PHASE 2: CREATE TABLES
-- ============================================================================

-- Table 1: coaches
CREATE TABLE coaches (
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
CREATE TABLE coach_athlete_relationships (
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
CREATE TABLE coach_feedback (
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
-- PHASE 3: MODIFY EXISTING TABLES
-- ============================================================================

-- Modify nutrition_plans
ALTER TABLE nutrition_plans
  ADD COLUMN created_by_coach_id UUID REFERENCES coaches(id) ON DELETE SET NULL,
  ADD COLUMN last_modified_by_coach_id UUID REFERENCES coaches(id) ON DELETE SET NULL,
  ADD COLUMN coach_notes TEXT,
  ADD COLUMN is_coach_created BOOLEAN DEFAULT false;

-- Modify activities
ALTER TABLE activities
  ADD COLUMN created_by_coach_id UUID REFERENCES coaches(id) ON DELETE SET NULL,
  ADD COLUMN assigned_by_coach_id UUID REFERENCES coaches(id) ON DELETE SET NULL,
  ADD COLUMN coach_notes TEXT,
  ADD COLUMN is_coach_assigned BOOLEAN DEFAULT false;

-- Modify workout_notes
ALTER TABLE workout_notes
  ADD COLUMN created_by_coach_id UUID REFERENCES coaches(id) ON DELETE SET NULL,
  ADD COLUMN is_coach_note BOOLEAN DEFAULT false,
  ADD COLUMN is_visible_to_athlete BOOLEAN DEFAULT true;

-- ============================================================================
-- PHASE 4: CREATE INDEXES
-- ============================================================================

-- Coaches table indexes
CREATE INDEX idx_coaches_user_id ON coaches(user_id);
CREATE INDEX idx_coaches_device_id ON coaches(device_id);
CREATE INDEX idx_coaches_is_active ON coaches(is_active) WHERE is_active = true;
CREATE INDEX idx_coaches_specializations ON coaches USING GIN(specializations);

-- Coach-athlete relationships indexes
CREATE INDEX idx_coach_athlete_rel_coach ON coach_athlete_relationships(coach_id);
CREATE INDEX idx_coach_athlete_rel_athlete_user ON coach_athlete_relationships(athlete_user_id);
CREATE INDEX idx_coach_athlete_rel_athlete_device ON coach_athlete_relationships(athlete_device_id);
CREATE INDEX idx_coach_athlete_rel_status ON coach_athlete_relationships(status);
CREATE INDEX idx_coach_athlete_rel_active ON coach_athlete_relationships(coach_id, status)
  WHERE status = 'active';
CREATE INDEX idx_coach_athlete_rel_custom_perms ON coach_athlete_relationships USING GIN(custom_permissions);

-- Coach feedback indexes
CREATE INDEX idx_coach_feedback_relationship ON coach_feedback(relationship_id);
CREATE INDEX idx_coach_feedback_coach ON coach_feedback(coach_id);
CREATE INDEX idx_coach_feedback_athlete ON coach_feedback(athlete_user_id);
CREATE INDEX idx_coach_feedback_activity ON coach_feedback(activity_id) WHERE activity_id IS NOT NULL;
CREATE INDEX idx_coach_feedback_nutrition_plan ON coach_feedback(nutrition_plan_id) WHERE nutrition_plan_id IS NOT NULL;
CREATE INDEX idx_coach_feedback_created ON coach_feedback(created_at DESC);

-- Modified table indexes
CREATE INDEX idx_nutrition_plans_created_by_coach
  ON nutrition_plans(created_by_coach_id)
  WHERE created_by_coach_id IS NOT NULL;

CREATE INDEX idx_activities_created_by_coach
  ON activities(created_by_coach_id)
  WHERE created_by_coach_id IS NOT NULL;

CREATE INDEX idx_activities_assigned_by_coach
  ON activities(assigned_by_coach_id)
  WHERE assigned_by_coach_id IS NOT NULL;

CREATE INDEX idx_workout_notes_coach
  ON workout_notes(created_by_coach_id)
  WHERE created_by_coach_id IS NOT NULL;

-- ============================================================================
-- PHASE 5: CREATE RLS POLICIES
-- ============================================================================

-- Enable RLS on new tables
ALTER TABLE coaches ENABLE ROW LEVEL SECURITY;
ALTER TABLE coach_athlete_relationships ENABLE ROW LEVEL SECURITY;
ALTER TABLE coach_feedback ENABLE ROW LEVEL SECURITY;

-- Coaches table policies
CREATE POLICY "Coaches can read own profile" ON coaches
  FOR SELECT
  USING (device_id = current_setting('app.device_id', true));

CREATE POLICY "Coaches can update own profile" ON coaches
  FOR UPDATE
  USING (device_id = current_setting('app.device_id', true));

CREATE POLICY "Anyone can read active coaches" ON coaches
  FOR SELECT
  USING (is_active = true);

-- Coach-athlete relationships policies
CREATE POLICY "Coaches can view their relationships" ON coach_athlete_relationships
  FOR SELECT
  USING (
    coach_id IN (SELECT id FROM coaches WHERE device_id = current_setting('app.device_id', true))
  );

CREATE POLICY "Athletes can view their relationships" ON coach_athlete_relationships
  FOR SELECT
  USING (
    athlete_device_id = current_setting('app.device_id', true)
  );

CREATE POLICY "Coaches can insert relationship requests" ON coach_athlete_relationships
  FOR INSERT
  WITH CHECK (
    coach_id IN (SELECT id FROM coaches WHERE device_id = current_setting('app.device_id', true))
    AND requested_by = 'coach'
  );

CREATE POLICY "Athletes can insert relationship requests" ON coach_athlete_relationships
  FOR INSERT
  WITH CHECK (
    athlete_device_id = current_setting('app.device_id', true)
    AND requested_by = 'athlete'
  );

CREATE POLICY "Coaches can update their relationships" ON coach_athlete_relationships
  FOR UPDATE
  USING (
    coach_id IN (SELECT id FROM coaches WHERE device_id = current_setting('app.device_id', true))
  );

CREATE POLICY "Athletes can update their relationships" ON coach_athlete_relationships
  FOR UPDATE
  USING (
    athlete_device_id = current_setting('app.device_id', true)
  );

CREATE POLICY "Both parties can delete relationships" ON coach_athlete_relationships
  FOR DELETE
  USING (
    coach_id IN (SELECT id FROM coaches WHERE device_id = current_setting('app.device_id', true))
    OR athlete_device_id = current_setting('app.device_id', true)
  );

-- Coach feedback policies
CREATE POLICY "Coaches can manage their feedback" ON coach_feedback
  FOR ALL
  USING (
    coach_id IN (SELECT id FROM coaches WHERE device_id = current_setting('app.device_id', true))
  );

CREATE POLICY "Athletes can view feedback for them" ON coach_feedback
  FOR SELECT
  USING (
    athlete_user_id IN (SELECT id FROM users WHERE device_id = current_setting('app.device_id', true))
    AND is_visible_to_athlete = true
  );

-- Nutrition plans coach access policies
CREATE POLICY "Coaches can view athlete plans" ON nutrition_plans
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM coach_athlete_relationships r
      JOIN coaches c ON c.id = r.coach_id
      WHERE r.athlete_device_id = nutrition_plans.device_id
        AND r.status = 'active'
        AND c.device_id = current_setting('app.device_id', true)
        AND (
          r.custom_permissions->>'view_nutrition_plans' = 'true'
          OR r.permission_level = 'full_access'
        )
    )
  );

CREATE POLICY "Coaches can create athlete plans" ON nutrition_plans
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM coach_athlete_relationships r
      JOIN coaches c ON c.id = r.coach_id
      WHERE r.athlete_device_id = nutrition_plans.device_id
        AND r.status = 'active'
        AND c.device_id = current_setting('app.device_id', true)
        AND (
          r.custom_permissions->>'create_nutrition_plans' = 'true'
          OR r.permission_level = 'full_access'
        )
    )
  );

CREATE POLICY "Coaches can update athlete plans" ON nutrition_plans
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM coach_athlete_relationships r
      JOIN coaches c ON c.id = r.coach_id
      WHERE r.athlete_device_id = nutrition_plans.device_id
        AND r.status = 'active'
        AND c.device_id = current_setting('app.device_id', true)
        AND (
          r.custom_permissions->>'modify_nutrition_plans' = 'true'
          OR r.permission_level = 'full_access'
        )
    )
  );

-- Activities coach access policies
CREATE POLICY "Coaches can view athlete activities" ON activities
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM coach_athlete_relationships r
      JOIN coaches c ON c.id = r.coach_id
      JOIN users u ON u.device_id = r.athlete_device_id
      WHERE u.id::text = activities.user_id
        AND r.status = 'active'
        AND c.device_id = current_setting('app.device_id', true)
        AND (
          r.custom_permissions->>'view_activities' = 'true'
          OR r.permission_level = 'full_access'
        )
    )
  );

CREATE POLICY "Coaches can create athlete activities" ON activities
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM coach_athlete_relationships r
      JOIN coaches c ON c.id = r.coach_id
      JOIN users u ON u.device_id = r.athlete_device_id
      WHERE u.id::text = activities.user_id
        AND r.status = 'active'
        AND c.device_id = current_setting('app.device_id', true)
        AND (
          r.custom_permissions->>'create_activities' = 'true'
          OR r.permission_level = 'full_access'
        )
    )
  );

CREATE POLICY "Coaches can update athlete activities" ON activities
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM coach_athlete_relationships r
      JOIN coaches c ON c.id = r.coach_id
      JOIN users u ON u.device_id = r.athlete_device_id
      WHERE u.id::text = activities.user_id
        AND r.status = 'active'
        AND c.device_id = current_setting('app.device_id', true)
        AND (
          r.custom_permissions->>'modify_activities' = 'true'
          OR r.permission_level = 'full_access'
        )
    )
  );

-- Workout notes coach access policies
CREATE POLICY "Coaches can view athlete notes" ON workout_notes
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM coach_athlete_relationships r
      JOIN coaches c ON c.id = r.coach_id
      WHERE workout_notes.user_id IN (SELECT id FROM users WHERE device_id = r.athlete_device_id)
        AND r.status = 'active'
        AND c.device_id = current_setting('app.device_id', true)
        AND (
          r.custom_permissions->>'view_notes' = 'true'
          OR r.permission_level = 'full_access'
        )
    )
  );

CREATE POLICY "Coaches can add athlete notes" ON workout_notes
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM coach_athlete_relationships r
      JOIN coaches c ON c.id = r.coach_id
      WHERE workout_notes.user_id IN (SELECT id FROM users WHERE device_id = r.athlete_device_id)
        AND r.status = 'active'
        AND c.device_id = current_setting('app.device_id', true)
        AND (
          r.custom_permissions->>'add_notes' = 'true'
          OR r.permission_level = 'full_access'
        )
    )
  );

-- Activity completions coach access policy
CREATE POLICY "Coaches can view athlete completions" ON activity_completions
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM coach_athlete_relationships r
      JOIN coaches c ON c.id = r.coach_id
      WHERE activity_completions.user_id = r.athlete_device_id
        AND r.status = 'active'
        AND c.device_id = current_setting('app.device_id', true)
        AND (
          r.custom_permissions->>'view_completions' = 'true'
          OR r.permission_level = 'full_access'
        )
    )
  );

-- Food preferences coach access policy (optional)
CREATE POLICY "Coaches can view athlete food preferences" ON food_preferences
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM coach_athlete_relationships r
      JOIN coaches c ON c.id = r.coach_id
      WHERE food_preferences.device_id = r.athlete_device_id
        AND r.status = 'active'
        AND c.device_id = current_setting('app.device_id', true)
        AND r.custom_permissions->>'view_food_preferences' = 'true'
    )
  );

-- ============================================================================
-- PHASE 6: CREATE HELPER FUNCTIONS
-- ============================================================================

-- Function 1: Check coach permission
CREATE OR REPLACE FUNCTION has_coach_permission(
  p_coach_device_id TEXT,
  p_athlete_device_id TEXT,
  p_permission TEXT
) RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM coach_athlete_relationships r
    JOIN coaches c ON c.id = r.coach_id
    WHERE c.device_id = p_coach_device_id
      AND r.athlete_device_id = p_athlete_device_id
      AND r.status = 'active'
      AND (
        r.permission_level = 'full_access'
        OR (r.permission_level = 'custom' AND r.custom_permissions->>p_permission = 'true')
      )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function 2: Get coach's athletes
CREATE OR REPLACE FUNCTION get_coach_athletes(
  p_coach_device_id TEXT,
  p_status relationship_status_enum DEFAULT 'active'
) RETURNS TABLE (
  athlete_id UUID,
  athlete_device_id TEXT,
  athlete_name TEXT,
  relationship_id UUID,
  permission_level permission_level_enum,
  relationship_status relationship_status_enum,
  relationship_started TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    u.id AS athlete_id,
    u.device_id AS athlete_device_id,
    COALESCE(u.gender::text || ' athlete', 'Athlete') AS athlete_name,
    r.id AS relationship_id,
    r.permission_level,
    r.status AS relationship_status,
    r.accepted_at AS relationship_started
  FROM coach_athlete_relationships r
  JOIN coaches c ON c.id = r.coach_id
  JOIN users u ON u.id = r.athlete_user_id
  WHERE c.device_id = p_coach_device_id
    AND r.status = p_status
  ORDER BY r.accepted_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function 3: Get athlete's coaches
CREATE OR REPLACE FUNCTION get_athlete_coaches(
  p_athlete_device_id TEXT,
  p_status relationship_status_enum DEFAULT 'active'
) RETURNS TABLE (
  coach_id UUID,
  coach_name TEXT,
  coach_bio TEXT,
  coach_specializations TEXT[],
  relationship_id UUID,
  permission_level permission_level_enum,
  relationship_status relationship_status_enum,
  relationship_started TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    c.id AS coach_id,
    c.coach_name,
    c.bio AS coach_bio,
    c.specializations,
    r.id AS relationship_id,
    r.permission_level,
    r.status AS relationship_status,
    r.accepted_at AS relationship_started
  FROM coach_athlete_relationships r
  JOIN coaches c ON c.id = r.coach_id
  WHERE r.athlete_device_id = p_athlete_device_id
    AND r.status = p_status
  ORDER BY r.accepted_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- PHASE 7: CREATE TRIGGERS
-- ============================================================================

-- Trigger 1: Update updated_at timestamps
CREATE TRIGGER update_coaches_updated_at
  BEFORE UPDATE ON coaches
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_coach_athlete_relationships_updated_at
  BEFORE UPDATE ON coach_athlete_relationships
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_coach_feedback_updated_at
  BEFORE UPDATE ON coach_feedback
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Trigger 2: Auto-update relationship status dates
CREATE OR REPLACE FUNCTION update_relationship_status_dates()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'active' AND OLD.status != 'active' THEN
    NEW.accepted_at = now();
  END IF;

  IF NEW.status = 'declined' AND OLD.status != 'declined' THEN
    NEW.declined_at = now();
  END IF;

  IF NEW.status = 'archived' AND OLD.status != 'archived' THEN
    NEW.archived_at = now();
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_relationship_status_dates_trigger
  BEFORE UPDATE ON coach_athlete_relationships
  FOR EACH ROW
  EXECUTE FUNCTION update_relationship_status_dates();

-- Trigger 3: Enforce max athletes limit
CREATE OR REPLACE FUNCTION check_coach_athlete_limit()
RETURNS TRIGGER AS $$
DECLARE
  current_athlete_count INTEGER;
  max_athlete_limit INTEGER;
BEGIN
  IF (TG_OP = 'INSERT' AND NEW.status = 'active') OR
     (TG_OP = 'UPDATE' AND NEW.status = 'active' AND OLD.status != 'active') THEN

    SELECT max_athletes INTO max_athlete_limit
    FROM coaches
    WHERE id = NEW.coach_id;

    SELECT COUNT(*) INTO current_athlete_count
    FROM coach_athlete_relationships
    WHERE coach_id = NEW.coach_id
      AND status = 'active'
      AND id != NEW.id;

    IF current_athlete_count >= max_athlete_limit THEN
      RAISE EXCEPTION 'Coach has reached maximum athlete limit of %', max_athlete_limit;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER enforce_coach_athlete_limit_trigger
  BEFORE INSERT OR UPDATE ON coach_athlete_relationships
  FOR EACH ROW
  EXECUTE FUNCTION check_coach_athlete_limit();

-- ============================================================================
-- PHASE 8: GRANT PERMISSIONS
-- ============================================================================

-- Grant table permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON coaches TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON coaches TO authenticated;
GRANT ALL ON coaches TO service_role;

GRANT SELECT, INSERT, UPDATE, DELETE ON coach_athlete_relationships TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON coach_athlete_relationships TO authenticated;
GRANT ALL ON coach_athlete_relationships TO service_role;

GRANT SELECT, INSERT, UPDATE, DELETE ON coach_feedback TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON coach_feedback TO authenticated;
GRANT ALL ON coach_feedback TO service_role;

-- Grant function permissions
GRANT EXECUTE ON FUNCTION has_coach_permission(TEXT, TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION has_coach_permission(TEXT, TEXT, TEXT) TO authenticated;

GRANT EXECUTE ON FUNCTION get_coach_athletes(TEXT, relationship_status_enum) TO anon;
GRANT EXECUTE ON FUNCTION get_coach_athletes(TEXT, relationship_status_enum) TO authenticated;

GRANT EXECUTE ON FUNCTION get_athlete_coaches(TEXT, relationship_status_enum) TO anon;
GRANT EXECUTE ON FUNCTION get_athlete_coaches(TEXT, relationship_status_enum) TO authenticated;

-- ============================================================================
-- PHASE 9: ADD COMMENTS
-- ============================================================================

-- Table comments
COMMENT ON TABLE coaches IS 'Coach profiles for users who provide coaching services';
COMMENT ON TABLE coach_athlete_relationships IS 'Tracks coach-athlete relationships with status and permissions';
COMMENT ON TABLE coach_feedback IS 'Coach feedback/notes for athletes on activities, plans, and progress';

-- Column comments (abbreviated - see full list in sections above)
COMMENT ON COLUMN coaches.user_id IS 'References users.id - one-to-one relationship';
COMMENT ON COLUMN coaches.max_athletes IS 'Maximum number of athletes this coach can manage';
COMMENT ON COLUMN coach_athlete_relationships.status IS 'Relationship lifecycle: pending → active/declined/archived';
COMMENT ON COLUMN coach_athlete_relationships.custom_permissions IS 'Granular JSON permissions when permission_level = custom';
COMMENT ON COLUMN coach_feedback.is_visible_to_athlete IS 'Controls whether athlete can see this feedback';

-- ============================================================================
-- COMPLETE MIGRATION
-- ============================================================================

COMMIT;

-- Verify migration
SELECT 'Migration completed successfully. Coach mode tables created and configured.' AS status;
```

---

## 12. Summary & Next Steps

### 12.1 Schema Changes Summary

**New Tables**: 3
- `coaches` - Coach profiles and settings
- `coach_athlete_relationships` - Relationship management with permissions
- `coach_feedback` - Coach notes and feedback

**Modified Tables**: 4
- `nutrition_plans` - Added coach tracking columns
- `activities` - Added coach tracking columns
- `workout_notes` - Added coach tracking columns
- `activity_completions` - Added coach RLS policies (no schema change)
- `food_preferences` - Added coach RLS policies (no schema change)

**New Indexes**: 15
**New RLS Policies**: 22
**New Functions**: 3
**New Triggers**: 5

### 12.2 Recommended Next Steps

1. **Review & Approval** (Week 1)
   - Technical review of schema design
   - Security audit of RLS policies
   - Performance review of index strategy
   - Stakeholder approval

2. **Development Environment Testing** (Week 2)
   - Apply migration to dev database
   - Test all CRUD operations
   - Test RLS policies with different permission levels
   - Performance benchmarking

3. **Edge Function Development** (Week 3-4)
   - Implement coach profile creation
   - Implement relationship request workflows
   - Implement permission management
   - Implement coach dashboards

4. **Flutter App Development** (Week 5-8)
   - UI for coach profiles
   - UI for relationship management
   - UI for coach dashboards
   - UI for feedback/notes

5. **Testing & QA** (Week 9-10)
   - Unit tests for all components
   - Integration tests for workflows
   - Security penetration testing
   - Performance load testing

6. **Production Deployment** (Week 11)
   - Apply migration to production
   - Monitor performance metrics
   - Gradual rollout to beta users
   - Full release

---

**End of Document**
