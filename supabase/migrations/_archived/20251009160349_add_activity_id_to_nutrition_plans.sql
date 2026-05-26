-- Add activity_id column to nutrition_plans table
-- This links nutrition plans to calendar activities/events
-- Non-breaking change: nullable column with no default

-- Add the activity_id column
ALTER TABLE nutrition_plans
ADD COLUMN activity_id TEXT NULL;

-- Add foreign key constraint to activities table
ALTER TABLE nutrition_plans
ADD CONSTRAINT fk_nutrition_plans_activity_id
FOREIGN KEY (activity_id)
REFERENCES activities(id)
ON DELETE SET NULL;

-- Add index for faster lookups
CREATE INDEX idx_nutrition_plans_activity_id ON nutrition_plans(activity_id);

-- Add comment for documentation
COMMENT ON COLUMN nutrition_plans.activity_id IS 'Links nutrition plan to a calendar activity/event. Nullable to support standalone plans.';
