import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/domain/activity_type.dart';
import '../../../shared/data/syncable_repository.dart';
import '../domain/activity.dart' as domain;
import '../domain/brick_metadata.dart';
import 'activity_mapper.dart';

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
  return ActivitiesRepository(
    supabase: Supabase.instance.client,
    database: ref.read(appDatabaseProvider),
    logger: ref.read(appLoggerProvider),
  );
}

/// Repository for managing activities following FOA pattern
/// Implements SyncableRepository for new sync architecture
class ActivitiesRepository with SyncableRepository {
  ActivitiesRepository({
    required SupabaseClient supabase,
    required AppDatabase database,
    required AppLogger logger,
  })  : _supabase = supabase,
        _database = database,
        _logger = logger,
        _mapper = ActivityMapper(logger: logger);

  final SupabaseClient _supabase;
  final AppDatabase _database;
  final AppLogger _logger;
  final ActivityMapper _mapper;

  /// Expose mapper for use by ActivitiesService and other consumers.
  ActivityMapper get mapper => _mapper;

  // ========================================================================
  // SyncableRepository Implementation
  // ========================================================================

  @override
  String get repositoryKey => 'activities';

  @override
  List<String> get dependencies => ['users'];

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

      // Save to Drift using batch operations
      await _database.batch((batch) {
        for (final activityJson in response as List) {
          final activity = _mapper.fromJson(activityJson);
          batch.insert(
            _database.activitiesTable,
            _mapper.toCompanion(activity),
            mode: InsertMode.insertOrReplace,
          );
        }
      });

      // Update last sync timestamp
      await setLastSyncTime(DateTime.now());

      _logger.info(
        'Activities synced successfully',
        context: 'ACTIVITIES_REPOSITORY',
        data: {'userId': userId, 'count': response.length},
      );

