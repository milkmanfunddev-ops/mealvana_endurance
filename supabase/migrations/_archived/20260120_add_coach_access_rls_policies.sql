-- ============================================================================
-- COACH ACCESS RLS POLICIES MIGRATION
-- ============================================================================
-- Created: 2026-01-20
-- Purpose: Update RLS policies to allow coaches with active relationships
--          to SELECT, UPDATE, and INSERT athlete data (activities, events,
--          carb loading plans)
--
-- SECURITY NOTES:
-- - Coaches can only access athletes they have an 'active' relationship with
-- - DELETE operations remain restricted to the owner (athlete) only
-- - INSERT operations allow coaches to create activities/events FOR athletes
--
-- TYPE CASTING NOTE:
-- - current_setting() returns TEXT, but user_id columns are UUID
-- - All comparisons use ::uuid cast for type safety
-- ============================================================================

-- ============================================================================
-- PHASE 1: ACTIVITIES TABLE - Coach Access
-- ============================================================================

-- Drop existing policies
DROP POLICY IF EXISTS "activities_select_policy" ON activities;
DROP POLICY IF EXISTS "activities_insert_policy" ON activities;
DROP POLICY IF EXISTS "activities_update_policy" ON activities;
DROP POLICY IF EXISTS "activities_delete_policy" ON activities;

-- SELECT: Owner OR active coach can view
CREATE POLICY "activities_select_policy" ON activities FOR SELECT USING (
  -- Owner can view their own activities
  user_id = current_setting('app.user_id', true)::uuid
  -- OR coach with active relationship can view athlete's activities
  OR EXISTS (
    SELECT 1 FROM coach_athlete_relationships
    WHERE coach_user_id = current_setting('app.user_id', true)::uuid
      AND athlete_user_id = activities.user_id
      AND status = 'active'
  )
);

-- INSERT: Owner OR active coach can create
-- Note: When coach creates activity for athlete, user_id is set to athlete's ID
CREATE POLICY "activities_insert_policy" ON activities FOR INSERT WITH CHECK (
  -- Owner can create their own activities
  user_id = current_setting('app.user_id', true)::uuid
  -- OR coach with active relationship can create activities for athlete
  OR EXISTS (
    SELECT 1 FROM coach_athlete_relationships
    WHERE coach_user_id = current_setting('app.user_id', true)::uuid
      AND athlete_user_id = activities.user_id
      AND status = 'active'
  )
);

-- UPDATE: Owner OR active coach can modify
CREATE POLICY "activities_update_policy" ON activities FOR UPDATE USING (
  -- Owner can update their own activities
  user_id = current_setting('app.user_id', true)::uuid
  -- OR coach with active relationship can update athlete's activities
  OR EXISTS (
    SELECT 1 FROM coach_athlete_relationships
    WHERE coach_user_id = current_setting('app.user_id', true)::uuid
      AND athlete_user_id = activities.user_id
      AND status = 'active'
  )
);

-- DELETE: Owner only (coaches cannot delete athlete activities)
CREATE POLICY "activities_delete_policy" ON activities FOR DELETE USING (
  user_id = current_setting('app.user_id', true)::uuid
);

-- ============================================================================
-- PHASE 2: EVENTS TABLE - Coach Access (via activities relationship)
-- ============================================================================

-- Drop existing policies
DROP POLICY IF EXISTS "events_select_policy" ON events;
DROP POLICY IF EXISTS "events_insert_policy" ON events;
DROP POLICY IF EXISTS "events_update_policy" ON events;
DROP POLICY IF EXISTS "events_delete_policy" ON events;
-- Also drop any legacy policies with different names
DROP POLICY IF EXISTS "Users can view their own events" ON events;
DROP POLICY IF EXISTS "Users can insert their own events" ON events;
DROP POLICY IF EXISTS "Users can update their own events" ON events;
DROP POLICY IF EXISTS "Users can delete their own events" ON events;

-- SELECT: Owner OR active coach (via activities join)
CREATE POLICY "events_select_policy" ON events FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM activities
    WHERE activities.id = events.activity_id
      AND (
        -- Owner
        activities.user_id = current_setting('app.user_id', true)::uuid
        -- OR active coach
        OR EXISTS (
          SELECT 1 FROM coach_athlete_relationships
          WHERE coach_user_id = current_setting('app.user_id', true)::uuid
            AND athlete_user_id = activities.user_id
            AND status = 'active'
        )
      )
  )
);

-- INSERT: Owner OR active coach (via activities join)
CREATE POLICY "events_insert_policy" ON events FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM activities
    WHERE activities.id = events.activity_id
      AND (
        -- Owner
        activities.user_id = current_setting('app.user_id', true)::uuid
        -- OR active coach
        OR EXISTS (
          SELECT 1 FROM coach_athlete_relationships
          WHERE coach_user_id = current_setting('app.user_id', true)::uuid
            AND athlete_user_id = activities.user_id
            AND status = 'active'
        )
      )
  )
);

