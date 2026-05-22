-- Data-hygiene fixes #27 + #28 (Formula Kit polish), 2026-05-22.
-- Apply via DataGrip to dev + prod. Idempotent.

-- #27 — serving_unit is null catalog-wide; the display derives the unit from
-- display_name_plural, which fails for foods whose display_name has a "/"
-- alternative or a parenthetical, yielding unit-less strings like
-- "1 Jam / Jelly". Set serving_unit explicitly for the affected foods so the
-- display path uses it directly. (Guarded so it won't clobber a future value.)
UPDATE template_foods SET serving_unit = 'tbsp'  WHERE name = 'jam'            AND serving_unit IS NULL;
UPDATE template_foods SET serving_unit = 'slice' WHERE name = 'toast'          AND serving_unit IS NULL;
UPDATE template_foods SET serving_unit = 'scoop' WHERE name = 'protein_powder' AND serving_unit IS NULL;

-- #28 — "Potato + Salt" advertised 300 mg sodium but listed only baked_potato
-- (17 mg) as a component, so the salt was invisible on the detail screen.
-- Add salt as a whole packet (the natural unit) and set sodium_mg to the sum
-- of the components: 17 mg potato + 1 packet salt (390 mg) = 407 mg.
UPDATE pre_workout_templates
SET component_food_names = ARRAY['baked_potato', 'salt'],
    component_quantities = '{"baked_potato": 1, "salt": 1}'::jsonb,
    sodium_mg = 407
WHERE name = 'Potato + Salt';
