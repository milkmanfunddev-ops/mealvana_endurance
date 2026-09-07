-- =====================================================================
-- 20260902_080000 · user_entitlements — the server-side Pro paywall
--
-- One row per (user, entitlement). Written ONLY by the revenuecat-webhook
-- edge function (service_role) from RevenueCat subscription events; the app
-- reads its own row (owner-select RLS) and mirrors it into Drift as a cache.
-- Edge functions gate Pro features with `has_entitlement(uid, 'pro')` — the
-- client-side flag is UX, this row is the paywall
-- (docs/implement_mealplanning/04-entitlement.md).
--
-- `users.is_internal` is the server-side counterpart of the app's 7-tap
-- tester switch: `has_entitlement` returns true for internal users so QA can
-- exercise Pro surfaces on prod without a real subscription. Idempotent.
-- =====================================================================

create table if not exists public.user_entitlements (
  user_id                   uuid        not null references public.users(id) on delete cascade,
  entitlement               text        not null,                    -- 'pro'
  active                    boolean     not null default false,
  product_id                text,                                    -- store SKU that granted it
  store                     text,                                    -- APP_STORE | PLAY_STORE | RC_BILLING | PROMOTIONAL | …
  period_type               text,                                    -- NORMAL | TRIAL | INTRO | PROMOTIONAL
  expires_at                timestamptz,
  unsubscribe_detected_at   timestamptz,
  billing_issue_detected_at timestamptz,
  source                    text        not null default 'revenuecat', -- revenuecat | promo | internal
  updated_at                timestamptz not null default now(),
  primary key (user_id, entitlement)
);

comment on table public.user_entitlements is
  'Subscription entitlements per user, written by the revenuecat-webhook edge function. '
  'Server-side source of truth for Pro gating; the app caches its own row in Drift.';
comment on column public.user_entitlements.active is
  'Whether the entitlement is currently active per the last RevenueCat event. '
  'Combine with expires_at — use has_entitlement() rather than reading this directly.';

create index if not exists user_entitlements_active_idx
  on public.user_entitlements (entitlement) where active;

-- ── RLS: owner select, writes service_role only ──────────────────────────
alter table public.user_entitlements enable row level security;

drop policy if exists "user_entitlements_owner_select" on public.user_entitlements;
create policy "user_entitlements_owner_select"
  on public.user_entitlements for select
  to authenticated
  using (user_id = auth.uid());

-- No insert/update/delete policies for authenticated: service_role bypasses
-- RLS, so the webhook (and admin SQL) are the only writers.
revoke insert, update, delete on public.user_entitlements from authenticated, anon;
grant select on public.user_entitlements to authenticated;
grant all on public.user_entitlements to service_role;

-- ── Server-side tester bypass ─────────────────────────────────────────────
alter table public.users add column if not exists is_internal boolean not null default false;
comment on column public.users.is_internal is
  'Team / QA account. has_entitlement() returns true for internal users so Pro surfaces can be tested without a subscription.';

-- ── has_entitlement(user, key) ────────────────────────────────────────────
-- SECURITY DEFINER so edge functions calling with the user JWT (and RLS on)
-- still resolve the row; STABLE so it can be inlined in a statement.
create or replace function public.has_entitlement(p_user uuid, p_key text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select true
      from public.user_entitlements e
      where e.user_id = p_user
        and e.entitlement = p_key
        and e.active
        and (e.expires_at is null or e.expires_at > now())
      limit 1
    ),
    (
      select u.is_internal
      from public.users u
      where u.id = p_user
    ),
    false
  );
$$;

revoke all on function public.has_entitlement(uuid, text) from public;
grant execute on function public.has_entitlement(uuid, text) to authenticated, service_role;
