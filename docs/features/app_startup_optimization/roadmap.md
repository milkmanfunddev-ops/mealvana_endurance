# App Startup Optimization Roadmap

**Goal**: Reduce app startup time and logging noise by consolidating 7 network calls into 1 unified sync operation and removing excessive logging.

**Expected Impact**:
- Startup sync time: ~1.5s → ~0.3-0.5s (70% faster)
- Log output: ~60+ lines → ~4-6 lines (90% reduction)
- Network round trips: 7 → 1 (86% reduction)
- Improved user experience with faster cold starts

---

## Current State Analysis

### Network Calls During Startup (7 total)
1. `get-foods` edge function (21 foods)
2. `get-carb-loading-foods` edge function (27 foods + 7 meal types)
3. Direct query: `activities` table
4. Direct query: `events` table
5. Direct query: `carb_loading_plans` table
6. Direct query: `carb_loading_days` table
7. Direct query: `activity_completions` table *(removed in Nov 2025; completion metadata now rides with each `activities` row. References to this query remain for historical context and will be cleaned up in the final doc pass.)*

### Logging Issues
- **60+ log lines** during startup with excessive noise:
  - Stack traces on every log (not just errors)
  - Debug logs for routine operations
  - Duplicate messages ("Calendar data sync completed" x2)
  - Verbose debugging (8+ logs for finding one event)

### Code Locations
- Startup orchestration: `lib/features/app_startup/application/app_startup_service.dart`
- Calendar sync: `lib/features/calendar/application/calendar_sync_service.dart`
- Carb loading sync: `lib/features/carb_loading/application/carb_loading_food_sync_service.dart`
- Food sync: `lib/features/nutrition_plan/data/food_repository.dart`
- Logging service: `lib/shared/services/logging_service.dart`

---

## Implementation Plan

### Phase 1: Create Unified Sync Edge Function

**Estimated Time**: 2-3 hours

#### Step 1.1: Create the Sync Edge Function
**File**: `supabase/functions/sync/index.ts`

