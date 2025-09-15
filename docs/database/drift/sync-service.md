# Sync Service Architecture

## Overview

The sync service manages data synchronization between the local Drift database and Supabase backend. It implements a 24-hour refresh cycle for content and food data while providing real-time sync for user-generated content.

## Sync Components

### 1. Food Sync Service

Manages the local food database cache with periodic refresh from Supabase.

```dart
class FoodSyncService {
  static const Duration SYNC_INTERVAL = Duration(hours: 24);
  static const String LAST_SYNC_KEY = 'food_last_sync_timestamp';
  
  final SupabaseClient _supabase;
  final AppDatabase _database;
  final SharedPreferences _prefs;
  
  FoodSyncService({
    required SupabaseClient supabase,
    required AppDatabase database, 
    required SharedPreferences prefs,
  }) : _supabase = supabase, _database = database, _prefs = prefs;
  
  /// Check if food data needs refreshing based on 24-hour interval
  Future<bool> needsSync() async {
    final lastSyncStr = _prefs.getString(LAST_SYNC_KEY);
    if (lastSyncStr == null) return true;
    
    final lastSync = DateTime.parse(lastSyncStr);
    final now = DateTime.now();
    
    return now.difference(lastSync) > SYNC_INTERVAL;
  }
  
  /// Sync food data if needed (called on app startup)
  Future<void> syncIfNeeded() async {
    if (await needsSync()) {
      await syncNow();
    }
  }
  
  /// Force immediate sync of food data
  Future<void> syncNow() async {
    try {
      print('🍎 Starting food database sync...');
      
      final stopwatch = Stopwatch()..start();
      
      // Fetch all foods with relationships
      final response = await _supabase
          .from('foods')
          .select('''
            *,
            food_categories (
              category_id,
              categories (
                id,
                name
              )
            ),
            brands (
              id,
              name,
              website_url,
              affiliate_program_url
            )
          ''')
          .order('name');
      
      final foods = response as List<dynamic>;
      
      // Update local database in transaction
      await _database.transaction(() async {
        // Clear existing food data
        await _clearFoodCache();
        
        // Insert foods in batches for performance
        await _insertFoodsInBatches(foods);
        
        // Update categories if needed
        await _updateCategories();
      });
      
      // Update last sync timestamp
      await _prefs.setString(LAST_SYNC_KEY, DateTime.now().toIso8601String());
      
      stopwatch.stop();
      print('✅ Food sync completed: ${foods.length} foods in ${stopwatch.elapsedMilliseconds}ms');
      
      // Track sync metrics
      _trackSyncMetrics('food_sync_success', foods.length, stopwatch.elapsed);
      
    } catch (e) {
      print('❌ Food sync failed: $e');
      _trackSyncMetrics('food_sync_failed', 0, Duration.zero, error: e.toString());
      
      // Don't rethrow - app should continue with cached data
    }
  }
  
  Future<void> _clearFoodCache() async {
    await _database.delete(_database.foodCategoriesTable).go();
    await _database.delete(_database.foodsTable).go();
  }
  
  Future<void> _insertFoodsInBatches(List<dynamic> foods) async {
    const batchSize = 50;
    
    for (int i = 0; i < foods.length; i += batchSize) {
      final batch = foods.skip(i).take(batchSize).toList();
      
      await _database.batch((batchInsert) {
        for (final foodData in batch) {
          // Convert Supabase food to local food entry
          final food = _convertSupabaseFoodToLocal(foodData);
          batchInsert.insert(_database.foodsTable, food);
          
          // Insert food-category relationships
          final categories = foodData['food_categories'] as List?;
          if (categories != null) {
            for (final categoryData in categories) {
              batchInsert.insert(_database.foodCategoriesTable, FoodCategoriesTableCompanion(
                foodId: Value(food.id.value),
                categoryId: Value(categoryData['category_id']),
              ));
            }
          }
        }
      });
    }
  }
  
  FoodsTableCompanion _convertSupabaseFoodToLocal(Map<String, dynamic> data) {
    return FoodsTableCompanion(
      id: Value(data['id']),
      name: Value(data['name']),
      imageAddress: Value(data['image_address']),
      description: Value(data['description']),
      instructions: Value(data['instructions']),
      nutritionalInfo: Value(jsonEncode(data['nutritional_info'] ?? {})),
      servingAmount: Value(data['serving_amount']?.toDouble()),
      servingUnit: Value(data['serving_unit']),
      servingUnitPlural: Value(data['serving_unit_plural']),
      servingQualifier: Value(data['serving_qualifier']),
      beforeRunSuitable: Value(data['before_run_suitable'] ?? false),
      duringRunSuitable: Value(data['during_run_suitable'] ?? false),
      runPortable: Value(data['run_portable'] ?? false),
      requiresPreparation: Value(data['requires_preparation'] ?? false),
      aidStationAvailable: Value(data['aid_station_available'] ?? false),
      maxServingsBefore: Value(data['max_servings_before']),
      maxServingsDuring: Value(data['max_servings_during']),
      carbsPerServing: Value(data['carbs_per_serving']?.toDouble()),
      proteinPerServing: Value(data['protein_per_serving']?.toDouble()),
      fatPerServing: Value(data['fat_per_serving']?.toDouble()),
      caloriesPerServing: Value(data['calories_per_serving']),
      fluidMlPerServing: Value(data['fluid_ml_per_serving']?.toDouble()),
      sodiumMg: Value(data['sodium_mg']),
      caffeineMg: Value(data['caffeine_mg']),
      potassiumMg: Value(data['potassium_mg']),
      brandId: Value(data['brand_id']),
      productType: Value(data['product_type']),
      purchaseUrl: Value(data['purchase_url']),
      affiliateSource: Value(data['affiliate_source']),
      createdAt: Value(DateTime.tryParse(data['created_at'] ?? '')),
    );
  }
}
```

