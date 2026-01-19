# Drift SQLite Database Documentation

## Overview

Mealvana Endurance uses Drift (formerly Moor) as its local SQLite database solution, providing offline-first functionality with type-safe database access. This documentation covers the complete schema (version 1) with 27 tables.

## Database Architecture

### Schema Version
- **Current Version**: 2 (migrated from v1 using proper Drift migrations)
- **Total Tables**: 27
- **Synced Tables**: 13 (sync with Supabase)
- **Local-Only Tables**: 7 (exist only in Drift, includes weather cache)
- **Calendar Feature Tables**: 7 (activities, events, carb_loading_plans, carb_loading_days, plus food system tables — completion data now lives on `activities`)
- **Weather Table**: 1 (weather_forecasts for API response caching)
- **Migration Strategy**: Idempotent migrations with column existence checks

### Database Location
- **Database Class**: `/lib/shared/database/app_database.dart`
- **Table Definitions**: `/lib/shared/database/tables/`
- **Schema SQL**: `/docs/database/drift/schema.sql`
- **Migration Schemas**: `/drift_schemas/v1/`

## Table Categories

### 1. Synced Tables (13)
These tables synchronize with Supabase PostgreSQL for backup and cross-device functionality:

| Table | Purpose | Primary Key | Foreign Keys |
|-------|---------|-------------|--------------|
| `user_profiles` | User biometric data and settings | `id` (UUID) | - |
| `nutrition_plans` | Generated nutrition plans | `id` (UUID) | `device_id` → `user_profiles.device_id` |
| `food_preferences` | User food likes/dislikes | `id` (UUID) | `device_id` → `user_profiles.device_id` |
| `feedback` | User feedback and surveys | `id` (UUID) | `device_id` → `user_profiles.device_id` (nullable) |
| `foods` | Food database with nutrition | `id` (UUID) | `product_type_id` → `product_types.id` |
| `product_types` | Food product categories | `id` (UUID) | - |
| `categories` | Timing categories | `id` (int) | - |
| `food_categories` | Food-to-category mapping | Composite | `food_id`, `category_id` |
| `user_foods` | User-created/scanned foods | `id` (UUID) | `device_id` → `user_profiles.device_id` |
| `user_food_categories` | User food timing | Composite | `user_food_id` |
| `user_hidden_foods` | Hidden foods per user | Composite | `device_id`, `food_id` |
| `app_content` | Dynamic UI text/parameters | `id` (UUID) | - |
| `edge_functions` | Edge function code | `id` (UUID) | - |

### 2. Local-Only Tables (7)
These tables exist only in Drift for local functionality:

| Table | Purpose | Primary Key | Foreign Keys |
|-------|---------|-------------|--------------|
| `macro_targets` | Nutrition target calculations | `id` (text) | - |
| `workout_notes` | User workout journal | `id` (UUID) | `userId` → `user_profiles.id` |
| `carb_loading_plans` | Carb loading planning | `id` (UUID) | `userId` → `user_profiles.id` |
| `weather_forecasts` | Weather API response cache | `id` (int, auto) | - |
| `carb_loading_simple_plans` | Simplified carb loading | `id` (UUID) | `userId` → `user_profiles.id` |
| `carb_loading_days` | Individual carb loading day entries | `id` (UUID) | `carb_loading_plan_id` → `carb_loading_plans.id` |
| `brands` | Brand affiliate information | `id` (text) | - |

### 3. Calendar Tables (2)
These tables power the calendar and event management features:

| Table | Purpose | Primary Key | Foreign Keys |
|-------|---------|-------------|--------------|
| `activities` | Training activities (running/cycling/swimming) | `id` (UUID) | `user_id` → `user_profiles.id` |
| `events` | Race events (optionally linked to activities) | `id` (UUID) | `activity_id` → `activities.id` (nullable) |

