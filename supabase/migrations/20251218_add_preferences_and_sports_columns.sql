-- Idempotent migration to add dietary preferences, allergies, and sport-specific columns
-- Safe to run on production - uses IF NOT EXISTS and DO $$ blocks

-- ============================================================================
-- 1. Create ENUM types if they don't exist
-- ============================================================================

-- Dietary Preference Enum
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'dietary_preference_enum') THEN
        CREATE TYPE public.dietary_preference_enum AS ENUM (
            'omnivore',
            'vegetarian',
            'pescatarian',
            'vegan',
            'mediterranean',
            'paleo',
            'keto',
            'low_carb'
        );
        COMMENT ON TYPE public.dietary_preference_enum IS 'User dietary preference options for food filtering';
    END IF;
END $$;

-- Allergy Enum
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'allergy_enum') THEN
        CREATE TYPE public.allergy_enum AS ENUM (
            'dairy',
            'eggs',
            'fish',
            'gluten',
            'peanuts',
            'sesame',
            'shellfish',
            'soy',
            'tree_nuts'
        );
        COMMENT ON TYPE public.allergy_enum IS 'Common food allergens for user allergy tracking';
    END IF;
END $$;

-- ============================================================================
-- 2. Add columns to users table (if they don't exist)
-- ============================================================================

-- Dietary Preference
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema = 'public'
                   AND table_name = 'users'
                   AND column_name = 'dietary_preference') THEN
        ALTER TABLE public.users ADD COLUMN dietary_preference public.dietary_preference_enum;
    END IF;
END $$;

-- Allergies
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema = 'public'
                   AND table_name = 'users'
                   AND column_name = 'allergies') THEN
        ALTER TABLE public.users ADD COLUMN allergies public.allergy_enum[] DEFAULT '{}'::public.allergy_enum[];
    END IF;
END $$;

-- GI Sensitivity
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema = 'public'
                   AND table_name = 'users'
                   AND column_name = 'gi_sensitivity') THEN
        ALTER TABLE public.users ADD COLUMN gi_sensitivity boolean;
    END IF;
END $$;

-- Cycling FTP Watts
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema = 'public'
                   AND table_name = 'users'
                   AND column_name = 'cycling_ftp_watts') THEN
        ALTER TABLE public.users ADD COLUMN cycling_ftp_watts integer;
    END IF;
END $$;

-- Typical Bike Bottles
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema = 'public'
                   AND table_name = 'users'
                   AND column_name = 'typical_bike_bottles') THEN
        ALTER TABLE public.users ADD COLUMN typical_bike_bottles integer;
    END IF;
END $$;

-- Has Aero Bottle
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema = 'public'
                   AND table_name = 'users'
                   AND column_name = 'has_aero_bottle') THEN
        ALTER TABLE public.users ADD COLUMN has_aero_bottle boolean;
    END IF;
END $$;

-- Has Bento Box
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema = 'public'
                   AND table_name = 'users'
                   AND column_name = 'has_bento_box') THEN
        ALTER TABLE public.users ADD COLUMN has_bento_box boolean;
    END IF;
END $$;

-- Swimming CSS Seconds Per 100m
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema = 'public'
                   AND table_name = 'users'
                   AND column_name = 'swimming_css_seconds_per_100m') THEN
        ALTER TABLE public.users ADD COLUMN swimming_css_seconds_per_100m integer;
    END IF;
END $$;

-- Typical Wetsuit
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema = 'public'
                   AND table_name = 'users'
                   AND column_name = 'typical_wetsuit') THEN
        ALTER TABLE public.users ADD COLUMN typical_wetsuit boolean;
    END IF;
END $$;

-- Typical Swim Cap Type
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema = 'public'
                   AND table_name = 'users'
                   AND column_name = 'typical_swim_cap_type') THEN
        ALTER TABLE public.users ADD COLUMN typical_swim_cap_type text;
    END IF;
END $$;

-- Prefers Cycling Power (optional - for future use)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema = 'public'
                   AND table_name = 'users'
                   AND column_name = 'prefers_cycling_power') THEN
        ALTER TABLE public.users ADD COLUMN prefers_cycling_power boolean DEFAULT false;
    END IF;
