-- Backfill pre_workout_templates.fluid_ml for food-type composite templates.
--
-- The column was added DEFAULT 0 NOT NULL (20260313000000) and only ever
-- seeded for the three drink rows (Water, Coconut Water, Sports Drink).
-- Food-type rows sat at 0, which made normalizeExplosionMacros scale every
-- exploded component's fluid to zero — "Full Meal" (oatmeal + raisins) and
-- "Pre-Workout Snack" (banana + blueberries + milk) reported 0 oz FLUIDS
-- (bug 3abe3fdb754c81ff879bdd1e5e28c0aa, Wiredash 2026-07-28).
--
-- Derive each food-type template's fluid from the sum of its components'
-- template_foods.fluid_ml weighted by component_quantities (default 1 when a
-- component has no explicit quantity). Only rows currently at 0 are touched;
-- curated nonzero values (the drink rows) are left alone.

UPDATE pre_workout_templates t
SET fluid_ml = sub.fluid_sum
FROM (
  SELECT
    t2.id,
    ROUND(
      SUM(
        tf.fluid_ml
        * COALESCE((t2.component_quantities ->> tf.name)::numeric, 1)
      )::numeric,
      1
    ) AS fluid_sum
  FROM pre_workout_templates t2
  JOIN template_foods tf
    ON tf.name = ANY (t2.component_food_names)
  WHERE t2.template_type = 'food'
    AND t2.fluid_ml = 0
  GROUP BY t2.id
) sub
WHERE t.id = sub.id
  AND sub.fluid_sum > 0;
