-- Macro-dashboard bundle (daily-macros-dashboard@v1), schema task 2:
-- the recalculateAfterSync calibration ledger, DDL as ruled in
-- docs/ssot/spec/daily-macros/platform-resolution.md (Garmin-first affirmed
-- with mandatory calibration logging, Xuan 2026-08-13). One row per
-- recalculateAfterSync run, plan_generation_log pattern: append-only, RLS
-- enabled with no policies, service-role writes only.
--
-- The evaluation question this ledger exists to answer (recorded with the
-- ruling): what is the distribution of garmin_kcal − formula_kcal by sport
-- and duration, and does the resulting fat/TDEE swing warrant a correction?
-- sessions[].formula_kcal is computed with the SAME resolved IF/duration as
-- the Garmin comparison — like-for-like, or the calibration is noise.

create table if not exists public.plan_recalc_log (
  id           uuid primary key default gen_random_uuid(),
  created_at   timestamptz not null default now(),
  device_id    text,
  local_sync_time time,       -- time-of-day the recalc landed (ruling 5's question)
  sessions     jsonb,         -- [{sport, duration_hr, resolved_if,
                              --   formula_kcal, garmin_kcal, kcal_source}]
  delta        jsonb,         -- the F27 delta object, verbatim
  ea_status_before text,
  ea_status_after  text
);

-- RLS on with no policies: anon/authenticated cannot read or write; the
-- service-role client used by edge functions bypasses RLS.
alter table public.plan_recalc_log enable row level security;

create index if not exists plan_recalc_log_created_at_idx
  on public.plan_recalc_log (created_at desc);
create index if not exists plan_recalc_log_device_id_idx
  on public.plan_recalc_log (device_id);
