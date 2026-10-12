-- Withdraws ticket 65's unique index (see
-- 20261008166500_events_unique_user_date_name.sql, now a no-op). Dev applied
-- it at the round's close; prod never did, so here this is a no-op.
-- Idempotent.

drop index if exists public.events_user_date_name_unique;
