# Database Documentation

## Overview

Mealvana Endurance uses a unified database architecture with local-first design:
- **Drift (SQLite)**: Local offline-first storage with 27 tables (v1)
- **Supabase Dev (PostgreSQL)**: Cloud backend with 27 tables (v1) - full multi-sport schema
- **Supabase Prod (PostgreSQL)**: Cloud backend with 27 tables (v1) - partial multi-sport schema

**⚠️ Schema Parity Status:**
- **Development**: Full schema parity between Drift and Supabase (all multi-sport columns)
- **Production**: Schema discrepancy - missing multi-sport columns in `users` and `activities` tables
- See `/docs/dev_schema.txt` and `/docs/prod_schema.txt` for complete schemas

**Multi-Sport Support (Added 2025-10-15 to Dev):**
- Activities table supports running, cycling, and swimming (dev only)
- Foods table includes sport-specific suitability filtering (dev and prod)
- User profiles store sport-specific preferences - FTP, CSS (dev only)

**Brick Workout Support (Added 2026-01-19 to Dev):**
- Activities table includes brick metadata and relationships (dev only)
- Supports combined swim/bike/run workouts with transition phases
- Soft-delete architecture for grouping/ungrouping activities
- Unified nutrition planning across multiple sports

**Dietary Preferences & Allergies (Added 2025-12-14 to Prod):**
- User profiles store dietary preference (omnivore, vegetarian, pescatarian, vegan, mediterranean, paleo, keto, low_carb)
- User profiles store allergies array (dairy, eggs, fish, gluten, peanuts, sesame, shellfish, soy, tree_nuts)
- Foods table includes allergens and excluded_diets arrays for filtering
- GIN indexes for efficient array-based filtering queries

**Weather Integration (Added 2025-10-28):**
- Weather forecasts table for caching weather data
- Supports 3-tier caching: in-memory, database (1-24hr), API fallback
- Caches by date only (not time) to reduce redundant API calls

## Architecture

### Local Database (Drift)
- **Schema Version**: 4 (migrated from v3 with integration sync tracking columns)
- **Tables**: 27 total
- **Location**: `/lib/shared/database/`
- **Purpose**: Offline functionality, fast local access
- **Multi-Sport**: Full support - cycling/swimming columns in activities, users, foods tables
- **Weather Caching**: weather_forecasts_table for API response caching
- **Integration Sync**: Change detection and staleness tracking for external providers (Final Surge, Training Peaks)
- **Migration Strategy**: Proper Drift migrations with version bumps and idempotent checks

### Cloud Database (Supabase)
- **Dev Environment**: 27 tables with full multi-sport support
- **Prod Environment**: 27 tables with partial multi-sport support (missing users/activities columns)
- **Schema Dumps**:
  - Dev: `/docs/dev_schema.txt` (full multi-sport)
  - Prod: `/docs/prod_schema.txt` (partial multi-sport)
  - V2 Current: `/database_schemas/v2/` (current schema with migrations)
  - V1 Baseline: `/database_schemas/v1/` (original baseline, preserved)
- **Purpose**: Data backup, cross-device sync, content management
- **Multi-Sport Migration**: Applied to dev, pending for prod
- **Weather Support**: Local-only table, not synced to Supabase
- **Migration Approach**: Idempotent migrations with column existence checks

## Table Structure

### Synced Tables (13)
These tables exist in both Drift and Supabase and can sync data:

| Table | Purpose | Primary Key |
|-------|---------|-------------|
| `users` | User profiles and settings | `id` (UUID) |
| `nutrition_plans` | Generated nutrition plans | `id` (UUID) |
| `food_preferences` | User food likes/dislikes | `id` (UUID) |
| `feedback` | Plan feedback and ratings | `id` (UUID) |
| `foods` | Food database with nutrition + sport suitability | `id` (UUID) |
| `product_types` | Food categories (gel, bar) | `id` (UUID) |
| `categories` | Timing (before/during/after) | `id` (int) |
| `food_categories` | Food-to-category mappings | Composite |
| `user_foods` | User-created/scanned foods + sport suitability | `id` (UUID) |
| `user_food_categories` | User food timing | Composite |
| `user_hidden_foods` | Hidden foods per user | Composite |
| `app_content` | Dynamic UI text/parameters | `id` (UUID) |
| `edge_functions` | Edge function code | `id` (UUID) |

