-- ---------------------------------------------------------------------------
--  Source of truth: qa repo tag  pre-workout-food-composition@v1
--                   spec/fueling/pre-workout-food-composition.md  (food-composition v3,
--                   RATIFIED 2026-08-05)
--                   vectors/fueling/pre-workout-food-composition.json  (87 vectors)
--  Generated:       2026-08-05
--  Scope:           DEV. Replayable on prod -- every statement is idempotent.
-- ---------------------------------------------------------------------------
--  STRUCTURE ONLY. Purely additive: no column is renamed or dropped.
--
--  THREE CHANGES, all required by the SSOT:
--
--  1. time_window CHECK widened. The pre-workout window moved from 90 min to 2 h,
--     so section 2's tiers are meal 240-120 min, snack 120-30 min, top-off 30-0 min.
--     The old values are kept in the constraint so this migration can be applied
--     BEFORE the data migration and before the app ships matching code.
--
--  2. pre_workout_templates.fiber_per_serving  -- NEW COLUMN.
--     H2 is a per-feeding fibre gate. The parent table stores carbs/protein/fat but
--     no fibre, so H2 is unenforceable against a template without this column.
--     >>> Lee: Drift table needs this column before the app builds. <<<
--
--  3. template_foods.food_group  -- NEW COLUMN.
--     Layer A (section 3) is the primary recommendation and the section 3.10 tier
--     matrix is keyed by food group. Nothing in the schema records which group a
--     food belongs to, so the matrix cannot be evaluated at all today.
--     >>> Lee: Drift table needs this column before the app builds. <<<
-- ---------------------------------------------------------------------------

begin;

-- 1 ── widen the time-window vocabulary -------------------------------------
alter table pre_workout_templates
  drop constraint if exists pre_workout_formulas_time_window_check;

alter table pre_workout_templates
  add constraint pre_workout_formulas_time_window_check
  check (time_window = any (array[
    '< 30 min'::text,       -- top-off  (30-0 min)   -- unchanged
    '30-120 min'::text,     -- snack    (120-30 min) -- NEW, replaces '30-90 min'
    '2-4 hours'::text,      -- meal     (240-120 min)-- NEW, replaces '1.5-3 hours'
    '30-90 min'::text,      -- legacy, retained so this migration is order-independent
    '1.5-3 hours'::text     -- legacy, retained so this migration is order-independent
  ]));

-- 2 ── per-serving fibre, required by H2 -------------------------------------
alter table pre_workout_templates
  add column if not exists fiber_per_serving numeric not null default 0;

comment on column pre_workout_templates.fiber_per_serving is
  'Fibre in grams per 1x serving, summed from component_food_names. Required by hard gate H2 '
  'of pre-workout-food-composition v3 (meal <= max(8 g, 0.12 g/kg), snack <= max(4 g, 0.06 g/kg), '
  'top-off <= 2 g flat).';

-- 3 ── Layer A food group, required by the section 3.10 tier matrix ----------
alter table template_foods
  add column if not exists food_group text;

alter table template_foods
  drop constraint if exists template_foods_food_group_check;

alter table template_foods
  add constraint template_foods_food_group_check
  check (food_group is null or food_group = any (array[
    'G1'::text,  -- refined starches
    'G2'::text,  -- cooked starchy vegetables
    'G3'::text,  -- low-residue fruit
    'G4a'::text, -- sugars and syrups
    'G4b'::text, -- engineered sports carbohydrate
    'G5'::text,  -- lean protein
    'G6'::text,  -- dairy and alternatives
    'G7'::text,  -- added fats
    'G8'::text,  -- high-residue whole foods
    'G9'::text   -- high-FODMAP
  ]));

comment on column template_foods.food_group is
  'Layer A food group per pre-workout-food-composition v3 section 3.1-3.9. Drives the section 3.10 '
  'tier matrix. NULL means the food is not classified by that SSOT (e.g. water, salt, electrolyte '
  'tablets), not that it is unrestricted. NOTE: section 3.9 states G9 deliberately overlaps G3 and '
  'G8, and the SSOT publishes no precedence rule -- this single-value column forces one reading. '
  'See the bundle conformance note, tripwire vector matrix-groups-are-disjoint.';

create index if not exists idx_template_foods_food_group
  on template_foods (food_group)
  where food_group is not null;

commit;
