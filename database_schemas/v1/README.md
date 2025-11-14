# Drift Schema V1 - Production Baseline

## Overview

This directory contains the **official v1 schema** for Mealvana Endurance's database. This schema represents the development baseline with full multi-sport support.

**Schema Version**: v1
**Total Tables**: 27
**Last Generated**: 2025-11-06
**Status**: Development baseline (living v1 - grows until v2 migration needed)
**⚠️ Note**: Production environment is missing multi-sport columns in `users` and `activities` tables

## V1 Schema Philosophy

This is a **living v1 schema** that grows with new features until we need breaking changes (which will trigger v2). We are NOT freezing v1 - it will continue to evolve as we add new non-breaking features.

## Current Schema (27 Tables)

### Core Tables (5)
1. **users** (user_profiles_table) - User biometric data, device authentication, multi-sport preferences
2. **nutrition_plans** - Generated nutrition plans with JSON data
3. **food_preferences_table** - User's liked/disliked/willing-to-try foods
4. **feedback** - User feedback and survey responses
5. **macro_targets_table** - Complete nutrition target calculations (26 columns)

### Food System Tables (9)
6. **foods_table** - Global food database with nutritional information and sport suitability
7. **product_types_table** - Food product categories (gel, bar, drink mix)
8. **categories_table** - Timing categories (before/during/after run)
9. **food_categories_table** - Many-to-many food-to-category mappings
10. **user_foods_table** - User-created or barcode-scanned foods
11. **user_food_categories_table** - User food timing associations
12. **user_hidden_foods_table** - Foods hidden by users
13. **edge_functions_table** - Edge function code storage
14. **feature_survey_responses** - User feature request votes

### Content Management (2)
15. **app_content_table** - Dynamic UI text and algorithm parameters
16. **workout_notes** - User workout journal entries

### Calendar Feature Tables (5)
17. **activities** - Scheduled workouts and events (running, cycling, swimming)
18. **events** - Race event details (marathon, half, 10K, etc.)
19. **activity_completions** - Post-workout data and ratings
20. **carb_loading_plans** - Multi-day carb loading plans for races
21. **carb_loading_days** - Daily carb targets and meal breakdowns

### Carb Loading Food System (6)
22. **meal_types** - Meal categories (breakfast, lunch, dinner, snacks)
23. **carb_loading_foods** - Global default carb loading foods
24. **carb_loading_user_foods** - User-created carb loading foods
25. **carb_loading_food_meal_types** - Links default foods to meal types
26. **carb_loading_user_food_meal_types** - Links user foods to meal types
27. **carb_loading_day_meals** - Actual food selections per meal per day

## Schema Parity: Drift ↔ Supabase

**Development Environment**:
- All 27 tables exist in both Drift SQLite and Supabase PostgreSQL Dev
- Full multi-sport support (cycling/swimming columns in users, activities, foods)
- Type mappings: TEXT ↔ UUID, REAL ↔ numeric, INTEGER ↔ integer
- Foreign key constraints preserved in both systems
- Row Level Security (RLS) policies in Supabase only

**⚠️ Production Environment**:
- All 27 tables exist but schemas differ between local and cloud
- Production Supabase is missing multi-sport columns in `users` and `activities` tables
- `foods` table has multi-sport columns in both dev and prod
- See `/docs/prod_schema.txt` for current production schema state

## Key Design Decisions

### Authentication Strategy
- **Primary**: Device-based auth via `device_id`
- **Calendar/Carb Loading**: User-based auth via `user_id` (references `users.id`)
- This mixed approach supports both device-specific and user-specific features

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
- **schema.sql** - Complete SQL DDL dump from Supabase Dev (all 27 tables with multi-sport support, RLS policies, functions, triggers)
- **drift_schema_v1.json** - Drift-specific schema snapshot for migration testing (auto-generated)

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

## Validation Checklist

To validate v1 schema correctness:

- [x] Table count: 27 tables total
- [x] Multi-sport support in development (cycling/swimming columns)
- [x] feature_survey_responses table added
- [x] All calendar tables present (5 tables)
- [x] All carb loading food tables present (6 tables)
- [x] Foreign keys reference correct tables
- [x] Check constraints enforced
- [x] Schema snapshot generated successfully
- [ ] Production schema needs multi-sport migration for users/activities tables

## Related Documentation

- [Drift Database Documentation](/docs/database/drift/README.md)
- [Supabase Tables Documentation](/docs/database/supabase/README.md)
- [Dev/Prod Workflow](/docs/features/dev_prod/readme.md)
- [Migration Testing Strategy](/docs/test/roadmap.md)