-- UPDATE: Owner OR active coach (via activities join)
CREATE POLICY "events_update_policy" ON events FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM activities
    WHERE activities.id = events.activity_id
      AND (
        -- Owner
        activities.user_id = current_setting('app.user_id', true)::uuid
        -- OR active coach
        OR EXISTS (
          SELECT 1 FROM coach_athlete_relationships
          WHERE coach_user_id = current_setting('app.user_id', true)::uuid
            AND athlete_user_id = activities.user_id
            AND status = 'active'
        )
      )
  )
);

-- DELETE: Owner only (via activities join)
CREATE POLICY "events_delete_policy" ON events FOR DELETE USING (
  EXISTS (
    SELECT 1 FROM activities
    WHERE activities.id = events.activity_id
      AND activities.user_id = current_setting('app.user_id', true)::uuid
  )
);

-- ============================================================================
-- PHASE 3: CARB_LOADING_PLANS TABLE - Coach Access
-- ============================================================================

-- Drop existing policies
DROP POLICY IF EXISTS "carb_plans_select_policy" ON carb_loading_plans;
DROP POLICY IF EXISTS "carb_plans_insert_policy" ON carb_loading_plans;
DROP POLICY IF EXISTS "carb_plans_update_policy" ON carb_loading_plans;
DROP POLICY IF EXISTS "carb_plans_delete_policy" ON carb_loading_plans;

-- SELECT: Owner OR active coach
CREATE POLICY "carb_plans_select_policy" ON carb_loading_plans FOR SELECT USING (
  -- Owner
  user_id = current_setting('app.user_id', true)::uuid
  -- OR active coach
  OR EXISTS (
    SELECT 1 FROM coach_athlete_relationships
    WHERE coach_user_id = current_setting('app.user_id', true)::uuid
      AND athlete_user_id = carb_loading_plans.user_id
      AND status = 'active'
  )
);

-- INSERT: Owner OR active coach
CREATE POLICY "carb_plans_insert_policy" ON carb_loading_plans FOR INSERT WITH CHECK (
  -- Owner
  user_id = current_setting('app.user_id', true)::uuid
  -- OR active coach
  OR EXISTS (
    SELECT 1 FROM coach_athlete_relationships
    WHERE coach_user_id = current_setting('app.user_id', true)::uuid
      AND athlete_user_id = carb_loading_plans.user_id
      AND status = 'active'
  )
);

-- UPDATE: Owner OR active coach
CREATE POLICY "carb_plans_update_policy" ON carb_loading_plans FOR UPDATE USING (
  -- Owner
  user_id = current_setting('app.user_id', true)::uuid
  -- OR active coach
  OR EXISTS (
    SELECT 1 FROM coach_athlete_relationships
    WHERE coach_user_id = current_setting('app.user_id', true)::uuid
      AND athlete_user_id = carb_loading_plans.user_id
      AND status = 'active'
  )
);

-- DELETE: Owner only
CREATE POLICY "carb_plans_delete_policy" ON carb_loading_plans FOR DELETE USING (
  user_id = current_setting('app.user_id', true)::uuid
);

-- ============================================================================
-- PHASE 4: CARB_LOADING_DAYS TABLE - Coach Access (via plans)
-- ============================================================================

-- Drop existing policies
DROP POLICY IF EXISTS "carb_days_select_policy" ON carb_loading_days;
DROP POLICY IF EXISTS "carb_days_insert_policy" ON carb_loading_days;
DROP POLICY IF EXISTS "carb_days_update_policy" ON carb_loading_days;
DROP POLICY IF EXISTS "carb_days_delete_policy" ON carb_loading_days;

-- SELECT: Owner OR active coach (via plans join)
CREATE POLICY "carb_days_select_policy" ON carb_loading_days FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM carb_loading_plans
    WHERE carb_loading_plans.id = carb_loading_days.carb_loading_plan_id
      AND (
        -- Owner
        carb_loading_plans.user_id = current_setting('app.user_id', true)::uuid
        -- OR active coach
        OR EXISTS (
          SELECT 1 FROM coach_athlete_relationships
          WHERE coach_user_id = current_setting('app.user_id', true)::uuid
            AND athlete_user_id = carb_loading_plans.user_id
            AND status = 'active'
        )
      )
  )
);

-- INSERT: Owner OR active coach (via plans join)
CREATE POLICY "carb_days_insert_policy" ON carb_loading_days FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM carb_loading_plans
    WHERE carb_loading_plans.id = carb_loading_days.carb_loading_plan_id
      AND (
        -- Owner
        carb_loading_plans.user_id = current_setting('app.user_id', true)::uuid
        -- OR active coach
        OR EXISTS (
          SELECT 1 FROM coach_athlete_relationships
          WHERE coach_user_id = current_setting('app.user_id', true)::uuid
            AND athlete_user_id = carb_loading_plans.user_id
            AND status = 'active'
        )
      )
  )
);

