-- Issue #12: Granola Bar shares base_category with gels/chews causing cross-phase duplication
--
-- The pre-workout algorithm (pre-workout.ts) treats `base_category` as the dedup key
-- across phases, so any two templates sharing a category are penalized when chosen for
-- different phases. Granola Bar (snack window) and Energy Gel/Chews (top-up window) all
-- shared `base_category = 'Quick Grab'`, so a gel in top-up was deprioritizing the
-- granola bar in the snack slot — even though they're fundamentally different foods.
--
-- Fix: rename `Oatmeal` -> `Oats / Granola` (same naming style as `Toast / Bread`),
-- and move Granola Bar into that category. Granola is oat-based, so the grouping is
-- semantically clean. `Quick Grab` then accurately describes its remaining contents
-- (engineered fast-absorbing sport carbs: gels and chews).

UPDATE public.pre_workout_templates
SET base_category = 'Oats / Granola'
WHERE base_category = 'Oatmeal';

UPDATE public.pre_workout_templates
SET base_category = 'Oats / Granola'
WHERE name = 'Granola Bar';