END $$;

-- Prefers Swimming Pace (optional - for future use)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema = 'public'
                   AND table_name = 'users'
                   AND column_name = 'prefers_swimming_pace') THEN
        ALTER TABLE public.users ADD COLUMN prefers_swimming_pace boolean DEFAULT false;
    END IF;
END $$;

-- ============================================================================
-- 3. Add constraints (if they don't exist)
-- ============================================================================

-- Bike bottles constraint (0-6)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                   WHERE conname = 'check_bike_bottles') THEN
        ALTER TABLE public.users ADD CONSTRAINT check_bike_bottles
        CHECK ((typical_bike_bottles IS NULL) OR
               ((typical_bike_bottles >= 0) AND (typical_bike_bottles <= 6)));
    END IF;
END $$;

-- Swim cap type constraint
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                   WHERE conname = 'check_swim_cap_type') THEN
        ALTER TABLE public.users ADD CONSTRAINT check_swim_cap_type
        CHECK ((typical_swim_cap_type IS NULL) OR
               (typical_swim_cap_type = ANY (ARRAY['none'::text, 'latex'::text, 'silicone'::text, 'neoprene'::text])));
    END IF;
END $$;

-- ============================================================================
-- 4. Add indexes (if they don't exist)
-- ============================================================================

-- Index on dietary_preference (only non-null values)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_indexes
                   WHERE schemaname = 'public'
                   AND tablename = 'users'
                   AND indexname = 'idx_users_dietary_preference') THEN
        CREATE INDEX idx_users_dietary_preference ON public.users (dietary_preference)
        WHERE (dietary_preference IS NOT NULL);
    END IF;
END $$;

-- ============================================================================
-- 5. Add column comments
-- ============================================================================

COMMENT ON COLUMN public.users.dietary_preference IS 'User dietary preference: omnivore, vegetarian, pescatarian, vegan, mediterranean, paleo, keto, low_carb. NULL means no preference set.';
COMMENT ON COLUMN public.users.allergies IS 'Array of user allergies for food filtering. Empty array means no allergies.';
COMMENT ON COLUMN public.users.gi_sensitivity IS 'Whether user has GI sensitivity issues during endurance activities';
COMMENT ON COLUMN public.users.cycling_ftp_watts IS 'User default FTP (Functional Threshold Power) in watts';
COMMENT ON COLUMN public.users.typical_bike_bottles IS 'Number of water bottles typically carried on bike (0-6)';
COMMENT ON COLUMN public.users.has_aero_bottle IS 'Whether cyclist has aero bottle for additional hydration';
COMMENT ON COLUMN public.users.has_bento_box IS 'Whether cyclist has bento box for additional nutrition storage';
COMMENT ON COLUMN public.users.swimming_css_seconds_per_100m IS 'User default CSS (Critical Swim Speed) in seconds per 100m';
COMMENT ON COLUMN public.users.typical_wetsuit IS 'Whether swimmer typically uses wetsuit in open water';
COMMENT ON COLUMN public.users.typical_swim_cap_type IS 'Typical swim cap type: none, latex, silicone, neoprene';
COMMENT ON COLUMN public.users.prefers_cycling_power IS 'Whether user prefers to input power vs speed for cycling';
COMMENT ON COLUMN public.users.prefers_swimming_pace IS 'Whether user prefers to input pace vs speed for swimming';

-- ============================================================================
-- 6. Verification query (run this separately to verify)
-- ============================================================================

-- Uncomment to verify all columns exist:
-- SELECT column_name, data_type, is_nullable, column_default
-- FROM information_schema.columns
-- WHERE table_schema = 'public'
-- AND table_name = 'users'
-- AND column_name IN (
--     'dietary_preference', 'allergies', 'gi_sensitivity',
--     'cycling_ftp_watts', 'typical_bike_bottles', 'has_aero_bottle', 'has_bento_box',
--     'swimming_css_seconds_per_100m', 'typical_wetsuit', 'typical_swim_cap_type',
--     'prefers_cycling_power', 'prefers_swimming_pace'
-- )
-- ORDER BY column_name;
