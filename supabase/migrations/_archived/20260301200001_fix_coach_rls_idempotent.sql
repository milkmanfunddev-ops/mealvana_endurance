-- ============================================================================
-- IDEMPOTENT FIX: Drop and recreate all coach access RLS policies
-- ============================================================================
-- Fixes error: policy "carb_meals_select_policy" already exists
-- This script drops ALL policy names (both old and new) before recreating.
-- ============================================================================

-- ============================================================================
-- PHASE 1: ACTIVITIES TABLE
-- ============================================================================

DROP POLICY IF EXISTS "activities_select_policy" ON activities;
DROP POLICY IF EXISTS "activities_insert_policy" ON activities;
DROP POLICY IF EXISTS "activities_update_policy" ON activities;
DROP POLICY IF EXISTS "activities_delete_policy" ON activities;

CREATE POLICY "activities_select_policy" ON activities FOR SELECT USING (
  user_id = current_setting('app.user_id', true)::uuid
  OR EXISTS (
    SELECT 1 FROM coach_athlete_relationships
    WHERE coach_user_id = current_setting('app.user_id', true)::uuid
      AND athlete_user_id = activities.user_id
      AND status = 'active'
  )
);

CREATE POLICY "activities_insert_policy" ON activities FOR INSERT WITH CHECK (
  user_id = current_setting('app.user_id', true)::uuid
  OR EXISTS (
    SELECT 1 FROM coach_athlete_relationships
    WHERE coach_user_id = current_setting('app.user_id', true)::uuid
      AND athlete_user_id = activities.user_id
      AND status = 'active'
  )
);

CREATE POLICY "activities_update_policy" ON activities FOR UPDATE USING (
  user_id = current_setting('app.user_id', true)::uuid
  OR EXISTS (
    SELECT 1 FROM coach_athlete_relationships
    WHERE coach_user_id = current_setting('app.user_id', true)::uuid
      AND athlete_user_id = activities.user_id
      AND status = 'active'
  )
);

CREATE POLICY "activities_delete_policy" ON activities FOR DELETE USING (
  user_id = current_setting('app.user_id', true)::uuid
);

-- ============================================================================
-- PHASE 2: EVENTS TABLE (FIXED: uses events.user_id directly)
-- ============================================================================

DROP POLICY IF EXISTS "events_select_policy" ON events;
DROP POLICY IF EXISTS "events_insert_policy" ON events;
DROP POLICY IF EXISTS "events_update_policy" ON events;
DROP POLICY IF EXISTS "events_delete_policy" ON events;
DROP POLICY IF EXISTS "Users can view their own events" ON events;
DROP POLICY IF EXISTS "Users can insert their own events" ON events;
DROP POLICY IF EXISTS "Users can update their own events" ON events;
DROP POLICY IF EXISTS "Users can delete their own events" ON events;

CREATE POLICY "events_select_policy" ON events FOR SELECT USING (
  user_id = current_setting('app.user_id', true)::uuid
  OR EXISTS (
    SELECT 1 FROM coach_athlete_relationships
    WHERE coach_user_id = current_setting('app.user_id', true)::uuid
      AND athlete_user_id = events.user_id
      AND status = 'active'
  )
);

CREATE POLICY "events_insert_policy" ON events FOR INSERT WITH CHECK (
  user_id = current_setting('app.user_id', true)::uuid
  OR EXISTS (
    SELECT 1 FROM coach_athlete_relationships
    WHERE coach_user_id = current_setting('app.user_id', true)::uuid
      AND athlete_user_id = events.user_id
      AND status = 'active'
  )
);

CREATE POLICY "events_update_policy" ON events FOR UPDATE USING (
  user_id = current_setting('app.user_id', true)::uuid
  OR EXISTS (
    SELECT 1 FROM coach_athlete_relationships
    WHERE coach_user_id = current_setting('app.user_id', true)::uuid
      AND athlete_user_id = events.user_id
      AND status = 'active'
  )
);

