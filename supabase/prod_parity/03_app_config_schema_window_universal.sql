-- Universal app_config compatibility-window setup
-- Safe to run in BOTH dev and prod.
-- Idempotent: can be re-run without changing existing rollout values.

BEGIN;

-- Guard: app_config must exist.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name = 'app_config'
  ) THEN
    RAISE EXCEPTION 'public.app_config does not exist. Run 20260118_create_app_config_table.sql first.';
  END IF;
END $$;

-- Ensure latest_schema_version exists.
-- Value priority:
--   1) existing latest_schema_version
--   2) current_schema_version
--   3) fallback '3'
INSERT INTO public.app_config (key, value, description)
SELECT
  'latest_schema_version',
  COALESCE(
    (SELECT value FROM public.app_config WHERE key = 'latest_schema_version' LIMIT 1),
    (SELECT value FROM public.app_config WHERE key = 'current_schema_version' LIMIT 1),
    '3'
  ),
  'Latest Drift schema version available to clients'
WHERE NOT EXISTS (
  SELECT 1 FROM public.app_config WHERE key = 'latest_schema_version'
);

-- Ensure min_supported_schema_version exists.
-- Value priority:
--   1) existing min_supported_schema_version
--   2) legacy min_supported_schema
--   3) current_schema_version
--   4) fallback '3'
INSERT INTO public.app_config (key, value, description)
SELECT
  'min_supported_schema_version',
  COALESCE(
    (SELECT value FROM public.app_config WHERE key = 'min_supported_schema_version' LIMIT 1),
    (SELECT value FROM public.app_config WHERE key = 'min_supported_schema' LIMIT 1),
    (SELECT value FROM public.app_config WHERE key = 'current_schema_version' LIMIT 1),
    '3'
  ),
  'Minimum Drift schema version still supported by backend'
WHERE NOT EXISTS (
  SELECT 1 FROM public.app_config WHERE key = 'min_supported_schema_version'
);

-- Keep descriptions current if keys already existed.
UPDATE public.app_config
SET description = 'Latest Drift schema version available to clients'
WHERE key = 'latest_schema_version'
  AND COALESCE(description, '') <> 'Latest Drift schema version available to clients';

UPDATE public.app_config
SET description = 'Minimum Drift schema version still supported by backend'
WHERE key = 'min_supported_schema_version'
  AND COALESCE(description, '') <> 'Minimum Drift schema version still supported by backend';

-- Validate numeric values and ordering (min_supported <= latest).
DO $$
DECLARE
  latest_schema_int INTEGER;
  min_supported_schema_int INTEGER;
BEGIN
  SELECT value::INTEGER
  INTO latest_schema_int
  FROM public.app_config
  WHERE key = 'latest_schema_version';

  SELECT value::INTEGER
  INTO min_supported_schema_int
  FROM public.app_config
  WHERE key = 'min_supported_schema_version';

  IF min_supported_schema_int > latest_schema_int THEN
    RAISE EXCEPTION
      'Invalid app_config: min_supported_schema_version (%) cannot be greater than latest_schema_version (%)',
      min_supported_schema_int,
      latest_schema_int;
  END IF;
END $$;

COMMIT;

-- Verification output
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
