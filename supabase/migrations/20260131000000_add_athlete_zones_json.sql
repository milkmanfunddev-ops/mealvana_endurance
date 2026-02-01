-- Add athlete_zones_json column to integrations table
-- Stores serialized Training Peaks zone data (HR, Speed, Power zones)
-- Used for precise intensity classification and pace auto-suggest
ALTER TABLE integrations ADD COLUMN IF NOT EXISTS athlete_zones_json JSONB;
