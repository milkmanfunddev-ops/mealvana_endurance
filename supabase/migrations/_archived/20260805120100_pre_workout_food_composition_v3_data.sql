-- ---------------------------------------------------------------------------
--  Source of truth: qa repo tag  pre-workout-food-composition@v1
--                   spec/fueling/pre-workout-food-composition.md  (food-composition v3,
--                   RATIFIED 2026-08-05)
--                   vectors/fueling/pre-workout-food-composition.json  (87 vectors)
--  Generated:       2026-08-05
--  Scope:           DEV. Replayable on prod -- every statement is idempotent.
-- ---------------------------------------------------------------------------
--  DATA. Regenerates the STANDARD pre-workout formula set from food-composition v3.
--
--  Touches ONLY pre_workout_templates (standard formulas) and template_foods.food_group.
--  Personal formulas live in separate tables -- personal_formulas and personal_templates --
--  and are never read or written here.
--
--  Requires 20260805120000_pre_workout_food_composition_v3_structure.sql first.
-- ---------------------------------------------------------------------------

begin;

-- ===========================================================================
-- 1 ── Layer A group assignment on the food catalog (section 3.1-3.9)
-- ===========================================================================
update template_foods set food_group = 'G7' where name = 'almond_butter';
update template_foods set food_group = 'G8' where name = 'apple';
update template_foods set food_group = 'G3' where name = 'applesauce';
update template_foods set food_group = 'G3' where name = 'applesauce_pouch';
update template_foods set food_group = 'G7' where name = 'avocado';
update template_foods set food_group = 'G1' where name = 'bagel';
update template_foods set food_group = 'G1' where name = 'bagel_large';
update template_foods set food_group = 'G2' where name = 'baked_potato';
update template_foods set food_group = 'G3' where name = 'banana';
update template_foods set food_group = 'G8' where name = 'blueberries';
update template_foods set food_group = 'G4a' where name = 'brown_sugar';
update template_foods set food_group = 'G7' where name = 'butter';
update template_foods set food_group = 'G4b' where name = 'carb_drink_mix';
update template_foods set food_group = 'G1' where name = 'cereal';
update template_foods set food_group = 'G7' where name = 'cheese_slice';
update template_foods set food_group = 'G5' where name = 'chicken';
update template_foods set food_group = 'G6' where name = 'chocolate_milk';
update template_foods set food_group = 'G5' where name = 'cottage_cheese';
update template_foods set food_group = 'G1' where name = 'crackers';
update template_foods set food_group = 'G7' where name = 'cream_cheese';
update template_foods set food_group = 'G9' where name = 'dates';
update template_foods set food_group = 'G5' where name = 'deli_turkey';
update template_foods set food_group = 'G9' where name = 'dried_mango';
update template_foods set food_group = 'G5' where name = 'egg';
update template_foods set food_group = 'G5' where name = 'eggs';
update template_foods set food_group = 'G4b' where name = 'electrolyte_drink_mix';
update template_foods set food_group = 'G8' where name = 'energy_bar';
update template_foods set food_group = 'G4b' where name = 'energy_chews';
update template_foods set food_group = 'G4b' where name = 'energy_chews_mini_pack';
update template_foods set food_group = 'G4b' where name = 'energy_gel';
update template_foods set food_group = 'G8' where name = 'fig_bar';
update template_foods set food_group = 'G1' where name = 'flour_tortilla';
update template_foods set food_group = 'G1' where name = 'graham_crackers';
update template_foods set food_group = 'G8' where name = 'granola';
update template_foods set food_group = 'G8' where name = 'granola_bar';
update template_foods set food_group = 'G8' where name = 'grapes';
update template_foods set food_group = 'G6' where name = 'greek_yogurt';
update template_foods set food_group = 'G4b' where name = 'high_carb_drink_mix';
update template_foods set food_group = 'G4a' where name = 'honey';
update template_foods set food_group = 'G4a' where name = 'jam';
update template_foods set food_group = 'G9' where name = 'mango_fresh';
update template_foods set food_group = 'G4a' where name = 'maple_syrup';
update template_foods set food_group = 'G6' where name = 'milk';
update template_foods set food_group = 'G8' where name = 'mixed_berries';
update template_foods set food_group = 'G7' where name = 'nutella';
update template_foods set food_group = 'G1' where name = 'oatmeal';
update template_foods set food_group = 'G8' where name = 'orange';
update template_foods set food_group = 'G3' where name = 'orange_juice';
update template_foods set food_group = 'G1' where name = 'pancake';
update template_foods set food_group = 'G3' where name = 'peaches';
update template_foods set food_group = 'G7' where name = 'peanut_butter';
update template_foods set food_group = 'G6' where name = 'plant_milk';
update template_foods set food_group = 'G5' where name = 'plant_protein_powder';
update template_foods set food_group = 'G5' where name = 'plant_protein_shake';
update template_foods set food_group = 'G5' where name = 'plant_protein_shake_rtd';
update template_foods set food_group = 'G1' where name = 'pop_tarts';
update template_foods set food_group = 'G1' where name = 'pretzels';
update template_foods set food_group = 'G8' where name = 'protein_bar';
update template_foods set food_group = 'G5' where name = 'protein_powder';
update template_foods set food_group = 'G5' where name = 'protein_shake';
update template_foods set food_group = 'G9' where name = 'raisins';
update template_foods set food_group = 'G1' where name = 'rice_cake';
update template_foods set food_group = 'G1' where name = 'rice_cake_during';
update template_foods set food_group = 'G4b' where name = 'sports_drink';
update template_foods set food_group = 'G4b' where name = 'sports_drink_mix';
update template_foods set food_group = 'G8' where name = 'strawberries';
update template_foods set food_group = 'G7' where name = 'string_cheese';
update template_foods set food_group = 'G1' where name = 'stroopwafel';
update template_foods set food_group = 'G2' where name = 'sweet_potato';
update template_foods set food_group = 'G1' where name = 'toast';
update template_foods set food_group = 'G1' where name = 'toaster_waffle';
update template_foods set food_group = 'G7' where name = 'trail_mix';
update template_foods set food_group = 'G5' where name = 'turkey_deli';
update template_foods set food_group = 'G3' where name = 'watermelon';
update template_foods set food_group = 'G5' where name = 'whey_protein_powder';
update template_foods set food_group = 'G5' where name = 'whey_protein_shake_rtd';
update template_foods set food_group = 'G1' where name = 'white_rice';
update template_foods set food_group = 'G8' where name = 'whole_wheat_bread';
update template_foods set food_group = 'G6' where name = 'yogurt';

