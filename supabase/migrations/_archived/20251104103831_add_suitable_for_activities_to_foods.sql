-- Add suitable_for_activities column to foods table
-- This column is JSONB like {"running": true, "cycling": true, "swimming": false}
-- NULL means suitable for all activities (backward compatibility)

ALTER TABLE foods 
ADD COLUMN IF NOT EXISTS suitable_for_activities JSONB;

COMMENT ON COLUMN foods.suitable_for_activities IS 'JSONB map of sport types to boolean suitability. Example: {"running": true, "cycling": true, "swimming": false}. Null means suitable for all activities (backward compatibility).';

-- Set all existing foods to be suitable for all activities (NULL = universal)
-- This maintains backward compatibility
UPDATE foods 
SET suitable_for_activities = NULL 
WHERE suitable_for_activities IS NOT NULL;
