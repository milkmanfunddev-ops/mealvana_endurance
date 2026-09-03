-- food-recommendation §10 — the step-resolution funnel's ledger columns
-- (RULED Xuan, 2026-09-03).
--
-- The funnel (steps: 1 personal formula · 2 pinned template · 3 default
-- template · 4 rule/LP/greedy) needs per-phase resolution paths; the ledger
-- previously carried during_path only. Adds:
--   before_path            before-phase resolution (derived from slot pin
--                          decisions + foods: personal_formula /
--                          pinned_template / template / empty)
--   after_path             after-phase generation_path
--                          (personal_formula / template / lp)
--   source                 test-traffic marker — the raw `x-mealvana-test`
--                          request header when present. Funnel queries
--                          exclude non-null rows (precedent: the 2026-09-02
--                          prod burst of 484 synthetic rows).
--   during_segment_paths   brick only: per-segment during paths keyed by
--                          segment order (bench finding B-2 — during_path
--                          alone reads "brick" and hides the cascade).
--
-- Values are enforced in code (generate-nutrition-plan-v3), matching the
-- existing unconstrained during_path. Additive + idempotent — safe on dev
-- and prod at any time (playbook §3). Reference computation:
-- qa/scripts/query-ledger.sh funnel.

alter table public.plan_generation_log
  add column if not exists before_path text,
  add column if not exists after_path text,
  add column if not exists source text,
  add column if not exists during_segment_paths jsonb;

comment on column public.plan_generation_log.before_path is
  'food-recommendation §10: before-phase cascade resolution (personal_formula/pinned_template/template/empty).';
comment on column public.plan_generation_log.after_path is
  'food-recommendation §10: after-phase generation path (personal_formula/template/lp).';
comment on column public.plan_generation_log.source is
  '§10 test-traffic marker: raw x-mealvana-test request header; funnel queries exclude non-null rows.';
comment on column public.plan_generation_log.during_segment_paths is
  'Brick: per-segment during generation paths keyed by segment order (bench B-2).';
