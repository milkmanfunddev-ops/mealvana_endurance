-- Idempotent, additive; timestamps are UTC timestamptz. Apply dev first, prod only at release.
-- Kroger credentials and OAuth state are service-role only. Drafts are owner scoped.
create table if not exists public.kroger_connections (
  user_id uuid primary key references auth.users(id) on delete cascade,
  access_token text not null,
  refresh_token text,
  expires_at timestamptz not null,
  environment text not null check (environment in ('certification', 'production')),
  refresh_locked_until timestamptz not null default '-infinity',
  updated_at timestamptz not null default now()
);
create table if not exists public.kroger_oauth_sessions (
  state uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  environment text not null,
  expires_at timestamptz not null default now() + interval '10 minutes'
);
create table if not exists public.kroger_drafts (
  id uuid primary key, -- stable meal-plan ID
  user_id uuid not null references auth.users(id) on delete cascade,
  revision integer not null default 1,
  draft jsonb not null,
  updated_at timestamptz not null default now()
);
create table if not exists public.kroger_exports (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  plan_id uuid not null,
  environment text not null check (environment in ('certification', 'production')),
  fingerprint text not null,
  payload jsonb not null,
  status text not null check (status in ('sending', 'sent', 'unknown')),
  created_at timestamptz not null default now(),
  unique(user_id, plan_id, environment)
);
alter table public.kroger_connections enable row level security;
alter table public.kroger_oauth_sessions enable row level security;
alter table public.kroger_drafts enable row level security;
alter table public.kroger_exports enable row level security;
revoke all on public.kroger_connections, public.kroger_oauth_sessions, public.kroger_drafts, public.kroger_exports from anon, authenticated;
grant all on public.kroger_connections, public.kroger_oauth_sessions, public.kroger_drafts, public.kroger_exports to service_role;
grant select on public.kroger_drafts, public.kroger_exports to authenticated;
drop policy if exists kroger_draft_owner on public.kroger_drafts;
create policy kroger_draft_owner on public.kroger_drafts for select to authenticated using (user_id = auth.uid());
drop policy if exists kroger_export_owner on public.kroger_exports;
create policy kroger_export_owner on public.kroger_exports for select to authenticated using (user_id = auth.uid());

-- Compare-and-swap: offline edits must never overwrite a newer draft from another device.
create or replace function public.save_kroger_draft(p_id uuid, p_revision integer, p_draft jsonb)
returns integer language plpgsql security definer set search_path = '' as $$
declare next_revision integer;
begin
  if auth.uid() is null then raise exception 'unauthenticated'; end if;
  if not exists (select 1 from public.meal_plans where id = p_id and user_id = auth.uid() and not is_deleted) then
    raise exception 'plan_not_found';
  end if;
  if pg_column_size(p_draft) > 524288 then raise exception 'draft_too_large'; end if;
  if p_draft is null or jsonb_typeof(p_draft) <> 'object' or (p_draft->>'planId') is distinct from p_id::text then
    raise exception 'invalid_draft';
  end if;
  if p_revision = 0 then
    insert into public.kroger_drafts(id, user_id, draft) values(p_id, auth.uid(), p_draft)
      on conflict(id) do nothing returning revision into next_revision;
  else
    update public.kroger_drafts set draft = p_draft, revision = revision + 1, updated_at = now()
      where id = p_id and user_id = auth.uid() and revision = p_revision
      returning revision into next_revision;
  end if;
  if next_revision is null then raise exception 'draft_conflict'; end if;
  return next_revision;
end $$;
revoke all on function public.save_kroger_draft(uuid, integer, jsonb) from public, anon;
grant execute on function public.save_kroger_draft(uuid, integer, jsonb) to authenticated;

create table if not exists public.kroger_rate_limits (
  user_id uuid primary key references auth.users(id) on delete cascade,
  window_start timestamptz not null default now(),
  requests integer not null default 1
);
alter table public.kroger_rate_limits enable row level security;
revoke all on public.kroger_rate_limits from anon, authenticated;
grant all on public.kroger_rate_limits to service_role;
create or replace function public.claim_kroger_request(p_user uuid) returns boolean
language plpgsql security definer set search_path = '' as $$
declare n integer;
begin
  insert into public.kroger_rate_limits(user_id) values(p_user)
  on conflict(user_id) do update set
    requests = case when kroger_rate_limits.window_start < now() - interval '1 minute' then 1 else kroger_rate_limits.requests + 1 end,
    window_start = case when kroger_rate_limits.window_start < now() - interval '1 minute' then now() else kroger_rate_limits.window_start end
  returning requests into n;
  return n <= 60;
end $$;
revoke all on function public.claim_kroger_request(uuid) from public, anon, authenticated;
grant execute on function public.claim_kroger_request(uuid) to service_role;
