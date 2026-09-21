-- =====================================================================
-- 20260921_120000 · Day notes: per-day input keys + a generation claim row
--  (ai-cost ticket 13 · mp-432 / mp-478)
--
-- Two additions, both about calling the model less often:
--
-- 1. `meal_plans.day_notes_keys` — {date → fingerprint} of the inputs the note for that date was
--    written from (the day's assigned slots, its workouts, its macro target, the plan's status and
--    batch flag, and — for a day with nothing assigned — the whole meal pool). The server compares
--    the stored fingerprint with the one the current plan would produce: the days that match keep
--    their stored note, only the days that differ are written again, and a plan whose days all match
--    calls no model at all. `day_notes_stale` stays as the cheap "look again" flag it already is.
--
-- 2. `vana_day_note_claims` — one row per plan while a generation is running. An edge function keeps
--    nothing between requests and there may be several isolates, so an in-process promise cannot stop
--    two simultaneous requests from each calling Haiku. Whoever inserts the row generates; everyone
--    else waits for the stored notes to appear. The row carries a TTL so an isolate torn down
--    mid-generation cannot block the plan forever.
--
-- Idempotent — safe to re-run.
-- =====================================================================

-- ------------------------------------------------------------ 1. per-day input keys
alter table public.meal_plans
  add column if not exists day_notes_keys jsonb not null default '{}'::jsonb;

comment on column public.meal_plans.day_notes_keys is
  'ai-cost ticket 13: {date → fingerprint} of the inputs each day_notes entry was written from. A date whose fingerprint still matches is never regenerated.';

-- ------------------------------------------------------------ 2. the generation claim row
create table if not exists public.vana_day_note_claims (
  plan_id    uuid primary key references public.meal_plans(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  claimed_at timestamptz not null default now()
);

comment on table public.vana_day_note_claims is
  'ai-cost ticket 13: a plan has at most one day-note generation in flight. Held by whoever wins the insert, released when it finishes, expired by TTL if the isolate died.';

create index if not exists vana_day_note_claims_claimed_at_idx
  on public.vana_day_note_claims (claimed_at);

alter table public.vana_day_note_claims enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'vana_day_note_claims' and policyname = 'vana_day_note_claims_owner') then
    create policy vana_day_note_claims_owner on public.vana_day_note_claims
      for all to authenticated
      using (user_id = auth.uid())
      with check (user_id = auth.uid());
  end if;
end $$;

grant select, insert, update, delete on public.vana_day_note_claims to authenticated, service_role;

-- ------------------------------------------------------------ claim / release
-- True → the caller owns the generation and must release it. False → someone else is generating; wait
-- for their notes rather than calling the model again. `on conflict … where` is the whole lock: a
-- concurrent insert blocks on the primary key, then takes the update branch and finds the claim still
-- fresh, so it returns nothing.
create or replace function public.vana_claim_day_notes(p_plan_id uuid, p_ttl_seconds int default 120)
returns boolean
language plpgsql volatile security invoker set search_path = public as $$
declare
  v_got uuid;
begin
  insert into public.vana_day_note_claims as c (plan_id, user_id, claimed_at)
  values (p_plan_id, auth.uid(), now())
  on conflict (plan_id) do update
     set claimed_at = now(), user_id = auth.uid()
   where c.claimed_at < now() - make_interval(secs => p_ttl_seconds)
  returning c.plan_id into v_got;
  return v_got is not null;
end $$;
revoke all on function public.vana_claim_day_notes(uuid, int) from public;
grant execute on function public.vana_claim_day_notes(uuid, int) to authenticated, service_role;

create or replace function public.vana_release_day_notes(p_plan_id uuid)
returns void
language sql volatile security invoker set search_path = public as $$
  delete from public.vana_day_note_claims where plan_id = p_plan_id;
$$;
revoke all on function public.vana_release_day_notes(uuid) from public;
grant execute on function public.vana_release_day_notes(uuid) to authenticated, service_role;
