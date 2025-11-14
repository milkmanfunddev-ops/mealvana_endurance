-- Populate foods.categories array column from food_categories junction table
-- This migration converts the old many-to-many relationship into the new array column format

-- Step 1: Update foods.categories from food_categories junction table
UPDATE foods
SET categories = COALESCE(
  (
    SELECT array_agg(c.name ORDER BY c.id)
    FROM food_categories fc
    JOIN categories c ON fc.category_id = c.id
    WHERE fc.food_id = foods.id
  ),
  ARRAY[]::text[] -- Default to empty array if no categories
);

-- Step 2: Set default categories for foods that have no categories assigned
-- Before-run suitable foods (based on common breakfast/pre-workout foods)
UPDATE foods
SET categories = ARRAY['before_run', 'after_run']::text[]
WHERE categories = ARRAY[]::text[]
  AND (
    name ILIKE '%toast%' OR
    name ILIKE '%bagel%' OR
    name ILIKE '%banana%' OR
    name ILIKE '%oatmeal%' OR
    name ILIKE '%coffee%' OR
    name ILIKE '%yogurt%' OR
    name ILIKE '%peanut butter%' OR
    name ILIKE '%apple%' OR
    name ILIKE '%berries%' OR
    name ILIKE '%orange juice%'
  );

-- During-run suitable foods (energy products)
UPDATE foods
SET categories = ARRAY['during_run']::text[]
WHERE categories = ARRAY[]::text[]
  AND (
    name ILIKE '%gel%' OR
    name ILIKE '%chew%' OR
    name ILIKE '%sports drink%' OR
    name ILIKE '%energy waffle%' OR
    name ILIKE '%electrolyte%' OR
    name ILIKE '%salt packet%' OR
    name ILIKE '%water%'
  );

-- Post-run suitable foods (recovery foods)
UPDATE foods
SET categories = ARRAY['after_run']::text[]
WHERE categories = ARRAY[]::text[]
  AND (
    name ILIKE '%protein shake%' OR
    name ILIKE '%protein bar%' OR
    name ILIKE '%protein powder%' OR
    name ILIKE '%chocolate milk%'
  );

-- All-purpose foods (can be used in any phase)
UPDATE foods
SET categories = ARRAY['before_run', 'during_run', 'after_run']::text[]
WHERE categories = ARRAY[]::text[]
  AND (
    name ILIKE '%energy bar%' OR
    name ILIKE '%fig bar%' OR
    name ILIKE '%dates%' OR
    name ILIKE '%pretzels%'
  );

-- Default fallback: if still no categories, make available for all phases
UPDATE foods
SET categories = ARRAY['before_run', 'during_run', 'after_run']::text[]
WHERE categories = ARRAY[]::text[] OR categories IS NULL;

-- Step 3: Set default activity_types (all foods suitable for running by default)
UPDATE foods
SET activity_types = ARRAY['running']::text[]
WHERE activity_types IS NULL OR activity_types = ARRAY[]::text[];

-- Step 4: Verify the migration
DO $$
DECLARE
  total_foods INTEGER;
  foods_with_categories INTEGER;
  foods_with_activity_types INTEGER;
BEGIN
  SELECT COUNT(*) INTO total_foods FROM foods;
  SELECT COUNT(*) INTO foods_with_categories FROM foods WHERE categories IS NOT NULL AND array_length(categories, 1) > 0;
  SELECT COUNT(*) INTO foods_with_activity_types FROM foods WHERE activity_types IS NOT NULL AND array_length(activity_types, 1) > 0;

  RAISE NOTICE 'Migration complete:';
  RAISE NOTICE '  Total foods: %', total_foods;
  RAISE NOTICE '  Foods with categories: %', foods_with_categories;
  RAISE NOTICE '  Foods with activity_types: %', foods_with_activity_types;

  IF total_foods > 0 AND (foods_with_categories < total_foods OR foods_with_activity_types < total_foods) THEN
    RAISE WARNING 'Some foods may not have categories or activity_types assigned!';
  END IF;
END $$;
