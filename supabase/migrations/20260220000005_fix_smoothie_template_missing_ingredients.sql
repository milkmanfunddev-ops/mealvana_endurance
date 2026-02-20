-- Fix smoothie templates that are missing their key liquid ingredient (milk or OJ).
-- The template system was designed with drinks being separate from template foods,
-- but smoothie ingredients like milk and OJ are *blended into* the smoothie and
-- should be part of the foods JSONB array, not the drink pool.
--
-- Affected templates:
-- 1. "Smoothie: Banana + PB + Milk" - missing milk
-- 2. "Smoothie: Banana + Milk + Honey" - missing milk
-- 3. "Smoothie: Banana + Dates + Milk" - missing milk
-- 4. "Smoothie: Banana + Berries + Milk" - missing milk
-- 5. "Smoothie: Banana + Protein Powder + Milk" - missing milk
-- 6. "Smoothie: Banana + Oats + Milk + Honey" - missing milk
-- 7. "Smoothie: Mango + Banana + OJ" - missing OJ

-- Milk food item to append (from template_foods: id=729254f8-7c67-4814-8d22-c232871d810b)
-- carbs: 12g, protein: 8g, fat: 8g, sodium: 105mg, fluid: 220ml, calories: 149

-- OJ food item to append (from template_foods: id=8e5ceb2a-c956-4c8d-8798-255eb6c048c3)
-- carbs: 26g, protein: 1.7g, fat: 0.5g, sodium: 2mg, fluid: 219ml, calories: 111

-- ================================================================
-- Add milk to smoothie templates
-- ================================================================

UPDATE templates
SET
  foods = foods || '[{
    "food_id": "729254f8-7c67-4814-8d22-c232871d810b",
    "food_name": "milk",
    "display_name": "Milk (whole)",
    "serving_size": "1 cup (8 oz)",
    "carbs_g": 12,
    "protein_g": 8,
    "fat_g": 8,
    "sodium_mg": 105,
    "fluid_ml": 220,
    "calories": 149,
    "allergens": ["dairy"],
    "digestion_speed": "medium",
    "default_servings": 1,
    "min_servings": 0.5,
    "max_servings": 2
  }]'::jsonb,
  food_names = array_append(food_names, 'milk'),
  -- Add dairy allergen if not already present
  allergens = CASE
    WHEN NOT ('dairy' = ANY(COALESCE(allergens, '{}'::text[])))
      THEN COALESCE(allergens, '{}'::text[]) || ARRAY['dairy']::text[]
    ELSE allergens
  END,
  -- Add vegan and paleo to excluded_diets if not already present
  excluded_diets = (
    SELECT array_agg(DISTINCT d) FROM unnest(
      COALESCE(excluded_diets, '{}'::text[]) || ARRAY['vegan', 'paleo']::text[]
    ) AS d
  ),
  -- Recalculate totals: add 1 serving of milk (12g carbs, 8g protein, 8g fat, 105mg sodium, 220ml fluid, 149 cal)
  total_carbs_g = total_carbs_g + 12,
  total_protein_g = total_protein_g + 8,
  total_fat_g = total_fat_g + 8,
  total_sodium_mg = total_sodium_mg + 105,
  total_fluid_ml = total_fluid_ml + 220,
  total_calories = total_calories + 149
WHERE name IN (
  'Smoothie: Banana + PB + Milk',
  'Smoothie: Banana + Milk + Honey',
  'Smoothie: Banana + Dates + Milk',
  'Smoothie: Banana + Berries + Milk',
  'Smoothie: Banana + Protein Powder + Milk',
  'Smoothie: Banana + Oats + Milk + Honey'
)
AND NOT EXISTS (
  SELECT 1 FROM jsonb_array_elements(foods) AS food
  WHERE food->>'food_name' = 'milk'
);

-- ================================================================
-- Add OJ to "Smoothie: Mango + Banana + OJ"
-- ================================================================

UPDATE templates
SET
  foods = foods || '[{
    "food_id": "8e5ceb2a-c956-4c8d-8798-255eb6c048c3",
    "food_name": "orange_juice",
    "display_name": "Orange Juice",
    "serving_size": "1 cup (8 oz)",
    "carbs_g": 26,
    "protein_g": 1.7,
    "fat_g": 0.5,
    "sodium_mg": 2,
    "fluid_ml": 219,
    "calories": 111,
    "allergens": [],
    "digestion_speed": "fast",
    "default_servings": 1,
    "min_servings": 0.5,
    "max_servings": 2
  }]'::jsonb,
  food_names = array_append(food_names, 'orange_juice'),
  -- Recalculate totals: add 1 serving of OJ
  total_carbs_g = total_carbs_g + 26,
  total_protein_g = total_protein_g + 1.7,
  total_fat_g = total_fat_g + 0.5,
  total_sodium_mg = total_sodium_mg + 2,
  total_fluid_ml = total_fluid_ml + 219,
  total_calories = total_calories + 111
WHERE name = 'Smoothie: Mango + Banana + OJ'
AND NOT EXISTS (
  SELECT 1 FROM jsonb_array_elements(foods) AS food
  WHERE food->>'food_name' = 'orange_juice'
);
