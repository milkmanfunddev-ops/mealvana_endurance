import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/services/sentry/sentry_reporter.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/sync/sync_dependency_graph.dart';
import '../../../shared/domain/activity_type.dart';
import '../../../shared/data/syncable_repository.dart';
import '../domain/activity.dart' as domain;
import '../domain/brick_metadata.dart';
import 'activity_mapper.dart';
import '../application/activity_deduplication_service.dart';

part 'activities_repository.g.dart';

class _BatchUploadResult {
  const _BatchUploadResult({
    required this.uploadedIds,
    required this.failedIds,
  });

  final Set<String> uploadedIds;
  final Set<String> failedIds;
}

@riverpod
ActivitiesRepository activitiesRepository(Ref ref) {
  final deps = ref.read(appExternalDepsProvider);
  return ActivitiesRepository(
    supabase: Supabase.instance.client,
    database: ref.read(appDatabaseProvider),
    logger: ref.read(appLoggerProvider),
    sentry: deps.sentry,
    deduplicationService: ref.read(activityDeduplicationServiceProvider),
  );
}

/// Repository for managing activities following FOA pattern
/// Implements SyncableRepository for new sync architecture
class ActivitiesRepository with SyncableRepository {
  ActivitiesRepository({
    required SupabaseClient supabase,
    required AppDatabase database,
    required AppLogger logger,
    required SentryReporter sentry,
    required ActivityDeduplicationService deduplicationService,
  }) : _supabase = supabase,
       _database = database,
       _logger = logger,
       _sentry = sentry,
       _mapper = ActivityMapper(logger: logger),
       _deduplicationService = deduplicationService;

  final SupabaseClient _supabase;
  final AppDatabase _database;
  final AppLogger _logger;
  final SentryReporter _sentry;
  final ActivityMapper _mapper;
  final ActivityDeduplicationService _deduplicationService;

  /// Expose mapper for use by ActivitiesService and other consumers.
  ActivityMapper get mapper => _mapper;

  // ========================================================================
  // SyncableRepository Implementation
  // ========================================================================

  @override
  String get repositoryKey => 'activities';

  @override
  List<String> get dependencies =>
      SyncDependencyGraph.dependenciesFor(repositoryKey);

