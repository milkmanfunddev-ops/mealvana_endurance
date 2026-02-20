-- ============================================================================
-- Migration: Normalize Food Preference Names
--
-- Purpose: Map food_preferences.food_name from legacy `foods` table names
-- (mixed case, various formats) to `template_foods` names (consistent snake_case).
--
-- Strategy: For each mapping, a 2-step approach:
--   Step 1 DELETE: Remove old-name rows where EITHER:
--     (a) user already has the target new-name, OR
--     (b) user has multiple old-name variants (keep only one per user)
--   Step 2 UPDATE: Rename the single remaining old-name row per user.
--
-- This avoids unique constraint violations on idx_food_preferences_user_food.
--
-- Date: 2026-02-20
-- ============================================================================

-- Energy gel (foods uses 'Gels' or 'Energy gel')
DELETE FROM food_preferences
WHERE lower(food_name) IN ('gels', 'energy gel')
  AND food_name != 'energy_gel'
  AND (
    user_id IN (SELECT user_id FROM food_preferences WHERE food_name = 'energy_gel')
    OR id NOT IN (
      SELECT DISTINCT ON (user_id) id
      FROM food_preferences
      WHERE lower(food_name) IN ('gels', 'energy gel') AND food_name != 'energy_gel'
      ORDER BY user_id, updated_at DESC
    )
  );
UPDATE food_preferences SET food_name = 'energy_gel'
WHERE lower(food_name) IN ('gels', 'energy gel') AND food_name != 'energy_gel';

-- Energy chews
DELETE FROM food_preferences
WHERE lower(food_name) = 'energy chews'
  AND food_name != 'energy_chews'
  AND (
    user_id IN (SELECT user_id FROM food_preferences WHERE food_name = 'energy_chews')
    OR id NOT IN (
      SELECT DISTINCT ON (user_id) id
      FROM food_preferences
      WHERE lower(food_name) = 'energy chews' AND food_name != 'energy_chews'
      ORDER BY user_id, updated_at DESC
    )
  );
UPDATE food_preferences SET food_name = 'energy_chews'
WHERE lower(food_name) = 'energy chews' AND food_name != 'energy_chews';

-- Energy bar
DELETE FROM food_preferences
WHERE lower(food_name) IN ('energy bar', 'energy/granola bar')
  AND food_name != 'energy_bar'
  AND (
    user_id IN (SELECT user_id FROM food_preferences WHERE food_name = 'energy_bar')
    OR id NOT IN (
      SELECT DISTINCT ON (user_id) id
      FROM food_preferences
      WHERE lower(food_name) IN ('energy bar', 'energy/granola bar') AND food_name != 'energy_bar'
      ORDER BY user_id, updated_at DESC
    )
  );
UPDATE food_preferences SET food_name = 'energy_bar'
WHERE lower(food_name) IN ('energy bar', 'energy/granola bar') AND food_name != 'energy_bar';

-- Sports drink
DELETE FROM food_preferences
WHERE lower(food_name) IN ('sports drink (carb + electrolytes)', 'sports drink', 'sports drink mix (carb + electrolytes)')
  AND food_name != 'sports_drink'
  AND (
    user_id IN (SELECT user_id FROM food_preferences WHERE food_name = 'sports_drink')
    OR id NOT IN (
      SELECT DISTINCT ON (user_id) id
      FROM food_preferences
      WHERE lower(food_name) IN ('sports drink (carb + electrolytes)', 'sports drink', 'sports drink mix (carb + electrolytes)') AND food_name != 'sports_drink'
      ORDER BY user_id, updated_at DESC
    )
  );
UPDATE food_preferences SET food_name = 'sports_drink'
WHERE lower(food_name) IN ('sports drink (carb + electrolytes)', 'sports drink', 'sports drink mix (carb + electrolytes)') AND food_name != 'sports_drink';

-- Coffee
DELETE FROM food_preferences
WHERE lower(food_name) = 'coffee'
  AND food_name != 'coffee'
  AND (
    user_id IN (SELECT user_id FROM food_preferences WHERE food_name = 'coffee')
    OR id NOT IN (
      SELECT DISTINCT ON (user_id) id
      FROM food_preferences
      WHERE lower(food_name) = 'coffee' AND food_name != 'coffee'
      ORDER BY user_id, updated_at DESC
    )
  );
UPDATE food_preferences SET food_name = 'coffee'
WHERE lower(food_name) = 'coffee' AND food_name != 'coffee';

-- Toast / White bread
DELETE FROM food_preferences
WHERE lower(food_name) IN ('toast', 'white bread')
  AND food_name != 'white_bread'
  AND (
    user_id IN (SELECT user_id FROM food_preferences WHERE food_name = 'white_bread')
    OR id NOT IN (
      SELECT DISTINCT ON (user_id) id
      FROM food_preferences
      WHERE lower(food_name) IN ('toast', 'white bread') AND food_name != 'white_bread'
      ORDER BY user_id, updated_at DESC
    )
  );
