-- =====================================================================
-- 20260925_100000 · user_entitlements.will_renew
--
-- testing-wave ticket 38 (06-002, mp-457): the server gate
-- (`_shared/vana/entitlement.ts` `isEntitled`) keeps Pro a short grace past
-- `active_until` while the row says the store subscription renews, so a paying
-- account's AI and Kroger calls are not refused between a period end and a
-- late RENEWAL webhook. The revenuecat-webhook writes this column on every
-- `pro` event; nothing app-side writes it (the grants of 20260916110000 stand).
--
-- Additive and idempotent. APPLY BEFORE deploying revenuecat-webhook or any
-- function importing `_shared/vana/entitlement.ts`: both name the column, and
-- the gate fails closed (refuses everyone) when its select errors.
-- Existing rows start not renewing (no grace) until their next event.
-- =====================================================================

alter table public.user_entitlements
  add column if not exists will_renew boolean not null default false;

comment on column public.user_entitlements.will_renew is
  'True when the store subscription that sets active_until renews there (last event INITIAL_PURCHASE, RENEWAL, '
  'UNCANCELLATION or PRODUCT_CHANGE, RevenueCat reporting live pro). The server gate keeps Pro RENEWAL_GRACE_MS past '
  'active_until while true. Written only by the revenuecat-webhook.';
