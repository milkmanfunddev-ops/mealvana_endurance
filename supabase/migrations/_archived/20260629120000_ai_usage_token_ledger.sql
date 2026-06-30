-- 20260629120000_ai_usage_token_ledger.sql
-- Per-user AI token ledger. Canonical, prod-safe record of every AI model
-- invocation across all four AI edge functions (jade-chat, describe-meal,
-- analyze-meal-photo, ai-coach). Service-role-written; users read own rows only.
-- "Track now, throttle later" — a future per-user throttle queries this table.
-- Applied to DEV + PROD via DataGrip (docs/database/apply_all.sql §5).

CREATE TABLE IF NOT EXISTS public.ai_usage (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  function_name  TEXT NOT NULL,   -- 'jade-chat' | 'describe-meal' | 'analyze-meal-photo' | 'ai-coach'
  model          TEXT NOT NULL,   -- provider/model string actually used
  input_tokens   INT NOT NULL DEFAULT 0,
  output_tokens  INT NOT NULL DEFAULT 0,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ai_usage_user_created
  ON public.ai_usage (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS ai_usage_created
  ON public.ai_usage (created_at DESC);

ALTER TABLE public.ai_usage ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users read own ai usage" ON public.ai_usage;
CREATE POLICY "Users read own ai usage"
  ON public.ai_usage FOR SELECT
  USING (user_id = auth.uid());
