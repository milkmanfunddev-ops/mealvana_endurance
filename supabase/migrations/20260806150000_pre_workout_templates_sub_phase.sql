-- ---------------------------------------------------------------------------
--  pre_workout_templates.sub_phase — category-based tier membership
--
--  Ruling (Lee, 2026-08-06): "when selecting meals, look at the CATEGORY of
--  the meal (full meal, snack, top off), not the time period, so we can
--  change times freely without changing the algorithm."
--
--  The 2026-08-05 time_window remap ('1.5-3 hours' -> '2-4 hours',
--  '30-90 min' -> '30-120 min') proved that deriving the tier from the
--  display label is fragile: every string move is a coordinated data + code
--  release (see docs/pre_workout_food_composition_v3_migration_report.md,
--  flag #1). This column makes the tier explicit. `time_window` stays as a
--  pure DISPLAY label from here on.
--
--  Values mirror BeforeSubPhase.storageValue on the client
--  ('full_meal' | 'snack' | 'top_up') so analytics payloads don't fork.
--
--  Scope: DEV now; replayable on prod (idempotent, and the backfill CASE
--  matches BOTH catalog generations so prod's old-generation windows map).
-- ---------------------------------------------------------------------------

begin;

alter table pre_workout_templates
  add column if not exists sub_phase text;

alter table pre_workout_templates
  drop constraint if exists pre_workout_templates_sub_phase_check;

alter table pre_workout_templates
  add constraint pre_workout_templates_sub_phase_check
  check (sub_phase in ('full_meal', 'snack', 'top_up'));

-- Backfill from time_window, accepting BOTH catalog generations so this
-- replays cleanly on prod (which still carries '1.5-3 hours' / '30-90 min').
update pre_workout_templates
set sub_phase = case
  when time_window in ('2-4 hours', '1.5-3 hours') then 'full_meal'
  when time_window in ('30-120 min', '30-90 min')  then 'snack'
  when time_window = '< 30 min'                    then 'top_up'
end
where sub_phase is null;

-- Every known window maps, so NOT NULL is safe after the backfill. Guarded so
-- a future unknown window makes the migration fail loudly instead of leaving
-- a silent NULL behind the NOT NULL attempt.
do $$
begin
  if exists (select 1 from pre_workout_templates where sub_phase is null) then
    raise exception
      'pre_workout_templates rows with unmappable time_window remain — refusing to set sub_phase NOT NULL';
  end if;
  alter table pre_workout_templates alter column sub_phase set not null;
end $$;

comment on column pre_workout_templates.sub_phase is
  'Tier membership (full_meal | snack | top_up). The selection algorithm keys on this '
  'column; time_window is a display label only and may change freely (Lee ruling 2026-08-06). '
  'Mirrors BeforeSubPhase.storageValue on the client.';

commit;
