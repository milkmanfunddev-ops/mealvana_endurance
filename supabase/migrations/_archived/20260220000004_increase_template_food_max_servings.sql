-- Increase max_servings for key carb-rich foods in templates to allow
-- better scaling for high-carb targets (marathon, ultra distances).
--
-- The grid search scales all foods by the same multiplier (0.25x-4.0x)
-- and then clamps to min/max. With max_servings=2, templates top out at
-- ~110g carbs. Marathon runners with 3-4h prep need 200-400g pre-run carbs.
--
-- Increase max_servings for carb-rich staples that are safe in larger quantities:

-- Update max_servings in the foods JSONB arrays within templates
-- For each template, update food items where max_servings should be higher

-- High-carb staples that runners commonly eat in larger quantities:
-- oatmeal: safe at 3-4 servings (1.5-2 cups dry)
-- banana: safe at 3 (3 bananas is common pre-marathon)
-- rice: safe at 4 servings
-- bagel: safe at 2 (already there, bagels are big)
-- tortilla: safe at 3
-- pancake: safe at 4 (4 pancakes is a normal serving)

-- Update templates with jsonb_set for each food
-- We use a CTE to find and update the foods arrays

-- Increase banana max_servings from 2 to 3 in all templates
UPDATE templates
SET foods = (
  SELECT jsonb_agg(
    CASE
      WHEN (food->>'food_name') = 'banana' AND (food->>'max_servings')::numeric < 3
        THEN jsonb_set(food, '{max_servings}', '3')
      WHEN (food->>'food_name') IN ('oats_dry') AND (food->>'max_servings')::numeric < 4
        THEN jsonb_set(food, '{max_servings}', '4')
      WHEN (food->>'food_name') IN ('white_rice') AND (food->>'max_servings')::numeric < 4
        THEN jsonb_set(food, '{max_servings}', '4')
      WHEN (food->>'food_name') = 'flour_tortilla' AND (food->>'max_servings')::numeric < 3
        THEN jsonb_set(food, '{max_servings}', '3')
      WHEN (food->>'food_name') IN ('pancake', 'toaster_waffle') AND (food->>'max_servings')::numeric < 4
        THEN jsonb_set(food, '{max_servings}', '4')
      WHEN (food->>'food_name') = 'maple_syrup' AND (food->>'max_servings')::numeric < 4
        THEN jsonb_set(food, '{max_servings}', '4')
      WHEN (food->>'food_name') = 'honey' AND (food->>'max_servings')::numeric < 4
        THEN jsonb_set(food, '{max_servings}', '4')
      WHEN (food->>'food_name') IN ('granola_bar', 'fig_bar') AND (food->>'max_servings')::numeric < 3
        THEN jsonb_set(food, '{max_servings}', '3')
      WHEN (food->>'food_name') IN ('raisins', 'dates') AND (food->>'max_servings')::numeric < 3
        THEN jsonb_set(food, '{max_servings}', '3')
      WHEN (food->>'food_name') = 'grapes' AND (food->>'max_servings')::numeric < 3
        THEN jsonb_set(food, '{max_servings}', '3')
      WHEN (food->>'food_name') IN ('mixed_berries', 'blueberries', 'strawberries') AND (food->>'max_servings')::numeric < 3
        THEN jsonb_set(food, '{max_servings}', '3')
      WHEN (food->>'food_name') = 'pop_tarts' AND (food->>'max_servings')::numeric < 3
        THEN jsonb_set(food, '{max_servings}', '3')
      WHEN (food->>'food_name') IN ('pretzels', 'crackers', 'graham_crackers') AND (food->>'max_servings')::numeric < 3
        THEN jsonb_set(food, '{max_servings}', '3')
      ELSE food
    END
  )
  FROM jsonb_array_elements(templates.foods) AS food
)
WHERE foods IS NOT NULL AND jsonb_array_length(foods) > 0;
