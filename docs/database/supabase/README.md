# Supabase Database Documentation

## Overview

Supabase provides the PostgreSQL cloud backend for data synchronization and backup.

## Current Status

- **Tables**: 14 production tables (13 data tables + 1 config table)
- **Authentication**: Device-based (no user accounts)
- **Access**: Via Edge Functions and direct client connections
- **Version Control**: Server-managed via `app_config` table

## Recent Schema Changes

### January 18, 2026: App Config Table for Version Control
- **Table**: `app_config`
- **Purpose**: Server-controlled version management and feature flags
- **Schema**:
  ```sql
  CREATE TABLE app_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key TEXT NOT NULL UNIQUE,
    value TEXT NOT NULL,
    description TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW()
  );
  ```
- **Configuration Keys**:
  - `min_app_version`: Minimum app version required to connect (`"1.12.0"`)
  - `current_schema_version`: Expected Drift schema version (`"3"`)
  - `maintenance_mode`: When true, blocks all sync operations (`"false"`)
  - `force_resync_before`: App versions requiring full database resync (`""`)
- **RLS Policies**:
  - Public read access (all users can check version)
  - Service role write access (only backend can modify)
- **Benefits**:
  - Server controls when schema migrations happen
  - Enables simplified migration strategy (delete and resync)
  - Centralized version management
  - No app updates required for config changes
- **Migration**: `/supabase/migrations/20260118_create_app_config_table.sql`

### December 14, 2025: Dietary Preferences & Allergies
- **Tables**: `users`, `foods`
- **New Enum Types**:
  - `dietary_preference_enum`: omnivore, vegetarian, pescatarian, vegan, mediterranean, paleo, keto, low_carb
  - `allergy_enum`: dairy, eggs, fish, gluten, peanuts, sesame, shellfish, soy, tree_nuts
- **Users Table Changes**:
  - Added `dietary_preference` (dietary_preference_enum, nullable)
  - Added `allergies` (allergy_enum[], default '{}')
  - Added index on `dietary_preference` (partial index where not null)
- **Foods Table Changes**:
  - Added `allergens` (allergy_enum[], default '{}')
  - Added `excluded_diets` (dietary_preference_enum[], default '{}')
  - Added GIN indexes on both array columns for efficient filtering
- **Purpose**: Supports onboarding revamp with dietary preferences and allergy tracking
- **Benefit**: Enables personalized food filtering based on user diet and allergies
- **Migration**: `/supabase/migrations/20251214120000_add_dietary_preference_and_allergies.sql`
- **Schema Version**: Still v1 (non-breaking field additions)

### October 9, 2025: Events Nutrition Plan Tracking
- **Table**: `events`
- **Change**: Added `has_nutrition_plan` field (BOOLEAN DEFAULT FALSE)
- **Purpose**: Tracks whether an event has an associated nutrition plan
- **Benefit**: Enables UI to show "View Nutrition Plan" vs "Create Nutrition Plan" button
- **Migration**: `/supabase/migrations/20251009153108_add_has_nutrition_plan_to_events.sql`
- **Schema Version**: Still v1 (non-breaking field addition)

### October 8, 2025: Carb Loading Days Enhancement
- **Table**: `carb_loading_days`
- **Change**: Added `carb_protocol_g_per_kg` field (REAL/double)
- **Purpose**: Stores the carbohydrate protocol formula (e.g., 8.0 for 8g/kg bodyweight)
- **Benefit**: Enables UI to display "8g/kg bodyweight" instead of just "610g carbs target"
- **Migration**: `/supabase/migrations/20251008233419_add_carb_protocol_g_per_kg_to_carb_loading_days.sql`
- **Schema Version**: Still v1 (field addition, not a breaking change)

## Schema

The complete PostgreSQL schema is maintained in:
- **Production Dump**: `/supabase/schema_dump.sql`
- **Migrations**: `/supabase/migrations/`

