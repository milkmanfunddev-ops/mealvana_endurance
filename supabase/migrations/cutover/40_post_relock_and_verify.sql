-- ---------------------------------------------------------------------------
--  PROD CUTOVER — STEP 3 of 4.  Run AFTER all three v3 data migrations.
--
--  Does three things:
--    1. Backfills sub_phase on the 17 rows the v3 data migration inserted
--       (that file predates the column -- see 00_pre_unlock_sub_phase.sql).
--    2. Clears formula_pins that now dangle, because the deletes in the data
--       migrations orphan them silently -- there is NO foreign key on
--       formula_pins.template_id (verified on prod 2026-08-11).
--    3. Re-asserts NOT NULL and verifies prod landed on exactly dev's shape.
--
--  PROD IS NOT DEV HERE. The migration headers state "zero formula_pins and
--  zero personal_formulas reference these rows on dev". That is true of dev
--  and FALSE of prod. Live prod check, 2026-08-11:
--
--    formula_pins      1  -> 'Dates + Banana'          (user 5c25e7b0…)
--    personal_formulas 2  -> 'Electrolyte Drink Mix'   (user 5f6ff116…)
--                            'Bagel + Peanut Butter'   (user e92cb452…)
--
--  personal_formulas are independent COPIES -- source_template_id is
--  provenance only, and the athlete's formula keeps working when the source
--  row goes away. They are deliberately left alone; only the pin is cleared,
--  because a pin whose template no longer exists resolves to nothing and the
--  athlete sees an empty slot with no way to clear it.
--
--  Idempotent. Safe to re-run.
-- ---------------------------------------------------------------------------

begin;

-- ── 1. sub_phase for the rows the v3 data migration inserted ───────────────
-- Same CASE as 20260806150000, still accepting both catalog generations so a
-- partially-applied cutover converges rather than failing.
update public.pre_workout_templates
set sub_phase = case
  when time_window in ('2-4 hours', '1.5-3 hours') then 'full_meal'
  when time_window in ('30-120 min', '30-90 min')  then 'snack'
  when time_window = '< 30 min'                    then 'top_up'
end
where sub_phase is null;

-- ── 2. Drop pins orphaned by the cutover deletes ───────────────────────────
-- Scoped to template_kind = 'pre_system' ONLY. template_id is polymorphic
-- across the template tables (prod carries during_system 11, personal_formula
-- 4, post_system 2, pre_system 15), so an unscoped
-- "not in pre_workout_templates" would delete every during-, post- and
-- personal-formula pin on the platform.
delete from public.formula_pins fp
where fp.template_kind = 'pre_system'
  and not exists (
    select 1 from public.pre_workout_templates t
    where t.id::text = fp.template_id::text
  );

-- ── 3. Re-assert NOT NULL ──────────────────────────────────────────────────
do $$
begin
  if exists (select 1 from public.pre_workout_templates where sub_phase is null) then
    raise exception
      'pre_workout_templates rows with unmappable time_window remain -- refusing to restore NOT NULL';
  end if;
  alter table public.pre_workout_templates alter column sub_phase set not null;
end $$;

-- ── 4. Verify prod landed on dev's shape ───────────────────────────────────
-- Live dev, 2026-08-11: full_meal 14 / snack 10 / top_up 5 = 29 rows.
-- Anything else means a migration was skipped or run out of order.
do $$
declare
  n_meal  int;
  n_snack int;
  n_top   int;
  n_group int;
begin
  select count(*) into n_meal  from public.pre_workout_templates where sub_phase = 'full_meal';
  select count(*) into n_snack from public.pre_workout_templates where sub_phase = 'snack';
  select count(*) into n_top   from public.pre_workout_templates where sub_phase = 'top_up';
  select count(*) into n_group from public.template_foods where food_group is not null;

  if (n_meal, n_snack, n_top) is distinct from (14, 10, 5) then
    raise exception
      'pre_workout_templates shape is full_meal=%, snack=%, top_up=% -- expected 14/10/5 (dev parity)',
      n_meal, n_snack, n_top;
  end if;

  -- Layer A selection is keyed by food group; prod had 0 of 93 populated
  -- before the cutover, so a zero here means the v3 data migration's
  -- section 1 did not run.
  if n_group = 0 then
    raise exception
      'template_foods.food_group is entirely NULL -- the v3 data migration did not apply';
  end if;

  raise notice 'cutover OK: 14/10/5 templates, % template_foods carry a food_group', n_group;
end $$;

commit;
