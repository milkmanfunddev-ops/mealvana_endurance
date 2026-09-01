-- ---------------------------------------------------------------------------
--  PROD CUTOVER — STEP 1 of 4.  Run BEFORE the v3 data migrations.
--
--  WHY THIS FILE EXISTS
--  --------------------
--  Prod applied the migrations in a different ORDER than dev did, and that
--  reordering turned the data migration into a hard failure.
--
--    dev  : v3 data (2026-08-05)  ->  sub_phase (2026-08-06)
--    prod : sub_phase (2026-08-10)  ->  v3 data (NOT YET APPLIED)
--
--  20260806150000_pre_workout_templates_sub_phase.sql ends with
--  `alter column sub_phase set not null`. On dev that was safe: the 17 new v3
--  rows already existed, so the backfill covered them before NOT NULL landed.
--
--  On prod, sub_phase is ALREADY NOT NULL (verified 2026-08-11), and the
--  INSERT column lists in 20260805120100_..._v3_data.sql do NOT include
--  sub_phase -- the file was generated 2026-08-05, a day before that column
--  existed. Every one of the 17 inserts would therefore abort with
--  23502 not_null_violation and roll the whole migration back.
--
--  This file drops the NOT NULL for the duration of the cutover.
--  40_post_relock_and_verify.sql backfills the new rows and puts it back.
--
--  Idempotent. Safe to re-run.
-- ---------------------------------------------------------------------------

begin;

-- Fail loudly if this is somehow run against a database that never got the
-- sub_phase migration -- that would mean the run order is wrong, not that
-- there is nothing to do.
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name   = 'pre_workout_templates'
      and column_name  = 'sub_phase'
  ) then
    raise exception
      'pre_workout_templates.sub_phase is missing -- apply 20260806150000_pre_workout_templates_sub_phase.sql first';
  end if;
end $$;

alter table public.pre_workout_templates
  alter column sub_phase drop not null;

commit;
