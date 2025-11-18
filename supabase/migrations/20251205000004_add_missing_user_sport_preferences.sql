-- Migration: Add missing cycling/swimming preference columns to users table
-- These columns exist in the local Drift schema but are missing from production

-- Add cycling preference columns
ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS typical_bike_bottles integer,
ADD COLUMN IF NOT EXISTS has_aero_bottle boolean,
ADD COLUMN IF NOT EXISTS has_bento_box boolean;

-- Add swimming preference columns
ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS typical_wetsuit boolean,
ADD COLUMN IF NOT EXISTS typical_swim_cap_type text;

-- Add shared sport preference column
ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS gi_sensitivity boolean;

-- Add column comments for documentation
COMMENT ON COLUMN public.users.typical_bike_bottles IS 'Number of water bottles typically carried on bike (1-4)';
COMMENT ON COLUMN public.users.has_aero_bottle IS 'Whether cyclist has aero bottle for additional hydration';
COMMENT ON COLUMN public.users.has_bento_box IS 'Whether cyclist has bento box for additional nutrition storage';
COMMENT ON COLUMN public.users.typical_wetsuit IS 'Whether swimmer typically uses wetsuit in open water';
COMMENT ON COLUMN public.users.typical_swim_cap_type IS 'Typical swim cap type: none, latex, silicone, neoprene';
COMMENT ON COLUMN public.users.gi_sensitivity IS 'Whether user has GI sensitivity issues during endurance activities';

-- Add constraint for swim cap type validation
ALTER TABLE public.users
ADD CONSTRAINT check_swim_cap_type
CHECK (typical_swim_cap_type IS NULL OR typical_swim_cap_type IN ('none', 'latex', 'silicone', 'neoprene'));

-- Add constraint for typical bike bottles (reasonable range)
ALTER TABLE public.users
ADD CONSTRAINT check_bike_bottles
CHECK (typical_bike_bottles IS NULL OR (typical_bike_bottles >= 0 AND typical_bike_bottles <= 6));