-- ===========================================================================
-- 2 ── time-window remap (section 2: the window moved from 90 min to 2 h)
-- ===========================================================================
update pre_workout_templates set time_window = '2-4 hours'  where time_window = '1.5-3 hours';
update pre_workout_templates set time_window = '30-120 min' where time_window = '30-90 min';
-- '< 30 min' (top-off) is unchanged.

-- ===========================================================================
-- 3 ── DELETIONS: standard formulas that violate a HARD gate
--
--      Parent rows only -- composition lives in pre_workout_templates.component_food_names
--      and component_quantities, so there are no child rows to orphan.
--
--      User data is deliberately NOT cascaded. formula_pins and personal_formulas rows
--      that point at these ids are left in place; see the report for the affected list.
-- ===========================================================================
-- Fruit Bowl (1.5-3 hours) -- H2 fibre 8.9 g > 8 g meal floor at 65 kg
delete from pre_workout_templates where name = 'Fruit Bowl';

-- Dates + Banana (30-90 min) -- H2 fibre 6.3 g > 4 g snack floor (also fails at 95 kg: 6.3 > 5.7)
delete from pre_workout_templates where name = 'Dates + Banana';

-- Bagel + Peanut Butter (30-90 min) -- Matrix: G7 added fats are AVOID at snack (3.10); also H1 fat 8 g > 7 g
delete from pre_workout_templates where name = 'Bagel + Peanut Butter';

-- Toast + Peanut Butter (30-90 min) -- Matrix: G7 added fats are AVOID at snack (3.10); also H1 fat 8 g > 7 g
delete from pre_workout_templates where name = 'Toast + Peanut Butter';

-- Rice Cake + Peanut Butter (30-90 min) -- Matrix: G7 added fats are AVOID at snack (3.10)
delete from pre_workout_templates where name = 'Rice Cake + Peanut Butter';

-- Granola Bar (30-90 min) -- Matrix: G8 high-residue whole foods are AVOID at snack (3.10)
delete from pre_workout_templates where name = 'Granola Bar';

-- Smoothie (Fruit) (30-90 min) -- Matrix: G8 raw berries (blueberries) are AVOID at snack (3.10)
delete from pre_workout_templates where name = 'Smoothie (Fruit)';

-- Coconut Water (< 30 min) -- H2 fibre 2.6 g > 2 g flat top-off ceiling
delete from pre_workout_templates where name = 'Coconut Water';

-- ===========================================================================
-- 4 ── per-serving fibre backfill (H2 cannot be evaluated without it)
-- ===========================================================================
update pre_workout_templates set fiber_per_serving = 0.0 where name = 'Electrolyte Drink Mix';
update pre_workout_templates set fiber_per_serving = 0.0 where name = 'Electrolyte Packet';
update pre_workout_templates set fiber_per_serving = 0.0 where name = 'Electrolyte Tablet';
update pre_workout_templates set fiber_per_serving = 0.0 where name = 'Water';
update pre_workout_templates set fiber_per_serving = 0.0 where name = 'Sports Drink';
update pre_workout_templates set fiber_per_serving = 0.0 where name = 'Energy Chews';
update pre_workout_templates set fiber_per_serving = 0.0 where name = 'Energy Gel';
update pre_workout_templates set fiber_per_serving = 2.0 where name = 'Bagel + PB + Jam';
update pre_workout_templates set fiber_per_serving = 1.1 where name = 'Bagel + Cream Cheese';
update pre_workout_templates set fiber_per_serving = 0.8 where name = 'Cereal + Milk';
update pre_workout_templates set fiber_per_serving = 4.0 where name = 'Oatmeal';
update pre_workout_templates set fiber_per_serving = 4.3 where name = 'Oatmeal + Raisins';
update pre_workout_templates set fiber_per_serving = 3.8 where name = 'Potato + Salt';
update pre_workout_templates set fiber_per_serving = 0.9 where name = 'Rice Cake + PB + Jam';
update pre_workout_templates set fiber_per_serving = 1.5 where name = 'Toast + PB + Jam';
update pre_workout_templates set fiber_per_serving = 3.7 where name = 'Rice + Banana';
update pre_workout_templates set fiber_per_serving = 0.9 where name = 'Yogurt + Granola';
update pre_workout_templates set fiber_per_serving = 1.2 where name = 'Bagel + Jam';
update pre_workout_templates set fiber_per_serving = 3.1 where name = 'Banana';
update pre_workout_templates set fiber_per_serving = 0.8 where name = 'OJ + Toast';
update pre_workout_templates set fiber_per_serving = 0.5 where name = 'Rice Cake + Jam';
update pre_workout_templates set fiber_per_serving = 0.7 where name = 'Toast + Jam';

