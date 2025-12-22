import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../shared/domain/activity_type.dart';
import '../domain/activity.dart' as domain;
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/logging_service.dart';
import '../data/activities_repository.dart';

part 'activities_service.g.dart';

@riverpod
ActivitiesService activitiesService(Ref ref) {
  return ActivitiesService(
    ref.read(appDatabaseProvider),
    ref.read(appLoggerProvider),
    ref.read(activitiesRepositoryProvider),
  );
}

/// Service for managing calendar activities
/// Handles all activity-related operations including CRUD for running, cycling, and swimming activities
class ActivitiesService {
  final AppDatabase _database;
  final AppLogger _logger;
  final ActivitiesRepository _activitiesRepository;

  ActivitiesService(
    this._database,
    this._logger,
    this._activitiesRepository,
  );

  /// Get activities for a specific date range
  Future<List<domain.Activity>> getActivitiesForDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      // CRITICAL FIX: Use case-insensitive comparison for userId
      // Supabase returns lowercase UUIDs, but local user profile may have uppercase
      final query = _database.select(_database.activitiesTable)
            ..where((tbl) => tbl.userId.lower().equals(userId.toLowerCase()) &
                              tbl.scheduledDateTime.isBetweenValues(startDate, endDate) &
                              tbl.deletedAt.isNull())
            ..orderBy([(tbl) => OrderingTerm.asc(tbl.scheduledDateTime)]);

      final activities = await query.get();

