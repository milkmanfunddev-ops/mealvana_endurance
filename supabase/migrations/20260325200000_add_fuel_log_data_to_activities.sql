-- Add fuel_log_data column to activities table for tracking actual consumption
ALTER TABLE activities ADD COLUMN IF NOT EXISTS fuel_log_data JSONB;

COMMENT ON COLUMN activities.fuel_log_data IS 'Actual consumption data logged on activity completion. JSON with items array containing planned vs actual quantities per food.';
