import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/data/syncable_repository.dart';
import '../../../shared/services/sync/sync_dependency_graph.dart';
import '../../../shared/services/report/decode_issue_report.dart';
import '../../../shared/services/report/report.dart';
import '../domain/carb_loading_food.dart' as domain;
import '../domain/meal_type.dart' show parseMealTypeIds;

part 'carb_loading_food_repository.g.dart';

/// Repository for managing global default carb loading foods
/// Handles database queries and conversions between Drift entities and domain models
/// Implements SyncableRepository for on-demand sync of global foods
class CarbLoadingFoodRepository with SyncableRepository {
  CarbLoadingFoodRepository({
    required AppDatabase database,
    required SupabaseClient supabase,
    required Report report,
  }) : _database = database,
       _supabase = supabase,
       _report = report;

  final AppDatabase _database;
  final SupabaseClient _supabase;
  final Report _report;

  // ========================================================================
  // SyncableRepository Implementation
  // ========================================================================

  @override
  String get repositoryKey => 'carb_loading_foods';

  @override
  List<String> get dependencies =>
      SyncDependencyGraph.dependenciesFor(repositoryKey);

  /// Override isStale to force sync when local database is empty.
  /// This handles the case where SharedPreferences has a "fresh" timestamp
  /// but the actual data was cleared or never synced.
  @override
  Future<bool> isStale() async {
    // First check if local database has any foods
    final localFoods = await _database
        .select(_database.carbLoadingFoodsTable)
        .get();
    if (localFoods.isEmpty) {
      _report.debug(
        'Forcing sync - no local carb loading foods found',
        area: 'carb_loading',
      );
      return true; // Force sync regardless of timestamp
    }

    // Otherwise, use default staleness check from mixin
    return await super.isStale();
  }

