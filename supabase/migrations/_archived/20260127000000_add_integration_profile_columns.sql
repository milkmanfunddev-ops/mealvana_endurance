-- ============================================================================
-- Migration: Add Integration Profile Data Columns
--
-- Purpose: Store athlete profile data from integration providers for
--          auto-populating user profile during onboarding
--
-- Changes:
--   1. Add provider_athlete_weight_kg (REAL) to integrations table
--   2. Add provider_athlete_birth_month (TEXT) to integrations table
--   3. Add provider_athlete_gender (TEXT) to integrations table
--
-- Provider Data Availability:
--   - Training Peaks: Provides weight (kg), birth month (YYYY-MM), sex (m/f)
--   - Final Surge: Does NOT provide biometric data (only name/email)
--   - Strava/Garmin: TBD
--
-- Use Case:
--   When user connects Training Peaks during onboarding, we fetch their
--   profile data and store it here. The "Tell us about yourself" screen
--   then auto-populates weight, birthday, and gender from this data.
-- ============================================================================

-- ============================================================================
-- STEP 1: Add provider_athlete_weight_kg column
-- Weight in kilograms (Training Peaks provides this)
-- ============================================================================

ALTER TABLE integrations
ADD COLUMN IF NOT EXISTS provider_athlete_weight_kg REAL DEFAULT NULL;

COMMENT ON COLUMN integrations.provider_athlete_weight_kg IS 'Athlete weight in kilograms from provider profile (Training Peaks). Used to auto-populate user profile during onboarding. Convert to lbs: kg * 2.20462';

-- ============================================================================
-- STEP 2: Add provider_athlete_birth_month column
-- Birth month in "YYYY-MM" format (Training Peaks only provides month, not day)
-- ============================================================================

ALTER TABLE integrations
ADD COLUMN IF NOT EXISTS provider_athlete_birth_month TEXT DEFAULT NULL;

COMMENT ON COLUMN integrations.provider_athlete_birth_month IS 'Athlete birth month in YYYY-MM format from provider profile (Training Peaks). Note: Training Peaks does NOT provide birth day, only year and month. Default to 1st of month when displaying.';

-- ============================================================================
-- STEP 3: Add provider_athlete_gender column
-- Gender as 'm' or 'f' (Training Peaks format)
-- ============================================================================

ALTER TABLE integrations
ADD COLUMN IF NOT EXISTS provider_athlete_gender TEXT DEFAULT NULL;

COMMENT ON COLUMN integrations.provider_athlete_gender IS 'Athlete gender from provider profile (Training Peaks). Values: "m" for male, "f" for female. Map to app Gender enum during auto-population.';

-- ============================================================================
-- Migration complete!
--
-- New columns:
--   - provider_athlete_weight_kg (REAL): Weight in kg from Training Peaks
--   - provider_athlete_birth_month (TEXT): Birth month "YYYY-MM" from Training Peaks
--   - provider_athlete_gender (TEXT): Gender "m" or "f" from Training Peaks
--
-- Usage in app:
--   1. TrainingPeaksOAuthService fetches profile during authentication
--   2. Profile data stored in IntegrationModel with these fields
--   3. UserProfileScreen.initState() checks for integration data
--   4. If found, auto-populates form fields (user can override)
--
-- Conversion notes:
--   - Weight: kg * 2.20462 = lbs
--   - Birthday: "YYYY-MM" -> DateTime(year, month, 1) [default to 1st]
--   - Gender: "m" -> Gender.male, "f" -> Gender.female
-- ============================================================================
