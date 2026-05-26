-- ============================================================================
-- APPLY ALL — current PENDING SQL
--
-- The SINGLE file to paste into DataGrip and run, top to bottom, on DEV + PROD.
-- Every statement is idempotent — safe to re-run.
--
-- Already applied 2026-05-22 (NOT repeated here): formula_pins +
-- personal_templates formula-kit columns. custom_foods was applied then
-- reverted — see section 2.
-- ============================================================================


-- ── 1. Data-hygiene fixes #27 + #28 ─────────────────────────────────────────

-- #27: serving_unit is null catalog-wide; the display derives the unit from
-- display_name_plural, which fails for foods whose display_name has a "/"
-- alternative or a parenthetical (e.g. "1 Jam / Jelly"). Set serving_unit
-- explicitly for the offenders.
UPDATE template_foods SET serving_unit = 'tbsp'  WHERE name = 'jam'            AND serving_unit IS NULL;
UPDATE template_foods SET serving_unit = 'slice' WHERE name = 'toast'          AND serving_unit IS NULL;
UPDATE template_foods SET serving_unit = 'scoop' WHERE name = 'protein_powder' AND serving_unit IS NULL;

-- #28: "Potato + Salt" listed only baked_potato (17 mg) yet advertised 300 mg.
-- Add salt as 1 whole packet and set sodium to the true sum
-- (17 mg potato + 390 mg salt = 407 mg).
UPDATE pre_workout_templates
SET component_food_names = ARRAY['baked_potato', 'salt'],
    component_quantities = '{"baked_potato": 1, "salt": 1}'::jsonb,
    sodium_mg = 407
WHERE name = 'Potato + Salt';


-- ── 2. Remove custom_foods (duplicate of user_foods) ────────────────────────
-- user_foods already stores user-created foods with macros (owned, soft-deleted,
-- offline-synced) and is richer + already wired into the app. custom_foods was
-- an empty duplicate with no consumers. Formula Kit reuses user_foods instead.
DROP TABLE IF EXISTS custom_foods;

COMMENT ON COLUMN personal_templates.custom_food_ids IS
  'JSON array of user_foods.id values used as custom components in this formula.';

-- ============================================================================
-- END
-- ============================================================================
