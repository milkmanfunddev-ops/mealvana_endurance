-- ============================================================================
-- Migration: Post-workout templates v2 — Notion import
--
-- Imports the 21 post-workout templates from the Notion "Post-workout formula
-- by Claude (v1)" database, and brings post-workout template parity with the
-- pre-workout and during-workout template systems.
--
-- Schema additions to post_workout_templates:
--   travel_friendliness  (in_bag | cooler_friendly | home_only)
--   flavor_profile       (sweet_creamy | sweet_crunchy | savory_salty
--                          | warm_comforting | mixed)
--   prep_effort          (grab_and_go | assemble | cook)
--   protein_anchor       (whey_shake | plant_shake | yogurt | cottage_cheese
--                          | chocolate_milk | smoothie | egg | nut_butter
--                          | deli_cheese)
--   carb_sources         TEXT[]   (subset of Notion Carb Sources, snake_case)
--   portions             TEXT      (human-readable portion description)
--   selection_priority   INTEGER   (tie breaker for template selection)
--
-- Existing columns recovery_window / recovery_type / workout_intensity are
-- made nullable so the new Notion templates (which don't carry those concepts)
-- can be inserted alongside the old shape if anyone re-runs prior migrations.
--
-- Source: https://www.notion.so/2f5dd41a5cd648fcb47d0a01c5416203
-- Date:   2026-05-18
-- ============================================================================


-- ============================================================================
-- STEP 1 — Create post_workout_templates if it doesn't exist, then add the
-- new Notion-driven columns. Idempotent: safe to re-run.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.post_workout_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_number INTEGER NOT NULL UNIQUE,
  name TEXT NOT NULL,
  formula TEXT NOT NULL,
  recovery_window TEXT,
  recovery_type TEXT,
  activity_types TEXT[] NOT NULL DEFAULT '{}',
  workout_intensity TEXT[] NOT NULL DEFAULT '{}',
  component_food_names TEXT[] NOT NULL DEFAULT '{}',
  component_ratios JSONB,
  target_carb_protein_ratio TEXT,
  allergens TEXT[] NOT NULL DEFAULT '{}',
  excluded_diets TEXT[] NOT NULL DEFAULT '{}',
  notes TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Drop NOT NULL on legacy columns if a prior shape had them
ALTER TABLE public.post_workout_templates
  ALTER COLUMN recovery_window DROP NOT NULL;
ALTER TABLE public.post_workout_templates
  ALTER COLUMN recovery_type DROP NOT NULL;

-- default_servings JSONB: servings count per food name for the canonical
-- portion. Single shared portion for all athletes — no body-size scaling
-- (matches the new "30-60 min recovery trigger" algorithm).
ALTER TABLE public.post_workout_templates
  ADD COLUMN IF NOT EXISTS default_servings JSONB NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE public.post_workout_templates
  ADD COLUMN IF NOT EXISTS travel_friendliness TEXT
    CHECK (travel_friendliness IS NULL OR travel_friendliness IN
      ('in_bag', 'cooler_friendly', 'home_only')),
  ADD COLUMN IF NOT EXISTS flavor_profile TEXT
    CHECK (flavor_profile IS NULL OR flavor_profile IN
      ('sweet_creamy', 'sweet_crunchy', 'savory_salty',
       'warm_comforting', 'mixed')),
  ADD COLUMN IF NOT EXISTS prep_effort TEXT
    CHECK (prep_effort IS NULL OR prep_effort IN
      ('grab_and_go', 'assemble', 'cook')),
  ADD COLUMN IF NOT EXISTS protein_anchor TEXT
    CHECK (protein_anchor IS NULL OR protein_anchor IN
      ('whey_shake', 'plant_shake', 'yogurt', 'cottage_cheese',
       'chocolate_milk', 'smoothie', 'egg', 'nut_butter', 'deli_cheese')),
  ADD COLUMN IF NOT EXISTS carb_sources TEXT[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS portions TEXT,
  ADD COLUMN IF NOT EXISTS selection_priority INTEGER NOT NULL DEFAULT 0;

-- Indexes used by the loader / selection priority
CREATE INDEX IF NOT EXISTS idx_pwt_active
  ON public.post_workout_templates (is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_pwt_activity_types
  ON public.post_workout_templates USING GIN (activity_types);
CREATE INDEX IF NOT EXISTS idx_pwt_template_number
  ON public.post_workout_templates (template_number);

-- RLS: public read, service_role write (mirrors during_workout_templates)
ALTER TABLE public.post_workout_templates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "post_workout_templates_select"
  ON public.post_workout_templates;
DROP POLICY IF EXISTS "post_workout_templates_insert_service"
  ON public.post_workout_templates;
DROP POLICY IF EXISTS "post_workout_templates_update_service"
  ON public.post_workout_templates;
DROP POLICY IF EXISTS "post_workout_templates_delete_service"
  ON public.post_workout_templates;

CREATE POLICY "post_workout_templates_select"
  ON public.post_workout_templates FOR SELECT USING (true);
CREATE POLICY "post_workout_templates_insert_service"
  ON public.post_workout_templates FOR INSERT
  WITH CHECK (auth.role() = 'service_role');
CREATE POLICY "post_workout_templates_update_service"
  ON public.post_workout_templates FOR UPDATE
  USING (auth.role() = 'service_role');
CREATE POLICY "post_workout_templates_delete_service"
  ON public.post_workout_templates FOR DELETE
  USING (auth.role() = 'service_role');

COMMENT ON COLUMN public.post_workout_templates.travel_friendliness IS
  'Where the template can be eaten: in_bag (shelf stable), cooler_friendly, or home_only.';
COMMENT ON COLUMN public.post_workout_templates.flavor_profile IS
  'Sensory dimension used for re-rolls and personalization.';
COMMENT ON COLUMN public.post_workout_templates.prep_effort IS
  'How much work the athlete has to do once they get to the food.';
COMMENT ON COLUMN public.post_workout_templates.protein_anchor IS
  'Primary protein category, mirrors the Notion taxonomy.';
COMMENT ON COLUMN public.post_workout_templates.carb_sources IS
  'Carb source tags (snake_case subset of Notion carb sources).';
COMMENT ON COLUMN public.post_workout_templates.portions IS
  'Human-readable portion description shown to the athlete.';
COMMENT ON COLUMN public.post_workout_templates.selection_priority IS
  'Tie breaker for template selection. Higher = preferred when scores tie.';

CREATE INDEX IF NOT EXISTS idx_pwt_protein_anchor
  ON public.post_workout_templates (protein_anchor);
CREATE INDEX IF NOT EXISTS idx_pwt_flavor_profile
  ON public.post_workout_templates (flavor_profile);


-- ============================================================================
-- STEP 2 — Make sure all foods the new templates reference exist
--
-- Idempotent: ON CONFLICT(name) DO NOTHING preserves prior rows.
-- Nutrition values are USDA-aligned, sized for typical post-workout portions.
-- ============================================================================

INSERT INTO public.template_foods (
  name, display_name, display_name_plural, serving_size, serving_weight_g,
  calories, carbs_g, protein_g, fat_g, fiber_g, sodium_mg, fluid_ml,
  allergens, digestion_speed, is_active,
  excluded_diets, product_type, activity_types, categories,
  show_in_preferences, is_essential, is_electrolyte, requires_preparation,
  caffeine_mg, potassium_mg, is_drink_pool, drink_pool_phases, is_liquid,
  max_servings_before, max_servings_during, max_servings_after,
  to_exclude_from_solver, is_indivisible, default_during, min_servings_during,
  serving_amount, serving_unit, description
)
VALUES
  -- ===== Foundational post-workout foods (carry-overs from prior unapplied
  --       seed migrations 20260408100000 / pre-dev-bootstrap) =====
  ('whey_protein_powder', 'Whey Protein Powder', 'scoops Whey Protein Powder',
   '1 scoop (30g)', 30.0,
   120, 3.0, 25.0, 1.5, 0.0, 130.0, 0.0,
   '{dairy}'::text[], 'fast', TRUE,
   '{vegan}'::text[], 'supplement', '{running,cycling,swimming}'::text[], '{after_run}'::text[],
   TRUE, FALSE, FALSE, TRUE, 0.0, 160.0,
   FALSE, '{}'::text[], FALSE,
   0, 0, 2, FALSE, TRUE, FALSE, 0,
   1, 'scoop', 'Whey protein isolate/concentrate. ~3g leucine per scoop.'),

  ('plant_protein_powder', 'Plant Protein Powder', 'scoops Plant Protein Powder',
   '1 scoop (35g)', 35.0,
   130, 5.0, 22.0, 2.5, 2.0, 300.0, 0.0,
   '{}'::text[], 'medium', TRUE,
   '{paleo}'::text[], 'supplement', '{running,cycling,swimming}'::text[], '{after_run}'::text[],
   TRUE, FALSE, FALSE, TRUE, 0.0, 120.0,
   FALSE, '{}'::text[], FALSE,
   0, 0, 2, FALSE, TRUE, FALSE, 0,
   1, 'scoop', 'Pea + rice protein blend. Complete amino acid profile.'),

  ('greek_yogurt', 'Greek Yogurt', 'cups Greek Yogurt',
   '1 cup (245g)', 245.0,
   130, 9.0, 23.0, 0.7, 0.0, 65.0, 200.0,
   '{dairy}'::text[], 'medium', TRUE,
   '{vegan}'::text[], 'whole_food', '{running,cycling,swimming}'::text[], '{after_run}'::text[],
   TRUE, FALSE, FALSE, FALSE, 0.0, 240.0,
   FALSE, '{}'::text[], FALSE,
   0, 0, 2, FALSE, FALSE, FALSE, 0,
   1, 'cup', 'Non-fat plain Greek yogurt. High protein (~23g/cup), leucine-rich.'),

  ('whole_wheat_bread', 'Whole Wheat Bread', 'slices Whole Wheat Bread',
   '2 slices (60g)', 60.0,
   160, 28.0, 8.0, 2.0, 4.0, 280.0, 0.0,
   '{gluten}'::text[], 'medium', TRUE,
   '{paleo}'::text[], 'whole_food', '{running,cycling,swimming}'::text[], '{after_run,before_run}'::text[],
   TRUE, FALSE, FALSE, FALSE, 0.0, 130.0,
   FALSE, '{}'::text[], FALSE,
   2, 0, 4, FALSE, TRUE, FALSE, 0,
   2, 'slices', 'Whole wheat sandwich bread. Solid carb base with fiber.'),

  ('bagel_large', 'Bagel (Large)', 'large bagels',
   '1 large bagel (95g)', 95.0,
   280, 56.0, 11.0, 1.5, 2.0, 460.0, 0.0,
   '{gluten}'::text[], 'medium', TRUE,
   '{paleo}'::text[], 'whole_food', '{running,cycling,swimming}'::text[], '{after_run,before_run}'::text[],
   TRUE, FALSE, FALSE, FALSE, 0.0, 100.0,
   FALSE, '{}'::text[], FALSE,
   1, 0, 2, FALSE, TRUE, FALSE, 0,
   1, 'bagel', 'Plain large bagel. Dense carb source (~56g/bagel).'),

  -- ===== Protein anchors =====
  ('cottage_cheese', 'Cottage Cheese', 'cups Cottage Cheese',
   '1 cup (226g)', 226.0,
   220, 9.0, 25.0, 9.0, 0.0, 700.0, 180.0,
   '{dairy}'::text[], 'medium', TRUE,
   '{vegan}'::text[], 'whole_food', '{running,cycling,swimming}'::text[], '{after_run}'::text[],
   TRUE, FALSE, FALSE, FALSE, 0.0, 200.0,
   FALSE, '{}'::text[], FALSE,
   0, 0, 2, FALSE, FALSE, FALSE, 0,
   1, 'cup', 'Low-fat cottage cheese. Lower lactose than other dairy, tolerated well after hot workouts. ~25g protein/cup.'),

  ('string_cheese', 'String Cheese', 'string cheese sticks',
   '1 stick (28g)', 28.0,
   80, 1.0, 7.0, 6.0, 0.0, 200.0, 0.0,
   '{dairy}'::text[], 'slow', TRUE,
   '{vegan}'::text[], 'whole_food', '{running,cycling,swimming}'::text[], '{after_run}'::text[],
   TRUE, FALSE, FALSE, FALSE, 0.0, 25.0,
   FALSE, '{}'::text[], FALSE,
   0, 0, 4, FALSE, TRUE, FALSE, 0,
   1, 'stick', 'Mozzarella string cheese. Portable, no refrigeration for 1-2 hrs in cool weather.'),

  ('whey_protein_shake_rtd', 'Whey Protein Shake (RTD)', 'bottles Whey Protein Shake',
   '1 bottle (11 oz)', 325.0,
   170, 9.0, 30.0, 2.5, 1.0, 200.0, 300.0,
   '{dairy}'::text[], 'fast', TRUE,
   '{vegan,paleo}'::text[], 'beverage', '{running,cycling,swimming}'::text[], '{after_run}'::text[],
   TRUE, FALSE, FALSE, FALSE, 0.0, 220.0,
   FALSE, '{}'::text[], TRUE,
   0, 0, 2, FALSE, TRUE, FALSE, 0,
   1, 'bottle', 'Generic 11 oz ready-to-drink whey protein shake (Premier, Muscle Milk, Fairlife, etc.). 30g protein.'),

  ('plant_protein_shake_rtd', 'Plant Protein Shake (RTD)', 'bottles Plant Protein Shake',
   '1 bottle (11 oz)', 325.0,
   170, 11.0, 20.0, 4.5, 3.0, 280.0, 300.0,
   '{soy}'::text[], 'medium', TRUE,
   '{paleo}'::text[], 'beverage', '{running,cycling,swimming}'::text[], '{after_run}'::text[],
   TRUE, FALSE, FALSE, FALSE, 0.0, 280.0,
   FALSE, '{}'::text[], TRUE,
   0, 0, 2, FALSE, TRUE, FALSE, 0,
   1, 'bottle', 'Pea+rice plant protein RTD (Orgain, Owyn, Vega). ~20g protein, complete amino acid profile.'),

  ('deli_turkey', 'Deli Turkey', 'oz Deli Turkey',
   '3 oz (85g)', 85.0,
   90, 2.0, 18.0, 1.5, 0.0, 700.0, 0.0,
   '{}'::text[], 'medium', TRUE,
   '{vegan,vegetarian}'::text[], 'whole_food', '{running,cycling,swimming}'::text[], '{after_run}'::text[],
   TRUE, FALSE, FALSE, FALSE, 0.0, 230.0,
   FALSE, '{}'::text[], FALSE,
   0, 0, 4, FALSE, FALSE, FALSE, 0,
   3, 'oz', 'Sliced deli turkey breast. High sodium replenishes electrolyte loss from sweat.'),

  ('cream_cheese', 'Cream Cheese', 'tbsp Cream Cheese',
   '1 tbsp (15g)', 15.0,
   50, 1.0, 1.0, 5.0, 0.0, 50.0, 0.0,
   '{dairy}'::text[], 'slow', TRUE,
   '{vegan}'::text[], 'condiment', '{running,cycling,swimming}'::text[], '{after_run}'::text[],
   FALSE, FALSE, FALSE, FALSE, 0.0, 15.0,
   FALSE, '{}'::text[], FALSE,
   0, 0, 4, TRUE, FALSE, FALSE, 0,
   1, 'tbsp', 'Spread for bagels. Adds fat + creamy texture.'),

  ('milk', 'Milk', 'cups Milk',
   '1 cup (8 oz)', 244.0,
   150, 12.0, 8.0, 8.0, 0.0, 105.0, 220.0,
   '{dairy}'::text[], 'medium', TRUE,
   '{vegan,paleo}'::text[], 'beverage', '{running,cycling,swimming}'::text[], '{after_run,before_run}'::text[],
   TRUE, FALSE, FALSE, FALSE, 0.0, 350.0,
   TRUE, '{snack,top_up}'::text[], TRUE,
   2, 0, 3, FALSE, FALSE, FALSE, 0,
   1, 'cup', 'Whole milk. Provides carbs, protein, fluid, calcium, sodium, potassium.'),

  ('plant_milk', 'Plant Milk', 'cups Plant Milk',
   '1 cup (8 oz)', 240.0,
   90, 13.0, 3.0, 3.0, 1.0, 100.0, 220.0,
   '{}'::text[], 'medium', TRUE,
   '{}'::text[], 'beverage', '{running,cycling,swimming}'::text[], '{after_run,before_run}'::text[],
   TRUE, FALSE, FALSE, FALSE, 0.0, 200.0,
   FALSE, '{}'::text[], TRUE,
   2, 0, 3, FALSE, FALSE, FALSE, 0,
   1, 'cup', 'Generic plant-based milk (oat/almond/soy). Often fortified with calcium.'),

  -- ===== Carb sources =====
  ('applesauce', 'Applesauce', 'cups Applesauce',
   '1 cup (244g)', 244.0,
   105, 28.0, 0.0, 0.0, 3.0, 5.0, 215.0,
   '{}'::text[], 'fast', TRUE,
   '{}'::text[], 'whole_food', '{running,cycling,swimming}'::text[], '{after_run,before_run}'::text[],
   FALSE, FALSE, FALSE, FALSE, 0.0, 180.0,
   FALSE, '{}'::text[], FALSE,
   1, 0, 3, FALSE, FALSE, FALSE, 0,
   1, 'cup', 'Unsweetened applesauce. Gentle on the gut, fast carbs, useful when nothing solid sounds good.'),

  ('apple', 'Apple', 'apples',
   '1 medium (182g)', 182.0,
   95, 25.0, 0.5, 0.3, 4.4, 2.0, 160.0,
   '{}'::text[], 'medium', TRUE,
   '{}'::text[], 'whole_food', '{running,cycling,swimming}'::text[], '{after_run,before_run}'::text[],
   TRUE, FALSE, FALSE, FALSE, 0.0, 195.0,
   FALSE, '{}'::text[], FALSE,
   1, 0, 3, FALSE, TRUE, FALSE, 0,
   1, 'medium', 'Whole apple. Portable, hydrating, fiber + natural sugars.'),

  ('crackers', 'Crackers', 'crackers',
   '8 crackers (28g)', 28.0,
   120, 22.0, 2.0, 3.0, 1.0, 230.0, 0.0,
   '{gluten}'::text[], 'fast', TRUE,
   '{}'::text[], 'whole_food', '{running,cycling,swimming}'::text[], '{after_run,before_run}'::text[],
   TRUE, FALSE, FALSE, FALSE, 0.0, 35.0,
   FALSE, '{}'::text[], FALSE,
   1, 0, 4, FALSE, FALSE, FALSE, 0,
   8, 'crackers', 'Saltine-style or whole-grain crackers. Dense carbs + sodium, bag-stable.'),

  ('pretzels', 'Pretzels', 'oz Pretzels',
   '1 oz (28g)', 28.0,
   110, 23.0, 3.0, 1.0, 1.0, 390.0, 0.0,
   '{gluten}'::text[], 'fast', TRUE,
   '{gluten_free}'::text[], 'whole_food', '{running,cycling,swimming}'::text[], '{after_run,before_run}'::text[],
   TRUE, FALSE, FALSE, FALSE, 0.0, 50.0,
   FALSE, '{}'::text[], FALSE,
   0, 1, 4, FALSE, FALSE, FALSE, 0,
   1, 'oz', 'High-sodium salty snack. Great after sweaty sessions.'),

  ('granola_bar', 'Granola Bar', 'granola bars',
   '1 bar (40g)', 40.0,
   170, 28.0, 4.0, 6.0, 3.0, 110.0, 0.0,
   '{gluten,tree_nuts}'::text[], 'medium', TRUE,
   '{}'::text[], 'packaged_food', '{running,cycling,swimming}'::text[], '{after_run,before_run}'::text[],
   TRUE, FALSE, FALSE, FALSE, 0.0, 110.0,
   FALSE, '{}'::text[], FALSE,
   1, 0, 3, FALSE, TRUE, FALSE, 0,
   1, 'bar', 'Generic chewy granola bar (Clif/KIND/Nature Valley). Carb count varies by brand.'),

  ('toaster_waffle', 'Toaster Waffle', 'toaster waffles',
   '2 waffles (70g)', 70.0,
   190, 30.0, 4.0, 6.0, 1.0, 380.0, 0.0,
   '{gluten,egg,dairy}'::text[], 'fast', TRUE,
   '{vegan,gluten_free}'::text[], 'packaged_food', '{running,cycling,swimming}'::text[], '{after_run,before_run}'::text[],
   TRUE, FALSE, FALSE, FALSE, 0.0, 80.0,
   FALSE, '{}'::text[], FALSE,
   1, 0, 3, FALSE, TRUE, FALSE, 0,
   2, 'waffles', 'Frozen toaster waffles (Eggo, Kashi). Tolerate hours in a gym bag.'),

  ('orange', 'Orange', 'oranges',
   '1 medium (131g)', 131.0,
   62, 15.0, 1.2, 0.2, 3.1, 0.0, 110.0,
   '{}'::text[], 'fast', TRUE,
   '{}'::text[], 'whole_food', '{running,cycling,swimming}'::text[], '{after_run,before_run}'::text[],
   TRUE, FALSE, FALSE, FALSE, 0.0, 240.0,
   FALSE, '{}'::text[], FALSE,
   1, 0, 3, FALSE, TRUE, FALSE, 0,
   1, 'medium', 'Whole orange. Vitamin C, potassium, hydrating sugars.'),

  ('dates', 'Dates', 'dates',
   '3 dates (24g)', 24.0,
   66, 18.0, 0.4, 0.0, 1.6, 0.0, 5.0,
   '{}'::text[], 'fast', TRUE,
   '{}'::text[], 'whole_food', '{running,cycling,swimming}'::text[], '{after_run,before_run}'::text[],
   TRUE, FALSE, FALSE, FALSE, 0.0, 165.0,
   FALSE, '{}'::text[], FALSE,
   1, 0, 4, FALSE, TRUE, FALSE, 0,
   3, 'dates', 'Medjool dates. Dense natural sugar, potassium-rich.'),

  ('graham_crackers', 'Graham Crackers', 'graham crackers',
   '2 sheets (28g)', 28.0,
   120, 22.0, 2.0, 3.0, 1.0, 130.0, 0.0,
   '{gluten}'::text[], 'fast', TRUE,
   '{}'::text[], 'packaged_food', '{running,cycling,swimming}'::text[], '{after_run,before_run}'::text[],
   FALSE, FALSE, FALSE, FALSE, 0.0, 40.0,
   FALSE, '{}'::text[], FALSE,
   1, 0, 3, FALSE, TRUE, FALSE, 0,
   2, 'sheets', 'Honey graham crackers. Easy on the stomach, snackable carbs.'),

  ('fig_bar', 'Fig Bar', 'fig bars',
   '1 bar (32g)', 32.0,
   100, 21.0, 1.0, 2.0, 1.0, 65.0, 0.0,
   '{gluten}'::text[], 'fast', TRUE,
   '{}'::text[], 'packaged_food', '{running,cycling,swimming}'::text[], '{after_run,before_run}'::text[],
   FALSE, FALSE, FALSE, FALSE, 0.0, 50.0,
   FALSE, '{}'::text[], FALSE,
   1, 0, 3, FALSE, TRUE, FALSE, 0,
   1, 'bar', 'Generic fig bar (Nature''s Bakery, Fig Newtons). Real-food carbs.'),

  ('maple_syrup', 'Maple Syrup', 'tbsp Maple Syrup',
   '1 tbsp (20g)', 20.0,
   52, 13.0, 0.0, 0.0, 0.0, 2.0, 0.0,
   '{}'::text[], 'fast', TRUE,
   '{}'::text[], 'condiment', '{running,cycling,swimming}'::text[], '{after_run,before_run}'::text[],
   FALSE, FALSE, FALSE, FALSE, 0.0, 40.0,
   FALSE, '{}'::text[], FALSE,
   0, 0, 4, FALSE, FALSE, FALSE, 0,
   1, 'tbsp', 'Pure maple syrup. Carb topper for oatmeal/yogurt.'),

  ('eggs', 'Eggs', 'eggs',
   '1 large egg (50g)', 50.0,
   72, 0.4, 6.0, 5.0, 0.0, 70.0, 35.0,
   '{egg}'::text[], 'medium', TRUE,
   '{vegan}'::text[], 'whole_food', '{running,cycling,swimming}'::text[], '{after_run}'::text[],
   TRUE, FALSE, FALSE, TRUE, 0.0, 70.0,
   FALSE, '{}'::text[], FALSE,
   0, 0, 4, FALSE, TRUE, FALSE, 0,
   1, 'egg', 'Whole eggs (boiled, scrambled, fried). Complete protein, leucine-rich.')

ON CONFLICT (name) DO NOTHING;


-- ============================================================================
-- STEP 3 — Backfill nutrition for templates that needed updates (no-op if
--          they already had these values from the legacy seed)
-- ============================================================================

-- Mark sodium top-up eligibility for new foods (mirrors during-workout pattern)
UPDATE public.template_foods
   SET sodium_top_up_eligible = TRUE
 WHERE is_electrolyte = TRUE
   AND COALESCE(sodium_mg, 0) > 0
   AND COALESCE(carbs_g, 0) <= 5
   AND name NOT IN ('sports_drink', 'high_carb_drink_mix');


-- ============================================================================
-- STEP 4 — Reseed post_workout_templates with the 21 Notion templates
--
-- The old 20 legacy templates are replaced — this is a full repopulation.
-- template_number 1..21 maps to the Notion list ordering (alphabetical by
-- title in the Notion default view; we keep it stable across re-runs).
-- ============================================================================

DELETE FROM public.post_workout_templates;


-- All post-workout templates apply to any endurance workout.
-- Setting activity_types = {running, cycling, swimming, triathlon, brick}
-- so the selector matches the user's actual activity regardless of sport.

INSERT INTO public.post_workout_templates (
  template_number, name, formula, portions,
  activity_types, component_food_names, component_ratios,
  target_carb_protein_ratio, allergens, excluded_diets,
  travel_friendliness, flavor_profile, prep_effort, protein_anchor,
  carb_sources, selection_priority, notes
) VALUES
  -- 1. Cottage Cheese + Applesauce
  (1, 'Cottage Cheese + Applesauce',
   '1 cup cottage cheese + 1 cup applesauce',
   '1 cup cottage cheese + 1 cup applesauce',
   '{running,cycling,swimming,triathlon,brick}',
   '{cottage_cheese,applesauce}',
   '{"cottage_cheese": 0.30, "applesauce": 0.70}',
   '~1:1 base, ~2:1 with 1 cup applesauce',
   '{dairy}', '{vegan}',
   'cooler_friendly', 'sweet_creamy', 'grab_and_go', 'cottage_cheese',
   '{applesauce}', 20,
   'Rachel''s combo. Gentle on the gut, fast carbs from applesauce, slow protein from cottage cheese. Excellent for hot-day recovery when nothing solid sounds good. Single-serve applesauce cups make this fully grab-and-go from a cooler. Ratio is protein-heavy at base — athlete should plan a carb-rich follow-up meal within 1-2 hours.'),

  -- 2. Cheese Stick + Crackers + Jam
  (2, 'Cheese Stick + Crackers + Jam',
   '2 string cheese sticks + 8 crackers + 1 tbsp jam',
   '2 string cheese sticks + 8 crackers + 1 tbsp jam',
   '{running,cycling,swimming,triathlon,brick}',
   '{string_cheese,crackers,jam}',
   '{"string_cheese": 0.15, "crackers": 0.55, "jam": 0.30}',
   '~2.5:1 (36g carbs / 14g protein at 2 sticks)',
   '{dairy,gluten}', '{vegan}',
   'cooler_friendly', 'mixed', 'grab_and_go', 'deli_cheese',
   '{crackers,jam}', 20,
   'Rachel''s ''crackers + jam + cheese stick'' combo. Sweet-savory mix — spread jam on crackers, eat cheese stick alongside. Distinct from Cheese Stick + Pretzels by being sweet-leaning rather than fully savory. Good middle option when athlete can''t decide between sweet and savory cravings.'),

  -- 3. PB&J + Milk
  (3, 'PB&J + Milk',
   '2 slices toast + 2 tbsp peanut butter + 2 tbsp jam + 1 cup milk',
   '2 slices toast + 2 tbsp peanut butter + 2 tbsp jam + 1 cup milk',
   '{running,cycling,swimming,triathlon,brick}',
   '{whole_wheat_bread,peanut_butter,jam,milk}',
   '{"whole_wheat_bread": 0.35, "peanut_butter": 0.05, "jam": 0.30, "milk": 0.30}',
   '~3:1 (43g carbs / 14g protein at base)',
   '{peanuts,gluten,dairy}', '{vegan,nut_free}',
   'cooler_friendly', 'sweet_creamy', 'assemble', 'nut_butter',
   '{toast,jam}', 10,
   'Allen Lim (Skratch Labs) calls this ''the perfect real food recovery.'' Distinct from Nut Butter + Toast + Banana — jam adds faster carbs and milk brings the protein anchor up to ~14g (close to a true 3:1 starter). Sandwich travels in foil; milk needs a single-serve box or cooler. Sub almond butter (Tree Nut) or sunflower butter (nut-free) per athlete profile.'),

  -- 4. Waffle + Banana + Protein Shake
  (4, 'Waffle + Banana + Protein Shake',
   '2 toaster waffles + 1 medium banana + 1 RTD whey shake (11 oz)',
   '2 toaster waffles + 1 medium banana + 1 RTD whey shake (11 oz)',
   '{running,cycling,swimming,triathlon,brick}',
   '{toaster_waffle,banana,whey_protein_shake_rtd}',
   '{"toaster_waffle": 0.50, "banana": 0.35, "whey_protein_shake_rtd": 0.15}',
   '~1.7:1 base, scales to 3:1 with 2 waffles',
   '{dairy,gluten,egg}', '{vegan,gluten_free}',
   'in_bag', 'sweet_crunchy', 'grab_and_go', 'whey_shake',
   '{toaster_waffle,banana}', 30,
   'Lee''s Template 10. Pop waffles in toaster (or eat cold from a bag for finish-line use), grab shake from fridge or cooler, eat banana whole. Done in 2 minutes. Toaster waffles tolerate a few hours in a gym bag. Shake stays fixed at 1 bottle; waffles + banana scale together for higher carb targets.'),

  -- 5. Bagel + Cream Cheese + Turkey
  (5, 'Bagel + Cream Cheese + Turkey',
   '1 large bagel + 1 tbsp cream cheese + 3 oz deli turkey',
   '1 large bagel + 1 tbsp cream cheese + 3 oz deli turkey',
   '{running,cycling,swimming,triathlon,brick}',
   '{bagel_large,cream_cheese,deli_turkey}',
   '{"bagel_large": 0.85, "cream_cheese": 0.05, "deli_turkey": 0.10}',
   '~2:1 base (53g carbs / 27g protein)',
   '{gluten,dairy}', '{vegan,vegetarian}',
   'cooler_friendly', 'savory_salty', 'assemble', 'deli_cheese',
   '{bagel}', 10,
   'Lee''s Template 8. Heaviest savory anchor in the database — verges on meal-sized at full serving (600+ cal for 1 bagel). For athletes who want a substantial savory recovery starter after long sessions. Pre-assemble the night before for cooler-friendly travel. Cream cheese contributes minimal protein but ties the bagel and turkey together.'),

  -- 6. Oatmeal + Protein Powder + Banana + Honey
  (6, 'Oatmeal + Protein Powder + Banana + Honey',
   '1 serving oatmeal (1/2 cup dry) + 1 scoop whey protein powder + 1 medium banana + 1 tbsp honey',
   '1 serving oatmeal (1/2 cup dry) + 1 scoop whey protein powder + 1 medium banana + 1 tbsp honey',
   '{running,cycling,swimming,triathlon,brick}',
   '{oatmeal,whey_protein_powder,banana,honey}',
   '{"oatmeal": 0.40, "whey_protein_powder": 0.05, "banana": 0.30, "honey": 0.25}',
   '~2.4:1 (71g carbs / 30g protein at base)',
   '{dairy,gluten}', '{vegan}',
   'home_only', 'warm_comforting', 'cook', 'whey_shake',
   '{oatmeal,banana,honey}', 10,
   'Lee''s Template 6. Warm and comforting — the main non-egg option for athletes who want a hot recovery. Add hot water to oatmeal, stir in whey protein powder, top with banana and honey. Swap honey for maple syrup for variety. SCHEMA NOTE: Protein source here is whey powder, not an RTD shake.'),

  -- 7. Egg + Toast + Jam
  (7, 'Egg + Toast + Jam',
   '2 eggs (boiled or scrambled) + 2 slices toast + 1 tbsp jam',
   '2 eggs (boiled or scrambled) + 2 slices toast + 1 tbsp jam',
   '{running,cycling,swimming,triathlon,brick}',
   '{eggs,toast,jam}',
   '{"eggs": 0.05, "toast": 0.65, "jam": 0.30}',
   '~3.5:1 (50g carbs / 14g protein at 2 each)',
   '{egg,gluten}', '{vegan}',
   'home_only', 'warm_comforting', 'cook', 'egg',
   '{toast,jam}', 10,
   'Sam Long''s #1 recovery food — ''the single food item he could not live without.'' Pre-boiled eggs make this Cooler-Friendly (can be re-tagged per athlete preference). Protein lower than shake/yogurt anchors — pair with milk or extra egg if athlete needs more.'),

  -- 8. Cottage Cheese + Crackers + Apple
  (8, 'Cottage Cheese + Crackers + Apple',
   '1 cup cottage cheese + 8 crackers + 1 medium apple, sliced',
   '1 cup cottage cheese + 8 crackers + 1 medium apple, sliced',
   '{running,cycling,swimming,triathlon,brick}',
   '{cottage_cheese,crackers,apple}',
   '{"cottage_cheese": 0.20, "crackers": 0.45, "apple": 0.35}',
   '~1.5:1 base, ~2:1 with extra apple',
   '{dairy,gluten}', '{vegan}',
   'cooler_friendly', 'savory_salty', 'assemble', 'cottage_cheese',
   '{crackers,apple}', 15,
   'Settles well on hot stomachs when sweet feels bad. Cottage cheese is often tolerated when other dairy isn''t (lower lactose). High satiety. Ratio is protein-heavy — better suited to athletes who''ll eat a carb-rich follow-up meal within 1-2 hours.'),

  -- 9. Yogurt + Berries + Granola
  (9, 'Yogurt + Berries + Granola',
   '1 cup Greek yogurt + 1/2 cup berries + 1/4 cup granola',
   '1 cup Greek yogurt + 1/2 cup berries + 1/4 cup granola',
   '{running,cycling,swimming,triathlon,brick}',
   '{greek_yogurt,mixed_berries,granola}',
   '{"greek_yogurt": 0.15, "mixed_berries": 0.40, "granola": 0.45}',
   '~2:1',
   '{dairy,gluten}', '{vegan}',
   'cooler_friendly', 'sweet_creamy', 'assemble', 'yogurt',
   '{mixed_berries,granola}', 20,
   'Lower-carb parfait for shorter or easier sessions. Berries add antioxidants without big sugar load. Good post-easy-run option for athletes managing weight.'),

  -- 10. Whey Shake + Pretzels + Banana
  (10, 'Whey Shake + Pretzels + Banana',
   '1 RTD whey shake (11 oz) + 1 oz pretzels + 1 medium banana',
   '1 RTD whey shake (11 oz) + 1 oz pretzels + 1 medium banana',
   '{running,cycling,swimming,triathlon,brick}',
   '{whey_protein_shake_rtd,pretzels,banana}',
   '{"whey_protein_shake_rtd": 0.15, "pretzels": 0.45, "banana": 0.40}',
   '~2:1 base, scales to 3-4:1',
   '{dairy,gluten}', '{vegan,gluten_free}',
   'in_bag', 'mixed', 'grab_and_go', 'whey_shake',
   '{pretzels,banana}', 25,
   'Sweet + salty combo for hot-day recovery when sweet alone feels nauseating. Pretzels add ~385mg sodium per oz — useful after high-sweat sessions. Recommended after long rides in summer.'),

  -- 11. Nut Butter + Toast + Banana
  (11, 'Nut Butter + Toast + Banana',
   '2 slices toast + 2 tbsp peanut butter + 1 banana (assembled as sandwich)',
   '2 slices toast + 2 tbsp peanut butter + 1 banana (assembled as sandwich)',
   '{running,cycling,swimming,triathlon,brick}',
   '{whole_wheat_bread,peanut_butter,banana}',
   '{"whole_wheat_bread": 0.40, "peanut_butter": 0.10, "banana": 0.50}',
   '~5:1 (carb-heavy)',
   '{peanuts,gluten}', '{nut_free}',
   'in_bag', 'sweet_creamy', 'assemble', 'nut_butter',
   '{toast,banana}', 15,
   'Allen Lim (Skratch Labs) calls PB&banana ''the perfect real food recovery.'' Travels as a sandwich in foil. Protein anchor is lighter than shake/yogurt (~10g) — pair with a small glass of milk to bring protein up. Sub almond butter (Tree Nut) or sunflower butter (nut-free) per athlete profile.'),

  -- 12. Whey Shake + Banana
  (12, 'Whey Shake + Banana',
   '1 RTD whey shake (11 oz) + 1 medium banana',
   '1 RTD whey shake (11 oz) + 1 medium banana',
   '{running,cycling,swimming,triathlon,brick}',
   '{whey_protein_shake_rtd,banana}',
   '{"whey_protein_shake_rtd": 0.25, "banana": 0.75}',
   '1:1 at base, scales to ~3:1 with 3 bananas',
   '{dairy}', '{vegan}',
   'in_bag', 'sweet_creamy', 'grab_and_go', 'whey_shake',
   '{banana}', 35,
   'Smaller athletes after a short session: 1 banana. Larger athletes or longer/harder sessions: 2-3 bananas. The shake stays fixed at 1 bottle. Foundational starter — every athlete should have this combo as a fallback.'),

  -- 13. Deli Turkey Roll-ups + Crackers
  (13, 'Deli Turkey Roll-ups + Crackers',
   '4 oz deli turkey rolled up + 10 crackers',
   '4 oz deli turkey rolled up + 10 crackers',
   '{running,cycling,swimming,triathlon,brick}',
   '{deli_turkey,crackers}',
   '{"deli_turkey": 0.10, "crackers": 0.90}',
   '~1.5:1',
   '{gluten}', '{vegan,vegetarian}',
   'cooler_friendly', 'savory_salty', 'grab_and_go', 'deli_cheese',
   '{crackers}', 15,
   'Pre-roll turkey the night before in a small container. High sodium (~700mg+ from turkey + crackers) — great for hot/sweaty days. Add cheese slices inside the roll-up for fat + extra protein. Protein-heavy ratio suits athletes who''ll eat a carb-rich meal within 1-2 hours.'),

  -- 14. Whey Shake + Granola Bar
  (14, 'Whey Shake + Granola Bar',
   '1 RTD whey shake (11 oz) + 1 granola bar',
   '1 RTD whey shake (11 oz) + 1 granola bar',
   '{running,cycling,swimming,triathlon,brick}',
   '{whey_protein_shake_rtd,granola_bar}',
   '{"whey_protein_shake_rtd": 0.30, "granola_bar": 0.70}',
   '~1:1 to 2:1 depending on bar',
   '{dairy,gluten,tree_nuts}', '{vegan,gluten_free}',
   'in_bag', 'sweet_crunchy', 'grab_and_go', 'whey_shake',
   '{granola_bar}', 30,
   'Universal travel combo — both items live in a gym bag for hours, no cooler needed. Granola bar carbs vary by brand (Clif ~40g, KIND ~15g) so ratio depends on choice. Best when athlete pre-stocks a specific bar in profile.'),

  -- 15. Smoothie - Frodeno Style
  (15, 'Smoothie - Frodeno Style',
   '1 cup milk + 1 medium banana + 1 tbsp peanut butter + 1 scoop whey protein powder',
   '1 cup milk + 1 medium banana + 1 tbsp peanut butter + 1 scoop whey protein powder',
   '{running,cycling,swimming,triathlon,brick}',
   '{milk,banana,peanut_butter,whey_protein_powder}',
   '{"milk": 0.30, "banana": 0.55, "peanut_butter": 0.10, "whey_protein_powder": 0.05}',
   '~2-3:1',
   '{dairy,peanuts}', '{vegan,nut_free}',
   'home_only', 'sweet_creamy', 'assemble', 'smoothie',
   '{banana}', 15,
   'Jan Frodeno''s daily recovery shake — same combo every day, no decision fatigue. Blender required. Swap PB for almond butter (becomes Tree Nut), sunflower seed butter (nut-free), or omit nut butter entirely if athlete prefers.'),

  -- 16. Smoothie - Plant Berry
  (16, 'Smoothie - Plant Berry',
   '1 cup plant milk + 1/2 banana + 1 cup berries + 1 scoop plant protein powder',
   '1 cup plant milk + 1/2 banana + 1 cup berries + 1 scoop plant protein powder',
   '{running,cycling,swimming,triathlon,brick}',
   '{plant_milk,banana,mixed_berries,plant_protein_powder}',
   '{"plant_milk": 0.30, "banana": 0.15, "mixed_berries": 0.45, "plant_protein_powder": 0.10}',
   '~2:1',
   '{soy}', '{}',
   'home_only', 'sweet_creamy', 'assemble', 'plant_shake',
   '{mixed_berries,banana}', 15,
   'Vegan-friendly home recovery. Lower carb than Frodeno version — good for shorter sessions. Add 1 tbsp seed butter (sunflower or pumpkin) for extra calories on long-ride days. Soy allergen flag depends on plant milk/protein source choice.'),

  -- 17. Chocolate Milk Solo
  (17, 'Chocolate Milk Solo',
   '2 cups (16 oz) chocolate milk',
   '2 cups (16 oz) chocolate milk',
   '{running,cycling,swimming,triathlon,brick}',
   '{chocolate_milk}',
   '{"chocolate_milk": 1.0}',
   '~3:1 perfect (30g carbs / 9g protein per cup)',
   '{dairy}', '{vegan}',
   'in_bag', 'sweet_creamy', 'grab_and_go', 'chocolate_milk',
   '{}', 40,
   'The most-studied recovery beverage. Hits the 3:1 ratio at every serving size. Doubles as hydration (88% water). Single-serve cartons are bag-stable for 2-3 hours unrefrigerated. 2 cups = 60g carbs / 18g protein, a complete starter for most athletes.'),

  -- 18. Chocolate Milk + Banana
  (18, 'Chocolate Milk + Banana',
   '2 cups (16 oz) chocolate milk + 1 medium banana',
   '2 cups (16 oz) chocolate milk + 1 medium banana',
   '{running,cycling,swimming,triathlon,brick}',
   '{chocolate_milk,banana}',
   '{"chocolate_milk": 0.55, "banana": 0.45}',
   '~6:1 (carb-heavy)',
   '{dairy}', '{vegan}',
   'in_bag', 'sweet_creamy', 'grab_and_go', 'chocolate_milk',
   '{banana}', 30,
   'For larger athletes who need more carbs than chocolate milk alone. 1 cup + 1 banana = 57g carbs / 10g protein. Note: protein-light — for athletes >75 kg, consider Whey Shake + Banana instead.'),

  -- 19. Yogurt + Granola + Banana + Honey
  (19, 'Yogurt + Granola + Banana + Honey',
   '1 cup Greek yogurt + 1/3 cup granola + 1 medium banana + 1 tbsp honey',
   '1 cup Greek yogurt + 1/3 cup granola + 1 medium banana + 1 tbsp honey',
   '{running,cycling,swimming,triathlon,brick}',
   '{greek_yogurt,granola,banana,honey}',
   '{"greek_yogurt": 0.15, "granola": 0.40, "banana": 0.30, "honey": 0.15}',
   '~3-4:1',
   '{dairy,gluten}', '{vegan}',
   'cooler_friendly', 'sweet_creamy', 'assemble', 'yogurt',
   '{granola,banana,honey}', 25,
   'The parfait. Assemble in a mason jar the night before and grab from the fridge. Greek yogurt provides ~17g protein/cup. Scales as a unit — bigger parfait = more of everything. Swap banana for berries, peaches, or any seasonal fruit.'),

  -- 20. Cheese Stick + Pretzels
  (20, 'Cheese Stick + Pretzels',
   '2 string cheese sticks + 1 oz pretzels',
   '2 string cheese sticks + 1 oz pretzels',
   '{running,cycling,swimming,triathlon,brick}',
   '{string_cheese,pretzels}',
   '{"string_cheese": 0.10, "pretzels": 0.90}',
   '~3:1',
   '{dairy,gluten}', '{vegan}',
   'cooler_friendly', 'savory_salty', 'grab_and_go', 'deli_cheese',
   '{pretzels}', 25,
   'Simplest savory option. String cheese tolerates ~1-2 hours unrefrigerated in cool weather but cooler-friendly is safer. Single stick (~7g protein) is light — pair 2-3 for a full protein anchor. Hits the 3:1 ratio cleanly.'),

  -- 21. Plant Shake + Banana + Pretzels
  (21, 'Plant Shake + Banana + Pretzels',
   '1 plant RTD shake (11 oz) + 1 medium banana + 1 oz pretzels',
   '1 plant RTD shake (11 oz) + 1 medium banana + 1 oz pretzels',
   '{running,cycling,swimming,triathlon,brick}',
   '{plant_protein_shake_rtd,banana,pretzels}',
   '{"plant_protein_shake_rtd": 0.20, "banana": 0.35, "pretzels": 0.45}',
   '~2-3:1',
   '{gluten,soy}', '{gluten_free}',
   'in_bag', 'mixed', 'grab_and_go', 'plant_shake',
   '{banana,pretzels}', 30,
   'Cody Beals'' approach — plant shake immediately after every session. Vegan-friendly. Note: plant shakes typically have lower leucine; for serious muscle recovery, athlete may want a slightly larger serving (e.g., 1.5 bottles) on long sessions. GF pretzels swap maintains compliance.');


-- ============================================================================
-- STEP 5 — Default servings per template
--
-- One shared portion across all athletes. Maps food name → serving count
-- in the food's catalog serving size (e.g. toaster_waffle serving = 2 waffles,
-- so {"toaster_waffle": 1} renders as "2 waffles" in the UI).
-- ============================================================================

UPDATE public.post_workout_templates SET default_servings = '{"cottage_cheese": 1, "applesauce": 1}'::jsonb WHERE template_number = 1;
UPDATE public.post_workout_templates SET default_servings = '{"string_cheese": 2, "crackers": 1, "jam": 1}'::jsonb WHERE template_number = 2;
UPDATE public.post_workout_templates SET default_servings = '{"whole_wheat_bread": 1, "peanut_butter": 2, "jam": 2, "milk": 1}'::jsonb WHERE template_number = 3;
UPDATE public.post_workout_templates SET default_servings = '{"toaster_waffle": 1, "banana": 1, "whey_protein_shake_rtd": 1}'::jsonb WHERE template_number = 4;
UPDATE public.post_workout_templates SET default_servings = '{"bagel_large": 1, "cream_cheese": 1, "deli_turkey": 1}'::jsonb WHERE template_number = 5;
UPDATE public.post_workout_templates SET default_servings = '{"oatmeal": 1, "whey_protein_powder": 1, "banana": 1, "honey": 1}'::jsonb WHERE template_number = 6;
UPDATE public.post_workout_templates SET default_servings = '{"eggs": 2, "toast": 2, "jam": 1}'::jsonb WHERE template_number = 7;
UPDATE public.post_workout_templates SET default_servings = '{"cottage_cheese": 1, "crackers": 1, "apple": 1}'::jsonb WHERE template_number = 8;
UPDATE public.post_workout_templates SET default_servings = '{"greek_yogurt": 1, "mixed_berries": 0.5, "granola": 1}'::jsonb WHERE template_number = 9;
UPDATE public.post_workout_templates SET default_servings = '{"whey_protein_shake_rtd": 1, "pretzels": 1, "banana": 1}'::jsonb WHERE template_number = 10;
UPDATE public.post_workout_templates SET default_servings = '{"whole_wheat_bread": 1, "peanut_butter": 2, "banana": 1}'::jsonb WHERE template_number = 11;
UPDATE public.post_workout_templates SET default_servings = '{"whey_protein_shake_rtd": 1, "banana": 1}'::jsonb WHERE template_number = 12;
UPDATE public.post_workout_templates SET default_servings = '{"deli_turkey": 1.5, "crackers": 1}'::jsonb WHERE template_number = 13;
UPDATE public.post_workout_templates SET default_servings = '{"whey_protein_shake_rtd": 1, "granola_bar": 1}'::jsonb WHERE template_number = 14;
UPDATE public.post_workout_templates SET default_servings = '{"milk": 1, "banana": 1, "peanut_butter": 1, "whey_protein_powder": 1}'::jsonb WHERE template_number = 15;
UPDATE public.post_workout_templates SET default_servings = '{"plant_milk": 1, "banana": 0.5, "mixed_berries": 1, "plant_protein_powder": 1}'::jsonb WHERE template_number = 16;
UPDATE public.post_workout_templates SET default_servings = '{"chocolate_milk": 2}'::jsonb WHERE template_number = 17;
UPDATE public.post_workout_templates SET default_servings = '{"chocolate_milk": 2, "banana": 1}'::jsonb WHERE template_number = 18;
UPDATE public.post_workout_templates SET default_servings = '{"greek_yogurt": 1, "granola": 1.5, "banana": 1, "honey": 1}'::jsonb WHERE template_number = 19;
UPDATE public.post_workout_templates SET default_servings = '{"string_cheese": 2, "pretzels": 1}'::jsonb WHERE template_number = 20;
UPDATE public.post_workout_templates SET default_servings = '{"plant_protein_shake_rtd": 1, "banana": 1, "pretzels": 1}'::jsonb WHERE template_number = 21;


-- ============================================================================
-- STEP 6 — Verification
-- ============================================================================
-- SELECT template_number, name, protein_anchor, flavor_profile, prep_effort,
--        travel_friendliness, array_length(component_food_names, 1) AS foods
--   FROM public.post_workout_templates
--  ORDER BY template_number;