**Implementation**:
```typescript
import { serve } from 'https://deno.land/std@0.131.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.38.4';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! },
        },
      }
    );

    const { user_id } = await req.json();

    // Execute all queries in parallel for maximum speed
    const [
      foodsResult,
      carbLoadingFoodsResult,
      mealTypesResult,
      activitiesResult,
      eventsResult,
      carbLoadingPlansResult,
      carbLoadingDaysResult,
      activityCompletionsResult,
    ] = await Promise.all([
      // Public data (no authentication needed)
      fetchFoods(supabaseClient),
      fetchCarbLoadingFoods(supabaseClient),
      fetchMealTypes(supabaseClient),

      // User data (conditional on user_id)
      user_id ? fetchActivities(supabaseClient, user_id) : Promise.resolve([]),
      user_id ? fetchEvents(supabaseClient, user_id) : Promise.resolve([]),
      user_id ? fetchCarbLoadingPlans(supabaseClient, user_id) : Promise.resolve([]),
      user_id ? fetchCarbLoadingDays(supabaseClient, user_id) : Promise.resolve([]),
      user_id ? fetchActivityCompletions(supabaseClient, user_id) : Promise.resolve([]),
    ]);

    return new Response(
      JSON.stringify({
        foods: foodsResult,
        carb_loading: {
          foods: carbLoadingFoodsResult,
          meal_types: mealTypesResult,
        },
        user_data: user_id ? {
          activities: activitiesResult,
          events: eventsResult,
          carb_loading_plans: carbLoadingPlansResult,
          carb_loading_days: carbLoadingDaysResult,
          activity_completions: activityCompletionsResult,
        } : null,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    );
  } catch (error) {
    console.error('Sync error:', error);
    return new Response(
      JSON.stringify({
        error: error instanceof Error ? error.message : 'Unknown error'
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      }
    );
  }
});

// Helper functions
async function fetchFoods(client: any) {
  const { data, error } = await client
    .from('foods')
    .select(`
      *,
      food_categories!inner(category_id),
      categories!inner(*)
    `);

  if (error) throw error;

  // Include essential foods
  const { data: essentialData } = await client
    .from('foods')
    .select('*')
    .eq('is_essential', true);

  // Deduplicate
  const foodsMap = new Map();
  for (const food of [...(data || []), ...(essentialData || [])]) {
    if (!foodsMap.has(food.id)) {
      foodsMap.set(food.id, {
        id: food.id,
        name: food.name,
        display_name: food.display_name,
        display_name_plural: food.display_name_plural,
        image_address: food.image_address,
        description: food.description,
        instructions: food.instructions,
        carbs_per_serving: food.carbs_per_serving || 0,
        sodium_mg: food.sodium_mg || 0,
        fluid_ml_per_serving: food.fluid_ml_per_serving || 0,
        calories_per_serving: food.calories_per_serving || 0,
        protein_per_serving: food.protein_per_serving || 0,
        fat_per_serving: food.fat_per_serving || 0,
        serving_amount: food.serving_amount || 1.0,
        before_run_suitable: food.before_run_suitable,
        during_run_suitable: food.during_run_suitable,
        run_portable: food.run_portable,
        requires_preparation: food.requires_preparation,
        aid_station_available: food.aid_station_available,
        max_servings_before: food.max_servings_before,
        max_servings_during: food.max_servings_during,
        caffeine_mg: food.caffeine_mg,
        potassium_mg: food.potassium_mg,
        show_in_preferences: food.show_in_preferences,
        is_electrolyte: food.is_electrolyte,
        to_exclude_from_solver: food.to_exclude_from_solver,
        created_at: food.created_at,
      });
    }
  }

  return Array.from(foodsMap.values());
}

async function fetchCarbLoadingFoods(client: any) {
  const { data, error } = await client
    .from('carb_loading_foods')
    .select(`
      *,
      carb_loading_food_meal_types!inner(meal_type_id)
    `);

  if (error) throw error;

  return (data || []).map((food: any) => ({
    id: food.id,
    name: food.name,
    display_name: food.display_name,
    display_name_plural: food.display_name_plural,
    carbs_per_serving: food.carbs_per_serving,
    image_address: food.image_address || '',
    is_default: food.is_default,
    created_at: food.created_at,
    meal_type_ids: food.carb_loading_food_meal_types?.map((mt: any) => mt.meal_type_id) || [],
  }));
}

async function fetchMealTypes(client: any) {
  const { data, error } = await client
    .from('meal_types')
    .select('*')
    .order('id', { ascending: true });

  if (error) throw error;
  return data || [];
}

async function fetchActivities(client: any, userId: string) {
  const { data, error } = await client
    .from('activities')
    .select()
    .eq('user_id', userId)
    .isFilter('deleted_at', null)
    .order('scheduled_date_time', { ascending: false });

  if (error) throw error;
  return data || [];
}

async function fetchEvents(client: any, userId: string) {
  const { data, error } = await client
    .from('events')
    .select()
    .order('created_at', { ascending: false });

  if (error) throw error;
  return data || [];
}

async function fetchCarbLoadingPlans(client: any, userId: string) {
  const { data, error } = await client
    .from('carb_loading_plans')
    .select()
    .eq('user_id', userId)
    .order('generated_at', { ascending: false });

  if (error) throw error;
  return data || [];
}

async function fetchCarbLoadingDays(client: any, userId: string) {
  const { data, error } = await client
    .from('carb_loading_days')
    .select(`
      *,
      carb_loading_plans!inner(user_id)
    `)
    .eq('carb_loading_plans.user_id', userId)
    .order('plan_date', { ascending: true });

  if (error) throw error;
  return data || [];
}

async function fetchActivityCompletions(client: any, userId: string) {
  const { data, error } = await client
    .from('activity_completions')
    .select()
    .eq('user_id', userId)
    .order('completed_at', { ascending: false });

  if (error) throw error;
  return data || [];
}
```

