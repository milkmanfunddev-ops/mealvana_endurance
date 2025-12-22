-- Migration: Populate allergens and excluded_diets for existing foods
-- Date: 2024-12-14
-- Description: LLM-analyzed allergen and dietary exclusion data for all foods
--
-- Allergen values: dairy, eggs, fish, gluten, peanuts, sesame, shellfish, soy, tree_nuts
-- Diet values: vegetarian, pescatarian, vegan, mediterranean, paleo, keto, low_carb
--
-- Analysis criteria:
-- - Allergens: Only marked if food TYPICALLY contains the allergen
-- - Excluded diets: Marked if food should NOT be recommended for that diet
--   - vegan: contains ANY animal products
--   - paleo: contains grains, legumes, dairy, or processed sugars
--   - keto: >10g net carbs per typical serving
--   - low_carb: >20g carbs per typical serving

-- ============================================================================
-- FRUITS & VEGETABLES (generally allergen-free)
-- ============================================================================

-- Coffee - no allergens, all diets OK
UPDATE foods SET
  allergens = '{}',
  excluded_diets = '{}'
WHERE name = 'Coffee';

-- Apple - no allergens, high carb for keto
UPDATE foods SET
  allergens = '{}',
  excluded_diets = '{keto}'
WHERE name = 'Apple';

-- Berries - no allergens, low carb (keto-friendly)
UPDATE foods SET
  allergens = '{}',
  excluded_diets = '{}'
WHERE name = 'Berries';

-- Bananas - no allergens, high carb for strict keto
UPDATE foods SET
  allergens = '{}',
  excluded_diets = '{keto}'
WHERE name = 'Bananas';

-- Dates - no allergens, very high carb
UPDATE foods SET
  allergens = '{}',
  excluded_diets = '{keto,low_carb}'
WHERE name = 'Dates';

-- Orange juice - no allergens, high sugar/carb, processed (paleo)
UPDATE foods SET
  allergens = '{}',
  excluded_diets = '{keto,low_carb,paleo}'
WHERE name = 'Orange juice';

-- Coconut water - no allergens, moderate carbs (keto borderline)
UPDATE foods SET
  allergens = '{}',
  excluded_diets = '{keto}'
WHERE name = 'Coconut water';

-- ============================================================================
-- DAIRY PRODUCTS
-- ============================================================================

-- Yogurt - contains dairy
UPDATE foods SET
  allergens = '{dairy}',
  excluded_diets = '{vegan,paleo}'
WHERE name = 'Yogurt';

-- Chocolate milk - contains dairy, high carb
UPDATE foods SET
  allergens = '{dairy}',
  excluded_diets = '{vegan,paleo,keto,low_carb}'
WHERE name = 'Chocolate milk';

-- Protein powder (whey) - contains dairy (whey is milk protein)
UPDATE foods SET
  allergens = '{dairy}',
  excluded_diets = '{vegan,paleo}'
WHERE name = 'Protein powder (whey)';

-- Protein shake (ready-to-drink) - typically contains dairy and soy
UPDATE foods SET
  allergens = '{dairy,soy}',
  excluded_diets = '{vegan,paleo}'
WHERE name = 'Protein shake (ready-to-drink)';

-- ============================================================================
-- GRAIN-BASED PRODUCTS (contain gluten)
-- ============================================================================

-- Oatmeal - contains gluten (unless certified GF), grain-based
UPDATE foods SET
  allergens = '{gluten}',
  excluded_diets = '{paleo,keto,low_carb}'
WHERE name = 'Oatmeal';

-- Bagel (plain) - contains gluten, high carb
UPDATE foods SET
  allergens = '{gluten}',
  excluded_diets = '{paleo,keto,low_carb}'
WHERE name = 'Bagel (plain)';

-- Toast - contains gluten, high carb
UPDATE foods SET
  allergens = '{gluten}',
  excluded_diets = '{paleo,keto,low_carb}'
WHERE name = 'Toast';

-- Pretzels (salted minis) - contains gluten, high carb
UPDATE foods SET
  allergens = '{gluten}',
  excluded_diets = '{paleo,keto,low_carb}'
