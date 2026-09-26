-- =====================================================================
-- 20260926_163400 · vana_action_requests: a repeated Vana write runs once
--  (testing-wave 134 · IMPROVEMENTS #82, Lee 2026-09-26)
--
-- The phone's 20 s transport timeout reports "needs a connection" while the edge function keeps
-- running, so a slow pick_meals / log_from_plan / save_meal could land after the screen said it
-- failed, and a second tap wrote it twice. The phone now sends one `requestId` per user action
-- (reused by that action's retry); vana-action claims it here before running, stores the result,
-- and answers a repeat from the stored result without writing. A repeat that arrives while the
-- first is still running is refused (409 in_progress). A run that fails releases its claim.
--
-- The row is the lock: `insert … on conflict do update … where <stale>` returns a row only to the
-- caller who inserted it or took over a `running` claim older than the TTL (an isolate torn down
-- mid-write), exactly like vana_day_note_claims (20260921_120000). Rows older than 7 days are
-- swept by the caller's own next claim, so the table stays small without a cron job.
--
-- security invoker: auth.uid() is the caller; the edge function calls these on the user's client.
-- Idempotent — safe to re-run. Apply to dev now; prod follows the cutover runbook. The function
-- deploy may go first: without these RPCs vana-action runs the write unguarded (fail open).
-- =====================================================================

create table if not exists public.vana_action_requests (
  user_id      uuid not null references auth.users(id) on delete cascade,
  request_id   text not null check (char_length(request_id) between 1 and 64),
  action_type  text not null,
  status       text not null default 'running' check (status in ('running', 'done')),
  result       jsonb,
  claimed_at   timestamptz not null default now(),
  finished_at  timestamptz,
  primary key (user_id, request_id)
);

comment on table public.vana_action_requests is
  'testing-wave 134 (#82): one row per idempotent vana-action write (pick_meals, log_from_plan, save_meal) keyed by the phone''s requestId. running = claimed, done = result stored; a repeat answers `result` and writes nothing.';

create index if not exists vana_action_requests_claimed_at_idx
  on public.vana_action_requests (claimed_at);

alter table public.vana_action_requests enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'vana_action_requests' and policyname = 'vana_action_requests_owner') then
    create policy vana_action_requests_owner on public.vana_action_requests
      for all to authenticated
      using (user_id = auth.uid())
      with check (user_id = auth.uid());
  end if;
end $$;

grant select, insert, update, delete on public.vana_action_requests to authenticated, service_role;

-- ------------------------------------------------------------ claim / finish / release
-- {claimed: true} → the caller owns this request and must run the action, then finish (or release on failure).
-- {claimed: false, status, action_type, result} → someone already did: `done` carries the stored result to answer
-- with; `running` means the first run is still on the server.
create or replace function public.vana_claim_action_request(p_request_id text, p_action_type text, p_ttl_seconds int default 120)
returns jsonb
language plpgsql volatile security invoker set search_path = public as $$
declare
  v_row public.vana_action_requests;
begin
  -- Housekeeping on the way in: this user's rows nobody will repeat any more.
  delete from public.vana_action_requests
   where user_id = auth.uid() and claimed_at < now() - interval '7 days';

  insert into public.vana_action_requests as r (user_id, request_id, action_type, status, result, claimed_at, finished_at)
  values (auth.uid(), p_request_id, p_action_type, 'running', null, now(), null)
  on conflict (user_id, request_id) do update
     set status = 'running', result = null, claimed_at = now(), finished_at = null, action_type = excluded.action_type
   where r.status = 'running' and r.claimed_at < now() - make_interval(secs => p_ttl_seconds)
  returning * into v_row;
  if found then
    return jsonb_build_object('claimed', true);
  end if;

  select * into v_row from public.vana_action_requests
   where user_id = auth.uid() and request_id = p_request_id;
  return jsonb_build_object('claimed', false, 'status', v_row.status, 'action_type', v_row.action_type, 'result', v_row.result);
end $$;
revoke all on function public.vana_claim_action_request(text, text, int) from public;
grant execute on function public.vana_claim_action_request(text, text, int) to authenticated, service_role;

create or replace function public.vana_finish_action_request(p_request_id text, p_result jsonb)
returns void
language sql volatile security invoker set search_path = public as $$
  update public.vana_action_requests
     set status = 'done', result = p_result, finished_at = now()
   where user_id = auth.uid() and request_id = p_request_id;
$$;
revoke all on function public.vana_finish_action_request(text, jsonb) from public;
grant execute on function public.vana_finish_action_request(text, jsonb) to authenticated, service_role;

create or replace function public.vana_release_action_request(p_request_id text)
returns void
language sql volatile security invoker set search_path = public as $$
  delete from public.vana_action_requests
   where user_id = auth.uid() and request_id = p_request_id and status = 'running';
$$;
revoke all on function public.vana_release_action_request(text) from public;
grant execute on function public.vana_release_action_request(text) to authenticated, service_role;
