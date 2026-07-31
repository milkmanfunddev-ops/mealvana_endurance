-- ============================================================================
-- Credit RPCs must be service-role only
-- ============================================================================
-- Found 2026-07-28 while enabling AI_CREDITS_ENFORCED on dev.
--
-- grant_credits / debit_credits / ensure_free_credits are SECURITY DEFINER —
-- they have to be, because they write token_wallets and token_ledger, which
-- RLS exposes to the user as read-only. But the deployed EXECUTE grants
-- included `anon` and `authenticated`, so anyone holding the public anon key
-- could call:
--
--     select grant_credits('<their own uuid>', 999999, 'lol', null);
--
-- and mint themselves unlimited AI credits, bypassing payment entirely.
--
-- The original migration (_archived/20260629140000_ai_credit_wallet.sql) did
-- REVOKE ALL ... FROM PUBLIC correctly. Postgres grants EXECUTE to PUBLIC by
-- default on function creation, so any later CREATE OR REPLACE silently
-- reopened it — which is why this needs to be a standing migration rather than
-- a one-off fix.
--
-- Only the edge functions may move credits: purchases via grant_credits from
-- the RevenueCat webhook, usage via debit_credits from the AI functions.
-- Neither path is client-side.
--
-- APPLIED TO DEV 2026-07-28. Apply to prod before AI_CREDITS_ENABLED is
-- flipped on there — until then prod has the feature gated off, but the hole
-- is present in the database regardless of the flag.
--
-- Idempotent: safe to re-run.
-- ============================================================================

revoke all on function public.grant_credits(uuid, int, text, text)
  from public, anon, authenticated;
revoke all on function public.debit_credits(uuid, int, text, text)
  from public, anon, authenticated;
revoke all on function public.ensure_free_credits(uuid, int)
  from public, anon, authenticated;

grant execute on function public.grant_credits(uuid, int, text, text)
  to service_role;
grant execute on function public.debit_credits(uuid, int, text, text)
  to service_role;
grant execute on function public.ensure_free_credits(uuid, int)
  to service_role;
