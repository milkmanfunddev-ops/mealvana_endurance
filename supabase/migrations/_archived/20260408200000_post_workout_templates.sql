-- ============================================================================
-- Migration: Create post_workout_templates table + seed 20 recovery templates
--
-- Follows the during_workout_templates pattern:
--   - component_food_names TEXT[] references template_foods.name values
--   - component_ratios JSONB maps food names to their portion share
--   - Public SELECT, service_role INSERT/UPDATE/DELETE
--
-- Source: docs/features/food_templates/research/post_workout_templates_plan.md
-- Date: 2026-04-08
-- ============================================================================

-- ============================================================================
-- STEP 1: Create table
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.post_workout_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_number INTEGER NOT NULL UNIQUE,
  name TEXT NOT NULL,
  formula TEXT NOT NULL,
  recovery_window TEXT NOT NULL CHECK (recovery_window IN ('immediate', 'meal')),
  recovery_type TEXT NOT NULL CHECK (recovery_type IN ('shake', 'smoothie', 'bowl', 'sandwich', 'snack', 'meal')),
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

-- Indexes
CREATE INDEX IF NOT EXISTS idx_pwt_active
  ON public.post_workout_templates (is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_pwt_activity_types
  ON public.post_workout_templates USING GIN (activity_types);
CREATE INDEX IF NOT EXISTS idx_pwt_recovery_window
  ON public.post_workout_templates (recovery_window);
CREATE INDEX IF NOT EXISTS idx_pwt_template_number
  ON public.post_workout_templates (template_number);

-- RLS: public read access (templates are not user-specific)
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

COMMENT ON TABLE public.post_workout_templates
  IS 'Formula templates for post-workout recovery nutrition. Each template defines a food combination for a specific recovery window and workout context.';

COMMENT ON COLUMN public.post_workout_templates.component_food_names
  IS 'Array of template_foods.name values that compose this template formula.';

COMMENT ON COLUMN public.post_workout_templates.component_ratios
  IS 'JSONB mapping food names to their target share of total carb/calorie allocation.';

COMMENT ON COLUMN public.post_workout_templates.recovery_window
  IS 'immediate = 0-30 min post-workout (liquids/easy foods). meal = 30-120 min (full meals).';

COMMENT ON COLUMN public.post_workout_templates.target_carb_protein_ratio
  IS 'Target carb:protein ratio for this template (e.g. "4:1", "3:1", "2:1").';


-- ============================================================================
-- STEP 2: Seed templates (1-20)
-- ============================================================================

-- Clear any existing rows in case of re-run
DELETE FROM public.post_workout_templates
  WHERE template_number BETWEEN 1 AND 20;


-- ==========================================================================
-- IMMEDIATE RECOVERY (0-30 min) — Templates 1-10
-- ==========================================================================

-- Template 1: Classic Chocolate Milk
INSERT INTO public.post_workout_templates
  (template_number, name, formula, recovery_window, recovery_type,
   activity_types, workout_intensity, component_food_names, component_ratios,
   target_carb_protein_ratio, allergens, excluded_diets, notes)
VALUES
  (1, 'Classic Chocolate Milk',
   'Low-fat chocolate milk (16 oz)',
   'immediate', 'shake',
   '{running,cycling,swimming,triathlon}',
   '{easy,moderate,hard}',
   '{chocolate_milk}',
   '{"chocolate_milk": 1.0}',
   '3:1',
   '{dairy}', '{vegan,paleo}',
   'Most research-validated recovery drink. 20+ studies confirm equal/superior to commercial products. Natural 3:1 carb:protein ratio. Budget-friendly (~$1.50). Used by: Sam Long, Reddit #1 recommendation. Source: European Journal of Clinical Nutrition meta-analysis 2018.');

-- Template 2: Banana Berry Protein Smoothie
INSERT INTO public.post_workout_templates
  (template_number, name, formula, recovery_window, recovery_type,
   activity_types, workout_intensity, component_food_names, component_ratios,
   target_carb_protein_ratio, allergens, excluded_diets, notes)
VALUES
  (2, 'Banana Berry Protein Smoothie',
   'Banana + Mixed Berries + Whey Protein + Greek Yogurt',
   'immediate', 'smoothie',
   '{running,cycling,swimming,triathlon}',
   '{moderate,hard}',
   '{banana,mixed_berries,whey_protein_powder,greek_yogurt}',
   '{"banana": 0.35, "mixed_berries": 0.20, "whey_protein_powder": 0.05, "greek_yogurt": 0.10}',
   '2:1',
   '{dairy}', '{vegan}',
   'Antioxidant-rich from berries. Whey provides ~3g leucine. Greek yogurt adds casein (slow-release). Used by: Frodeno, Lionel Sanders (smoothie bowl variant). Prep tip: freeze banana + berries in bags.');

-- Template 3: Tart Cherry Recovery Shake
INSERT INTO public.post_workout_templates
  (template_number, name, formula, recovery_window, recovery_type,
   activity_types, workout_intensity, component_food_names, component_ratios,
   target_carb_protein_ratio, allergens, excluded_diets, notes)
VALUES
  (3, 'Tart Cherry Recovery Shake',
   'Tart Cherry Juice + Whey Protein',
   'immediate', 'shake',
   '{running,cycling,triathlon}',
   '{hard,race}',
   '{tart_cherry_juice,whey_protein_powder}',
   '{"tart_cherry_juice": 0.85, "whey_protein_powder": 0.15}',
   '2:1',
   '{dairy}', '{vegan}',
   'Anti-inflammatory powerhouse. Anthocyanins reduce CRP by up to 49%. Best for hard sessions/race recovery. Most effective with 7-10 day pre-loading. Research: JISSN 2010, Howatson et al. 2010.');

-- Template 4: Recovery Protein Shake (Commercial)
INSERT INTO public.post_workout_templates
  (template_number, name, formula, recovery_window, recovery_type,
   activity_types, workout_intensity, component_food_names, component_ratios,
   target_carb_protein_ratio, allergens, excluded_diets, notes)
VALUES
  (4, 'Recovery Protein Shake (Commercial)',
   'Recovery Drink Mix + Water',
   'immediate', 'shake',
   '{running,cycling,swimming,triathlon}',
   '{easy,moderate,hard}',
   '{recovery_drink_mix,water}',
   '{"recovery_drink_mix": 1.0}',
   '3:1',
   '{dairy}', '{vegan}',
   'Precise macros, pre-measured. Brands: Skratch Recovery (4:1), Hammer Recoverite (3:1), Tailwind Rebuild (2:1 vegan). Portable powder for travel. TrainerRoad podcast consistent recommendation.');

-- Template 5: Greek Yogurt Parfait
INSERT INTO public.post_workout_templates
  (template_number, name, formula, recovery_window, recovery_type,
   activity_types, workout_intensity, component_food_names, component_ratios,
   target_carb_protein_ratio, allergens, excluded_diets, notes)
VALUES
  (5, 'Greek Yogurt Parfait',
   'Greek Yogurt + Granola + Berries + Honey',
   'immediate', 'snack',
   '{running,cycling,swimming,triathlon}',
   '{easy,moderate}',
   '{greek_yogurt,granola,mixed_berries,honey}',
   '{"greek_yogurt": 0.15, "granola": 0.45, "mixed_berries": 0.25, "honey": 0.15}',
   '2.5:1',
   '{dairy,gluten}', '{vegan}',
   'Solid food option. Greek yogurt = leucine-rich (17g protein/cup). Make-ahead in mason jar. Daniela Ryf (bircher muesli variant), Gustav Iden (skyr variant). Reddit favorite.');

-- Template 6: Bagel + Nut Butter + Banana
INSERT INTO public.post_workout_templates
  (template_number, name, formula, recovery_window, recovery_type,
   activity_types, workout_intensity, component_food_names, component_ratios,
   target_carb_protein_ratio, allergens, excluded_diets, notes)
VALUES
  (6, 'Bagel + Nut Butter + Banana',
   'Bagel + Peanut Butter + Banana + Low-Fat Milk',
   'immediate', 'snack',
   '{running,cycling,triathlon}',
   '{moderate,hard}',
   '{bagel_large,peanut_butter,banana,milk_lowfat}',
   '{"bagel_large": 0.50, "peanut_butter": 0.05, "banana": 0.25, "milk_lowfat": 0.20}',
   '3:1',
   '{gluten,peanuts,dairy}', '{vegan}',
   'Dense carb source (60g+ per bagel). Solid food for chewing preference. Triathlete Mag: 475 cal, ideal ratio. Slowtwitch staple. Lower-fat variant: PB2 powder.');

-- Template 7: Core Power Shake (Grab-and-Go)
INSERT INTO public.post_workout_templates
  (template_number, name, formula, recovery_window, recovery_type,
   activity_types, workout_intensity, component_food_names, component_ratios,
   target_carb_protein_ratio, allergens, excluded_diets, notes)
VALUES
  (7, 'Core Power Shake (Grab-and-Go)',
   'Core Power Elite Protein Shake',
   'immediate', 'shake',
   '{running,cycling,swimming,triathlon}',
   '{moderate,hard}',
   '{core_power_shake}',
   '{"core_power_shake": 1.0}',
   '1:1',
   '{dairy}', '{vegan,paleo}',
   'Zero prep. Gas stations/convenience stores. Ultra-filtered milk (42g protein). Travel/race morning perfect. Used by: Lionel Sanders, Slowtwitch consensus. Long shelf life.');

-- Template 8: Oatmeal + Protein + Fruit
INSERT INTO public.post_workout_templates
  (template_number, name, formula, recovery_window, recovery_type,
   activity_types, workout_intensity, component_food_names, component_ratios,
   target_carb_protein_ratio, allergens, excluded_diets, notes)
VALUES
  (8, 'Oatmeal + Protein + Fruit',
   'Oatmeal + Whey Protein + Banana + Honey',
   'immediate', 'snack',
   '{running,cycling,swimming,triathlon}',
   '{moderate,hard}',
   '{oatmeal,whey_protein_powder,banana,honey}',
   '{"oatmeal": 0.40, "whey_protein_powder": 0.05, "banana": 0.35, "honey": 0.20}',
   '3:1',
   '{gluten,dairy}', '{vegan}',
   'Dual carb source: complex (oats) + simple (banana, honey). Warming comfort food. Gustav Iden porridge staple. Kodiak cups for convenience. Post-morning-swim popular.');

-- Template 9: Plant-Based Recovery Smoothie
INSERT INTO public.post_workout_templates
  (template_number, name, formula, recovery_window, recovery_type,
   activity_types, workout_intensity, component_food_names, component_ratios,
   target_carb_protein_ratio, allergens, excluded_diets, notes)
VALUES
  (9, 'Plant-Based Recovery Smoothie',
   'Banana + Mixed Berries + Plant Protein + Oat Milk',
   'immediate', 'smoothie',
   '{running,cycling,swimming,triathlon}',
   '{moderate,hard}',
   '{banana,mixed_berries,plant_protein_powder,oat_milk}',
   '{"banana": 0.35, "mixed_berries": 0.20, "plant_protein_powder": 0.10, "oat_milk": 0.35}',
   '2:1',
   '{gluten}', '{paleo}',
   'Fully vegan/plant-based. Pea+rice protein = complete amino acids. Cody Beals uses Vega Sport protein. May need slightly more total protein (30-35g) due to lower leucine density.');

-- Template 10: PB&J + Milk (Classic)
INSERT INTO public.post_workout_templates
  (template_number, name, formula, recovery_window, recovery_type,
   activity_types, workout_intensity, component_food_names, component_ratios,
   target_carb_protein_ratio, allergens, excluded_diets, notes)
VALUES
  (10, 'PB&J + Milk (Classic)',
   'Whole Wheat Bread + Peanut Butter + Jam + Low-Fat Milk',
   'immediate', 'snack',
   '{running,cycling,triathlon}',
   '{easy,moderate,hard}',
   '{whole_wheat_bread,peanut_butter,jam,milk_lowfat}',
   '{"whole_wheat_bread": 0.30, "peanut_butter": 0.10, "jam": 0.15, "milk_lowfat": 0.45}',
   '3:1',
   '{gluten,peanuts,dairy}', '{vegan}',
   'Universal, budget-friendly (~$2). Reddit r/running #5 most popular. Allen Lim / Skratch Labs: "perfect real food recovery." Comfort factor. Can eat half now, half later.');


-- ==========================================================================
-- RECOVERY MEALS (30-120 min) — Templates 11-20
-- ==========================================================================

-- Template 11: Chicken Sweet Potato Bowl
INSERT INTO public.post_workout_templates
  (template_number, name, formula, recovery_window, recovery_type,
   activity_types, workout_intensity, component_food_names, component_ratios,
   target_carb_protein_ratio, allergens, excluded_diets, notes)
VALUES
  (11, 'Chicken Sweet Potato Bowl',
   'Grilled Chicken + Sweet Potato + Rice + Broccoli',
   'meal', 'bowl',
   '{running,cycling,swimming,triathlon}',
   '{moderate,hard}',
   '{grilled_chicken,sweet_potato,white_rice_cooked,broccoli}',
   '{"grilled_chicken": 0.05, "sweet_potato": 0.25, "white_rice_cooked": 0.40, "broccoli": 0.05}',
   '2:1',
   '{}', '{vegan,vegetarian}',
   'Complete meal. Meal-prep friendly (cook Sunday, portion containers). Chicken = lean, high leucine. Lucy Charles rice bowl variant. Allen Lim Feed Zone staple.');

-- Template 12: Salmon Rice Bowl
INSERT INTO public.post_workout_templates
  (template_number, name, formula, recovery_window, recovery_type,
   activity_types, workout_intensity, component_food_names, component_ratios,
   target_carb_protein_ratio, allergens, excluded_diets, notes)
VALUES
  (12, 'Salmon Rice Bowl',
   'Salmon + Rice + Avocado + Vegetables',
   'meal', 'bowl',
   '{running,cycling,swimming,triathlon}',
   '{hard,race}',
   '{salmon,white_rice_cooked,avocado,mixed_vegetables}',
   '{"salmon": 0.05, "white_rice_cooked": 0.45, "avocado": 0.10, "mixed_vegetables": 0.05}',
   '2:1',
   '{fish}', '{vegan,vegetarian}',
   'Anti-inflammatory focus — omega-3 from salmon. Blumenfeld and Iden eat salmon 3-4x/week. Avocado adds healthy fats + potassium. Budget: canned salmon works.');

-- Template 13: Breakfast Burrito
INSERT INTO public.post_workout_templates
  (template_number, name, formula, recovery_window, recovery_type,
   activity_types, workout_intensity, component_food_names, component_ratios,
   target_carb_protein_ratio, allergens, excluded_diets, notes)
VALUES
  (13, 'Breakfast Burrito',
   'Whole Wheat Tortilla + Scrambled Eggs + Black Beans + Cheese',
   'meal', 'sandwich',
   '{running,cycling,triathlon}',
   '{moderate,hard}',
   '{whole_wheat_tortilla,scrambled_eggs,black_beans,cheddar_cheese}',
   '{"whole_wheat_tortilla": 0.30, "scrambled_eggs": 0.10, "black_beans": 0.30, "cheddar_cheese": 0.05}',
   '2:1',
   '{gluten,eggs,dairy}', '{vegan}',
   'Morning workout recovery. Eggs = complete protein + leucine. Freezer-friendly: batch 5-7, wrap foil, freeze. Microwave 2-3 min from frozen. Portable.');

-- Template 14: Burrito Bowl (Chipotle-Style)
INSERT INTO public.post_workout_templates
  (template_number, name, formula, recovery_window, recovery_type,
   activity_types, workout_intensity, component_food_names, component_ratios,
   target_carb_protein_ratio, allergens, excluded_diets, notes)
VALUES
  (14, 'Burrito Bowl (Chipotle-Style)',
   'Rice + Chicken + Black Beans + Vegetables + Salsa',
   'meal', 'bowl',
   '{running,cycling,swimming,triathlon}',
   '{moderate,hard}',
   '{white_rice_cooked,grilled_chicken,black_beans,salsa}',
   '{"white_rice_cooked": 0.45, "grilled_chicken": 0.05, "black_beans": 0.25, "salsa": 0.05}',
   '2:1',
   '{}', '{vegan,vegetarian}',
   'Available at Chipotle/Qdoba nationwide. No cooking required. Popular post-race meal. Reddit r/triathlon recommendation. Order: rice, chicken, black beans, fajita veggies, mild salsa.');

-- Template 15: Pasta + Lean Protein
INSERT INTO public.post_workout_templates
  (template_number, name, formula, recovery_window, recovery_type,
   activity_types, workout_intensity, component_food_names, component_ratios,
   target_carb_protein_ratio, allergens, excluded_diets, notes)
VALUES
  (15, 'Pasta + Lean Protein',
   'Pasta + Marinara + Grilled Chicken',
   'meal', 'meal',
   '{running,cycling,triathlon}',
   '{hard,race}',
   '{pasta_cooked,marinara_sauce,grilled_chicken}',
   '{"pasta_cooked": 0.55, "marinara_sauce": 0.10, "grilled_chicken": 0.05}',
   '3:1',
   '{gluten}', '{vegan,vegetarian}',
   'Classic endurance recovery meal. Lionel Sanders post-long-ride staple. Dense carbs for aggressive glycogen restoration. Marinara = lycopene (antioxidant). Easy to meal-prep.');

-- Template 16: Recovery Beef Jerky + Trail Mix
INSERT INTO public.post_workout_templates
  (template_number, name, formula, recovery_window, recovery_type,
   activity_types, workout_intensity, component_food_names, component_ratios,
   target_carb_protein_ratio, allergens, excluded_diets, notes)
VALUES
  (16, 'Recovery Beef Jerky + Trail Mix',
   'Beef Jerky + Trail Mix + Sports Drink',
   'meal', 'snack',
   '{running,cycling,triathlon}',
   '{hard,race}',
   '{beef_jerky,trail_mix,sports_drink}',
   '{"beef_jerky": 0.05, "trail_mix": 0.55, "sports_drink": 0.40}',
   '2:1',
   '{tree_nuts}', '{vegan,vegetarian}',
   'Portable, no refrigeration. Salty — replaces sodium. High leucine from jerky. Ultra-marathon/triathlon athletes. Slowtwitch recommendation for post-race without kitchen. Dark chocolate in trail mix = antioxidants.');

-- Template 17: Eggs + Toast + Fruit
INSERT INTO public.post_workout_templates
  (template_number, name, formula, recovery_window, recovery_type,
   activity_types, workout_intensity, component_food_names, component_ratios,
   target_carb_protein_ratio, allergens, excluded_diets, notes)
VALUES
  (17, 'Eggs + Toast + Fruit',
   'Scrambled Eggs + Toast + Orange Juice',
   'meal', 'meal',
   '{running,cycling,swimming,triathlon}',
   '{easy,moderate}',
   '{scrambled_eggs,toast,orange_juice}',
   '{"scrambled_eggs": 0.05, "toast": 0.35, "orange_juice": 0.50}',
   '3:1',
   '{eggs,gluten}', '{vegan}',
   'Simple breakfast recovery after morning workouts. Eggs = complete protein. OJ = fast carbs + vitamin C + potassium. Easy to prepare (10 min). Reddit r/running favorite.');

-- Template 18: Rice + Stir-Fry + Tofu (Vegan)
INSERT INTO public.post_workout_templates
  (template_number, name, formula, recovery_window, recovery_type,
   activity_types, workout_intensity, component_food_names, component_ratios,
   target_carb_protein_ratio, allergens, excluded_diets, notes)
VALUES
  (18, 'Rice + Stir-Fry + Tofu (Vegan)',
   'Rice + Stir-Fry Vegetables + Tofu + Soy Sauce',
   'meal', 'bowl',
   '{running,cycling,swimming,triathlon}',
   '{moderate,hard}',
   '{white_rice_cooked,mixed_vegetables,tofu,soy_sauce}',
   '{"white_rice_cooked": 0.55, "mixed_vegetables": 0.10, "tofu": 0.15, "soy_sauce": 0.01}',
   '2:1',
   '{soy}', '{paleo}',
   'Fully vegan/plant-based. Cody Beals: plant-based stir fry after 6-hour ride. Soy sauce adds sodium. Meal-prep friendly. Can substitute tempeh for higher protein.');

-- Template 19: Avocado Toast + Eggs
INSERT INTO public.post_workout_templates
  (template_number, name, formula, recovery_window, recovery_type,
   activity_types, workout_intensity, component_food_names, component_ratios,
   target_carb_protein_ratio, allergens, excluded_diets, notes)
VALUES
  (19, 'Avocado Toast + Eggs',
   'Whole Grain Toast + Avocado + Scrambled Eggs',
   'meal', 'meal',
   '{running,cycling,swimming,triathlon}',
   '{easy,moderate}',
   '{whole_wheat_bread,avocado,scrambled_eggs}',
   '{"whole_wheat_bread": 0.35, "avocado": 0.20, "scrambled_eggs": 0.10}',
   '2:1',
   '{gluten,eggs}', '{vegan}',
   'Avocado = healthy fats + potassium. Eggs = complete protein. Cody Beals post-swim/run recovery. Good for lighter sessions. Bob Seebohar metabolic efficiency approach.');

-- Template 20: Overnight Oats + Protein
INSERT INTO public.post_workout_templates
  (template_number, name, formula, recovery_window, recovery_type,
   activity_types, workout_intensity, component_food_names, component_ratios,
   target_carb_protein_ratio, allergens, excluded_diets, notes)
VALUES
  (20, 'Overnight Oats + Protein',
   'Overnight Oats + Protein Powder + Berries + Nut Butter',
   'meal', 'snack',
   '{running,cycling,swimming,triathlon}',
   '{easy,moderate,hard}',
   '{oatmeal,whey_protein_powder,mixed_berries,almond_butter}',
   '{"oatmeal": 0.40, "whey_protein_powder": 0.05, "mixed_berries": 0.20, "almond_butter": 0.10}',
   '3:1',
   '{gluten,dairy,tree_nuts}', '{vegan}',
   'Zero post-workout prep — assemble night before. Beta-glucan from oats. TrainerRoad forum: prep smoothie bags before rides. Mason jar portability.');