-- ===========================================================================
-- 5 ── NEW standard formulas
--
--      Every row is a COMPLETE record: all columns populated, and component_food_names
--      / component_quantities always non-empty so no parent exists without a composition.
--      Deterministic ids (uuid5) so dev and prod land on the same primary keys and the
--      insert is replayable.
-- ===========================================================================
-- Oatmeal + Banana + Honey  [2-4 hours]  -- SSOT 3.11 meal #1; worked example 7 row 1
--   summed feeding: 71.3 g carb, 6.4 g protein, 2.9 g fat, 7.1 g fibre, 2.0 mg Na
insert into pre_workout_templates (
  id, name, base_category, time_window, digestion_speed, allergens, serving_unit,
  min_servings, max_servings, plus_banana, plus_sports_drink, notes, is_active,
  carbs_per_serving, protein_per_serving, fat_per_serving, fiber_per_serving,
  sodium_mg, fluid_ml, template_type, component_food_names, component_quantities, excluded_diets
) values (
  '1e4ff584-ceed-58a8-809e-316c6850a3cc', 'Oatmeal + Banana + Honey', 'Oats / Granola', '2-4 hours', 'Medium', '{"Gluten"}', '0.5 cup dry oats + 1 banana + 1 tbsp honey',
  1, 2, false, false, 'Section 7 row 1: fibre 7.1 g against the 8 g floor is the tightest gate in the SSOT and passes.', true,
  71.3, 6.4, 2.9, 7.1,
  2.0, 292.0, 'food', '{"banana","honey","oatmeal"}', '{"oatmeal": 1, "banana": 1, "honey": 1}'::jsonb, '{"gluten_free","keto","low_carb"}'
)
on conflict (id) do update set
  name = excluded.name, base_category = excluded.base_category,
  time_window = excluded.time_window, digestion_speed = excluded.digestion_speed,
  allergens = excluded.allergens, serving_unit = excluded.serving_unit,
  min_servings = excluded.min_servings, max_servings = excluded.max_servings,
  notes = excluded.notes, is_active = excluded.is_active,
  carbs_per_serving = excluded.carbs_per_serving, protein_per_serving = excluded.protein_per_serving,
  fat_per_serving = excluded.fat_per_serving, fiber_per_serving = excluded.fiber_per_serving,
  sodium_mg = excluded.sodium_mg, fluid_ml = excluded.fluid_ml,
  template_type = excluded.template_type,
  component_food_names = excluded.component_food_names,
  component_quantities = excluded.component_quantities,
  excluded_diets = excluded.excluded_diets, updated_at = now();

-- Bagel + Jam + Juice  [2-4 hours]  -- SSOT 3.11 meal #2; worked example 7 row 2
--   summed feeding: 80.1 g carb, 7.4 g protein, 1.2 g fat, 2.0 g fibre, 245.0 mg Na
insert into pre_workout_templates (
  id, name, base_category, time_window, digestion_speed, allergens, serving_unit,
  min_servings, max_servings, plus_banana, plus_sports_drink, notes, is_active,
  carbs_per_serving, protein_per_serving, fat_per_serving, fiber_per_serving,
  sodium_mg, fluid_ml, template_type, component_food_names, component_quantities, excluded_diets
) values (
  'aee4c995-1741-5a47-bba3-53ad179d4644', 'Bagel + Jam + Juice', 'Bagel', '2-4 hours', 'Fast', '{"Gluten"}', '0.5 bagel + 2 tbsp jam + 1 cup juice',
  1, 2, false, false, 'Juice at the meal tier is NOT concentration-gated: H6 is scoped to the top-off (spec check 11).', true,
  80.1, 7.4, 1.2, 2.0,
  245.0, 231.0, 'food', '{"bagel","jam","orange_juice"}', '{"bagel": 0.5, "jam": 2, "orange_juice": 1}'::jsonb, '{"gluten_free","keto","low_carb","paleo"}'
)
on conflict (id) do update set
  name = excluded.name, base_category = excluded.base_category,
  time_window = excluded.time_window, digestion_speed = excluded.digestion_speed,
  allergens = excluded.allergens, serving_unit = excluded.serving_unit,
  min_servings = excluded.min_servings, max_servings = excluded.max_servings,
  notes = excluded.notes, is_active = excluded.is_active,
  carbs_per_serving = excluded.carbs_per_serving, protein_per_serving = excluded.protein_per_serving,
  fat_per_serving = excluded.fat_per_serving, fiber_per_serving = excluded.fiber_per_serving,
  sodium_mg = excluded.sodium_mg, fluid_ml = excluded.fluid_ml,
  template_type = excluded.template_type,
  component_food_names = excluded.component_food_names,
  component_quantities = excluded.component_quantities,
  excluded_diets = excluded.excluded_diets, updated_at = now();

-- Rice + Chicken + Sweet Potato  [2-4 hours]  -- SSOT 3.11 meal #3; worked example 7 row 3
--   summed feeding: 57.0 g carb, 22.9 g protein, 2.5 g fat, 2.5 g fibre, 64.7 mg Na
insert into pre_workout_templates (
  id, name, base_category, time_window, digestion_speed, allergens, serving_unit,
  min_servings, max_servings, plus_banana, plus_sports_drink, notes, is_active,
  carbs_per_serving, protein_per_serving, fat_per_serving, fiber_per_serving,
  sodium_mg, fluid_ml, template_type, component_food_names, component_quantities, excluded_diets
) values (
  '6c67c9a6-7077-5644-8d1f-17214644ae35', 'Rice + Chicken + Sweet Potato', 'White Rice', '2-4 hours', 'Medium', '{}', '1 cup rice + 2 oz chicken + 0.5 sweet potato',
  1, 2, false, false, 'Chicken is 2 oz, not 3 oz: section 7 row 3 records 3 oz FAILING H3 at 65 kg (31.2 g vs 26 g) and names 2 oz as the passing fix.', true,
  57.0, 22.9, 2.5, 2.5,
  64.7, 166.0, 'food', '{"chicken","sweet_potato","white_rice"}', '{"white_rice": 1, "chicken": 0.67, "sweet_potato": 0.5}'::jsonb, '{"keto","low_carb","pescatarian","vegan","vegetarian"}'
)
on conflict (id) do update set
  name = excluded.name, base_category = excluded.base_category,
  time_window = excluded.time_window, digestion_speed = excluded.digestion_speed,
  allergens = excluded.allergens, serving_unit = excluded.serving_unit,
  min_servings = excluded.min_servings, max_servings = excluded.max_servings,
  notes = excluded.notes, is_active = excluded.is_active,
  carbs_per_serving = excluded.carbs_per_serving, protein_per_serving = excluded.protein_per_serving,
  fat_per_serving = excluded.fat_per_serving, fiber_per_serving = excluded.fiber_per_serving,
  sodium_mg = excluded.sodium_mg, fluid_ml = excluded.fluid_ml,
  template_type = excluded.template_type,
  component_food_names = excluded.component_food_names,
  component_quantities = excluded.component_quantities,
  excluded_diets = excluded.excluded_diets, updated_at = now();

