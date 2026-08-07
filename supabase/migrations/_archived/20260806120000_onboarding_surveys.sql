-- Archived copy of the onboarding_surveys migration authored 2026-08-06.
-- Canonical application path: docs/database/apply_all.sql section 7,
-- applied by hand via DataGrip (dev first; prod at schema-17 release).


-- ── 7. onboarding_surveys — onboarding redesign survey answers ──────────────
-- ⏳ NOT YET APPLIED. Apply to DEV now; apply to PROD only when the schema-17
-- app build ships (bumping app_config.current_schema_version to 17 triggers
-- client delete-and-resync — see docs/features/onboarding-redesign/README.md §3).
--
-- One row per user: sports/goals/pitfalls multi-selects from the new
-- onboarding flow, plus survey_payload jsonb for small flags (tridot_notify,
-- sweat_test_interest, declined_training_apps, connected_provider). Future
-- survey questions extend survey_payload — no new columns.
-- Mirrored locally as Drift v17 onboarding_surveys.

CREATE TABLE IF NOT EXISTS public.onboarding_surveys (
  user_id     uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  sports      jsonb NOT NULL DEFAULT '[]'::jsonb,
  goals       jsonb NOT NULL DEFAULT '[]'::jsonb,
  pitfalls    jsonb NOT NULL DEFAULT '[]'::jsonb,
  survey_payload jsonb,
  completed_at timestamptz NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.onboarding_surveys IS
  'Onboarding survey answers (sports/goals/pitfalls), one row per user. survey_payload holds small flags; extend it instead of adding columns.';

ALTER TABLE public.onboarding_surveys ENABLE ROW LEVEL SECURITY;

-- (select auth.uid()) so the function is evaluated once per query, not per
-- row; user_id is the PK so the policy predicate is index-backed.
DROP POLICY IF EXISTS "Users read own onboarding survey" ON public.onboarding_surveys;
CREATE POLICY "Users read own onboarding survey"
  ON public.onboarding_surveys FOR SELECT
  USING (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users insert own onboarding survey" ON public.onboarding_surveys;
CREATE POLICY "Users insert own onboarding survey"
  ON public.onboarding_surveys FOR INSERT
  WITH CHECK (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users update own onboarding survey" ON public.onboarding_surveys;
CREATE POLICY "Users update own onboarding survey"
  ON public.onboarding_surveys FOR UPDATE
  USING (user_id = (select auth.uid()))
  WITH CHECK (user_id = (select auth.uid()));

-- app_config.current_schema_version → 16: DO NOT run until the schema-17
-- build is released (it force-resyncs every client).
--   UPDATE public.app_config SET value = '16' WHERE key = 'current_schema_version';
-- If a latest_schema_version row exists it takes precedence in
-- VersionCheckService — bump it too:
--   UPDATE public.app_config SET value = '16' WHERE key = 'latest_schema_version';