### Local-Only Tables (6)
These tables exist only in Drift for local functionality:

| Table | Purpose |
|-------|---------|
| `macro_targets` | Nutritional target calculations |
| `workout_notes` | User workout notes |
| `carb_loading_plans` | Carb loading feature |
| `carb_loading_simple` | Simple carb loading |
| `brands` | Brand information |
| `weather_forecasts` | Weather API response cache (1-24hr expiry) |

### Local-Only Columns
Some synced tables have extra Drift-only columns:
- `users.temp_plan_data` - Persists unsaved plans
- `users.swipe_hint_shown` - UI state tracking

## Synchronization Strategy

### Repository-Level Sync (Current)

The app uses a **repository-level sync strategy** with staleness tracking:

**Key Characteristics:**
- **24-Hour Staleness Threshold**: Data is considered stale after 24 hours
- **Timestamp Storage**: Last sync times stored in SharedPreferences (key: `{repositoryKey}_last_sync`)
- **Dependency Resolution**: Repositories declare dependencies (e.g., activities depends on users)
- **On-Demand Syncing**: Controllers call `ensureSynced()` to get fresh data when needed
- **No App Startup Sync**: Returning users see cached data until stale or manually refreshed

**Sync Flow:**
1. Controller checks if data is stale (>24h since last sync)
2. If fresh, returns immediately (no network call)
3. If stale, recursively syncs dependencies first
4. Uploads dirty records for repository
5. Downloads fresh data from Supabase
6. Updates sync timestamp in SharedPreferences

**Example Usage:**
```dart
@override
FutureOr<List<Activity>> build() async {
  final userId = await ref.watch(userIdProvider.future);
  await ref.read(syncCoordinatorProvider.notifier).ensureSynced(
    'activities',
    userId,
    repository: this,
  );
  // Now safe to query activities - data is fresh
  return await _db.getAllActivities();
}
```