### 2. Content Sync Service

Manages app content (UI text, algorithm parameters) with version-based caching.

```dart
class ContentSyncService {
  static const Duration SYNC_INTERVAL = Duration(hours: 24);
  static const String LAST_SYNC_KEY = 'content_last_sync_timestamp';
  static const String CACHED_VERSION_KEY = 'cached_content_version';
  
  final SupabaseClient _supabase;
  final AppDatabase _database;
  final SharedPreferences _prefs;
  
  /// Get active content with version checking
  Future<AppContent?> getActiveContent(String environment, String locale) async {
    // Check local cache first
    final cached = await _getCachedContent(environment, locale);
    
    // Check if we need to sync
    if (await _shouldSync(cached)) {
      await syncNow(environment, locale);
      
      // Return fresh content after sync
      return await _getCachedContent(environment, locale);
    }
    
    return cached;
  }
  
  Future<AppContent?> _getCachedContent(String environment, String locale) async {
    final contentEntry = await (_database.select(_database.appContentTable)
      ..where((t) => 
        t.environment.equals(environment) & 
        t.locale.equals(locale) & 
        t.isActive.equals(true))
      ..orderBy([(t) => OrderingTerm.desc(t.version)])
      ..limit(1)).getSingleOrNull();
    
    if (contentEntry == null) return null;
    
    return AppContent(
      version: contentEntry.version,
      environment: contentEntry.environment,
      locale: contentEntry.locale,
      content: jsonDecode(contentEntry.content),
      lastSync: contentEntry.lastSyncAt,
    );
  }
  
  Future<bool> _shouldSync(AppContent? cached) async {
    // Always sync if no cached content
    if (cached == null) return true;
    
    // Check time-based sync interval
    final lastSyncStr = _prefs.getString(LAST_SYNC_KEY);
    if (lastSyncStr != null) {
      final lastSync = DateTime.parse(lastSyncStr);
      if (DateTime.now().difference(lastSync) < SYNC_INTERVAL) {
        return false; // Too soon to sync again
      }
    }
    
    return true;
  }
  
  Future<void> syncNow(String environment, String locale) async {
    try {
      print('📄 Starting content sync for $environment/$locale...');
      
      // Fetch latest content from Supabase
      final response = await _supabase
          .from('app_content')
          .select()
          .eq('environment', environment)
          .eq('locale', locale)
          .eq('is_active', true)
          .order('version', ascending: false)
          .limit(1)
          .maybeSingle();
      
      if (response != null) {
        // Check if we have a newer version
        final serverVersion = response['version'] as int;
        final cachedVersion = _prefs.getInt(CACHED_VERSION_KEY) ?? 0;
        
        if (serverVersion > cachedVersion) {
          // Save new content to database
          await _database.into(_database.appContentTable).insertOnConflictUpdate(
            AppContentTableCompanion(
              id: Value(response['id']),
              version: Value(serverVersion),
              environment: Value(environment),
              locale: Value(locale),
              content: Value(jsonEncode(response['content'])),
              isActive: Value(true),
              lastSyncAt: Value(DateTime.now()),
              isCached: Value(true),
              createdAt: Value(DateTime.tryParse(response['created_at'] ?? '')),
              updatedAt: Value(DateTime.tryParse(response['updated_at'] ?? '')),
            ),
          );
          
          // Update cached version
          await _prefs.setInt(CACHED_VERSION_KEY, serverVersion);
          
          print('✅ Content updated to version $serverVersion');
        } else {
          print('ℹ️ Content is up to date (v$cachedVersion)');
        }
      }
      
      // Update last sync timestamp
      await _prefs.setString(LAST_SYNC_KEY, DateTime.now().toIso8601String());
      
    } catch (e) {
      print('❌ Content sync failed: $e');
      // Don't rethrow - app can continue with cached content
    }
  }
}
```

