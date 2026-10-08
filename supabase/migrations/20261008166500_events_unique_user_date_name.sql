-- Ticket 65 (round develop-2026-10; Lee's ruling 2026-10-08): one event per
-- user, day and name. Enforces the key the provider-import dedupe
-- (EventsRepository.findExistingEvent) and auth_migration_service already
-- assume. Before this, nothing on the server enforced it.
--
-- RUN FIRST, IN ORDER, or this fails with 23505 on the existing duplicates:
--   1. scripts/events_rederive_event_date.sql  (event_date := start_time's date)
--   2. scripts/events_duplicate_sweep.sql      (keeps the oldest row per group)
-- Dev at the round's close; prod at the next prod bundle, same order.
--
-- Nulls are distinct in a unique index, so rows with a null event_date or
-- event_name never collide. Idempotent.

create unique index if not exists events_user_date_name_unique
  on public.events (user_id, event_date, event_name);