UPDATE food_preferences SET food_name = 'white_bread'
WHERE lower(food_name) IN ('toast', 'white bread') AND food_name != 'white_bread';

-- Banana
DELETE FROM food_preferences
WHERE lower(food_name) = 'banana'
  AND food_name != 'banana'
  AND (
    user_id IN (SELECT user_id FROM food_preferences WHERE food_name = 'banana')
    OR id NOT IN (
      SELECT DISTINCT ON (user_id) id
      FROM food_preferences
      WHERE lower(food_name) = 'banana' AND food_name != 'banana'
      ORDER BY user_id, updated_at DESC
    )
  );
UPDATE food_preferences SET food_name = 'banana'
WHERE lower(food_name) = 'banana' AND food_name != 'banana';

-- Oatmeal
DELETE FROM food_preferences
WHERE lower(food_name) IN ('oatmeal', 'oatmeal (cooked)')
  AND food_name != 'oatmeal_cooked'
  AND (
    user_id IN (SELECT user_id FROM food_preferences WHERE food_name = 'oatmeal_cooked')
    OR id NOT IN (
      SELECT DISTINCT ON (user_id) id
      FROM food_preferences
      WHERE lower(food_name) IN ('oatmeal', 'oatmeal (cooked)') AND food_name != 'oatmeal_cooked'
      ORDER BY user_id, updated_at DESC
    )
  );
UPDATE food_preferences SET food_name = 'oatmeal_cooked'
WHERE lower(food_name) IN ('oatmeal', 'oatmeal (cooked)') AND food_name != 'oatmeal_cooked';

-- Orange juice
DELETE FROM food_preferences
WHERE lower(food_name) = 'orange juice'
  AND food_name != 'orange_juice'
  AND (
    user_id IN (SELECT user_id FROM food_preferences WHERE food_name = 'orange_juice')
    OR id NOT IN (
      SELECT DISTINCT ON (user_id) id
      FROM food_preferences
      WHERE lower(food_name) = 'orange juice' AND food_name != 'orange_juice'
      ORDER BY user_id, updated_at DESC
    )
  );
UPDATE food_preferences SET food_name = 'orange_juice'
WHERE lower(food_name) = 'orange juice' AND food_name != 'orange_juice';

-- Peanut butter
DELETE FROM food_preferences
WHERE lower(food_name) = 'peanut butter'
  AND food_name != 'peanut_butter'
  AND (
    user_id IN (SELECT user_id FROM food_preferences WHERE food_name = 'peanut_butter')
    OR id NOT IN (
      SELECT DISTINCT ON (user_id) id
      FROM food_preferences
      WHERE lower(food_name) = 'peanut butter' AND food_name != 'peanut_butter'
      ORDER BY user_id, updated_at DESC
    )
  );
UPDATE food_preferences SET food_name = 'peanut_butter'
WHERE lower(food_name) = 'peanut butter' AND food_name != 'peanut_butter';

-- Dates
DELETE FROM food_preferences
WHERE lower(food_name) = 'dates'
  AND food_name != 'dates'
  AND (
    user_id IN (SELECT user_id FROM food_preferences WHERE food_name = 'dates')
    OR id NOT IN (
      SELECT DISTINCT ON (user_id) id
      FROM food_preferences
      WHERE lower(food_name) = 'dates' AND food_name != 'dates'
      ORDER BY user_id, updated_at DESC
    )
  );
UPDATE food_preferences SET food_name = 'dates'
WHERE lower(food_name) = 'dates' AND food_name != 'dates';

-- Pretzels
DELETE FROM food_preferences
WHERE lower(food_name) IN ('pretzels', 'pretzels (salted minis)')
  AND food_name != 'pretzels'
  AND (
    user_id IN (SELECT user_id FROM food_preferences WHERE food_name = 'pretzels')
    OR id NOT IN (
      SELECT DISTINCT ON (user_id) id
      FROM food_preferences
      WHERE lower(food_name) IN ('pretzels', 'pretzels (salted minis)') AND food_name != 'pretzels'
      ORDER BY user_id, updated_at DESC
    )
  );
UPDATE food_preferences SET food_name = 'pretzels'
WHERE lower(food_name) IN ('pretzels', 'pretzels (salted minis)') AND food_name != 'pretzels';

-- Chocolate milk
DELETE FROM food_preferences
WHERE lower(food_name) = 'chocolate milk'
  AND food_name != 'chocolate_milk'
  AND (
    user_id IN (SELECT user_id FROM food_preferences WHERE food_name = 'chocolate_milk')
    OR id NOT IN (
      SELECT DISTINCT ON (user_id) id
      FROM food_preferences
      WHERE lower(food_name) = 'chocolate milk' AND food_name != 'chocolate_milk'
      ORDER BY user_id, updated_at DESC
    )
  );
UPDATE food_preferences SET food_name = 'chocolate_milk'
WHERE lower(food_name) = 'chocolate milk' AND food_name != 'chocolate_milk';

