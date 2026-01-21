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

part 'activities_repository.g.dart';

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
  const ActivitiesRepository({
    required SupabaseClient supabase,
    required AppDatabase database,
    required AppLogger logger,
  })  : _supabase = supabase,
        _database = database,
        _logger = logger;

  final SupabaseClient _supabase;
  final AppDatabase _database;
  final AppLogger _logger;

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
          final activity = _mapJsonToActivityDomain(activityJson);
          batch.insert(
            _database.activitiesTable,
            _mapDomainToCompanion(activity),
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
      final dirtyRecords = await (_database.select(_database.activitiesTable)
            ..where((t) =>
                t.userId.lower().equals(userId.toLowerCase()) &
                t.needsUpload.equals(true)))
          .get();

      if (dirtyRecords.isEmpty) {
        return UploadResult.nothingToUpload();
      }

      _logger.info(
        'Uploading dirty activities',
        context: 'ACTIVITIES_REPOSITORY',
        data: {'userId': userId, 'count': dirtyRecords.length},
      );

      // Convert to JSON for Supabase upsert
      final recordsToUpload = dirtyRecords.map((record) {
        return {
          'id': record.id,
          'user_id': record.userId,
          'activity_type': record.activityType,
          'title': record.title,
          'scheduled_date_time': record.scheduledDateTime.toIso8601String(),
          'status': record.status,
          'distance_miles': record.distanceMiles,
          'duration_minutes': record.durationMinutes,
          'pace_target_minutes_per_mile': record.paceTargetMinutesPerMile,
          'intensity_level': record.intensityLevel,
          'intensity_target': record.intensityTarget,
          'time_before_minutes': record.timeBeforeMinutes,
          'notes': record.notes,
          'cycling_speed_mph': record.cyclingSpeedMph,
          'cycling_terrain': record.cyclingTerrain,
          'cycling_indoor_outdoor': record.cyclingIndoorOutdoor,
          'cycling_elevation_gain_ft': record.cyclingElevationGainFt,
          'cycling_session_goal': record.cyclingSessionGoal,
          'swimming_pace_per_100m_seconds': record.swimmingPacePer100mSeconds,
          'swimming_pool_or_open_water': record.swimmingPoolOrOpenWater,
          'swimming_water_temp_c': record.swimmingWaterTempC,
          'completed_at': record.completedAt?.toIso8601String(),
          'actual_distance_miles': record.actualDistanceMiles,
          'actual_duration_minutes': record.actualDurationMinutes,
          'completion_rating': record.completionRating,
          'completion_notes': record.completionNotes,
          'nutrition_plan_data': record.nutritionPlanData,
          'reminder_enabled': record.reminderEnabled,
          'reminder_days_before': record.reminderDaysBefore,
          'reminder_time_of_day': record.reminderTimeOfDay,
          'reminder_recurring': record.reminderRecurring,
          'synced_from_provider': record.syncedFromProvider,
          'provider_workout_id': record.providerWorkoutId,
          'provider_workout_url': record.providerWorkoutUrl,
          'last_synced_at': record.lastSyncedAt?.toIso8601String(),
          'workout_subtype': record.workoutSubtype,
          'pace_min_minutes_per_mile': record.paceMinMinutesPerMile,
          'pace_max_minutes_per_mile': record.paceMaxMinutesPerMile,
          'brick_metadata': record.brickMetadata,
          'brick_id': record.brickId,
          'created_at': record.createdAt.toIso8601String(),
          'updated_at': record.updatedAt.toIso8601String(),
        };
      }).toList();

      // Upload to Supabase with upsert
      await _supabase
          .from('activities')
          .upsert(recordsToUpload);

      // Clear dirty flags on success
      await _database.batch((batch) {
        for (final record in dirtyRecords) {
          batch.update(
            _database.activitiesTable,
            const ActivitiesTableCompanion(needsUpload: Value(false)),
            where: (t) => t.id.equals(record.id),
          );
        }
      });

      _logger.info(
        'Dirty activities uploaded successfully',
        context: 'ACTIVITIES_REPOSITORY',
        data: {'userId': userId, 'count': dirtyRecords.length},
      );

      return UploadResult.successful(dirtyRecords.length);
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

  // ========================================================================
  // Existing Repository Methods (Backwards Compatibility)
  // ========================================================================

  /// Create a new activity (save to Drift first, then sync to Supabase for final ID)
  ///
  /// IMPORTANT: This method now waits for Supabase upload to complete before returning,
  /// ensuring the returned activity has the server-assigned ID. This prevents race
  /// conditions where the UI navigates with the local ID but the database gets rekeyed.
  Future<domain.Activity> createActivity({
    required String deviceId,
    required domain.Activity activity,
  }) async {
    try {
      // STEP 1: Save to Drift IMMEDIATELY with dirty flag
      // Note: ID will be auto-generated by database if not provided
      final generatedId = await _saveToDrift(activity.copyWith(
        needsUpload: true,
        localUpdatedAt: DateTime.now(),
      ));

      // Get the activity back from the database with the generated ID
      final savedActivity = await (_database.select(_database.activitiesTable)
            ..where((tbl) => tbl.id.equals(generatedId)))
          .getSingle();

      var activityWithId = _mapToActivityDomain(savedActivity);

      // STEP 2: Upload to Supabase SYNCHRONOUSLY
      // This ensures sync completes before returning, preventing race conditions
      _logger.info(
        'Uploading new activity to Supabase (sync)',
        context: 'ACTIVITIES_REPOSITORY',
        data: {
          'activityId': activityWithId.id,
          'hasNutritionPlan': activityWithId.nutritionPlanData != null,
        },
      );

      try {
        await _uploadActivityToSupabaseSync(deviceId, activityWithId);
      } catch (uploadError) {
        // Upload failed but local save succeeded - activity will sync later
        _logger.warning(
          'Supabase upload failed during create, activity will sync later',
          context: 'ACTIVITIES_REPOSITORY',
          data: {'activityId': activityWithId.id, 'error': uploadError.toString()},
        );
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
      unawaited(_uploadActivityToSupabase(deviceId, activity, 'update'));

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
      await (_database.update(_database.activitiesTable)
            ..where((tbl) => tbl.id.equals(activityId)))
          .write(ActivitiesTableCompanion(
        deletedAt: Value(DateTime.now()),
        needsUpload: const Value(true),
        localUpdatedAt: Value(DateTime.now()),
      ));

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
      final payload = {
        'id': activity.id,
        'user_id': activity.userId,
        'activity_type': activity.activityType.name,
        'title': activity.title,
        'scheduled_date_time': activity.scheduledDateTime.toIso8601String(),
        'status': activity.status.toDbValue,
        'distance_miles': activity.distanceMiles,
        'duration_minutes': activity.durationMinutes,
        'pace_target_minutes_per_mile': activity.paceTargetMinutesPerMile,
        'intensity_level': activity.intensityLevel?.name,
        'intensity_target': activity.intensityTarget,
        'time_before_minutes': activity.timeBeforeMinutes,
        'notes': activity.notes,
        'cycling_speed_mph': activity.cyclingSpeedMph,
        'cycling_terrain': activity.cyclingTerrain,
        'cycling_indoor_outdoor': activity.cyclingIndoorOutdoor,
        'cycling_elevation_gain_ft': activity.cyclingElevationGainFt,
        'cycling_session_goal': activity.cyclingSessionGoal,
        'swimming_pace_per_100m_seconds': activity.swimmingPacePer100mSeconds,
        'swimming_pool_or_open_water': activity.swimmingPoolOrOpenWater,
        'swimming_water_temp_c': activity.swimmingWaterTempC,
        'completed_at': activity.completedAt?.toIso8601String(),
        'actual_distance_miles': activity.actualDistanceMiles,
        'actual_duration_minutes': activity.actualDurationMinutes,
        'completion_rating': activity.completionRating,
        'completion_notes': activity.completionNotes,
        'nutrition_plan_data': activity.nutritionPlanData != null
            ? jsonEncode(activity.nutritionPlanData)
            : null,
        'brick_metadata': activity.brickMetadata != null
            ? jsonEncode(activity.brickMetadata!.toJson())
            : null,
        'brick_id': activity.brickId,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase
          .from('activities')
          .update(payload)
          .eq('id', activity.id); // Security: RLS will check if current user (coach) has access

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

  /// Get all activities for a device (local-first, returns cached data)
  Future<List<domain.Activity>> getActivities(String userId) async {
    try {
      _logger.info(
        '🔍 QUERYING activities',
        context: 'ACTIVITIES_REPOSITORY',
        data: {'userId': userId},
      );

      // CRITICAL FIX: Use case-insensitive comparison for userId
      final query = _database.select(_database.activitiesTable)
        ..where((tbl) => tbl.userId.lower().equals(userId.toLowerCase()) & tbl.deletedAt.isNull())
        ..orderBy([(tbl) => OrderingTerm.desc(tbl.scheduledDateTime)]);

      final activities = await query.get();

      _logger.info(
        '🔍 QUERY RESULT',
        context: 'ACTIVITIES_REPOSITORY',
        data: {
          'userId': userId,
          'activitiesFound': activities.length,
          'allActivitiesInDB': await _database.select(_database.activitiesTable).get().then((a) => a.length),
        },
      );

      return activities.map(_mapToActivityDomain).toList();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get activities',
        context: 'ACTIVITIES_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
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

      // Convert Supabase response (Map) to Activity domain model
      // We can use the same mapping logic, but need to construct a database-like object first
      // OR simpler: manually map from JSON to domain
      return _mapJsonToActivityDomain(response);
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

  /// Map JSON from Supabase to domain Activity
  domain.Activity _mapJsonToActivityDomain(Map<String, dynamic> json) {
    return domain.Activity(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      activityType: ActivityType.values.firstWhere(
        (type) => type.name == json['activity_type'],
        orElse: () => ActivityType.running,
      ),
      title: json['title'] as String,
      scheduledDateTime: DateTime.parse(json['scheduled_date_time'] as String),
      status: domain.ActivityStatusDb.fromDbValue(json['status'] as String? ?? 'planned'),
      distanceMiles: (json['distance_miles'] as num?)?.toDouble(),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
      paceTargetMinutesPerMile: (json['pace_target_minutes_per_mile'] as num?)?.toDouble(),
      intensityLevel: json['intensity_level'] != null
          ? domain.IntensityLevel.values.firstWhere(
              (level) => level.name == json['intensity_level'],
              orElse: () => domain.IntensityLevel.moderate,
            )
          : null,
      // Cycling-specific fields
      cyclingSpeedMph: (json['cycling_speed_mph'] as num?)?.toDouble(),
      cyclingTerrain: json['cycling_terrain'] as String?,
      cyclingIndoorOutdoor: json['cycling_indoor_outdoor'] as String?,
      cyclingElevationGainFt: (json['cycling_elevation_gain_ft'] as num?)?.toInt(),
      cyclingSessionGoal: json['cycling_session_goal'] as String?,
      // Swimming-specific fields
      swimmingPacePer100mSeconds: (json['swimming_pace_per_100m_seconds'] as num?)?.toInt(),
      swimmingPoolOrOpenWater: json['swimming_pool_or_open_water'] as String?,
      swimmingWaterTempC: (json['swimming_water_temp_c'] as num?)?.toDouble(),
      // Shared fields
      intensityTarget: json['intensity_target'] as String?,
      timeBeforeMinutes: (json['time_before_minutes'] as num?)?.toInt(),
      // Completion data
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at'] as String) : null,
      completionRating: (json['completion_rating'] as num?)?.toInt(),
      completionNotes: json['completion_notes'] as String?,
      actualDistanceMiles: (json['actual_distance_miles'] as num?)?.toDouble(),
      actualDurationMinutes: (json['actual_duration_minutes'] as num?)?.toInt(),
      // Nutrition plan data (embedded JSON)
      nutritionPlanData: json['nutrition_plan_data'] != null
          ? _parseNutritionPlanData(json['nutrition_plan_data'] as String)
          : null,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      deletedAt: json['deleted_at'] != null ? DateTime.parse(json['deleted_at'] as String) : null,
      // Brick fields
      brickMetadata: json['brick_metadata'] != null
          ? _parseBrickMetadata(json['brick_metadata'] as String)
          : null,
      brickId: json['brick_id'] as String?,
      // Reminder fields (default to false/null since these might not be relevant for coach view)
      reminderEnabled: false,
      needsUpload: false,
      localUpdatedAt: DateTime.now(),
    );
  }

  /// Get a specific activity by ID
  Future<domain.Activity?> getActivityById(String userId, String activityId) async {
    try {
      // CRITICAL FIX: Use case-insensitive comparison for userId
      final query = _database.select(_database.activitiesTable)
        ..where((tbl) =>
            tbl.userId.lower().equals(userId.toLowerCase()) &
            tbl.id.equals(activityId) &
            tbl.deletedAt.isNull());

      final activity = await query.getSingleOrNull();
      return activity != null ? _mapToActivityDomain(activity) : null;
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
      // CRITICAL FIX: Use case-insensitive comparison for userId
      final query = _database.select(_database.activitiesTable)
        ..where((tbl) =>
            tbl.userId.lower().equals(userId.toLowerCase()) &
            tbl.scheduledDateTime.isBetweenValues(startDate, endDate) &
            tbl.deletedAt.isNull())
        ..orderBy([(tbl) => OrderingTerm.asc(tbl.scheduledDateTime)]);

      final activities = await query.get();
      return activities.map(_mapToActivityDomain).toList();
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

  /// Find activity by external provider workout ID for a specific user
  ///
  /// Used to check if a workout has already been imported from Final Surge, etc.
  /// IMPORTANT: This method is user-scoped to allow multiple users to import
  /// the same workout from their respective training platforms.
  Future<domain.Activity?> findByProviderWorkoutId(
    String userId,
    String provider,
    String providerWorkoutId,
  ) async {
    try {
      // CRITICAL: Filter by user_id to allow per-user deduplication
      // Without this, User B cannot import workouts that User A already imported
      final query = _database.select(_database.activitiesTable)
        ..where((tbl) =>
            tbl.userId.lower().equals(userId.toLowerCase()) &
            tbl.syncedFromProvider.equals(provider) &
            tbl.providerWorkoutId.equals(providerWorkoutId) &
            tbl.deletedAt.isNull());

      final activity = await query.getSingleOrNull();
      return activity != null ? _mapToActivityDomain(activity) : null;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to find activity by provider workout ID',
        context: 'ACTIVITIES_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {'userId': userId, 'provider': provider, 'providerWorkoutId': providerWorkoutId},
      );
      return null; // Return null on error to allow sync to continue
    }
  }

  /// Insert a new activity directly (used by sync services)
  ///
  /// Unlike createActivity, this method doesn't immediately upload to Supabase.
  /// Used for batch imports from external providers.
  ///
  /// IMPORTANT: Always clears the activity ID to ensure a new row is created.
  /// The transformer may provide a pre-generated UUID, but we want the database
  /// to generate the actual ID to ensure proper INSERT behavior.
  Future<domain.Activity> insertActivity(domain.Activity activity) async {
    try {
      // Clear the ID to force INSERT path in _saveToDrift
      // This ensures we always create a new row, not update a non-existent one
      final activityWithFlags = activity.copyWith(
        id: '', // Force INSERT by clearing ID
        needsUpload: true,
        localUpdatedAt: DateTime.now(),
      );

      final generatedId = await _saveToDrift(activityWithFlags);

      final savedActivity = await (_database.select(_database.activitiesTable)
            ..where((tbl) => tbl.id.equals(generatedId)))
          .getSingle();

      _logger.info(
        'Inserted activity from sync',
        context: 'ACTIVITIES_REPOSITORY',
        data: {
          'activityId': generatedId,
          'provider': activity.syncedFromProvider,
          'providerWorkoutId': activity.providerWorkoutId,
        },
      );

      return _mapToActivityDomain(savedActivity);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to insert activity',
        context: 'ACTIVITIES_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
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

    if (activity.id.isEmpty) {
      // CREATE: New activity - let database generate UUID
      final companion = ActivitiesTableCompanion.insert(
        id: const Value.absent(), // Trigger auto-generation
        userId: activity.userId,
        activityType: activity.activityType.name,
        title: activity.title,
        scheduledDateTime: activity.scheduledDateTime,
        status: Value(activity.status.toDbValue),
        distanceMiles: Value(activity.distanceMiles),
        durationMinutes: Value(activity.durationMinutes),
        paceTargetMinutesPerMile: Value(activity.paceTargetMinutesPerMile),
        intensityLevel: Value(activity.intensityLevel?.name),
        notes: Value(activity.notes),
        // Cycling-specific fields
        cyclingSpeedMph: Value(activity.cyclingSpeedMph),
        cyclingTerrain: Value(activity.cyclingTerrain),
        cyclingIndoorOutdoor: Value(activity.cyclingIndoorOutdoor),
        cyclingElevationGainFt: Value(activity.cyclingElevationGainFt),
        cyclingSessionGoal: Value(activity.cyclingSessionGoal),
        // Swimming-specific fields
        swimmingPacePer100mSeconds: Value(activity.swimmingPacePer100mSeconds),
        swimmingPoolOrOpenWater: Value(activity.swimmingPoolOrOpenWater),
        swimmingWaterTempC: Value(activity.swimmingWaterTempC),
        // Shared fields
        intensityTarget: Value(activity.intensityTarget),
        timeBeforeMinutes: Value(activity.timeBeforeMinutes),
        // Completion data
        completedAt: Value(activity.completedAt),
        actualDistanceMiles: Value(activity.actualDistanceMiles),
        actualDurationMinutes: Value(activity.actualDurationMinutes),
        completionRating: Value(activity.completionRating),
        completionNotes: Value(activity.completionNotes),
        // Nutrition plan data (embedded JSON)
        nutritionPlanData: Value(
          activity.nutritionPlanData != null
              ? jsonEncode(activity.nutritionPlanData)
              : null,
        ),
        // Reminder fields
        reminderEnabled: Value(activity.reminderEnabled),
        reminderDaysBefore: Value(activity.reminderDaysBefore),
        reminderTimeOfDay: Value(activity.reminderTimeOfDay),
        reminderRecurring: Value(activity.reminderRecurring),
        // Brick fields
        brickMetadata: Value(
          activity.brickMetadata != null
              ? jsonEncode(activity.brickMetadata!.toJson())
              : null,
        ),
        brickId: Value(activity.brickId),
        // Sync tracking
        needsUpload: Value(activity.needsUpload ?? false),
        localUpdatedAt: Value(activity.localUpdatedAt ?? DateTime.now()),
        deletedAt: const Value.absent(), // Soft delete support
        // External provider sync fields
        syncedFromProvider: Value(activity.syncedFromProvider),
        providerWorkoutId: Value(activity.providerWorkoutId),
        providerWorkoutUrl: Value(activity.providerWorkoutUrl),
        lastSyncedAt: Value(activity.lastSyncedAt),
        workoutSubtype: Value(activity.workoutSubtype),
        paceMinMinutesPerMile: Value(activity.paceMinMinutesPerMile),
        paceMaxMinutesPerMile: Value(activity.paceMaxMinutesPerMile),
        distanceMeters: const Value.absent(), // Calculated from distanceMiles if needed
        // Metadata
        createdAt: activity.createdAt,
        updatedAt: activity.updatedAt,
      );

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
      final companion = ActivitiesTableCompanion(
        id: Value(activity.id), // Preserve existing ID
        userId: Value(activity.userId),
        activityType: Value(activity.activityType.name),
        title: Value(activity.title),
        scheduledDateTime: Value(activity.scheduledDateTime),
        status: Value(activity.status.toDbValue),
        distanceMiles: Value(activity.distanceMiles),
        durationMinutes: Value(activity.durationMinutes),
        paceTargetMinutesPerMile: Value(activity.paceTargetMinutesPerMile),
        intensityLevel: Value(activity.intensityLevel?.name),
        notes: Value(activity.notes),
        // Cycling-specific fields
        cyclingSpeedMph: Value(activity.cyclingSpeedMph),
        cyclingTerrain: Value(activity.cyclingTerrain),
        cyclingIndoorOutdoor: Value(activity.cyclingIndoorOutdoor),
        cyclingElevationGainFt: Value(activity.cyclingElevationGainFt),
        cyclingSessionGoal: Value(activity.cyclingSessionGoal),
        // Swimming-specific fields
        swimmingPacePer100mSeconds: Value(activity.swimmingPacePer100mSeconds),
        swimmingPoolOrOpenWater: Value(activity.swimmingPoolOrOpenWater),
        swimmingWaterTempC: Value(activity.swimmingWaterTempC),
        // Shared fields
        intensityTarget: Value(activity.intensityTarget),
        timeBeforeMinutes: Value(activity.timeBeforeMinutes),
        // Completion data
        completedAt: Value(activity.completedAt),
        actualDistanceMiles: Value(activity.actualDistanceMiles),
        actualDurationMinutes: Value(activity.actualDurationMinutes),
        completionRating: Value(activity.completionRating),
        completionNotes: Value(activity.completionNotes),
        // Nutrition plan data (embedded JSON)
        nutritionPlanData: Value(
          activity.nutritionPlanData != null
              ? jsonEncode(activity.nutritionPlanData)
              : null,
        ),
        // Reminder fields
        reminderEnabled: Value(activity.reminderEnabled),
        reminderDaysBefore: Value(activity.reminderDaysBefore),
        reminderTimeOfDay: Value(activity.reminderTimeOfDay),
        reminderRecurring: Value(activity.reminderRecurring),
        // Brick fields
        brickMetadata: Value(
          activity.brickMetadata != null
              ? jsonEncode(activity.brickMetadata!.toJson())
              : null,
        ),
        brickId: Value(activity.brickId),
        // Sync tracking
        needsUpload: Value(activity.needsUpload ?? false),
        localUpdatedAt: Value(activity.localUpdatedAt ?? DateTime.now()),
        deletedAt: Value(activity.deletedAt), // Soft delete support
        // External provider sync fields
        syncedFromProvider: Value(activity.syncedFromProvider),
        providerWorkoutId: Value(activity.providerWorkoutId),
        providerWorkoutUrl: Value(activity.providerWorkoutUrl),
        lastSyncedAt: Value(activity.lastSyncedAt),
        workoutSubtype: Value(activity.workoutSubtype),
        paceMinMinutesPerMile: Value(activity.paceMinMinutesPerMile),
        paceMaxMinutesPerMile: Value(activity.paceMaxMinutesPerMile),
        // Metadata
        createdAt: Value(activity.createdAt),
        updatedAt: Value(activity.updatedAt),
      );

      await (_database.update(_database.activitiesTable)
            ..where((tbl) => tbl.id.equals(activity.id)))
          .write(companion);

      _logger.debug(
        'Updated existing activity',
        context: 'ACTIVITIES_REPOSITORY',
        data: {'activityId': activity.id},
      );

      return activity.id;
    }
  }

  /// Upload activity to Supabase in background (non-blocking)
  /// Uses direct Supabase upsert instead of edge function for better reliability
  Future<void> _uploadActivityToSupabase(
    String deviceId, // Kept for signature compatibility, but effectively unused for ID lookup
    domain.Activity activity,
    String operation,
  ) async {
    try {
      // Use userId from activity directly
      final userId = activity.userId;

      final payload = {
        'id': activity.id, // Use same UUID from Drift
        'user_id': userId,
        'activity_type': activity.activityType.name,
        'title': activity.title,
        'scheduled_date_time': activity.scheduledDateTime.toIso8601String(),
        'status': activity.status.toDbValue,
        'distance_miles': activity.distanceMiles,
        'duration_minutes': activity.durationMinutes,
        'pace_target_minutes_per_mile': activity.paceTargetMinutesPerMile,
        'intensity_level': activity.intensityLevel?.name,
        'intensity_target': activity.intensityTarget,
        'time_before_minutes': activity.timeBeforeMinutes,
        'notes': activity.notes,
        // Cycling fields
        'cycling_speed_mph': activity.cyclingSpeedMph,
        'cycling_terrain': activity.cyclingTerrain,
        'cycling_indoor_outdoor': activity.cyclingIndoorOutdoor,
        'cycling_elevation_gain_ft': activity.cyclingElevationGainFt,
        'cycling_session_goal': activity.cyclingSessionGoal,
        // Swimming fields
        'swimming_pace_per_100m_seconds': activity.swimmingPacePer100mSeconds,
        'swimming_pool_or_open_water': activity.swimmingPoolOrOpenWater,
        'swimming_water_temp_c': activity.swimmingWaterTempC,
        // Completion data (if provided)
        'completed_at': activity.completedAt?.toIso8601String(),
        'actual_distance_miles': activity.actualDistanceMiles,
        'actual_duration_minutes': activity.actualDurationMinutes,
        'completion_rating': activity.completionRating,
        'completion_notes': activity.completionNotes,
        // Nutrition plan data (embedded JSON)
        'nutrition_plan_data': activity.nutritionPlanData != null
            ? jsonEncode(activity.nutritionPlanData)
            : null,
        // Brick fields
        'brick_metadata': activity.brickMetadata != null
            ? jsonEncode(activity.brickMetadata!.toJson())
            : null,
        'brick_id': activity.brickId,
        // Timestamps
        'created_at': activity.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (operation == 'create') {
        // Insert with explicit UUID from Drift
        await _supabase
            .from('activities')
            .insert(payload);

        _logger.info(
          'Activity uploaded to Supabase with UUID',
          context: 'ACTIVITIES_REPOSITORY',
          data: {'activityId': activity.id},
        );

        await _clearDirtyFlag(activity.id);
      } else {
        // Update existing record by UUID
        await _supabase
            .from('activities')
            .upsert(payload);

        await _clearDirtyFlag(activity.id);
      }
    } catch (e) {
      _logger.warning(
        'Failed to upload activity (will retry on next sync)',
        context: 'ACTIVITIES_REPOSITORY',
        error: e,
        data: {'activityId': activity.id},
      );
      // Don't rethrow - keep dirty flag, will retry on next sync
    }
  }

  /// Upload activity to Supabase SYNCHRONOUSLY
  /// Used during activity creation to ensure upload completes before returning
  Future<void> _uploadActivityToSupabaseSync(
    String deviceId,
    domain.Activity activity,
  ) async {
    // Use userId from activity directly
    final userId = activity.userId;

    final payload = {
      'id': activity.id, // Use same UUID from Drift
      'user_id': userId,
      'activity_type': activity.activityType.name,
      'title': activity.title,
      'scheduled_date_time': activity.scheduledDateTime.toIso8601String(),
      'status': activity.status.toDbValue,
      'distance_miles': activity.distanceMiles,
      'duration_minutes': activity.durationMinutes,
      'pace_target_minutes_per_mile': activity.paceTargetMinutesPerMile,
      'intensity_level': activity.intensityLevel?.name,
      'intensity_target': activity.intensityTarget,
      'time_before_minutes': activity.timeBeforeMinutes,
      'notes': activity.notes,
      // Cycling fields
      'cycling_speed_mph': activity.cyclingSpeedMph,
      'cycling_terrain': activity.cyclingTerrain,
      'cycling_indoor_outdoor': activity.cyclingIndoorOutdoor,
      'cycling_elevation_gain_ft': activity.cyclingElevationGainFt,
      'cycling_session_goal': activity.cyclingSessionGoal,
      // Swimming fields
      'swimming_pace_per_100m_seconds': activity.swimmingPacePer100mSeconds,
      'swimming_pool_or_open_water': activity.swimmingPoolOrOpenWater,
      'swimming_water_temp_c': activity.swimmingWaterTempC,
      // Completion data (if provided)
      'completed_at': activity.completedAt?.toIso8601String(),
      'actual_distance_miles': activity.actualDistanceMiles,
      'actual_duration_minutes': activity.actualDurationMinutes,
      'completion_rating': activity.completionRating,
      'completion_notes': activity.completionNotes,
      // Nutrition plan data (embedded JSON)
      'nutrition_plan_data': activity.nutritionPlanData != null
          ? jsonEncode(activity.nutritionPlanData)
          : null,
      // Brick fields
      'brick_metadata': activity.brickMetadata != null
          ? jsonEncode(activity.brickMetadata!.toJson())
          : null,
      'brick_id': activity.brickId,
      // Timestamps
      'created_at': activity.createdAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    // Insert with explicit UUID from Drift
    await _supabase
        .from('activities')
        .insert(payload);

    _logger.info(
      'Activity uploaded to Supabase with UUID (sync)',
      context: 'ACTIVITIES_REPOSITORY',
      data: {'activityId': activity.id},
    );

    await _clearDirtyFlag(activity.id);
  }

  /// Upload activity deletion to Supabase in background (non-blocking)
  /// Uses direct Supabase delete instead of edge function for better reliability
  Future<void> _uploadActivityDeletion(
    String deviceId, // acts as userId in new architecture
    String activityId,
  ) async {
    try {
      // DIRECT FIX: Use deviceId as userId directly
      // The app architecture has unified deviceId and userId
      final userId = deviceId;

      // Use direct Supabase delete
      await _supabase
          .from('activities')
          .delete()
          .eq('id', activityId)
          .eq('user_id', userId);

      // Upload successful - hard delete from local database
      await (_database.delete(_database.activitiesTable)
            ..where((tbl) => tbl.id.equals(activityId)))
          .go();
    } catch (e) {
      _logger.warning(
        'Failed to upload activity deletion (will retry on next sync)',
        context: 'ACTIVITIES_REPOSITORY',
        error: e,
        data: {'activityId': activityId},
      );
      // Don't rethrow - keep dirty flag, will retry on next sync
    }
  }

  /// Clear dirty flag after successful upload
  Future<void> _clearDirtyFlag(String activityId) async {
    await (_database.update(_database.activitiesTable)
          ..where((tbl) => tbl.id.equals(activityId)))
        .write(const ActivitiesTableCompanion(needsUpload: Value(false)));
  }

  /// Map database Activity to domain Activity
  domain.Activity _mapToActivityDomain(Activity activity) {
    return domain.Activity(
      id: activity.id,
      userId: activity.userId,
      activityType: ActivityType.values.firstWhere(
        (type) => type.name == activity.activityType,
        orElse: () => ActivityType.running,
      ),
      title: activity.title,
      scheduledDateTime: activity.scheduledDateTime,
      status: domain.ActivityStatusDb.fromDbValue(activity.status),
      distanceMiles: activity.distanceMiles,
      durationMinutes: activity.durationMinutes,
      paceTargetMinutesPerMile: activity.paceTargetMinutesPerMile,
      intensityLevel: activity.intensityLevel != null
          ? domain.IntensityLevel.values.firstWhere(
              (level) => level.name == activity.intensityLevel,
              orElse: () => domain.IntensityLevel.moderate,
            )
          : null,
      // Cycling-specific fields
      cyclingSpeedMph: activity.cyclingSpeedMph,
      cyclingTerrain: activity.cyclingTerrain,
      cyclingIndoorOutdoor: activity.cyclingIndoorOutdoor,
      cyclingElevationGainFt: activity.cyclingElevationGainFt,
      cyclingSessionGoal: activity.cyclingSessionGoal,
      // Swimming-specific fields
      swimmingPacePer100mSeconds: activity.swimmingPacePer100mSeconds,
      swimmingPoolOrOpenWater: activity.swimmingPoolOrOpenWater,
      swimmingWaterTempC: activity.swimmingWaterTempC,
      // Shared fields
      intensityTarget: activity.intensityTarget,
      timeBeforeMinutes: activity.timeBeforeMinutes,
      // Completion data
      completedAt: activity.completedAt,
      completionRating: activity.completionRating,
      completionNotes: activity.completionNotes,
      actualDistanceMiles: activity.actualDistanceMiles,
      actualDurationMinutes: activity.actualDurationMinutes,
      // Nutrition plan data (parse JSON string from database)
      nutritionPlanData: activity.nutritionPlanData != null
          ? _parseNutritionPlanData(activity.nutritionPlanData!)
          : null,
      notes: activity.notes,
      createdAt: activity.createdAt,
      updatedAt: activity.updatedAt,
      deletedAt: activity.deletedAt,
      // Reminder fields
      reminderEnabled: activity.reminderEnabled,
      reminderDaysBefore: activity.reminderDaysBefore,
      reminderTimeOfDay: activity.reminderTimeOfDay,
      reminderRecurring: activity.reminderRecurring,
      // Brick fields
      brickMetadata: activity.brickMetadata != null
          ? _parseBrickMetadata(activity.brickMetadata!)
          : null,
      brickId: activity.brickId,
      // Sync fields
      needsUpload: activity.needsUpload,
      localUpdatedAt: activity.localUpdatedAt,
      // External provider sync fields
      syncedFromProvider: activity.syncedFromProvider,
      providerWorkoutId: activity.providerWorkoutId,
      providerWorkoutUrl: activity.providerWorkoutUrl,
      lastSyncedAt: activity.lastSyncedAt,
      workoutSubtype: activity.workoutSubtype,
      paceMinMinutesPerMile: activity.paceMinMinutesPerMile,
      paceMaxMinutesPerMile: activity.paceMaxMinutesPerMile,
    );
  }

  /// Parse nutrition plan data JSON string from database
  Map<String, dynamic>? _parseNutritionPlanData(String jsonString) {
    try {
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      _logger.error(
        'Failed to parse nutrition plan data',
        context: 'ACTIVITIES_REPOSITORY',
        error: e,
      );
      return null;
    }
  }

  /// Parse brick metadata JSON string from database
  BrickMetadata? _parseBrickMetadata(String jsonString) {
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return BrickMetadata.fromJson(json);
    } catch (e) {
      _logger.error(
        'Failed to parse brick metadata',
        context: 'ACTIVITIES_REPOSITORY',
        error: e,
      );
      return null;
    }
  }

  /// Map domain Activity to ActivitiesTableCompanion for database operations
  ActivitiesTableCompanion _mapDomainToCompanion(domain.Activity activity) {
    return ActivitiesTableCompanion(
      id: Value(activity.id),
      userId: Value(activity.userId),
      activityType: Value(activity.activityType.name),
      title: Value(activity.title),
      scheduledDateTime: Value(activity.scheduledDateTime),
      status: Value(activity.status.toDbValue),
      distanceMiles: Value(activity.distanceMiles),
      durationMinutes: Value(activity.durationMinutes),
      paceTargetMinutesPerMile: Value(activity.paceTargetMinutesPerMile),
      intensityLevel: Value(activity.intensityLevel?.name),
      intensityTarget: Value(activity.intensityTarget),
      timeBeforeMinutes: Value(activity.timeBeforeMinutes),
      notes: Value(activity.notes),
      cyclingSpeedMph: Value(activity.cyclingSpeedMph),
      cyclingTerrain: Value(activity.cyclingTerrain),
      cyclingIndoorOutdoor: Value(activity.cyclingIndoorOutdoor),
      cyclingElevationGainFt: Value(activity.cyclingElevationGainFt),
      cyclingSessionGoal: Value(activity.cyclingSessionGoal),
      swimmingPacePer100mSeconds: Value(activity.swimmingPacePer100mSeconds),
      swimmingPoolOrOpenWater: Value(activity.swimmingPoolOrOpenWater),
      swimmingWaterTempC: Value(activity.swimmingWaterTempC),
      completedAt: Value(activity.completedAt),
      actualDistanceMiles: Value(activity.actualDistanceMiles),
      actualDurationMinutes: Value(activity.actualDurationMinutes),
      completionRating: Value(activity.completionRating),
      completionNotes: Value(activity.completionNotes),
      nutritionPlanData: Value(
        activity.nutritionPlanData != null
            ? jsonEncode(activity.nutritionPlanData)
            : null,
      ),
      reminderEnabled: Value(activity.reminderEnabled),
      reminderDaysBefore: Value(activity.reminderDaysBefore),
      reminderTimeOfDay: Value(activity.reminderTimeOfDay),
      reminderRecurring: Value(activity.reminderRecurring),
      brickMetadata: Value(
        activity.brickMetadata != null
            ? jsonEncode(activity.brickMetadata!.toJson())
            : null,
      ),
      brickId: Value(activity.brickId),
      syncedFromProvider: Value(activity.syncedFromProvider),
      providerWorkoutId: Value(activity.providerWorkoutId),
      providerWorkoutUrl: Value(activity.providerWorkoutUrl),
      lastSyncedAt: Value(activity.lastSyncedAt),
      workoutSubtype: Value(activity.workoutSubtype),
      paceMinMinutesPerMile: Value(activity.paceMinMinutesPerMile),
      paceMaxMinutesPerMile: Value(activity.paceMaxMinutesPerMile),
      createdAt: Value(activity.createdAt),
      updatedAt: Value(activity.updatedAt),
      deletedAt: Value(activity.deletedAt),
      needsUpload: Value(activity.needsUpload ?? false),
      localUpdatedAt: Value(activity.localUpdatedAt ?? DateTime.now()),
    );
  }

  /// Migrate activities from one user ID to another
  ///
  /// Used during onboarding when activities are synced before the final
  /// user profile is created. This updates the user_id on all activities
  /// that belong to the old user so they appear for the new user.
  ///
  /// Returns the number of activities migrated.
  Future<int> migrateActivitiesToUser({
    required String fromUserId,
    required String toUserId,
  }) async {
    if (fromUserId == toUserId) return 0;

    try {
      final result = await (_database.update(_database.activitiesTable)
            ..where((tbl) => tbl.userId.equals(fromUserId) & tbl.deletedAt.isNull()))
          .write(ActivitiesTableCompanion(
        userId: Value(toUserId),
        needsUpload: const Value(true),
        localUpdatedAt: Value(DateTime.now()),
      ));

      if (result > 0) {
        _logger.info(
          'Migrated activities to new user',
          context: 'ACTIVITIES_REPOSITORY',
          data: {
            'fromUserId': fromUserId,
            'toUserId': toUserId,
            'count': result,
          },
        );
      }

      return result;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to migrate activities',
        context: 'ACTIVITIES_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {'fromUserId': fromUserId, 'toUserId': toUserId},
      );
      return 0;
    }
  }

  /// Get all activities synced from external providers (regardless of user)
  ///
  /// Used to find activities that were synced during onboarding before
  /// the user profile was finalized.
  Future<List<domain.Activity>> getActivitiesByProvider(String provider) async {
    try {
      final query = _database.select(_database.activitiesTable)
        ..where((tbl) =>
            tbl.syncedFromProvider.equals(provider) & tbl.deletedAt.isNull());

      final results = await query.get();
      return results.map(_mapToActivityDomain).toList();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get activities by provider',
        context: 'ACTIVITIES_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {'provider': provider},
      );
      return [];
    }
  }

  // ========================================================================
  // Brick Workout Methods
  // ========================================================================

  /// Get archived activities for a specific brick
  ///
  /// Returns all activities that were archived when creating the specified brick.
  /// These activities have status='archived_for_brick' and brick_id pointing to
  /// the parent brick activity.
  Future<List<domain.Activity>> getArchivedActivitiesForBrick(String brickId) async {
    try {
      final query = _database.select(_database.activitiesTable)
        ..where((tbl) =>
            tbl.brickId.equals(brickId) &
            tbl.status.equals('archived_for_brick') &
            tbl.deletedAt.isNull())
        ..orderBy([(tbl) => OrderingTerm.asc(tbl.scheduledDateTime)]);

      final results = await query.get();
      return results.map(_mapToActivityDomain).toList();
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
  ///
  /// This method:
  /// 1. Creates a new brick activity with type='brick' and brick_metadata JSON
  /// 2. Marks the original activities as archived (status='archived_for_brick')
  /// 3. Links archived activities to the brick via brick_id
  /// 4. Saves all changes to Drift with needsUpload=true for sync
  ///
  /// The segment order list determines the order of sports in the brick (e.g., ['swimming', 'running']).
  /// This must match the order of activities in the activities list.
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
          final durationMinutes = activity.durationMinutes ?? 0;
          totalDurationMinutes += durationMinutes;

          final segment = BrickSegment(
            sport: sport,
            order: i + 1,
            durationMinutes: durationMinutes,
            intensity: activity.intensityLevel?.name ?? 'moderate',
            // Swimming fields
            distanceMeters: activity.activityType == ActivityType.swimming
                ? (activity.distanceMiles != null ? activity.distanceMiles! * 1609.34 : null)
                : null,
            pacePer100mSeconds: activity.swimmingPacePer100mSeconds,
            poolOrOpenWater: activity.swimmingPoolOrOpenWater,
            waterTempC: activity.swimmingWaterTempC,
            // Cycling fields
            distanceMiles: activity.activityType == ActivityType.cycling || activity.activityType == ActivityType.running
                ? activity.distanceMiles
                : null,
            speedMph: activity.cyclingSpeedMph,
            terrain: activity.cyclingTerrain,
            indoorOutdoor: activity.cyclingIndoorOutdoor,
            elevationGainFt: activity.cyclingElevationGainFt,
            // Running fields
            paceMinutesPerMile: activity.paceTargetMinutesPerMile,
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
          data: {
            'brickId': brickId,
            'archivedCount': activities.length,
          },
        );

        // Return the created brick activity (fetch from DB to get full object)
        final savedBrick = await (_database.select(_database.activitiesTable)
              ..where((tbl) => tbl.id.equals(brickId)))
            .getSingle();

        return _mapToActivityDomain(savedBrick);
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

      // Check if this is a schema error - if so, delete DB and trigger resync
      if (AppDatabase.isSchemaError(e)) {
        await AppDatabase.handleSchemaError(e, context: 'createBrickFromActivities');
      }

      rethrow;
    }
  }

  /// Ungroup a brick workout
  ///
  /// This method:
  /// 1. Gets the brick activity and its archived original activities
  /// 2. Restores original activities (status='planned', brick_id=null)
  /// 3. Deletes the brick activity (soft delete)
  /// 4. Saves all changes to Drift with needsUpload=true for sync
  Future<void> ungroupBrick(String brickId) async {
    try {
      // Use transaction to ensure atomicity
      await _database.transaction(() async {
        // Step 1: Get the brick activity
        final brickQuery = _database.select(_database.activitiesTable)
          ..where((tbl) => tbl.id.equals(brickId) & tbl.deletedAt.isNull());

        final brickActivity = await brickQuery.getSingleOrNull();
        if (brickActivity == null) {
          throw StateError('Brick activity not found: $brickId');
        }

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

        // Step 4: Soft delete the brick activity
        await (_database.update(_database.activitiesTable)
              ..where((tbl) => tbl.id.equals(brickId)))
            .write(ActivitiesTableCompanion(
          deletedAt: Value(now),
          needsUpload: const Value(true),
          localUpdatedAt: Value(now),
        ));

        _logger.info(
          'Deleted brick activity',
          context: 'ACTIVITIES_REPOSITORY',
          data: {'brickId': brickId},
        );
      });
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
