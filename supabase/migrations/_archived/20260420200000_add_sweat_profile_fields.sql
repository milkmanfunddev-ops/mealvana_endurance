-- Add sweat profile fields to users table for hydration/sodium transparency (Phase 2).
-- These fields store the user's sweat profile data used by the generate-macros-v4
-- edge function to personalise fluid and sodium targets.
--
-- sweat_sodium: categorical sodium loss (low/average/high per Baker 2016).
--   Accepts 'medium' as a legacy alias but the canonical values are low/average/high.
-- known_sweat_rate_ml_per_hour: personal sweat-test result (ml/hr); overrides algorithmic estimate.
-- known_sodium_concentration_mg_per_liter: personal sweat-test result (mg/L); overrides estimate.
-- sweat_test_date: when the sweat test was performed.
-- sweat_test_source: how the test data was obtained.

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS sweat_sodium TEXT
    CHECK (sweat_sodium IN ('low', 'average', 'high', 'medium'));

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS known_sweat_rate_ml_per_hour INT;

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS known_sodium_concentration_mg_per_liter INT;

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS sweat_test_date TIMESTAMPTZ;

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS sweat_test_source TEXT
    CHECK (sweat_test_source IN ('self_calculated', 'commercial_test', 'gatorade_gx', 'estimated', 'other'));