  @override
  Future<SyncResult> syncFromRemote(String userId) async {
    try {
      _logger.info(
        'Syncing activities from Supabase',
        context: 'ACTIVITIES_REPOSITORY',
        data: {'userId': userId},
      );

      // Direct Supabase query (no edge function)
      final response = await _supabase
          .from('activities')
          .select('*')
          .eq('user_id', userId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false);

      final syncedCount = await _upsertRemoteActivitiesPreservingDirty(
        response as List<dynamic>,
      );

      // Update last sync timestamp
      await setLastSyncTime(DateTime.now());

      _logger.info(
        'Activities synced successfully',
        context: 'ACTIVITIES_REPOSITORY',
        data: {'userId': userId, 'count': syncedCount},
      );

      return SyncResult.successful(syncedCount);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to sync activities from remote',
        context: 'ACTIVITIES_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {'userId': userId},
      );
      await _sentry.reportNetworkError(
        e,
        url: 'supabase/activities',
        method: 'SELECT',
        stackTrace: stackTrace,
      );
      return SyncResult.failed(e.toString());
    }
  }

  Future<int> _upsertRemoteActivitiesPreservingDirty(
    List<dynamic> rawActivities,
  ) async {
    final remoteById = <String, Map<String, dynamic>>{};

    for (final item in rawActivities) {
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
        await (_database.select(_database.activitiesTable)..where(
              (tbl) => tbl.id.isIn(remoteIds) & tbl.needsUpload.equals(true),
            ))
            .get();
    final dirtyIds = dirtyRows.map((row) => row.id).toSet();

    var upsertedCount = 0;
    await _database.batch((batch) {
      for (final entry in remoteById.entries) {
        if (dirtyIds.contains(entry.key)) {
          continue;
        }

        final activity = _mapper.fromJson(entry.value);
        batch.insert(
          _database.activitiesTable,
          _mapper.toCompanion(activity),
          mode: InsertMode.insertOrReplace,
        );
        upsertedCount++;
      }
    });

    if (dirtyIds.isNotEmpty) {
      _logger.debug(
        'Skipped remote activity overwrite for dirty local rows',
        context: 'ACTIVITIES_REPOSITORY',
        data: {
          'skippedCount': dirtyIds.length,
          'totalRemote': remoteById.length,
        },
      );
    }

    return upsertedCount;
  }

  @override
  Future<UploadResult> uploadDirtyRecords(String userId) async {
    try {
      // Query Drift for records with needsUpload = true
      final dirtyRecords =
          await (_database.select(_database.activitiesTable)..where(
                (t) =>
                    t.userId.lower().equals(userId.toLowerCase()) &
                    t.needsUpload.equals(true),
              ))
              .get();

      if (dirtyRecords.isEmpty) {
        return UploadResult.nothingToUpload();
      }

      _logger.info(
        'Uploading dirty activities',
        context: 'ACTIVITIES_REPOSITORY',
        data: {'userId': userId, 'count': dirtyRecords.length},
      );

      // Separate records into batches to respect brick_id foreign key constraint.
      // Parent brick activities must be uploaded before sub-activities that
      // reference them via brick_id.
      final parentBricks = <Activity>[];
      final subActivities = <Activity>[];
      final regularActivities = <Activity>[];

      for (final record in dirtyRecords) {
        if (record.brickId != null) {
          subActivities.add(record);
        } else if (record.activityType == 'brick') {
          parentBricks.add(record);
        } else {
          regularActivities.add(record);
        }
      }

      // Ensure parent bricks exist for sub-activities, even if the parent
      // isn't dirty itself. Without this, sub-activities fail the FK constraint
      // when the parent brick was never uploaded or isn't in the dirty set.
      if (subActivities.isNotEmpty) {
        final dirtyParentIds = parentBricks.map((b) => b.id).toSet();
        final missingParentIds = subActivities
            .map((s) => s.brickId!)
            .toSet()
            .difference(dirtyParentIds);

        if (missingParentIds.isNotEmpty) {
          final missingParents = await (_database.select(
            _database.activitiesTable,
          )..where((t) => t.id.isIn(missingParentIds))).get();

          final foundParentIds = missingParents.map((p) => p.id).toSet();

          if (missingParents.isNotEmpty) {
            parentBricks.addAll(missingParents);
            _logger.info(
              'Including non-dirty parent bricks for sub-activity FK',
              context: 'ACTIVITIES_REPOSITORY',
              data: {'parentIds': foundParentIds.toList()},
            );
          }

          // Parents that don't exist locally at all — these sub-activities
          // are truly orphaned. Clear their brick_id locally so the FK
          // constraint doesn't block upload, then move them to the regular
          // batch (re-read from DB so the payload reflects the null).
          final orphanedBrickIds = missingParentIds.difference(foundParentIds);
          if (orphanedBrickIds.isNotEmpty) {
            final orphanedSubIds = subActivities
                .where((s) => orphanedBrickIds.contains(s.brickId))
                .map((s) => s.id)
                .toList();

            _logger.warning(
              'Clearing brick_id on orphaned sub-activities '
              '(parent brick not found locally or remotely)',
              context: 'ACTIVITIES_REPOSITORY',
              data: {
                'orphanedBrickIds': orphanedBrickIds.toList(),
                'subActivityIds': orphanedSubIds,
              },
            );

            // Update local DB: clear brick_id and restore status to
            // 'planned' so the activities reappear as standalone.
            // (archivedForBrick + no brick_id = invisible ghost)
            await (_database.update(
              _database.activitiesTable,
            )..where((t) => t.id.isIn(orphanedSubIds))).write(
              const ActivitiesTableCompanion(
                brickId: Value(null),
                status: Value('planned'),
              ),
            );

            // Re-read the corrected records and move to regular batch
            final corrected = await (_database.select(
              _database.activitiesTable,
            )..where((t) => t.id.isIn(orphanedSubIds))).get();
            subActivities.removeWhere(
              (s) => orphanedBrickIds.contains(s.brickId),
            );
            regularActivities.addAll(corrected);
          }
        }
      }

      final uploadedIds = <String>{};
      final failedIds = <String>{};

      // Upload in order: parent bricks first, then regular, then sub-activities
      final batch1 = [...parentBricks, ...regularActivities];
      if (batch1.isNotEmpty) {
        final batchResult = await _uploadBatchWithRecordRetry(
          batch1,
          batchLabel: 'parent_and_regular',
        );
        uploadedIds.addAll(batchResult.uploadedIds);
        failedIds.addAll(batchResult.failedIds);
      }

      if (subActivities.isNotEmpty) {
        final subBatchResult = await _uploadBatchWithRecordRetry(
          subActivities,
          batchLabel: 'sub_activities',
        );
        uploadedIds.addAll(subBatchResult.uploadedIds);
        failedIds.addAll(subBatchResult.failedIds);
      }

      // Clear dirty flags for successful uploads even if some records failed.
      if (uploadedIds.isNotEmpty) {
        await _database.batch((batch) {
          for (final activityId in uploadedIds) {
            batch.update(
              _database.activitiesTable,
              const ActivitiesTableCompanion(needsUpload: Value(false)),
              where: (t) => t.id.equals(activityId),
            );
          }
        });
      }

      if (failedIds.isNotEmpty) {
        _logger.warning(
          'Dirty activities upload partially failed',
          context: 'ACTIVITIES_REPOSITORY',
          data: {
            'userId': userId,
            'total': dirtyRecords.length,
            'uploaded': uploadedIds.length,
            'failed': failedIds.length,
            'failedIds': failedIds.take(10).toList(),
          },
        );
        return UploadResult.failed(
          'Uploaded ${uploadedIds.length}/${dirtyRecords.length} activities; '
          '${failedIds.length} failed and remain dirty for retry.',
        );
      }

      _logger.info(
        'Dirty activities uploaded successfully',
        context: 'ACTIVITIES_REPOSITORY',
        data: {'userId': userId, 'count': uploadedIds.length},
      );

      return UploadResult.successful(uploadedIds.length);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to upload dirty activities',
        context: 'ACTIVITIES_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {'userId': userId},
      );
      await _sentry.reportNetworkError(
        e,
        url: 'supabase/activities',
        method: 'UPSERT',
        stackTrace: stackTrace,
      );
      return UploadResult.failed(e.toString());
    }
  }

  Future<_BatchUploadResult> _uploadBatchWithRecordRetry(
    List<Activity> records, {
    required String batchLabel,
  }) async {
    if (records.isEmpty) {
      return const _BatchUploadResult(
        uploadedIds: <String>{},
        failedIds: <String>{},
      );
    }

    final uploadedIds = <String>{};
    final failedIds = <String>{};

    try {
      await _uploadDirtyBatch(records);
      uploadedIds.addAll(records.map((record) => record.id));
      return _BatchUploadResult(uploadedIds: uploadedIds, failedIds: failedIds);
    } catch (e, stackTrace) {
      final missingRemoteUser = _isMissingRemoteUserForeignKeyError(e);
      _logger.warning(
        'Dirty activity batch failed, retrying one-by-one',
        context: 'ACTIVITIES_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {
          'batchLabel': batchLabel,
          'count': records.length,
          'code': _postgrestErrorCode(e),
          'missingRemoteUser': missingRemoteUser,
        },
      );

      if (missingRemoteUser) {
        _logger.warning(
          'Skipping one-by-one retry because remote user row is missing',
          context: 'ACTIVITIES_REPOSITORY',
          data: {
            'batchLabel': batchLabel,
            'count': records.length,
            'reason': 'activities_user_id_fkey',
          },
        );
        failedIds.addAll(records.map((record) => record.id));
        return _BatchUploadResult(
          uploadedIds: uploadedIds,
          failedIds: failedIds,
        );
      }
    }

    for (final record in records) {
      try {
        await _uploadDirtyBatch([record]);
        uploadedIds.add(record.id);
      } catch (recordError, recordStackTrace) {
        failedIds.add(record.id);
        _logger.error(
          'Dirty activity record failed upload',
          context: 'ACTIVITIES_REPOSITORY',
          error: recordError,
          stackTrace: recordStackTrace,
          data: {
            ..._dirtyRecordLogData(record),
            'batchLabel': batchLabel,
            'code': _postgrestErrorCode(recordError),
          },
        );
      }
    }

    return _BatchUploadResult(uploadedIds: uploadedIds, failedIds: failedIds);
  }

  String? _postgrestErrorCode(Object error) {
    if (error is PostgrestException) {
      return error.code;
    }
    return null;
  }

  bool _isMissingRemoteUserForeignKeyError(Object error) {
    if (error is PostgrestException) {
      final details = (error.details ?? '').toString().toLowerCase();
      final message = error.message.toString().toLowerCase();
      return error.code == '23503' &&
          (details.contains('activities_user_id_fkey') ||
              details.contains('key (user_id)') ||
              message.contains('activities_user_id_fkey'));
    }

    final raw = error.toString().toLowerCase();
    return raw.contains('activities_user_id_fkey') &&
        raw.contains('key (user_id)');
  }

  Map<String, dynamic> _dirtyRecordLogData(Activity record) {
    return {
      'activityId': record.id,
      'activityType': record.activityType,
      'status': record.status,
      'brickId': record.brickId,
      'syncedFromProvider': record.syncedFromProvider,
      'providerWorkoutId': record.providerWorkoutId,
      'title': record.title,
    };
  }

  /// Upload a dirty batch using provider conflict keys when available.
  Future<void> _uploadDirtyBatch(List<Activity> records) async {
    final providerBacked = <Activity>[];
    final idBacked = <Activity>[];

    for (final record in records) {
      if (_hasProviderConflictKey(
        syncedFromProvider: record.syncedFromProvider,
        providerWorkoutId: record.providerWorkoutId,
      )) {
        providerBacked.add(record);
      } else {
        idBacked.add(record);
      }
    }

    if (idBacked.isNotEmpty) {
      await _upsertWithConflictFallback(
        idBacked.map(_mapper.buildUploadPayloadFromRow).toList(),
        onConflict: 'id',
      );
    }

    if (providerBacked.isNotEmpty) {
      await _upsertWithConflictFallback(
        providerBacked.map(_mapper.buildUploadPayloadFromRow).toList(),
        onConflict: 'user_id,synced_from_provider,provider_workout_id',
        fallbackOnConflict: 'id',
      );
    }
  }

  Future<void> _upsertWithConflictFallback(
    Object payload, {
    required String onConflict,
    String? fallbackOnConflict,
  }) async {
    try {
      await _supabase
          .from('activities')
          .upsert(payload, onConflict: onConflict);
    } catch (e) {
      final canFallback =
          fallbackOnConflict != null &&
          fallbackOnConflict != onConflict &&
          (_isMissingConflictConstraintError(e) ||
              _isDuplicateKeyOnDifferentColumn(e, onConflict));

      if (!canFallback) {
        rethrow;
      }

      _logger.warning(
        'Supabase upsert conflict mismatch, retrying with fallback target',
        context: 'ACTIVITIES_REPOSITORY',
        error: e,
        data: {
          'onConflict': onConflict,
          'fallbackOnConflict': fallbackOnConflict,
          'errorCode': _postgrestErrorCode(e),
        },
      );

      await _supabase
          .from('activities')
          .upsert(payload, onConflict: fallbackOnConflict);
    }
  }

  bool _hasProviderConflictKey({
    required String? syncedFromProvider,
    required String? providerWorkoutId,
  }) {
    return syncedFromProvider != null &&
        syncedFromProvider.trim().isNotEmpty &&
        providerWorkoutId != null &&
        providerWorkoutId.trim().isNotEmpty;
  }

  bool _isMissingConflictConstraintError(Object error) {
    if (error is PostgrestException && error.code == '42P10') {
      return true;
    }

    final message = error.toString().toLowerCase();
    return message.contains(
      'no unique or exclusion constraint matching the on conflict specification',
    );
  }

  /// Detects when a 23505 (unique constraint violation) occurs on a column
  /// that is NOT part of the onConflict target. This happens when the upsert
  /// conflict columns don't match an existing row (e.g. user_id changed) but
  /// the primary key (id) already exists under a different user. In this case,
  /// falling back to onConflict: 'id' will correctly UPDATE instead of INSERT.
  bool _isDuplicateKeyOnDifferentColumn(Object error, String onConflict) {
    if (error is! PostgrestException || error.code != '23505') {
      return false;
    }
    // Only fall back when the violated constraint is NOT the same as onConflict.
    // e.g. onConflict='user_id,synced_from_provider,provider_workout_id' but
    // the violated constraint is 'activities_id_new_unique' (the id column).
    final details = (error.details ?? '').toString().toLowerCase();
    final message = error.message.toLowerCase();
    final conflictColumns = onConflict
        .toLowerCase()
        .split(',')
        .map((c) => c.trim())
        .toSet();
    // If the violated constraint mentions 'id' and 'id' is not in the
    // onConflict columns, the fallback to onConflict:'id' should work.
    final violatesIdConstraint =
        details.contains('key (id)') ||
        message.contains('activities_id_new_unique') ||
        message.contains('activities_pkey');
    return violatesIdConstraint && !conflictColumns.contains('id');
  }

  // ========================================================================
  // Existing Repository Methods (Backwards Compatibility)
  // ========================================================================

  /// Create a new activity (save to Drift first, then sync to Supabase for final ID)
  Future<domain.Activity> createActivity({
    required String deviceId,
    required domain.Activity activity,
    bool requireRemoteAck = false,
  }) async {
    try {
      // STEP 1: Save to Drift IMMEDIATELY with dirty flag
      final generatedId = await _saveToDrift(
        activity.copyWith(needsUpload: true, localUpdatedAt: DateTime.now()),
      );

      // Get the activity back from the database with the generated ID
      final savedActivity = await (_database.select(
        _database.activitiesTable,
      )..where((tbl) => tbl.id.equals(generatedId))).getSingle();

      var activityWithId = _mapper.fromDriftRow(savedActivity);

      // STEP 2: Upload to Supabase SYNCHRONOUSLY
      _logger.info(
        'Uploading new activity to Supabase (sync)',
        context: 'ACTIVITIES_REPOSITORY',
        data: {
          'activityId': activityWithId.id,
          'hasNutritionPlan': activityWithId.nutritionPlanData != null,
        },
      );

      try {
        await _uploadActivityToSupabase(
          activityWithId,
          operation: 'create',
          requireRemoteAck: requireRemoteAck,
        );
      } catch (e, stackTrace) {
        _logger.warning(
          'Immediate upload failed; record stays dirty for retry',
          context: 'ACTIVITIES_REPOSITORY',
          error: e,
          stackTrace: stackTrace,
          data: {'operation': 'create', 'recordId': activityWithId.id},
        );
        _sentry.reportNetworkError(
          e,
          url: 'supabase:activities:create',
          method: 'INSERT',
          stackTrace: stackTrace,
        );
        if (requireRemoteAck) {
          rethrow;
        }
      }

      return activityWithId;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to create activity',
        context: 'ACTIVITIES_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Update an existing activity (offline-first: save to Drift first, background upload)
  Future<domain.Activity> updateActivity({
    required String deviceId,
    required domain.Activity activity,
    bool requireRemoteAck = false,
  }) async {
    try {
      // OFFLINE-FIRST: Save to Drift IMMEDIATELY with dirty flag
      final activityWithDirtyFlag = activity.copyWith(
        needsUpload: true,
        localUpdatedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _saveToDrift(activityWithDirtyFlag);

      if (requireRemoteAck) {
        try {
          await _uploadActivityToSupabase(
            activityWithDirtyFlag,
            operation: 'update',
            requireRemoteAck: true,
          );
        } catch (e, stackTrace) {
          _logger.warning(
            'Immediate upload failed; record stays dirty for retry',
            context: 'ACTIVITIES_REPOSITORY',
            error: e,
            stackTrace: stackTrace,
            data: {'operation': 'update', 'recordId': activityWithDirtyFlag.id},
          );
          _sentry.reportNetworkError(
            e,
            url: 'supabase:activities:update',
            method: 'UPSERT',
            stackTrace: stackTrace,
          );
          rethrow;
        }
      } else {
        // Attempt background upload (non-blocking)
        unawaited(() async {
          try {
            await _uploadActivityToSupabase(
              activityWithDirtyFlag,
              operation: 'update',
            );
          } catch (e, stackTrace) {
            _logger.warning(
              'Immediate upload failed; record stays dirty for retry',
              context: 'ACTIVITIES_REPOSITORY',
              error: e,
              stackTrace: stackTrace,
              data: {
                'operation': 'update',
                'recordId': activityWithDirtyFlag.id,
              },
            );
            _sentry.reportNetworkError(
              e,
              url: 'supabase:activities:update',
              method: 'UPSERT',
              stackTrace: stackTrace,
            );
          }
        }());
      }

      return activityWithDirtyFlag;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to update activity',
        context: 'ACTIVITIES_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Delete an activity (offline-first: mark deleted in Drift first, background upload)
  Future<void> deleteActivity({
    required String deviceId,
    required String activityId,
    bool requireRemoteAck = false,
    String? remoteUserId,
  }) async {
    try {
      final now = DateTime.now();
      final userIdForRemoteDelete = remoteUserId ?? deviceId;

      // OFFLINE-FIRST: Mark as deleted in Drift IMMEDIATELY with dirty flag
      await (_database.update(
        _database.activitiesTable,
      )..where((tbl) => tbl.id.equals(activityId))).write(
        ActivitiesTableCompanion(
          deletedAt: Value(now),
          needsUpload: const Value(true),
          localUpdatedAt: Value(now),
        ),
      );

      // Unlink any events that pointed to this activity so event detail
      // can correctly show "Create Nutrition Plan" after deletion.
      final unlinkedEventsCount =
          await (_database.update(
            _database.eventsTable,
          )..where((tbl) => tbl.activityId.equals(activityId))).write(
            EventsTableCompanion(
              activityId: const Value(null),
              hasNutritionPlan: const Value(false),
              needsUpload: const Value(true),
              localUpdatedAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      if (unlinkedEventsCount > 0) {
        _logger.info(
          'Unlinked events from deleted activity',
          context: 'ACTIVITIES_REPOSITORY',
          data: {
            'activityId': activityId,
            'unlinkedEventsCount': unlinkedEventsCount,
          },
        );
      }

      if (requireRemoteAck) {
        try {
          await _uploadActivityDeletion(userIdForRemoteDelete, activityId);
        } catch (e, stackTrace) {
          _logger.warning(
            'Immediate upload failed; record stays dirty for retry',
            context: 'ACTIVITIES_REPOSITORY',
            error: e,
            stackTrace: stackTrace,
            data: {'operation': 'delete', 'recordId': activityId},
          );
          _sentry.reportNetworkError(
            e,
            url: 'supabase:activities:delete',
            method: 'DELETE',
            stackTrace: stackTrace,
          );
          rethrow;
        }
      } else {
        // Attempt background upload (non-blocking)
        unawaited(() async {
          try {
            await _uploadActivityDeletion(userIdForRemoteDelete, activityId);
          } catch (e, stackTrace) {
            _logger.warning(
              'Immediate upload failed; record stays dirty for retry',
              context: 'ACTIVITIES_REPOSITORY',
              error: e,
              stackTrace: stackTrace,
              data: {'operation': 'delete', 'recordId': activityId},
            );
            _sentry.reportNetworkError(
              e,
              url: 'supabase:activities:delete',
              method: 'DELETE',
              stackTrace: stackTrace,
            );
          }
        }());
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to delete activity',
        context: 'ACTIVITIES_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Update an existing activity directly in Supabase (Remote-only)
  /// Used by coaches to edit athlete activities
  Future<void> updateRemoteActivity(domain.Activity activity) async {
    try {
      final payload = _mapper.buildSupabasePayload(activity);

      await _supabase.from('activities').update(payload).eq('id', activity.id);

      _logger.info(
        'Remote activity updated',
        context: 'ACTIVITIES_REPOSITORY',
        data: {'activityId': activity.id},
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to update remote activity',
        context: 'ACTIVITIES_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {'activityId': activity.id},
      );
      rethrow;
    }
  }

  /// Fetch a single activity from Supabase and upsert it locally,
  /// preserving any dirty local changes. Used to pick up coach-made
  /// updates (e.g. nutrition plans) without a full sync.
  ///
  /// Skips the remote fetch entirely when the local row is dirty
  /// (`needsUpload == true`): a dirty row means the local copy is ahead of
  /// remote (e.g. a nutrition plan was just created offline-first but not yet
  /// uploaded), so pulling the older remote row would only risk transiently
  /// shadowing the local changes. `_upsertRemoteActivitiesPreservingDirty`
  /// also guards this, but returning early closes the timing window between
  /// the dirty write and the sync upload.
  Future<void> refreshActivityFromRemote(String activityId) async {
    final localRow = await (_database.select(
      _database.activitiesTable,
    )..where((tbl) => tbl.id.equals(activityId))).getSingleOrNull();
    if (localRow?.needsUpload == true) {
      _logger.debug(
        'Skipping remote refresh for dirty local activity',
        context: 'ACTIVITIES_REPOSITORY',
        data: {'activityId': activityId},
      );
      return;
    }

    final response = await _supabase
        .from('activities')
        .select()
        .eq('id', activityId)
        .maybeSingle();

    if (response == null) return;

    await _upsertRemoteActivitiesPreservingDirty([response]);
  }

  /// Get a specific activity by ID (REMOTE/SUPABASE)
  /// Used by coaches to view athlete activities without syncing everything locally
  Future<domain.Activity?> getRemoteActivityById(String activityId) async {
    try {
      final response = await _supabase
          .from('activities')
          .select()
          .eq('id', activityId)
          .maybeSingle();

      if (response == null) return null;

      return _mapper.fromJson(response);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get remote activity by ID',
        context: 'ACTIVITIES_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {'activityId': activityId},
      );
      rethrow;
    }
  }

  /// Get a specific activity by ID
  Future<domain.Activity?> getActivityById(
    String userId,
    String activityId,
  ) async {
    try {
      final query = _database.select(_database.activitiesTable)
        ..where(
          (tbl) =>
              tbl.userId.lower().equals(userId.toLowerCase()) &
              tbl.id.equals(activityId) &
              tbl.deletedAt.isNull() &
              (tbl.status.equals('archivedForBrick') |
                      tbl.status.equals('archived_for_brick'))
                  .not(),
        );

      final activity = await query.getSingleOrNull();
      return activity != null ? _mapper.fromDriftRow(activity) : null;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get activity by ID',
        context: 'ACTIVITIES_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get activities for a specific date range
  Future<List<domain.Activity>> getActivitiesForDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final query = _database.select(_database.activitiesTable)
        ..where(
          (tbl) =>
              tbl.userId.lower().equals(userId.toLowerCase()) &
              tbl.scheduledDateTime.isBetweenValues(startDate, endDate) &
              tbl.deletedAt.isNull() &
              (tbl.status.equals('archivedForBrick') |
                      tbl.status.equals('archived_for_brick'))
                  .not(),
        )
        ..orderBy([(tbl) => OrderingTerm.asc(tbl.scheduledDateTime)]);

      final activities = await query.get();
      return activities.map(_mapper.fromDriftRow).toList();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get activities for date range',
        context: 'ACTIVITIES_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get recent completed activities of a given sport, most-recent-first.
  ///
  /// Backs the post-workout carbs/hr baseline: returns the user's completed
  /// activities of [activityType] ordered by completion time (newest first),
  /// excluding soft-deleted rows, brick-archived rows, and [excludeActivityId]
  /// (the session being reviewed). Caller filters/aggregates fuel data.
  Future<List<domain.Activity>> getRecentCompletedActivitiesBySport(
    String userId,
    ActivityType activityType, {
    String? excludeActivityId,
    int limit = 12,
  }) async {
    try {
      final query = _database.select(_database.activitiesTable)
        ..where(
          (tbl) =>
              tbl.userId.lower().equals(userId.toLowerCase()) &
              tbl.activityType.equals(activityType.name) &
              tbl.status.equals('completed') &
              tbl.deletedAt.isNull(),
        )
        ..orderBy([(tbl) => OrderingTerm.desc(tbl.completedAt)])
        // Fetch one extra so excluding the current activity still yields `limit`.
        ..limit(limit + 1);

      final rows = await query.get();
      final activities = rows
          .map(_mapper.fromDriftRow)
          .where((a) => a.id != excludeActivityId)
          .take(limit)
          .toList();
      return activities;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get recent completed activities by sport',
        context: 'ACTIVITIES_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Watches completed activities scheduled on [date]'s local calendar day.
  ///
  /// Backs the Daily Macros consumed totals: completed workouts contribute
  /// their logged during-workout fuel to "eaten today". Day attribution uses
  /// `scheduledDateTime` local wall clock, matching the fuel timeline's
  /// filter. Archived brick segments (`brickId` set) are excluded so a
  /// combined brick and its segments never both count.
  Stream<List<domain.Activity>> watchCompletedActivitiesForDate(
    String userId,
    DateTime date,
  ) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final query = _database.select(_database.activitiesTable)
      ..where(
        (tbl) =>
            tbl.userId.lower().equals(userId.toLowerCase()) &
            tbl.status.equals('completed') &
            tbl.deletedAt.isNull() &
            tbl.brickId.isNull() &
            tbl.scheduledDateTime.isBiggerOrEqualValue(dayStart) &
            tbl.scheduledDateTime.isSmallerThanValue(dayEnd),
      );
    return query.watch().map(
      (rows) => rows.map(_mapper.fromDriftRow).toList(),
    );
  }

  /// Insert a new activity directly (used by sync services)
  ///
  /// Unlike createActivity, this method doesn't immediately upload to Supabase.
  /// Used for batch imports from external providers.
  Future<domain.Activity> insertActivity(domain.Activity activity) async {
    try {
      // If this is a provider-synced activity, check for an existing row
      final provider = activity.syncedFromProvider;
      final providerWorkoutId = activity.providerWorkoutId;
      if (provider != null &&
          providerWorkoutId != null &&
          providerWorkoutId.isNotEmpty) {
        final existing = await _findActivityByProviderKey(
          userId: activity.userId,
          provider: provider,
          providerWorkoutId: providerWorkoutId,
        );
        if (existing != null) {
          final merged = _mergeProviderUpdate(existing, activity);
          return await updateActivityFromProvider(merged);
        }

        // Cross-origin dedup: no provider-keyed row exists, but the user may
        // have created this same run in-app (which has no provider linkage).
        // Reconcile the provider import onto that row instead of inserting a
        // duplicate (Bug 385e3fdb).
        final fingerprintMatch = await findActivityByFingerprint(
          userId: activity.userId,
          activityType: activity.activityType,
          scheduledDate: activity.scheduledDateTime,
          distanceMiles: activity.distanceMiles,
        );
        if (fingerprintMatch != null) {
          final merged = _mergeProviderUpdate(fingerprintMatch, activity);
          _logger.info(
            'Reconciled provider workout onto user-created activity '
            '(cross-origin dedup)',
            context: 'ACTIVITIES_REPOSITORY',
            data: {
              'localActivityId': fingerprintMatch.id,
              'provider': provider,
              'providerWorkoutId': providerWorkoutId,
            },
          );
          return await updateActivityFromProvider(merged);
        }
      }

      // No existing provider workout found: create a new row
      final activityWithFlags = activity.copyWith(
        id: '', // Force INSERT by clearing ID
        needsUpload: true,
        localUpdatedAt: DateTime.now(),
      );

      final generatedId = await _saveToDrift(activityWithFlags);

      final savedActivity = await (_database.select(
        _database.activitiesTable,
      )..where((tbl) => tbl.id.equals(generatedId))).getSingle();

      _logger.info(
        'Inserted activity from sync',
        context: 'ACTIVITIES_REPOSITORY',
        data: {
          'activityId': generatedId,
          'provider': activity.syncedFromProvider,
          'providerWorkoutId': activity.providerWorkoutId,
        },
      );

      return _mapper.fromDriftRow(savedActivity);
    } catch (e, stackTrace) {
      // If insert failed due to a unique constraint, try to resolve by updating
      final provider = activity.syncedFromProvider;
      final providerWorkoutId = activity.providerWorkoutId;
      if (provider != null &&
          providerWorkoutId != null &&
          providerWorkoutId.isNotEmpty) {
        try {
          final existing = await _findActivityByProviderKey(
            userId: activity.userId,
            provider: provider,
            providerWorkoutId: providerWorkoutId,
          );
          if (existing != null) {
            final merged = _mergeProviderUpdate(existing, activity);
            return await updateActivityFromProvider(merged);
          }
        } catch (_) {
          // Fall through to logging/rethrow below
        }
      }

      _logger.error(
        'Failed to insert activity',
        context: 'ACTIVITIES_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Find an existing activity by provider workout key
  Future<domain.Activity?> _findActivityByProviderKey({
    required String userId,
    required String provider,
    required String providerWorkoutId,
  }) async {
    final providerVariants = _providerLookupVariants(provider);
    Activity? bestMatch;

    for (final variant in providerVariants) {
      final query = _database.select(_database.activitiesTable)
        ..where(
          (tbl) =>
              tbl.userId.lower().equals(userId.toLowerCase()) &
              tbl.syncedFromProvider.lower().equals(variant) &
              tbl.providerWorkoutId.equals(providerWorkoutId),
        )
        ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)])
        ..limit(1);

      final match = await query.getSingleOrNull();
      if (match == null) {
        continue;
      }

      if (bestMatch == null || match.updatedAt.isAfter(bestMatch.updatedAt)) {
        bestMatch = match;
      }
    }

    return bestMatch != null ? _mapper.fromDriftRow(bestMatch) : null;
  }

  /// Find an existing *user-created* activity (no provider linkage) that matches
  /// an incoming provider workout by fingerprint: same activity type, scheduled
  /// within ±1 day, and distance within 10%.
  ///
  /// This powers cross-origin deduplication: a run created in-app has
  /// `synced_from_provider`/`provider_workout_id` both null, so when the same
  /// physical run is later completed and synced back from Garmin/Final Surge it
  /// would otherwise be inserted as a second row. The provider-key lookup
  /// ([_findActivityByProviderKey]) can't catch this because the in-app row has
  /// no provider key. We only ever match rows that have NO provider linkage —
  /// provider-synced rows are reconciled via the provider-key path, never by
  /// fingerprint — so this can't accidentally collapse two distinct provider
  /// imports together.
  ///
  /// The scheduled-time window is computed tz-naively (local day bounds), matching
  /// how `scheduled_date_time` is stored (tz-naive) elsewhere in the codebase.
  Future<domain.Activity?> findActivityByFingerprint({
    required String userId,
    required ActivityType activityType,
    required DateTime scheduledDate,
    double? distanceMiles,
  }) async {
    final day = DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
    );
    final lowerBound = day.subtract(const Duration(days: 1));
    // Exclusive upper bound covering the whole of scheduledDate + 1 day.
    final upperBound = day.add(const Duration(days: 2));

    final query = _database.select(_database.activitiesTable)
      ..where(
        (tbl) =>
            tbl.userId.lower().equals(userId.toLowerCase()) &
            tbl.activityType.equals(activityType.name) &
            tbl.deletedAt.isNull() &
            tbl.scheduledDateTime.isBiggerOrEqualValue(lowerBound) &
            tbl.scheduledDateTime.isSmallerThanValue(upperBound),
      )
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.scheduledDateTime)]);

    final rows = await query.get();
    for (final row in rows) {
      // Only match user-created rows (no provider linkage).
      final hasProviderLink =
          row.providerWorkoutId != null && row.providerWorkoutId!.isNotEmpty;
      if (hasProviderLink) {
        continue;
      }

      // If both distances are known, require them within 10%.
      if (distanceMiles != null && distanceMiles > 0) {
        final localDistance = row.distanceMiles;
        if (localDistance == null || localDistance <= 0) {
          continue;
        }
        final pctDiff = (localDistance - distanceMiles).abs() / distanceMiles;
        if (pctDiff > 0.10) {
          continue;
        }
      }

      return _mapper.fromDriftRow(row);
    }

    return null;
  }

  /// Merge latest provider data into an existing activity while preserving
  /// local-only fields (nutrition plan, completion, reminders, brick metadata).
  domain.Activity _mergeProviderUpdate(
    domain.Activity existing,
    domain.Activity incoming,
  ) {
    return domain.Activity(
      // identity
      id: existing.id,
      userId: existing.userId,

      // provider-owned workout data (allow null overwrites)
      activityType: incoming.activityType,
      title: incoming.title,
      scheduledDateTime: incoming.scheduledDateTime,
      status: existing.status,
      distanceMiles: incoming.distanceMiles,
      durationMinutes: incoming.durationMinutes,
      paceTargetMinutesPerMile: incoming.paceTargetMinutesPerMile,
      intensityLevel: incoming.intensityLevel,
      cyclingSpeedMph: incoming.cyclingSpeedMph,
      cyclingTerrain: incoming.cyclingTerrain,
      cyclingIndoorOutdoor: incoming.cyclingIndoorOutdoor,
      cyclingElevationGainFt: incoming.cyclingElevationGainFt,
      cyclingSessionGoal: incoming.cyclingSessionGoal,
      swimmingPacePer100mSeconds: incoming.swimmingPacePer100mSeconds,
      swimmingPoolOrOpenWater: incoming.swimmingPoolOrOpenWater,
      swimmingWaterTempC: incoming.swimmingWaterTempC,
      intensityTarget: incoming.intensityTarget,
      intensityDistribution: incoming.intensityDistribution,
      timeBeforeMinutes: incoming.timeBeforeMinutes,
      notes: incoming.notes,

      // preserve local completion and nutrition data
      completedAt: existing.completedAt,
      completionRating: existing.completionRating,
      nutritionRating: existing.nutritionRating,
      completionNotes: existing.completionNotes,
      actualDistanceMiles: existing.actualDistanceMiles,
      actualDurationMinutes: existing.actualDurationMinutes,
      nutritionPlanData: existing.nutritionPlanData,
      // Preserve the locally-logged fuel data; provider imports never carry it.
      fuelLogData: existing.fuelLogData,

      // Adopt provider device/summary identifiers so the surviving row shows
      // the device badge (Activity.hasGarminData), falling back to whatever the
      // existing row already had.
      garminSummaryId: incoming.garminSummaryId ?? existing.garminSummaryId,
      garminDeviceName: incoming.garminDeviceName ?? existing.garminDeviceName,

      // preserve local metadata
      createdAt: existing.createdAt,
      updatedAt: existing.updatedAt,
      deletedAt: existing.deletedAt,
      reminderEnabled: existing.reminderEnabled,
      reminderDaysBefore: existing.reminderDaysBefore,
      reminderTimeOfDay: existing.reminderTimeOfDay,
      reminderRecurring: existing.reminderRecurring,
      needsUpload: existing.needsUpload,
      localUpdatedAt: existing.localUpdatedAt,

      // provider sync tracking
      syncedFromProvider: incoming.syncedFromProvider,
      providerWorkoutId: incoming.providerWorkoutId,
      providerWorkoutUrl: incoming.providerWorkoutUrl,
      lastSyncedAt: incoming.lastSyncedAt,
      workoutSubtype: incoming.workoutSubtype,
      paceMinMinutesPerMile: incoming.paceMinMinutesPerMile,
      paceMaxMinutesPerMile: incoming.paceMaxMinutesPerMile,
      needsNutritionRefresh: incoming.needsNutritionRefresh,
      providerDeletedAt: incoming.providerDeletedAt,
      providerScheduledAt: incoming.providerScheduledAt,
      scheduleChangedAt: incoming.scheduleChangedAt,

      // preserve brick grouping metadata
      brickMetadata: existing.brickMetadata,
      brickId: existing.brickId,
    );
  }

  /// Save activity to Drift database (offline-first pattern)
  /// Returns the ID of the saved activity (auto-generated if creating new)
  Future<String> _saveToDrift(domain.Activity activity) async {
    // Log nutrition plan data presence for debugging
    if (activity.nutritionPlanData != null) {
      final jsonString = jsonEncode(activity.nutritionPlanData);
      _logger.info(
        'Saving activity with nutrition plan data',
        context: 'ACTIVITIES_REPOSITORY',
        data: {
          'activityId': activity.id,
          'hasNutritionPlan': true,
          'nutritionPlanDataSize': jsonString.length,
        },
      );
    } else {
      _logger.debug(
        'Saving activity without nutrition plan data',
        context: 'ACTIVITIES_REPOSITORY',
        data: {'activityId': activity.id, 'hasNutritionPlan': false},
      );
    }

    final isInsert = activity.id.isEmpty;
    final companion = _mapper.toCompanion(activity, forInsert: isInsert);

    if (isInsert) {
      // CREATE: New activity - let database generate UUID
      final insertedRow = await _database
          .into(_database.activitiesTable)
          .insertReturning(companion);

      _logger.debug(
        'Created new activity',
        context: 'ACTIVITIES_REPOSITORY',
        data: {'activityId': insertedRow.id},
      );

      return insertedRow.id;
    } else {
      // UPDATE: Existing activity - update by ID
      await (_database.update(
        _database.activitiesTable,
      )..where((tbl) => tbl.id.equals(activity.id))).write(companion);

      _logger.debug(
        'Updated existing activity',
        context: 'ACTIVITIES_REPOSITORY',
        data: {'activityId': activity.id},
      );

      return activity.id;
    }
  }

  /// Upload activity to Supabase
  Future<void> _uploadActivityToSupabase(
    domain.Activity activity, {
    required String operation,
    bool requireRemoteAck = false,
  }) async {
    final payload = _mapper.buildSupabasePayload(
      activity,
      includeCreatedAt: true,
    );

    if (operation == 'create') {
      if (requireRemoteAck) {
        final response = await _supabase
            .from('activities')
            .insert(payload)
            .select('id,user_id,nutrition_plan_data')
            .maybeSingle();
        _verifyRemoteAckResult(
          activity: activity,
          operation: operation,
          response: response,
        );
      } else {
        await _supabase.from('activities').insert(payload);
      }
    } else {
      if (requireRemoteAck) {
        // For coach-critical flows, require deterministic update on the exact row.
        // Upsert can silently "succeed" while missing the intended row.
        final response = await _supabase
            .from('activities')
            .update(payload)
            .eq('id', activity.id)
            .select('id,user_id,nutrition_plan_data')
            .maybeSingle();
        _verifyRemoteAckResult(
          activity: activity,
          operation: operation,
          response: response,
        );
      } else {
        final hasProviderKey = _hasProviderConflictKey(
          syncedFromProvider: activity.syncedFromProvider,
          providerWorkoutId: activity.providerWorkoutId,
        );

        await _upsertWithConflictFallback(
          payload,
          onConflict: hasProviderKey
              ? 'user_id,synced_from_provider,provider_workout_id'
              : 'id',
          fallbackOnConflict: hasProviderKey ? 'id' : null,
        );
      }
    }

    _logger.info(
      'Activity uploaded to Supabase with UUID',
      context: 'ACTIVITIES_REPOSITORY',
      data: {'activityId': activity.id, 'operation': operation},
    );

    await _clearDirtyFlag(activity.id);
  }

  void _verifyRemoteAckResult({
    required domain.Activity activity,
    required String operation,
    required dynamic response,
  }) {
    if (response is! Map<String, dynamic>) {
      throw StateError(
        'Remote ack failed for activity ${activity.id}: no row returned after $operation',
      );
    }

    final remoteId = response['id']?.toString();
    if (remoteId == null || remoteId != activity.id) {
      throw StateError(
        'Remote ack failed for activity ${activity.id}: unexpected row returned ($remoteId) after $operation',
      );
    }

    final remoteUserId = response['user_id']?.toString();
    if (remoteUserId == null || remoteUserId != activity.userId) {
      throw StateError(
        'Remote ack failed for activity ${activity.id}: unexpected owner ($remoteUserId) after $operation',
      );
    }

    final expectsNutritionPlan = activity.nutritionPlanData != null;
    final hasRemoteNutritionPlan = response['nutrition_plan_data'] != null;
    if (expectsNutritionPlan && !hasRemoteNutritionPlan) {
      throw StateError(
        'Remote ack failed for activity ${activity.id}: nutrition plan missing after $operation',
      );
    }
  }

  /// Upload activity deletion to Supabase in background (non-blocking)
  Future<void> _uploadActivityDeletion(String userId, String activityId) async {
    await _supabase
        .from('activities')
        .delete()
        .eq('id', activityId)
        .eq('user_id', userId);

    // Upload successful - hard delete from local database
    await (_database.delete(
      _database.activitiesTable,
    )..where((tbl) => tbl.id.equals(activityId))).go();
  }

  Future<void> _queueImmediateActivityUpsertById(
    String activityId, {
    required String operation,
  }) async {
    final row = await (_database.select(
      _database.activitiesTable,
    )..where((tbl) => tbl.id.equals(activityId))).getSingleOrNull();
    if (row == null) return;

    final activity = _mapper.fromDriftRow(row);
    unawaited(() async {
      try {
        await _uploadActivityToSupabase(activity, operation: 'update');
      } catch (e, stackTrace) {
        _logger.warning(
          'Immediate upload failed; record stays dirty for retry',
          context: 'ACTIVITIES_REPOSITORY',
          error: e,
          stackTrace: stackTrace,
          data: {'operation': operation, 'recordId': activityId},
        );
        _sentry.reportNetworkError(
          e,
          url: 'supabase:activities:$operation',
          method: 'UPSERT',
          stackTrace: stackTrace,
        );
      }
    }());
  }

  /// Clear dirty flag after successful upload
  Future<void> _clearDirtyFlag(String activityId) async {
    await (_database.update(_database.activitiesTable)
          ..where((tbl) => tbl.id.equals(activityId)))
        .write(const ActivitiesTableCompanion(needsUpload: Value(false)));
  }

  // ========================================================================
  // Provider Integration Methods
  // ========================================================================

  /// Get all activities from a specific provider for a user
  Future<List<domain.Activity>> getActivitiesByUserAndProvider(
    String userId,
    String provider,
  ) async {
    try {
      final providerVariants = _providerLookupVariants(provider);
      var activities = await _loadLocalProviderActivities(
        userId: userId,
        providerVariants: providerVariants,
      );

      if (activities.isEmpty) {
        _logger.debug(
          'No local provider activities found - attempting remote hydration',
          context: 'ACTIVITIES_REPOSITORY',
          data: {
            'userId': userId,
            'provider': provider,
            'providerVariants': providerVariants,
          },
        );

        try {
          activities = await _hydrateProviderActivitiesFromRemote(
            userId: userId,
            providerVariants: providerVariants,
          );
        } catch (e, stackTrace) {
          _logger.warning(
            'Remote hydration for provider activities failed',
            context: 'ACTIVITIES_REPOSITORY',
            error: e,
            stackTrace: stackTrace,
            data: {'userId': userId, 'provider': provider},
          );
        }
      }

      final removedDuplicates = activities.length > 1
          ? await cleanupDuplicateProviderActivities(
              userId: userId,
              provider: provider,
            )
          : 0;

      if (removedDuplicates > 0) {
        activities = await _loadLocalProviderActivities(
          userId: userId,
          providerVariants: providerVariants,
        );
      }

      _logger.info(
        'Retrieved activities by provider',
        context: 'ACTIVITIES_REPOSITORY',
        data: {
          'userId': userId,
          'provider': provider,
          'count': activities.length,
        },
      );

      return activities.map(_mapper.fromDriftRow).toList();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get activities by provider',
        context: 'ACTIVITIES_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {'userId': userId, 'provider': provider},
      );
      rethrow;
    }
  }

  /// Remove duplicate provider-synced activities for a user/provider pair.
  /// Uses ActivityDeduplicationService to identify duplicates, then removes them.
  Future<int> cleanupDuplicateProviderActivities({
    required String userId,
    required String provider,
  }) async {
    try {
      final rows = await _loadLocalProviderActivities(
        userId: userId,
        providerVariants: _providerLookupVariants(provider),
      );

      if (rows.length < 2) return 0;

      // Use deduplication service to identify duplicates
      final result = _deduplicationService.identifyDuplicates(rows);
      final duplicates = result.duplicates;

      if (duplicates.isEmpty) return 0;

      // Delete from local database
      await _database.batch((batch) {
        for (final duplicate in duplicates) {
          batch.deleteWhere(
            _database.activitiesTable,
            (tbl) => tbl.id.equals(duplicate.id),
          );
        }
      });

      // Best-effort remote cleanup so deleted duplicates don't rehydrate
      for (final duplicate in duplicates) {
        try {
          await _supabase
              .from('activities')
              .delete()
              .eq('id', duplicate.id)
              .eq('user_id', duplicate.userId);
        } catch (e) {
          _logger.warning(
            'Failed to delete duplicate activity from Supabase',
            context: 'ACTIVITIES_REPOSITORY',
            error: e,
            data: {
              'activityId': duplicate.id,
              'userId': duplicate.userId,
              'provider': provider,
            },
          );
        }
      }

      _logger.debug(
        'Removed duplicate provider activities',
        context: 'ACTIVITIES_REPOSITORY',
        data: {
          'userId': userId,
          'provider': provider,
          'removedCount': duplicates.length,
        },
      );

      return duplicates.length;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to cleanup duplicate provider activities',
        context: 'ACTIVITIES_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {'userId': userId, 'provider': provider},
      );
      return 0;
    }
  }

  /// Get provider name variants for case-insensitive lookup.
  List<String> _providerLookupVariants(String provider) {
    final normalized = provider.trim().toLowerCase();
    final variants = <String>{normalized};

    switch (normalized) {
      case 'training_peaks':
        variants.addAll(const ['trainingpeaks', 'training peaks']);
        break;
      case 'final_surge':
        variants.addAll(const ['finalsurge', 'final surge']);
        break;
      case 'vdot':
        variants.addAll(const ['v.o2', 'v02', 'vo2', 'vdoto2']);
        break;
      default:
        break;
    }

    return variants.toList(growable: false);
  }

  /// Load all provider activities for the given user and provider variants.
  Future<List<Activity>> _loadLocalProviderActivities({
    required String userId,
    required List<String> providerVariants,
  }) async {
    final byId = <String, Activity>{};

    for (final providerVariant in providerVariants) {
      final query = _database.select(_database.activitiesTable)
        ..where(
          (tbl) =>
              tbl.userId.lower().equals(userId.toLowerCase()) &
              tbl.syncedFromProvider.lower().equals(providerVariant) &
              tbl.deletedAt.isNull(),
        );

      final rows = await query.get();
      for (final row in rows) {
        byId[row.id] = row;
      }
    }

    final activities = byId.values.toList();
    activities.sort(
      (a, b) => b.scheduledDateTime.compareTo(a.scheduledDateTime),
    );
    return activities;
  }

  Future<List<Activity>> _hydrateProviderActivitiesFromRemote({
    required String userId,
    required List<String> providerVariants,
  }) async {
    final remoteById = <String, Map<String, dynamic>>{};

    for (final providerVariant in providerVariants) {
      final response = await _supabase
          .from('activities')
          .select('*')
          .eq('user_id', userId)
          .eq('synced_from_provider', providerVariant)
          .isFilter('deleted_at', null)
          .order('updated_at', ascending: false);

      for (final item in response as List) {
        if (item is! Map) continue;
        final json = Map<String, dynamic>.from(item);
        final id = json['id']?.toString();
        if (id == null || id.isEmpty) continue;
        remoteById[id] = json;
      }
    }

    if (remoteById.isEmpty) {
      return const [];
    }

    final syncedCount = await _upsertRemoteActivitiesPreservingDirty(
      remoteById.values.toList(growable: false),
    );

    _logger.info(
      'Hydrated provider activities from Supabase',
      context: 'ACTIVITIES_REPOSITORY',
      data: {
        'userId': userId,
        'providerVariants': providerVariants,
        'count': syncedCount,
      },
    );

    return _loadLocalProviderActivities(
      userId: userId,
      providerVariants: providerVariants,
    );
  }

  /// Update an activity from provider sync (preserves nutrition data)
  Future<domain.Activity> updateActivityFromProvider(
    domain.Activity activity,
  ) async {
    try {
      _logger.info(
        'Updating activity from provider sync',
        context: 'ACTIVITIES_REPOSITORY',
        data: {
          'activityId': activity.id,
          'provider': activity.syncedFromProvider,
          'providerWorkoutId': activity.providerWorkoutId,
        },
      );

      // Merge incoming provider fields with existing local data
      final existingRow = await (_database.select(
        _database.activitiesTable,
      )..where((tbl) => tbl.id.equals(activity.id))).getSingleOrNull();
      final existing = existingRow != null
          ? _mapper.fromDriftRow(existingRow)
          : null;
      final merged = existing != null
          ? _mergeProviderUpdate(existing, activity)
          : activity;

      // Preserve existing stale flag unless new update explicitly sets it
      final keepRefreshFlag = existing?.needsNutritionRefresh == true;

      final now = DateTime.now();
      final activityWithFlags = merged.copyWith(
        needsNutritionRefresh: keepRefreshFlag
            ? true
            : activity.needsNutritionRefresh,
        providerDeletedAt:
            activity.providerDeletedAt ?? existing?.providerDeletedAt,
        providerScheduledAt:
            activity.providerScheduledAt ?? existing?.providerScheduledAt,
        scheduleChangedAt:
            activity.scheduleChangedAt ?? existing?.scheduleChangedAt,
        needsUpload: true,
        localUpdatedAt: now,
        updatedAt: now,
      );

      await _saveToDrift(activityWithFlags);

      unawaited(() async {
        try {
          await _uploadActivityToSupabase(
            activityWithFlags,
            operation: 'update',
          );
        } catch (e, stackTrace) {
          _logger.warning(
            'Immediate upload failed; record stays dirty for retry',
            context: 'ACTIVITIES_REPOSITORY',
            error: e,
            stackTrace: stackTrace,
            data: {
              'operation': 'provider_update',
              'recordId': activityWithFlags.id,
            },
          );
          _sentry.reportNetworkError(
            e,
            url: 'supabase:activities:provider_update',
            method: 'UPSERT',
            stackTrace: stackTrace,
          );
        }
      }());

      _logger.info(
        'Activity updated from provider',
        context: 'ACTIVITIES_REPOSITORY',
        data: {'activityId': activity.id},
      );

      return activityWithFlags;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to update activity from provider',
        context: 'ACTIVITIES_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {'activityId': activity.id},
      );
      rethrow;
    }
  }

  /// Soft-delete an activity that was removed from provider
  Future<void> softDeleteFromProvider(String activityId) async {
    try {
      _logger.info(
        'Soft-deleting activity from provider',
        context: 'ACTIVITIES_REPOSITORY',
        data: {'activityId': activityId},
      );

      final now = DateTime.now();

      await (_database.update(
        _database.activitiesTable,
      )..where((tbl) => tbl.id.equals(activityId))).write(
        ActivitiesTableCompanion(
          providerDeletedAt: Value(now),
          needsUpload: const Value(true),
          localUpdatedAt: Value(now),
        ),
      );

      await _queueImmediateActivityUpsertById(
        activityId,
        operation: 'provider_soft_delete',
      );

      _logger.info(
        'Activity soft-deleted from provider',
        context: 'ACTIVITIES_REPOSITORY',
        data: {'activityId': activityId},
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to soft-delete activity from provider',
        context: 'ACTIVITIES_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {'activityId': activityId},
      );
      rethrow;
    }
  }

  /// Clear nutrition refresh flag after regeneration
  Future<void> clearNutritionRefreshFlag(String activityId) async {
    try {
      _logger.info(
        'Clearing nutrition refresh flag',
        context: 'ACTIVITIES_REPOSITORY',
        data: {'activityId': activityId},
      );

      final now = DateTime.now();

      await (_database.update(
        _database.activitiesTable,
      )..where((tbl) => tbl.id.equals(activityId))).write(
        ActivitiesTableCompanion(
          needsNutritionRefresh: const Value(false),
          needsUpload: const Value(true),
          localUpdatedAt: Value(now),
        ),
      );

      await _queueImmediateActivityUpsertById(
        activityId,
        operation: 'nutrition_refresh_cleared',
      );

      _logger.info(
        'Nutrition refresh flag cleared',
        context: 'ACTIVITIES_REPOSITORY',
        data: {'activityId': activityId},
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to clear nutrition refresh flag',
        context: 'ACTIVITIES_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {'activityId': activityId},
      );
      rethrow;
    }
  }

  // ========================================================================
  // Brick Workout Methods
  // ========================================================================

  /// Get archived activities for a specific brick
  Future<List<domain.Activity>> getArchivedActivitiesForBrick(
    String brickId,
  ) async {
    try {
      final query = _database.select(_database.activitiesTable)
        ..where(
          (tbl) =>
              tbl.brickId.equals(brickId) &
              (tbl.status.equals('archivedForBrick') |
                  tbl.status.equals('archived_for_brick')) &
              tbl.deletedAt.isNull(),
        )
        ..orderBy([(tbl) => OrderingTerm.asc(tbl.scheduledDateTime)]);

      final results = await query.get();
      return results.map(_mapper.fromDriftRow).toList();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get archived activities for brick',
        context: 'ACTIVITIES_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {'brickId': brickId},
      );
      rethrow;
    }
  }

  /// Create a brick activity from existing activities
  Future<domain.Activity> createBrickFromActivities({
    required List<domain.Activity> activities,
    required List<String> segmentOrder,
  }) async {
    try {
      if (activities.length < 2 || activities.length > 3) {
        throw ArgumentError('Brick must have 2-3 activities');
      }

      if (segmentOrder.length != activities.length) {
        throw ArgumentError('Segment order must match activities length');
      }

      // Use transaction to ensure atomicity
      return await _database.transaction(() async {
        // Step 1: Build BrickSegment list from activities
        final segments = <BrickSegment>[];
        int totalDurationMinutes = 0;

        for (int i = 0; i < activities.length; i++) {
          final activity = activities[i];
          final sport = activity.activityType.name;

          // Calculate duration from distance/speed if not directly available
          int durationMinutes = activity.durationMinutes ?? 0;

          if (durationMinutes == 0) {
            // Cycling: duration = distance / speed * 60
            if (activity.activityType == ActivityType.cycling &&
                activity.distanceMiles != null &&
                activity.cyclingSpeedMph != null &&
                activity.cyclingSpeedMph! > 0) {
              durationMinutes =
                  ((activity.distanceMiles! / activity.cyclingSpeedMph!) * 60)
                      .round();
            }
            // Swimming: duration = (distance / 100) * pace / 60
            else if (activity.activityType == ActivityType.swimming &&
                activity.distanceMiles != null &&
                activity.swimmingPacePer100mSeconds != null &&
                activity.swimmingPacePer100mSeconds! > 0) {
              final distanceMeters = activity.distanceMiles! * 1609.34;
              final numberOfHundredMeters = distanceMeters / 100;
              durationMinutes =
                  ((numberOfHundredMeters *
                              activity.swimmingPacePer100mSeconds!) /
                          60)
                      .round();
            }
            // Running: duration = distance * pace
            else if (activity.activityType == ActivityType.running &&
                activity.distanceMiles != null &&
                activity.paceTargetMinutesPerMile != null &&
                activity.paceTargetMinutesPerMile! > 0) {
              durationMinutes =
                  (activity.distanceMiles! * activity.paceTargetMinutesPerMile!)
                      .round();
            }
          }

          totalDurationMinutes += durationMinutes;

          double? speedMph = activity.cyclingSpeedMph;
          if ((speedMph == null || speedMph <= 0) &&
              activity.activityType == ActivityType.cycling &&
              activity.distanceMiles != null &&
              activity.distanceMiles! > 0 &&
              durationMinutes > 0) {
            final hours = durationMinutes / 60.0;
            if (hours > 0) {
              speedMph = activity.distanceMiles! / hours;
            }
          }

          int? pacePer100mSeconds = activity.swimmingPacePer100mSeconds;
          if ((pacePer100mSeconds == null || pacePer100mSeconds <= 0) &&
              activity.activityType == ActivityType.swimming &&
              activity.distanceMiles != null &&
              activity.distanceMiles! > 0 &&
              durationMinutes > 0) {
            final distanceMeters = activity.distanceMiles! * 1609.34;
            final numberOfHundredMeters = distanceMeters / 100;
            if (numberOfHundredMeters > 0) {
              pacePer100mSeconds =
                  ((durationMinutes * 60) / numberOfHundredMeters).round();
            }
          }

          double? paceMinutesPerMile = activity.paceTargetMinutesPerMile;
          if ((paceMinutesPerMile == null || paceMinutesPerMile <= 0) &&
              activity.activityType == ActivityType.running &&
              activity.distanceMiles != null &&
              activity.distanceMiles! > 0 &&
              durationMinutes > 0) {
            paceMinutesPerMile = durationMinutes / activity.distanceMiles!;
          }

          final segment = BrickSegment(
            sport: sport,
            order: i + 1,
            durationMinutes: durationMinutes,
            intensity: activity.intensityLevel?.name ?? 'moderate',
            // Swimming fields
            distanceMeters: activity.activityType == ActivityType.swimming
                ? (activity.distanceMiles != null
                      ? activity.distanceMiles! * 1609.34
                      : null)
                : null,
            pacePer100mSeconds: pacePer100mSeconds,
            poolOrOpenWater: activity.swimmingPoolOrOpenWater,
            waterTempC: activity.swimmingWaterTempC,
            // Cycling fields
            distanceMiles:
                activity.activityType == ActivityType.cycling ||
                    activity.activityType == ActivityType.running
                ? activity.distanceMiles
                : null,
            speedMph: speedMph,
            terrain: activity.cyclingTerrain,
            indoorOutdoor: activity.cyclingIndoorOutdoor,
            elevationGainFt: activity.cyclingElevationGainFt,
            // Running fields
            paceMinutesPerMile: paceMinutesPerMile,
          );

          segments.add(segment);
        }

        // Step 2: Create BrickMetadata
        final brickMetadata = BrickMetadata(
          segmentOrder: segmentOrder,
          segments: segments,
          originalActivityIds: activities.map((a) => a.id).toList(),
          createdFromExisting: true,
          totalDurationMinutes: totalDurationMinutes,
        );

        // Step 3: Create brick activity title (e.g., "SWIM/RUN BRICK")
        final sportNames = segmentOrder
            .map((sport) => sport.toUpperCase())
            .join('/');
        final brickTitle = '$sportNames BRICK';

        // Step 4: Create the brick activity
        final now = DateTime.now();
        final userId = activities.first.userId;
        final scheduledDateTime = activities.first.scheduledDateTime;

        final brickActivity = domain.Activity(
          id: '', // Will be auto-generated by database
          userId: userId,
          activityType: ActivityType.brick,
          title: brickTitle,
          scheduledDateTime: scheduledDateTime,
          status: domain.ActivityStatus.planned,
          durationMinutes: totalDurationMinutes,
          brickMetadata: brickMetadata,
          createdAt: now,
          updatedAt: now,
          needsUpload: true,
          localUpdatedAt: now,
        );

        // Save brick activity and get generated ID
        final brickId = await _saveToDrift(brickActivity);

        _logger.info(
          'Created brick activity',
          context: 'ACTIVITIES_REPOSITORY',
          data: {
            'brickId': brickId,
            'segmentCount': segments.length,
            'totalDuration': totalDurationMinutes,
          },
        );

        // Step 5: Archive original activities and link to brick
        for (final activity in activities) {
          final archivedActivity = activity.copyWith(
            status: domain.ActivityStatus.archivedForBrick,
            brickId: brickId,
            needsUpload: true,
            localUpdatedAt: now,
            updatedAt: now,
          );

          await _saveToDrift(archivedActivity);
        }

        _logger.info(
          'Archived original activities for brick',
          context: 'ACTIVITIES_REPOSITORY',
          data: {'brickId': brickId, 'archivedCount': activities.length},
        );

        // Return the created brick activity (fetch from DB to get full object)
        final savedBrick = await (_database.select(
          _database.activitiesTable,
        )..where((tbl) => tbl.id.equals(brickId))).getSingle();

        return _mapper.fromDriftRow(savedBrick);
      });
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to create brick from activities',
        context: 'ACTIVITIES_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {
          'activityCount': activities.length,
          'segmentOrder': segmentOrder,
        },
      );

      // Check if this is a schema error - if so, close DB, delete files, and trigger resync
      if (AppDatabase.isSchemaError(e)) {
        await AppDatabase.handleSchemaError(
          e,
          context: 'createBrickFromActivities',
          database: _database,
        );
      }

      rethrow;
    }
  }

  /// Ungroup a brick workout
  Future<void> ungroupBrick(String brickId) async {
    String? userIdForSupabaseDelete;

    try {
      // Use transaction to ensure atomicity for local Drift operations
      await _database.transaction(() async {
        // Step 1: Get the brick activity
        final brickQuery = _database.select(_database.activitiesTable)
          ..where((tbl) => tbl.id.equals(brickId) & tbl.deletedAt.isNull());

        final brickActivity = await brickQuery.getSingleOrNull();
        if (brickActivity == null) {
          throw StateError('Brick activity not found: $brickId');
        }

        // Store userId for Supabase deletion after transaction completes
        userIdForSupabaseDelete = brickActivity.userId;

        // Step 2: Get archived activities
        final archivedActivities = await getArchivedActivitiesForBrick(brickId);

        if (archivedActivities.isEmpty) {
          _logger.debug(
            'No archived activities found for brick',
            context: 'ACTIVITIES_REPOSITORY',
            data: {'brickId': brickId},
          );
        }

        // Step 3: Restore archived activities
        final now = DateTime.now();
        for (final activity in archivedActivities) {
          final restoredActivity = activity.copyWith(
            status: domain.ActivityStatus.planned,
            brickId: null,
            needsUpload: true,
            localUpdatedAt: now,
            updatedAt: now,
          );

          await _saveToDrift(restoredActivity);
        }

        _logger.info(
          'Restored archived activities',
          context: 'ACTIVITIES_REPOSITORY',
          data: {
            'brickId': brickId,
            'restoredCount': archivedActivities.length,
          },
        );

        // Step 4: Hard delete the brick activity from Drift
        await (_database.delete(
          _database.activitiesTable,
        )..where((tbl) => tbl.id.equals(brickId))).go();

        _logger.info(
          'Hard deleted brick activity from Drift',
          context: 'ACTIVITIES_REPOSITORY',
          data: {'brickId': brickId},
        );
      });

      // Step 5: Delete from Supabase AFTER transaction completes (non-blocking)
      if (userIdForSupabaseDelete != null) {
        unawaited(() async {
          try {
            await _uploadActivityDeletion(userIdForSupabaseDelete!, brickId);
          } catch (e, stackTrace) {
            _logger.warning(
              'Immediate upload failed; record stays dirty for retry',
              context: 'ACTIVITIES_REPOSITORY',
              error: e,
              stackTrace: stackTrace,
              data: {'operation': 'delete', 'recordId': brickId},
            );
            _sentry.reportNetworkError(
              e,
              url: 'supabase:activities:delete',
              method: 'DELETE',
              stackTrace: stackTrace,
            );
          }
        }());
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to ungroup brick',
        context: 'ACTIVITIES_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {'brickId': brickId},
      );
      rethrow;
    }
  }
}
