-- ============================================================================
-- NORMALIZE FOOD PREFERENCES ON PROD (comprehensive)
-- ============================================================================
-- Run on: PRODUCTION Supabase SQL Editor (or via psql)
-- Purpose: Map legacy food_preferences.food_name values to template_foods names.
--
-- Strategy: For each mapping, a 2-step approach:
--   Step 1 DELETE: Remove old-name rows where EITHER:
--     (a) user already has the target new-name, OR
--     (b) user has multiple old-name variants (keep only one per user)
--   Step 2 UPDATE: Rename the single remaining old-name row per user.
--
-- This avoids unique constraint violations on idx_food_preferences_user_food.
-- Idempotent: Safe to re-run (only affects rows that haven't been renamed yet).
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. Energy gel: 'Gels', 'Energy gel', 'energy gel' → 'energy_gel'
-- ============================================================================
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

-- ============================================================================
-- 2. Energy chews: 'Energy chews', 'chews' → 'energy_chews'
-- ============================================================================
DELETE FROM food_preferences
WHERE lower(food_name) IN ('energy chews', 'chews')
  AND food_name != 'energy_chews'
  AND (
    user_id IN (SELECT user_id FROM food_preferences WHERE food_name = 'energy_chews')
    OR id NOT IN (
      SELECT DISTINCT ON (user_id) id
      FROM food_preferences
      WHERE lower(food_name) IN ('energy chews', 'chews') AND food_name != 'energy_chews'
      ORDER BY user_id, updated_at DESC
    )
  );
UPDATE food_preferences SET food_name = 'energy_chews'
WHERE lower(food_name) IN ('energy chews', 'chews') AND food_name != 'energy_chews';

-- ============================================================================
-- 3. Energy bar: 'Energy bar', 'Energy/Granola bar' → 'energy_bar'
-- ============================================================================
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

-- ============================================================================
-- 4. Sports drink: 'Sports drink (carb + electrolytes)', 'sports drink',
--    'Sports drink mix (carb + electrolytes)' → 'sports_drink'
-- ============================================================================
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

-- ============================================================================
-- 5. Coffee → 'coffee'
-- ============================================================================
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

-- ============================================================================
-- 6. Toast, White bread → 'white_bread'
-- ============================================================================
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

-- ============================================================================
-- 7. Banana, Bananas → 'banana'
-- ============================================================================
DELETE FROM food_preferences
WHERE lower(food_name) IN ('banana', 'bananas')
  AND food_name != 'banana'
  AND (
    user_id IN (SELECT user_id FROM food_preferences WHERE food_name = 'banana')
    OR id NOT IN (
      SELECT DISTINCT ON (user_id) id
      FROM food_preferences
      WHERE lower(food_name) IN ('banana', 'bananas') AND food_name != 'banana'
      ORDER BY user_id, updated_at DESC
    )
  );
UPDATE food_preferences SET food_name = 'banana'
WHERE lower(food_name) IN ('banana', 'bananas') AND food_name != 'banana';

-- ============================================================================
-- 8. Oatmeal → 'oatmeal_cooked'
-- ============================================================================
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

-- ============================================================================
-- 9. Orange juice → 'orange_juice'
-- ============================================================================
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

-- ============================================================================
-- 10. Peanut butter → 'peanut_butter'
-- ============================================================================
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

-- ============================================================================
-- 11. Dates → 'dates'
-- ============================================================================
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

-- ============================================================================
-- 12. Pretzels (salted minis) → 'pretzels'
-- ============================================================================
DELETE FROM food_preferences
WHERE lower(food_name) IN ('pretzels (salted minis)')
  AND food_name != 'pretzels'
  AND (
    user_id IN (SELECT user_id FROM food_preferences WHERE food_name = 'pretzels')
    OR id NOT IN (
      SELECT DISTINCT ON (user_id) id
      FROM food_preferences
      WHERE lower(food_name) IN ('pretzels (salted minis)') AND food_name != 'pretzels'
      ORDER BY user_id, updated_at DESC
    )
  );
UPDATE food_preferences SET food_name = 'pretzels'
WHERE lower(food_name) IN ('pretzels (salted minis)') AND food_name != 'pretzels';

-- ============================================================================
-- 13. Chocolate milk → 'chocolate_milk'
-- ============================================================================
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

-- ============================================================================
-- 14. Coconut water → 'coconut_water'
-- ============================================================================
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

-- ============================================================================
-- 15. Protein bar → 'protein_bar'
-- ============================================================================
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

-- ============================================================================
-- 16. Protein shake (ready-to-drink) → 'protein_shake'
-- ============================================================================
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

-- ============================================================================
-- 17. Electrolyte tablet (electrolyte-only) → 'electrolyte_tablet'
-- ============================================================================
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

-- ============================================================================
-- 18. Electrolyte drink mix (electrolyte-only) → 'electrolyte_drink'
--     (matches DEV naming convention)
-- ============================================================================
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

-- ============================================================================
-- 19. Fig bar → 'fig_bar'
-- ============================================================================
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

-- ============================================================================
-- 20. Water → 'water'
-- ============================================================================
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

-- ============================================================================
-- 21. Apple → 'apple' (NEW - not in original script)
-- ============================================================================
DELETE FROM food_preferences
WHERE lower(food_name) = 'apple'
  AND food_name != 'apple'
  AND (
    user_id IN (SELECT user_id FROM food_preferences WHERE food_name = 'apple')
    OR id NOT IN (
      SELECT DISTINCT ON (user_id) id
      FROM food_preferences
      WHERE lower(food_name) = 'apple' AND food_name != 'apple'
      ORDER BY user_id, updated_at DESC
    )
  );
UPDATE food_preferences SET food_name = 'apple'
WHERE lower(food_name) = 'apple' AND food_name != 'apple';

-- ============================================================================
-- 22. Applesauce / fruit purée pouch → 'applesauce_pouch' (NEW)
-- ============================================================================
DELETE FROM food_preferences
WHERE lower(food_name) LIKE 'applesauce%'
  AND food_name != 'applesauce_pouch'
  AND (
    user_id IN (SELECT user_id FROM food_preferences WHERE food_name = 'applesauce_pouch')
    OR id NOT IN (
      SELECT DISTINCT ON (user_id) id
      FROM food_preferences
      WHERE lower(food_name) LIKE 'applesauce%' AND food_name != 'applesauce_pouch'
      ORDER BY user_id, updated_at DESC
    )
  );
UPDATE food_preferences SET food_name = 'applesauce_pouch'
WHERE lower(food_name) LIKE 'applesauce%' AND food_name != 'applesauce_pouch';

-- ============================================================================
-- 23. Bagel (plain) → 'bagel' (NEW)
-- ============================================================================
DELETE FROM food_preferences
WHERE lower(food_name) LIKE 'bagel%'
  AND food_name != 'bagel'
  AND (
    user_id IN (SELECT user_id FROM food_preferences WHERE food_name = 'bagel')
    OR id NOT IN (
      SELECT DISTINCT ON (user_id) id
      FROM food_preferences
      WHERE lower(food_name) LIKE 'bagel%' AND food_name != 'bagel'
      ORDER BY user_id, updated_at DESC
    )
  );
UPDATE food_preferences SET food_name = 'bagel'
WHERE lower(food_name) LIKE 'bagel%' AND food_name != 'bagel';

-- ============================================================================
-- 24. Berries → 'mixed_berries' (NEW)
-- ============================================================================
DELETE FROM food_preferences
WHERE lower(food_name) = 'berries'
  AND food_name != 'mixed_berries'
  AND (
    user_id IN (SELECT user_id FROM food_preferences WHERE food_name = 'mixed_berries')
    OR id NOT IN (
      SELECT DISTINCT ON (user_id) id
      FROM food_preferences
      WHERE lower(food_name) = 'berries' AND food_name != 'mixed_berries'
      ORDER BY user_id, updated_at DESC
    )
  );
UPDATE food_preferences SET food_name = 'mixed_berries'
WHERE lower(food_name) = 'berries' AND food_name != 'mixed_berries';

-- ============================================================================
-- 25. Energy waffle (stroopwafel-style) → 'stroopwafel' (NEW)
-- ============================================================================
DELETE FROM food_preferences
WHERE lower(food_name) LIKE 'energy waffle%'
  AND food_name != 'stroopwafel'
  AND (
    user_id IN (SELECT user_id FROM food_preferences WHERE food_name = 'stroopwafel')
    OR id NOT IN (
      SELECT DISTINCT ON (user_id) id
      FROM food_preferences
      WHERE lower(food_name) LIKE 'energy waffle%' AND food_name != 'stroopwafel'
      ORDER BY user_id, updated_at DESC
    )
  );
UPDATE food_preferences SET food_name = 'stroopwafel'
WHERE lower(food_name) LIKE 'energy waffle%' AND food_name != 'stroopwafel';

-- ============================================================================
-- 26. Pickle juice shot → 'pickle_juice_shot' (NEW)
-- ============================================================================
DELETE FROM food_preferences
WHERE lower(food_name) = 'pickle juice shot'
  AND food_name != 'pickle_juice_shot'
  AND (
    user_id IN (SELECT user_id FROM food_preferences WHERE food_name = 'pickle_juice_shot')
    OR id NOT IN (
      SELECT DISTINCT ON (user_id) id
      FROM food_preferences
      WHERE lower(food_name) = 'pickle juice shot' AND food_name != 'pickle_juice_shot'
      ORDER BY user_id, updated_at DESC
    )
  );
UPDATE food_preferences SET food_name = 'pickle_juice_shot'
WHERE lower(food_name) = 'pickle juice shot' AND food_name != 'pickle_juice_shot';

-- ============================================================================
-- 27. Protein powder (whey) → 'protein_powder' (NEW)
-- ============================================================================
DELETE FROM food_preferences
WHERE lower(food_name) LIKE 'protein powder%'
  AND food_name != 'protein_powder'
  AND (
    user_id IN (SELECT user_id FROM food_preferences WHERE food_name = 'protein_powder')
    OR id NOT IN (
      SELECT DISTINCT ON (user_id) id
      FROM food_preferences
      WHERE lower(food_name) LIKE 'protein powder%' AND food_name != 'protein_powder'
      ORDER BY user_id, updated_at DESC
    )
  );
UPDATE food_preferences SET food_name = 'protein_powder'
WHERE lower(food_name) LIKE 'protein powder%' AND food_name != 'protein_powder';

-- ============================================================================
-- 28. Trail mix → 'trail_mix' (NEW)
-- ============================================================================
DELETE FROM food_preferences
WHERE lower(food_name) = 'trail mix'
  AND food_name != 'trail_mix'
  AND (
    user_id IN (SELECT user_id FROM food_preferences WHERE food_name = 'trail_mix')
    OR id NOT IN (
      SELECT DISTINCT ON (user_id) id
      FROM food_preferences
      WHERE lower(food_name) = 'trail mix' AND food_name != 'trail_mix'
      ORDER BY user_id, updated_at DESC
    )
  );
UPDATE food_preferences SET food_name = 'trail_mix'
WHERE lower(food_name) = 'trail mix' AND food_name != 'trail_mix';

-- ============================================================================
-- 29. Yogurt → 'yogurt' (NEW)
-- ============================================================================
DELETE FROM food_preferences
WHERE lower(food_name) = 'yogurt'
  AND food_name != 'yogurt'
  AND (
    user_id IN (SELECT user_id FROM food_preferences WHERE food_name = 'yogurt')
    OR id NOT IN (
      SELECT DISTINCT ON (user_id) id
      FROM food_preferences
      WHERE lower(food_name) = 'yogurt' AND food_name != 'yogurt'
      ORDER BY user_id, updated_at DESC
    )
  );
UPDATE food_preferences SET food_name = 'yogurt'
WHERE lower(food_name) = 'yogurt' AND food_name != 'yogurt';

COMMIT;
