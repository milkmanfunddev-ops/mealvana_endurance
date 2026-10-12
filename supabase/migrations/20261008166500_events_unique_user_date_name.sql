-- Ticket 65 (round develop-2026-10) proposed a unique index on events
-- (user_id, event_date, event_name). WITHDRAWN 2026-10-12 (Xuan, 1.29.1
-- pre-ship audit): no athlete ever hit the bug it guarded against (it came
-- from one old dev test row), and applying it to prod first required
-- scripts/events_duplicate_sweep.sql to DELETE athletes' events (6 prod rows
-- on 2026-10-12, one of them a race 26 days out with a linked workout).
--
-- Kept as a no-op so the version dev already recorded stays in the history;
-- 20261012120000_drop_events_user_date_name_unique.sql removes the index
-- where it was applied (dev). Prod never gets it.

select 1;
