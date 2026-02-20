-- ============================================================================
-- Migration: Fix ALL Template Timing Windows & Meal Types
--
-- Purpose: Align ALL Supabase templates with Notion "Pre-workout formula by
--          Claude (v1)" source of truth. Fixes two systemic issues:
--
--   1. Invalid timing_window values: '30-60 min' and '1-2 hours' do NOT exist
--      in Notion or in the mealChain paradigm. Valid values are:
--        - '< 30 min'    (top_up)
--        - '30-90 min'   (snack)
--        - '1.5-3 hours' (full_meal)
--        - '3-4 hours'   (full_meal)
--
--   2. Wrong meal_type assignments: Several templates tagged as 'top_up' should
--      be 'snack', and several 'snack' templates should be 'full_meal'.
--
--   3. Incorrect 3-4 hour categorizations: Several templates at 3-4 hours
--      should be 1.5-3 hours per Notion (items without eggs/PB/protein powder).
--
-- Source: Notion database "Pre-workout formula by Claude (v1)"
--         collection://303e3fdb-754c-812a-959f-000bcc319a70
--
-- Templates already correct (13 of 41) — no changes:
--   energy-gel-water-a, applesauce-water, rice-banana-chocolate-milk,
--   oatmeal-eggs-toast-oj, energy-gel-water-b, energy-chews-water,
--   waffles-almond-butter-banana, pancakes-maple-syrup-eggs,
--   pasta-light-sauce-toast, rice-sweet-potato-eggs, applesauce-cup,
--   sports-drink-only, superhero-muffin-banana-coffee
--
-- Templates updated (28 of 41) — grouped below.
--
-- Date: 2026-02-13
-- ============================================================================

BEGIN;

-- ============================================================================
-- GROUP A: '30-60 min' / 'top_up' → '30-90 min' / 'snack'
--
-- These are all snack-level items (rice cakes, granola bars, fig bars, toast
-- combos, half-bagel) that belong in the 30-90 min window per Notion.
-- Notion references: Rice Cake + Honey = 30-90 min, Granola Bar = 30-90 min,
--                    Toast + Honey = 30-90 min
-- ============================================================================

UPDATE public.templates SET
  timing_window = '30-90 min',
  timing_min_minutes = 30,
  timing_max_minutes = 90,
  meal_type = 'snack'
WHERE slug IN (
  'bagel-half-banana-sports-drink',     -- Bagel (half) + Banana + Sports Drink (half bagel = light snack)
  'toast-honey-banana-water',           -- Toast + Honey + Banana + Water (Notion: Toast + Honey = 30-90 min)
  'rice-cakes-honey',                   -- Rice Cakes + Honey (Notion: Rice Cake + Honey = 30-90 min)
  'rice-cakes-banana-honey',            -- Rice Cakes + Banana + Honey (Notion: Rice Cake + Honey = 30-90 min)
  'granola-bar-banana-sports-drink',    -- Granola Bar + Banana + Sports Drink (Notion: Granola Bar = 30-90 min)
  'granola-bar-banana-oj',              -- Granola Bar + Banana + OJ (Notion: Granola Bar = 30-90 min)
  'fig-bars-banana-water',              -- Fig Bars + Banana + Water (snack-level items)
  'fig-bars',                           -- Fig Bars (snack-level)
  'graham-crackers-honey-banana'        -- Graham Crackers + Honey + Banana (snack-level)
);

-- ============================================================================
-- GROUP B: '30-60 min' / 'top_up' → '< 30 min' / 'top_up'
--
-- Orange Juice is a fast-digesting liquid that can be consumed < 30 min before.
-- ============================================================================

UPDATE public.templates SET
  timing_window = '< 30 min',
  timing_min_minutes = 0,
  timing_max_minutes = 30,
  meal_type = 'top_up'
WHERE slug IN (
  'orange-juice'                        -- Orange Juice (liquid, very fast digestion)
);

-- ============================================================================
-- GROUP C: '30-60 min' / 'top_up' → '1.5-3 hours' / 'full_meal'
--
-- Bagel with Jam is a dense bread item. Notion categorizes bagel combos at
-- 1.5-3 hours (e.g., Bagel + Butter + Honey = 1.5-3 hours).
-- ============================================================================

