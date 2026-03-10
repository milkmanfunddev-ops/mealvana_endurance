-- ============================================================================
-- EXPORT DEV templates DATA
-- ============================================================================
-- Run on: DEV Supabase SQL Editor
-- Purpose: Generates INSERT...ON CONFLICT statements for ALL templates rows.
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
    'INSERT INTO templates (' ||
    '  id, name, slug,' ||
    '  phase, timing_window, timing_min_minutes, timing_max_minutes, meal_type,' ||
    '  base_category, digestion_speed, allergens, notes,' ||
    '  foods,' ||
    '  total_carbs_g, total_protein_g, total_fat_g, total_sodium_mg, total_fluid_ml, total_calories,' ||
    '  validation_status, is_active, sort_order,' ||
    '  excluded_diets, has_liquid_base, food_names' ||
    ') VALUES (' ||
    '  ' || quote_literal(id::text) || '::uuid, ' ||
    quote_literal(name) || ', ' ||
    quote_literal(slug) || ', ' ||
    quote_literal(phase) || ', ' ||
    quote_literal(timing_window) || ', ' ||
    timing_min_minutes::text || ', ' ||
    timing_max_minutes::text || ', ' ||
    quote_literal(meal_type) || ', ' ||
    quote_literal(base_category) || ', ' ||
    COALESCE(quote_literal(digestion_speed), '''medium''') || ', ' ||
    quote_literal(COALESCE(allergens::text, '{}')) || '::text[], ' ||
    COALESCE(quote_literal(notes), 'NULL') || ', ' ||
    quote_literal(foods::text) || '::jsonb, ' ||
    COALESCE(total_carbs_g::text, '0') || ', ' ||
    COALESCE(total_protein_g::text, '0') || ', ' ||
    COALESCE(total_fat_g::text, '0') || ', ' ||
    COALESCE(total_sodium_mg::text, '0') || ', ' ||
    COALESCE(total_fluid_ml::text, '0') || ', ' ||
    COALESCE(total_calories::text, '0') || ', ' ||
    COALESCE(quote_literal(validation_status), '''unvalidated''') || ', ' ||
    COALESCE(is_active::text, 'true') || ', ' ||
    COALESCE(sort_order::text, '0') || ', ' ||
    quote_literal(COALESCE(excluded_diets::text, '{}')) || '::text[], ' ||
    COALESCE(has_liquid_base::text, 'false') || ', ' ||
    quote_literal(COALESCE(food_names::text, '{}')) || '::text[]' ||
    ') ON CONFLICT (slug) DO UPDATE SET ' ||
    'id = EXCLUDED.id, ' ||
    'name = EXCLUDED.name, ' ||
    'phase = EXCLUDED.phase, ' ||
    'timing_window = EXCLUDED.timing_window, ' ||
    'timing_min_minutes = EXCLUDED.timing_min_minutes, ' ||
    'timing_max_minutes = EXCLUDED.timing_max_minutes, ' ||
    'meal_type = EXCLUDED.meal_type, ' ||
    'base_category = EXCLUDED.base_category, ' ||
    'digestion_speed = EXCLUDED.digestion_speed, ' ||
    'allergens = EXCLUDED.allergens, ' ||
    'notes = EXCLUDED.notes, ' ||
    'foods = EXCLUDED.foods, ' ||
    'total_carbs_g = EXCLUDED.total_carbs_g, ' ||
    'total_protein_g = EXCLUDED.total_protein_g, ' ||
    'total_fat_g = EXCLUDED.total_fat_g, ' ||
    'total_sodium_mg = EXCLUDED.total_sodium_mg, ' ||
    'total_fluid_ml = EXCLUDED.total_fluid_ml, ' ||
    'total_calories = EXCLUDED.total_calories, ' ||
    'validation_status = EXCLUDED.validation_status, ' ||
    'is_active = EXCLUDED.is_active, ' ||
    'sort_order = EXCLUDED.sort_order, ' ||
    'excluded_diets = EXCLUDED.excluded_diets, ' ||
    'has_liquid_base = EXCLUDED.has_liquid_base, ' ||
    'food_names = EXCLUDED.food_names, ' ||
    'updated_at = now();'
    AS stmt
  FROM templates
  ORDER BY slug
) sub;
