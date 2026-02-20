-- ============================================================================
-- Migration: Normalize Food Preference Names
--
-- Purpose: Map food_preferences.food_name from legacy `foods` table names
-- (mixed case, various formats) to `template_foods` names (consistent snake_case).
--
-- Strategy: For each mapping, first DELETE the old-name row if a new-name row
-- already exists for the same user (avoid unique constraint violation on
-- idx_food_preferences_user_food), then UPDATE remaining old-name rows.
--
-- Date: 2026-02-20
-- ============================================================================

-- Helper: For each food rename, delete old-name rows where user already has new-name
-- Then rename remaining old-name rows to new-name

-- Energy gel (foods uses 'Gels' or 'Energy gel')
DELETE FROM food_preferences
WHERE lower(food_name) IN ('gels', 'energy gel')
  AND food_name != 'energy_gel'
  AND user_id IN (
    SELECT user_id FROM food_preferences WHERE food_name = 'energy_gel'
  );
UPDATE food_preferences SET food_name = 'energy_gel'
WHERE lower(food_name) IN ('gels', 'energy gel') AND food_name != 'energy_gel';

-- Energy chews
DELETE FROM food_preferences
WHERE lower(food_name) = 'energy chews'
  AND food_name != 'energy_chews'
  AND user_id IN (
    SELECT user_id FROM food_preferences WHERE food_name = 'energy_chews'
  );
UPDATE food_preferences SET food_name = 'energy_chews'
WHERE lower(food_name) = 'energy chews' AND food_name != 'energy_chews';

-- Energy bar
DELETE FROM food_preferences
WHERE lower(food_name) IN ('energy bar', 'energy/granola bar')
  AND food_name != 'energy_bar'
  AND user_id IN (
    SELECT user_id FROM food_preferences WHERE food_name = 'energy_bar'
  );
UPDATE food_preferences SET food_name = 'energy_bar'
WHERE lower(food_name) IN ('energy bar', 'energy/granola bar') AND food_name != 'energy_bar';

-- Sports drink
DELETE FROM food_preferences
WHERE lower(food_name) IN (
    'sports drink (carb + electrolytes)',
    'sports drink',
    'sports drink mix (carb + electrolytes)'
  )
  AND food_name != 'sports_drink'
  AND user_id IN (
    SELECT user_id FROM food_preferences WHERE food_name = 'sports_drink'
  );
UPDATE food_preferences SET food_name = 'sports_drink'
WHERE lower(food_name) IN (
  'sports drink (carb + electrolytes)',
  'sports drink',
  'sports drink mix (carb + electrolytes)'
) AND food_name != 'sports_drink';

-- Coffee
DELETE FROM food_preferences
WHERE lower(food_name) = 'coffee'
  AND food_name != 'coffee'
  AND user_id IN (
    SELECT user_id FROM food_preferences WHERE food_name = 'coffee'
  );
UPDATE food_preferences SET food_name = 'coffee'
WHERE lower(food_name) = 'coffee' AND food_name != 'coffee';

-- Toast / White bread
DELETE FROM food_preferences
WHERE lower(food_name) IN ('toast', 'white bread')
  AND food_name != 'white_bread'
  AND user_id IN (
    SELECT user_id FROM food_preferences WHERE food_name = 'white_bread'
  );
UPDATE food_preferences SET food_name = 'white_bread'
WHERE lower(food_name) IN ('toast', 'white bread') AND food_name != 'white_bread';

-- Banana
DELETE FROM food_preferences
WHERE lower(food_name) = 'banana'
  AND food_name != 'banana'
  AND user_id IN (
    SELECT user_id FROM food_preferences WHERE food_name = 'banana'
  );
UPDATE food_preferences SET food_name = 'banana'
WHERE lower(food_name) = 'banana' AND food_name != 'banana';

-- Oatmeal
DELETE FROM food_preferences
WHERE lower(food_name) IN ('oatmeal', 'oatmeal (cooked)')
  AND food_name != 'oatmeal_cooked'
  AND user_id IN (
    SELECT user_id FROM food_preferences WHERE food_name = 'oatmeal_cooked'
  );
UPDATE food_preferences SET food_name = 'oatmeal_cooked'
WHERE lower(food_name) IN ('oatmeal', 'oatmeal (cooked)') AND food_name != 'oatmeal_cooked';

-- Orange juice
DELETE FROM food_preferences
WHERE lower(food_name) = 'orange juice'
  AND food_name != 'orange_juice'
  AND user_id IN (
    SELECT user_id FROM food_preferences WHERE food_name = 'orange_juice'
  );
UPDATE food_preferences SET food_name = 'orange_juice'
WHERE lower(food_name) = 'orange juice' AND food_name != 'orange_juice';

