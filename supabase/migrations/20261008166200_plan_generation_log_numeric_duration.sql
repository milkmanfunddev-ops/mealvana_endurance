-- plan_generation_log.duration_minutes: integer -> numeric
-- (testing-wave develop-2026-10 ticket 62, Finding 49-012; Lee 2026-10-08).
--
-- At 17:40Z on 2026-10-08 generate-nutrition-plan-v3 lost two ledger rows to
-- 22P02 "invalid input syntax for type integer" ("18.64", "117.9"). The
-- source was test/e2e/dev_cloud_e2e_test.dart: its strict-macro tests send
-- macros-v4's `duration_min` as `duration_minutes`, and that is fractional
-- for a distance/pace run. The app sends whole minutes, but a fraction is
-- valid input and the ledger records inputs as they arrived, so the column
-- widens rather than the function rounding.
--
-- duration_minutes is the table's only integer column; everything else the
-- row carries is text, uuid or jsonb.
--
-- Widening only (integer -> numeric): existing rows and the funnel query
-- (qa/scripts/query-ledger.sh) read the same. Re-running on a numeric column
-- is a no-op in effect. Additive, so safe on dev and prod at any time
-- (playbook §3).

alter table public.plan_generation_log
  alter column duration_minutes type numeric using duration_minutes::numeric;

comment on column public.plan_generation_log.duration_minutes is
  'minutes as sent by the caller; fractional allowed (e2e sends macros-v4 duration_min)';
