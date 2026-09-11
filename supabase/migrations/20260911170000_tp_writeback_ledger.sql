-- TP write-back ledger (data-integrations@v1 Stage D — TP-5/Q-INT16 as
-- amended 2026-09-11: sharing defaults ON for everyone, and NO push happens
-- without a ledger row). One row PER PUSH ATTEMPT with its outcome — unlike
-- the client's Drift tp_writeback_log, which keeps only the latest state per
-- workout. The ledger is the server-side audit trail the settings surface
-- reads ("last pushed ..."), and disconnect purges it.

CREATE TABLE IF NOT EXISTS public.tp_writeback_ledger (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  activity_id text,
  tp_workout_id text NOT NULL,
  plan_hash text,
  block_kind text NOT NULL DEFAULT 'plan',
  status text NOT NULL DEFAULT 'attempt',
  error text,
  pushed_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT tp_writeback_ledger_status_check
    CHECK (status IN ('attempt', 'success', 'failure')),
  CONSTRAINT tp_writeback_ledger_block_kind_check
    CHECK (block_kind IN ('plan', 'feedback'))
);

CREATE INDEX IF NOT EXISTS idx_tp_writeback_ledger_user_pushed
  ON public.tp_writeback_ledger (user_id, pushed_at DESC);

COMMENT ON TABLE public.tp_writeback_ledger IS
  'Per-push audit trail for TP write-back (TP-5/Q-INT16): a push may not happen without its attempt row; disconnect purges the user''s rows';
