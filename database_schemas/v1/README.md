# Drift Schema V1 - Production Baseline

## Overview

This directory contains the **official v1 schema** for Mealvana Endurance's database. This schema represents the development baseline with authentication support.

**Schema Version**: v1
**Total Tables**: 16
**Last Generated**: 2025-11-17 (Phase 0 - Auth Prerequisites)
**Status**: Development baseline (living v1 - grows until v2 migration needed)
**Recent Changes**: Added auth columns to `users` table (links to Supabase `auth.users`)

## V1 Schema Philosophy

This is a **living v1 schema** that grows with new features until we need breaking changes (which will trigger v2). We are NOT freezing v1 - it will continue to evolve as we add new non-breaking features.

## Current Schema (16 Tables)

### Core Tables (3)
1. **users** - User biometric data, authentication (links to auth.users), and preferences
2. **food_preferences_table** - User's liked/disliked/willing-to-try foods
3. **feedback** - User feedback and survey responses

### Food System Tables (2)
4. **foods** - Global food database with nutritional information
5. **user_foods_table** - User-created or barcode-scanned foods

### Content Management (2)
6. **app_content_table** - Dynamic UI text and algorithm parameters
7. **edge_functions_table** - Edge function code storage

### Calendar Feature Tables (4)
8. **activities** - Scheduled workouts and events
9. **events** - Race event details (marathon, half, 10K, etc.)
10. **carb_loading_plans** - Multi-day carb loading plans for races
11. **carb_loading_days** - Daily carb targets and meal breakdowns

### Carb Loading Food System (3)
12. **carb_loading_foods** - Global default carb loading foods
13. **carb_loading_user_foods** - User-created carb loading foods
14. **carb_loading_day_meals** - Actual food selections per meal per day

### Additional Features (2)
15. **weather_forecasts_table** - Weather data for activity planning
16. **feature_survey_responses** - User feature request votes

## Schema Parity: Drift ↔ Supabase

**Development Environment**:
- All 16 tables exist in Drift SQLite
- Type mappings: TEXT ↔ UUID, REAL ↔ numeric, INTEGER ↔ integer
- Foreign key constraints preserved in both systems
- Row Level Security (RLS) policies in Supabase only

**Production Environment (Requires Migration)**:
- ⚠️ Production Supabase DOES NOT have auth columns in `public.users` table yet
- **Action Required**: Run `migration_auth_phase0_complete.sql` to update production
- Migration is NON-DESTRUCTIVE and IDEMPOTENT - safe to run multiple times

**Authentication Tables**:
- `auth.users` - Supabase-managed table (automatically exists)
- `public.users` - Our app data, links to auth.users via `auth_user_id`
- Sessions managed by Supabase SDK (stored in platform secure storage)

## Key Design Decisions (Phase 0 - Authentication Prerequisites)

### Authentication Strategy (Transitioning)
- **Current (Legacy)**: Device-based auth via `device_id`
- **Phase 0 (New)**: Added Supabase auth columns to `public.users` table
  - `auth_user_id`: Links to `auth.users.id` (nullable during migration)
  - `auth_provider`: ENUM type ('anonymous', 'email', 'google', 'apple')
  - `is_anonymous`: Boolean flag for anonymous users
- **Phase 1 (Coming)**: Anonymous auth as default, optional account linking
- **Session Management**: Handled by Supabase SDK
  - Sessions stored in platform secure storage (iOS Keychain, Android KeyStore)
  - Auto-refresh before expiry (access: 1hr, refresh: 7 days)
  - No custom session table needed

### Data Integrity
- **Soft deletes**: `is_deleted` flags on synced tables
- **Foreign keys**: CASCADE delete for dependent data
- **Check constraints**: Extensive validation for enums and positive values
- **Unique constraints**: Prevent duplicate entries

### Storage Strategy
- **JSON fields**: Complex data stored as JSON in TEXT columns
- **UUIDs**: Drift stores as TEXT, Supabase as UUID type
- **Timestamps**: Drift uses INTEGER (Unix epoch), Supabase uses TIMESTAMP

## Files in this Directory

- **README.md** - This documentation file
- **schema.sql** - Complete SQL DDL dump from Supabase (needs regeneration to include auth_sessions)
- **drift_schema_v1.json** - Drift-specific schema snapshot (17 tables, includes auth changes)
- **migration_auth_phase0_complete.sql** - Idempotent PostgreSQL migration for Phase 0 auth prerequisites

## Generating New Schema Snapshots

When tables are added or modified, regenerate both files:

```bash
# 1. Generate Drift schema snapshot (for migration testing)
dart run drift_dev schema dump lib/shared/database/app_database.dart database_schemas/v1/

# 2. Generate Supabase SQL dump (human-readable DDL)
supabase db dump --local -f database_schemas/v1/schema.sql --schema public

# 3. Verify table count
cat database_schemas/v1/drift_schema_v1.json | python3 -c "import json, sys; data=json.load(sys.stdin); print(f'{len([e for e in data[\"entities\"] if e[\"type\"]==\"table\"])} tables')"
```

## Migration Strategy for V2

When we need **breaking changes** (table drops, column renames, etc.):

1. **Create v2 directory**: `database_schemas/v2/`
2. **Update schema version**: `schemaVersion => 2` in `app_database.dart`
3. **Generate v2 snapshot**: `dart run drift_dev schema dump`
4. **Implement migration**:
   ```dart
   @override
   MigrationStrategy get migration => MigrationStrategy(
     onUpgrade: (m, from, to) async {
       if (from < 2) {
         // Add migration logic here
       }
     },
   );
   ```
5. **Test migration**: Use drift_dev schema steps command
6. **Deploy to Supabase**: Create Supabase migration files

## Validation Checklist (Phase 0 Complete)

To validate v1 schema correctness:

- [x] Table count: 16 tables total (removed auth_sessions)
- [x] users table has auth columns (auth_user_id, auth_provider, is_anonymous)
- [x] UUID generation fixed (proper UUID v4)
- [x] All calendar tables present (4 tables)
- [x] All carb loading food tables present (3 tables)
- [x] Foreign keys reference correct tables
- [x] Check constraints enforced
- [x] Schema snapshot generated successfully
- [x] Simplified architecture (no SessionRepository, no auth_sessions table)
- [ ] Production migration pending (run migration_auth_phase0_complete.sql)

## Related Documentation

- [Drift Database Documentation](/docs/database/drift/README.md)
- [Supabase Tables Documentation](/docs/database/supabase/README.md)
- [Dev/Prod Workflow](/docs/features/dev_prod/readme.md)
- [Migration Testing Strategy](/docs/test/roadmap.md)
