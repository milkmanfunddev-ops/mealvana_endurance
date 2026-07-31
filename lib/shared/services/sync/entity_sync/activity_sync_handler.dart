import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../database/app_database.dart';
import '../../../database/database_provider.dart';
import '../../../utils/sync_type_converters.dart';
import '../../logging_service.dart';
import '../../notification_service.dart';

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
  }) : _database = database,
       _logger = logger;

  final AppDatabase _database;
  final AppLogger _logger;
  static const Duration _garminNotificationFreshnessWindow = Duration(
    minutes: 30,
  );

  /// Upsert an activity from remote data.
  Future<void> upsertActivity(
    Map<String, dynamic> data, {
    bool enableNotifications = true,
  }) async {
    try {
      final activityId = SyncTypeConverters.toRequiredStringId(
        data['id'],
        'activity.id',
      );
      final userId = SyncTypeConverters.toRequiredStringId(
        data['user_id'],
        'activity.user_id',
      );

      final existingActivity = await (_database.select(
        _database.activitiesTable,
      )..where((tbl) => tbl.id.equals(activityId))).getSingleOrNull();

      final supabaseUpdatedAt = DateTime.parse(data['updated_at'] as String);
      final incomingStatus = (data['status'] as String? ?? 'planned').trim();
      final incomingProvider = (data['synced_from_provider'] as String?)
          ?.toLowerCase()
          .trim();
      final incomingGarminSummaryId = (data['garmin_summary_id'] as String?)
          ?.trim();
      final incomingCompletedAt = data['completed_at'] != null
          ? DateTime.parse(data['completed_at'] as String)
          : null;

      // CRITICAL: Preserve local data if it has pending changes (needsUpload = true)
      // Phone data is the source of truth - never overwrite local changes.
      // Exception: a remote Garmin completion should still merge onto the local
      // record so completed workouts show up even when a nutrition plan edit
      // is still pending upload.
      if (existingActivity != null && (existingActivity.needsUpload ?? false)) {
        if (_shouldMergeGarminCompletionIntoDirtyLocal(
          existingActivity: existingActivity,
          incomingProvider: incomingProvider,
          incomingGarminSummaryId: incomingGarminSummaryId,
          incomingStatus: incomingStatus,
        )) {
          await (_database.update(
            _database.activitiesTable,
          )..where((tbl) => tbl.id.equals(activityId))).write(
            ActivitiesTableCompanion(
              status: Value(incomingStatus),
              completedAt: Value(
                incomingCompletedAt ??
                    existingActivity.completedAt ??
                    supabaseUpdatedAt,
              ),
              distanceMiles: Value(
                (data['distance_miles'] as num?)?.toDouble() ??
                    existingActivity.distanceMiles,
              ),
              distanceMeters: Value(
                (data['distance_meters'] as num?)?.toDouble() ??
                    existingActivity.distanceMeters,
              ),
              durationMinutes: Value(
                data['duration_minutes'] as int? ??
                    existingActivity.durationMinutes,
              ),
              actualDistanceMiles: Value(
                (data['actual_distance_miles'] as num?)?.toDouble() ??
                    (data['distance_miles'] as num?)?.toDouble() ??
                    existingActivity.actualDistanceMiles,
              ),
              actualDurationMinutes: Value(
                data['actual_duration_minutes'] as int? ??
                    data['duration_minutes'] as int? ??
                    existingActivity.actualDurationMinutes,
              ),
              garminSummaryId: Value(
                incomingGarminSummaryId ?? existingActivity.garminSummaryId,
              ),
              garminDeviceName: Value(
                (data['garmin_device_name'] as String?)?.trim() ??
                    existingActivity.garminDeviceName,
              ),
              updatedAt: Value(supabaseUpdatedAt),
            ),
          );

          if (enableNotifications &&
              _shouldNotifyGarminCompletion(
                existingActivity: existingActivity,
                incomingProvider: incomingProvider,
                incomingGarminSummaryId: incomingGarminSummaryId,
                incomingStatus: incomingStatus,
                supabaseUpdatedAt: supabaseUpdatedAt,
              ) &&
              !NotificationService.isRemotePushConfigured) {
            final title = (data['title'] as String?)?.trim();
            final scheduledAt = DateTime.parse(
              data['scheduled_date_time'] as String,
            );

            await NotificationService.showActivityUploadedNotification(
              activityId: activityId,
              title: title == null || title.isEmpty
                  ? 'Workout uploaded'
                  : title,
              activityDate: scheduledAt,
              provider: 'Garmin Connect',
            );
          }
        }
        return; // Keep local version with pending changes
      }

      if (existingActivity == null ||
          existingActivity.updatedAt.isBefore(supabaseUpdatedAt)) {
        final companion = ActivitiesTableCompanion.insert(
          id: Value(activityId),
          userId: userId,
          activityType: data['activity_type'] as String,
          title: data['title'] as String,
          scheduledDateTime: DateTime.parse(
            data['scheduled_date_time'] as String,
          ),
          status: Value(data['status'] as String? ?? 'planned'),
          distanceMiles: Value((data['distance_miles'] as num?)?.toDouble()),
          durationMinutes: Value(data['duration_minutes'] as int?),
          distanceMeters: Value((data['distance_meters'] as num?)?.toDouble()),
          paceTargetMinutesPerMile: Value(
            (data['pace_target_minutes_per_mile'] as num?)?.toDouble(),
          ),
          intensityLevel: Value(data['intensity_level'] as String?),
          cyclingSpeedMph: Value(
            (data['cycling_speed_mph'] as num?)?.toDouble(),
          ),
          cyclingTerrain: Value(data['cycling_terrain'] as String?),
          cyclingIndoorOutdoor: Value(
            data['cycling_indoor_outdoor'] as String?,
          ),
          cyclingElevationGainFt: Value(
            data['cycling_elevation_gain_ft'] as int?,
          ),
          cyclingSessionGoal: Value(data['cycling_session_goal'] as String?),
          swimmingPacePer100mSeconds: Value(
            data['swimming_pace_per_100m_seconds'] as int?,
          ),
          swimmingPoolOrOpenWater: Value(
            data['swimming_pool_or_open_water'] as String?,
          ),
          swimmingWaterTempC: Value(
            (data['swimming_water_temp_c'] as num?)?.toDouble(),
          ),
          intensityTarget: Value(data['intensity_target'] as String?),
          timeBeforeMinutes: Value(data['time_before_minutes'] as int?),
          // Tolerates old remote rows without the column (null → false).
          isFasted: Value(SyncTypeConverters.toBool(data['is_fasted'])),
          completedAt: Value(incomingCompletedAt),
          completionRating: Value(data['completion_rating'] as int?),
          completionNotes: Value(data['completion_notes'] as String?),
          actualDistanceMiles: Value(
            (data['actual_distance_miles'] as num?)?.toDouble(),
          ),
          actualDurationMinutes: Value(data['actual_duration_minutes'] as int?),
          nutritionPlanData: Value(
            _encodeJsonIfNeeded(data['nutrition_plan_data']),
          ),
          fuelLogData: Value(_encodeJsonIfNeeded(data['fuel_log_data'])),
          brickMetadata: Value(_encodeJsonIfNeeded(data['brick_metadata'])),
          brickId: Value(data['brick_id'] as String?),
          notes: Value(data['notes'] as String?),
          syncedFromProvider: Value(data['synced_from_provider'] as String?),
          providerWorkoutId: Value(data['provider_workout_id'] as String?),
          providerWorkoutUrl: Value(data['provider_workout_url'] as String?),
          lastSyncedAt: Value(
            data['last_synced_at'] != null
                ? DateTime.parse(data['last_synced_at'] as String)
                : null,
          ),
          needsNutritionRefresh: Value(
            SyncTypeConverters.toBool(data['needs_nutrition_refresh']),
          ),
          providerDeletedAt: Value(
            data['provider_deleted_at'] != null
                ? DateTime.parse(data['provider_deleted_at'] as String)
                : null,
          ),
          providerScheduledAt: Value(
            data['provider_scheduled_at'] != null
                ? DateTime.parse(data['provider_scheduled_at'] as String)
                : null,
          ),
          scheduleChangedAt: Value(
            data['schedule_changed_at'] != null
                ? DateTime.parse(data['schedule_changed_at'] as String)
                : null,
          ),
          garminSummaryId: Value(incomingGarminSummaryId),
          garminDeviceName: Value(
            (data['garmin_device_name'] as String?)?.trim(),
          ),
          createdAt: DateTime.parse(data['created_at'] as String),
          updatedAt: supabaseUpdatedAt,
        );

        await _database
            .into(_database.activitiesTable)
            .insert(companion, mode: InsertMode.insertOrReplace);

        // Notify when Garmin push marks an activity as newly completed.
        // We intentionally only notify for fresh server updates to avoid
        // spamming users on historical backfills or first-time full syncs.
        if (enableNotifications &&
            _shouldNotifyGarminCompletion(
              existingActivity: existingActivity,
              incomingProvider: incomingProvider,
              incomingGarminSummaryId: incomingGarminSummaryId,
              incomingStatus: incomingStatus,
              supabaseUpdatedAt: supabaseUpdatedAt,
            ) &&
            !NotificationService.isRemotePushConfigured) {
          final title = (data['title'] as String?)?.trim();
          final scheduledAt = DateTime.parse(
            data['scheduled_date_time'] as String,
          );

          await NotificationService.showActivityUploadedNotification(
            activityId: activityId,
            title: title == null || title.isEmpty ? 'Workout uploaded' : title,
            activityDate: scheduledAt,
            provider: 'Garmin Connect',
          );
        }
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

  bool _shouldNotifyGarminCompletion({
    required Activity? existingActivity,
    required String? incomingProvider,
    required String? incomingGarminSummaryId,
    required String incomingStatus,
    required DateTime supabaseUpdatedAt,
  }) {
    final isGarminCompletion =
        incomingStatus == 'completed' &&
        ((incomingProvider == 'garmin') ||
            (incomingGarminSummaryId != null &&
                incomingGarminSummaryId.isNotEmpty));

    if (!isGarminCompletion) {
      return false;
    }

    final wasAlreadyGarminCompleted =
        existingActivity != null &&
        existingActivity.completedAt != null &&
        existingActivity.status == 'completed';
    if (wasAlreadyGarminCompleted) {
      return false;
    }

    // Freshness gate to avoid noisy notifications from historical sync data.
    final nowUtc = DateTime.now().toUtc();
    final updatedAtUtc = supabaseUpdatedAt.toUtc();
    final age = nowUtc.difference(updatedAtUtc);
    if (age.isNegative) {
      return age.abs() <= _garminNotificationFreshnessWindow;
    }
    return age <= _garminNotificationFreshnessWindow;
  }

  bool _shouldMergeGarminCompletionIntoDirtyLocal({
    required Activity existingActivity,
    required String? incomingProvider,
    required String? incomingGarminSummaryId,
    required String incomingStatus,
  }) {
    final isGarminCompletion =
        incomingStatus == 'completed' &&
        ((incomingProvider == 'garmin') ||
            (incomingGarminSummaryId != null &&
                incomingGarminSummaryId.isNotEmpty));

    if (!isGarminCompletion) {
      return false;
    }

    return existingActivity.status != 'completed';
  }

  /// Sync multiple athlete activities (for coach view).
  Future<void> syncAthleteActivities(List<dynamic> activities) async {
    try {
      for (final activityData in activities) {
        await upsertActivity(
          activityData as Map<String, dynamic>,
          enableNotifications: false,
        );
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
      'status': _activityStatusToDbValue(activity.status),
      'distance_miles': activity.distanceMiles,
      'duration_minutes': activity.durationMinutes,
      'pace_target_minutes_per_mile': activity.paceTargetMinutesPerMile,
      'intensity_level': activity.intensityLevel,
      'intensity_target': activity.intensityTarget,
      'intensity_z1_z2_pct': activity.intensityZ1Z2Pct,
      'intensity_z3_z4_pct': activity.intensityZ3Z4Pct,
      'intensity_z5_pct': activity.intensityZ5Pct,
      'time_before_minutes': activity.timeBeforeMinutes,
      'is_fasted': activity.isFasted,
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
      'nutrition_plan_data': _decodeJsonIfNeeded(activity.nutritionPlanData),
      'fuel_log_data': _decodeJsonIfNeeded(activity.fuelLogData),
      'synced_from_provider': activity.syncedFromProvider,
      'provider_workout_id': activity.providerWorkoutId,
      'provider_workout_url': activity.providerWorkoutUrl,
      'last_synced_at': activity.lastSyncedAt?.toIso8601String(),
      'workout_subtype': activity.workoutSubtype,
      'pace_min_minutes_per_mile': activity.paceMinMinutesPerMile,
      'pace_max_minutes_per_mile': activity.paceMaxMinutesPerMile,
      'provider_deleted_at': activity.providerDeletedAt?.toIso8601String(),
      'provider_scheduled_at': activity.providerScheduledAt?.toIso8601String(),
      'schedule_changed_at': activity.scheduleChangedAt?.toIso8601String(),
      'brick_metadata': _decodeJsonIfNeeded(activity.brickMetadata),
      'brick_id': activity.brickId,
      'created_at': activity.createdAt.toIso8601String(),
      'updated_at': activity.updatedAt.toIso8601String(),
    };
  }

  /// Convert remote JSON/JSONB values to the local TEXT storage format.
  String? _encodeJsonIfNeeded(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    try {
      return jsonEncode(value);
    } catch (_) {
      return null;
    }
  }

  /// Convert local TEXT JSON payloads to JSON objects for upload when possible.
  dynamic _decodeJsonIfNeeded(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return jsonDecode(value);
    } catch (_) {
      return value;
    }
  }

  /// Convert local status values to Supabase enum-compatible values.
  String _activityStatusToDbValue(String status) {
    switch (status) {
      case 'inProgress':
        return 'in_progress';
      case 'archivedForBrick':
        return 'archived_for_brick';
      default:
        return status;
    }
  }
}