**Testing**:
```bash
# Deploy the function
supabase functions deploy sync

# Test locally
deno run --allow-all supabase/functions/sync/index.ts

# Test with curl
curl -X POST 'https://YOUR_PROJECT.supabase.co/functions/v1/sync' \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -d '{"user_id": null}'
```

---

### Phase 2: Update Client-Side Sync Service

**Estimated Time**: 2-3 hours

#### Step 2.1: Create Unified Sync Service
**File**: `lib/features/app_startup/application/unified_sync_service.dart`

```dart
import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/logging_service.dart';

part 'unified_sync_service.g.dart';

@riverpod
UnifiedSyncService unifiedSyncService(Ref ref) {
  return UnifiedSyncService(
    supabase: Supabase.instance.client,
    database: ref.read(appDatabaseProvider),
    logger: ref.read(appLoggerProvider),
  );
}

/// Unified sync service that calls a single edge function
/// Replaces multiple individual sync operations
class UnifiedSyncService {
  const UnifiedSyncService({
    required SupabaseClient supabase,
    required AppDatabase database,
    required AppLogger logger,
  })  : _supabase = supabase,
        _database = database,
        _logger = logger;

  final SupabaseClient _supabase;
  final AppDatabase _database;
  final AppLogger _logger;

  /// Sync all data from Supabase in a single call
  Future<void> syncAllData() async {
    try {
      // Get user ID if available
      final user = await _database.getCurrentUserProfile();
      final userId = user?.id;

      // Call unified sync edge function
      final response = await _supabase.functions.invoke(
        'sync',
        body: {'user_id': userId},
      );

      if (response.status != 200) {
        throw Exception(
          'Sync failed: ${response.data?['error'] ?? 'Unknown error'}',
        );
      }

      final data = response.data;
      if (data == null) {
        throw Exception('Invalid sync response');
      }

      // Sync all data to local database in parallel
      await Future.wait([
        _syncFoods(data['foods'] as List<dynamic>),
        _syncCarbLoadingData(data['carb_loading'] as Map<String, dynamic>),
        if (data['user_data'] != null)
          _syncUserData(data['user_data'] as Map<String, dynamic>),
      ]);

    } catch (e, stackTrace) {
      _logger.error(
        'Sync failed',
        error: e,
        stackTrace: stackTrace,
      );
      // Don't rethrow - app continues with cached data
    }
  }

  Future<void> _syncFoods(List<dynamic> foodsData) async {
    if (foodsData.isEmpty) return;

    await _database.batch((batch) {
      for (final foodJson in foodsData) {
        final food = FoodsTableCompanion.insert(
          id: foodJson['id'] as String,
          name: foodJson['name'] as String,
          displayName: foodJson['display_name'] as String,
          displayNamePlural: Value(foodJson['display_name_plural'] as String?),
          imageAddress: Value(foodJson['image_address'] as String?),
          description: Value(foodJson['description'] as String?),
          instructions: Value(foodJson['instructions'] as String?),
          carbsPerServing: Value(foodJson['carbs_per_serving'] as double?),
          sodiumMg: Value(foodJson['sodium_mg'] as double?),
          fluidMlPerServing: Value(foodJson['fluid_ml_per_serving'] as double?),
          caloriesPerServing: Value(foodJson['calories_per_serving'] as double?),
          proteinPerServing: Value(foodJson['protein_per_serving'] as double?),
          fatPerServing: Value(foodJson['fat_per_serving'] as double?),
          servingAmount: Value(foodJson['serving_amount'] as double?),
          beforeRunSuitable: Value(foodJson['before_run_suitable'] as bool?),
          duringRunSuitable: Value(foodJson['during_run_suitable'] as bool?),
          runPortable: Value(foodJson['run_portable'] as bool?),
          requiresPreparation: Value(foodJson['requires_preparation'] as bool?),
          aidStationAvailable: Value(foodJson['aid_station_available'] as bool?),
          maxServingsBefore: Value(foodJson['max_servings_before'] as int?),
          maxServingsDuring: Value(foodJson['max_servings_during'] as int?),
          caffeineMg: Value(foodJson['caffeine_mg'] as double?),
          potassiumMg: Value(foodJson['potassium_mg'] as double?),
          showInPreferences: Value(foodJson['show_in_preferences'] as bool?),
          isElectrolyte: Value(foodJson['is_electrolyte'] as bool?),
          toExcludeFromSolver: Value(foodJson['to_exclude_from_solver'] as bool?),
          createdAt: Value(DateTime.parse(foodJson['created_at'] as String)),
        );

        batch.insert(
          _database.foodsTable,
          food,
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  Future<void> _syncCarbLoadingData(Map<String, dynamic> carbLoadingData) async {
    final foods = carbLoadingData['foods'] as List<dynamic>;
    final mealTypes = carbLoadingData['meal_types'] as List<dynamic>;

    await Future.wait([
      _syncMealTypes(mealTypes),
      _syncCarbLoadingFoods(foods),
    ]);
  }

  Future<void> _syncMealTypes(List<dynamic> mealTypesData) async {
    if (mealTypesData.isEmpty) return;

    await _database.batch((batch) {
      for (final mealTypeJson in mealTypesData) {
        final mealType = MealTypesTableCompanion.insert(
          id: Value(mealTypeJson['id'] as int),
          name: mealTypeJson['name'] as String,
          displayName: mealTypeJson['display_name'] as String,
        );

        batch.insert(
          _database.mealTypesTable,
          mealType,
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  Future<void> _syncCarbLoadingFoods(List<dynamic> foodsData) async {
    if (foodsData.isEmpty) return;

    await _database.batch((batch) {
      for (final foodJson in foodsData) {
        final foodId = foodJson['id'] as String;

        final food = CarbLoadingFoodsTableCompanion.insert(
          id: foodId,
          name: foodJson['name'] as String,
          displayName: foodJson['display_name'] as String,
          displayNamePlural: Value(foodJson['display_name_plural'] as String?),
          carbsPerServing: (foodJson['carbs_per_serving'] as num).toDouble(),
          imageAddress: Value(foodJson['image_address'] as String? ?? ''),
          isDefault: Value(foodJson['is_default'] as bool? ?? true),
          createdAt: Value(DateTime.parse(foodJson['created_at'] as String)),
        );

        batch.insert(
          _database.carbLoadingFoodsTable,
          food,
          mode: InsertMode.insertOrReplace,
        );

        // Sync meal type associations
        final mealTypeIds = foodJson['meal_type_ids'] as List<dynamic>? ?? [];
        for (final mealTypeId in mealTypeIds) {
          final association = CarbLoadingFoodMealTypesTableCompanion.insert(
            carbLoadingFoodId: foodId,
            mealTypeId: mealTypeId as int,
          );

          batch.insert(
            _database.carbLoadingFoodMealTypesTable,
            association,
            mode: InsertMode.insertOrReplace,
          );
        }
      }
    });
  }

  Future<void> _syncUserData(Map<String, dynamic> userData) async {
    await Future.wait([
      _syncActivities(userData['activities'] as List<dynamic>),
      _syncEvents(userData['events'] as List<dynamic>),
      _syncCarbLoadingPlans(userData['carb_loading_plans'] as List<dynamic>),
      _syncCarbLoadingDays(userData['carb_loading_days'] as List<dynamic>),
      _syncActivityCompletions(userData['activity_completions'] as List<dynamic>),
    ]);
  }

  // Copy the upsert methods from CalendarSyncService
  Future<void> _syncActivities(List<dynamic> activitiesData) async {
    // Implementation from CalendarSyncService._syncActivities
    // ... (copy the logic)
  }

  Future<void> _syncEvents(List<dynamic> eventsData) async {
    // Implementation from CalendarSyncService._syncEvents
    // ... (copy the logic)
  }

  Future<void> _syncCarbLoadingPlans(List<dynamic> plansData) async {
    // Implementation from CalendarSyncService._syncCarbLoadingPlans
    // ... (copy the logic)
  }

  Future<void> _syncCarbLoadingDays(List<dynamic> daysData) async {
    // Implementation from CalendarSyncService._syncCarbLoadingDays
    // ... (copy the logic)
  }

  Future<void> _syncActivityCompletions(List<dynamic> completionsData) async {
    // Implementation from CalendarSyncService._syncActivityCompletions
    // ... (copy the logic)
  }
}
```

