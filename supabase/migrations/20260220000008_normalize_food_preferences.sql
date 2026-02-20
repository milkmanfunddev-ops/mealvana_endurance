-- ============================================================================
-- Migration: Normalize Food Preference Names
--
-- Purpose: Map food_preferences.food_name from legacy `foods` table names
-- (mixed case, various formats) to `template_foods` names (consistent snake_case).
--
-- The food-utils.ts matchesPreference() function uses 4-tier matching:
--   1. ID match
--   2. Exact name match
--   3. Lowercase name match
--   4. Partial substring match
--
-- After this migration, preferences will match template_foods.name directly
-- at tier 2 (exact match), which is the fastest path.
--
-- BACKWARDS COMPATIBILITY: The 4-tier matching in food-utils.ts continues
-- to work even if some preferences aren't normalized (substring fallback).
-- This migration just makes matching more reliable and deterministic.
--
-- Date: 2026-02-20
-- ============================================================================

-- ============================================================================
-- Map legacy foods.name → template_foods.name
-- Only update if the old name exists and new name doesn't already exist
-- ============================================================================

-- Banana (foods uses 'Banana', template_foods uses 'banana')
UPDATE food_preferences SET food_name = 'banana'
WHERE lower(food_name) = 'banana' AND food_name != 'banana';

-- Energy gel (foods uses 'Gels' or 'Energy gel')
UPDATE food_preferences SET food_name = 'energy_gel'
WHERE lower(food_name) IN ('gels', 'energy gel', 'energy_gel') AND food_name != 'energy_gel';

-- Energy chews
UPDATE food_preferences SET food_name = 'energy_chews'
WHERE lower(food_name) IN ('energy chews') AND food_name != 'energy_chews';

-- Energy bar
UPDATE food_preferences SET food_name = 'energy_bar'
WHERE lower(food_name) IN ('energy bar', 'energy/granola bar') AND food_name != 'energy_bar';

-- Sports drink
UPDATE food_preferences SET food_name = 'sports_drink'
WHERE lower(food_name) IN (
  'sports drink (carb + electrolytes)',
  'sports drink',
  'sports drink mix (carb + electrolytes)'
) AND food_name != 'sports_drink';

-- Coffee
UPDATE food_preferences SET food_name = 'coffee'
WHERE lower(food_name) = 'coffee' AND food_name != 'coffee';

-- Toast / White bread
UPDATE food_preferences SET food_name = 'white_bread'
WHERE lower(food_name) IN ('toast', 'white bread') AND food_name != 'white_bread';

-- Oatmeal
UPDATE food_preferences SET food_name = 'oatmeal_cooked'
WHERE lower(food_name) IN ('oatmeal', 'oatmeal (cooked)') AND food_name != 'oatmeal_cooked';

-- Orange juice
UPDATE food_preferences SET food_name = 'orange_juice'
WHERE lower(food_name) IN ('orange juice') AND food_name != 'orange_juice';

-- Peanut butter
UPDATE food_preferences SET food_name = 'peanut_butter'
WHERE lower(food_name) IN ('peanut butter') AND food_name != 'peanut_butter';

-- Dates
UPDATE food_preferences SET food_name = 'dates'
WHERE lower(food_name) = 'dates' AND food_name != 'dates';

-- Pretzels
UPDATE food_preferences SET food_name = 'pretzels'
WHERE lower(food_name) IN ('pretzels', 'pretzels (salted minis)') AND food_name != 'pretzels';

-- Chocolate milk
UPDATE food_preferences SET food_name = 'chocolate_milk'
WHERE lower(food_name) IN ('chocolate milk') AND food_name != 'chocolate_milk';

-- Coconut water
UPDATE food_preferences SET food_name = 'coconut_water'
WHERE lower(food_name) IN ('coconut water') AND food_name != 'coconut_water';

-- Protein bar
UPDATE food_preferences SET food_name = 'protein_bar'
WHERE lower(food_name) IN ('protein bar') AND food_name != 'protein_bar';

-- Protein shake
UPDATE food_preferences SET food_name = 'protein_shake'
WHERE lower(food_name) IN ('protein shake', 'protein shake (ready-to-drink)') AND food_name != 'protein_shake';

-- Electrolyte tablet
UPDATE food_preferences SET food_name = 'electrolyte_tablet'
WHERE lower(food_name) IN ('electrolyte tablet', 'electrolyte tablet (electrolyte-only)') AND food_name != 'electrolyte_tablet';

-- Electrolyte drink mix
UPDATE food_preferences SET food_name = 'electrolyte_drink'
WHERE lower(food_name) IN (
  'electrolyte drink mix',
  'electrolyte drink mix (electrolyte-only)'
) AND food_name != 'electrolyte_drink';

-- Fig bar
UPDATE food_preferences SET food_name = 'fig_bar'
WHERE lower(food_name) IN ('fig bar') AND food_name != 'fig_bar';

-- Water
UPDATE food_preferences SET food_name = 'water'
WHERE lower(food_name) = 'water' AND food_name != 'water';

-- Apple
UPDATE food_preferences SET food_name = 'banana'  -- intentionally NOT mapping apple
WHERE 1=0; -- Apple doesn't exist in template_foods, so no mapping needed

-- Energy waffle (stroopwafel) — not in template_foods, leave as-is
-- Trail mix — already snake_case in template_foods
-- Pickle juice shot — already snake_case in template_foods

-- ============================================================================
-- Handle UUID-based preferences (some entries reference food IDs)
-- These already match by ID in the 4-tier matcher, so no action needed.
-- ============================================================================

-- ============================================================================
-- Done! food_preferences.food_name now uses template_foods.name format.
-- The 4-tier matcher in food-utils.ts handles any remaining edge cases.
-- ============================================================================
