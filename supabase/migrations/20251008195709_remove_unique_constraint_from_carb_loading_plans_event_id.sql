-- Remove UNIQUE constraint from carb_loading_plans.event_id to allow multiple carb loading plans
-- This supports the use case of having multiple active carb loading plans simultaneously

-- Drop the unique constraint on event_id
ALTER TABLE carb_loading_plans
DROP CONSTRAINT IF EXISTS carb_loading_plans_event_id_key;

-- The column should already be nullable, but let's ensure it explicitly
ALTER TABLE carb_loading_plans
ALTER COLUMN event_id DROP NOT NULL;

-- Add a comment explaining the schema design
COMMENT ON COLUMN carb_loading_plans.event_id IS
'FOREIGN KEY to events.id. Nullable to support standalone carb loading plans not tied to specific events. Multiple plans can share the same event_id.';