**Benefits:**
- Reduced network usage (only sync what's needed)
- Faster app startup (no sync blocking)
- Automatic dependency management
- Offline-first with smart online updates

### Server-Side Version Control

The database architecture includes **app_config** table for server-controlled versioning:

**Table: app_config**
- **Location**: Supabase PostgreSQL
- **Purpose**: Stores application configuration and version control
- **Schema**:
  ```sql
  CREATE TABLE app_config (
    id UUID PRIMARY KEY,
    key TEXT NOT NULL UNIQUE,
    value TEXT NOT NULL,
    description TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW()
  )
  ```

**Configuration Keys:**
| Key | Purpose | Example Value |
|-----|---------|---------------|
| `min_app_version` | Minimum app version allowed | `"1.12.0"` |
| `current_schema_version` | Current Drift schema version | `"3"` |
| `maintenance_mode` | Blocks sync during maintenance | `"false"` |
| `force_resync_before` | Versions requiring full resync | `""` |

**RLS Policies:**
- **Public Read**: All users can read config (for version checks)
- **Service Role Write**: Only backend can modify config

**Schema Version Control:**
The app checks `current_schema_version` against local Drift schema to determine if database migration is needed. This enables:
- Server-controlled schema updates
- Simplified migration strategy (delete and resync instead of complex migrations)
- Centralized version management

## Key Design Decisions

1. **Device-Based Authentication**: No traditional user accounts, uses `device_id`
2. **Offline-First**: Full functionality without internet
3. **Repository-Level Sync**: Each repository tracks its own staleness and syncs independently
4. **24-Hour Staleness**: Data older than 24 hours is automatically refreshed
5. **SharedPreferences Timestamps**: Sync times persisted outside database for resync safety
6. **Dependency Resolution**: Automated sync ordering based on foreign key relationships
7. **Simple Schema Migrations**: Delete local DB and resync for schema changes
8. **Server Version Control**: Backend manages minimum versions and schema compatibility

## Critical Schema Notes

### Foreign Key References
- All user references use `device_id` (not `user_id`)
- Foods reference `product_type_id` (UUID to product_types.id)
- All foreign keys are enforced in both databases

### Enum Types

**Supabase (PostgreSQL):**
Supabase uses native PostgreSQL enum types:
- `dietary_preference_enum`: omnivore, vegetarian, pescatarian, vegan, mediterranean, paleo, keto, low_carb
- `allergy_enum`: dairy, eggs, fish, gluten, peanuts, sesame, shellfish, soy, tree_nuts
- `gender_enum`: male, female, other, unknown
- `gut_training_enum`: low, moderate, high
- `activity_type_enum`: running, cycling, swimming, triathlon, duathlon, multisport
- `category_enum`: before_run, during_run, after_run
- `product_type_enum`: gel, bar, chew, drink_mix, etc.

**Drift (SQLite):**
SQLite doesn't support native enums, so Drift uses TEXT columns with CHECK constraints:
```sql
-- Users table
CHECK (gender IN ('male', 'female', 'other') OR gender IS NULL)
CHECK (gut_training_level IN ('low', 'moderate', 'high'))
CHECK (dietary_preference IN ('omnivore', 'vegetarian', 'pescatarian', 'vegan', 'mediterranean', 'paleo', 'keto', 'low_carb') OR dietary_preference IS NULL)

-- Food preferences
CHECK (preference IN ('like', 'dislike', 'willing_to_try'))
```

**Array Storage:**
- **Supabase**: Native PostgreSQL arrays (e.g., `allergy_enum[]`)
- **Drift**: PostgreSQL-compatible text format (e.g., `'{dairy,gluten,peanuts}'`)

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
│   ├── users_table.dart       # UsersTable → 'users' table
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

## Weather Forecasts Caching

### Table: weather_forecasts

**Purpose**: Cache weather API responses to reduce API calls and improve performance

**Schema**:
```sql
CREATE TABLE weather_forecasts_table (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  forecast_date DATETIME NOT NULL,  -- Stored as date only (time stripped)
  temperature_c REAL NOT NULL,
  humidity_pct INTEGER NOT NULL,
  forecast_available BOOLEAN NOT NULL,
  source TEXT NOT NULL,  -- 'forecast', 'historical', or 'default'
  conditions TEXT,  -- Weather conditions (clear, cloudy, rain, etc.)
  wind_speed_kmh INTEGER,
  precipitation_mm REAL,
  fetched_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  expires_at DATETIME NOT NULL
);
```

**Caching Strategy (3-Tier)**:

1. **In-Memory Cache** (Fastest)
   - Stored in `WeatherService._memoryCache` Map
   - Key format: `"lat_lon_yyyy-MM-dd"`
   - Duration: For session lifetime
   - Purpose: Prevents refetch on tab switches

2. **Database Cache** (Fast)
   - Stored in `weather_forecasts_table`
   - Variable expiry:
     - **Forecast data**: 1 hour (weather can change)
     - **Historical data**: 24 hours (rarely changes)
   - Cache key: lat/lon + date (time ignored)

3. **API Fallback** (Slow)
   - Calls `/supabase/functions/get-weather-forecast`
   - Open-Meteo API (free, no key required)
   - Supports 0-16 days future, 0-92 days past

**Key Optimizations**:
- **Date-only caching**: Changing time from 7:00 AM → 7:05 AM doesn't refetch
- **Replace on insert**: `InsertMode.insertOrReplace` prevents duplicates
- **Automatic cleanup**: Expired forecasts removed in background

**Example Usage**:
```dart
// Fetch weather (checks all 3 cache tiers automatically)
final forecast = await weatherService.getWeatherForecast(
  location: Location(latitude: 37.7749, longitude: -122.4194),
  activityDate: DateTime(2025, 10, 28),
);

// Result: forecast or historical data, or defaults (20°C, 60%)
print('Temperature: ${forecast.temperatureC}°C');
print('Source: ${forecast.source}'); // 'forecast', 'historical', 'default'
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

### Core Architecture
- [Sync Architecture](sync-architecture.md) - **START HERE** - Repository-level sync with staleness tracking
- [Drift Database](drift/README.md) - Complete local SQLite schema and implementation
- [Supabase Database](supabase/README.md) - Cloud PostgreSQL backend details

### Version Control & Migration
- [App Config Table](app-config-table.md) - Server-controlled version management
- [Server-Side Versioning Plan](server-side-versioning-plan.md) - Comprehensive migration strategy

## Recent Fixes Applied

✅ Fixed `foods.product_type` → `foods.product_type_id`
✅ Re-enabled foreign key constraints in user tables
✅ Added missing check constraints for enums
✅ Documented local-only tables and columns

## Multi-Sport Schema Changes (v1 - October 2025)

### Activities Table
Added support for cycling and swimming:
- `sport_type` TEXT - 'running', 'cycling', or 'swimming'
- `cycling_power_watts` INTEGER - Average power for cycling
- `cycling_ftp_watts` INTEGER - Functional Threshold Power
- `swimming_speed_per_100m` INTEGER - Pace in seconds per 100m
- `swimming_css_seconds_per_100m` INTEGER - Critical Swim Speed

### Users Table
Added sport-specific preferences:
- `cycling_ftp_watts` INTEGER - User's default FTP
- `prefers_cycling_power` BOOLEAN - Power vs speed preference
- `swimming_css_seconds_per_100m` INTEGER - User's default CSS
- `prefers_swimming_pace` BOOLEAN - Pace vs speed preference

### Foods & User Foods Tables
Added sport suitability filtering:
- `suitable_for_activities` JSONB - Sport-specific food suitability
  - Example: `{"running": true, "cycling": true, "swimming": false}`
  - NULL means suitable for all sports (backward compatible)
  - Indexed with GIN for efficient JSONB queries

**Migration:** `/supabase/migrations/20251015000000_add_cycling_swimming_support.sql`

## Integration Sync Tracking (v4 - January 2026)

### Activities Table Changes

Added support for tracking schedule changes from external providers (Final Surge, Training Peaks):

**New Columns:**
- `needs_nutrition_refresh` BOOLEAN (default false) - Flags when nutrition plan is stale due to schedule changes
- `provider_deleted_at` TIMESTAMP - Soft-delete timestamp when provider removes workout
- `provider_scheduled_at` TIMESTAMP - Original provider schedule for change detection
- `schedule_changed_at` TIMESTAMP - When change was last detected during sync

**Significant Schedule Change Criteria:**
A schedule change triggers `needs_nutrition_refresh = true` when:
- Time changed by more than 30 minutes
- Date changed (different day)
- Duration changed by more than 15 minutes
- Distance changed by more than 10%

**Database Indexes:**
- `idx_activities_needs_nutrition_refresh` - Partial index for efficient queries on stale plans (WHERE needs_nutrition_refresh = TRUE)
- `idx_activities_provider_deleted_at` - Partial index for soft-deleted workouts (WHERE provider_deleted_at IS NOT NULL)

**Key Behaviors:**
- When sync detects schedule change, activity is updated and `needs_nutrition_refresh` flag is set
- User sees warning banner in Activity Detail screen prompting to regenerate nutrition plan
- Provider-deleted workouts are soft-deleted (remain visible with indicator) rather than hard-deleted
- Single-activity refresh button allows fetching latest data for specific workout
- On-demand sync pattern via `ensureSynced()` checks for changes when user views activities

**Migration:** `/supabase/migrations/20260125000000_add_integration_sync_tracking.sql`

**Documentation:**
- Feature implementation: `/docs/update_integration/notes.md`
- Design decisions: `/docs/update_integration/design-decisions.md`
- Implementation checklist: `/docs/update_integration/checklist.md`

---

## Brick Workout Support (v3 - January 2026)

### Activities Table Changes
Added support for brick workouts (multi-sport training sessions):

**New Columns:**
- `brick_metadata` JSONB (Supabase) / TEXT (Drift) - Stores segment information for brick workouts
- `brick_id` UUID (Supabase) / TEXT (Drift) - Links archived activities to their parent brick

**New Enum Values:**
- `activity_type_enum`: Added 'brick' value for multi-sport workouts
- `activity_status_enum`: Added 'archived_for_brick' status for soft-deleted original activities

**Brick Metadata JSON Structure:**
```json
{
  "segment_order": ["swimming", "running"],
  "segments": [
    {
      "sport": "swimming",
      "order": 1,
      "duration_minutes": 40,
      "intensity": "moderate",
      "distance_meters": 2000,
      "pace_per_100m_seconds": 120,
      "pool_or_open_water": "pool"
    },
    {
      "sport": "running",
      "order": 2,
      "duration_minutes": 55,
      "intensity": "moderate",
      "distance_miles": 6.2,
      "pace_minutes_per_mile": 8.5
    }
  ],
  "original_activity_ids": ["uuid-1", "uuid-2"],
  "created_from_existing": true,
  "total_duration_minutes": 95
}
```

**Database Indexes:**
- `idx_activities_brick_id` - Efficient queries for archived activities belonging to a brick
- `idx_activities_brick_type` - Efficient queries for brick activities

**Key Behaviors:**
- When creating a brick from existing activities, originals are soft-deleted with `status = 'archived_for_brick'` and `brick_id` pointing to the new brick
- Ungrouping a brick restores original activities and deletes the brick
- Brick activities sync as single records with embedded segment metadata
- Supports 2-3 sport combinations in any order (swim/run, bike/run, swim/bike/run, etc.)

**Migration:** `/supabase/migrations/20260119000000_add_brick_support.sql`

**Documentation:**
- Feature overview: `/docs/brick/README.md`
- Schema details: `/docs/brick/schema-changes.md`
- Nutrition algorithm: `/docs/brick/nutrition-algorithm.md`

## Schema Version History

### V4 (Current - January 2026)
- **Migration Approach**: Proper Drift migrations with version bumps
- **Key Changes**:
  - Added integration sync tracking columns to activities table:
    - `needsNutritionRefresh` (boolean) - flags stale nutrition plans when schedule changes from external providers
    - `providerDeletedAt` (datetime) - soft-delete timestamp when provider removes workout
    - `providerScheduledAt` (datetime) - original provider schedule for change detection
    - `scheduleChangedAt` (datetime) - when change was last detected during sync
  - Added partial indexes for performance on sync queries
  - Enables schedule change detection for Final Surge and Training Peaks integrations
- **Schema Location**: `/database_schemas/v4/`
- **Supabase Migration**: `/supabase/migrations/20260125000000_add_integration_sync_tracking.sql`
- **Status**: Development and production - full integration sync support

### V3 (January 2026)
- **Migration Approach**: Proper Drift migrations with version bumps
- **Key Changes**:
  - Added brick workout support (brick_metadata and brick_id columns)
  - Added 'brick' to activity_type_enum and 'archived_for_brick' to activity_status_enum
  - Added indexes for brick queries
  - Transition food category support
- **Schema Location**: `/database_schemas/v3/`
- **Status**: Released to production

### V2 (Current - December 2025)
- **Migration Approach**: Proper Drift migrations with version bumps
- **Key Changes**:
  - Consolidated preference_level, dietary_preference, and allergies columns
  - Added idempotent migration checks (verifies column existence before adding)
  - Implemented simple rollback strategy (delete DB and resync)
- **Schema Location**: `/database_schemas/v2/`

### V1 (Baseline - October 2025)
- **Initial Implementation**: 27 tables with multi-sport support
- **Approach**: Runtime column additions in beforeOpen hook (deprecated)
- **Schema Location**: `/database_schemas/v1/` (preserved for reference)

---
*Last updated: January 2026 - Schema Version 4 with Integration Sync Tracking*