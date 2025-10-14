# Database Documentation

## Overview

Mealvana Endurance uses a unified database architecture with 100% schema parity:
- **Drift (SQLite)**: Local offline-first storage with 26 tables (v1)
- **Supabase (PostgreSQL)**: Cloud backend with 26 tables (v1) - complete parity

## Architecture

### Local Database (Drift)
- **Schema Version**: 1
- **Tables**: 26 total (100% synced with Supabase)
- **Location**: `/lib/shared/database/`
- **Purpose**: Offline functionality, fast local access

### Cloud Database (Supabase)
- **Tables**: 13 production tables
- **Schema Dump**: `/supabase/schema_dump.sql`
- **Purpose**: Data backup, cross-device sync, content management

## Table Structure

### Synced Tables (13)
These tables exist in both Drift and Supabase and can sync data:

| Table | Purpose | Primary Key |
|-------|---------|-------------|
| `users` | User profiles and settings | `id` (UUID) |
| `nutrition_plans` | Generated nutrition plans | `id` (UUID) |
| `food_preferences` | User food likes/dislikes | `id` (UUID) |
| `feedback` | Plan feedback and ratings | `id` (UUID) |
| `foods` | Food database with nutrition | `id` (UUID) |
| `product_types` | Food categories (gel, bar) | `id` (UUID) |
| `categories` | Timing (before/during/after) | `id` (int) |
| `food_categories` | Food-to-category mappings | Composite |
| `user_foods` | User-created/scanned foods | `id` (UUID) |
| `user_food_categories` | User food timing | Composite |
| `user_hidden_foods` | Hidden foods per user | Composite |
| `app_content` | Dynamic UI text/parameters | `id` (UUID) |
| `edge_functions` | Edge function code | `id` (UUID) |

### Local-Only Tables (5)
These tables exist only in Drift for local functionality:

| Table | Purpose |
|-------|---------|
| `macro_targets` | Nutritional target calculations |
| `workout_notes` | User workout notes |
| `carb_loading_plans` | Carb loading feature |
| `carb_loading_simple` | Simple carb loading |
| `brands` | Brand information |

### Local-Only Columns
Some synced tables have extra Drift-only columns:
- `users.temp_plan_data` - Persists unsaved plans
- `users.swipe_hint_shown` - UI state tracking

## Key Design Decisions

1. **Device-Based Authentication**: No traditional user accounts, uses `device_id`
2. **Offline-First**: Full functionality without internet
3. **Selective Sync**: Only core tables sync to Supabase
4. **Incremental Migration**: Drift's built-in migration system for v1→v2 and beyond

## Critical Schema Notes

### Foreign Key References
- All user references use `device_id` (not `user_id`)
- Foods reference `product_type_id` (UUID to product_types.id)
- All foreign keys are enforced in both databases

### Check Constraints
The following enum constraints are enforced:
```sql
-- Users table
CHECK (gender IN ('male', 'female', 'other'))
CHECK (gut_training_level IN ('low', 'moderate', 'high'))

-- Food preferences
CHECK (preference IN ('like', 'dislike', 'willing_to_try'))
```

### Data Type Mappings
| Supabase Type | Drift Type | Notes |
|---------------|------------|--------|
| UUID | TEXT(36) | 36-character string |
| JSONB | TEXT | With JSON converter |
| TIMESTAMPTZ | DateTime | Auto-converted |
| BOOLEAN | Boolean | Native support |
| NUMERIC(5,2) | REAL | Floating point |

## File Structure

```
/lib/shared/database/
├── app_database.dart          # Main database class
├── tables/                     # Table definitions
│   ├── user_profiles.dart     # Maps to 'users' table
│   ├── nutrition_plans.dart
│   ├── food_preferences.dart
│   └── ... (18 total)
└── database_provider.dart     # Riverpod provider

/supabase/
├── schema_dump.sql            # Production schema
└── migrations/                # Schema migrations

/drift_schemas/v1/
├── schema_v1_actual.sql       # Original 4-table schema
├── production_schema_analysis.md
└── CRITICAL_FIXES_REQUIRED.md
```

## Common Operations

```dart
// Get database instance
final db = ref.read(appDatabaseProvider);

// Get current user
final user = await db.getCurrentUserProfile();

// Save nutrition plan
await db.saveNutritionPlan(plan);

// Get foods by category
final foods = await db.getFoodsByCategory('before_run');
```

## Documentation Files

- [Drift Schema Details](drift/schema.md) - Complete table structures
- [Supabase Tables](supabase/tables.md) - Cloud database details
- [Migration Strategy](drift/migration-strategy.md) - Schema versioning

## Recent Fixes Applied

✅ Fixed `foods.product_type` → `foods.product_type_id`
✅ Re-enabled foreign key constraints in user tables
✅ Added missing check constraints for enums
✅ Documented local-only tables and columns

---
*Last updated: October 2024 - Schema Version 1*