-- Ticket 80 Q3 (round develop-2026-10; Lee's ruling 2026-10-09): store the
-- provider's own id for an imported event (TrainingPeaks `EventId`) and match
-- the import on it before (user, name, date). A renamed or re-dated imported
-- event is then not imported a second time.
--
-- Additive and nullable: manual rows and rows imported before this stay null
-- and keep the (name, date) match. The client sends `provider_event_id` only
-- when it is set, so manual-event uploads work before this is applied;
-- imported-event uploads do not (PGRST204), so APPLY THIS BEFORE the build
-- carrying Drift v25 reaches a device. Then app_config.current_schema_version
-- may go to 25. Not unique: an index only, never an onConflict target.
-- Idempotent.

alter table public.events
  add column if not exists provider_event_id text;

comment on column public.events.provider_event_id is
  'Provider''s own id for an imported event (TrainingPeaks EventId); the import matches on it before (user, name, date). Null for manual rows.';

create index if not exists events_user_provider_event_id_idx
  on public.events (user_id, provider_event_id)
  where provider_event_id is not null;