WHERE name = 'Pretzels (salted minis)';

-- Energy waffle (stroopwafel-style) - contains gluten, dairy, eggs
UPDATE foods SET
  allergens = '{gluten,dairy,eggs}',
  excluded_diets = '{vegan,paleo,keto,low_carb}'
WHERE name = 'Energy waffle (stroopwafel-style)';

-- Fig bar - contains gluten, high carb
UPDATE foods SET
  allergens = '{gluten}',
  excluded_diets = '{paleo,keto,low_carb}'
WHERE name = 'Fig bar';

-- ============================================================================
-- SPORTS NUTRITION PRODUCTS
-- ============================================================================

-- Gels - typically processed sugars, high carb
UPDATE foods SET
  allergens = '{}',
  excluded_diets = '{keto,low_carb,paleo}'
WHERE name = 'Gels';

-- Energy chews - typically processed sugars, high carb
UPDATE foods SET
  allergens = '{}',
  excluded_diets = '{keto,low_carb,paleo}'
WHERE name = 'Energy chews';

-- Energy bar - often contains gluten, high carb
UPDATE foods SET
  allergens = '{gluten}',
  excluded_diets = '{paleo,keto,low_carb}'
WHERE name = 'Energy bar';

-- Protein bar - often contains dairy, gluten, soy
UPDATE foods SET
  allergens = '{dairy,gluten,soy}',
  excluded_diets = '{vegan,paleo}'
WHERE name = 'Protein bar';

-- Sports drink (carb + electrolytes) - processed sugars, high carb
UPDATE foods SET
  allergens = '{}',
  excluded_diets = '{keto,low_carb,paleo}'
WHERE name = 'Sports drink (carb + electrolytes)';

-- Sports drink mix (carb + electrolytes) - processed sugars, high carb
UPDATE foods SET
  allergens = '{}',
  excluded_diets = '{keto,low_carb,paleo}'
WHERE name = 'Sports drink mix (carb + electrolytes)';

-- ============================================================================
-- ELECTROLYTE PRODUCTS (generally safe for all diets)
-- ============================================================================

-- Electrolyte drink mix (electrolyte-only) - no carbs, no allergens
UPDATE foods SET
  allergens = '{}',
  excluded_diets = '{}'
WHERE name = 'Electrolyte drink mix (electrolyte-only)';

-- Electrolyte tablet (electrolyte-only) - no carbs, no allergens
UPDATE foods SET
  allergens = '{}',
  excluded_diets = '{}'
WHERE name = 'Electrolyte tablet (electrolyte-only)';

-- Pickle juice shot - no allergens, low carb
UPDATE foods SET
  allergens = '{}',
  excluded_diets = '{}'
WHERE name = 'Pickle juice shot';

-- Salt Packet - no allergens, all diets OK
UPDATE foods SET
  allergens = '{}',
  excluded_diets = '{}'
WHERE name = 'Salt Packet';

-- Water - no allergens, all diets OK
UPDATE foods SET
  allergens = '{}',
  excluded_diets = '{}'
WHERE name = 'Water';

-- ============================================================================
-- NUT & SEED PRODUCTS
-- ============================================================================

-- Peanut butter - contains peanuts (legume, not paleo)
UPDATE foods SET
  allergens = '{peanuts}',
  excluded_diets = '{paleo}'
WHERE name = 'Peanut butter';

-- Trail mix - typically contains tree nuts and peanuts
UPDATE foods SET
  allergens = '{tree_nuts,peanuts}',
  excluded_diets = '{paleo}'
WHERE name = 'Trail mix';

-- ============================================================================
-- OTHER PRODUCTS
-- ============================================================================

-- Applesauce / fruit purée pouch - no allergens, high carb
UPDATE foods SET
  allergens = '{}',
  excluded_diets = '{keto,low_carb}'
WHERE name = 'Applesauce / fruit purée pouch';

-- ============================================================================
-- VERIFICATION QUERY (run after migration to verify)
-- ============================================================================
-- SELECT name, allergens, excluded_diets FROM foods ORDER BY name;
