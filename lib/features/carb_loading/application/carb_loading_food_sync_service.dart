import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/logging_service.dart';

part 'carb_loading_food_sync_service.g.dart';

/// Service for syncing carb loading foods from Supabase to local Drift database
/// Called during app startup to ensure offline access to carb loading foods
class CarbLoadingFoodSyncService {
  const CarbLoadingFoodSyncService({
    required SupabaseClient supabase,
    required AppDatabase database,
    required AppLogger logger,
  }) : _supabase = supabase,
       _database = database,
       _logger = logger;

  final SupabaseClient _supabase;
  final AppDatabase _database;
  final AppLogger _logger;

  /// Sync carb loading foods from Supabase to local database
  /// This should be called during app startup to ensure data is available offline
  /// Note: meal_types are now stored as array column, not separate table
  /// REFACTORED: Uses direct Supabase query instead of edge function
  Future<void> syncCarbLoadingFoods() async {
    try {
      // Direct Supabase query - no edge function needed!
      final response = await _supabase
          .from('carb_loading_foods')
          .select(
            'id, name, display_name, display_name_plural, carbs_per_serving, '
            'image_address, is_default, meal_types, created_at',
          )
          .order('display_name');

      final List<dynamic> foodsData = response as List<dynamic>;

      // Sync foods with their meal type arrays
      await _syncFoodsToLocalDatabase(foodsData);
    } catch (e, stackTrace) {
      _logger.error(
        'Error syncing carb loading foods from Supabase',
        context: 'CARB_LOADING_SYNC',
        error: e,
        stackTrace: stackTrace,
      );
      // Don't rethrow - app should continue even if sync fails
      // Foods might already be in local database from previous sync
    }
  }

  /// Sync foods with their meal type arrays to local database
  /// Meal types are now stored as array column in foods table
  Future<void> _syncFoodsToLocalDatabase(List<dynamic> foodsData) async {
    if (foodsData.isEmpty) {
      return;
    }

    await _database.batch((batch) {
      for (final foodJson in foodsData) {
        final foodId = foodJson['id'] as String;
        final displayName = foodJson['display_name'] as String;

        // Convert meal_types array from PostgreSQL format to String
        // Production schema: meal_types text[] (e.g., ['breakfast', 'lunch'])
        final mealTypesFromDb = foodJson['meal_types'] as List<dynamic>? ?? [];
        final mealTypesArray = mealTypesFromDb.isEmpty
            ? null
            : '{${mealTypesFromDb.join(',')}}';

        // Debug logging removed for performance - was logging 27 foods on every sync
        // Uncomment if debugging specific food sync issues:
        // _logger.debug(
        //   'Syncing food: $displayName with meal_types: $mealTypesArray',
        //   context: 'CARB_LOADING_SYNC',
        // );

        // Insert food with meal_types array
        final food = CarbLoadingFoodsTableCompanion.insert(
          id: foodId,
          name: foodJson['name'] as String,
          displayName: displayName,
          displayNamePlural: Value(foodJson['display_name_plural'] as String?),
          carbsPerServing: (foodJson['carbs_per_serving'] as num).toDouble(),
          imageAddress: Value(foodJson['image_address'] as String? ?? ''),
          isDefault: Value(foodJson['is_default'] as bool? ?? true),
          mealTypes: Value(mealTypesArray),
          createdAt: Value(DateTime.parse(foodJson['created_at'] as String)),
        );

        batch.insert(
          _database.carbLoadingFoodsTable,
          food,
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  /// Sync carb loading foods from pre-downloaded data (from sync-all-data edge function)
  /// This method is called during app startup after sync-all-data returns
  /// Note: meal_types are now stored as array column, not separate table
  Future<void> syncFromDownloadedData({
    required List<dynamic> carbLoadingFoods,
  }) async {
    try {
      // Sync carb loading foods with their meal type arrays
      await _syncFoodsToLocalDatabase(carbLoadingFoods);
    } catch (e, stackTrace) {
      _logger.error(
        'Carb loading foods sync failed',
        context: 'CARB_LOADING_SYNC',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}

@riverpod
CarbLoadingFoodSyncService carbLoadingFoodSyncService(Ref ref) {
  return CarbLoadingFoodSyncService(
    supabase: ref.watch(appExternalDepsProvider).supabaseClient,
    database: ref.watch(appDatabaseProvider),
    logger: ref.watch(appExternalDepsProvider).logger,
  );
}
