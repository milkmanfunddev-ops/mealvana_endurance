-- Add schema compatibility window keys to app_config.
-- This supports phased rollouts where older schema versions remain temporarily valid.

-- Latest schema available to clients.
INSERT INTO app_config (key, value, description)
SELECT
    'latest_schema_version',
    value,
    'Latest Drift schema version available to clients'
FROM app_config
WHERE key = 'current_schema_version'
ON CONFLICT (key) DO NOTHING;

-- Oldest schema still supported without forcing an app upgrade.
INSERT INTO app_config (key, value, description)
SELECT
    'min_supported_schema_version',
    value,
    'Minimum Drift schema version still supported by backend'
FROM app_config
WHERE key = 'current_schema_version'
ON CONFLICT (key) DO NOTHING;