#### Step 2.2: Update AppStartupService
**File**: `lib/features/app_startup/application/app_startup_service.dart`

Replace these three methods:
```dart
// DELETE THESE:
Future<void> checkAndRefreshFoodData() async { ... }
Future<void> syncCalendarData() async { ... }

// REPLACE WITH:
/// Sync all data from Supabase using unified sync service
Future<void> syncAllData() async {
  try {
    final syncService = ref.read(unifiedSyncServiceProvider);
    await syncService.syncAllData();
  } catch (e, stackTrace) {
    _logger.error(
      'Data sync failed',
      error: e,
      stackTrace: stackTrace,
    );
    // Don't throw - app continues with cached data
  }
}
```

#### Step 2.3: Update App Startup Provider
**File**: `lib/features/app_startup/application/app_startup_provider.dart`

Update the `onAppStart` method to use the new unified sync:

```dart
@override
Future<void> build() async {
  // ... existing code ...

  // REPLACE multiple sync calls with single call:
  await _appStartupService.syncAllData();  // Instead of checkAndRefreshFoodData() and syncCalendarData()

  // ... rest of existing code ...
}
```

---

### Phase 3: Logging Cleanup

**Estimated Time**: 1-2 hours

#### Step 3.1: Update Logging Service
**File**: `lib/shared/services/logging_service.dart`