-- Pancakes + Maple Syrup  [2-4 hours]  -- SSOT 3.11 meal #4
--   summed feeding: 70.8 g carb, 10.0 g protein, 14.0 g fat, 1.0 g fibre, 456.0 mg Na
insert into pre_workout_templates (
  id, name, base_category, time_window, digestion_speed, allergens, serving_unit,
  min_servings, max_servings, plus_banana, plus_sports_drink, notes, is_active,
  carbs_per_serving, protein_per_serving, fat_per_serving, fiber_per_serving,
  sodium_mg, fluid_ml, template_type, component_food_names, component_quantities, excluded_diets
) values (
  '68dd9483-3eb3-5b71-8ccd-eb9790ca0a45', 'Pancakes + Maple Syrup', 'Pancakes', '2-4 hours', 'Medium', '{"Dairy","Eggs","Gluten"}', '2 pancakes + 2 tbsp maple syrup',
  1, 2, false, false, 'Fat 14.0 g sits just under H1 floor of 15 g at 65 kg. Do not raise the pancake count without re-checking H1.', true,
  70.8, 10.0, 14.0, 1.0,
  456.0, 90.0, 'food', '{"maple_syrup","pancake"}', '{"pancake": 2, "maple_syrup": 2}'::jsonb, '{"gluten_free","keto","low_carb","paleo","vegan"}'
)
on conflict (id) do update set
  name = excluded.name, base_category = excluded.base_category,
  time_window = excluded.time_window, digestion_speed = excluded.digestion_speed,
  allergens = excluded.allergens, serving_unit = excluded.serving_unit,
  min_servings = excluded.min_servings, max_servings = excluded.max_servings,
  notes = excluded.notes, is_active = excluded.is_active,
  carbs_per_serving = excluded.carbs_per_serving, protein_per_serving = excluded.protein_per_serving,
  fat_per_serving = excluded.fat_per_serving, fiber_per_serving = excluded.fiber_per_serving,
  sodium_mg = excluded.sodium_mg, fluid_ml = excluded.fluid_ml,
  template_type = excluded.template_type,
  component_food_names = excluded.component_food_names,
  component_quantities = excluded.component_quantities,
  excluded_diets = excluded.excluded_diets, updated_at = now();

-- Applesauce Pouch  [30-120 min]  -- SSOT 3.11 snack #3
--   summed feeding: 11.0 g carb, 0.2 g protein, 0.0 g fat, 1.0 g fibre, 3.0 mg Na
insert into pre_workout_templates (
  id, name, base_category, time_window, digestion_speed, allergens, serving_unit,
  min_servings, max_servings, plus_banana, plus_sports_drink, notes, is_active,
  carbs_per_serving, protein_per_serving, fat_per_serving, fiber_per_serving,
  sodium_mg, fluid_ml, template_type, component_food_names, component_quantities, excluded_diets
) values (
  '79f9d557-02b8-5cbf-ba4b-f8d2aac85498', 'Applesauce Pouch', 'Fruit', '30-120 min', 'Fast', '{}', '1 pouch (90g)',
  1, 3, false, false, NULL, true,
  11.0, 0.2, 0.0, 1.0,
  3.0, 77.0, 'food', '{"applesauce_pouch"}', '{"applesauce_pouch": 1}'::jsonb, '{}'
)
on conflict (id) do update set
  name = excluded.name, base_category = excluded.base_category,
  time_window = excluded.time_window, digestion_speed = excluded.digestion_speed,
  allergens = excluded.allergens, serving_unit = excluded.serving_unit,
  min_servings = excluded.min_servings, max_servings = excluded.max_servings,
  notes = excluded.notes, is_active = excluded.is_active,
  carbs_per_serving = excluded.carbs_per_serving, protein_per_serving = excluded.protein_per_serving,
  fat_per_serving = excluded.fat_per_serving, fiber_per_serving = excluded.fiber_per_serving,
  sodium_mg = excluded.sodium_mg, fluid_ml = excluded.fluid_ml,
  template_type = excluded.template_type,
  component_food_names = excluded.component_food_names,
  component_quantities = excluded.component_quantities,
  excluded_diets = excluded.excluded_diets, updated_at = now();

