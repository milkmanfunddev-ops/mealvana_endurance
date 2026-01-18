-- Create app_config table for version control and app configuration
-- This table stores key-value pairs for app version control and feature flags

CREATE TABLE IF NOT EXISTS app_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key TEXT NOT NULL UNIQUE,
    value TEXT NOT NULL,
    description TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index on key for faster lookups
CREATE INDEX IF NOT EXISTS idx_app_config_key ON app_config(key);

-- Enable Row Level Security
ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Allow public read access (all users can read config)
CREATE POLICY "Allow public read access to app_config"
    ON app_config
    FOR SELECT
    TO anon, authenticated
    USING (true);

-- RLS Policy: Only service role can insert/update/delete config
CREATE POLICY "Allow service role to manage app_config"
    ON app_config
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- Insert initial configuration values
INSERT INTO app_config (key, value, description) VALUES
    ('min_app_version', '1.12.0', 'Minimum app version allowed to connect to the backend'),
    ('current_schema_version', '3', 'Current Drift database schema version'),
    ('maintenance_mode', 'false', 'When true, blocks all sync operations and shows maintenance screen'),
    ('force_resync_before', '', 'App versions before this version must perform a full resync')
ON CONFLICT (key) DO NOTHING;

-- Add trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_app_config_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER app_config_updated_at
    BEFORE UPDATE ON app_config
    FOR EACH ROW
    EXECUTE FUNCTION update_app_config_updated_at();

-- Add comment to table
COMMENT ON TABLE app_config IS 'Stores application configuration key-value pairs for version control and feature flags';
COMMENT ON COLUMN app_config.key IS 'Unique configuration key (e.g., min_app_version, current_schema_version)';
COMMENT ON COLUMN app_config.value IS 'Configuration value stored as text';
COMMENT ON COLUMN app_config.description IS 'Human-readable description of what this configuration controls';
COMMENT ON COLUMN app_config.updated_at IS 'Timestamp of last update, automatically managed by trigger';