Remove stack traces from info/debug logs:

```dart
// Find the _logWithContext method and update it:
void _logWithContext(
  String message,
  LogLevel level, {
  String? context,
  Object? error,
  StackTrace? stackTrace,
  Map<String, dynamic>? data,
}) {
  // ONLY include stack trace for ERROR level
  final shouldIncludeStackTrace = level == LogLevel.error && stackTrace != null;

  // Build the log message
  final buffer = StringBuffer();

  // Level emoji and message
  buffer.writeln('${_getLevelEmoji(level)} $message');

  // Context if provided
  if (context != null) {
    buffer.writeln('Context: $context');
  }

  // Data if provided
  if (data != null && data.isNotEmpty) {
    buffer.writeln('Data: $data');
  }

  // Error if provided
  if (error != null) {
    buffer.writeln('Error: $error');
  }

  // Stack trace ONLY for errors
  if (shouldIncludeStackTrace) {
    buffer.writeln('Stack trace:');
    buffer.writeln(stackTrace.toString());
  }

  // Print the log
  developer.log(
    buffer.toString(),
    name: _loggerName,
    level: _getLogLevel(level),
  );
}
```

#### Step 3.2: Remove Debug Logs from Repositories

**Files to update**:
1. `lib/features/nutrition_plan/data/food_repository.dart`
2. `lib/features/calendar/application/calendar_sync_service.dart`
3. `lib/features/carb_loading/application/carb_loading_food_sync_service.dart`

**Pattern**: Remove all `_logger.debug()` calls except for error cases.

**Example for FoodRepository**:
```dart
// REMOVE:
_logger.debug('Loaded ${localFoods.length} foods from local database (offline-first)');
_logger.debug('Local database empty, fetching foods from Supabase');
_logger.warning('Returning local foods after error');

// KEEP ONLY:
_logger.error('Error loading foods', context: 'FoodRepository', error: e);
```

#### Step 3.3: Simplify Calendar Service Logs

**File**: `lib/features/calendar/application/calendar_service.dart`

Remove the excessive `nextUpcomingEventFromDate` debug logs (lines 145-201 in your logs).