-- Pretzels + Sports Drink  [30-120 min]  -- SSOT 3.11 snack #5
--   summed feeding: 38.0 g carb, 2.8 g protein, 1.0 g fat, 0.9 g fibre, 485.0 mg Na
insert into pre_workout_templates (
  id, name, base_category, time_window, digestion_speed, allergens, serving_unit,
  min_servings, max_servings, plus_banana, plus_sports_drink, notes, is_active,
  carbs_per_serving, protein_per_serving, fat_per_serving, fiber_per_serving,
  sodium_mg, fluid_ml, template_type, component_food_names, component_quantities, excluded_diets
) values (
  '4888e879-f8aa-51a8-ad73-c2d3dffac876', 'Pretzels + Sports Drink', 'Pretzels', '30-120 min', 'Fast', '{"Gluten"}', '1 oz pretzels + 1 cup sports drink',
  1, 2, false, false, 'G4b sports drink at the snack tier is the v3 ruling (section 3.4, check 10).', true,
  38.0, 2.8, 1.0, 0.9,
  485.0, 240.0, 'food', '{"pretzels","sports_drink"}', '{"pretzels": 1, "sports_drink": 1}'::jsonb, '{"gluten_free","keto","low_carb","paleo"}'
)
on conflict (id) do update set
  name = excluded.name, base_category = excluded.base_category,
  time_window = excluded.time_window, digestion_speed = excluded.digestion_speed,
  allergens = excluded.allergens, serving_unit = excluded.serving_unit,
  min_servings = excluded.min_servings, max_servings = excluded.max_servings,
  notes = excluded.notes, is_active = excluded.is_active,
  carbs_per_serving = excluded.carbs_per_serving, protein_per_serving = excluded.protein_per_serving,
  fat_per_serving = excluded.fat_per_serving, fiber_per_serving = excluded.fiber_per_serving,
  sodium_mg = excluded.sodium_mg, fluid_ml = excluded.fluid_ml,
  template_type = excluded.template_type,
  component_food_names = excluded.component_food_names,
  component_quantities = excluded.component_quantities,
  excluded_diets = excluded.excluded_diets, updated_at = now();

-- Toast + Honey  [30-120 min]  -- SSOT 3.11 snack #1
--   summed feeding: 30.0 g carb, 1.9 g protein, 0.8 g fat, 0.6 g fibre, 131.0 mg Na
insert into pre_workout_templates (
  id, name, base_category, time_window, digestion_speed, allergens, serving_unit,
  min_servings, max_servings, plus_banana, plus_sports_drink, notes, is_active,
  carbs_per_serving, protein_per_serving, fat_per_serving, fiber_per_serving,
  sodium_mg, fluid_ml, template_type, component_food_names, component_quantities, excluded_diets
) values (
  'a0a9a961-5da4-52fd-8e7f-33f1435126a7', 'Toast + Honey', 'Toast / Bread', '30-120 min', 'Fast', '{"Gluten"}', '1 slice toast + 1 tbsp honey',
  1, 3, false, false, NULL, true,
  30.0, 1.9, 0.8, 0.6,
  131.0, 4.0, 'food', '{"honey","toast"}', '{"toast": 1, "honey": 1}'::jsonb, '{"gluten_free","keto","low_carb","paleo"}'
)
on conflict (id) do update set
  name = excluded.name, base_category = excluded.base_category,
  time_window = excluded.time_window, digestion_speed = excluded.digestion_speed,
  allergens = excluded.allergens, serving_unit = excluded.serving_unit,
  min_servings = excluded.min_servings, max_servings = excluded.max_servings,
  notes = excluded.notes, is_active = excluded.is_active,
  carbs_per_serving = excluded.carbs_per_serving, protein_per_serving = excluded.protein_per_serving,
  fat_per_serving = excluded.fat_per_serving, fiber_per_serving = excluded.fiber_per_serving,
  sodium_mg = excluded.sodium_mg, fluid_ml = excluded.fluid_ml,
  template_type = excluded.template_type,
  component_food_names = excluded.component_food_names,
  component_quantities = excluded.component_quantities,
  excluded_diets = excluded.excluded_diets, updated_at = now();

-- Rice Cake + Honey  [30-120 min]  -- SSOT 3.11 snack #1
--   summed feeding: 24.6 g carb, 0.8 g protein, 0.3 g fat, 0.4 g fibre, 30.0 mg Na
insert into pre_workout_templates (
  id, name, base_category, time_window, digestion_speed, allergens, serving_unit,
  min_servings, max_servings, plus_banana, plus_sports_drink, notes, is_active,
  carbs_per_serving, protein_per_serving, fat_per_serving, fiber_per_serving,
  sodium_mg, fluid_ml, template_type, component_food_names, component_quantities, excluded_diets
) values (
  '5e8bc882-8243-55d8-8153-5f96edbb11d1', 'Rice Cake + Honey', 'Rice Cake', '30-120 min', 'Fast', '{}', '1 rice cake + 1 tbsp honey',
  1, 3, false, false, NULL, true,
  24.6, 0.8, 0.3, 0.4,
  30.0, 4.0, 'food', '{"honey","rice_cake"}', '{"rice_cake": 1, "honey": 1}'::jsonb, '{"keto","low_carb"}'
)
on conflict (id) do update set
  name = excluded.name, base_category = excluded.base_category,
  time_window = excluded.time_window, digestion_speed = excluded.digestion_speed,
  allergens = excluded.allergens, serving_unit = excluded.serving_unit,
  min_servings = excluded.min_servings, max_servings = excluded.max_servings,
  notes = excluded.notes, is_active = excluded.is_active,
  carbs_per_serving = excluded.carbs_per_serving, protein_per_serving = excluded.protein_per_serving,
  fat_per_serving = excluded.fat_per_serving, fiber_per_serving = excluded.fiber_per_serving,
  sodium_mg = excluded.sodium_mg, fluid_ml = excluded.fluid_ml,
  template_type = excluded.template_type,
  component_food_names = excluded.component_food_names,
  component_quantities = excluded.component_quantities,
  excluded_diets = excluded.excluded_diets, updated_at = now();

