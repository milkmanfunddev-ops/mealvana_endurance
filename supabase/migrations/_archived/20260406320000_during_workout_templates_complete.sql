-- ============================================================================
-- Consolidated during-workout template migration
-- Combines:
--   20260406100000_add_during_template_constraint_columns.sql
--   20260406200000_create_during_workout_templates.sql
--   20260406300000_add_during_sodium_top_up_eligibility.sql
--   20260406310000_split_carb_drink_mix_catalog.sql
-- ============================================================================

-- SECTION 1: Per-hour constraint columns


-- STEP 1: Add columns
ALTER TABLE public.template_foods
  ADD COLUMN IF NOT EXISTS max_per_hr_low NUMERIC(4,2),
  ADD COLUMN IF NOT EXISTS max_per_hr_moderate NUMERIC(4,2),
  ADD COLUMN IF NOT EXISTS max_per_hr_high NUMERIC(4,2),
  ADD COLUMN IF NOT EXISTS min_increment NUMERIC(3,2) DEFAULT 0.5;

COMMENT ON COLUMN public.template_foods.max_per_hr_low
  IS 'Max servings per hour for low gut training level. NULL = unconstrained.';
COMMENT ON COLUMN public.template_foods.max_per_hr_moderate
  IS 'Max servings per hour for moderate gut training level. NULL = unconstrained.';
COMMENT ON COLUMN public.template_foods.max_per_hr_high
  IS 'Max servings per hour for high gut training level. NULL = unconstrained.';
COMMENT ON COLUMN public.template_foods.min_increment
  IS 'Minimum serving increment for rounding (e.g. 1 for gels = whole units only, 0.5 for bars = half bars allowed).';

-- STEP 2: Populate per-hour constraints for during-phase products
-- Values from: docs/features/during_workout_templates/during_workout_product_max_unit_constraints.md

-- Gels: 2/hr low, 3/hr moderate, 3/hr high. Whole units only (no half gels).
UPDATE public.template_foods
  SET max_per_hr_low = 2, max_per_hr_moderate = 3, max_per_hr_high = 3, min_increment = 1
  WHERE name = 'energy_gel';

-- Chews: 1 serving/hr low, 2/hr moderate, 2/hr high. Half servings allowed.
UPDATE public.template_foods
  SET max_per_hr_low = 1, max_per_hr_moderate = 2, max_per_hr_high = 2, min_increment = 0.5
  WHERE name IN ('energy_chews', 'energy_chews_mini_pack');

-- Bar: 0.5/hr low, 1/hr moderate, 1/hr high. Half bars common.
UPDATE public.template_foods
  SET max_per_hr_low = 0.5, max_per_hr_moderate = 1, max_per_hr_high = 1, min_increment = 0.5
  WHERE name = 'energy_bar';

-- Stroopwafel: 1/hr low, 1/hr moderate, 2/hr high. Whole units (hard to split).
UPDATE public.template_foods
  SET max_per_hr_low = 1, max_per_hr_moderate = 1, max_per_hr_high = 2, min_increment = 1
  WHERE name = 'stroopwafel';

-- Banana: 0.5/hr low, 1/hr moderate, 1/hr high. Half bananas practical.
UPDATE public.template_foods
  SET max_per_hr_low = 0.5, max_per_hr_moderate = 1, max_per_hr_high = 1, min_increment = 0.5
  WHERE name = 'banana';

-- Rice cake: 1/hr low, 1/hr moderate, 2/hr high. Half rice cakes practical.
UPDATE public.template_foods
  SET max_per_hr_low = 1, max_per_hr_moderate = 1, max_per_hr_high = 2, min_increment = 0.5
  WHERE name = 'rice_cake';

-- Sports drink: 2/hr low (16oz), 2.5/hr moderate (20oz), 3/hr high (24oz).
-- 1 serving = 8oz/240ml, so 16oz = 2 servings, 20oz = 2.5, 24oz = 3.
UPDATE public.template_foods
  SET max_per_hr_low = 2, max_per_hr_moderate = 2.5, max_per_hr_high = 3, min_increment = 0.5
  WHERE name = 'sports_drink';

-- High carb drink mix: N/A low, N/A moderate, 1 bottle/hr high only.
UPDATE public.template_foods
  SET max_per_hr_low = 0, max_per_hr_moderate = 0, max_per_hr_high = 1, min_increment = 0.5
  WHERE name = 'high_carb_drink_mix';

-- Water: no per-hour limit (NULL = unconstrained), 0.5 serving increments.
UPDATE public.template_foods
  SET min_increment = 0.5
  WHERE name = 'water';

-- Electrolytes (indivisible: tablets, capsules): whole units only.
UPDATE public.template_foods
  SET min_increment = 1
  WHERE is_electrolyte = true AND is_indivisible = true;

-- Electrolytes (divisible: drink mixes, packets): 0.5 increments.
UPDATE public.template_foods
  SET min_increment = 0.5
  WHERE is_electrolyte = true AND is_indivisible = false;