-- Coconut water
DELETE FROM food_preferences
WHERE lower(food_name) = 'coconut water'
  AND food_name != 'coconut_water'
  AND (
    user_id IN (SELECT user_id FROM food_preferences WHERE food_name = 'coconut_water')
    OR id NOT IN (
      SELECT DISTINCT ON (user_id) id
      FROM food_preferences
      WHERE lower(food_name) = 'coconut water' AND food_name != 'coconut_water'
      ORDER BY user_id, updated_at DESC
    )
  );
UPDATE food_preferences SET food_name = 'coconut_water'
WHERE lower(food_name) = 'coconut water' AND food_name != 'coconut_water';

-- Protein bar
DELETE FROM food_preferences
WHERE lower(food_name) = 'protein bar'
  AND food_name != 'protein_bar'
  AND (
    user_id IN (SELECT user_id FROM food_preferences WHERE food_name = 'protein_bar')
    OR id NOT IN (
      SELECT DISTINCT ON (user_id) id
      FROM food_preferences
      WHERE lower(food_name) = 'protein bar' AND food_name != 'protein_bar'
      ORDER BY user_id, updated_at DESC
    )
  );
UPDATE food_preferences SET food_name = 'protein_bar'
WHERE lower(food_name) = 'protein bar' AND food_name != 'protein_bar';

-- Protein shake
DELETE FROM food_preferences
WHERE lower(food_name) IN ('protein shake', 'protein shake (ready-to-drink)')
  AND food_name != 'protein_shake'
  AND (
    user_id IN (SELECT user_id FROM food_preferences WHERE food_name = 'protein_shake')
    OR id NOT IN (
      SELECT DISTINCT ON (user_id) id
      FROM food_preferences
      WHERE lower(food_name) IN ('protein shake', 'protein shake (ready-to-drink)') AND food_name != 'protein_shake'
      ORDER BY user_id, updated_at DESC
    )
  );
UPDATE food_preferences SET food_name = 'protein_shake'
WHERE lower(food_name) IN ('protein shake', 'protein shake (ready-to-drink)') AND food_name != 'protein_shake';

-- Electrolyte tablet
DELETE FROM food_preferences
WHERE lower(food_name) IN ('electrolyte tablet', 'electrolyte tablet (electrolyte-only)')
  AND food_name != 'electrolyte_tablet'
  AND (
    user_id IN (SELECT user_id FROM food_preferences WHERE food_name = 'electrolyte_tablet')
    OR id NOT IN (
      SELECT DISTINCT ON (user_id) id
      FROM food_preferences
      WHERE lower(food_name) IN ('electrolyte tablet', 'electrolyte tablet (electrolyte-only)') AND food_name != 'electrolyte_tablet'
      ORDER BY user_id, updated_at DESC
    )
  );
UPDATE food_preferences SET food_name = 'electrolyte_tablet'
WHERE lower(food_name) IN ('electrolyte tablet', 'electrolyte tablet (electrolyte-only)') AND food_name != 'electrolyte_tablet';

-- Electrolyte drink mix
DELETE FROM food_preferences
WHERE lower(food_name) IN ('electrolyte drink mix', 'electrolyte drink mix (electrolyte-only)')
  AND food_name != 'electrolyte_drink'
  AND (
    user_id IN (SELECT user_id FROM food_preferences WHERE food_name = 'electrolyte_drink')
    OR id NOT IN (
      SELECT DISTINCT ON (user_id) id
      FROM food_preferences
      WHERE lower(food_name) IN ('electrolyte drink mix', 'electrolyte drink mix (electrolyte-only)') AND food_name != 'electrolyte_drink'
      ORDER BY user_id, updated_at DESC
    )
  );
UPDATE food_preferences SET food_name = 'electrolyte_drink'
WHERE lower(food_name) IN ('electrolyte drink mix', 'electrolyte drink mix (electrolyte-only)') AND food_name != 'electrolyte_drink';

-- Fig bar
DELETE FROM food_preferences
WHERE lower(food_name) = 'fig bar'
  AND food_name != 'fig_bar'
  AND (
    user_id IN (SELECT user_id FROM food_preferences WHERE food_name = 'fig_bar')
    OR id NOT IN (
      SELECT DISTINCT ON (user_id) id
      FROM food_preferences
      WHERE lower(food_name) = 'fig bar' AND food_name != 'fig_bar'
      ORDER BY user_id, updated_at DESC
    )
  );
UPDATE food_preferences SET food_name = 'fig_bar'
WHERE lower(food_name) = 'fig bar' AND food_name != 'fig_bar';

-- Water
DELETE FROM food_preferences
WHERE lower(food_name) = 'water'
  AND food_name != 'water'
  AND (
    user_id IN (SELECT user_id FROM food_preferences WHERE food_name = 'water')
    OR id NOT IN (
      SELECT DISTINCT ON (user_id) id
      FROM food_preferences
      WHERE lower(food_name) = 'water' AND food_name != 'water'
      ORDER BY user_id, updated_at DESC
    )
  );
UPDATE food_preferences SET food_name = 'water'
WHERE lower(food_name) = 'water' AND food_name != 'water';
