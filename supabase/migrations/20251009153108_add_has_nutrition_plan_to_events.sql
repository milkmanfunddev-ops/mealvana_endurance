-- Add has_nutrition_plan column to events table
-- This allows events to track whether they have an associated nutrition plan
-- Non-breaking change: defaults to FALSE for existing events

-- Add the column with a default value
ALTER TABLE events
ADD COLUMN has_nutrition_plan BOOLEAN DEFAULT FALSE;

-- Backfill existing events that have nutrition plans
-- Note: Currently nutrition_plans table doesn't have activity_id column yet
-- This backfill will be a no-op until nutrition_plans.activity_id is added
-- For now, we skip the backfill and rely on application code to set has_nutrition_plan
-- when creating nutrition plans for events

-- Future implementation (after nutrition_plans.activity_id is added):
-- UPDATE events e
-- SET has_nutrition_plan = TRUE
-- WHERE EXISTS (
--   SELECT 1
--   FROM nutrition_plans np
--   WHERE np.activity_id = e.activity_id
--     AND np.is_deleted = FALSE
-- );

-- Add comment for documentation
COMMENT ON COLUMN events.has_nutrition_plan IS 'Indicates whether this event has an associated nutrition plan (via activities.id -> nutrition_plans.activity_id)';