### 3. User Data Sync Service

Handles real-time synchronization of user-generated data (plans, feedback).

```dart
class UserDataSyncService {
  final SupabaseClient _supabase;
  final AppDatabase _database;
  
  /// Sync all pending user data to Supabase
  Future<void> syncPendingData(String userId) async {
    await Future.wait([
      _syncPendingNutritionPlans(userId),
      _syncPendingFeedback(userId),
      _syncUserProfile(userId),
    ]);
  }
  
  Future<void> _syncPendingNutritionPlans(String userId) async {
    try {
      // Get plans that need syncing (created/updated locally)
      final pendingPlans = await (_database.select(_database.nutritionPlans)
        ..where((t) => t.userId.equals(userId) & t.lastModifiedBy.isNull()))
        .get();
      
      for (final plan in pendingPlans) {
        await _syncNutritionPlan(plan);
      }
      
      if (pendingPlans.isNotEmpty) {
        print('✅ Synced ${pendingPlans.length} nutrition plans');
      }
    } catch (e) {
      print('❌ Nutrition plan sync failed: $e');
    }
  }
  
  Future<void> _syncNutritionPlan(NutritionPlanEntry plan) async {
    try {
      // Upsert to Supabase
      await _supabase.from('nutrition_plans').upsert({
        'id': plan.id,
        'device_id': plan.userId,
        'plan_name': plan.planName,
        'plan_data': jsonDecode(plan.planData),
        'distance_miles': plan.distanceMiles,
        'pace_minutes_per_mile': plan.paceMinutesPerMile,
        'total_calories': plan.totalCalories,
        'notes': plan.notes,
        'version': plan.version,
        'created_at': plan.createdAt.toIso8601String(),
        'updated_at': plan.updatedAt.toIso8601String(),
      });
      
      // Mark as synced locally
      await _database.update(_database.nutritionPlans)
        .where((t) => t.id.equals(plan.id))
        .write(NutritionPlansCompanion(
          lastModifiedBy: Value('synced'),
          updatedAt: Value(DateTime.now()),
        ));
        
    } catch (e) {
      print('❌ Failed to sync plan ${plan.id}: $e');
      rethrow;
    }
  }
  
  Future<void> _syncPendingFeedback(String userId) async {
    try {
      // Get unsynced feedback
      final pendingFeedback = await (_database.customSelect(
        'SELECT * FROM feedback WHERE created_at > ? ORDER BY created_at',
        variables: [Variable(DateTime.now().subtract(Duration(days: 30)))]
      )).get();
      
      for (final feedback in pendingFeedback) {
        await _syncFeedbackEntry(feedback.data);
      }
      
      if (pendingFeedback.isNotEmpty) {
        print('✅ Synced ${pendingFeedback.length} feedback entries');
      }
    } catch (e) {
      print('❌ Feedback sync failed: $e');
    }
  }
}
```

### 4. Sync Coordinator

Orchestrates all sync services and manages sync scheduling.

```dart
class SyncCoordinator {
  final FoodSyncService _foodSync;
  final ContentSyncService _contentSync;
  final UserDataSyncService _userDataSync;
  
  Timer? _periodicSyncTimer;
  Timer? _userDataSyncTimer;
  
  SyncCoordinator({
    required FoodSyncService foodSync,
    required ContentSyncService contentSync,
    required UserDataSyncService userDataSync,
  }) : _foodSync = foodSync, _contentSync = contentSync, _userDataSync = userDataSync;
  
  /// Start background sync services
  void startPeriodicSync() {
    // Daily sync for content and food data
    _periodicSyncTimer = Timer.periodic(Duration(hours: 24), (_) async {
      await _performPeriodicSync();
    });
    
    // More frequent user data sync (every 15 minutes when online)
    _userDataSyncTimer = Timer.periodic(Duration(minutes: 15), (_) async {
      await _syncUserDataIfOnline();
    });
  }
  
  void stopPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _userDataSyncTimer?.cancel();
  }
  
  Future<void> _performPeriodicSync() async {
    if (!await _isOnline()) return;
    
    try {
      print('🔄 Starting periodic sync...');
      
      // Run food and content sync in parallel
      await Future.wait([
        _foodSync.syncIfNeeded(),
        _contentSync.syncNow('production', 'en'),
      ]);
      
      print('✅ Periodic sync completed');
    } catch (e) {
      print('❌ Periodic sync failed: $e');
    }
  }
  
  Future<void> _syncUserDataIfOnline() async {
    if (!await _isOnline()) return;
    
    final userId = await _getCurrentUserId();
    if (userId != null) {
      await _userDataSync.syncPendingData(userId);
    }
  }
  
  /// Manual refresh triggered by user
  Future<void> refreshAll() async {
    if (!await _isOnline()) {
      throw SyncException('Cannot refresh - device is offline');
    }
    
    try {
      print('🔄 Manual refresh requested...');
      
      final userId = await _getCurrentUserId();
      
      await Future.wait([
        _foodSync.syncNow(),
        _contentSync.syncNow('production', 'en'),
        if (userId != null) _userDataSync.syncPendingData(userId),
      ]);
      
      print('✅ Manual refresh completed');
    } catch (e) {
      print('❌ Manual refresh failed: $e');
      rethrow;
    }
  }
  
  Future<bool> _isOnline() async {
    final connectivity = await Connectivity().checkConnectivity();
    return connectivity != ConnectivityResult.none;
  }
}
```