-- Peanut butter
DELETE FROM food_preferences
WHERE lower(food_name) = 'peanut butter'
  AND food_name != 'peanut_butter'
  AND user_id IN (
    SELECT user_id FROM food_preferences WHERE food_name = 'peanut_butter'
  );
UPDATE food_preferences SET food_name = 'peanut_butter'
WHERE lower(food_name) = 'peanut butter' AND food_name != 'peanut_butter';

-- Dates
DELETE FROM food_preferences
WHERE lower(food_name) = 'dates'
  AND food_name != 'dates'
  AND user_id IN (
    SELECT user_id FROM food_preferences WHERE food_name = 'dates'
  );
UPDATE food_preferences SET food_name = 'dates'
WHERE lower(food_name) = 'dates' AND food_name != 'dates';

-- Pretzels
DELETE FROM food_preferences
WHERE lower(food_name) IN ('pretzels', 'pretzels (salted minis)')
  AND food_name != 'pretzels'
  AND user_id IN (
    SELECT user_id FROM food_preferences WHERE food_name = 'pretzels'
  );
UPDATE food_preferences SET food_name = 'pretzels'
WHERE lower(food_name) IN ('pretzels', 'pretzels (salted minis)') AND food_name != 'pretzels';

-- Chocolate milk
DELETE FROM food_preferences
WHERE lower(food_name) = 'chocolate milk'
  AND food_name != 'chocolate_milk'
  AND user_id IN (
    SELECT user_id FROM food_preferences WHERE food_name = 'chocolate_milk'
  );
UPDATE food_preferences SET food_name = 'chocolate_milk'
WHERE lower(food_name) = 'chocolate milk' AND food_name != 'chocolate_milk';

-- Coconut water
DELETE FROM food_preferences
WHERE lower(food_name) = 'coconut water'
  AND food_name != 'coconut_water'
  AND user_id IN (
    SELECT user_id FROM food_preferences WHERE food_name = 'coconut_water'
  );
UPDATE food_preferences SET food_name = 'coconut_water'
WHERE lower(food_name) = 'coconut water' AND food_name != 'coconut_water';

-- Protein bar
DELETE FROM food_preferences
WHERE lower(food_name) = 'protein bar'
  AND food_name != 'protein_bar'
  AND user_id IN (
    SELECT user_id FROM food_preferences WHERE food_name = 'protein_bar'
  );
UPDATE food_preferences SET food_name = 'protein_bar'
WHERE lower(food_name) = 'protein bar' AND food_name != 'protein_bar';

-- Protein shake
DELETE FROM food_preferences
WHERE lower(food_name) IN ('protein shake', 'protein shake (ready-to-drink)')
  AND food_name != 'protein_shake'
  AND user_id IN (
    SELECT user_id FROM food_preferences WHERE food_name = 'protein_shake'
  );
UPDATE food_preferences SET food_name = 'protein_shake'
WHERE lower(food_name) IN ('protein shake', 'protein shake (ready-to-drink)') AND food_name != 'protein_shake';

-- Electrolyte tablet
DELETE FROM food_preferences
WHERE lower(food_name) IN ('electrolyte tablet', 'electrolyte tablet (electrolyte-only)')
  AND food_name != 'electrolyte_tablet'
  AND user_id IN (
    SELECT user_id FROM food_preferences WHERE food_name = 'electrolyte_tablet'
  );
UPDATE food_preferences SET food_name = 'electrolyte_tablet'
WHERE lower(food_name) IN ('electrolyte tablet', 'electrolyte tablet (electrolyte-only)') AND food_name != 'electrolyte_tablet';

-- Electrolyte drink mix
DELETE FROM food_preferences
WHERE lower(food_name) IN ('electrolyte drink mix', 'electrolyte drink mix (electrolyte-only)')
  AND food_name != 'electrolyte_drink'
  AND user_id IN (
    SELECT user_id FROM food_preferences WHERE food_name = 'electrolyte_drink'
  );
UPDATE food_preferences SET food_name = 'electrolyte_drink'
WHERE lower(food_name) IN (
  'electrolyte drink mix',
  'electrolyte drink mix (electrolyte-only)'
) AND food_name != 'electrolyte_drink';

-- Fig bar
DELETE FROM food_preferences
WHERE lower(food_name) = 'fig bar'
  AND food_name != 'fig_bar'
  AND user_id IN (
    SELECT user_id FROM food_preferences WHERE food_name = 'fig_bar'
  );
UPDATE food_preferences SET food_name = 'fig_bar'
WHERE lower(food_name) = 'fig bar' AND food_name != 'fig_bar';

-- Water
DELETE FROM food_preferences
WHERE lower(food_name) = 'water'
  AND food_name != 'water'
  AND user_id IN (
    SELECT user_id FROM food_preferences WHERE food_name = 'water'
  );
UPDATE food_preferences SET food_name = 'water'
WHERE lower(food_name) = 'water' AND food_name != 'water';