Find the method and remove all debug logs:
```dart
// REMOVE all these debug logs:
_logger.debug('nextUpcomingEventFromDate: Found X total events...');
_logger.debug('nextUpcomingEventFromDate: Processing event...');
_logger.debug('nextUpcomingEventFromDate: Using event.startTime...');
// etc.
```

#### Step 3.4: Update AppStartupService Logs

**File**: `lib/features/app_startup/application/app_startup_service.dart`

Keep only critical info logs:

```dart
// Keep these INFO logs:
_logger.info('App startup beginning');
_logger.info('Database initialized');
_logger.info('Sync completed successfully');

// Remove all DEBUG logs
// Remove duplicate INFO logs
```

#### Step 3.5: Update UnifiedSyncService Logs

**File**: `lib/features/app_startup/application/unified_sync_service.dart`

```dart
Future<void> syncAllData() async {
  try {
    final user = await _database.getCurrentUserProfile();
    final userId = user?.id;

    final response = await _supabase.functions.invoke(
      'sync',
      body: {'user_id': userId},
    );

    if (response.status != 200) {
      throw Exception(
        'Sync failed: ${response.data?['error'] ?? 'Unknown error'}',
      );
    }

    final data = response.data;
    if (data == null) {
      throw Exception('Invalid sync response');
    }

    await Future.wait([
      _syncFoods(data['foods'] as List<dynamic>),
      _syncCarbLoadingData(data['carb_loading'] as Map<String, dynamic>),
      if (data['user_data'] != null)
        _syncUserData(data['user_data'] as Map<String, dynamic>),
    ]);

    // ONLY log on success - no debug logs
    _logger.info('Sync completed successfully');

  } catch (e, stackTrace) {
    // ONLY log errors
    _logger.error(
      'Sync failed',
      error: e,
      stackTrace: stackTrace,
    );
  }
}
```

---

### Phase 4: Testing & Validation

**Estimated Time**: 2-3 hours

#### Step 4.1: Unit Tests
Create test file: `test/features/app_startup/unified_sync_service_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UnifiedSyncService', () {
    test('syncAllData fetches and syncs all data successfully', () async {
      // Test implementation
    });

    test('syncAllData handles errors gracefully', () async {
      // Test implementation
    });

    test('syncAllData works without user_id (anonymous)', () async {
      // Test implementation
    });
  });
}
```

#### Step 4.2: Integration Tests
1. Test cold start with empty database
2. Test warm start with cached data
3. Test sync failure with network error
4. Test sync with partial data

#### Step 4.3: Performance Validation
Measure and compare:
- **Before**: Time from app launch to sync complete
- **After**: Time from app launch to sync complete
- **Expected**: 70% reduction (1.5s → 0.3-0.5s)

#### Step 4.4: Log Validation
Compare log output:
- **Before**: ~60 lines during startup
- **After**: ~4-6 lines during startup
- **Expected**: 90% reduction

Expected log output after changes:
```
flutter: 💡 App startup beginning
flutter: 💡 Database initialized
flutter: 💡 Sync completed successfully
flutter: 💡 App ready
```

---

### Phase 5: Cleanup & Deprecation

**Estimated Time**: 2-3 hours

#### Step 5.1: Deprecate Old Client Services
Mark as deprecated but don't delete yet:
```dart
@Deprecated('Use UnifiedSyncService instead')
class CalendarSyncService { ... }

@Deprecated('Use UnifiedSyncService instead')
class CarbLoadingFoodSyncService { ... }
```

#### Step 5.2: Keep Edge Functions as Fallbacks

**IMPORTANT**: The unified `sync` edge function handles READ operations during startup, but we must KEEP the old GET functions as fallbacks in case something happens to the foods data.

**Edge Functions to KEEP as Fallbacks**:
1. ✅ `get-foods` - Keep as fallback for food data recovery
2. ✅ `get-carb-loading-foods` - Keep as fallback for carb loading data recovery

**Edge Functions to KEEP** (these serve different purposes):