**Key Relationship**:
- Activities are training sessions (running, cycling, swimming)
- Events are races (marathons, 5Ks, etc.)
- Events MAY have an associated activity, but NOT all activities have events
- An event can exist without an activity (e.g., a future race you haven't trained for yet)

**Multi-Sport Support (Added 2025-10-15)**:
The `activities` table now supports three sports:
- **Running** (original): distance_miles, pace_target_minutes_per_mile
- **Cycling** (new): cycling_power_watts, cycling_ftp_watts
- **Swimming** (new): swimming_speed_per_100m, swimming_css_seconds_per_100m
- **Sport Type**: `sport_type` column determines which sport-specific fields are populated

## Key Design Patterns

### 1. Device-Based Authentication
- Users are identified by `device_id` (not traditional user accounts)
- Most foreign keys reference `device_id` from `user_profiles` table
- Exception: `workout_notes` and carb loading tables reference `user_profiles.id` (UUID)

### 2. Foreign Key Strategy
```sql
-- Most tables use device_id for device-based auth:
FOREIGN KEY (device_id) REFERENCES user_profiles(device_id)

-- Some tables use user profile UUID:
FOREIGN KEY (userId) REFERENCES user_profiles(id)
```

### 3. Soft Deletes
- `nutrition_plans` and `user_foods` use `is_deleted` flag
- Allows data recovery and sync conflict resolution

### 4. JSON Storage
Several tables store complex data as JSON:
- `nutrition_plans.plan_data` - Complete nutrition plan
- `feedback.feedback_data` - Survey responses
- `app_content.content_data` - Dynamic content
- `carb_loading_plans.planData` - Carb loading details
- `carb_loading_simple_plans.daySelectionsJson` - Food selections
- `foods.suitable_for_activities` - Sport-specific food suitability (JSONB)
- `user_foods.suitable_for_activities` - Sport-specific food suitability (JSONB)

## Table Details

### Core User Tables

#### user_profiles
```sql
- id: UUID (primary key)
- device_id: Unique device identifier
- gender: male/female/other
- birthday: Date of birth
- height_feet/height_inches: Height
- weight_pounds: Body weight
- gut_training_level: low/moderate/high
- has_completed_onboarding: Boolean
- temp_plan_data: (Drift-only) Temporary storage
- swipe_hint_shown: (Drift-only) UI state
```

### Nutrition Planning Tables

#### nutrition_plans
```sql
- id: UUID (primary key)
- device_id: Foreign key
- plan_id: Unique plan identifier
- plan_data: JSON with full plan details
- is_deleted: Soft delete flag
```

#### macro_targets (Local-Only)
Complete nutrition target calculations with 26 columns:
- **Pre-run macros**: carbs, protein, fat cap, fluids, sodium
- **During-run macros**: carb rate/total, fluid rate/total, sodium rate/total
- **Post-run macros**: carbs, protein, fluids, sodium
- **Run metrics**: distance, duration, pace, calories, MET
- **Metadata**: calculation rule, timestamp, modification tracking

### Food Management Tables

#### foods
```sql
- id: UUID (primary key)
- name: Food name
- label: Display label
- product_type_id: Category reference
- Nutrition: carbs_g, protein_g, fat_g, sodium_mg, water_ml
```

#### user_foods
User-created or barcode-scanned foods:
```sql
- id: UUID (primary key)
- device_id: User reference
- client_food_id: Client-generated ID
- barcode: Scanned barcode (optional)
- brand: Brand name
- Nutrition: carbs_g, protein_g, fat_g, sodium_mg, water_ml
- serving_size/serving_unit: Portion information
```

### User Activity Tables

#### workout_notes (Local-Only)
```sql
- id: UUID (primary key)
- userId: References user_profiles.id (NOT device_id)
- planId: Optional nutrition plan reference
- noteText: Journal entry
- rating: 1-5 scale (optional)
- createdAt/updatedAt: Timestamps
```

#### carb_loading_plans (Local-Only)
```sql
- id: UUID (primary key)
- userId: References user_profiles.id
- raceDate: Target race date
- raceDistance: 5k/10k/half_marathon/marathon/50k/etc.
- trainingVolume: low/moderate/high
- planData: JSON with full carb loading plan
```

#### carb_loading_days (Local-Only)
Individual day entries within a carb loading plan with detailed tracking:
```sql
- id: UUID (primary key)
- carb_loading_plan_id: References carb_loading_plans.id
- plan_date: Date for this carb loading day
- day_number: Sequence number (1, 2, 3, etc.)
- carb_target_grams: Daily carb target in grams
- carb_protocol_g_per_kg: Carb protocol formula (e.g., 8.0 for 8g/kg bodyweight)
  * Enables UI to display "8g/kg bodyweight" instead of just "610g carbs target"
  * Provides context for the absolute gram target
- calorie_target: Daily calorie target (optional)
- meal_count: Number of meals (default: 6)
- Meal distribution percentages: breakfast, morning_snack, lunch, afternoon_snack, dinner, evening_snack
- Progress tracking: logged_carbs_grams, logged_calories, completed
```

## Enum Constraints

The database enforces several enum constraints:

```sql
-- Gender
CHECK (gender IN ('male', 'female', 'other'))

-- Gut Training Level
CHECK (gut_training_level IN ('low', 'moderate', 'high'))

-- Food Preferences
CHECK (preference IN ('like', 'dislike', 'willing_to_try'))

-- Feedback Types
CHECK (feedback_type IN ('survey', 'plan_rating', 'general'))

-- Categories
CHECK (name IN ('before_run', 'during_run', 'after_run'))

-- Race Distances
CHECK (raceDistance IN ('5k', '10k', 'half_marathon', 'marathon', '50k', '50mi', '100k', '100mi'))

-- Training Volume
CHECK (trainingVolume IN ('low', 'moderate', 'high'))
```

## Indexes

Performance indexes are created for:
- Foreign key columns (`device_id`, `userId`, `product_type_id`)
- Frequently queried columns (`created_at`, `synced`, `barcode`)
- Junction table lookups

## Synchronization and Versioning

### Repository-Level Sync Strategy

The database uses a **repository-level sync** approach instead of syncing all data at app startup:

**Staleness Tracking:**
- Each repository tracks its last sync time in SharedPreferences
- Key pattern: `{repositoryKey}_last_sync` (e.g., `activities_last_sync`)
- Staleness threshold: 24 hours (configurable per repository)
- Controllers call `ensureSynced()` before querying data

**Why SharedPreferences for Timestamps?**
- Persists across database resyncs (when local DB is deleted)
- Lightweight and fast to access
- Survives app restarts
- Doesn't pollute database schema with sync metadata

**Dependency Resolution:**
Repositories declare dependencies for automatic sync ordering:
```dart
// Example: Activities repository
@override
String get repositoryKey => 'activities';

@override
List<String> get dependencies => ['users']; // Sync users first
```

**Dirty Record Tracking:**
- Upload dirty records BEFORE downloading fresh data
- Prevents data loss during schema migrations
- Each repository manages its own dirty flag handling

### Server-Side Version Control

The app uses `app_config` table in Supabase to control versioning and migrations:

**Schema Version Checking:**
1. App reads `current_schema_version` from app_config table
2. Compares with local Drift `schemaVersion` property
3. If mismatch:
   - App uploads dirty records (protect user data)
   - App deletes local SQLite database
   - App recreates fresh database (onCreate runs)
   - App downloads all data from Supabase
4. If match: Normal operation continues

**Benefits:**
- Server controls when schema migrations happen
- No complex step-by-step Drift migrations
- Simple rollback: delete DB and resync
- Dirty records always uploaded first (no data loss)

**Configuration Keys:**
- `min_app_version`: Force app updates for breaking changes
- `current_schema_version`: Server's expected schema version
- `maintenance_mode`: Block syncs during backend maintenance
- `force_resync_before`: Force resync for specific app versions

## Migration Strategy

### Current Implementation (v2)
Schema version 2 with **simplified migration strategy**:
- **No step-by-step migrations**: Server-controlled version checks replace complex Drift migrations
- **Delete and resync**: When schema mismatch detected, local DB is deleted and recreated
- **Dirty record backup**: User changes are uploaded before database deletion
- V1 baseline is preserved for reference

**V2 Migration Details (December 2025)**:
- **Migration Type**: Idempotent with column existence checks
- **Key Changes**: Consolidated preference_level, dietary_preference, and allergies columns
- **Rollback Strategy**: Simple - delete local DB and resync from Supabase if migration fails
- **Migration File**: See `app_database.dart` onUpgrade method

**Previous Schema (V1 - October 2025)**:
- Baseline with 27 tables
- Used runtime column additions in beforeOpen hook (deprecated approach)
- Preserved in `/database_schemas/v1/` for reference

### Schema Files
- **SQL Documentation**: `/docs/database/drift/schema.sql` - Human-readable DDL
- **V2 Drift Schema Snapshot**: `/database_schemas/v2/drift_schema_v2.json` - Current version
- **V1 Drift Schema Snapshot**: `/database_schemas/v1/drift_schema_v1.json` - Baseline (preserved)
- **Generation Command**: `dart run drift_dev schema dump lib/shared/database/app_database.dart database_schemas/v2/`

### How Migrations Work in Drift

#### App Startup Process
1. App launches and initializes database in `appStartupProvider`
2. Drift checks `schemaVersion` property in `AppDatabase` (currently 1)
3. Compares with version stored in SQLite `user_version` pragma
4. If versions differ, runs `onUpgrade` callback
5. If fresh install, runs `onCreate` callback

#### Migration Code Structure
```dart
@DriftDatabase(tables: [...])
class AppDatabase extends _$AppDatabase {
  @override
  int get schemaVersion => 2; // Current version (was 1)

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll(); // Fresh install
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // V1 to V2 migration
      if (from < 2) {
        // Idempotent migration with column checks
        await _migrateV1ToV2(m);
      }
    },
  );
}
```

### Step-by-Step Migration Guide (v2 → v3 Example)

#### Step 1: Before Making Changes
```bash
# Ensure v2 snapshot exists (already done)
ls database_schemas/v2/drift_schema_v2.json
```

#### Step 2: Modify Your Tables
```dart
// Example: Add new column to existing table
class UsersTable extends Table {
  // ... existing columns ...
  TextColumn get newField => text().nullable()(); // New column
}

// Or add entirely new table
class NewFeatureTable extends Table {
  TextColumn get id => text()();
  // ... other columns ...
}
```

#### Step 3: Update Schema Version
```dart
// In app_database.dart
@override
int get schemaVersion => 3; // Increment from 2 to 3
```

#### Step 4: Generate v3 Snapshot
```bash
# Generate new schema snapshot
dart run drift_dev schema dump lib/shared/database/app_database.dart database_schemas/v3/
```

#### Step 5: Generate Migration Code
```bash
# Compare v2 and v3 to generate migration steps
dart run drift_dev schema steps database_schemas/v2/drift_schema_v2.json database_schemas/v3/drift_schema_v3.json

# This outputs migration code you can use
```

#### Step 6: Implement Migration (Idempotent Pattern)
```dart
@override
MigrationStrategy get migration => MigrationStrategy(
  onCreate: (Migrator m) async {
    await m.createAll();
  },
  onUpgrade: (Migrator m, int from, int to) async {
    if (from < 2) {
      await _migrateV1ToV2(m);
    }
    if (from < 3) {
      // New v2 to v3 migration
      // Use idempotent pattern - check if column exists first
      final result = await customSelect(
        "PRAGMA table_info(users)"
      ).get();

      final hasNewField = result.any((row) => row.data['name'] == 'new_field');

      if (!hasNewField) {
        await m.addColumn(userProfilesTable, userProfilesTable.newField);
      }

      // Create new table if it doesn't exist
      await m.createTable(newFeatureTable);

      // Run custom SQL if needed
      await customStatement('UPDATE users SET new_field = "default" WHERE new_field IS NULL');
    }
  },
);
```

### Migration Best Practices

#### Safe Migrations
- ✅ Adding nullable columns with idempotent checks
- ✅ Adding new tables
- ✅ Adding indexes
- ✅ Removing constraints
- ✅ Using PRAGMA table_info to check column existence

#### Risky Migrations (Require Care)
- ⚠️ Adding non-nullable columns (provide defaults + check existence first)
- ⚠️ Changing column types (may lose data)
- ⚠️ Renaming columns (use ALTER TABLE + check existence)
- ⚠️ Removing columns (data loss - consider soft deletes instead)

#### Idempotent Migration Pattern (RECOMMENDED)
```dart
// Always check if changes already exist before applying
Future<void> _migrateV2ToV3(Migrator m) async {
  // Check column existence
  final result = await customSelect("PRAGMA table_info(users)").get();
  final hasColumn = result.any((row) => row.data['name'] == 'new_column');

  if (!hasColumn) {
    await m.addColumn(usersTable, usersTable.newColumn);
  }

  // For tables, catch exceptions if table already exists
  try {
    await m.createTable(newTable);
  } catch (e) {
    // Table might already exist from failed previous migration
    print('Table may already exist: $e');
  }
}
```

#### Simple Rollback Strategy
If migration fails:
1. Delete the local database file
2. Restart the app
3. Database will be recreated from scratch
4. Sync from Supabase to restore user data

#### Testing Migrations
```dart
// test/database/migration_test.dart
void main() {
  test('v1 to v2 migration', () async {
    // Create v1 database
    final v1Db = AppDatabase.memory();

    // Insert test data
    await v1Db.insertUser(...);

    // Run migration
    await v1Db.close();
    final v2Db = AppDatabase.memory();

    // Verify data preserved
    final users = await v2Db.getAllUsers();
    expect(users, isNotEmpty);
  });
}
```

### Common Migration Scenarios

#### Adding a Column
```dart
await m.addColumn(tableName, tableName.newColumn);
```

#### Creating a Table
```dart
await m.createTable(newTable);
```

#### Renaming a Column
```dart
await customStatement('ALTER TABLE old_name RENAME TO new_name');
```

#### Data Migration
```dart
// Move data from old structure to new
await customStatement('''
  INSERT INTO new_table (id, data)
  SELECT id, json_extract(old_data, '$.field')
  FROM old_table
''');
```

## Usage Examples

### Accessing the Database
```dart
final db = ref.read(appDatabaseProvider);
```

### Common Operations
```dart
// Get current user
final user = await db.getCurrentUserProfile();

// Save food preferences
await db.saveFoodPreferences(deviceId, preferences);

// Get latest nutrition plan
final plan = await db.getLatestNutritionPlan(deviceId);

// Add workout note
await db.insertWorkoutNote(WorkoutNoteEntry(...));
```

## Data Type Mappings

| SQLite Type | Drift Type | Dart Type |
|-------------|------------|-----------|
| TEXT | TextColumn | String |
| INTEGER | IntColumn | int |
| REAL | RealColumn | double |
| INTEGER (0/1) | BoolColumn | bool |
| TEXT (ISO 8601) | DateTimeColumn | DateTime |

## Best Practices

1. **Always use device_id for new user-related tables**
2. **Store complex data as JSON in TEXT columns**
3. **Use soft deletes for synced data**
4. **Include created_at/updated_at timestamps**
5. **Add CHECK constraints for data validation**
6. **Create indexes for foreign keys and frequently queried columns**

## App Startup & Database Initialization

### What Happens When the App Starts

1. **Main Entry Point** (`main.dart`)
   - Initializes Supabase and other non-recoverable services
   - Does NOT initialize the database here

2. **App Startup Widget** (`app_startup_widget.dart`)
   - Calls `appStartupProvider` which handles database initialization
   - Shows loading screen during initialization

3. **Database Initialization** (`app_startup_service.dart`)
   ```dart
   // Database is initialized here
   final db = AppDatabase();
   ```

4. **Drift Schema Check**
   - Reads `schemaVersion` from `AppDatabase` (currently 1)
   - Checks SQLite's `user_version` pragma
   - **First Install**: Runs `onCreate` → Creates all 26 tables
   - **Existing Install**: If versions match, opens normally
   - **After Update**: If version increased, runs `onUpgrade`

5. **Database Ready**
   - App continues to main screens
   - Database available via `appDatabaseProvider`

### Performance Considerations
- Initial table creation (26 tables) takes < 100ms
- Future migrations should complete < 1 second
- Heavy migrations should show progress indicator

## Related Documentation

- [Database Overview](/docs/database/README.md) - Dual database architecture
- [Supabase Schema](/docs/database/supabase/README.md) - Cloud database structure
- [Complete Schema SQL](schema.sql) - Full DDL for all 26 tables
- [App Database Class](/lib/shared/database/app_database.dart) - Drift implementation
- [Migration Testing](/docs/test/roadmap.md) - Schema migration test strategy
- [CLAUDE.md](/CLAUDE.md) - Primary AI assistant context with migration commands
