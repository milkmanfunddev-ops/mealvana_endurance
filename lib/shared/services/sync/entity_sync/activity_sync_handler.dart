import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../database/app_database.dart';
import '../../../database/database_provider.dart';
import '../../../utils/sync_type_converters.dart';
import '../../logging_service.dart';

part 'activity_sync_handler.g.dart';

@Riverpod(keepAlive: true)
ActivitySyncHandler activitySyncHandler(Ref ref) {
  return ActivitySyncHandler(
    database: ref.read(appDatabaseProvider),
    logger: ref.read(appLoggerProvider),
  );
}

/// Handles sync operations for Activity entities.
class ActivitySyncHandler {
  const ActivitySyncHandler({
    required AppDatabase database,
    required AppLogger logger,
  })  : _database = database,
        _logger = logger;

  final AppDatabase _database;
  final AppLogger _logger;

  /// Upsert an activity from remote data.
  Future<void> upsertActivity(Map<String, dynamic> data) async {
    try {
      final activityId = SyncTypeConverters.toRequiredStringId(data['id'], 'activity.id');
      final userId = SyncTypeConverters.toRequiredStringId(data['user_id'], 'activity.user_id');

      final existingActivity = await (_database.select(_database.activitiesTable)
            ..where((tbl) => tbl.id.equals(activityId)))
          .getSingleOrNull();

      final supabaseUpdatedAt = DateTime.parse(data['updated_at'] as String);

      // CRITICAL: Preserve local data if it has pending changes (needsUpload = true)
      // Phone data is the source of truth - never overwrite local changes
      if (existingActivity != null && (existingActivity.needsUpload ?? false)) {
        return; // Keep local version with pending changes
      }

      if (existingActivity == null || existingActivity.updatedAt.isBefore(supabaseUpdatedAt)) {
        final companion = ActivitiesTableCompanion.insert(
          id: Value(activityId),
          userId: userId,
          activityType: data['activity_type'] as String,
          title: data['title'] as String,
          scheduledDateTime: DateTime.parse(data['scheduled_date_time'] as String),
          status: Value(data['status'] as String? ?? 'planned'),
          distanceMiles: Value((data['distance_miles'] as num?)?.toDouble()),
          durationMinutes: Value(data['duration_minutes'] as int?),
          paceTargetMinutesPerMile: Value((data['pace_target_minutes_per_mile'] as num?)?.toDouble()),
          intensityLevel: Value(data['intensity_level'] as String?),
          cyclingSpeedMph: Value((data['cycling_speed_mph'] as num?)?.toDouble()),
          cyclingTerrain: Value(data['cycling_terrain'] as String?),
          cyclingIndoorOutdoor: Value(data['cycling_indoor_outdoor'] as String?),
          cyclingElevationGainFt: Value(data['cycling_elevation_gain_ft'] as int?),
          cyclingSessionGoal: Value(data['cycling_session_goal'] as String?),
          swimmingPacePer100mSeconds: Value(data['swimming_pace_per_100m_seconds'] as int?),
          swimmingPoolOrOpenWater: Value(data['swimming_pool_or_open_water'] as String?),
          swimmingWaterTempC: Value((data['swimming_water_temp_c'] as num?)?.toDouble()),
          intensityTarget: Value(data['intensity_target'] as String?),
          timeBeforeMinutes: Value(data['time_before_minutes'] as int?),
          completedAt: Value(
            data['completed_at'] != null ? DateTime.parse(data['completed_at'] as String) : null,
          ),
          completionRating: Value(data['completion_rating'] as int?),
          completionNotes: Value(data['completion_notes'] as String?),
          actualDistanceMiles: Value((data['actual_distance_miles'] as num?)?.toDouble()),
          actualDurationMinutes: Value(data['actual_duration_minutes'] as int?),
          nutritionPlanData: Value(data['nutrition_plan_data'] as String?),
          notes: Value(data['notes'] as String?),
          createdAt: DateTime.parse(data['created_at'] as String),
          updatedAt: supabaseUpdatedAt,
        );

        await _database
            .into(_database.activitiesTable)
            .insert(companion, mode: InsertMode.insertOrReplace);
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to upsert activity',
        context: 'ACTIVITY_SYNC',
        error: e,
        stackTrace: stackTrace,
        data: {'activityId': data['id']},
      );
    }
  }

  /// Sync multiple athlete activities (for coach view).
  Future<void> syncAthleteActivities(List<dynamic> activities) async {
    try {
      for (final activityData in activities) {
        await upsertActivity(activityData as Map<String, dynamic>);
      }

      _logger.info(
        'Synced ${activities.length} athlete activities',
        context: 'ACTIVITY_SYNC',
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to sync athlete activities',
        context: 'ACTIVITY_SYNC',
        error: e,
        stackTrace: stackTrace,
      );
      // Don't rethrow - continue with other syncs
    }
  }

  /// Convert Activity entity to JSON for edge function upload.
  Map<String, dynamic> activityToJson(Activity activity) {
    return {
      'id': activity.id,
      'user_id': activity.userId,
      'activity_type': activity.activityType,
      'title': activity.title,
      'scheduled_date_time': activity.scheduledDateTime.toIso8601String(),
      'status': activity.status,
      'distance_miles': activity.distanceMiles,
      'duration_minutes': activity.durationMinutes,
      'pace_target_minutes_per_mile': activity.paceTargetMinutesPerMile,
      'intensity_level': activity.intensityLevel,
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
      'nutrition_plan_data': activity.nutritionPlanData,
      'created_at': activity.createdAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}
