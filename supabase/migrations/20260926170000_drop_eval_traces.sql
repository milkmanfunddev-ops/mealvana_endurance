-- Drop eval_traces (created 20260923140000): the old Vana evals system's durable trace store.
-- Dev-only table — the migration that created it was never applied to prod. The judging system
-- (eval/) does not read it: round transcripts are captured from vana_conversations / vana_messages
-- (eval/tools/capture-transcript.mjs). RLS was enabled with no policies and both indexes were
-- table-owned, so the drop takes them with it. Idempotent.

drop table if exists public.eval_traces;