UPDATE public.templates SET
  timing_window = '1.5-3 hours',
  timing_min_minutes = 90,
  timing_max_minutes = 180,
  meal_type = 'full_meal'
WHERE slug IN (
  'bagel-with-jam'                      -- Bagel with Jam (Notion: bagels = 1.5-3 hours)
);

-- ============================================================================
-- GROUP D: '< 30 min' / 'top_up' → '30-90 min' / 'snack'
--
-- Graham crackers + banana need slightly more digestion time than gels/liquids.
-- ============================================================================

UPDATE public.templates SET
  timing_window = '30-90 min',
  timing_min_minutes = 30,
  timing_max_minutes = 90,
  meal_type = 'snack'
WHERE slug IN (
  'graham-crackers-banana-electrolyte'  -- Graham Crackers + Banana + Electrolyte Drink
);

-- ============================================================================
-- GROUP E: '1-2 hours' / 'snack' → '1.5-3 hours' / 'full_meal'
--
-- Per Notion, oatmeal, rice cake+PB, waffle+syrup, and cereal+milk combos
-- are all categorized at 1.5-3 hours. These are substantial enough to be
-- full meals.
-- Notion refs: Oatmeal + Banana = 1.5-3h, Rice Cake + PB + Banana = 1.5-3h,
--              Waffles + Syrup = 1.5-3h, Cereal + Milk = 1.5-3h
-- ============================================================================

UPDATE public.templates SET
  timing_window = '1.5-3 hours',
  timing_min_minutes = 90,
  timing_max_minutes = 180,
  meal_type = 'full_meal'
WHERE slug IN (
  'oatmeal-berries-water',             -- Oatmeal + Berries (Notion: oatmeal = 1.5-3 hours)
  'oatmeal-banana-honey',              -- Oatmeal + Banana + Honey (Notion: 1.5-3 hours)
  'rice-cakes-pb-banana-water',        -- Rice Cakes + PB + Banana (Notion: 1.5-3 hours)
  'waffles-maple-syrup',               -- Waffles + Maple Syrup (Notion: Waffles + Syrup = 1.5-3 hours)
  'cereal-milk-banana'                 -- Cereal + Milk + Banana (Notion: Cereal + Milk = 1.5-3 hours)
);

-- ============================================================================
-- GROUP F: '1-2 hours' / 'snack' → '30-90 min' / 'snack'
--
-- Lighter items that are quick-digesting: smoothies, rice cakes + honey,
-- and dried fruit are all 30-90 min in Notion.
-- Notion refs: Smoothie: Banana + Berries + Milk = 30-90 min,
--              Dates = 30-90 min, Rice Cake + Honey = 30-90 min
-- ============================================================================

UPDATE public.templates SET
  timing_window = '30-90 min',
  timing_min_minutes = 30,
  timing_max_minutes = 90,
  meal_type = 'snack'
WHERE slug IN (
  'smoothie-toast',                     -- Smoothie + Toast (Notion: smoothies = 30-90 min)
  'rice-cakes-honey-berries-water',     -- Rice Cakes + Honey + Berries (light snack, 30-90 min)
  'dried-fruit-mix'                     -- Dried Fruit Mix (Notion: dates = 30-90 min)
);

-- ============================================================================
-- GROUP G: '3-4 hours' / 'full_meal' → '1.5-3 hours' / 'full_meal'
--
-- Per Notion, these combos are all 1.5-3 hours because they lack the
-- slow-digesting elements (eggs, protein powder, heavy nut butters) that
-- push items to 3-4 hours:
--   - Yogurt + Granola = 1.5-3 hours
--   - Oatmeal + Blueberries = 1.5-3 hours
--   - Oatmeal + Banana (no eggs) = 1.5-3 hours
--   - Bagel + PB + Banana = 1.5-3 hours
--   - Pancakes + Syrup + Banana = 1.5-3 hours (vs Pancakes + Eggs = 3-4h)
--   - Cereal + Milk = 1.5-3 hours
-- ============================================================================

