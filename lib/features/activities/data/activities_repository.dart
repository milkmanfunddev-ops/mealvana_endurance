import 'dart:async';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/domain/activity_type.dart';
import '../domain/activity.dart' as domain;

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
/// Prepares for server-authoritative sync with edge functions
class ActivitiesRepository {
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

  /// Create a new activity (offline-first: save to Drift first, background upload)
  Future<domain.Activity> createActivity({
    required String deviceId,
    required domain.Activity activity,
  }) async {
    try {
      // OFFLINE-FIRST: Save to Drift IMMEDIATELY with dirty flag
      final activityWithDirtyFlag = activity.copyWith(
        needsUpload: true,
        localUpdatedAt: DateTime.now(),
      );

      await _saveToDrift(activityWithDirtyFlag);

      // Attempt background upload (non-blocking)
      unawaited(_uploadActivityToSupabase(deviceId, activity, 'create'));

      return activityWithDirtyFlag;
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

  /// Get all activities for a device (local-first, returns cached data)
  Future<List<domain.Activity>> getActivities(String userId) async {
    try {
      final query = _database.select(_database.activitiesTable)
        ..where((tbl) => tbl.userId.equals(userId) & tbl.deletedAt.isNull())
        ..orderBy([(tbl) => OrderingTerm.desc(tbl.scheduledDateTime)]);

      final activities = await query.get();
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

  /// Get a specific activity by ID
  Future<domain.Activity?> getActivityById(String userId, String activityId) async {
    try {
      final query = _database.select(_database.activitiesTable)
        ..where((tbl) =>
            tbl.userId.equals(userId) &
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
      final query = _database.select(_database.activitiesTable)
        ..where((tbl) =>
            tbl.userId.equals(userId) &
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

  /// Save activity to Drift database (offline-first pattern)
  Future<void> _saveToDrift(domain.Activity activity) async {
    final companion = ActivitiesTableCompanion.insert(
      id: activity.id,
      userId: activity.userId,
      activityType: activity.activityType.name,
      title: activity.title,
      scheduledDateTime: activity.scheduledDateTime,
      status: Value(activity.status.name),
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
      // Reminder fields
      reminderEnabled: Value(activity.reminderEnabled),
      reminderDaysBefore: Value(activity.reminderDaysBefore),
      reminderTimeOfDay: Value(activity.reminderTimeOfDay),
      reminderRecurring: Value(activity.reminderRecurring),
      // Sync tracking
      needsUpload: Value(activity.needsUpload ?? false),
      localUpdatedAt: Value(activity.localUpdatedAt ?? DateTime.now()),
      // Metadata
      createdAt: activity.createdAt,
      updatedAt: activity.updatedAt,
    );

    await _database
        .into(_database.activitiesTable)
        .insert(companion, mode: InsertMode.insertOrReplace);
  }

  /// Upload activity to Supabase in background (non-blocking)
  Future<void> _uploadActivityToSupabase(
    String deviceId,
    domain.Activity activity,
    String operation,
  ) async {
    try {
      final response = await _supabase.functions.invoke(
        'save-calendar-activity',
        body: {
          'device_id': deviceId,
          'activity': activity.toJson(),
          'operation': operation,
        },
      );

      if (response.status >= 200 && response.status < 300) {
        // Upload successful - clear dirty flag
        await _clearDirtyFlag(activity.id);
      } else {
        throw Exception('Edge function failed: ${response.data}');
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

  /// Upload activity deletion to Supabase in background (non-blocking)
  Future<void> _uploadActivityDeletion(
    String deviceId,
    String activityId,
  ) async {
    try {
      final response = await _supabase.functions.invoke(
        'save-calendar-activity',
        body: {
          'device_id': deviceId,
          'activity_id': activityId,
          'operation': 'delete',
        },
      );

      if (response.status >= 200 && response.status < 300) {
        // Upload successful - hard delete from local database
        await (_database.delete(_database.activitiesTable)
              ..where((tbl) => tbl.id.equals(activityId)))
            .go();
      } else {
        throw Exception('Edge function failed: ${response.data}');
      }
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
      status: domain.ActivityStatus.values.firstWhere(
        (status) => status.name == activity.status,
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
      notes: activity.notes,
      createdAt: activity.createdAt,
      updatedAt: activity.updatedAt,
      deletedAt: activity.deletedAt,
    );
  }
}