**Read Operations** (fallback/recovery functions):
- ✅ `get-foods` - Fallback for food data recovery
- ✅ `get-carb-loading-foods` - Fallback for carb loading data recovery

**Write Operations** (user-initiated actions):
- ✅ `save-calendar-activity` - User creates/updates/deletes activities
- ✅ `save-calendar-event` - User creates/updates/deletes events
- ✅ `save-user-food` - User adds custom foods
- ✅ `save-food-preferences` - User updates food preferences
- ✅ `save-carb-loading-plan` - User creates carb loading plans
- ✅ `save-activity-completion` - User logs activity completions
- ✅ `delete-user-food` - User deletes custom foods

**Business Logic** (computation-heavy operations):
- ✅ `generate-nutrition-plan` - AI/algorithm for nutrition plan generation
- ✅ `generate-macros` - Macro calculation algorithms
- ✅ `create-nutrition-plan` - Creates nutrition plans with validation
- ✅ `create-user` - User registration with device validation

**External APIs** (third-party integrations):
- ✅ `lookup-product` - Barcode product lookup
- ✅ `barcode-lookup` - Alternative barcode lookup
- ✅ `get-weather-forecast` - Weather API integration
- ✅ `send-nutrition-plan-email` - Email sending service

**Usage Pattern**:

The GET functions will remain deployed but only be called as fallbacks:

1. **Primary Path** (99% of cases):
   - App startup calls `sync()` edge function
   - Gets all data in one call
   - Fast and efficient

2. **Fallback Path** (1% of cases - when food data is corrupted/missing):
   - User manually refreshes food data from settings
   - User reports missing foods
   - Developer triggers re-sync after database issue
   - Call `get-foods()` or `get-carb-loading-foods()` individually

**Implementation Example**:
```dart
// In FoodRepository
Future<void> refreshFoodsFromSupabase() async {
  try {
    // Fallback: call get-foods directly
    final response = await _supabase.functions.invoke('get-foods', body: {
      'category': null,
      'generic_only': false,
    });

    if (response.status == 200) {
      final data = response.data;
      await _syncFoodsToLocalDatabase(data['foods'] as List<dynamic>);
    }
  } catch (e) {
    _logger.error('Failed to refresh foods', error: e);
    rethrow;
  }
}
```

**When to Use Fallback Functions**:
- User reports missing or incorrect food data
- Database corruption detected
- Manual "Refresh Food Data" button in settings
- Developer tools for troubleshooting
- After app reinstall if sync fails

#### Step 5.3: Update Documentation
Update these files with new sync architecture:

**Technical Documentation**:
- `docs/technical/README.md` - Document unified sync pattern
- `docs/database/README.md` - Update sync strategy section
- `CLAUDE.md` - Update architecture overview with new sync flow

**Edge Functions Documentation**:
Create `docs/technical/edge-functions-architecture.md`:

```markdown
# Edge Functions Architecture

## Sync Operations

### Unified Sync Function
- **Function**: `sync`
- **Purpose**: Single endpoint for all read-only data synchronization
- **Called**: Once during app startup
- **Returns**: All foods, carb loading data, and user-specific data

## Write Operations

### Calendar Management
- `save-calendar-activity` - Create/update/delete activities
- `save-calendar-event` - Create/update/delete events
- `save-activity-completion` - Log activity completion data
- `save-carb-loading-plan` - Create carb loading plans

### Food Management
- `save-user-food` - Add custom foods
- `delete-user-food` - Remove custom foods
- `save-food-preferences` - Update liked/disliked foods

### Nutrition Planning
- `generate-nutrition-plan` - AI-powered nutrition plan generation
- `generate-macros` - Calculate macro targets
- `create-nutrition-plan` - Create and validate nutrition plans

### External Integrations
- `barcode-lookup` / `lookup-product` - Product barcode scanning
- `get-weather-forecast` - Weather data for activities
- `send-nutrition-plan-email` - Share plans via email

### User Management
- `create-user` - User registration and device validation

## Fallback Functions

The following functions remain deployed as fallbacks for data recovery:
- ✅ `get-foods` - Use for manual food data refresh
- ✅ `get-carb-loading-foods` - Use for manual carb loading data refresh

**Note**: These are kept for recovery scenarios but not called during normal app startup.
```

