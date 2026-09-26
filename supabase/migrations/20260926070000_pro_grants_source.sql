-- =====================================================================
-- 20260926_070000 · pro_grants: where each Grant came from
--
-- mp-615 (folded into mp-495, docs/ssot/decisions/paywall.md): the server
-- stores where each Grant of `pro` came from, so the Subscription screen
-- labels it from that and never guesses from its length. RevenueCat's
-- customer info names no source (every server grant reads as product
-- `rc_promo_pro_custom`, and the SDK hands the app no subscriber
-- attributes), so a coach's own 30-day code read as the grace month.
--
-- One row per Grant made, written right after the RevenueCat grant succeeds:
--   source     grace   the Legacy grace month (flip-day run, grace-claim)
--              code    a giveaway code (redeem-code)
--              coach   a coach entering their own coach code (redeem-code)
--   pro_days   days of `pro` granted
--   granted_at when the grant was made (timestamptz, a UTC instant)
--
-- The app reads its own latest row (RLS: select own) when RevenueCat shows a
-- running Grant. No row (a Grant made before this table, or a failed write)
-- falls back to the length guess. Only the service role writes.
--
-- Additive and idempotent: safe to re-run, safe to apply ahead of the
-- function deploys (playbook §3). APPLY BEFORE deploying grace-claim and
-- redeem-code; they write here (a failed write is logged, never refused).
-- No `app_config` change: nothing in Drift.
-- =====================================================================

create table if not exists public.pro_grants (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  source text not null,
  pro_days integer not null,
  granted_at timestamptz not null default now(),
  constraint pro_grants_source_check check (source in ('grace', 'code', 'coach')),
  constraint pro_grants_pro_days_check check (pro_days > 0)
);

comment on table public.pro_grants is
  'One row per Grant of pro (mp-615): where it came from (grace | code | coach). Written only by the service role '
  '(grace-claim, redeem-code, scripts/grace-grant.mjs); each account reads its own rows.';

create index if not exists idx_pro_grants_user_granted_at
  on public.pro_grants (user_id, granted_at desc);

alter table public.pro_grants enable row level security;

revoke all on table public.pro_grants from anon, authenticated;
grant select on table public.pro_grants to authenticated;

drop policy if exists pro_grants_select_own on public.pro_grants;
create policy pro_grants_select_own on public.pro_grants
  for select to authenticated
  using (user_id = auth.uid());
