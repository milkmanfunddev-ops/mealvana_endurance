-- =====================================================================
-- 20260916_110000 · user_entitlements becomes a two-field cache of RevenueCat
--
-- mp-285: the table stays, shrunk to the two fields the gate reads —
-- `active_until` and `period_type` — plus `event_at`, the RevenueCat event
-- time that lets the webhook ignore an event older than the row. Written only
-- by the revenuecat-webhook edge function (service_role). Nothing app-side
-- can insert into or update it (no policies for authenticated/anon; the
-- grants below re-assert it). The `has_entitlement()` function goes: the
-- server reads the two fields directly (`_shared/vana/entitlement.ts`) and
-- the `users.is_internal` bypass it carried is no longer a gate.
--
-- Idempotent: safe to re-run. Dev had 0 rows on 2026-09-15; the backfill is
-- for prod, where rows written by the old webhook may exist at cutover.
-- =====================================================================

alter table public.user_entitlements
  add column if not exists active_until timestamptz,
  add column if not exists event_at     timestamptz;

-- Backfill from the old shape when it is still there (no-op once dropped).
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'user_entitlements' and column_name = 'expires_at'
  ) then
    execute $sql$
      update public.user_entitlements
         set active_until = coalesce(active_until,
                                     case when active then expires_at else least(expires_at, updated_at) end),
             event_at     = coalesce(event_at, updated_at)
       where active_until is null or event_at is null
    $sql$;
  end if;
end $$;

update public.user_entitlements set event_at = now() where event_at is null;
alter table public.user_entitlements alter column event_at set default now();
alter table public.user_entitlements alter column event_at set not null;

-- One row per user: the entitlement key column goes with the rest.
drop index if exists public.user_entitlements_active_idx;
alter table public.user_entitlements
  drop column if exists entitlement,
  drop column if exists active,
  drop column if exists product_id,
  drop column if exists store,
  drop column if exists expires_at,
  drop column if exists unsubscribe_detected_at,
  drop column if exists billing_issue_detected_at,
  drop column if exists source,
  drop column if exists updated_at;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.user_entitlements'::regclass and contype = 'p'
  ) then
    alter table public.user_entitlements add primary key (user_id);
  end if;
end $$;

comment on table public.user_entitlements is
  'Two-field cache of RevenueCat per user (mp-285): active_until and period_type, written only by the '
  'revenuecat-webhook edge function. The server gate reads active_until > now(); nothing app-side writes here.';
comment on column public.user_entitlements.active_until is
  'End of the period RevenueCat last reported (expiration_at_ms). Null = no access.';
comment on column public.user_entitlements.period_type is
  'RevenueCat period type: NORMAL | TRIAL | INTRO | PROMOTIONAL.';
comment on column public.user_entitlements.event_at is
  'RevenueCat event_timestamp_ms of the event that wrote the row; an older event is ignored.';

-- ── Access: owner select only; writes service_role only ──────────────────
alter table public.user_entitlements enable row level security;

drop policy if exists "user_entitlements_owner_select" on public.user_entitlements;
create policy "user_entitlements_owner_select"
  on public.user_entitlements for select
  to authenticated
  using (user_id = auth.uid());

revoke all on public.user_entitlements from anon, authenticated, public;
grant select on public.user_entitlements to authenticated;
grant all on public.user_entitlements to service_role;

-- ── The RPC gate is gone; the server reads the row ───────────────────────
drop function if exists public.has_entitlement(uuid, text);