## Network State Management

### Connectivity Handling
```dart
class NetworkStateManager {
  final SyncCoordinator _syncCoordinator;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  
  void startNetworkMonitoring() {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen(_onConnectivityChanged);
  }
  
  void _onConnectivityChanged(ConnectivityResult result) {
    if (result != ConnectivityResult.none) {
      // Network became available - trigger sync
      _onNetworkAvailable();
    } else {
      // Network lost - enter offline mode
      _onNetworkLost();
    }
  }
  
  Future<void> _onNetworkAvailable() async {
    print('🌐 Network available - triggering sync...');
    
    try {
      // Immediately sync critical user data
      await _syncCoordinator._syncUserDataIfOnline();
      
      // Schedule background refresh of content/food data
      Timer(Duration(seconds: 5), () async {
        await _syncCoordinator._performPeriodicSync();
      });
    } catch (e) {
      print('❌ Network sync failed: $e');
    }
  }
  
  void _onNetworkLost() {
    print('📴 Network lost - entering offline mode');
    // App continues functioning with cached data
  }
}
```

## Sync Service Providers

### Riverpod Integration
```dart
// Sync service providers
final foodSyncServiceProvider = Provider<FoodSyncService>((ref) {
  return FoodSyncService(
    supabase: ref.read(supabaseProvider),
    database: ref.read(databaseProvider).requireValue,
    prefs: ref.read(sharedPreferencesProvider).requireValue,
  );
});

final contentSyncServiceProvider = Provider<ContentSyncService>((ref) {
  return ContentSyncService(
    supabase: ref.read(supabaseProvider),
    database: ref.read(databaseProvider).requireValue,
    prefs: ref.read(sharedPreferencesProvider).requireValue,
  );
});

final syncCoordinatorProvider = Provider<SyncCoordinator>((ref) {
  return SyncCoordinator(
    foodSync: ref.read(foodSyncServiceProvider),
    contentSync: ref.read(contentSyncServiceProvider),
    userDataSync: ref.read(userDataSyncServiceProvider),
  );
});

// Auto-start sync services on app startup
@riverpod
Future<void> initializeSyncServices(InitializeSyncServicesRef ref) async {
  final coordinator = ref.read(syncCoordinatorProvider);
  coordinator.startPeriodicSync();
  
  final networkManager = NetworkStateManager(coordinator);
  networkManager.startNetworkMonitoring();
}
```

## Error Handling and Retry Logic

### Exponential Backoff
```dart
class SyncRetryManager {
  static const int maxRetries = 3;
  static const Duration baseDelay = Duration(seconds: 5);
  
  static Future<T> withRetry<T>(
    Future<T> Function() operation,
    String operationName,
  ) async {
    int attempts = 0;
    
    while (attempts < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempts++;
        
        if (attempts >= maxRetries) {
          print('❌ $operationName failed after $maxRetries attempts: $e');
          rethrow;
        }
        
        final delay = baseDelay * pow(2, attempts - 1);
        print('⚠️ $operationName failed (attempt $attempts/$maxRetries), retrying in ${delay.inSeconds}s: $e');
        
        await Future.delayed(delay);
      }
    }
    
    throw Exception('Unreachable code');
  }
}
```

## Performance Monitoring

### Sync Metrics
```dart
class SyncMetrics {
  static void trackSyncOperation(
    String operation,
    int recordCount,
    Duration duration, {
    String? error,
  }) {
    final analytics = Mixpanel.getInstance();
    
    analytics.track('sync_operation', {
      'operation': operation,
      'record_count': recordCount,
      'duration_ms': duration.inMilliseconds,
      'success': error == null,
      'error': error,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  static void trackSyncHealth() {
    // Track overall sync health metrics
    analytics.track('sync_health_check', {
      'last_food_sync': _getLastFoodSyncAge(),
      'last_content_sync': _getLastContentSyncAge(),
      'pending_user_data_count': _getPendingUserDataCount(),
    });
  }
}
```

This comprehensive sync service architecture ensures reliable data synchronization while maintaining excellent offline functionality and performance.