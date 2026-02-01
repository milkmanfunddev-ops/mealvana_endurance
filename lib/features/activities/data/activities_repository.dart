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
import '../../nutrition_plan/domain/intensity_distribution.dart';
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
          'intensity_z1_z2_pct': record.intensityZ1Z2Pct,
          'intensity_z3_z4_pct': record.intensityZ3Z4Pct,
          'intensity_z5_pct': record.intensityZ5Pct,
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
          // NOTE: reminder_* columns exist in local Drift but NOT in Supabase
          // They are stored locally only and not synced to the server
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

      // Upload to Supabase - errors are logged but don't block the operation
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
      final payload = _buildSupabasePayload(activity);

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
    // Parse intensity distribution if all three fields are present
    IntensityDistribution? intensityDistribution;
    final z1z2 = json['intensity_z1_z2_pct'] as int?;
    final z3z4 = json['intensity_z3_z4_pct'] as int?;
    final z5 = json['intensity_z5_pct'] as int?;

    if (z1z2 != null && z3z4 != null && z5 != null) {
      try {
        intensityDistribution = IntensityDistribution(
          conversationalPct: z1z2,
          tempoPct: z3z4,
          allOutPct: z5,
        );
      } catch (e) {
        _logger.warning(
          'Failed to parse intensity distribution from Supabase',
          context: 'ACTIVITIES_REPOSITORY',
          error: e,
          data: {'z1z2': z1z2, 'z3z4': z3z4, 'z5': z5},
        );
      }
    }

    return domain.Activity(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      activityType: ActivityType.values.firstWhere(
        (type) => type.name == json['activity_type'],
        orElse: () => ActivityType.running,
      ),
      title: json['title'] as String,
      scheduledDateTime: DateTime.parse(json['scheduled_date_time'] as String),
      status: domain.ActivityStatus.values.firstWhere(
        (s) => s.name == (json['status'] as String? ?? 'planned'),
        orElse: () => domain.ActivityStatus.planned,
      ),
      distanceMiles: (json['distance_miles'] as num?)?.toDouble(),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
      paceTargetMinutesPerMile: (json['pace_target_minutes_per_mile'] as num?)?.toDouble(),
      intensityLevel: json['intensity_level'] != null
          ? domain.IntensityLevel.values.firstWhere(
              (level) => level.name == json['intensity_level'],
              orElse: () => domain.IntensityLevel.moderate,
            )
          : null,
      intensityDistribution: intensityDistribution,
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
      // Exclude deleted activities and archived brick originals
      final query = _database.select(_database.activitiesTable)
        ..where((tbl) =>
            tbl.userId.lower().equals(userId.toLowerCase()) &
            tbl.id.equals(activityId) &
            tbl.deletedAt.isNull() &
            tbl.status.equals('archivedForBrick').not());

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
      // Exclude deleted activities and archived brick originals
      final query = _database.select(_database.activitiesTable)
        ..where((tbl) =>
            tbl.userId.lower().equals(userId.toLowerCase()) &
            tbl.scheduledDateTime.isBetweenValues(startDate, endDate) &
            tbl.deletedAt.isNull() &
            tbl.status.equals('archivedForBrick').not())
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

    final isInsert = activity.id.isEmpty;
    final companion = _mapDomainToCompanion(activity, forInsert: isInsert);

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

  /// Upload activity to Supabase
  ///
  /// Unified upload method for all Supabase operations.
  /// - [operation]: 'create' for insert, 'update' for upsert
  /// - [throwOnError]: if true, rethrows exceptions; if false, logs warning and continues
  ///
  /// For background (non-blocking) uploads, call with throwOnError: false
  /// For synchronous uploads that must succeed, call with throwOnError: true
  Future<void> _uploadActivityToSupabase(
    domain.Activity activity, {
    required String operation,
    bool throwOnError = false,
  }) async {
    try {
      final payload = _buildSupabasePayload(activity, includeCreatedAt: true);

      if (operation == 'create') {
        // Insert with explicit UUID from Drift
        await _supabase.from('activities').insert(payload);
      } else {
        // Update existing record by UUID
        await _supabase.from('activities').upsert(payload);
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
      // Otherwise keep dirty flag, will retry on next sync
    }
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

  /// Build Supabase payload from domain Activity
  ///
  /// Consolidates payload construction for all Supabase upload operations.
  /// Set [includeCreatedAt] to true for insert operations, false for updates.
  Map<String, dynamic> _buildSupabasePayload(
    domain.Activity activity, {
    bool includeCreatedAt = false,
  }) {
    return {
      'id': activity.id,
      'user_id': activity.userId,
      'activity_type': activity.activityType.name,
      'title': activity.title,
      'scheduled_date_time': activity.scheduledDateTime.toIso8601String(),
      'status': activity.status.name,
      'distance_miles': activity.distanceMiles,
      'duration_minutes': activity.durationMinutes,
      'pace_target_minutes_per_mile': activity.paceTargetMinutesPerMile,
      'intensity_level': activity.intensityLevel?.name,
      'intensity_target': activity.intensityTarget,
      'intensity_z1_z2_pct': activity.intensityDistribution?.conversationalPct,
      'intensity_z3_z4_pct': activity.intensityDistribution?.tempoPct,
      'intensity_z5_pct': activity.intensityDistribution?.allOutPct,
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
      // Completion data
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
      if (includeCreatedAt) 'created_at': activity.createdAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Map database Activity to domain Activity
  domain.Activity _mapToActivityDomain(Activity activity) {
    // Parse intensity distribution if all three fields are present
    IntensityDistribution? intensityDistribution;
    if (activity.intensityZ1Z2Pct != null &&
        activity.intensityZ3Z4Pct != null &&
        activity.intensityZ5Pct != null) {
      try {
        intensityDistribution = IntensityDistribution(
          conversationalPct: activity.intensityZ1Z2Pct!,
          tempoPct: activity.intensityZ3Z4Pct!,
          allOutPct: activity.intensityZ5Pct!,
        );
      } catch (e) {
        _logger.warning(
          'Failed to parse intensity distribution from Drift',
          context: 'ACTIVITIES_REPOSITORY',
          error: e,
          data: {
            'activityId': activity.id,
            'z1z2': activity.intensityZ1Z2Pct,
            'z3z4': activity.intensityZ3Z4Pct,
            'z5': activity.intensityZ5Pct,
          },
        );
      }
    }

    return domain.Activity(
      id: activity.id,
      userId: activity.userId,
      activityType: ActivityType.values.firstWhere(
        (type) => type.name == activity.activityType,
        orElse: () => ActivityType.running,
      ),
      title: activity.title,
      scheduledDateTime: activity.scheduledDateTime,
      status: domain.ActivityStatus.values.firstWhere(
        (s) => s.name == activity.status,
        orElse: () => domain.ActivityStatus.planned,
      ),
      distanceMiles: activity.distanceMiles,
      durationMinutes: activity.durationMinutes,
      paceTargetMinutesPerMile: activity.paceTargetMinutesPerMile,
      intensityLevel: activity.intensityLevel != null
          ? domain.IntensityLevel.values.firstWhere(
              (level) => level.name == activity.intensityLevel,
              orElse: () => domain.IntensityLevel.moderate,
            )
          : null,
      intensityDistribution: intensityDistribution,
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
  ///
  /// Set [forInsert] to true when creating a new activity to use Value.absent()
  /// for id and deletedAt, which triggers auto-generation and proper defaults.
  ActivitiesTableCompanion _mapDomainToCompanion(
    domain.Activity activity, {
    bool forInsert = false,
  }) {
    return ActivitiesTableCompanion(
      id: forInsert ? const Value.absent() : Value(activity.id),
      userId: Value(activity.userId),
      activityType: Value(activity.activityType.name),
      title: Value(activity.title),
      scheduledDateTime: Value(activity.scheduledDateTime),
      status: Value(activity.status.name),
      distanceMiles: Value(activity.distanceMiles),
      durationMinutes: Value(activity.durationMinutes),
      paceTargetMinutesPerMile: Value(activity.paceTargetMinutesPerMile),
      intensityLevel: Value(activity.intensityLevel?.name),
      intensityTarget: Value(activity.intensityTarget),
      intensityZ1Z2Pct: Value(activity.intensityDistribution?.conversationalPct),
      intensityZ3Z4Pct: Value(activity.intensityDistribution?.tempoPct),
      intensityZ5Pct: Value(activity.intensityDistribution?.allOutPct),
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
      deletedAt: forInsert ? const Value.absent() : Value(activity.deletedAt),
      needsUpload: Value(activity.needsUpload ?? false),
      localUpdatedAt: Value(activity.localUpdatedAt ?? DateTime.now()),
    );
  }

  /// Get all activities from a specific provider for a user
  ///
  /// Used during sync to compare local activities with provider workouts.
  /// Only returns non-deleted activities that were synced from the specified provider.
  Future<List<domain.Activity>> getActivitiesByUserAndProvider(String userId, String provider) async {
    try {
      // Query activities synced from the specified provider
      // Exclude deleted activities and archived brick originals
      final query = _database.select(_database.activitiesTable)
        ..where((tbl) =>
            tbl.userId.lower().equals(userId.toLowerCase()) &
            tbl.syncedFromProvider.equals(provider) &
            tbl.deletedAt.isNull() &
            tbl.status.equals('archivedForBrick').not())
        ..orderBy([(tbl) => OrderingTerm.desc(tbl.scheduledDateTime)]);

      final activities = await query.get();

      _logger.info(
        'Retrieved activities by provider',
        context: 'ACTIVITIES_REPOSITORY',
        data: {
          'userId': userId,
          'provider': provider,
          'count': activities.length,
        },
      );

      return activities.map(_mapToActivityDomain).toList();
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

  /// Update an activity from provider sync (preserves nutrition data)
  ///
  /// Used when a schedule change is detected from an external provider.
  /// Updates schedule fields (scheduledDateTime, duration, distance, etc.)
  /// while preserving local nutrition plan and user modifications.
  ///
  /// Sets needsUpload flag for eventual sync back to Supabase.
  ///
  /// Note: This method expects the Activity domain model to include the new
  /// sync tracking fields (needsNutritionRefresh, providerScheduledAt, scheduleChangedAt).
  /// It will be fully functional once Phase 1 (database schema changes) is complete.
  Future<domain.Activity> updateActivityFromProvider(domain.Activity activity) async {
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

      // Prepare update with schedule fields only
      // Preserve nutrition_plan_data by not including it in the update
      final now = DateTime.now();
      final activityWithFlags = activity.copyWith(
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
  ///
  /// Sets providerDeletedAt timestamp to mark that the workout was deleted
  /// in the external provider (Training Peaks, Final Surge, etc.).
  ///
  /// The activity remains visible locally with a visual indicator,
  /// allowing the user to decide whether to delete or convert to manual activity.
  Future<void> softDeleteFromProvider(String activityId) async {
    try {
      _logger.info(
        'Soft-deleting activity from provider',
        context: 'ACTIVITIES_REPOSITORY',
        data: {'activityId': activityId},
      );

      final now = DateTime.now();

      await (_database.update(_database.activitiesTable)
            ..where((tbl) => tbl.id.equals(activityId)))
          .write(ActivitiesTableCompanion(
        providerDeletedAt: Value(now),
        needsUpload: const Value(true),
        localUpdatedAt: Value(now),
      ));

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
  ///
  /// Called after the user successfully regenerates their nutrition plan
  /// following a schedule change from the provider.
  Future<void> clearNutritionRefreshFlag(String activityId) async {
    try {
      _logger.info(
        'Clearing nutrition refresh flag',
        context: 'ACTIVITIES_REPOSITORY',
        data: {'activityId': activityId},
      );

      final now = DateTime.now();

      await (_database.update(_database.activitiesTable)
            ..where((tbl) => tbl.id.equals(activityId)))
          .write(ActivitiesTableCompanion(
        needsNutritionRefresh: const Value(false),
        needsUpload: const Value(true),
        localUpdatedAt: Value(now),
      ));

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
  ///
  /// Returns all activities that were archived when creating the specified brick.
  /// These activities have status='archivedForBrick' and brick_id pointing to
  /// the parent brick activity.
  Future<List<domain.Activity>> getArchivedActivitiesForBrick(String brickId) async {
    try {
      final query = _database.select(_database.activitiesTable)
        ..where((tbl) =>
            tbl.brickId.equals(brickId) &
            tbl.status.equals('archivedForBrick') &
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
  /// 2. Marks the original activities as archived (status='archivedForBrick')
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

          // Calculate duration from distance/speed if not directly available
          int durationMinutes = activity.durationMinutes ?? 0;

          if (durationMinutes == 0) {
            // Cycling: duration = distance / speed * 60
            if (activity.activityType == ActivityType.cycling &&
                activity.distanceMiles != null &&
                activity.cyclingSpeedMph != null &&
                activity.cyclingSpeedMph! > 0) {
              durationMinutes = ((activity.distanceMiles! / activity.cyclingSpeedMph!) * 60).round();
            }
            // Swimming: duration = (distance / 100) * pace / 60
            else if (activity.activityType == ActivityType.swimming &&
                activity.distanceMiles != null &&
                activity.swimmingPacePer100mSeconds != null &&
                activity.swimmingPacePer100mSeconds! > 0) {
              // Convert miles to meters for calculation
              final distanceMeters = activity.distanceMiles! * 1609.34;
              final numberOfHundredMeters = distanceMeters / 100;
              durationMinutes = ((numberOfHundredMeters * activity.swimmingPacePer100mSeconds!) / 60).round();
            }
          }

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
  ///
  /// This method:
  /// 1. Gets the brick activity and its archived original activities
  /// 2. Restores original activities (status='planned', brick_id=null)
  /// 3. Deletes the brick activity (soft delete)
  /// 4. Saves all changes to Drift with needsUpload=true for sync
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
        // (bricks don't need to be restored, only the underlying activities do)
        await (_database.delete(_database.activitiesTable)
              ..where((tbl) => tbl.id.equals(brickId)))
            .go();

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
