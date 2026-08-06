-- ---------------------------------------------------------------------------
--  Source of truth: qa repo tag  pre-workout-food-composition@v1
--                   spec/fueling/pre-workout-food-composition.md  (food-composition v3)
--  Generated:       2026-08-05
--  Scope:           DEV. Replayable on prod -- idempotent.
--  Follows:         20260805120100_pre_workout_food_composition_v3_data.sql
-- ---------------------------------------------------------------------------
--
--  Drop the five STANDALONE G4b rows at the meal and snack tiers.
--
--  WHY -- a product rule the SSOT does not model (Xuan, 2026-08-05):
--
--    A row in pre_workout_templates must be a STANDALONE-SUFFICIENT feeding for
--    its window. The engine does not stack two formulas inside one window, so a
--    row has to answer the window on its own. A sports drink is 15 g of
--    carbohydrate and a gel is 25 g -- neither is a snack, let alone a meal.
--
--  These rows were added by the v3 data migration on a correct reading of the
--  SSOT that was nonetheless the wrong call for the product. Section 3.4's v3
--  ruling and check 10 say G4b is PERMITTED at every tier -- which is a statement
--  about what a composed feeding MAY CONTAIN, not a licence to publish each G4b
--  item as a feeding in its own right. Permission is not sufficiency.
--
--  NOT A DEVIATION -- corrected 2026-08-05. An earlier version of this header
--  claimed dropping these rows conflicted with section 11 check 10 and needed a
--  DEVIATIONS.md entry. That was wrong.
--
--      The conformance vectors test a SUITABILITY FUNCTION, not this table.
--      `matrix-G4b-meal` takes {tier, foodGroup, gutTolerance} and asserts
--      {available: true, rating: 'FREE'} -- a pure function of the section 3.10
--      table. `g4b-sports-drink-meal` passes summed macros straight in. No
--      vector reads pre_workout_templates, the vectors' `engine` field is null,
--      and their note states that food-to-macro lookup "is a separate food-
--      database concern."
--
--      So check 10 requires the ENGINE to permit a G4b item at the meal tier.
--      It does not require this catalog to CONTAIN one. pre_workout_templates
--      is a curated subset that must CONFORM to the SSOT, not EXHAUST it.
--      Declining to publish a formula is a curation decision, outside the
--      SSOT's remit. No DEVIATIONS.md entry is needed.
--
--  The SNACK tier keeps G4b representation anyway through 'Pretzels + Sports
--  Drink' (38 g carbohydrate, section 3.11 canonical snack #5).
--
--  Not touched: the top-off rows. Energy Gel, Energy Chews, Sports Drink and
--  Energy Gel + Water at '< 30 min' are exactly what a top-off is for
--  (section 2: "carbohydrate delivery, not digestion") and stay.
-- ---------------------------------------------------------------------------

begin;

delete from pre_workout_templates where name = 'Sports Drink (Meal)';
delete from pre_workout_templates where name = 'Sports Drink (Snack)';
delete from pre_workout_templates where name = 'Energy Gel (Meal)';
delete from pre_workout_templates where name = 'Energy Gel (Snack)';
delete from pre_workout_templates where name = 'Energy Chews (Snack)';

commit;