-- Cereal (Dry)  [30-120 min]  -- SSOT 3.11 snack #4
--   summed feeding: 24.0 g carb, 2.0 g protein, 0.0 g fat, 1.0 g fibre, 200.0 mg Na
insert into pre_workout_templates (
  id, name, base_category, time_window, digestion_speed, allergens, serving_unit,
  min_servings, max_servings, plus_banana, plus_sports_drink, notes, is_active,
  carbs_per_serving, protein_per_serving, fat_per_serving, fiber_per_serving,
  sodium_mg, fluid_ml, template_type, component_food_names, component_quantities, excluded_diets
) values (
  '49f90f6a-c7f6-5184-b933-3294319a2e56', 'Cereal (Dry)', 'Cereal', '30-120 min', 'Fast', '{"Gluten"}', '1 cup low-fibre cereal, dry',
  1, 2, false, false, NULL, true,
  24.0, 2.0, 0.0, 1.0,
  200.0, 0.0, 'food', '{"cereal"}', '{"cereal": 1}'::jsonb, '{"gluten_free","keto","low_carb","paleo"}'
)
on conflict (id) do update set
  name = excluded.name, base_category = excluded.base_category,
  time_window = excluded.time_window, digestion_speed = excluded.digestion_speed,
  allergens = excluded.allergens, serving_unit = excluded.serving_unit,
  min_servings = excluded.min_servings, max_servings = excluded.max_servings,
  notes = excluded.notes, is_active = excluded.is_active,
  carbs_per_serving = excluded.carbs_per_serving, protein_per_serving = excluded.protein_per_serving,
  fat_per_serving = excluded.fat_per_serving, fiber_per_serving = excluded.fiber_per_serving,
  sodium_mg = excluded.sodium_mg, fluid_ml = excluded.fluid_ml,
  template_type = excluded.template_type,
  component_food_names = excluded.component_food_names,
  component_quantities = excluded.component_quantities,
  excluded_diets = excluded.excluded_diets, updated_at = now();

-- Energy Gel + Water  [< 30 min]  -- SSOT 3.11 top-off #1; worked example 7 row 8
--   summed feeding: 25.0 g carb, 0.0 g protein, 0.0 g fat, 0.0 g fibre, 55.0 mg Na
insert into pre_workout_templates (
  id, name, base_category, time_window, digestion_speed, allergens, serving_unit,
  min_servings, max_servings, plus_banana, plus_sports_drink, notes, is_active,
  carbs_per_serving, protein_per_serving, fat_per_serving, fiber_per_serving,
  sodium_mg, fluid_ml, template_type, component_food_names, component_quantities, excluded_diets
) values (
  'd95c5700-a528-520c-9c24-fd8a5ff10376', 'Energy Gel + Water', 'Quick Grab', '< 30 min', 'Fast', '{}', '1 gel packet + 250 ml water',
  1, 2, false, false, 'The canonical top-off. Gel plus chase water is ~8 % as mixed in the stomach (section 7 row 8).', true,
  25.0, 0.0, 0.0, 0.0,
  55.0, 260.0, 'food', '{"energy_gel","water"}', '{"energy_gel": 1, "water": 1}'::jsonb, '{}'
)
on conflict (id) do update set
  name = excluded.name, base_category = excluded.base_category,
  time_window = excluded.time_window, digestion_speed = excluded.digestion_speed,
  allergens = excluded.allergens, serving_unit = excluded.serving_unit,
  min_servings = excluded.min_servings, max_servings = excluded.max_servings,
  notes = excluded.notes, is_active = excluded.is_active,
  carbs_per_serving = excluded.carbs_per_serving, protein_per_serving = excluded.protein_per_serving,
  fat_per_serving = excluded.fat_per_serving, fiber_per_serving = excluded.fiber_per_serving,
  sodium_mg = excluded.sodium_mg, fluid_ml = excluded.fluid_ml,
  template_type = excluded.template_type,
  component_food_names = excluded.component_food_names,
  component_quantities = excluded.component_quantities,
  excluded_diets = excluded.excluded_diets, updated_at = now();

-- Banana (Top-Off)  [< 30 min]  -- SSOT 3.11 top-off #4; worked example 7 row 10
--   summed feeding: 27.0 g carb, 1.3 g protein, 0.4 g fat, 3.1 g fibre, 1.0 mg Na
insert into pre_workout_templates (
  id, name, base_category, time_window, digestion_speed, allergens, serving_unit,
  min_servings, max_servings, plus_banana, plus_sports_drink, notes, is_active,
  carbs_per_serving, protein_per_serving, fat_per_serving, fiber_per_serving,
  sodium_mg, fluid_ml, template_type, component_food_names, component_quantities, excluded_diets
) values (
  '2a7e2219-fbaf-5086-8aab-3830f721527f', 'Banana (Top-Off)', 'Fruit', '< 30 min', 'Fast', '{}', '1 medium banana',
  1, 1, false, false, 'DOCUMENTED EXCEPTION: fibre 3.1 g exceeds H2 top-off ceiling of 2 g. H4 grants a soft low-residue allowance from t-30 to about t-20, explicitly not in the final 15 minutes. Recorded, not silent.', true,
  27.0, 1.3, 0.4, 3.1,
  1.0, 88.0, 'food', '{"banana"}', '{"banana": 1}'::jsonb, '{}'
)
on conflict (id) do update set
  name = excluded.name, base_category = excluded.base_category,
  time_window = excluded.time_window, digestion_speed = excluded.digestion_speed,
  allergens = excluded.allergens, serving_unit = excluded.serving_unit,
  min_servings = excluded.min_servings, max_servings = excluded.max_servings,
  notes = excluded.notes, is_active = excluded.is_active,
  carbs_per_serving = excluded.carbs_per_serving, protein_per_serving = excluded.protein_per_serving,
  fat_per_serving = excluded.fat_per_serving, fiber_per_serving = excluded.fiber_per_serving,
  sodium_mg = excluded.sodium_mg, fluid_ml = excluded.fluid_ml,
  template_type = excluded.template_type,
  component_food_names = excluded.component_food_names,
  component_quantities = excluded.component_quantities,
  excluded_diets = excluded.excluded_diets, updated_at = now();