CREATE POLICY "events_delete_policy" ON events FOR DELETE USING (
  user_id = current_setting('app.user_id', true)::uuid
);

-- ============================================================================
-- PHASE 3: CARB_LOADING_PLANS TABLE
-- ============================================================================

DROP POLICY IF EXISTS "carb_plans_select_policy" ON carb_loading_plans;
DROP POLICY IF EXISTS "carb_plans_insert_policy" ON carb_loading_plans;
DROP POLICY IF EXISTS "carb_plans_update_policy" ON carb_loading_plans;
DROP POLICY IF EXISTS "carb_plans_delete_policy" ON carb_loading_plans;

CREATE POLICY "carb_plans_select_policy" ON carb_loading_plans FOR SELECT USING (
  user_id = current_setting('app.user_id', true)::uuid
  OR EXISTS (
    SELECT 1 FROM coach_athlete_relationships
    WHERE coach_user_id = current_setting('app.user_id', true)::uuid
      AND athlete_user_id = carb_loading_plans.user_id
      AND status = 'active'
  )
);

CREATE POLICY "carb_plans_insert_policy" ON carb_loading_plans FOR INSERT WITH CHECK (
  user_id = current_setting('app.user_id', true)::uuid
  OR EXISTS (
    SELECT 1 FROM coach_athlete_relationships
    WHERE coach_user_id = current_setting('app.user_id', true)::uuid
      AND athlete_user_id = carb_loading_plans.user_id
      AND status = 'active'
  )
);

CREATE POLICY "carb_plans_update_policy" ON carb_loading_plans FOR UPDATE USING (
  user_id = current_setting('app.user_id', true)::uuid
  OR EXISTS (
    SELECT 1 FROM coach_athlete_relationships
    WHERE coach_user_id = current_setting('app.user_id', true)::uuid
      AND athlete_user_id = carb_loading_plans.user_id
      AND status = 'active'
  )
);

CREATE POLICY "carb_plans_delete_policy" ON carb_loading_plans FOR DELETE USING (
  user_id = current_setting('app.user_id', true)::uuid
);

-- ============================================================================
-- PHASE 4: CARB_LOADING_DAYS TABLE
-- ============================================================================

DROP POLICY IF EXISTS "carb_days_select_policy" ON carb_loading_days;
DROP POLICY IF EXISTS "carb_days_insert_policy" ON carb_loading_days;
DROP POLICY IF EXISTS "carb_days_update_policy" ON carb_loading_days;
DROP POLICY IF EXISTS "carb_days_delete_policy" ON carb_loading_days;

CREATE POLICY "carb_days_select_policy" ON carb_loading_days FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM carb_loading_plans
    WHERE carb_loading_plans.id = carb_loading_days.carb_loading_plan_id
      AND (
        carb_loading_plans.user_id = current_setting('app.user_id', true)::uuid
        OR EXISTS (
          SELECT 1 FROM coach_athlete_relationships
          WHERE coach_user_id = current_setting('app.user_id', true)::uuid
            AND athlete_user_id = carb_loading_plans.user_id
            AND status = 'active'
        )
      )
  )
);

CREATE POLICY "carb_days_insert_policy" ON carb_loading_days FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM carb_loading_plans
    WHERE carb_loading_plans.id = carb_loading_days.carb_loading_plan_id
      AND (
        carb_loading_plans.user_id = current_setting('app.user_id', true)::uuid
        OR EXISTS (
          SELECT 1 FROM coach_athlete_relationships
          WHERE coach_user_id = current_setting('app.user_id', true)::uuid
            AND athlete_user_id = carb_loading_plans.user_id
            AND status = 'active'
        )
      )
  )
);

CREATE POLICY "carb_days_update_policy" ON carb_loading_days FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM carb_loading_plans
    WHERE carb_loading_plans.id = carb_loading_days.carb_loading_plan_id
      AND (
        carb_loading_plans.user_id = current_setting('app.user_id', true)::uuid
        OR EXISTS (
          SELECT 1 FROM coach_athlete_relationships
          WHERE coach_user_id = current_setting('app.user_id', true)::uuid
            AND athlete_user_id = carb_loading_plans.user_id
            AND status = 'active'
        )
      )
  )
);

