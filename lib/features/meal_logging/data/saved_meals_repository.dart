import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/data/syncable_repository.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/services/sentry/sentry_reporter.dart';
import '../../../shared/services/sync/sync_dependency_graph.dart';
import '../domain/saved_meal.dart';

part 'saved_meals_repository.g.dart';

@riverpod
SavedMealsRepository savedMealsRepository(Ref ref) {
  final deps = ref.read(appExternalDepsProvider);
  return SavedMealsRepository(
    supabase: Supabase.instance.client,
    database: ref.read(appDatabaseProvider),
    logger: ref.read(appLoggerProvider),
    sentry: deps.sentry,
  );
}

/// Repository for explicit user favorites ("My Meals", `saved_meals` table).
///
/// Storage and sync strategy mirrors [MealLogRepository]: local-first writes,
/// `needs_upload` dirty tracking, soft delete, upsert `onConflict: 'id'`.
///
/// [watchSavedMeals] orders by [SavedMeal.lastUsedAt] descending (most
/// recently re-used first) so the meal picker surfaces the most relevant items.
class SavedMealsRepository with SyncableRepository {
  SavedMealsRepository({
    required SupabaseClient supabase,
    required AppDatabase database,
    required AppLogger logger,
    required SentryReporter sentry,
  })  : _supabase = supabase,
        _database = database,
        _logger = logger,
        _sentry = sentry;

  final SupabaseClient _supabase;
  final AppDatabase _database;
  final AppLogger _logger;
  final SentryReporter _sentry;

  static const _uuid = Uuid();

  /// Coalesces concurrent [syncFromRemote] callers.
  Future<SyncResult>? _inflightSync;

  // ========================================================================
  // SyncableRepository
  // ========================================================================

  @override
  String get repositoryKey => 'saved_meals';

  @override
  List<String> get dependencies =>
      SyncDependencyGraph.dependenciesFor(repositoryKey);

  @override
  Future<SyncResult> syncFromRemote(String userId) async {
    final inflight = _inflightSync;
    if (inflight != null) {
      _logger.debug(
        'syncFromRemote: coalescing into in-flight sync',
        context: 'SAVED_MEALS_REPOSITORY',
        data: {'userId': userId},
      );
      return inflight;
    }
    final future = _syncFromRemoteImpl(userId);
    _inflightSync = future;
    try {
      return await future;
    } finally {
      _inflightSync = null;
    }
  }

