-- One-off: sweep duplicate events before the unique index
-- (user_id, event_date, event_name) lands (ticket 65, round develop-2026-10;
-- Lee's ruling 2026-10-08: oldest row kept).
--
-- Order at the close: scripts/events_rederive_event_date.sql FIRST (this sweep
-- groups on event_date, the index key, so it must see the re-derived dates),
-- then THIS FILE, then migration
-- 20261008166500_events_unique_user_date_name.sql.
--
-- A group is same user_id + same event_date + same event_name. Rows with a
-- null event_date or event_name are not grouped: the unique index treats nulls
-- as distinct, so they never collide. In each group the OLDEST row is kept
-- (created_at, then id, ascending); the rest are removed.
--
-- carb_loading_plans.event_id references events ON DELETE CASCADE, so a
-- removed row's plans would be deleted with it. Step 2 repoints them to the
-- kept row first. Nothing else references events (pg_constraint, dev and prod,
-- 2026-10-08).
--
-- Expected at 2026-10-08 (read-only listing, before the re-derive, which
-- touches none of these rows):
--   dev  3 groups, 9 rows, 6 removed: "IM NC 70.3" x3 (training_peaks, keep
--        581e21b5), "Test" x2 (keep 11), "Jjjjj" x4 (keep 16). No plans.
--   prod 4 groups, 10 rows, 6 removed: "Test" x2 (keep 11), "Jjjjj" x4
--        (keep 16), "test123" x2 (keep 7ed4623d, which holds the 2 plans),
--        "IRONMAN Florida" x2 (keep 31133a0b, 1 plan; removes 44f05953, which
--        is linked to a different activity, 398bdce9; see ticket 65's
--        Questions for Lee before running this on prod).

-- 1. Read-only listing: every row in a duplicate group and what happens to it.
with ranked as (
  select e.*,
         row_number() over w as rn,
         first_value(e.id) over w as keep_id,
         count(*) over (partition by e.user_id, e.event_date, e.event_name) as n
    from events e
   where e.event_date is not null
     and e.event_name is not null
  window w as (partition by e.user_id, e.event_date, e.event_name
               order by e.created_at, e.id)
)
select case when rn = 1 then 'keep' else 'remove' end as action,
       id, keep_id, user_id, event_name, event_date, start_time, origin,
       activity_id, created_at,
       (select count(*) from carb_loading_plans c where c.event_id = ranked.id)
         as carb_plans_to_repoint
  from ranked
 where n > 1
 order by user_id, event_date, event_name, rn;

-- 2. The write. Run as one transaction; it re-checks the precondition.
-- begin;
--
-- do $$
-- begin
--   if exists (
--     select 1 from events
--      where start_time ~ '^\d{4}-\d{2}-\d{2}'
--        and event_date is distinct from left(start_time, 10)::date
--   ) then
--     raise exception 'run scripts/events_rederive_event_date.sql first';
--   end if;
-- end $$;
--
-- create temp table events_sweep on commit drop as
-- select id as remove_id, keep_id
--   from (
--     select e.id,
--            row_number() over w as rn,
--            first_value(e.id) over w as keep_id
--       from events e
--      where e.event_date is not null
--        and e.event_name is not null
--     window w as (partition by e.user_id, e.event_date, e.event_name
--                  order by e.created_at, e.id)
--   ) r
--  where rn > 1;
--
-- select * from events_sweep;  -- dev 6, prod 6 expected
--
-- update carb_loading_plans c
--    set event_id = s.keep_id
--   from events_sweep s
--  where c.event_id = s.remove_id;
--
-- delete from events e
--  using events_sweep s
--  where e.id = s.remove_id;
--
-- commit;

-- 3. After: expect 0 rows.
-- select user_id, event_date, event_name, count(*)
--   from events
--  where event_date is not null and event_name is not null
--  group by 1, 2, 3
-- having count(*) > 1;