  @override
  Future<SyncResult> syncFromRemote(String userId) async {
    // Note: userId is ignored for global tables like carb_loading_foods
    try {
      _report.info(
        'Syncing carb loading foods from Supabase',
        area: 'carb_loading',
      );

      // Query all carb loading foods from Supabase
      final response = await _supabase
          .from('carb_loading_foods')
          .select(
            'id, name, display_name, display_name_plural, carbs_per_serving, '
            'image_address, is_default, meal_types, created_at',
          )
          .order('display_name');

      final List<dynamic> foodsData = response as List<dynamic>;

      if (foodsData.isEmpty) {
        await setLastSyncTime(DateTime.now());
        _report.info('No carb loading foods to sync', area: 'carb_loading');
        return SyncResult.successful(0);
      }

      // Save foods to Drift database
      await _database.batch((batch) {
        for (final foodJson in foodsData) {
          final foodId = foodJson['id'] as String;
          final displayName = foodJson['display_name'] as String;

          // Convert meal_types array from PostgreSQL format to String
          // Production schema: meal_types text[] (e.g., ['breakfast', 'lunch'])
          final mealTypesFromDb =
              foodJson['meal_types'] as List<dynamic>? ?? [];
          final mealTypesArray = mealTypesFromDb.isEmpty
              ? null
              : '{${mealTypesFromDb.join(',')}}';

          // Parse created_at - handle both String and null
          DateTime createdAt;
          final createdAtValue = foodJson['created_at'];
          if (createdAtValue is String) {
            createdAt = DateTime.parse(createdAtValue);
          } else {
            createdAt = DateTime.now();
          }

          // Insert food with meal_types array
          final food = CarbLoadingFoodsTableCompanion.insert(
            id: foodId,
            name: foodJson['name'] as String,
            displayName: displayName,
            displayNamePlural: Value(
              foodJson['display_name_plural'] as String?,
            ),
            carbsPerServing: (foodJson['carbs_per_serving'] as num).toDouble(),
            imageAddress: Value(foodJson['image_address'] as String? ?? ''),
            isDefault: Value(foodJson['is_default'] as bool? ?? true),
            mealTypes: Value(mealTypesArray),
            createdAt: Value(createdAt),
          );

          batch.insert(
            _database.carbLoadingFoodsTable,
            food,
            mode: InsertMode.insertOrReplace,
          );
        }
      });

      await setLastSyncTime(DateTime.now());

      _report.info(
        'Successfully synced carb loading foods',
        area: 'carb_loading',
        data: {'count': foodsData.length},
      );

      return SyncResult.successful(foodsData.length);
    } catch (e, stackTrace) {
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'carb_loading',
        message: 'Failed to sync carb loading foods from Supabase',
      );
      return SyncResult.failed(e.toString());
    }
  }

  @override
  Future<UploadResult> uploadDirtyRecords(String userId) async {
    // Global table - users don't modify these records
    // No dirty records to upload
    return UploadResult.nothingToUpload();
  }

  // ========================================================================
  // Existing Methods
  // ========================================================================

  /// Get all default carb loading foods with their meal type associations
  Future<List<domain.CarbLoadingFood>> getAllFoods() async {
    final query = _database.select(_database.carbLoadingFoodsTable);
    final foods = await query.get();

    return foods.map((food) => _convertToFoodDomain(food)).toList();
  }

  /// Get foods suitable for a specific meal type
  /// REFACTORED: More forgiving filtering - includes foods with null/empty meal_types
  Future<List<domain.CarbLoadingFood>> getFoodsByMealType(
    int mealTypeId,
  ) async {
    _report.debug(
      'Querying foods for meal type',
      area: 'carb_loading',
      data: {'mealTypeId': mealTypeId},
    );

    // Query foods and filter by meal_types array column
    final query = _database.select(_database.carbLoadingFoodsTable);
    final allFoods = await query.get();

    _report.debug(
      'Found foods in database',
      area: 'carb_loading',
      data: {'count': allFoods.length},
    );

    // Filter foods that have this meal type in their array
    final filteredFoods = allFoods
        .where((food) {
          // If meal_types is null or empty, include the food (works for all meal types)
          if (food.mealTypes == null || food.mealTypes!.isEmpty) {
            return true; // Changed from false to true - more forgiving!
          }

          final mealTypes = parseMealTypeIds(
            food.mealTypes,
            onIssue: _report.decodeIssue('carb_loading'),
          );
          final matches = mealTypes.isEmpty || mealTypes.contains(mealTypeId);

          return matches;
        })
        .map((food) => _convertToFoodDomain(food))
        .toList();

    _report.debug(
      'After filtering foods',
      area: 'carb_loading',
      data: {'filtered': filteredFoods.length, 'mealTypeId': mealTypeId},
    );

    if (filteredFoods.isEmpty && allFoods.isNotEmpty) {
      _report.degraded(
        LoggedFault('No foods matched filter', context: 'carb_loading'),
        area: 'carb_loading',
        extra: {
          'sampleMealTypes': allFoods.take(3).map((f) => f.mealTypes).toList(),
        },
      );
    }

    return filteredFoods;
  }

  /// Get a specific food by ID
  Future<domain.CarbLoadingFood?> getFoodById(String id) async {
    final query = _database.select(_database.carbLoadingFoodsTable)
      ..where((tbl) => tbl.id.equals(id));

    final food = await query.getSingleOrNull();
    if (food == null) return null;

    return _convertToFoodDomain(food);
  }

  /// Search foods by name
  Future<List<domain.CarbLoadingFood>> searchFoodsByName(
    String searchTerm,
  ) async {
    final query = _database.select(_database.carbLoadingFoodsTable)
      ..where((tbl) => tbl.displayName.contains(searchTerm));

    final foods = await query.get();
    return foods.map((food) => _convertToFoodDomain(food)).toList();
  }

  /// Convert Drift entity to domain model
  domain.CarbLoadingFood _convertToFoodDomain(CarbLoadingFood food) {
    final mealTypeIds = parseMealTypeIds(
      food.mealTypes,
      onIssue: _report.decodeIssue('carb_loading'),
    );

    return domain.CarbLoadingFood.fromDatabase(
      id: food.id,
      name: food.name,
      displayName: food.displayName,
      displayNamePlural: food.displayNamePlural,
      carbsPerServing: food.carbsPerServing,
      imageAddress: food.imageAddress,
      isDefault: food.isDefault,
      createdAt: food.createdAt,
      mealTypeIds: mealTypeIds,
    );
  }

  /// Watch all foods (for real-time updates)
  Stream<List<domain.CarbLoadingFood>> watchAllFoods() {
    return _database
        .select(_database.carbLoadingFoodsTable)
        .watch()
        .map(
          (foods) => foods.map((food) => _convertToFoodDomain(food)).toList(),
        );
  }

  /// Watch foods by meal type (for real-time updates)
  Stream<List<domain.CarbLoadingFood>> watchFoodsByMealType(int mealTypeId) {
    return _database
        .select(_database.carbLoadingFoodsTable)
        .watch()
        .map(
          (foods) => foods
              .where((food) {
                if (food.mealTypes == null) return false;
                final mealTypes = parseMealTypeIds(
                  food.mealTypes,
                  onIssue: _report.decodeIssue('carb_loading'),
                );
                return mealTypes.contains(mealTypeId);
              })
              .map((food) => _convertToFoodDomain(food))
              .toList(),
        );
  }
}

@riverpod
CarbLoadingFoodRepository carbLoadingFoodRepository(Ref ref) {
  return CarbLoadingFoodRepository(
    database: ref.watch(appDatabaseProvider),
    supabase: Supabase.instance.client,
    report: ref.watch(reportProvider),
  );
}