      return SyncResult.successful(response.length);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to sync activities from remote',
        context: 'ACTIVITIES_REPOSITORY',
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
      _logger.warning(
        'Dirty activity batch failed, retrying one-by-one',
        context: 'ACTIVITIES_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {
          'batchLabel': batchLabel,
          'count': records.length,
          'code': _postgrestErrorCode(e),
        },
      );
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
      if (!_isMissingConflictConstraintError(e) ||
          fallbackOnConflict == null ||
          fallbackOnConflict == onConflict) {
        rethrow;
      }

      _logger.warning(
        'Supabase missing ON CONFLICT target, retrying with fallback target',
        context: 'ACTIVITIES_REPOSITORY',
        error: e,
        data: {
          'onConflict': onConflict,
          'fallbackOnConflict': fallbackOnConflict,
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

  // ========================================================================
  // Existing Repository Methods (Backwards Compatibility)
  // ========================================================================

  /// Create a new activity (save to Drift first, then sync to Supabase for final ID)
  Future<domain.Activity> createActivity({
    required String deviceId,
    required domain.Activity activity,
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

      await _uploadActivityToSupabase(
        activityWithId,
        operation: 'create',
        throwOnError: false,
      );

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
  }) async {
    try {
      // OFFLINE-FIRST: Save to Drift IMMEDIATELY with dirty flag
      final activityWithDirtyFlag = activity.copyWith(
        needsUpload: true,
        localUpdatedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _saveToDrift(activityWithDirtyFlag);

      // Attempt background upload (non-blocking)
      unawaited(_uploadActivityToSupabase(activity, operation: 'update'));

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
  }) async {
    try {
      // OFFLINE-FIRST: Mark as deleted in Drift IMMEDIATELY with dirty flag
      await (_database.update(
        _database.activitiesTable,
      )..where((tbl) => tbl.id.equals(activityId))).write(
        ActivitiesTableCompanion(
          deletedAt: Value(DateTime.now()),
          needsUpload: const Value(true),
          localUpdatedAt: Value(DateTime.now()),
        ),
      );

      // Attempt background upload (non-blocking)
      unawaited(_uploadActivityDeletion(deviceId, activityId));
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

      await _supabase
          .from('activities')
          .update(payload)
          .eq('id', activity.id);

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

  /// Merge latest provider data into an existing activity while preserving
  /// local-only fields (nutrition plan, completion, reminders, brick metadata).
  domain.Activity _mergeProviderUpdate(
    domain.Activity existing,
    domain.Activity incoming,
  ) {
    return existing.copyWith(
      activityType: incoming.activityType,
      title: incoming.title,
      scheduledDateTime: incoming.scheduledDateTime,
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
    bool throwOnError = false,
  }) async {
    try {
      final payload = _mapper.buildSupabasePayload(
        activity,
        includeCreatedAt: true,
      );

      if (operation == 'create') {
        await _supabase.from('activities').insert(payload);
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

      _logger.info(
        'Activity uploaded to Supabase with UUID',
        context: 'ACTIVITIES_REPOSITORY',
        data: {'activityId': activity.id, 'operation': operation},
      );

      await _clearDirtyFlag(activity.id);
    } catch (e) {
      _logger.warning(
        'Failed to upload activity (will retry on next sync)',
        context: 'ACTIVITIES_REPOSITORY',
        error: e,
        data: {'activityId': activity.id},
      );
      if (throwOnError) rethrow;
    }
  }

  /// Upload activity deletion to Supabase in background (non-blocking)
  Future<void> _uploadActivityDeletion(
    String deviceId,
    String activityId,
  ) async {
    try {
      final userId = deviceId;

      await _supabase
          .from('activities')
          .delete()
          .eq('id', activityId)
          .eq('user_id', userId);

      // Upload successful - hard delete from local database
      await (_database.delete(
        _database.activitiesTable,
      )..where((tbl) => tbl.id.equals(activityId))).go();
    } catch (e) {
      _logger.warning(
        'Failed to upload activity deletion (will retry on next sync)',
        context: 'ACTIVITIES_REPOSITORY',
        error: e,
        data: {'activityId': activityId},
      );
    }
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
        _logger.warning(
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

      final keeperByKey = <String, Activity>{};
      final duplicates = <Activity>[];

      for (final row in rows) {
        final key = _providerDuplicateKey(row);
        final existing = keeperByKey[key];

        if (existing == null) {
          keeperByKey[key] = row;
          continue;
        }

        final preferred = _selectPreferredDuplicate(existing, row);
        if (preferred.id == row.id) {
          duplicates.add(existing);
          keeperByKey[key] = row;
        } else {
          duplicates.add(row);
        }
      }

      if (duplicates.isEmpty) return 0;

      await _database.batch((batch) {
        for (final duplicate in duplicates) {
          batch.deleteWhere(
            _database.activitiesTable,
            (tbl) => tbl.id.equals(duplicate.id),
          );
        }
      });

      // Best-effort remote cleanup so deleted duplicates don't rehydrate.
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

      _logger.warning(
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

  String _providerDuplicateKey(Activity activity) {
    final providerWorkoutId = activity.providerWorkoutId?.trim();
    if (providerWorkoutId != null && providerWorkoutId.isNotEmpty) {
      return 'id:$providerWorkoutId';
    }

    final normalizedTitle = activity.title.trim().toLowerCase();
    final scheduledAt = activity.scheduledDateTime.toUtc().toIso8601String();
    final duration = activity.durationMinutes ?? -1;
    final distance = activity.distanceMiles?.toStringAsFixed(3) ?? 'na';
    return 'fp:${activity.activityType}|$normalizedTitle|$scheduledAt|$duration|$distance';
  }

  Activity _selectPreferredDuplicate(Activity a, Activity b) {
    final scoreA = _duplicateRecordScore(a);
    final scoreB = _duplicateRecordScore(b);

    if (scoreA != scoreB) {
      return scoreA > scoreB ? a : b;
    }

    return b.updatedAt.isAfter(a.updatedAt) ? b : a;
  }

  int _duplicateRecordScore(Activity activity) {
    var score = 0;

    if (activity.nutritionPlanData != null &&
        activity.nutritionPlanData!.isNotEmpty) {
      score += 100;
    }
    if (activity.completedAt != null ||
        activity.actualDistanceMiles != null ||
        activity.actualDurationMinutes != null) {
      score += 50;
    }
    if ((activity.notes ?? '').trim().isNotEmpty) {
      score += 10;
    }
    if (activity.providerDeletedAt == null) {
      score += 5;
    }

    return score;
  }

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
      default:
        break;
    }

    return variants.toList(growable: false);
  }

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

    await _database.batch((batch) {
      for (final activityJson in remoteById.values) {
        final activity = _mapper.fromJson(activityJson);
        batch.insert(
          _database.activitiesTable,
          _mapper.toCompanion(activity),
          mode: InsertMode.insertOrReplace,
        );
      }
    });

    _logger.info(
      'Hydrated provider activities from Supabase',
      context: 'ACTIVITIES_REPOSITORY',
      data: {
        'userId': userId,
        'providerVariants': providerVariants,
        'count': remoteById.length,
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
          _logger.warning(
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
        unawaited(_uploadActivityDeletion(userIdForSupabaseDelete!, brickId));
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
