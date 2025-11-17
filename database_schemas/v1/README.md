# Drift Schema V1 - Production Baseline

## Overview

This directory contains the **official v1 schema** for Mealvana Endurance's database. This schema represents the development baseline with authentication support.

**Schema Version**: v1
**Total Tables**: 17
**Last Generated**: 2025-11-17 (Phase 0 - Auth Prerequisites)
**Status**: Development baseline (living v1 - grows until v2 migration needed)
**Recent Changes**: Added `auth_sessions` table and auth columns to `users` table

## V1 Schema Philosophy

This is a **living v1 schema** that grows with new features until we need breaking changes (which will trigger v2). We are NOT freezing v1 - it will continue to evolve as we add new non-breaking features.

## Current Schema (17 Tables)

### Core Tables (3)
1. **users** - User biometric data, authentication, and preferences
2. **food_preferences_table** - User's liked/disliked/willing-to-try foods
3. **feedback** - User feedback and survey responses

### Authentication (1) - NEW in Phase 0
4. **auth_sessions** - Offline session persistence for Supabase auth (24-hour grace period)

### Food System Tables (2)
5. **foods** - Global food database with nutritional information
6. **user_foods_table** - User-created or barcode-scanned foods

### Content Management (2)
7. **app_content_table** - Dynamic UI text and algorithm parameters
8. **edge_functions_table** - Edge function code storage

### Calendar Feature Tables (4)
9. **activities** - Scheduled workouts and events
10. **events** - Race event details (marathon, half, 10K, etc.)
11. **carb_loading_plans** - Multi-day carb loading plans for races
12. **carb_loading_days** - Daily carb targets and meal breakdowns

### Carb Loading Food System (3)
13. **carb_loading_foods** - Global default carb loading foods
14. **carb_loading_user_foods** - User-created carb loading foods
15. **carb_loading_day_meals** - Actual food selections per meal per day

### Additional Features (2)
16. **weather_forecasts_table** - Weather data for activity planning
17. **feature_survey_responses** - User feature request votes

## Schema Parity: Drift ↔ Supabase

**Development Environment**:
- All 17 tables exist in both Drift SQLite and Supabase PostgreSQL
- Type mappings: TEXT ↔ UUID, REAL ↔ numeric, INTEGER ↔ integer
- Foreign key constraints preserved in both systems
- Row Level Security (RLS) policies in Supabase only

**Production Environment (Requires Migration)**:
- ⚠️ Production Supabase DOES NOT have `auth_sessions` table yet
- ⚠️ Production Supabase DOES NOT have auth columns in `users` table yet
- **Action Required**: Run `migration_auth_phase0.sql` to update production
- Migration is NON-DESTRUCTIVE - all existing data remains intact

## Key Design Decisions (Phase 0 - Authentication Prerequisites)

### Authentication Strategy (Transitioning)
- **Current (Legacy)**: Device-based auth via `device_id`
- **Phase 0 (New)**: Added Supabase auth columns to `users` table
  - `auth_user_id`: Canonical user ID from Supabase auth.uid() (nullable during migration)
  - `auth_provider`: OAuth provider ('anonymous', 'email', 'google', 'apple')
  - `is_anonymous`: Boolean flag for anonymous users
- **Phase 1 (Coming)**: Anonymous auth as default, optional account linking
- **Offline Support**: Custom session persistence in `auth_sessions` table (24-hour grace period)

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
- **migration_auth_phase0.sql** - PostgreSQL migration for Phase 0 auth prerequisites

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

- [x] Table count: 17 tables total
- [x] auth_sessions table added with proper constraints
- [x] users table has auth columns (auth_user_id, auth_provider, is_anonymous)
- [x] SessionRepository implemented (FOA compliant)
- [x] UUID generation fixed (proper UUID v4)
- [x] All calendar tables present (4 tables)
- [x] All carb loading food tables present (3 tables)
- [x] Foreign keys reference correct tables
- [x] Check constraints enforced
- [x] Schema snapshot generated successfully
- [ ] Production migration pending (run migration_auth_phase0.sql)

## Related Documentation

- [Drift Database Documentation](/docs/database/drift/README.md)
- [Supabase Tables Documentation](/docs/database/supabase/README.md)
- [Dev/Prod Workflow](/docs/features/dev_prod/readme.md)
- [Migration Testing Strategy](/docs/test/roadmap.md)
