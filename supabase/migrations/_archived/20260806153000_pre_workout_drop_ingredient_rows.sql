-- ---------------------------------------------------------------------------
--  Drop the ingredient-shaped rows from pre_workout_templates.
--
--  Sprint task 3b3e3fdb…7b9c8d / food-composition v3 H5 ("the top-off must
--  deliver carbohydrate"). These rows existed only to feed Pass 2 (pickDrink)
--  and Pass 3 (pickElectrolyte); both passes now read the ingredient catalog
--  (template_foods — see generate-macros-v4/ingredient-pools.ts, 2026-08-06),
--  so H5 can hold literally: pre_workout_templates contains only real
--  formulas.
--
--  Scoped tightly by name AND template_type so no food formula can ever be
--  caught. 'Coconut Water' was already deleted on dev by the v3 data
--  migration (H2 fibre gate) but is kept in the list so this replays
--  correctly on prod regardless of migration order. Verified before applying:
--  zero formula_pins and zero personal_formulas reference these rows on dev.
--
--  Idempotent; replayable on prod.
-- ---------------------------------------------------------------------------

delete from pre_workout_templates
where template_type in ('drink', 'electrolyte')
  and name in (
    'Water',
    'Electrolyte Tablet',
    'Electrolyte Packet',
    'Electrolyte Drink Mix',
    'Sports Drink',
    'Coconut Water'
  );
