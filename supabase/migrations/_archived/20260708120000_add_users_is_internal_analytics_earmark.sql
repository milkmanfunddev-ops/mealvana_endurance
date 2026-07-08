-- users.is_internal — internal-account earmark for analytics exclusion
-- Applied to DEV + PROD on 2026-07-08 via Supabase MCP (verified: 8 rows
-- flagged in prod, 4 in dev). Historical record — do not run directly; the
-- live idempotent copy lives in docs/database/apply_all.sql (Section 5).
--
-- Flags team/test accounts so Mixpanel wiring and engagement queries can
-- exclude them. Seed list = accounts confirmed internal during the 2026-07-08
-- prod engagement audit.

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS is_internal BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN public.users.is_internal IS
  'Internal team/test account. Exclude from analytics (Mixpanel) and engagement metrics.';

UPDATE public.users SET is_internal = true
WHERE id IN (
  '5c25e7b0-c152-449f-a87f-1c77c6133d15', -- Xuan — main (apple auth)
  'f3e1c70e-ba22-454f-bd4a-6a4c0a75c71c', -- Xuan — second account (email auth)
  'd628ceab-7fe7-40ae-8fb3-171c3ab0d44d', -- Xuan — athlete-side account (coach-paired)
  'e92cb452-0368-4bb3-a888-3e86a65d097f', -- test coach "Samwise Gamgee" (test@test.com)
  '9754a410-25e7-4d70-8110-db51b951075f', -- test athlete "samwise g" (teest@test.com)
  '09cd66df-b38e-42c9-a738-1f002f7c1f1e', -- Lee Martin — main
  'd519d63b-954d-43fb-8eb6-713f6196bcc9', -- Lee Martin — second account
  'bed7c42b-9293-4895-a724-2c1d9fb3577d'  -- Ray (ruitian821@gmail.com)
);

-- Candidates NOT yet flagged — anonymous sessions created on team signup days;
-- flag once confirmed internal:
--   'aada1a31-24a5-4ac0-a4d6-88e4c5e57885'  -- anon, created 2025-11-27 (Xuan's signup day)
--   '64dd093b-28d3-4442-bfc7-59679791089d'  -- anon, created 2025-11-29 (test coach's signup day)