  Future<SyncResult> _syncFromRemoteImpl(String userId) async {
    try {
      _logger.info(
        'Syncing saved meals from Supabase',
        context: 'SAVED_MEALS_REPOSITORY',
        data: {'userId': userId},
      );

      // Fetch ALL rows (including tombstones) so deletes propagate.
      final response = await _supabase
          .from('saved_meals')
          .select('*')
          .eq('user_id', userId)
          .order('updated_at', ascending: false);

      final remoteRows = response as List<dynamic>;
      final syncedCount = await _upsertRemotePreservingDirty(remoteRows);

      await setLastSyncTime(DateTime.now());

      _logger.info(
        'Successfully synced saved meals from Supabase',
        context: 'SAVED_MEALS_REPOSITORY',
        data: {'userId': userId, 'count': syncedCount},
      );

      return SyncResult.successful(syncedCount);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to sync saved meals from Supabase',
        context: 'SAVED_MEALS_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {'userId': userId},
      );
      return SyncResult.failed(e.toString());
    }
  }

  @override
  Future<UploadResult> uploadDirtyRecords(String userId) async {
    try {
      _logger.info(
        'Uploading dirty saved meals to Supabase',
        context: 'SAVED_MEALS_REPOSITORY',
        data: {'userId': userId},
      );

      final dirtyEntries = await (_database.select(_database.savedMealsTable)
            ..where(
              (t) => t.needsUpload.equals(true) & t.userId.equals(userId),
            ))
          .get();

      if (dirtyEntries.isEmpty) return UploadResult.nothingToUpload();

      final meals = dirtyEntries.map(SavedMeal.fromDriftEntry).toList();
      final payload = meals.map((m) => m.toSupabaseJson()).toList();

      // CRITICAL: onConflict: 'id' only — see PostgREST partial-index gotcha.
      await _supabase.from('saved_meals').upsert(payload, onConflict: 'id');

      await _database.batch((batch) {
        for (final meal in meals) {
          batch.update(
            _database.savedMealsTable,
            const SavedMealsTableCompanion(needsUpload: Value(false)),
            where: (t) => t.id.equals(meal.id),
          );
        }
      });

      _logger.info(
        'Successfully uploaded dirty saved meals',
        context: 'SAVED_MEALS_REPOSITORY',
        data: {'count': meals.length},
      );

      return UploadResult.successful(meals.length);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to upload dirty saved meals',
        context: 'SAVED_MEALS_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {'userId': userId},
      );
      return UploadResult.failed(e.toString());
    }
  }

  // ========================================================================
  // Query Methods
  // ========================================================================

  /// Watch all non-deleted saved meals for [userId], ordered by
  /// [SavedMeal.lastUsedAt] descending (nulls last), then by [SavedMeal.name]
  /// ascending as a stable tiebreaker.
  Stream<List<SavedMeal>> watchSavedMeals(String userId) {
    final query = _database.select(_database.savedMealsTable)
      ..where(
        (t) => t.userId.equals(userId) & t.isDeleted.equals(false),
      )
      ..orderBy([
        (t) => OrderingTerm(
              expression: t.lastUsedAt,
              mode: OrderingMode.desc,
              nulls: NullsOrder.last,
            ),
        (t) => OrderingTerm.asc(t.name),
      ]);

    return query
        .watch()
        .map((entries) => entries.map(SavedMeal.fromDriftEntry).toList());
  }

  // ========================================================================
  // Mutation Methods
  // ========================================================================

  /// Persist a new saved meal (offline-first).
  ///
  /// Assigns a UUID if [meal.id] is empty.
  Future<SavedMeal> saveMeal(SavedMeal meal) async {
    final now = DateTime.now();
    final toSave = meal.copyWith(
      id: meal.id.isEmpty ? _uuid.v4() : meal.id,
      createdAt: meal.createdAt,
      updatedAt: now,
      isDeleted: false,
      needsUpload: true,
      localUpdatedAt: now,
    );

    await _database
        .into(_database.savedMealsTable)
        .insert(toSave.toDriftCompanion(), mode: InsertMode.insertOrReplace);

    _logger.info(
      'Saved meal created',
      context: 'SAVED_MEALS_REPOSITORY',
      data: {'mealId': toSave.id, 'name': toSave.name},
    );

    _scheduleImmediateUpload(toSave, label: 'save');
    return toSave;
  }

  /// Bump [SavedMeal.lastUsedAt] to now (called when the meal is re-logged).
  Future<void> touchLastUsed(String mealId) async {
    final now = DateTime.now();
    await (_database.update(_database.savedMealsTable)
          ..where((t) => t.id.equals(mealId) & t.isDeleted.equals(false)))
        .write(
      SavedMealsTableCompanion(
        lastUsedAt: Value(now),
        updatedAt: Value(now),
        needsUpload: const Value(true),
        localUpdatedAt: Value(now),
      ),
    );

    _logger.debug(
      'Touched last_used_at for saved meal',
      context: 'SAVED_MEALS_REPOSITORY',
      data: {'mealId': mealId},
    );

    // Best-effort remote update; failure leaves row dirty for next sync.
    unawaited(() async {
      try {
        await _supabase
            .from('saved_meals')
            .update({'last_used_at': now.toUtc().toIso8601String()})
            .eq('id', mealId);
        await (_database.update(_database.savedMealsTable)
              ..where((t) => t.id.equals(mealId)))
            .write(const SavedMealsTableCompanion(needsUpload: Value(false)));
      } catch (e, stackTrace) {
        _logger.warning(
          'touchLastUsed remote update failed; stays dirty for retry',
          context: 'SAVED_MEALS_REPOSITORY',
          error: e,
          stackTrace: stackTrace,
          data: {'mealId': mealId},
        );
      }
    }());
  }

  /// Soft-delete a saved meal by id. No-op if no active row exists.
  Future<void> softDelete(String mealId) async {
    final row = await (_database.select(_database.savedMealsTable)
          ..where((t) => t.id.equals(mealId) & t.isDeleted.equals(false))
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return;

    final meal = SavedMeal.fromDriftEntry(row);
    final now = DateTime.now();

    await (_database.update(_database.savedMealsTable)
          ..where((t) => t.id.equals(mealId)))
        .write(
      SavedMealsTableCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(now),
        needsUpload: const Value(true),
        localUpdatedAt: Value(now),
      ),
    );

    _logger.info(
      'Soft-deleted saved meal',
      context: 'SAVED_MEALS_REPOSITORY',
      data: {'mealId': mealId},
    );

    final tombstone = meal.copyWith(
      isDeleted: true,
      updatedAt: now,
      needsUpload: true,
      localUpdatedAt: now,
    );
    _scheduleImmediateUpload(tombstone, label: 'delete');
  }

  // ========================================================================
  // Remote Hydration
  // ========================================================================

  /// Apply a batch of remote rows to Drift, preserving dirty local rows.
  @visibleForTesting
  Future<int> hydrateFromRemote(
    String userId, {
    DateTime? since,
  }) async {
    final response = await _supabase
        .from('saved_meals')
        .select('*')
        .eq('user_id', userId)
        .order('updated_at', ascending: false);

    final remoteRows = response as List<dynamic>;
    return _upsertRemotePreservingDirty(remoteRows);
  }

  // ========================================================================
  // Private Helpers
  // ========================================================================

  Future<int> _upsertRemotePreservingDirty(List<dynamic> remoteRows) async {
    final remoteById = <String, Map<String, dynamic>>{};
    for (final item in remoteRows) {
      if (item is! Map) continue;
      final mapped = Map<String, dynamic>.from(item);
      final id = mapped['id']?.toString();
      if (id == null || id.isEmpty) continue;
      remoteById[id] = mapped;
    }

    if (remoteById.isEmpty) return 0;

    final remoteIds = remoteById.keys.toList(growable: false);
    final dirtyRows = await (_database.select(_database.savedMealsTable)
          ..where(
            (t) => t.id.isIn(remoteIds) & t.needsUpload.equals(true),
          ))
        .get();
    final dirtyIds = dirtyRows.map((r) => r.id).toSet();

    if (dirtyIds.isNotEmpty) {
      _logger.warning(
        'Skipped remote saved meal overwrite for dirty local rows',
        context: 'SAVED_MEALS_REPOSITORY',
        data: {
          'skippedCount': dirtyIds.length,
          'totalRemote': remoteById.length,
        },
      );
    }

    var upsertedCount = 0;
    await _database.batch((batch) {
      for (final entry in remoteById.entries) {
        if (dirtyIds.contains(entry.key)) continue;

        final meal = SavedMeal.fromSupabaseJson(entry.value);
        batch.insert(
          _database.savedMealsTable,
          meal
              .copyWith(needsUpload: false, localUpdatedAt: DateTime.now())
              .toDriftCompanion(),
          mode: InsertMode.insertOrReplace,
        );
        upsertedCount++;
      }
    });

    return upsertedCount;
  }

  void _scheduleImmediateUpload(SavedMeal meal, {required String label}) {
    unawaited(() async {
      try {
        await _supabase
            .from('saved_meals')
            .upsert(meal.toSupabaseJson(), onConflict: 'id');
        await _clearDirtyFlag(meal.id);
      } catch (e, stackTrace) {
        _logger.warning(
          'Immediate $label upload failed; saved meal stays dirty for retry',
          context: 'SAVED_MEALS_REPOSITORY',
          error: e,
          stackTrace: stackTrace,
          data: {'mealId': meal.id},
        );
        unawaited(
          _sentry.reportNetworkError(
            e,
            url: 'supabase:saved_meals:$label',
            method: 'UPSERT',
            stackTrace: stackTrace,
          ),
        );
      }
    }());
  }

  Future<void> _clearDirtyFlag(String mealId) async {
    await (_database.update(_database.savedMealsTable)
          ..where((t) => t.id.equals(mealId)))
        .write(const SavedMealsTableCompanion(needsUpload: Value(false)));
  }
}