-- UPDATE: Owner OR active coach (via plans join)
CREATE POLICY "carb_days_update_policy" ON carb_loading_days FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM carb_loading_plans
    WHERE carb_loading_plans.id = carb_loading_days.carb_loading_plan_id
      AND (
        -- Owner
        carb_loading_plans.user_id = current_setting('app.user_id', true)::uuid
        -- OR active coach
        OR EXISTS (
          SELECT 1 FROM coach_athlete_relationships
          WHERE coach_user_id = current_setting('app.user_id', true)::uuid
            AND athlete_user_id = carb_loading_plans.user_id
            AND status = 'active'
        )
      )
  )
);

-- DELETE: Owner only (via plans join)
CREATE POLICY "carb_days_delete_policy" ON carb_loading_days FOR DELETE USING (
  EXISTS (
    SELECT 1 FROM carb_loading_plans
    WHERE carb_loading_plans.id = carb_loading_days.carb_loading_plan_id
      AND carb_loading_plans.user_id = current_setting('app.user_id', true)::uuid
  )
);

-- ============================================================================
-- PHASE 5: CARB_LOADING_DAY_MEALS TABLE - Coach Access (via days→plans chain)
-- ============================================================================

-- Drop existing policies
DROP POLICY IF EXISTS "carb_loading_day_meals_device_read" ON carb_loading_day_meals;
DROP POLICY IF EXISTS "carb_loading_day_meals_device_insert" ON carb_loading_day_meals;
DROP POLICY IF EXISTS "carb_loading_day_meals_device_update" ON carb_loading_day_meals;
DROP POLICY IF EXISTS "carb_loading_day_meals_device_delete" ON carb_loading_day_meals;

-- SELECT: Owner OR active coach (via days→plans join)
CREATE POLICY "carb_meals_select_policy" ON carb_loading_day_meals FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM carb_loading_days d
    JOIN carb_loading_plans p ON p.id = d.carb_loading_plan_id
    WHERE d.id = carb_loading_day_meals.carb_loading_day_id
      AND (
        -- Owner
        p.user_id = current_setting('app.user_id', true)::uuid
        -- OR active coach
        OR EXISTS (
          SELECT 1 FROM coach_athlete_relationships
          WHERE coach_user_id = current_setting('app.user_id', true)::uuid
            AND athlete_user_id = p.user_id
            AND status = 'active'
        )
      )
  )
);

-- INSERT: Owner OR active coach (via days→plans join)
CREATE POLICY "carb_meals_insert_policy" ON carb_loading_day_meals FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM carb_loading_days d
    JOIN carb_loading_plans p ON p.id = d.carb_loading_plan_id
    WHERE d.id = carb_loading_day_meals.carb_loading_day_id
      AND (
        -- Owner
        p.user_id = current_setting('app.user_id', true)::uuid
        -- OR active coach
        OR EXISTS (
          SELECT 1 FROM coach_athlete_relationships
          WHERE coach_user_id = current_setting('app.user_id', true)::uuid
            AND athlete_user_id = p.user_id
            AND status = 'active'
        )
      )
  )
);

-- UPDATE: Owner OR active coach (via days→plans join)
CREATE POLICY "carb_meals_update_policy" ON carb_loading_day_meals FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM carb_loading_days d
    JOIN carb_loading_plans p ON p.id = d.carb_loading_plan_id
    WHERE d.id = carb_loading_day_meals.carb_loading_day_id
      AND (
        -- Owner
        p.user_id = current_setting('app.user_id', true)::uuid
        -- OR active coach
        OR EXISTS (
          SELECT 1 FROM coach_athlete_relationships
          WHERE coach_user_id = current_setting('app.user_id', true)::uuid
            AND athlete_user_id = p.user_id
            AND status = 'active'
        )
      )
  )
);

-- DELETE: Owner only (via days→plans join)
CREATE POLICY "carb_meals_delete_policy" ON carb_loading_day_meals FOR DELETE USING (
  EXISTS (
    SELECT 1 FROM carb_loading_days d
    JOIN carb_loading_plans p ON p.id = d.carb_loading_plan_id
    WHERE d.id = carb_loading_day_meals.carb_loading_day_id
      AND p.user_id = current_setting('app.user_id', true)::uuid
  )
);

-- ============================================================================
-- PHASE 6: CREATE INDEX FOR PERFORMANCE
-- ============================================================================

-- Index to speed up coach relationship lookups in RLS policies
CREATE INDEX IF NOT EXISTS idx_car_coach_athlete_status
ON coach_athlete_relationships(coach_user_id, athlete_user_id, status);

-- ============================================================================
-- VERIFICATION COMMENT
-- ============================================================================
-- After running this migration, test by:
-- 1. Setting app.user_id to a coach's user_id
-- 2. Attempting to SELECT/UPDATE an athlete's activity
-- 3. Verify the operation succeeds when relationship is 'active'
-- 4. Verify the operation fails when relationship is not 'active'
-- ============================================================================