-- Applesauce Pouch (Top-Off)  [< 30 min]  -- SSOT 3.11 top-off #4; vector h4-applesauce-pouch-t25
--   summed feeding: 11.0 g carb, 0.2 g protein, 0.0 g fat, 1.0 g fibre, 3.0 mg Na
insert into pre_workout_templates (
  id, name, base_category, time_window, digestion_speed, allergens, serving_unit,
  min_servings, max_servings, plus_banana, plus_sports_drink, notes, is_active,
  carbs_per_serving, protein_per_serving, fat_per_serving, fiber_per_serving,
  sodium_mg, fluid_ml, template_type, component_food_names, component_quantities, excluded_diets
) values (
  '35ce685d-0cf6-5d59-a83f-f89312eae496', 'Applesauce Pouch (Top-Off)', 'Fruit', '< 30 min', 'Fast', '{}', '1 pouch (90g)',
  1, 2, false, false, 'Soft low-residue purée. Fibre 1.0 g is under the 2 g top-off ceiling, so it needs no H2 waiver.', true,
  11.0, 0.2, 0.0, 1.0,
  3.0, 77.0, 'food', '{"applesauce_pouch"}', '{"applesauce_pouch": 1}'::jsonb, '{}'
)
on conflict (id) do update set
  name = excluded.name, base_category = excluded.base_category,
  time_window = excluded.time_window, digestion_speed = excluded.digestion_speed,
  allergens = excluded.allergens, serving_unit = excluded.serving_unit,
  min_servings = excluded.min_servings, max_servings = excluded.max_servings,
  notes = excluded.notes, is_active = excluded.is_active,
  carbs_per_serving = excluded.carbs_per_serving, protein_per_serving = excluded.protein_per_serving,
  fat_per_serving = excluded.fat_per_serving, fiber_per_serving = excluded.fiber_per_serving,
  sodium_mg = excluded.sodium_mg, fluid_ml = excluded.fluid_ml,
  template_type = excluded.template_type,
  component_food_names = excluded.component_food_names,
  component_quantities = excluded.component_quantities,
  excluded_diets = excluded.excluded_diets, updated_at = now();

-- Sports Drink (Meal)  [2-4 hours]  -- SSOT 3.4 v3 ruling; check 10; vector g4b-sports-drink-meal
--   summed feeding: 15.0 g carb, 0.0 g protein, 0.0 g fat, 0.0 g fibre, 100.0 mg Na
insert into pre_workout_templates (
  id, name, base_category, time_window, digestion_speed, allergens, serving_unit,
  min_servings, max_servings, plus_banana, plus_sports_drink, notes, is_active,
  carbs_per_serving, protein_per_serving, fat_per_serving, fiber_per_serving,
  sodium_mg, fluid_ml, template_type, component_food_names, component_quantities, excluded_diets
) values (
  '0f53669e-41cc-5ad5-b3cd-a175afae4b2b', 'Sports Drink (Meal)', 'Hydration', '2-4 hours', 'Fast', '{}', '1 cup (8 oz)',
  1, 3, false, false, 'v3 reverses the v2 top-off-only rule. Zero fat/fibre/protein clears H1-H3 by the widest margin in the SSOT.', true,
  15.0, 0.0, 0.0, 0.0,
  100.0, 240.0, 'drink', '{"sports_drink"}', '{"sports_drink": 1}'::jsonb, '{}'
)
on conflict (id) do update set
  name = excluded.name, base_category = excluded.base_category,
  time_window = excluded.time_window, digestion_speed = excluded.digestion_speed,
  allergens = excluded.allergens, serving_unit = excluded.serving_unit,
  min_servings = excluded.min_servings, max_servings = excluded.max_servings,
  notes = excluded.notes, is_active = excluded.is_active,
  carbs_per_serving = excluded.carbs_per_serving, protein_per_serving = excluded.protein_per_serving,
  fat_per_serving = excluded.fat_per_serving, fiber_per_serving = excluded.fiber_per_serving,
  sodium_mg = excluded.sodium_mg, fluid_ml = excluded.fluid_ml,
  template_type = excluded.template_type,
  component_food_names = excluded.component_food_names,
  component_quantities = excluded.component_quantities,
  excluded_diets = excluded.excluded_diets, updated_at = now();

-- Sports Drink (Snack)  [30-120 min]  -- SSOT 3.4 v3 ruling; check 10; vector g4b-sports-drink-snack
--   summed feeding: 15.0 g carb, 0.0 g protein, 0.0 g fat, 0.0 g fibre, 100.0 mg Na
insert into pre_workout_templates (
  id, name, base_category, time_window, digestion_speed, allergens, serving_unit,
  min_servings, max_servings, plus_banana, plus_sports_drink, notes, is_active,
  carbs_per_serving, protein_per_serving, fat_per_serving, fiber_per_serving,
  sodium_mg, fluid_ml, template_type, component_food_names, component_quantities, excluded_diets
) values (
  '96bf3eee-917a-51b2-a542-13194a185db1', 'Sports Drink (Snack)', 'Hydration', '30-120 min', 'Fast', '{}', '1 cup (8 oz)',
  1, 3, false, false, NULL, true,
  15.0, 0.0, 0.0, 0.0,
  100.0, 240.0, 'drink', '{"sports_drink"}', '{"sports_drink": 1}'::jsonb, '{}'
)
on conflict (id) do update set
  name = excluded.name, base_category = excluded.base_category,
  time_window = excluded.time_window, digestion_speed = excluded.digestion_speed,
  allergens = excluded.allergens, serving_unit = excluded.serving_unit,
  min_servings = excluded.min_servings, max_servings = excluded.max_servings,
  notes = excluded.notes, is_active = excluded.is_active,
  carbs_per_serving = excluded.carbs_per_serving, protein_per_serving = excluded.protein_per_serving,
  fat_per_serving = excluded.fat_per_serving, fiber_per_serving = excluded.fiber_per_serving,
  sodium_mg = excluded.sodium_mg, fluid_ml = excluded.fluid_ml,
  template_type = excluded.template_type,
  component_food_names = excluded.component_food_names,
  component_quantities = excluded.component_quantities,
  excluded_diets = excluded.excluded_diets, updated_at = now();

