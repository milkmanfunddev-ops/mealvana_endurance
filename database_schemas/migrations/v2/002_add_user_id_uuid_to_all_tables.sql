-- ============================================================================
-- Migration 002: Add user_id (UUID) to all user-scoped tables
-- ============================================================================
-- Description: Convert TEXT user_id columns to UUID foreign keys
-- Date: 2025-01-07
-- ============================================================================

BEGIN;

-- ============================================================================
-- Activities Table
-- ============================================================================
-- Drop old user_id column and recreate as UUID
ALTER TABLE public.activities
  DROP COLUMN IF EXISTS user_id CASCADE;

ALTER TABLE public.activities
  ADD COLUMN user_id UUID NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000'::UUID;

-- Set user_id based on device_id lookup (temporary migration logic)
-- This assumes single user per device_id
UPDATE public.activities a
SET user_id = u.id
FROM public.users u
WHERE a.id IN (
  SELECT DISTINCT id FROM public.activities
)
AND u.device_id = (
  SELECT device_id FROM public.users LIMIT 1
);

-- Add foreign key constraint
ALTER TABLE public.activities
  ADD CONSTRAINT activities_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

-- Add index
CREATE INDEX IF NOT EXISTS idx_activities_user_id ON public.activities (user_id);

COMMENT ON COLUMN public.activities.user_id IS 'Foreign key to users.id (UUID)';

-- ============================================================================
-- Events Table
-- ============================================================================
ALTER TABLE public.events
  DROP COLUMN IF EXISTS user_id CASCADE;

ALTER TABLE public.events
  ADD COLUMN user_id UUID NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000'::UUID;

UPDATE public.events e
SET user_id = u.id
FROM public.users u
WHERE e.id IN (SELECT DISTINCT id FROM public.events)
AND u.device_id = (SELECT device_id FROM public.users LIMIT 1);

ALTER TABLE public.events
  ADD CONSTRAINT events_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_events_user_id ON public.events (user_id);

COMMENT ON COLUMN public.events.user_id IS 'Foreign key to users.id (UUID)';

-- ============================================================================
-- Carb Loading Plans Table
-- ============================================================================
ALTER TABLE public.carb_loading_plans
  DROP COLUMN IF EXISTS user_id CASCADE;

ALTER TABLE public.carb_loading_plans
  ADD COLUMN user_id UUID NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000'::UUID;

UPDATE public.carb_loading_plans clp
SET user_id = u.id
FROM public.users u
WHERE clp.id IN (SELECT DISTINCT id FROM public.carb_loading_plans)
AND u.device_id = (SELECT device_id FROM public.users LIMIT 1);

ALTER TABLE public.carb_loading_plans
  ADD CONSTRAINT carb_loading_plans_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_carb_loading_plans_user_id ON public.carb_loading_plans (user_id);

COMMENT ON COLUMN public.carb_loading_plans.user_id IS 'Foreign key to users.id (UUID)';

-- ============================================================================
-- User Foods Table
-- ============================================================================
ALTER TABLE public.user_foods
  DROP COLUMN IF EXISTS user_id CASCADE;

ALTER TABLE public.user_foods
  ADD COLUMN user_id UUID NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000'::UUID;

UPDATE public.user_foods uf
SET user_id = u.id
FROM public.users u
WHERE uf.id IN (SELECT DISTINCT id FROM public.user_foods)
AND u.device_id = (SELECT device_id FROM public.users LIMIT 1);

ALTER TABLE public.user_foods
  ADD CONSTRAINT user_foods_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_user_foods_user_id ON public.user_foods (user_id);

COMMENT ON COLUMN public.user_foods.user_id IS 'Foreign key to users.id (UUID)';

-- ============================================================================
-- User Hidden Foods Table
-- ============================================================================
ALTER TABLE public.user_hidden_foods
  DROP COLUMN IF EXISTS user_id CASCADE;

ALTER TABLE public.user_hidden_foods
  ADD COLUMN user_id UUID NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000'::UUID;

UPDATE public.user_hidden_foods uhf
SET user_id = u.id
FROM public.users u
WHERE uhf.id IN (SELECT DISTINCT id FROM public.user_hidden_foods)
AND u.device_id = (SELECT device_id FROM public.users LIMIT 1);

ALTER TABLE public.user_hidden_foods
  ADD CONSTRAINT user_hidden_foods_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_user_hidden_foods_user_id ON public.user_hidden_foods (user_id);

COMMENT ON COLUMN public.user_hidden_foods.user_id IS 'Foreign key to users.id (UUID)';

-- ============================================================================
-- Carb Loading User Foods Table
-- ============================================================================
ALTER TABLE public.carb_loading_user_foods
  DROP COLUMN IF EXISTS user_id CASCADE;

ALTER TABLE public.carb_loading_user_foods
  ADD COLUMN user_id UUID NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000'::UUID;

UPDATE public.carb_loading_user_foods cluf
SET user_id = u.id
FROM public.users u
WHERE cluf.id IN (SELECT DISTINCT id FROM public.carb_loading_user_foods)
AND u.device_id = (SELECT device_id FROM public.users LIMIT 1);

ALTER TABLE public.carb_loading_user_foods
  ADD CONSTRAINT carb_loading_user_foods_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_carb_loading_user_foods_user_id ON public.carb_loading_user_foods (user_id);

COMMENT ON COLUMN public.carb_loading_user_foods.user_id IS 'Foreign key to users.id (UUID)';

-- ============================================================================
-- Food Preferences Table
-- ============================================================================
ALTER TABLE public.food_preferences
  DROP COLUMN IF EXISTS user_id CASCADE;

ALTER TABLE public.food_preferences
  ADD COLUMN user_id UUID NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000'::UUID;

UPDATE public.food_preferences fp
SET user_id = u.id
FROM public.users u
WHERE fp.id IN (SELECT DISTINCT id FROM public.food_preferences)
AND u.device_id = (SELECT device_id FROM public.users LIMIT 1);

ALTER TABLE public.food_preferences
  ADD CONSTRAINT food_preferences_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_food_preferences_user_id ON public.food_preferences (user_id);

COMMENT ON COLUMN public.food_preferences.user_id IS 'Foreign key to users.id (UUID)';

-- ============================================================================
-- Nutrition Plans Table (will be dropped later, but migrate for now)
-- ============================================================================
ALTER TABLE public.nutrition_plans
  DROP COLUMN IF EXISTS user_id CASCADE;

ALTER TABLE public.nutrition_plans
  ADD COLUMN user_id UUID DEFAULT '00000000-0000-0000-0000-000000000000'::UUID;

UPDATE public.nutrition_plans np
SET user_id = u.id
FROM public.users u
WHERE np.id IN (SELECT DISTINCT id FROM public.nutrition_plans)
AND u.device_id = (SELECT device_id FROM public.users LIMIT 1);

ALTER TABLE public.nutrition_plans
  ALTER COLUMN user_id SET NOT NULL;

ALTER TABLE public.nutrition_plans
  ADD CONSTRAINT nutrition_plans_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_nutrition_plans_user_id ON public.nutrition_plans (user_id);

COMMENT ON COLUMN public.nutrition_plans.user_id IS 'Foreign key to users.id (UUID) - TABLE WILL BE DROPPED IN LATER MIGRATION';

COMMIT;

SELECT 'user_id (UUID) added to all user-scoped tables' AS status;
