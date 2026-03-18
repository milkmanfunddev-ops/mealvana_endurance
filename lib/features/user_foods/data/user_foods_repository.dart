import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/sentry/sentry_reporter.dart';
import '../../../shared/data/syncable_repository.dart';
import '../../../shared/services/sync/sync_dependency_graph.dart';

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
  List<String> get dependencies =>
      SyncDependencyGraph.dependenciesFor(repositoryKey);

  @override
  Future<SyncResult> syncFromRemote(String userId) async {
    try {
      // Query Supabase for this user's custom foods (excluding soft-deleted)
      final response = await supabase
          .from('user_foods')
          .select('*')
          .eq('user_id', userId)
          .eq('is_deleted', false);

      final syncedCount = await _syncRemoteRowsPreservingDirty(
        userId,
        response as List<dynamic>,
      );

      // Update last sync timestamp
      await setLastSyncTime(DateTime.now());

      sentry.addBreadcrumb(
        message: 'User foods synced from Supabase',
        category: 'sync',
        data: {
          'user_id': userId,
          'repository': repositoryKey,
          'count': syncedCount,
        },
      );

      return SyncResult.successful(syncedCount);
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
      final dirtyFoods =
          await (database.select(database.userFoodsTable)
                ..where((t) => t.userId.equals(userId))
                ..where((t) => t.needsUpload.equals(true)))
              .get();

      if (dirtyFoods.isEmpty) {
        return UploadResult.nothingToUpload();
      }

      // Convert to JSON array for batch upsert
      final foodsToUpload = dirtyFoods
          .map(
            (food) => {
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
              'serving_size': food.servingSize,
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
            },
          )
          .toList();

      // Batch upload to Supabase
      await supabase.from('user_foods').upsert(foodsToUpload, onConflict: 'id');

      // Clear dirty flags in local database
      await database.transaction(() async {
        for (final food in dirtyFoods) {
          await database
              .update(database.userFoodsTable)
              .replace(
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
                  servingSize: Value(food.servingSize),
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

      await _syncRemoteRowsPreservingDirty(userId, response as List<dynamic>);

      sentry.addBreadcrumb(
        message: 'User foods synced from Supabase',
        category: 'sync',
        data: {'user_id': userId, 'count': response.length},
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

  Future<int> _syncRemoteRowsPreservingDirty(
    String userId,
    List<dynamic> remoteRows,
  ) async {
    final remoteById = <String, Map<String, dynamic>>{};
    for (final item in remoteRows) {
      if (item is! Map) continue;
      final mapped = Map<String, dynamic>.from(item);
      final id = mapped['id']?.toString();
      if (id == null || id.isEmpty) continue;
      remoteById[id] = mapped;
    }

    if (remoteById.isEmpty) {
      return 0;
    }

    final remoteIds = remoteById.keys.toList(growable: false);
    final dirtyRows =
        await (database.select(database.userFoodsTable)..where(
              (t) =>
                  t.id.isIn(remoteIds) &
                  t.needsUpload.equals(true) &
                  (t.userId.equals(userId) | t.deviceId.equals(userId)),
            ))
            .get();
    final dirtyIds = dirtyRows.map((row) => row.id).toSet();

    var upserted = 0;
    await database.transaction(() async {
      for (final entry in remoteById.entries) {
        if (dirtyIds.contains(entry.key)) {
          continue;
        }

        await database
            .into(database.userFoodsTable)
            .insertOnConflictUpdate(
              _mapRemoteUserFoodToCompanion(userId, entry.value),
            );
        upserted++;
      }
    });

    if (dirtyIds.isNotEmpty) {
      sentry.addBreadcrumb(
        message: 'Skipped remote user_food overwrite for dirty local rows',
        category: 'sync',
        data: {
          'user_id': userId,
          'skipped_count': dirtyIds.length,
          'total_remote': remoteById.length,
        },
      );
    }

    return upserted;
  }

  UserFoodsTableCompanion _mapRemoteUserFoodToCompanion(
    String userId,
    Map<String, dynamic> food,
  ) {
    final categoriesJson = food['categories'];
    final activityTypesJson = food['activity_types'];

    return UserFoodsTableCompanion(
      id: Value(food['id'] as String),
      deviceId: Value(food['device_id'] as String? ?? userId),
      userId: Value(food['user_id'] as String? ?? userId),
      clientFoodId: Value(food['client_food_id'] as String?),
      barcode: Value(food['barcode'] as String?),
      name: Value(food['name'] as String),
      displayName: Value(food['display_name'] as String?),
      displayNamePlural: Value(food['display_name_plural'] as String?),
      description: Value(food['description'] as String?),
      imageAddress: Value(food['image_address'] as String?),
      servingAmount: Value((food['serving_amount'] as num?)?.toDouble()),
      servingUnit: Value(food['serving_unit'] as String?),
      servingSize: Value(food['serving_size'] as String?),
      caloriesPerServing: Value(food['calories_per_serving'] as int?),
      carbsPerServing: Value((food['carbs_per_serving'] as num?)?.toDouble()),
      proteinPerServing: Value(
        (food['protein_per_serving'] as num?)?.toDouble(),
      ),
      fatPerServing: Value((food['fat_per_serving'] as num?)?.toDouble()),
      sodiumMg: Value(food['sodium_mg'] as int?),
      fluidMlPerServing: Value(
        (food['fluid_ml_per_serving'] as num?)?.toDouble(),
      ),
      productTypeId: Value(
        (food['product_type'] ?? food['product_type_id']) as String?,
      ),
      categories: Value(
        categoriesJson is List
            ? jsonEncode(categoriesJson)
            : categoriesJson as String?,
      ),
      activityTypes: Value(
        activityTypesJson is List
            ? jsonEncode(activityTypesJson)
            : activityTypesJson as String?,
      ),
      isElectrolyte: Value(_asBool(food['is_electrolyte'])),
      toExcludeFromSolver: Value(_asBool(food['to_exclude_from_solver'])),
      isDeleted: Value(_asBool(food['is_deleted'])),
      createdAt: Value(_parseDate(food['created_at']) ?? DateTime.now()),
      updatedAt: Value(_parseDate(food['updated_at']) ?? DateTime.now()),
      clientUpdatedAt: Value(_parseDate(food['client_updated_at'])),
      needsUpload: const Value(false),
      localUpdatedAt: Value(DateTime.now()),
    );
  }

  bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return false;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
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
