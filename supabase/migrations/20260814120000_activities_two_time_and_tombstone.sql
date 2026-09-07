-- Macro-dashboard bundle (daily-macros-dashboard@v1), schema task 1:
-- the two-time model + the soft-delete tombstone on activities.
-- SSOT: docs/ssot/spec/daily-macros/platform-resolution.md (ruled 2026-08-14).
--
-- planned_time : set at scheduling; gestures NEVER write it. Survives Garmin
--                completion (unlike scheduled_date_time, which the completion
--                path historically overwrote with the actual start).
-- actual_time  : written by Garmin sync (activity start) or mark-done (= now);
--                cleared by mark-undone. Display shows actual ?? planned.
-- 'deleted'    : tombstone status. The row persists so the sync import
--                matcher can recognize a deleted workout and drop the
--                incoming platform activity instead of re-importing it
--                (match key: platform id, else platform+sport+start ±15 min).

-- Nullable, no default: no table rewrite, no lock pain on a large table.
--
-- TYPE: timestamp WITHOUT time zone, deliberately — the table's convention is
-- NAIVE LOCAL (scheduled_date_time is naive; the Garmin matcher's ±15 min
-- window and garminTimestampToLocalNaiveISO are built on it; the Dart client
-- uploads toIso8601String(), a naive local string). The first cut of this
-- file said `timestamptz`; on 2026-08-19 the dev deploy's live round-trip
-- shifted every value by the UTC offset (naive local string → read as UTC →
-- handed back +00:00 → parsed 5 h earlier), caught by the Patrol flow's
-- planned_time-immutability assert. Corrected in place before prod ever ran
-- it; dev was ALTERed with `USING (col AT TIME ZONE 'UTC')`, which exactly
-- recovers the stored naive-local values.
alter table public.activities
  add column if not exists planned_time timestamp without time zone,
  add column if not exists actual_time timestamp without time zone;

-- Correction for any environment that ran the first (timestamptz) cut of
-- this file — no-op where the columns are already naive:
do $$
begin
  if exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='activities'
               and column_name='planned_time'
               and data_type='timestamp with time zone') then
    alter table public.activities
      alter column planned_time type timestamp without time zone
        using (planned_time at time zone 'UTC'),
      alter column actual_time type timestamp without time zone
        using (actual_time at time zone 'UTC');
  end if;
end $$;

comment on column public.activities.planned_time is
  'Scheduled start (two-time model). Immutable by gestures; null for unscheduled imports.';
comment on column public.activities.actual_time is
  'Actual start: Garmin activity start, or mark-done time. Null until done; cleared by mark-undone.';

-- Tombstone status value. Since PG 12 ADD VALUE is transaction-safe; the new
-- value is usable after this migration commits.
alter type public.activity_status_enum add value if not exists 'deleted';

comment on type public.activity_status_enum is
  'Activity workflow states. archived_for_brick: combined into a brick workout. '
  'deleted: soft-delete tombstone — the row persists so sync matching can '
  'recognize it and not re-import the platform activity; it never renders and '
  'contributes zero to every derived quantity.';