-- Energy Gel (Meal)  [2-4 hours]  -- SSOT 3.4 v3 ruling; vector g4b-gel-at-meal
--   summed feeding: 25.0 g carb, 0.0 g protein, 0.0 g fat, 0.0 g fibre, 55.0 mg Na
insert into pre_workout_templates (
  id, name, base_category, time_window, digestion_speed, allergens, serving_unit,
  min_servings, max_servings, plus_banana, plus_sports_drink, notes, is_active,
  carbs_per_serving, protein_per_serving, fat_per_serving, fiber_per_serving,
  sodium_mg, fluid_ml, template_type, component_food_names, component_quantities, excluded_diets
) values (
  'ae25efd1-79ef-5c35-b2f9-204b78933abd', 'Energy Gel (Meal)', 'Quick Grab', '2-4 hours', 'Fast', '{}', '1 gel packet (~25g carbs)',
  1, 2, false, false, NULL, true,
  25.0, 0.0, 0.0, 0.0,
  55.0, 20.0, 'food', '{"energy_gel"}', '{"energy_gel": 1}'::jsonb, '{}'
)
on conflict (id) do update set
  name = excluded.name, base_category = excluded.base_category,
  time_window = excluded.time_window, digestion_speed = excluded.digestion_speed,
  allergens = excluded.allergens, serving_unit = excluded.serving_unit,
  min_servings = excluded.min_servings, max_servings = excluded.max_servings,
  notes = excluded.notes, is_active = excluded.is_active,
  carbs_per_serving = excluded.carbs_per_serving, protein_per_serving = excluded.protein_per_serving,
  fat_per_serving = excluded.fat_per_serving, fiber_per_serving = excluded.fiber_per_serving,
  sodium_mg = excluded.sodium_mg, fluid_ml = excluded.fluid_ml,
  template_type = excluded.template_type,
  component_food_names = excluded.component_food_names,
  component_quantities = excluded.component_quantities,
  excluded_diets = excluded.excluded_diets, updated_at = now();

-- Energy Gel (Snack)  [30-120 min]  -- SSOT 3.4 v3 ruling; check 10
--   summed feeding: 25.0 g carb, 0.0 g protein, 0.0 g fat, 0.0 g fibre, 55.0 mg Na
insert into pre_workout_templates (
  id, name, base_category, time_window, digestion_speed, allergens, serving_unit,
  min_servings, max_servings, plus_banana, plus_sports_drink, notes, is_active,
  carbs_per_serving, protein_per_serving, fat_per_serving, fiber_per_serving,
  sodium_mg, fluid_ml, template_type, component_food_names, component_quantities, excluded_diets
) values (
  '99dc361f-e377-5119-9f5e-6eb671bb54a4', 'Energy Gel (Snack)', 'Quick Grab', '30-120 min', 'Fast', '{}', '1 gel packet (~25g carbs)',
  1, 2, false, false, NULL, true,
  25.0, 0.0, 0.0, 0.0,
  55.0, 20.0, 'food', '{"energy_gel"}', '{"energy_gel": 1}'::jsonb, '{}'
)
on conflict (id) do update set
  name = excluded.name, base_category = excluded.base_category,
  time_window = excluded.time_window, digestion_speed = excluded.digestion_speed,
  allergens = excluded.allergens, serving_unit = excluded.serving_unit,
  min_servings = excluded.min_servings, max_servings = excluded.max_servings,
  notes = excluded.notes, is_active = excluded.is_active,
  carbs_per_serving = excluded.carbs_per_serving, protein_per_serving = excluded.protein_per_serving,
  fat_per_serving = excluded.fat_per_serving, fiber_per_serving = excluded.fiber_per_serving,
  sodium_mg = excluded.sodium_mg, fluid_ml = excluded.fluid_ml,
  template_type = excluded.template_type,
  component_food_names = excluded.component_food_names,
  component_quantities = excluded.component_quantities,
  excluded_diets = excluded.excluded_diets, updated_at = now();

-- Energy Chews (Snack)  [30-120 min]  -- SSOT 3.4 v3 ruling; check 10
--   summed feeding: 25.0 g carb, 0.0 g protein, 0.0 g fat, 0.0 g fibre, 80.0 mg Na
insert into pre_workout_templates (
  id, name, base_category, time_window, digestion_speed, allergens, serving_unit,
  min_servings, max_servings, plus_banana, plus_sports_drink, notes, is_active,
  carbs_per_serving, protein_per_serving, fat_per_serving, fiber_per_serving,
  sodium_mg, fluid_ml, template_type, component_food_names, component_quantities, excluded_diets
) values (
  '6f2074ef-562b-5564-9a3a-eb36c2519fd5', 'Energy Chews (Snack)', 'Quick Grab', '30-120 min', 'Fast', '{}', '1 sleeve / 3-4 chews (~25g carbs)',
  1, 2, false, false, NULL, true,
  25.0, 0.0, 0.0, 0.0,
  80.0, 0.0, 'food', '{"energy_chews"}', '{"energy_chews": 1}'::jsonb, '{}'
)
on conflict (id) do update set
  name = excluded.name, base_category = excluded.base_category,
  time_window = excluded.time_window, digestion_speed = excluded.digestion_speed,
  allergens = excluded.allergens, serving_unit = excluded.serving_unit,
  min_servings = excluded.min_servings, max_servings = excluded.max_servings,
  notes = excluded.notes, is_active = excluded.is_active,
  carbs_per_serving = excluded.carbs_per_serving, protein_per_serving = excluded.protein_per_serving,
  fat_per_serving = excluded.fat_per_serving, fiber_per_serving = excluded.fiber_per_serving,
  sodium_mg = excluded.sodium_mg, fluid_ml = excluded.fluid_ml,
  template_type = excluded.template_type,
  component_food_names = excluded.component_food_names,
  component_quantities = excluded.component_quantities,
  excluded_diets = excluded.excluded_diets, updated_at = now();

commit;
