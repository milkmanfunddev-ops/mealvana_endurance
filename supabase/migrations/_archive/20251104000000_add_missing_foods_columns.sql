-- ============================================================================
-- Unify foods table schema across DEV/PROD/Drift
-- Adds 16 missing columns to DEV (3 from PROD + 13 from Drift)
-- Adds 13 missing columns to PROD (from Drift)
-- Target: 34 total columns
-- ============================================================================

-- Add 3 columns from PROD
ALTER TABLE public.foods
  ADD COLUMN IF NOT EXISTS cycling_suitable boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS swimming_suitable boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS suitable_for_activities jsonb;

-- Add 13 columns from Drift (used in business logic)
ALTER TABLE public.foods
  ADD COLUMN IF NOT EXISTS before_run_suitable boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS during_run_suitable boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS run_portable boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS requires_preparation boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS aid_station_available boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS after_run_suitable boolean,
  ADD COLUMN IF NOT EXISTS instructions text,
  ADD COLUMN IF NOT EXISTS nutritional_info text,
  ADD COLUMN IF NOT EXISTS serving_unit text,
  ADD COLUMN IF NOT EXISTS serving_unit_plural text,
  ADD COLUMN IF NOT EXISTS serving_qualifier text,
  ADD COLUMN IF NOT EXISTS purchase_url text,
  ADD COLUMN IF NOT EXISTS affiliate_source text,
  ADD COLUMN IF NOT EXISTS preference_priority integer;
