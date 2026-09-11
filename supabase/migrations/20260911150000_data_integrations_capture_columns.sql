-- data-integrations@v1 Stage A — additive capture columns (Q-INT26,
-- RATIFIED Xuan 2026-09-10; per-source typed convention 2026-09-09).
--
-- Every captured quantity that can arrive from more than one source gets its
-- own per-source typed column; precedence is applied only at read time, so
-- priority can be re-ruled without re-ingesting. All columns are nullable and
-- null-tolerant (DI-13): a provider omitting a field never errors and never
-- fabricates — for basic (non-premium) TP athletes every one of the TP
-- fields below arrives null, and null != 0.
--
-- activities:
--   tss_planned / if_planned     TP TSSPlanned / IFPlanned (planned load) —
--                                previously computed then DISCARDED (Q-INT13)
--   tss_actual / if_actual       TP TssActual / IF (completed load) — the
--                                engine's dead TP_ACTUAL ladder rungs' feed
--   tp_calories(_planned)        TP session energy, RECORD-ONLY: lands beside
--                                Garmin's calories_burned, never into it (F4
--                                stays authoritative; promotion to a measured
--                                rung is a separate F22 ruling)
--   parent_summary_id/is_parent  Garmin multisport lineage (Q-INT23) —
--                                parsed since forever, never persisted;
--                                unblocks brick verification B-2/B-5
-- integrations:
--   provider_is_premium          TP IsPremium — predicts null completed
--                                fields and write-back 403s
--   athlete_metrics_json         latest TP /v2/metrics fetch (weight, HRV,
--                                steps, stress, sleep quality) on the 24 h
--                                zones staleness clock, premium-gated
--
-- The existing never-written activities.tss column retires with the Q-INT25
-- hygiene batch (separate migration, after these land).

ALTER TABLE public.activities
  ADD COLUMN IF NOT EXISTS tss_planned real,
  ADD COLUMN IF NOT EXISTS tss_actual real,
  ADD COLUMN IF NOT EXISTS if_planned real,
  ADD COLUMN IF NOT EXISTS if_actual real,
  ADD COLUMN IF NOT EXISTS tp_calories real,
  ADD COLUMN IF NOT EXISTS tp_calories_planned real,
  ADD COLUMN IF NOT EXISTS parent_summary_id text,
  ADD COLUMN IF NOT EXISTS is_parent boolean;

ALTER TABLE public.integrations
  ADD COLUMN IF NOT EXISTS provider_is_premium boolean,
  ADD COLUMN IF NOT EXISTS athlete_metrics_json jsonb;

COMMENT ON COLUMN public.activities.tss_planned IS
  'TP TSSPlanned (data-integrations@v1 capture; null for basic TP athletes)';
COMMENT ON COLUMN public.activities.tss_actual IS
  'TP TssActual on completion (data-integrations@v1 capture)';
COMMENT ON COLUMN public.activities.if_planned IS
  'TP IFPlanned (data-integrations@v1 capture)';
COMMENT ON COLUMN public.activities.if_actual IS
  'TP IF on completion (data-integrations@v1 capture)';
COMMENT ON COLUMN public.activities.tp_calories IS
  'TP Calories on completion — record-only; calories_burned (Garmin) stays the measured-kcal rung';
COMMENT ON COLUMN public.activities.tp_calories_planned IS
  'TP CaloriesPlanned — record-only planned-day energy cross-check against F4';
COMMENT ON COLUMN public.activities.parent_summary_id IS
  'Garmin multisport: parent session summary id this child leg belongs to (Q-INT23)';
COMMENT ON COLUMN public.activities.is_parent IS
  'Garmin multisport: true on the parent (MULTI_SPORT) session row (Q-INT23)';
COMMENT ON COLUMN public.integrations.provider_is_premium IS
  'TP IsPremium at last profile fetch — predicts null completed-workout fields and write-back 403s';
COMMENT ON COLUMN public.integrations.athlete_metrics_json IS
  'Latest TP /v2/metrics body-metrics fetch ({fetchedAt, metrics[]}); premium-gated, 24 h staleness';