      return _mapActivitiesAsync(activities);
    } catch (e) {
      _logger.error('Error getting activities for date range', error: e);
      rethrow;
    }
  }

  /// Get activities for a specific week
  Future<List<domain.Activity>> getActivitiesForWeek(String userId, DateTime weekStart) async {
    final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    return getActivitiesForDateRange(userId, weekStart, weekEnd);
  }

  /// Get all activities for a user (no date filter)
  Future<List<domain.Activity>> getAllActivities(String userId) async {
    try {
      // CRITICAL FIX: Use case-insensitive comparison for userId
      final query = _database.select(_database.activitiesTable)
            ..where((tbl) => tbl.userId.lower().equals(userId.toLowerCase()) &
                              tbl.deletedAt.isNull())
            ..orderBy([(tbl) => OrderingTerm.desc(tbl.scheduledDateTime)]);

      final activities = await query.get();

      return _mapActivitiesAsync(activities);
    } catch (e) {
      _logger.error('Error getting all activities', error: e);
      rethrow;
    }
  }

  /// Helper to map activities asynchronously yielding to the event loop
  /// This prevents the main thread from freezing during heavy syncs
  Future<List<domain.Activity>> _mapActivitiesAsync(List<Activity> activities) async {
    final result = <domain.Activity>[];
    final stopwatch = Stopwatch()..start();

    for (var i = 0; i < activities.length; i++) {
      // Yield every 5 items OR if we've been processing for more than 16ms (1 frame)
      if (i > 0 && (i % 5 == 0 || stopwatch.elapsedMilliseconds > 16)) {
        await Future.delayed(Duration.zero);
        stopwatch.reset();
      }
      result.add(mapToActivityDomain(activities[i]));
    }
    return result;
  }

  /// Get a specific activity by ID
  Future<domain.Activity?> getActivityById(String userId, String activityId) async {
    try {
      _logger.info(
        'Fetching activity by ID',
        context: 'ACTIVITIES_SERVICE',
        data: {
          'userId': userId,
          'activityId': activityId,
        },
      );

      // CRITICAL FIX: Use case-insensitive comparison for userId
      final query = _database.select(_database.activitiesTable)
            ..where((tbl) => tbl.userId.lower().equals(userId.toLowerCase()) &
                              tbl.id.equals(activityId) &
                              tbl.deletedAt.isNull());

      final activity = await query.getSingleOrNull();

      if (activity == null) {
        _logger.warning(
          'Activity not found in database',
          context: 'ACTIVITIES_SERVICE',
          data: {
            'userId': userId,
            'activityId': activityId,
            'searchedWithDeletedAtNull': true,
          },
        );
        return null;
      }

      _logger.info(
        'Activity found successfully',
        context: 'ACTIVITIES_SERVICE',
        data: {
          'activityId': activity.id,
          'title': activity.title,
          'hasNutritionPlan': activity.nutritionPlanData != null,
        },
      );

      return mapToActivityDomain(activity);
    } catch (e) {
      _logger.error(
        'Error getting activity by ID',
        context: 'ACTIVITIES_SERVICE',
        error: e,
        data: {
          'userId': userId,
          'activityId': activityId,
        },
      );
      rethrow;
    }
  }

  /// Create a new running activity
  Future<domain.Activity> createActivity({
    required String deviceId,
    required String userId,
    required ActivityType activityType,
    required String title,
    required DateTime scheduledDateTime,
    double? distanceMiles,
    int? durationMinutes,
    double? paceTargetMinutesPerMile,
    domain.IntensityLevel? intensityLevel,
    String? notes,
    // Cycling-specific parameters
    double? cyclingSpeedMph,
    String? cyclingTerrain,
    String? cyclingIndoorOutdoor,
    int? cyclingElevationGainFt,
    String? cyclingSessionGoal,
    // Swimming-specific parameters
    int? swimmingPacePer100mSeconds,
    String? swimmingPoolOrOpenWater,
    double? swimmingWaterTempC,
    // Shared parameters
    String? intensityTarget,
    int? timeBeforeMinutes,
    // Nutrition plan data (embedded JSON)
    Map<String, dynamic>? nutritionPlanData,
  }) async {
    try {
      final now = DateTime.now();
      final activity = domain.Activity(
        id: '', // Empty string - will be auto-generated by database
        userId: userId,
        activityType: activityType,
        title: title,
        scheduledDateTime: scheduledDateTime,
        status: domain.ActivityStatus.planned,
        distanceMiles: distanceMiles,
        durationMinutes: durationMinutes,
        paceTargetMinutesPerMile: paceTargetMinutesPerMile,
        intensityLevel: intensityLevel,
        notes: notes,
        // Cycling-specific fields
        cyclingSpeedMph: cyclingSpeedMph,
        cyclingTerrain: cyclingTerrain,
        cyclingIndoorOutdoor: cyclingIndoorOutdoor,
        cyclingElevationGainFt: cyclingElevationGainFt,
        cyclingSessionGoal: cyclingSessionGoal,
        // Swimming-specific fields
        swimmingPacePer100mSeconds: swimmingPacePer100mSeconds,
        swimmingPoolOrOpenWater: swimmingPoolOrOpenWater,
        swimmingWaterTempC: swimmingWaterTempC,
        // Shared fields
        intensityTarget: intensityTarget,
        timeBeforeMinutes: timeBeforeMinutes,
        // Nutrition plan data (embedded JSON)
        nutritionPlanData: nutritionPlanData,
        createdAt: now,
        updatedAt: now,
      );

      return await _activitiesRepository.createActivity(
        deviceId: deviceId,
        activity: activity,
      );
    } catch (e, stackTrace) {
      _logger.error('Error creating activity', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Create a new cycling activity (convenience method)
  Future<domain.Activity> createCyclingActivity({
    required String deviceId,
    required String userId,
    required String title,
    required DateTime scheduledDateTime,
    required double distanceMiles,
    required int durationMinutes,
    required double cyclingSpeedMph,
    String? cyclingTerrain,
    String? cyclingIndoorOutdoor,
    int? cyclingElevationGainFt,
    String? cyclingSessionGoal,
    String? intensityTarget,
    int? timeBeforeMinutes,
    String? notes,
  }) async {
    return createActivity(
      deviceId: deviceId,
      userId: userId,
      activityType: ActivityType.cycling,
      title: title,
      scheduledDateTime: scheduledDateTime,
      distanceMiles: distanceMiles,
      durationMinutes: durationMinutes,
      cyclingSpeedMph: cyclingSpeedMph,
      cyclingTerrain: cyclingTerrain,
      cyclingIndoorOutdoor: cyclingIndoorOutdoor,
      cyclingElevationGainFt: cyclingElevationGainFt,
      cyclingSessionGoal: cyclingSessionGoal,
      intensityTarget: intensityTarget,
      timeBeforeMinutes: timeBeforeMinutes,
      notes: notes,
    );
  }

  /// Create a new swimming activity (convenience method)
  Future<domain.Activity> createSwimmingActivity({
    required String deviceId,
    required String userId,
    required String title,
    required DateTime scheduledDateTime,
    required double distanceMiles,
    required int durationMinutes,
    required int swimmingPacePer100mSeconds,
    String? swimmingPoolOrOpenWater,
    double? swimmingWaterTempC,
    String? intensityTarget,
    int? timeBeforeMinutes,
    String? notes,
  }) async {
    return createActivity(
      deviceId: deviceId,
      userId: userId,
      activityType: ActivityType.swimming,
      title: title,
      scheduledDateTime: scheduledDateTime,
      distanceMiles: distanceMiles,
      durationMinutes: durationMinutes,
      swimmingPacePer100mSeconds: swimmingPacePer100mSeconds,
      swimmingPoolOrOpenWater: swimmingPoolOrOpenWater,
      swimmingWaterTempC: swimmingWaterTempC,
      intensityTarget: intensityTarget,
      timeBeforeMinutes: timeBeforeMinutes,
      notes: notes,
    );
  }

  /// Update an existing activity
  Future<domain.Activity> updateActivity({
    required String deviceId,
    required domain.Activity activity,
  }) async {
    try {
      return await _activitiesRepository.updateActivity(
        deviceId: deviceId,
        activity: activity.copyWith(updatedAt: DateTime.now()),
      );
    } catch (e, stackTrace) {
      _logger.error('Error updating activity', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Delete an activity (soft delete)
  Future<void> deleteActivity({
    required String deviceId,
    required String activityId,
  }) async {
    try {
      await _activitiesRepository.deleteActivity(
        deviceId: deviceId,
        activityId: activityId,
      );
    } catch (e, stackTrace) {
      _logger.error('Error deleting activity', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Map database Activity to domain Activity
  /// Public to support Drift streams in controllers
  domain.Activity mapToActivityDomain(Activity activity) {
    // Log nutrition plan data presence for debugging
    // if (activity.nutritionPlanData != null) {
    //   _logger.info(
    //     'Mapping activity with nutrition plan data',
    //     context: 'ACTIVITIES_SERVICE',
    //     data: {
    //       'activityId': activity.id,
    //       'hasNutritionPlan': true,
    //       'nutritionPlanDataSize': activity.nutritionPlanData!.length,
    //     },
    //   );
    // }

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
              orElse: () => domain.IntensityLevel.easy,
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
      // Nutrition plan data (parse JSON string from database)
      nutritionPlanData: activity.nutritionPlanData != null
          ? _parseNutritionPlanData(activity.nutritionPlanData!)
          : null,
      completedAt: activity.completedAt,
      completionRating: activity.completionRating,
      completionNotes: activity.completionNotes,
      actualDistanceMiles: activity.actualDistanceMiles,
      actualDurationMinutes: activity.actualDurationMinutes,
      notes: activity.notes,
      createdAt: activity.createdAt,
      updatedAt: activity.updatedAt,
      deletedAt: activity.deletedAt,
      // Reminder fields
      reminderEnabled: activity.reminderEnabled,
      reminderDaysBefore: activity.reminderDaysBefore,
      reminderTimeOfDay: activity.reminderTimeOfDay,
      reminderRecurring: activity.reminderRecurring,
      // Sync fields
      needsUpload: activity.needsUpload,
      localUpdatedAt: activity.localUpdatedAt,
    );
  }

  /// Parse nutrition plan data from JSON string
  Map<String, dynamic>? _parseNutritionPlanData(String jsonString) {
    try {
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      _logger.error(
        'Failed to parse nutrition plan data',
        context: 'ACTIVITIES_SERVICE',
        error: e,
      );
      return null;
    }
  }
}