UPDATE public.templates SET
  timing_window = '1.5-3 hours',
  timing_min_minutes = 90,
  timing_max_minutes = 180,
  meal_type = 'full_meal'
WHERE slug IN (
  'greek-yogurt-granola-banana-honey',  -- Yogurt + Granola (Notion: 1.5-3 hours)
  'oatmeal-banana-toast-oj',            -- Oatmeal + Banana + Toast + OJ (Notion: oatmeal+banana = 1.5-3h, no eggs)
  'oatmeal-blueberries-honey-toast',    -- Oatmeal + Blueberries + Honey (Notion: 1.5-3 hours)
  'bagel-pb-banana-coffee-a',           -- Bagel + PB + Banana (Notion: 1.5-3 hours)
  'bagel-pb-banana-coffee-b',           -- Bagel + PB + Banana (Notion: 1.5-3 hours)
  'pancakes-syrup-banana-oj',           -- Pancakes + Syrup + Banana + OJ (Notion: Pancakes+Syrup+Banana = 1.5-3h)
  'cereal-milk-banana-toast',           -- Cereal + Milk + Banana + Toast (Notion: Cereal+Milk = 1.5-3h)
  'cereal-milk-toast-banana'            -- Cereal + Milk + Toast + Banana (Notion: Cereal+Milk = 1.5-3h)
);

-- ============================================================================
-- CATCH-ALL: Enforce timing_window → meal_type 1:1 mapping for ALL templates
--
-- This catches any templates NOT in the seed file (added separately) that
-- have a valid timing_window but wrong meal_type. The mapping is:
--   '< 30 min'    → 'top_up'
--   '30-90 min'   → 'snack'
--   '1.5-3 hours' → 'full_meal'
--   '3-4 hours'   → 'full_meal'
-- ============================================================================

UPDATE public.templates SET meal_type = 'top_up'
WHERE timing_window = '< 30 min' AND meal_type != 'top_up';

UPDATE public.templates SET meal_type = 'snack'
WHERE timing_window = '30-90 min' AND meal_type != 'snack';

UPDATE public.templates SET meal_type = 'full_meal'
WHERE timing_window = '1.5-3 hours' AND meal_type != 'full_meal';

UPDATE public.templates SET meal_type = 'full_meal'
WHERE timing_window = '3-4 hours' AND meal_type != 'full_meal';

-- ============================================================================
-- ALSO FIX: Any remaining invalid timing_window values
--
-- If any template still has '30-60 min' or '1-2 hours', remap them:
--   '30-60 min' → '30-90 min' / 'snack'
--   '1-2 hours' → '1.5-3 hours' / 'full_meal'
-- ============================================================================

UPDATE public.templates SET
  timing_window = '30-90 min',
  timing_min_minutes = 30,
  timing_max_minutes = 90,
  meal_type = 'snack'
WHERE timing_window = '30-60 min';

UPDATE public.templates SET
  timing_window = '1.5-3 hours',
  timing_min_minutes = 90,
  timing_max_minutes = 180,
  meal_type = 'full_meal'
WHERE timing_window = '1-2 hours';

-- ============================================================================
-- VERIFICATION: After migration, there should be ZERO rows with:
--   - timing_window NOT IN ('< 30 min', '30-90 min', '1.5-3 hours', '3-4 hours')
--   - meal_type mismatching its timing_window
-- ============================================================================

-- Uncomment to verify:
-- SELECT timing_window, meal_type, COUNT(*) as count
-- FROM public.templates
-- GROUP BY timing_window, meal_type
-- ORDER BY timing_window, meal_type;

-- Uncomment to find any remaining mismatches:
-- SELECT slug, name, timing_window, meal_type
-- FROM public.templates
-- WHERE (timing_window = '< 30 min' AND meal_type != 'top_up')
--    OR (timing_window = '30-90 min' AND meal_type != 'snack')
--    OR (timing_window IN ('1.5-3 hours', '3-4 hours') AND meal_type != 'full_meal')
--    OR timing_window NOT IN ('< 30 min', '30-90 min', '1.5-3 hours', '3-4 hours');

COMMIT;
