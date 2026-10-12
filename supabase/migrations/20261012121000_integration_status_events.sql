-- Reconnect notice measurement (1.29.1, Xuan 2026-10-12: "everything
-- measurable"). One row each time a connection enters or leaves
-- `requires_reauth`, whoever wrote it: the app (any provider) or an edge
-- function (Garmin). The row on `integrations` keeps only its latest status,
-- so without this a flag that cleared itself leaves no trace (D9: silent
-- paths must record, prod-readable).
--
-- How a flag ends, read from to_status:
--   'pending'  -> reconnected (every connect writes pending: the four
--                 *_oauth_service.dart upserts)
--   'success'  -> cleared by itself: the connection worked again with no
--                 reconnect (a Garmin push, a later sync). A false alarm, or a
--                 dead connection that recovered.
--   to_active = false -> the athlete disconnected instead
-- keys_changed: the refresh token differs from before (a reconnect or a
-- renewal; also what a stale device putting back old keys looks like, see
-- ops bug 2026-10-12-connection-status-save-resends-sign-in-keys).
--
-- Read by ops/queries/observe/reconnect-notice-false-alarms.sql (Monday
-- release postmortem). Server-only: RLS on, no policies, no grants to app
-- roles. Additive; safe to apply before the build.

create table if not exists public.integration_status_events (
  id bigint generated always as identity primary key,
  user_id uuid not null,
  provider text not null,
  from_status text,
  to_status text,
  from_active boolean,
  to_active boolean,
  error_code text,
  keys_changed boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists integration_status_events_provider_created_idx
  on public.integration_status_events (provider, created_at);

alter table public.integration_status_events enable row level security;
revoke all on public.integration_status_events from anon, authenticated;

create or replace function public.log_integration_status_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    if new.last_sync_status = 'requires_reauth' then
      insert into public.integration_status_events
        (user_id, provider, from_status, to_status, from_active, to_active,
         error_code, keys_changed)
      values
        (new.user_id, new.provider, null, new.last_sync_status, null,
         new.is_active, new.last_sync_error, false);
    end if;
    return new;
  end if;

  if (old.last_sync_status is distinct from new.last_sync_status
        and (old.last_sync_status = 'requires_reauth'
             or new.last_sync_status = 'requires_reauth'))
     or (old.is_active is distinct from new.is_active
        and old.last_sync_status = 'requires_reauth') then
    insert into public.integration_status_events
      (user_id, provider, from_status, to_status, from_active, to_active,
       error_code, keys_changed)
    values
      (new.user_id, new.provider, old.last_sync_status, new.last_sync_status,
       old.is_active, new.is_active, new.last_sync_error,
       old.refresh_token is distinct from new.refresh_token);
  end if;
  return new;
end;
$$;

revoke all on function public.log_integration_status_event() from public, anon, authenticated;

drop trigger if exists integrations_status_event on public.integrations;
create trigger integrations_status_event
  after insert or update on public.integrations
  for each row execute function public.log_integration_status_event();
