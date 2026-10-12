-- One-off: re-derive events.event_date from start_time (ticket 65, round
-- develop-2026-10). start_time is the source; event_date is its derived copy.
--
-- The unique index and duplicate sweep this once preceded were withdrawn
-- 2026-10-12 (1.29.1 pre-ship audit). Diagnostic only; not run on prod.
--
-- start_time is naive local text ('YYYY-MM-DDTHH:MM:SS...', no offset on any
-- dev or prod row, checked read-only 2026-10-08), so the date is the first ten
-- characters. `is distinct from` also catches event_date null; `<>` skips it.
-- updated_at moves so EventSyncHandler.upsertEvent's newer-than check pulls
-- the change down (the app's download path re-derives regardless).

-- 1. Read-only: the rows that would change (dev 9, prod 6 expected).
select id, user_id, event_name, event_date, start_time, origin, updated_at
  from events
 where start_time ~ '^\d{4}-\d{2}-\d{2}'
   and event_date is distinct from left(start_time, 10)::date
 order by user_id, start_time;

-- 2. The write.
-- update events
--    set event_date = left(start_time, 10)::date,
--        updated_at = now()
--  where start_time ~ '^\d{4}-\d{2}-\d{2}'
--    and event_date is distinct from left(start_time, 10)::date;

-- 3. After: expect 0.
-- select count(*)
--   from events
--  where start_time ~ '^\d{4}-\d{2}-\d{2}'
--    and event_date is distinct from left(start_time, 10)::date;
