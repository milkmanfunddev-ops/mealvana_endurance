-- Fix 1: Add missing categories (before_run, during_run, after_run)
-- These are essential for the nutrition plan edge function to work

INSERT INTO categories (id, name)
VALUES 
  (1, 'before_run'),
  (2, 'during_run'),
  (3, 'after_run')
ON CONFLICT (id) DO NOTHING;

-- Fix 2: Add suitable_for_activities column to user_foods
-- This column is JSONB like {"running": true, "cycling": true, "swimming": false}
-- NULL means suitable for all activities (backward compatibility)

ALTER TABLE user_foods 
ADD COLUMN IF NOT EXISTS suitable_for_activities JSONB;

COMMENT ON COLUMN user_foods.suitable_for_activities IS 'JSONB map of sport types to boolean suitability. Example: {"running": true, "cycling": true, "swimming": false}. Null means suitable for all activities (backward compatibility).';
