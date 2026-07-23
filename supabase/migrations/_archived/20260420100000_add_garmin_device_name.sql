-- Track Garmin device model so we can attribute derived data per
-- Garmin brand guidelines ("Garmin [device model]" attribution on screens
-- that display data inferred from Garmin Connect activity pushes).
ALTER TABLE activities
ADD COLUMN IF NOT EXISTS garmin_device_name TEXT;