CREATE POLICY "carb_days_delete_policy" ON carb_loading_days FOR DELETE USING (
  EXISTS (
    SELECT 1 FROM carb_loading_plans
    WHERE carb_loading_plans.id = carb_loading_days.carb_loading_plan_id
      AND carb_loading_plans.user_id = current_setting('app.user_id', true)::uuid
  )
);

-- ============================================================================
-- PHASE 5: CARB_LOADING_DAY_MEALS TABLE
-- ============================================================================
-- Drop BOTH old and new policy names to be fully idempotent

DROP POLICY IF EXISTS "carb_loading_day_meals_device_read" ON carb_loading_day_meals;
DROP POLICY IF EXISTS "carb_loading_day_meals_device_insert" ON carb_loading_day_meals;
DROP POLICY IF EXISTS "carb_loading_day_meals_device_update" ON carb_loading_day_meals;
DROP POLICY IF EXISTS "carb_loading_day_meals_device_delete" ON carb_loading_day_meals;
DROP POLICY IF EXISTS "carb_meals_select_policy" ON carb_loading_day_meals;
DROP POLICY IF EXISTS "carb_meals_insert_policy" ON carb_loading_day_meals;
DROP POLICY IF EXISTS "carb_meals_update_policy" ON carb_loading_day_meals;
DROP POLICY IF EXISTS "carb_meals_delete_policy" ON carb_loading_day_meals;

CREATE POLICY "carb_meals_select_policy" ON carb_loading_day_meals FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM carb_loading_days d
    JOIN carb_loading_plans p ON p.id = d.carb_loading_plan_id
    WHERE d.id = carb_loading_day_meals.carb_loading_day_id
      AND (
        p.user_id = current_setting('app.user_id', true)::uuid
        OR EXISTS (
          SELECT 1 FROM coach_athlete_relationships
          WHERE coach_user_id = current_setting('app.user_id', true)::uuid
            AND athlete_user_id = p.user_id
            AND status = 'active'
        )
      )
  )
);

CREATE POLICY "carb_meals_insert_policy" ON carb_loading_day_meals FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM carb_loading_days d
    JOIN carb_loading_plans p ON p.id = d.carb_loading_plan_id
    WHERE d.id = carb_loading_day_meals.carb_loading_day_id
      AND (
        p.user_id = current_setting('app.user_id', true)::uuid
        OR EXISTS (
          SELECT 1 FROM coach_athlete_relationships
          WHERE coach_user_id = current_setting('app.user_id', true)::uuid
            AND athlete_user_id = p.user_id
            AND status = 'active'
        )
      )
  )
);

CREATE POLICY "carb_meals_update_policy" ON carb_loading_day_meals FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM carb_loading_days d
    JOIN carb_loading_plans p ON p.id = d.carb_loading_plan_id
    WHERE d.id = carb_loading_day_meals.carb_loading_day_id
      AND (
        p.user_id = current_setting('app.user_id', true)::uuid
        OR EXISTS (
          SELECT 1 FROM coach_athlete_relationships
          WHERE coach_user_id = current_setting('app.user_id', true)::uuid
            AND athlete_user_id = p.user_id
            AND status = 'active'
        )
      )
  )
);

CREATE POLICY "carb_meals_delete_policy" ON carb_loading_day_meals FOR DELETE USING (
  EXISTS (
    SELECT 1 FROM carb_loading_days d
    JOIN carb_loading_plans p ON p.id = d.carb_loading_plan_id
    WHERE d.id = carb_loading_day_meals.carb_loading_day_id
      AND p.user_id = current_setting('app.user_id', true)::uuid
  )
);

-- ============================================================================
-- PHASE 6: PERFORMANCE INDEX
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_car_coach_athlete_status
ON coach_athlete_relationships(coach_user_id, athlete_user_id, status);