## Key Features

### Row Level Security (RLS)

All tables have RLS policies for data isolation:

```sql
-- Users can only access their own data
CREATE POLICY "Users can read own data" ON users
  FOR SELECT USING (device_id = auth.jwt() ->> 'device_id');
```

### Edge Functions

Serverless functions for complex operations:
- `generate-ai-nutrition-plan` - AI-powered plan generation
- `run-plan` - Algorithmic plan generation (fallback)
- `save-food-preferences` - Batch preference updates

### Data Types

| PostgreSQL | Purpose |
|------------|---------|
| UUID | Unique identifiers |
| JSONB | Structured JSON data |
| TIMESTAMPTZ | Timezone-aware timestamps |
| TEXT[] | Array types |
| CHECK constraints | Data validation |

## Access Patterns

### Via Supabase Client
```dart
final supabase = ref.read(appExternalDepsProvider).supabaseClient;

// Basic food query
final data = await supabase
  .from('foods')
  .select()
  .eq('category', 'before_run');

// Filter foods by user allergies (exclude foods containing allergens)
final userAllergies = ['dairy', 'gluten'];
final safeFood s = await supabase
  .from('foods')
  .select()
  .not('allergens', 'cs', '{${userAllergies.join(',')}}'); // contains (cs) operator

// Filter foods by dietary preference (exclude foods not suitable for diet)
final userDiet = 'vegan';
final suitableFoods = await supabase
  .from('foods')
  .select()
  .not('excluded_diets', 'cs', '{$userDiet}'); // contains (cs) operator
```

### Via Edge Functions
```dart
final response = await supabase.functions.invoke(
  'generate-ai-nutrition-plan',
  body: planRequest,
);
```

## Sync Strategy

### Repository-Level Sync (Current)

The app uses a **repository-level sync strategy** instead of syncing all data at startup:

**Staleness Tracking:**
- Each repository tracks its last sync time in SharedPreferences
- Key format: `{repositoryKey}_last_sync` (e.g., `activities_last_sync`, `events_last_sync`)
- Staleness threshold: 24 hours per repository
- Controllers call `ensureSynced()` when they need fresh data

**Sync Flow:**
1. Controller checks if repository data is stale (>24h since last sync)
2. If fresh, skip sync (use cached data)
3. If stale, sync dependencies first (e.g., users before activities)
4. Upload dirty records to Supabase (protect user changes)
5. Download fresh data from Supabase
6. Update sync timestamp in SharedPreferences

**Sync Timestamps (SharedPreferences):**
```dart
// Stored per repository
'users_last_sync' → '2026-01-18T14:30:00Z'
'activities_last_sync' → '2026-01-18T15:45:00Z'
'events_last_sync' → '2026-01-18T15:45:00Z'
'food_preferences_last_sync' → '2026-01-17T08:00:00Z' // Stale
```

**Benefits:**
- Reduces network usage (only sync what's needed)
- Faster app startup (no blocking sync)
- Automatic dependency management
- Offline-first with smart online updates

**Dependency Graph:**
```
users → (no dependencies)
foods → (no dependencies)
activities → [users]
events → [users]
food_preferences → [users, foods]
carb_loading_plans → [users, events]
```

### Schema Version Control

The app checks `app_config.current_schema_version` to determine if local database needs migration:

**Version Check Process:**
1. App queries `app_config` table for `current_schema_version`
2. Compares with local Drift schema version
3. If mismatch:
   - Upload dirty records (backup user changes)
   - Delete local SQLite database
   - Recreate fresh database
   - Download all data from Supabase
4. If match: Continue normal operation

**Configuration Management:**
- Update `current_schema_version` to trigger client migrations
- Set `maintenance_mode = true` to block all syncs
- Increase `min_app_version` to force app updates

## Local Development

```bash
# Start local Supabase
supabase start

# Pull from production
supabase db pull

# Push schema changes
supabase db push
```
