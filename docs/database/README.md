# Database Documentation

## Overview

Mealvana Endurance uses a unified database architecture with 100% schema parity:
- **Drift (SQLite)**: Local offline-first storage with 27 tables (v1)
- **Supabase (PostgreSQL)**: Cloud backend with 27 tables (v1) - complete parity

**Multi-Sport Support (Added 2025-10-15):**
- Activities table supports running, cycling, and swimming
- Foods table includes sport-specific suitability filtering
- User profiles store sport-specific preferences (FTP, CSS)

**Weather Integration (Added 2025-10-28):**
- Weather forecasts table for caching weather data
- Supports 3-tier caching: in-memory, database (1-24hr), API fallback
- Caches by date only (not time) to reduce redundant API calls

## Architecture

### Local Database (Drift)
- **Schema Version**: 1
- **Tables**: 27 total (100% synced with Supabase)
- **Location**: `/lib/shared/database/`
- **Purpose**: Offline functionality, fast local access
- **Multi-Sport**: Cycling/swimming columns added to activities, users, foods tables
- **Weather Caching**: weather_forecasts_table for API response caching

### Cloud Database (Supabase)
- **Tables**: 27 production tables (includes weather_forecasts)
- **Schema Dump**: `/database_schemas/v1/schema.sql`
- **Purpose**: Data backup, cross-device sync, content management
- **Multi-Sport Migration**: `20251015000000_add_cycling_swimming_support.sql`
- **Weather Support**: Local-only table, not synced to Supabase

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

- [Drift Schema Details](drift/schema.md) - Complete table structures
- [Supabase Tables](supabase/tables.md) - Cloud database details
- [Migration Strategy](drift/migration-strategy.md) - Schema versioning

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

---
*Last updated: October 2025 - Schema Version 1*