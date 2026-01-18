import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/sentry/sentry_reporter.dart';
import '../../../shared/data/syncable_repository.dart';

part 'user_foods_repository.g.dart';

/// Repository for managing user-created custom foods in Drift database and Supabase
/// Level 1 repository - depends on users only
class UserFoodsRepository with SyncableRepository {
  UserFoodsRepository({
    required this.database,
    required this.supabase,
    required this.sentry,
  });

  final AppDatabase database;
  final SupabaseClient supabase;
  final SentryReporter sentry;

  // ========== SyncableRepository Implementation ==========

  @override
  String get repositoryKey => 'user_foods';

  @override
  List<String> get dependencies => ['users']; // Level 1 - depends on users

  @override
  Future<SyncResult> syncFromRemote(String userId) async {
    try {
      // Query Supabase for this user's custom foods (excluding soft-deleted)
      final response = await supabase
          .from('user_foods')
          .select('*')
          .eq('user_id', userId)
          .eq('is_deleted', false);

      // Replace local user foods with fresh data from Supabase
      await database.replaceUserFoods(userId, List<Map<String, dynamic>>.from(response));

      // Update last sync timestamp
      await setLastSyncTime(DateTime.now());

      sentry.addBreadcrumb(
        message: 'User foods synced from Supabase',
        category: 'sync',
        data: {
          'user_id': userId,
          'repository': repositoryKey,
          'count': response.length,
        },
      );

      return SyncResult.successful(response.length);
    } catch (e, stackTrace) {
      await sentry.reportNetworkError(
        e,
        url: 'supabase:user_foods:sync',
        method: 'SELECT',
        stackTrace: stackTrace,
      );
      return SyncResult.failed(e.toString());
    }
  }

  @override
  Future<UploadResult> uploadDirtyRecords(String userId) async {
    try {
      // Query Drift for user foods with needs_upload = true
      final dirtyFoods = await (database.select(database.userFoodsTable)
            ..where((t) => t.userId.equals(userId))
            ..where((t) => t.needsUpload.equals(true)))
          .get();

      if (dirtyFoods.isEmpty) {
        return UploadResult.nothingToUpload();
      }

      // Convert to JSON array for batch upsert
      final foodsToUpload = dirtyFoods.map((food) => {
        'id': food.id,
        'device_id': food.deviceId,
        'user_id': food.userId,
        'client_food_id': food.clientFoodId,
        'barcode': food.barcode,
        'name': food.name,
        'display_name': food.displayName,
        'display_name_plural': food.displayNamePlural,
        'description': food.description,
        'image_address': food.imageAddress,
        'serving_amount': food.servingAmount,
        'serving_unit': food.servingUnit,
        'calories_per_serving': food.caloriesPerServing,
        'carbs_per_serving': food.carbsPerServing,
        'protein_per_serving': food.proteinPerServing,
        'fat_per_serving': food.fatPerServing,
        'sodium_mg': food.sodiumMg,
        'fluid_ml_per_serving': food.fluidMlPerServing,
        'product_type_id': food.productTypeId,
        'categories': food.categories,
        'activity_types': food.activityTypes,
        'is_electrolyte': food.isElectrolyte,
        'to_exclude_from_solver': food.toExcludeFromSolver,
        'is_deleted': food.isDeleted,
        'created_at': food.createdAt.toIso8601String(),
        'updated_at': food.updatedAt.toIso8601String(),
        'client_updated_at': food.clientUpdatedAt?.toIso8601String(),
      }).toList();

      // Batch upload to Supabase
      await supabase.from('user_foods').upsert(
        foodsToUpload,
        onConflict: 'id',
      );

      // Clear dirty flags in local database
      await database.transaction(() async {
        for (final food in dirtyFoods) {
          await database.update(database.userFoodsTable).replace(
                UserFoodsTableCompanion(
                  id: Value(food.id),
                  deviceId: Value(food.deviceId),
                  userId: Value(food.userId),
                  clientFoodId: Value(food.clientFoodId),
                  barcode: Value(food.barcode),
                  name: Value(food.name),
                  displayName: Value(food.displayName),
                  displayNamePlural: Value(food.displayNamePlural),
                  description: Value(food.description),
                  imageAddress: Value(food.imageAddress),
                  servingAmount: Value(food.servingAmount),
                  servingUnit: Value(food.servingUnit),
                  caloriesPerServing: Value(food.caloriesPerServing),
                  carbsPerServing: Value(food.carbsPerServing),
                  proteinPerServing: Value(food.proteinPerServing),
                  fatPerServing: Value(food.fatPerServing),
                  sodiumMg: Value(food.sodiumMg),
                  fluidMlPerServing: Value(food.fluidMlPerServing),
                  productTypeId: Value(food.productTypeId),
                  categories: Value(food.categories),
                  activityTypes: Value(food.activityTypes),
                  isElectrolyte: Value(food.isElectrolyte),
                  toExcludeFromSolver: Value(food.toExcludeFromSolver),
                  isDeleted: Value(food.isDeleted),
                  createdAt: Value(food.createdAt),
                  updatedAt: Value(food.updatedAt),
                  clientUpdatedAt: Value(food.clientUpdatedAt),
                  needsUpload: const Value(false), // Clear dirty flag
                  localUpdatedAt: Value(food.localUpdatedAt),
                ),
              );
        }
      });

      sentry.addBreadcrumb(
        message: 'Uploaded dirty user foods to Supabase',
        category: 'sync',
        data: {
          'user_id': userId,
          'repository': repositoryKey,
          'count': dirtyFoods.length,
        },
      );

      return UploadResult.successful(dirtyFoods.length);
    } catch (e, stackTrace) {
      await sentry.reportNetworkError(
        e,
        url: 'supabase:user_foods:upload',
        method: 'UPSERT',
        stackTrace: stackTrace,
      );
      return UploadResult.failed(e.toString());
    }
  }

  // ========== End SyncableRepository Implementation ==========

  // ========== User Foods CRUD Methods ==========

  /// Sync user foods from Supabase and cache locally
  /// This is the main method used by existing code
  Future<void> syncUserFoodsFromSupabase(String userId) async {
    try {
      final response = await supabase
          .from('user_foods')
          .select()
          .eq('user_id', userId)
          .eq('is_deleted', false);

      await database.replaceUserFoods(userId, List<Map<String, dynamic>>.from(response));

      sentry.addBreadcrumb(
        message: 'User foods synced from Supabase',
        category: 'sync',
        data: {
          'user_id': userId,
          'count': response.length,
        },
      );
    } catch (e, stackTrace) {
      await sentry.reportNetworkError(
        e,
        url: 'supabase:user_foods:select',
        method: 'SELECT',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}

/// Repository provider following Andrea's pattern
@riverpod
Future<UserFoodsRepository> userFoodsRepository(Ref ref) async {
  final database = ref.watch(appDatabaseProvider);
  final sentry = ref.watch(sentryReporterProvider);
  final supabase = ref.watch(appExternalDepsProvider).supabaseClient;

  return UserFoodsRepository(
    database: database,
    supabase: supabase,
    sentry: sentry,
  );
}
