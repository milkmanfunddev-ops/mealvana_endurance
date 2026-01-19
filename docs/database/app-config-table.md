# App Config Table Documentation

## Overview

The `app_config` table is a **server-controlled configuration system** that enables version management, feature flags, and maintenance mode without requiring app updates.

**Key Benefits:**
- Server controls when schema migrations happen
- Simplified migration strategy (delete and resync instead of complex Drift migrations)
- Centralized version management
- Dynamic feature flags and maintenance mode
- No app deployment required for config changes

## Table Schema

```sql
CREATE TABLE IF NOT EXISTS app_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key TEXT NOT NULL UNIQUE,
    value TEXT NOT NULL,
    description TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for faster lookups
CREATE INDEX IF NOT EXISTS idx_app_config_key ON app_config(key);

-- Row Level Security
ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;

-- Public read access
CREATE POLICY "Allow public read access to app_config"
    ON app_config
    FOR SELECT
    TO anon, authenticated
    USING (true);

-- Service role write access only
CREATE POLICY "Allow service role to manage app_config"
    ON app_config
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);
```

## Configuration Keys

### Version Control Keys

| Key | Type | Purpose | Example Value |
|-----|------|---------|---------------|
| `min_app_version` | Semver String | Minimum app version allowed to connect to backend | `"1.12.0"` |
| `current_schema_version` | Integer String | Current Drift database schema version expected by server | `"3"` |
| `force_resync_before` | Semver String | App versions below this must perform full database resync | `""` (empty = no forced resync) |
| `maintenance_mode` | Boolean String | When true, blocks all sync operations and shows maintenance screen | `"false"` |

### Future Keys (Planned)

| Key | Type | Purpose | Example Value |
|-----|------|---------|---------------|
| `feature_flag_carb_loading` | Boolean String | Enable/disable carb loading feature | `"true"` |
| `feature_flag_coach_mode` | Boolean String | Enable/disable coach mode | `"true"` |
| `max_sync_retries` | Integer String | Maximum number of sync retry attempts | `"3"` |
| `sync_timeout_ms` | Integer String | Timeout for sync operations in milliseconds | `"30000"` |

## Usage Patterns

### Version Checking (Client-Side)

The app checks version compatibility on startup:

```dart
// Example: Version check service
Future<VersionCheckResult> checkVersion() async {
  final response = await supabase.functions.invoke('check-version', body: {
    'app_version': packageInfo.version,
    'schema_version': AppDatabase.schemaVersion,
    'has_dirty_records': await hasDirtyRecords(),
  });

  // Server responds with: ok, resync, upload_first, or update_app
  return VersionCheckResult.fromJson(response.data);
}
```

### Configuration Management (Server-Side)

Update configuration via Supabase SQL Editor or backend scripts:

```sql
-- Trigger schema migration for all clients
UPDATE app_config
SET value = '4', updated_at = NOW()
WHERE key = 'current_schema_version';

-- Force app update for breaking changes
UPDATE app_config
SET value = '2.0.0', updated_at = NOW()
WHERE key = 'min_app_version';

-- Enable maintenance mode
UPDATE app_config
SET value = 'true', updated_at = NOW()
WHERE key = 'maintenance_mode';

-- Force resync for old app versions
UPDATE app_config
SET value = '1.11.0', updated_at = NOW()
WHERE key = 'force_resync_before';
```

## Schema Version Migration Flow

### Normal Operation (Versions Match)

```
App Startup
    ↓
Query app_config.current_schema_version → "3"
Compare with local Drift schemaVersion → 3
    ↓
Match! Continue normal operation
```

### Schema Mismatch (Migration Required)

```
App Startup
    ↓
Query app_config.current_schema_version → "4"
Compare with local Drift schemaVersion → 3
    ↓
Mismatch detected!
    ↓
1. Upload dirty records (backup user changes)
    ↓
2. Delete local SQLite database
    ↓
3. Recreate fresh database (Drift onCreate runs)
    ↓
4. Download all data from Supabase
    ↓
5. Update sync timestamps
    ↓
Continue with new schema
```

## Migration Strategy

### Why Delete and Resync?

**Traditional Approach (Complex):**
- Write step-by-step Drift migrations (v1→v2, v2→v3, etc.)
- Handle edge cases and rollbacks
- Test all migration paths
- Debug migration failures
- 500+ lines of migration code

**New Approach (Simple):**
- Server updates `current_schema_version`
- Client detects mismatch
- Upload dirty records (protect user data)
- Delete local database
- Recreate fresh database
- Download all data
- **Result:** 200 lines of simpler code, fewer bugs

**Benefits:**
- No complex migration logic
- Guaranteed schema consistency
- Automatic rollback (delete and retry)
- User data protected (upload first)
- Faster development cycle

### Dirty Record Protection

The system ensures no data loss during migrations:

1. **Before Migration:** Upload all dirty records to Supabase
2. **During Migration:** Delete local database
3. **After Migration:** Download fresh data (includes uploaded changes)

Example flow:
```
User has 3 dirty activities (needs_upload = true)
    ↓
Schema mismatch detected (v3 → v4)
    ↓
Upload 3 activities to Supabase ✓
    ↓
Delete local database ✓
    ↓
Recreate database with v4 schema ✓
    ↓
Download all activities (includes the 3 uploaded) ✓
    ↓
No data loss!
```

## RLS (Row Level Security)

### Public Read Access

All users (authenticated and anonymous) can read config:

```sql
CREATE POLICY "Allow public read access to app_config"
    ON app_config
    FOR SELECT
    TO anon, authenticated
    USING (true);
```

**Why public read?**
- Version checks must happen before authentication
- Maintenance mode visible to all users
- No sensitive data stored in config table

### Service Role Write Access

Only backend services can modify config:

```sql
CREATE POLICY "Allow service role to manage app_config"
    ON app_config
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);
```

**Why service role only?**
- Prevents users from bypassing version checks
- Ensures centralized control
- Audit trail via updated_at timestamps

## Auto-Update Trigger

The table includes an automatic timestamp update trigger:

```sql
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
```

**Purpose:**
- Track when each config value was last changed
- Useful for debugging and auditing
- Helps identify when schema migrations were triggered

## Initial Data

Default configuration values inserted on table creation:

```sql
INSERT INTO app_config (key, value, description) VALUES
    ('min_app_version', '1.12.0', 'Minimum app version allowed to connect to the backend'),
    ('current_schema_version', '3', 'Current Drift database schema version'),
    ('maintenance_mode', 'false', 'When true, blocks all sync operations and shows maintenance screen'),
    ('force_resync_before', '', 'App versions before this version must perform a full resync')
ON CONFLICT (key) DO NOTHING;
```

## Related Documentation

- [Database Overview](/docs/database/README.md) - Complete database architecture
- [Drift Database](/docs/database/drift/README.md) - Local SQLite implementation
- [Supabase Tables](/docs/database/supabase/README.md) - Cloud backend structure
- [Server-Side Versioning Plan](/docs/database/server-side-versioning-plan.md) - Full migration strategy

## Migration File

**Location:** `/supabase/migrations/20260118_create_app_config_table.sql`

**Applied to:** Production Supabase (2026-01-18)

---

*Last updated: January 2026*
