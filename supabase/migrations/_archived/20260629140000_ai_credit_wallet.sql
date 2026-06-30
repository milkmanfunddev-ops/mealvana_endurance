-- 20260629140000_ai_credit_wallet.sql
-- AI credit wallet — per-user balance of app-defined "AI credits".
--   • token_wallets : materialized balance (fast checks, never negative)
--   • token_ledger  : append-only audit of every grant/debit
--   • RPCs grant_credits / debit_credits / ensure_free_credits (SECURITY DEFINER,
--     service-role-only) — the ONLY way balances change.
-- Purchases (RevenueCat webhook) call grant_credits; AI edge functions call
-- debit_credits; monthly free top-up is lazy via ensure_free_credits.
-- Applied to DEV + PROD via Supabase CLI.

-- ── Tables ───────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.token_wallets (
  user_id      UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  balance      INT NOT NULL DEFAULT 0 CHECK (balance >= 0),
  free_period  TEXT,                       -- 'YYYY-MM' of last monthly free grant
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.token_ledger (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  delta         INT NOT NULL,              -- +grant / -debit
  reason        TEXT NOT NULL,             -- grant_free | grant_purchase | grant_admin | debit_usage | refund
  ref           TEXT,                      -- rc event id, function name, period, etc.
  balance_after INT NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS token_ledger_user_created
  ON public.token_ledger (user_id, created_at DESC);
-- Idempotency for purchase grants: one row per RevenueCat event id.
CREATE UNIQUE INDEX IF NOT EXISTS token_ledger_purchase_ref_uniq
  ON public.token_ledger (ref) WHERE reason = 'grant_purchase' AND ref IS NOT NULL;

-- ── RLS: users read their own wallet + ledger; all writes go through the
-- SECURITY DEFINER RPCs (or service role). No INSERT/UPDATE policies. ─────────
ALTER TABLE public.token_wallets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users read own wallet" ON public.token_wallets;
CREATE POLICY "Users read own wallet"
  ON public.token_wallets FOR SELECT USING (user_id = auth.uid());

ALTER TABLE public.token_ledger ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users read own ledger" ON public.token_ledger;
CREATE POLICY "Users read own ledger"
  ON public.token_ledger FOR SELECT USING (user_id = auth.uid());

-- ── RPCs ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.grant_credits(
  p_user_id uuid, p_amount int, p_reason text, p_ref text DEFAULT NULL
) RETURNS int
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_balance int;
BEGIN
  IF p_amount <= 0 THEN RAISE EXCEPTION 'grant amount must be positive'; END IF;
  INSERT INTO public.token_wallets (user_id, balance) VALUES (p_user_id, 0)
    ON CONFLICT (user_id) DO NOTHING;
  UPDATE public.token_wallets
    SET balance = balance + p_amount, updated_at = now()
    WHERE user_id = p_user_id
    RETURNING balance INTO v_balance;
  INSERT INTO public.token_ledger (user_id, delta, reason, ref, balance_after)
    VALUES (p_user_id, p_amount, p_reason, p_ref, v_balance);
  RETURN v_balance;
END; $$;

CREATE OR REPLACE FUNCTION public.debit_credits(
  p_user_id uuid, p_amount int, p_reason text, p_ref text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_balance int;
BEGIN
  IF p_amount <= 0 THEN RAISE EXCEPTION 'debit amount must be positive'; END IF;
  SELECT balance INTO v_balance FROM public.token_wallets
    WHERE user_id = p_user_id FOR UPDATE;
  IF v_balance IS NULL THEN
    RETURN jsonb_build_object('success', false, 'balance', 0);
  END IF;
  IF v_balance < p_amount THEN
    RETURN jsonb_build_object('success', false, 'balance', v_balance);
  END IF;
  UPDATE public.token_wallets SET balance = balance - p_amount, updated_at = now()
    WHERE user_id = p_user_id RETURNING balance INTO v_balance;
  INSERT INTO public.token_ledger (user_id, delta, reason, ref, balance_after)
    VALUES (p_user_id, -p_amount, p_reason, p_ref, v_balance);
  RETURN jsonb_build_object('success', true, 'balance', v_balance);
END; $$;

-- Lazy monthly free top-up: grants p_amount once per calendar month per user.
-- Additive (purchased credits are never touched). Returns current balance.
CREATE OR REPLACE FUNCTION public.ensure_free_credits(
  p_user_id uuid, p_amount int
) RETURNS int
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_period text := to_char(now(), 'YYYY-MM'); v_balance int; v_last text;
BEGIN
  INSERT INTO public.token_wallets (user_id, balance) VALUES (p_user_id, 0)
    ON CONFLICT (user_id) DO NOTHING;
  SELECT free_period, balance INTO v_last, v_balance FROM public.token_wallets
    WHERE user_id = p_user_id FOR UPDATE;
  IF p_amount > 0 AND v_last IS DISTINCT FROM v_period THEN
    UPDATE public.token_wallets
      SET balance = balance + p_amount, free_period = v_period, updated_at = now()
      WHERE user_id = p_user_id RETURNING balance INTO v_balance;
    INSERT INTO public.token_ledger (user_id, delta, reason, ref, balance_after)
      VALUES (p_user_id, p_amount, 'grant_free', v_period, v_balance);
  END IF;
  RETURN v_balance;
END; $$;

-- Lock down: balance-mutating RPCs are service-role only (edge functions).
REVOKE ALL ON FUNCTION public.grant_credits(uuid,int,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.debit_credits(uuid,int,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.ensure_free_credits(uuid,int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.grant_credits(uuid,int,text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.debit_credits(uuid,int,text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.ensure_free_credits(uuid,int) TO service_role;