#### Step 5.4: Update Client Code References

**IMPORTANT**: Keep fallback methods in repositories but remove from startup flow.

**Update in `FoodRepository`**:
```dart
// KEEP this method as a fallback (for manual refresh)
Future<List<FoodItem>> _fetchAndSyncFromSupabase() async {
  // Calls get-foods edge function
  // Used for manual refresh, not startup
}

// ADD this note in documentation
/// ⚠️ This method is a fallback for manual food refresh.
/// For app startup, use UnifiedSyncService instead.
```

**Update in `CarbLoadingFoodSyncService`**:
```dart
// KEEP the service but don't call from startup
@Deprecated('Use UnifiedSyncService for startup. Keep for manual refresh only.')
class CarbLoadingFoodSyncService {
  // Keep syncCarbLoadingFoods() as fallback
  // Used for manual refresh, not startup
}
```

**Remove from startup flow**:
- `lib/features/app_startup/application/app_startup_service.dart` - Remove `checkAndRefreshFoodData()` call
- Replace with `syncAllData()` which uses UnifiedSyncService

#### Step 5.5: Clean Up Unused Imports

After removing old sync services, clean up imports:
```dart
// Remove these imports from files that no longer need them:
import '../../carb_loading/application/carb_loading_food_sync_service.dart'; // DELETE
import '../../calendar/application/calendar_sync_service.dart'; // DELETE
```

**Files to check**:
- `lib/features/app_startup/application/app_startup_service.dart`
- `lib/features/app_startup/application/app_startup_provider.dart`

---

## Expected Results

### Performance Improvements
| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Network calls | 7 | 1 | 86% reduction |
| Sync time | ~1.5s | ~0.3-0.5s | 70% faster |
| Log lines | ~60 | ~4-6 | 90% reduction |

### User Experience
- Faster cold start
- Cleaner debug output for developers
- Simpler error handling
- Single point of failure (easier to debug)

### Maintenance Benefits
- Single edge function to maintain instead of 7+
- Atomic sync operations (all or nothing)
- Easier to add new data sources
- Simplified client code

---

## Rollback Plan

If issues arise in production:

1. **Immediate**: Revert `app_startup_provider.dart` to use old sync methods
2. **Client Side**: Old services still exist (deprecated but functional)
3. **Server Side**: Old edge functions remain deployed
4. **Timeline**: Can rollback in < 5 minutes with code change + hot restart

---

## Success Criteria

- [ ] Sync time reduced by at least 50%
- [ ] Log output reduced by at least 80%
- [ ] All existing tests pass
- [ ] No user-facing bugs introduced
- [ ] Cold start works with empty database
- [ ] Warm start works with cached data
- [ ] Sync failures handled gracefully
- [ ] Performance validated on real devices

---

## Timeline

**Total Estimated Time**: 9-13 hours

| Phase | Time | Priority |
|-------|------|----------|
| Phase 1: Edge Function | 2-3h | High |
| Phase 2: Client Sync | 2-3h | High |
| Phase 3: Logging Cleanup | 1-2h | Medium |
| Phase 4: Testing | 2-3h | High |
| Phase 5: Cleanup & Edge Function Removal | 2-3h | Medium |

**Recommended Approach**:
1. **Week 1**: Complete Phases 1-2 (core functionality) and deploy
2. **Week 1**: Test thoroughly and monitor error rates
3. **Week 2**: Complete Phase 3 (logging) as a separate PR
4. **Week 2**: Add deprecation warnings to old edge functions
5. **Week 3+**: Complete Phase 5 (remove old functions) incrementally

---

## Notes

- This is a **non-breaking change** - old sync methods remain functional
- Can be rolled out gradually with feature flag if needed
- Monitor error rates closely in production for first week
- Consider adding telemetry to measure actual performance gains
