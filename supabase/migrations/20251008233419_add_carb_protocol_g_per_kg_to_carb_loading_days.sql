-- Add carb_protocol_g_per_kg column to carb_loading_days table
-- This stores the carbohydrate protocol formula (e.g., 8.0 for 8g/kg bodyweight)
-- so the UI can display "8g/kg bodyweight" instead of just "610g carbs target"

ALTER TABLE carb_loading_days
ADD COLUMN carb_protocol_g_per_kg REAL NOT NULL DEFAULT 8.0;

-- Add comment explaining the column
COMMENT ON COLUMN carb_loading_days.carb_protocol_g_per_kg IS 'Carbohydrate protocol in grams per kilogram of bodyweight (e.g., 8.0 for 8g/kg)';
