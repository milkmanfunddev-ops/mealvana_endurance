-- ============================================================================
-- EXPORT DEV template_foods DATA
-- ============================================================================
-- Run on: DEV Supabase SQL Editor
-- Purpose: Generates INSERT...ON CONFLICT statements for ALL template_foods rows.
--
-- HOW TO USE:
--   1. Run this query in DEV Supabase SQL Editor
--   2. The result is ONE row with ONE column called "all_sql"
--   3. Click on the cell to expand it, then copy the entire text
--   4. Paste into PROD SQL Editor and run
-- ============================================================================

SELECT string_agg(stmt, E'\n\n') AS all_sql
FROM (
  SELECT
    'INSERT INTO template_foods (' ||
    '  id, name, display_name, serving_size, serving_weight_g,' ||
    '  calories, carbs_g, protein_g, fat_g, fiber_g, sodium_mg, fluid_ml,' ||
    '  allergens, digestion_speed, is_active,' ||
    '  excluded_diets, product_type, activity_types, categories,' ||
    '  show_in_preferences, is_essential, is_electrolyte, requires_preparation,' ||
    '  caffeine_mg, potassium_mg,' ||
    '  is_drink_pool, drink_pool_phases, is_liquid,' ||
    '  max_servings_before, max_servings_during, max_servings_after,' ||
    '  to_exclude_from_solver, display_name_plural, image_address, description,' ||
    '  serving_amount, serving_unit, serving_qualifier,' ||
    '  is_indivisible, default_during, min_servings_during' ||
    ') VALUES (' ||
    '  ' || quote_literal(id::text) || '::uuid, ' ||
    quote_literal(name) || ', ' ||
    quote_literal(display_name) || ', ' ||
    quote_literal(serving_size) || ', ' ||
    COALESCE(serving_weight_g::text, 'NULL') || ', ' ||
    COALESCE(calories::text, 'NULL') || ', ' ||
    carbs_g::text || ', ' ||
    protein_g::text || ', ' ||
    fat_g::text || ', ' ||
    COALESCE(fiber_g::text, 'NULL') || ', ' ||
    sodium_mg::text || ', ' ||
    COALESCE(fluid_ml::text, 'NULL') || ', ' ||
    quote_literal(COALESCE(allergens::text, '{}')) || '::text[], ' ||
    quote_literal(COALESCE(digestion_speed, 'medium')) || ', ' ||
    COALESCE(is_active::text, 'true') || ', ' ||
    quote_literal(COALESCE(excluded_diets::text, '{}')) || '::text[], ' ||
    quote_literal(COALESCE(product_type, 'real_food')) || ', ' ||
    quote_literal(COALESCE(activity_types::text, '{running,cycling,swimming}')) || '::text[], ' ||
    quote_literal(COALESCE(categories::text, '{before_run}')) || '::text[], ' ||
    COALESCE(show_in_preferences::text, 'true') || ', ' ||
    COALESCE(is_essential::text, 'false') || ', ' ||
    COALESCE(is_electrolyte::text, 'false') || ', ' ||
    COALESCE(requires_preparation::text, 'false') || ', ' ||
    COALESCE(caffeine_mg::text, '0') || ', ' ||
    COALESCE(potassium_mg::text, '0') || ', ' ||
    COALESCE(is_drink_pool::text, 'false') || ', ' ||
    quote_literal(COALESCE(drink_pool_phases::text, '{}')) || '::text[], ' ||
    COALESCE(is_liquid::text, 'false') || ', ' ||
    COALESCE(max_servings_before::text, '4') || ', ' ||
    COALESCE(max_servings_during::text, '4') || ', ' ||
    COALESCE(max_servings_after::text, '4') || ', ' ||
    COALESCE(to_exclude_from_solver::text, 'false') || ', ' ||
    COALESCE(quote_literal(display_name_plural), 'NULL') || ', ' ||
    COALESCE(quote_literal(image_address), 'NULL') || ', ' ||
    COALESCE(quote_literal(description), 'NULL') || ', ' ||
    COALESCE(serving_amount::text, 'NULL') || ', ' ||
    COALESCE(quote_literal(serving_unit), 'NULL') || ', ' ||
    COALESCE(quote_literal(serving_qualifier), 'NULL') || ', ' ||
    COALESCE(is_indivisible::text, 'false') || ', ' ||
    COALESCE(default_during::text, 'false') || ', ' ||
    COALESCE(min_servings_during::text, '1.0') ||
    ') ON CONFLICT (name) DO UPDATE SET ' ||
    'id = EXCLUDED.id, ' ||
    'display_name = EXCLUDED.display_name, ' ||
    'serving_size = EXCLUDED.serving_size, ' ||
    'serving_weight_g = EXCLUDED.serving_weight_g, ' ||
    'calories = EXCLUDED.calories, ' ||
    'carbs_g = EXCLUDED.carbs_g, ' ||
    'protein_g = EXCLUDED.protein_g, ' ||
    'fat_g = EXCLUDED.fat_g, ' ||
    'fiber_g = EXCLUDED.fiber_g, ' ||
    'sodium_mg = EXCLUDED.sodium_mg, ' ||
    'fluid_ml = EXCLUDED.fluid_ml, ' ||
    'allergens = EXCLUDED.allergens, ' ||
    'digestion_speed = EXCLUDED.digestion_speed, ' ||
    'is_active = EXCLUDED.is_active, ' ||
    'excluded_diets = EXCLUDED.excluded_diets, ' ||
    'product_type = EXCLUDED.product_type, ' ||
    'activity_types = EXCLUDED.activity_types, ' ||
    'categories = EXCLUDED.categories, ' ||
    'show_in_preferences = EXCLUDED.show_in_preferences, ' ||
    'is_essential = EXCLUDED.is_essential, ' ||
    'is_electrolyte = EXCLUDED.is_electrolyte, ' ||
    'requires_preparation = EXCLUDED.requires_preparation, ' ||
    'caffeine_mg = EXCLUDED.caffeine_mg, ' ||
    'potassium_mg = EXCLUDED.potassium_mg, ' ||
    'is_drink_pool = EXCLUDED.is_drink_pool, ' ||
    'drink_pool_phases = EXCLUDED.drink_pool_phases, ' ||
    'is_liquid = EXCLUDED.is_liquid, ' ||
    'max_servings_before = EXCLUDED.max_servings_before, ' ||
    'max_servings_during = EXCLUDED.max_servings_during, ' ||
    'max_servings_after = EXCLUDED.max_servings_after, ' ||
    'to_exclude_from_solver = EXCLUDED.to_exclude_from_solver, ' ||
    'display_name_plural = EXCLUDED.display_name_plural, ' ||
    'image_address = EXCLUDED.image_address, ' ||
    'description = EXCLUDED.description, ' ||
    'serving_amount = EXCLUDED.serving_amount, ' ||
    'serving_unit = EXCLUDED.serving_unit, ' ||
    'serving_qualifier = EXCLUDED.serving_qualifier, ' ||
    'is_indivisible = EXCLUDED.is_indivisible, ' ||
    'default_during = EXCLUDED.default_during, ' ||
    'min_servings_during = EXCLUDED.min_servings_during, ' ||
    'updated_at = now();'
    AS stmt
  FROM template_foods
  ORDER BY name
) sub;
