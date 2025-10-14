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
  })  : _supabase = supabase,
        _database = database,
        _logger = logger;

  final SupabaseClient _supabase;
  final AppDatabase _database;
  final AppLogger _logger;

  /// Sync carb loading foods and meal types from Supabase to local database
  /// This should be called during app startup to ensure data is available offline
  Future<void> syncCarbLoadingFoods() async {
    try {
      _logger.info('Starting carb loading foods sync from Supabase');

      // Call the get-carb-loading-foods edge function
      final response = await _supabase.functions.invoke(
        'get-carb-loading-foods',
        body: {
          'meal_type_id': null, // Get all foods regardless of meal type
        },
      );

      if (response.status != 200) {
        throw Exception(
          'Edge Function error: ${response.data?['error'] ?? 'Unknown error'}',
        );
      }

      final data = response.data;
      if (data == null) {
        throw Exception('Invalid response from get-carb-loading-foods');
      }

      final List<dynamic> foodsData = data['foods'] as List<dynamic>? ?? [];
      final List<dynamic> mealTypesData = data['meal_types'] as List<dynamic>? ?? [];

      // Sync meal types first
      await _syncMealTypes(mealTypesData);

      // Sync foods and their meal type associations
      await _syncFoodsToLocalDatabase(foodsData);

      _logger.info(
        'Successfully synced ${foodsData.length} carb loading foods and ${mealTypesData.length} meal types',
      );
    } catch (e) {
      _logger.error(
        'Error syncing carb loading foods from Supabase',
        context: 'CarbLoadingFoodSyncService',
        error: e,
      );
      // Don't rethrow - app should continue even if sync fails
      // Foods might already be in local database from previous sync
    }
  }

  /// Sync meal types to local database
  Future<void> _syncMealTypes(List<dynamic> mealTypesData) async {
    if (mealTypesData.isEmpty) {
      _logger.warning('No meal types to sync');
      return;
    }

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

    _logger.debug('Synced ${mealTypesData.length} meal types to local database');
  }

  /// Sync foods and their meal type associations to local database
  Future<void> _syncFoodsToLocalDatabase(List<dynamic> foodsData) async {
    if (foodsData.isEmpty) {
      _logger.warning('No carb loading foods to sync');
      return;
    }

    await _database.batch((batch) {
      for (final foodJson in foodsData) {
        final foodId = foodJson['id'] as String;

        // Insert food
        final food = CarbLoadingFoodsTableCompanion.insert(
          id: foodId,
          name: foodJson['name'] as String,
          displayName: foodJson['display_name'] as String,
          displayNamePlural: Value(foodJson['display_name_plural'] as String?),
          carbsPerServing: (foodJson['carbs_per_serving'] as num).toDouble(),
          imageAddress: Value(foodJson['image_address'] as String? ?? ''),
          isDefault: Value(foodJson['is_default'] as bool? ?? true),
          createdAt: Value(
            DateTime.parse(foodJson['created_at'] as String),
          ),
        );

        batch.insert(
          _database.carbLoadingFoodsTable,
          food,
          mode: InsertMode.insertOrReplace,
        );

        // Insert meal type associations
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

    _logger.debug('Synced ${foodsData.length} carb loading foods to local database');
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