-- SECTION 2: During-workout template catalog

-- ============================================================================
-- Migration: Create during_workout_templates table + seed all 21 templates
--
-- This table stores formula templates for during-workout nutrition.
-- Each template defines a combination of foods (formula) appropriate for
-- specific activity types, duration ranges, and gut training levels.
--
-- Follows the pre_workout_templates pattern:
--   component_food_names TEXT[] references template_foods.name values
--   component_carb_ratios JSONB maps food names to their share of total carbs
--
-- Source: docs/features/during_workout_templates/during_workout_formula_templates_v1.md
-- Date: 2026-04-06
-- ============================================================================

-- STEP 1: Create table
CREATE TABLE IF NOT EXISTS public.during_workout_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_number INTEGER NOT NULL UNIQUE,
  name TEXT NOT NULL,
  formula TEXT NOT NULL,
  food_form TEXT NOT NULL,
  activity_types TEXT[] NOT NULL DEFAULT '{}',
  duration_brackets TEXT[] NOT NULL DEFAULT '{}',
  gut_training_levels TEXT[] NOT NULL DEFAULT '{}',
  component_food_names TEXT[] NOT NULL DEFAULT '{}',
  component_carb_ratios JSONB,
  primary_to_secondary_ratio TEXT,
  allergens TEXT[] NOT NULL DEFAULT '{}',
  excluded_diets TEXT[] NOT NULL DEFAULT '{}',
  notes TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_dwt_active
  ON public.during_workout_templates (is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_dwt_activity_types
  ON public.during_workout_templates USING GIN (activity_types);
CREATE INDEX IF NOT EXISTS idx_dwt_template_number
  ON public.during_workout_templates (template_number);

-- RLS: public read access (templates are not user-specific)
ALTER TABLE public.during_workout_templates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "during_workout_templates_select"
  ON public.during_workout_templates;
DROP POLICY IF EXISTS "during_workout_templates_insert_service"
  ON public.during_workout_templates;
DROP POLICY IF EXISTS "during_workout_templates_update_service"
  ON public.during_workout_templates;
DROP POLICY IF EXISTS "during_workout_templates_delete_service"
  ON public.during_workout_templates;

CREATE POLICY "during_workout_templates_select"
  ON public.during_workout_templates FOR SELECT USING (true);

CREATE POLICY "during_workout_templates_insert_service"
  ON public.during_workout_templates FOR INSERT
  WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "during_workout_templates_update_service"
  ON public.during_workout_templates FOR UPDATE
  USING (auth.role() = 'service_role');

CREATE POLICY "during_workout_templates_delete_service"
  ON public.during_workout_templates FOR DELETE
  USING (auth.role() = 'service_role');

COMMENT ON TABLE public.during_workout_templates
  IS 'Formula templates for during-workout nutrition. Each template defines a food combination for a specific activity/duration/gut-training context.';

COMMENT ON COLUMN public.during_workout_templates.component_food_names
  IS 'Array of template_foods.name values that compose this template formula.';

COMMENT ON COLUMN public.during_workout_templates.component_carb_ratios
  IS 'JSONB mapping food names to their target share of total carb allocation. e.g. {"energy_gel": 0.7, "sports_drink": 0.3}. Water and electrolytes are excluded (they fill fluid/sodium gaps).';

COMMENT ON COLUMN public.during_workout_templates.primary_to_secondary_ratio
  IS 'Unit ratio for triple-source templates. "1:1" means solid and gel must have equal unit counts. NULL for single/dual-source templates.';


-- ============================================================================
-- STEP 2: Seed base templates (0-20)
-- ============================================================================

-- This consolidated migration may be applied after an earlier split migration
-- in some environments. Reset the catalog rows it owns before re-seeding them.
DELETE FROM public.during_workout_templates
  WHERE template_number BETWEEN 0 AND 24;

-- Template 0: Quick Gel Module (T1/T2) — transition only
INSERT INTO public.during_workout_templates
  (template_number, name, formula, food_form, activity_types, duration_brackets,
   gut_training_levels, component_food_names, component_carb_ratios,
   primary_to_secondary_ratio, allergens, excluded_diets, notes)
VALUES
  (0, 'Quick Gel Module (T1/T2)', 'Gel + Water + sip of Sports Drink',
   'Liquid + Gel/Chew',
   '{triathlon_transition}',
   '{90-150 min,150-240 min,> 240 min}',
   '{low,moderate,high}',
   '{energy_gel,water,sports_drink}',
   '{"energy_gel": 0.8, "sports_drink": 0.2}',
   NULL, '{}', '{}',
   'Transition-specific. Keep it simple — one gel chased with a quick sip. Do not waste transition time on solids.');

-- Template 1: Gel + Water (Running)
INSERT INTO public.during_workout_templates
  (template_number, name, formula, food_form, activity_types, duration_brackets,
   gut_training_levels, component_food_names, component_carb_ratios,
   primary_to_secondary_ratio, allergens, excluded_diets, notes)
VALUES
  (1, 'Gel + Water', 'Gel + Water',
   'Liquid + Gel/Chew',
   '{running,triathlon_run}',
   '{90-150 min}',
   '{low,moderate,high}',
   '{energy_gel,water}',
   '{"energy_gel": 1.0}',
   NULL, '{}', '{}',
   'Most portable running option. Chase gel with water to aid absorption. Electrolyte add-on optional.');

-- Template 2: (Gel + Water) + Sports Drink (Running)
INSERT INTO public.during_workout_templates
  (template_number, name, formula, food_form, activity_types, duration_brackets,
   gut_training_levels, component_food_names, component_carb_ratios,
   primary_to_secondary_ratio, allergens, excluded_diets, notes)
VALUES
  (2, '(Gel + Water) + Sports Drink', '(Gel + Water) + Sports Drink',
   'Liquid + Gel/Chew',
   '{running,triathlon_run}',
   '{90-150 min,150-240 min,> 240 min}',
   '{moderate,high}',
   '{energy_gel,water,sports_drink}',
   '{"energy_gel": 0.7, "sports_drink": 0.3}',
   NULL, '{}', '{}',
   'Higher carb rate via dual liquid sources. Alternate gel with sports drink sips. Watch total carb concentration to avoid GI issues.');

-- Template 3: Chew + Water (Running)
INSERT INTO public.during_workout_templates
  (template_number, name, formula, food_form, activity_types, duration_brackets,
   gut_training_levels, component_food_names, component_carb_ratios,
   primary_to_secondary_ratio, allergens, excluded_diets, notes)
VALUES
  (3, 'Chew + Water', 'Chew + Water',
   'Liquid + Gel/Chew',
   '{running,triathlon_run}',
   '{90-150 min}',
   '{low,moderate,high}',
   '{energy_chews,water}',
   '{"energy_chews": 1.0}',
   NULL, '{}', '{}',
   'Easier to pace intake vs. gels. Chewing may reduce nausea for some athletes. Good entry point for newer runners.');

-- Template 4: Chew + Water + Sports Drink (Running)
INSERT INTO public.during_workout_templates
  (template_number, name, formula, food_form, activity_types, duration_brackets,
   gut_training_levels, component_food_names, component_carb_ratios,
   primary_to_secondary_ratio, allergens, excluded_diets, notes)
VALUES
  (4, 'Chew + Water + Sports Drink', 'Chew + Water + Sports Drink',
   'Liquid + Gel/Chew',
   '{running,triathlon_run}',
   '{90-150 min,150-240 min,> 240 min}',
   '{moderate,high}',
   '{energy_chews,water,sports_drink}',
   '{"energy_chews": 0.7, "sports_drink": 0.3}',
   NULL, '{}', '{}',
   'Dual carb source for longer efforts. Good alternative if gels cause GI distress.');

-- Template 5: Sports Drink Only (All sports, < 90 min)
INSERT INTO public.during_workout_templates
  (template_number, name, formula, food_form, activity_types, duration_brackets,
   gut_training_levels, component_food_names, component_carb_ratios,
   primary_to_secondary_ratio, allergens, excluded_diets, notes)
VALUES
  (5, 'Sports Drink Only', 'Sports Drink Only',
   'Liquid Only',
   '{running,cycling,triathlon_bike,triathlon_run}',
   '{< 90 min}',
   '{low,moderate,high}',
   '{sports_drink}',
   '{"sports_drink": 1.0}',
   NULL, '{}', '{}',
   'Default for sub-90 min efforts. Sip consistently rather than large boluses. Sufficient for moderate intensity.');

-- Template 6: High Carb Drink Mix + Water (Cycling, high gut)
INSERT INTO public.during_workout_templates
  (template_number, name, formula, food_form, activity_types, duration_brackets,
   gut_training_levels, component_food_names, component_carb_ratios,
   primary_to_secondary_ratio, allergens, excluded_diets, notes)
VALUES
  (6, 'High Carb Drink Mix + Water', 'High Carb Drink Mix + Water',
   'Liquid Only',
   '{cycling,triathlon_bike}',
   '{90-150 min,150-240 min}',
   '{high}',
   '{high_carb_drink_mix,water}',
   '{"high_carb_drink_mix": 1.0}',
   NULL, '{}', '{}',
   'Highest liquid carb density. Requires well-trained gut. Separate plain water bottle essential to manage osmolality and rinse mouth.');

-- Template 7: Bar + Sports Drink + Water (Cycling)
INSERT INTO public.during_workout_templates
  (template_number, name, formula, food_form, activity_types, duration_brackets,
   gut_training_levels, component_food_names, component_carb_ratios,
   primary_to_secondary_ratio, allergens, excluded_diets, notes)
VALUES
  (7, 'Bar + Sports Drink + Water', 'Bar + Sports Drink + Water',
   'Liquid + Solid',
   '{cycling,triathlon_bike}',
   '{90-150 min}',
   '{low,moderate,high}',
   '{energy_bar,sports_drink,water}',
   '{"energy_bar": 0.55, "sports_drink": 0.45}',
   NULL, '{}', '{}',
   'Steady energy from solid + liquid combo. Eat in small bites during low-intensity segments. Bars with simple ingredients preferred.');

-- Template 8: Bar + (Gel + Water) + Sports Drink (Cycling, triple-source)
INSERT INTO public.during_workout_templates
  (template_number, name, formula, food_form, activity_types, duration_brackets,
   gut_training_levels, component_food_names, component_carb_ratios,
   primary_to_secondary_ratio, allergens, excluded_diets, notes)
VALUES
  (8, 'Bar + (Gel + Water) + Sports Drink', 'Bar + (Gel + Water) + Sports Drink',
   'Mixed (Solid + Gel + Liquid)',
   '{cycling,triathlon_bike}',
   '{150-240 min}',
   '{moderate,high}',
   '{energy_bar,energy_gel,water,sports_drink}',
   '{"energy_bar": 0.35, "energy_gel": 0.35, "sports_drink": 0.3}',
   '1:1', '{}', '{}',
   'Triple source for sustained long rides. Rotate solid -> gel -> drink in cadence. Shift toward gel/liquid as intensity increases.');

-- Template 9: Stroopwafel + Sports Drink + Water (Cycling)
INSERT INTO public.during_workout_templates
  (template_number, name, formula, food_form, activity_types, duration_brackets,
   gut_training_levels, component_food_names, component_carb_ratios,
   primary_to_secondary_ratio, allergens, excluded_diets, notes)
VALUES
  (9, 'Stroopwafel + Sports Drink + Water', 'Stroopwafel + Sports Drink + Water',
   'Liquid + Solid',
   '{cycling,triathlon_bike}',
   '{90-150 min}',
   '{low,moderate,high}',
   '{stroopwafel,sports_drink,water}',
   '{"stroopwafel": 0.55, "sports_drink": 0.45}',
   NULL, '{gluten,dairy}', '{vegan,gluten_free}',
   'Highly palatable on-bike option. Warm on top tube to soften. Easy to eat at pace. Popular with triathletes.');

-- Template 10: Stroopwafel + (Gel + Water) + Sports Drink (Cycling, triple-source)
INSERT INTO public.during_workout_templates
  (template_number, name, formula, food_form, activity_types, duration_brackets,
   gut_training_levels, component_food_names, component_carb_ratios,
   primary_to_secondary_ratio, allergens, excluded_diets, notes)
VALUES
  (10, 'Stroopwafel + (Gel + Water) + Sports Drink',
   'Stroopwafel + (Gel + Water) + Sports Drink',
   'Mixed (Solid + Gel + Liquid)',
   '{cycling,triathlon_bike}',
   '{150-240 min}',
   '{moderate,high}',
   '{stroopwafel,energy_gel,water,sports_drink}',
   '{"stroopwafel": 0.35, "energy_gel": 0.35, "sports_drink": 0.3}',
   '1:1', '{gluten,dairy}', '{vegan,gluten_free}',
   'Variety prevents flavor fatigue on longer rides. Stroopwafel early, transition to gel as effort intensifies.');

-- Template 11: Banana + Sports Drink + Water (Cycling)
INSERT INTO public.during_workout_templates
  (template_number, name, formula, food_form, activity_types, duration_brackets,
   gut_training_levels, component_food_names, component_carb_ratios,
   primary_to_secondary_ratio, allergens, excluded_diets, notes)
VALUES
  (11, 'Banana + Sports Drink + Water', 'Banana + Sports Drink + Water',
   'Liquid + Solid',
   '{cycling,triathlon_bike}',
   '{90-150 min}',
   '{low,moderate,high}',
   '{banana,sports_drink,water}',
   '{"banana": 0.55, "sports_drink": 0.45}',
   NULL, '{}', '{}',
   'Real food option with natural potassium. Pre-peel and store in jersey pocket or bento box.');

-- Template 12: Banana + (Gel + Water) + Sports Drink (Cycling, triple-source)
INSERT INTO public.during_workout_templates
  (template_number, name, formula, food_form, activity_types, duration_brackets,
   gut_training_levels, component_food_names, component_carb_ratios,
   primary_to_secondary_ratio, allergens, excluded_diets, notes)
VALUES
  (12, 'Banana + (Gel + Water) + Sports Drink',
   'Banana + (Gel + Water) + Sports Drink',
   'Mixed (Solid + Gel + Liquid)',
   '{cycling,triathlon_bike}',
   '{150-240 min}',
   '{moderate,high}',
   '{banana,energy_gel,water,sports_drink}',
   '{"banana": 0.35, "energy_gel": 0.35, "sports_drink": 0.3}',
   '1:1', '{}', '{}',
   'Real food + gel combo. Banana early when intensity is lower; transition to gel as effort rises.');

-- Template 13: Rice Cake + Sports Drink + Water (Cycling)
INSERT INTO public.during_workout_templates
  (template_number, name, formula, food_form, activity_types, duration_brackets,
   gut_training_levels, component_food_names, component_carb_ratios,
   primary_to_secondary_ratio, allergens, excluded_diets, notes)
VALUES
  (13, 'Rice Cake + Sports Drink + Water', 'Rice Cake + Sports Drink + Water',
   'Liquid + Solid',
   '{cycling,triathlon_bike}',
   '{90-150 min,150-240 min,> 240 min}',
   '{low,moderate,high}',
   '{rice_cake_during,sports_drink,water}',
   '{"rice_cake_during": 0.55, "sports_drink": 0.45}',
   NULL, '{}', '{}',
   'Savory option breaks sweet monotony. Popular in pro peloton. Wrap in foil for jersey pocket. Real food priority for ultra-long efforts.');

-- Template 14: Rice Cake + (Gel + Water) + Sports Drink (Cycling, triple-source)
INSERT INTO public.during_workout_templates
  (template_number, name, formula, food_form, activity_types, duration_brackets,
   gut_training_levels, component_food_names, component_carb_ratios,
   primary_to_secondary_ratio, allergens, excluded_diets, notes)
VALUES
  (14, 'Rice Cake + (Gel + Water) + Sports Drink',
   'Rice Cake + (Gel + Water) + Sports Drink',
   'Mixed (Solid + Gel + Liquid)',
   '{cycling,triathlon_bike}',
   '{150-240 min,> 240 min}',
   '{moderate,high}',
   '{rice_cake_during,energy_gel,water,sports_drink}',
   '{"rice_cake_during": 0.35, "energy_gel": 0.35, "sports_drink": 0.3}',
   '1:1', '{}', '{}',
   'Best for ultra-long rides. Real food priority with gel bridging for quick carb hits. Shift rice cake -> gel ratio as race progresses.');

-- Template 15: Chew + Water (Cycling)
INSERT INTO public.during_workout_templates
  (template_number, name, formula, food_form, activity_types, duration_brackets,
   gut_training_levels, component_food_names, component_carb_ratios,
   primary_to_secondary_ratio, allergens, excluded_diets, notes)
VALUES
  (15, 'Chew + Water (Cycling)', 'Chew + Water',
   'Liquid + Gel/Chew',
   '{cycling,triathlon_bike}',
   '{90-150 min}',
   '{low,moderate,high}',
   '{energy_chews,water}',
   '{"energy_chews": 1.0}',
   NULL, '{}', '{}',
   'Cycling chew option for athletes who prefer chewing over gels. Easier to dose in small bites while riding. Low GI demand.');

-- Template 16: Chew + Water + Sports Drink (Cycling)
INSERT INTO public.during_workout_templates
  (template_number, name, formula, food_form, activity_types, duration_brackets,
   gut_training_levels, component_food_names, component_carb_ratios,
   primary_to_secondary_ratio, allergens, excluded_diets, notes)
VALUES
  (16, 'Chew + Water + Sports Drink (Cycling)', 'Chew + Water + Sports Drink',
   'Liquid + Gel/Chew',
   '{cycling,triathlon_bike}',
   '{90-150 min,150-240 min,> 240 min}',
   '{moderate,high}',
   '{energy_chews,water,sports_drink}',
   '{"energy_chews": 0.7, "sports_drink": 0.3}',
   NULL, '{}', '{}',
   'Dual carb source on the bike using chews instead of gels. Good for athletes with gel aversion. Chews easier to portion on long rides.');

-- Template 17: High Carb Drink Mix + Bar + Water (Cycling, high gut)
INSERT INTO public.during_workout_templates
  (template_number, name, formula, food_form, activity_types, duration_brackets,
   gut_training_levels, component_food_names, component_carb_ratios,
   primary_to_secondary_ratio, allergens, excluded_diets, notes)
VALUES
  (17, 'High Carb Drink Mix + Bar + Water', 'High Carb Drink Mix + Bar + Water',
   'Liquid + Solid',
   '{cycling,triathlon_bike}',
   '{150-240 min,> 240 min}',
   '{high}',
   '{high_carb_drink_mix,energy_bar,water}',
   '{"high_carb_drink_mix": 0.7, "energy_bar": 0.3}',
   NULL, '{}', '{}',
   'Pro-level fueling: max liquid carb density in the bottle + solid food on top. Requires very well-trained gut. Separate plain water bottle mandatory.');

-- Template 18: High Carb Drink Mix + Stroopwafel + Water (Cycling, high gut)
INSERT INTO public.during_workout_templates
  (template_number, name, formula, food_form, activity_types, duration_brackets,
   gut_training_levels, component_food_names, component_carb_ratios,
   primary_to_secondary_ratio, allergens, excluded_diets, notes)
VALUES
  (18, 'High Carb Drink Mix + Stroopwafel + Water',
   'High Carb Drink Mix + Stroopwafel + Water',
   'Liquid + Solid',
   '{cycling,triathlon_bike}',
   '{150-240 min,> 240 min}',
   '{high}',
   '{high_carb_drink_mix,stroopwafel,water}',
   '{"high_carb_drink_mix": 0.7, "stroopwafel": 0.3}',
   NULL, '{gluten,dairy}', '{vegan,gluten_free}',
   'High carb liquid base + palatable solid. Stroopwafel is easier to eat at tempo than bars. Warm on top tube. Plain water essential to manage osmolality.');

-- Template 19: High Carb Drink Mix + Banana + Water (Cycling, high gut)
INSERT INTO public.during_workout_templates
  (template_number, name, formula, food_form, activity_types, duration_brackets,
   gut_training_levels, component_food_names, component_carb_ratios,
   primary_to_secondary_ratio, allergens, excluded_diets, notes)
VALUES
  (19, 'High Carb Drink Mix + Banana + Water',
   'High Carb Drink Mix + Banana + Water',
   'Liquid + Solid',
   '{cycling,triathlon_bike}',
   '{150-240 min,> 240 min}',
   '{high}',
   '{high_carb_drink_mix,banana,water}',
   '{"high_carb_drink_mix": 0.7, "banana": 0.3}',
   NULL, '{}', '{}',
   'High carb liquid base + real food. Natural potassium from banana complements the drink mix. Pre-peel banana. Plain water bottle required.');

-- Template 20: High Carb Drink Mix + Rice Cake + Water (Cycling, high gut)
INSERT INTO public.during_workout_templates
  (template_number, name, formula, food_form, activity_types, duration_brackets,
   gut_training_levels, component_food_names, component_carb_ratios,
   primary_to_secondary_ratio, allergens, excluded_diets, notes)
VALUES
  (20, 'High Carb Drink Mix + Rice Cake + Water',
   'High Carb Drink Mix + Rice Cake + Water',
   'Liquid + Solid',
   '{cycling,triathlon_bike}',
   '{150-240 min,> 240 min}',
   '{high}',
   '{high_carb_drink_mix,rice_cake_during,water}',
   '{"high_carb_drink_mix": 0.7, "rice_cake_during": 0.3}',
   NULL, '{}', '{}',
   'Maximum fueling template: high carb liquid + savory solid. Breaks sweet monotony. Pro peloton staple for ultra-long rides and Ironman bike legs. Plain water mandatory.');


-- ============================================================================
-- STEP 3: Add rice_cake_during to template_foods
--
-- The existing rice_cake is a before-phase food. We need a during-specific
-- version with appropriate categories, activity_types, and constraints.
-- ============================================================================

INSERT INTO public.template_foods
  (name, display_name, display_name_plural, serving_size, serving_weight_g,
   calories, carbs_g, protein_g, fat_g, fiber_g, sodium_mg, fluid_ml,
   allergens, digestion_speed, is_active,
   excluded_diets, product_type, activity_types, categories,
   show_in_preferences, is_essential, is_electrolyte, requires_preparation,
   caffeine_mg, potassium_mg, is_drink_pool, drink_pool_phases, is_liquid,
   max_servings_before, max_servings_during, max_servings_after,
   to_exclude_from_solver, is_indivisible, default_during, min_servings_during,
   max_per_hr_low, max_per_hr_moderate, max_per_hr_high, min_increment,
   serving_amount, serving_unit, description)
VALUES
  ('rice_cake_during', 'Rice Cake', 'Rice Cakes', '1 rice cake', 60.0,
   180, 35.0, 2.0, 3.0, 0.5, 100.0, 0.0,
   '{}', 'medium', true,
   '{keto,low_carb}', 'real_food', '{cycling}', '{during_bike}',
   true, false, false, true,
   0.0, 50.0, false, '{}', false,
   0, 4, 0,
   false, false, true, 0.5,
   1, 1, 2, 0.5,
   1, 'rice cake', 'Homemade rice cake with sticky rice, salt, and optional mix-ins. Pro peloton staple for long rides.')
ON CONFLICT (name) DO NOTHING;

-- SECTION 3: Sodium top-up eligibility

-- ============================================================================
-- During-workout sodium top-up eligibility
-- ============================================================================
-- Separates carb-delivery drinks from true sodium top-up products.
-- Sports drink and high-carb drink mix may still appear when a template's carb
-- ratios explicitly include them, but they should not be selected as generic
-- electrolyte fillers.

ALTER TABLE public.template_foods
  ADD COLUMN IF NOT EXISTS sodium_top_up_eligible BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN public.template_foods.sodium_top_up_eligible
  IS 'Whether this food may be used as a generic sodium top-up in during-workout template solving. Carb-delivery drinks should remain false and only be used when explicitly present in a template.';

UPDATE public.template_foods
  SET sodium_top_up_eligible = true
  WHERE is_electrolyte = true
    AND COALESCE(sodium_mg, 0) > 0
    AND COALESCE(carbs_g, 0) <= 5
    AND name NOT IN ('sports_drink', 'high_carb_drink_mix')
    AND COALESCE(product_type, '') <> 'sports_drink';

UPDATE public.template_foods
  SET sodium_top_up_eligible = false
  WHERE name IN (
    'sports_drink',
    'sports_drink_mix',
    'electrolyte_drink_mix',
    'high_carb_drink_mix'
  )
    OR COALESCE(carbs_g, 0) > 5;

-- SECTION 4: Carb drink mix and high-carb drink mix split

-- ============================================================================
-- Split moderate carb drink mix from high-carb drink mix
-- ============================================================================
-- The existing high_carb_drink_mix row was a 60g packet. The during-workout
-- template docs define high-carb drink mix as an 80-100g prepared bottle.
-- Keep a 60g option as carb_drink_mix for moderate/high long rides, and make
-- high_carb_drink_mix the high-gut 90g bottle option.

ALTER TABLE public.during_workout_templates
  ADD COLUMN IF NOT EXISTS selection_priority INTEGER NOT NULL DEFAULT 0;

COMMENT ON COLUMN public.during_workout_templates.selection_priority
  IS 'Catalog-driven tie breaker for template selection. Higher values are tried before lower values after activity, duration, gut, diet, allergy, and preference filtering.';

-- 60g/bottle option: useful for moderate and high gut athletes on long bike
-- workouts without treating it as a generic sodium filler.
INSERT INTO public.template_foods
  (name, display_name, display_name_plural, serving_size, serving_weight_g,
   calories, carbs_g, protein_g, fat_g, fiber_g, sodium_mg, fluid_ml,
   allergens, digestion_speed, is_active,
   excluded_diets, product_type, activity_types, categories,
   show_in_preferences, is_essential, is_electrolyte, requires_preparation,
   caffeine_mg, potassium_mg, is_drink_pool, drink_pool_phases, is_liquid,
   max_servings_before, max_servings_during, max_servings_after,
   to_exclude_from_solver, is_indivisible, default_during, min_servings_during,
   max_per_hr_low, max_per_hr_moderate, max_per_hr_high, min_increment,
   serving_amount, serving_unit, description, sodium_top_up_eligible)
VALUES
  ('carb_drink_mix', 'Carb Drink Mix', 'packets Carb Drink Mix',
   '1 packet (60g carbs in 16-20 oz water)', NULL,
   240, 60.0, 0.0, 0.0, 0.0, 160.0, 500.0,
   '{}', 'medium', TRUE,
   '{}', 'drink_mix', '{running,cycling}', '{during_bike,during_run,during_swim,transition}',
   TRUE, FALSE, FALSE, FALSE,
   0.0, 0.0, FALSE, '{}', TRUE,
   0, 10, 0,
   FALSE, FALSE, TRUE, 0.5,
   0, 1, 1, 0.5,
   1, 'packet', 'Moderate-concentration carbohydrate drink mix. One packet provides about 60g carbs in a prepared bottle.',
   FALSE)
ON CONFLICT (name) DO UPDATE SET
  display_name = EXCLUDED.display_name,
  display_name_plural = EXCLUDED.display_name_plural,
  serving_size = EXCLUDED.serving_size,
  calories = EXCLUDED.calories,
  carbs_g = EXCLUDED.carbs_g,
  sodium_mg = EXCLUDED.sodium_mg,
  fluid_ml = EXCLUDED.fluid_ml,
  digestion_speed = EXCLUDED.digestion_speed,
  excluded_diets = EXCLUDED.excluded_diets,
  product_type = EXCLUDED.product_type,
  activity_types = EXCLUDED.activity_types,
  categories = EXCLUDED.categories,
  show_in_preferences = EXCLUDED.show_in_preferences,
  is_electrolyte = EXCLUDED.is_electrolyte,
  is_liquid = EXCLUDED.is_liquid,
  max_servings_during = EXCLUDED.max_servings_during,
  default_during = EXCLUDED.default_during,
  min_servings_during = EXCLUDED.min_servings_during,
  max_per_hr_low = EXCLUDED.max_per_hr_low,
  max_per_hr_moderate = EXCLUDED.max_per_hr_moderate,
  max_per_hr_high = EXCLUDED.max_per_hr_high,
  min_increment = EXCLUDED.min_increment,
  serving_amount = EXCLUDED.serving_amount,
  serving_unit = EXCLUDED.serving_unit,
  description = EXCLUDED.description,
  sodium_top_up_eligible = EXCLUDED.sodium_top_up_eligible,
  updated_at = NOW();

-- True high-carb bottle option: high gut only, matching the template docs.
UPDATE public.template_foods
  SET display_name = 'High-Carb Drink Mix',
      display_name_plural = 'packets High-Carb Drink Mix',
      serving_size = '1 packet (90g carbs in 20-24 oz water)',
      calories = 360,
      carbs_g = 90.0,
      sodium_mg = 200.0,
      fluid_ml = 600.0,
      digestion_speed = 'medium',
      product_type = 'drink_mix',
      activity_types = '{running,cycling}',
      categories = '{during_bike,during_run,during_swim,transition}',
      show_in_preferences = TRUE,
      is_electrolyte = FALSE,
      is_liquid = TRUE,
      max_servings_during = 10,
      default_during = TRUE,
      min_servings_during = 0.5,
      max_per_hr_low = 0,
      max_per_hr_moderate = 0,
      max_per_hr_high = 1,
      min_increment = 0.5,
      serving_amount = 1,
      serving_unit = 'packet',
      description = 'High-carb drink mix for well-trained guts. One packet provides about 90g carbs in a prepared bottle.',
      sodium_top_up_eligible = FALSE,
      updated_at = NOW()
  WHERE name = 'high_carb_drink_mix';

-- Prefer the high-gut high-carb templates over lower-density bike templates
-- when they are eligible.
UPDATE public.during_workout_templates
  SET selection_priority = 40
  WHERE template_number IN (17, 18, 19, 20);

-- Moderate/high long-bike carb-drink templates. These use the 60g bottle, so
-- moderate athletes can reach high long-ride targets without opening the
-- high-carb 90g bottle templates.
INSERT INTO public.during_workout_templates
  (template_number, name, formula, food_form, activity_types, duration_brackets,
   gut_training_levels, component_food_names, component_carb_ratios,
   primary_to_secondary_ratio, allergens, excluded_diets, notes,
   selection_priority)
VALUES
  (21, 'Carb Drink Mix + Bar + Water',
   'Carb Drink Mix + Bar + Water',
   'Liquid + Solid',
   '{cycling,triathlon_bike}',
   '{150-240 min,> 240 min}',
   '{moderate,high}',
   '{carb_drink_mix,energy_bar,water}',
   '{"carb_drink_mix": 0.7, "energy_bar": 0.3}',
   NULL, '{}', '{}',
   'Moderate long-ride bottle option: 60g carb drink mix plus small bites of bar and separate plain water.',
   30),
  (22, 'Carb Drink Mix + Stroopwafel + Water',
   'Carb Drink Mix + Stroopwafel + Water',
   'Liquid + Solid',
   '{cycling,triathlon_bike}',
   '{150-240 min,> 240 min}',
   '{moderate,high}',
   '{carb_drink_mix,stroopwafel,water}',
   '{"carb_drink_mix": 0.7, "stroopwafel": 0.3}',
   NULL, '{gluten,dairy}', '{vegan,gluten_free}',
   'Moderate long-ride bottle option with a palatable solid. Plain water remains separate for rinsing and hydration.',
   30),
  (23, 'Carb Drink Mix + Banana + Water',
   'Carb Drink Mix + Banana + Water',
   'Liquid + Solid',
   '{cycling,triathlon_bike}',
   '{150-240 min,> 240 min}',
   '{moderate,high}',
   '{carb_drink_mix,banana,water}',
   '{"carb_drink_mix": 0.7, "banana": 0.3}',
   NULL, '{}', '{}',
   'Moderate long-ride bottle option with real-food carbohydrate. Use early when intensity is lower.',
   30),
  (24, 'Carb Drink Mix + Rice Cake + Water',
   'Carb Drink Mix + Rice Cake + Water',
   'Liquid + Solid',
   '{cycling,triathlon_bike}',
   '{150-240 min,> 240 min}',
   '{moderate,high}',
   '{carb_drink_mix,rice_cake_during,water}',
   '{"carb_drink_mix": 0.7, "rice_cake_during": 0.3}',
   NULL, '{}', '{}',
   'Moderate long-ride bottle option with savory solid food. Plain water is still required alongside the carb bottle.',
   30)
ON CONFLICT (template_number) DO UPDATE SET
  name = EXCLUDED.name,
  formula = EXCLUDED.formula,
  food_form = EXCLUDED.food_form,
  activity_types = EXCLUDED.activity_types,
  duration_brackets = EXCLUDED.duration_brackets,
  gut_training_levels = EXCLUDED.gut_training_levels,
  component_food_names = EXCLUDED.component_food_names,
  component_carb_ratios = EXCLUDED.component_carb_ratios,
  primary_to_secondary_ratio = EXCLUDED.primary_to_secondary_ratio,
  allergens = EXCLUDED.allergens,
  excluded_diets = EXCLUDED.excluded_diets,
  notes = EXCLUDED.notes,
  selection_priority = EXCLUDED.selection_priority,
  updated_at = NOW();
