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
--  >>> KNOWN DEVIATION, needs logging in the qa repo's DEVIATIONS.md <<<
--      After this migration the MEAL tier contains no G4b item at all, which is
--      the one thing v3 actually changed. A conformance harness asserting
--      "a sports drink is available at the meal tier" will fail against this
--      data. That is a deliberate product decision, not a data error -- but it
--      is a genuine divergence from the ratified SSOT and must not be silent.
--
--      The SNACK tier keeps G4b representation through 'Pretzels + Sports Drink'
--      (38 g carbohydrate, section 3.11 canonical snack #5), so only the meal
--      tier diverges.
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
