-- Production app_config compatibility-window setup
-- Run this against PROD when preparing release/1.15 compatibility rollout.

BEGIN;

-- Keep existing production values explicit.
UPDATE public.app_config
SET value = '1.14.1'
WHERE key = 'min_app_version';

UPDATE public.app_config
SET value = '3'
WHERE key = 'current_schema_version';

-- Add compatibility window keys if missing.
INSERT INTO public.app_config (key, value, description)
VALUES
  ('latest_schema_version', '3', 'Latest Drift schema version available to clients'),
  ('min_supported_schema_version', '3', 'Minimum Drift schema version still supported by backend')
ON CONFLICT (key) DO NOTHING;

-- Ensure values are aligned to current rollout baseline.
UPDATE public.app_config
SET value = '3'
WHERE key IN ('latest_schema_version', 'min_supported_schema_version');

COMMIT;

-- Verification
SELECT key, value, description, updated_at
FROM public.app_config
WHERE key IN (
  'min_app_version',
  'current_schema_version',
  'latest_schema_version',
  'min_supported_schema_version',
  'maintenance_mode',
  'force_resync_before'
)
ORDER BY key;

-- Later release flip (after 1.15.1 is live in stores):
-- BEGIN;
-- UPDATE public.app_config SET value = '1.15.1' WHERE key = 'min_app_version';
-- UPDATE public.app_config SET value = '4' WHERE key = 'latest_schema_version';
-- -- Keep v3 compatible during review/rollout window:
-- UPDATE public.app_config SET value = '3' WHERE key = 'min_supported_schema_version';
-- -- Optional: keep legacy key aligned
-- UPDATE public.app_config SET value = '4' WHERE key = 'current_schema_version';
-- COMMIT;
