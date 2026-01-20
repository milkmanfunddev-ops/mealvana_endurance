import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../shared/domain/activity_type.dart';
import '../domain/activity.dart' as domain;
import '../domain/brick_metadata.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/logging_service.dart';
import '../data/activities_repository.dart';
import '../../coach_mode/data/coach_repository.dart';

part 'activities_service.g.dart';

@riverpod
ActivitiesService activitiesService(Ref ref) {
  return ActivitiesService(
    ref.read(appDatabaseProvider),
    ref.read(appLoggerProvider),
    ref.read(activitiesRepositoryProvider),
    ref.read(coachRepositoryProvider),
  );
}

/// Service for managing calendar activities
/// Handles all activity-related operations including CRUD for running, cycling, and swimming activities
class ActivitiesService {
  final AppDatabase _database;
  final AppLogger _logger;
  final ActivitiesRepository _activitiesRepository;
  final CoachRepository _coachRepository;

  ActivitiesService(
    this._database,
    this._logger,
    this._activitiesRepository,
    this._coachRepository,
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
  /// If [forUserId] is provided and different from [userId], validates coach-athlete relationship
  Future<domain.Activity> createActivity({
    required String deviceId,
    required String userId,
    String? forUserId, // NEW: If provided, create activity for this user (coach creating for athlete)
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
    // Brick-specific parameters
    BrickMetadata? brickMetadata,
    String? brickId,
  }) async {
    try {
      // Determine the owner of the activity
      final ownerId = forUserId ?? userId;

      // Validate coach-athlete relationship if creating for someone else
      if (forUserId != null && forUserId != userId) {
        final hasActiveRelationship = await _coachRepository
            .isActiveCoachAthleteRelationship(
          coachUserId: userId,
          athleteUserId: forUserId,
        );

        if (!hasActiveRelationship) {
          _logger.error(
            'Coach does not have active relationship with athlete',
            context: 'ACTIVITIES_SERVICE',
            data: {
              'coachUserId': userId,
              'athleteUserId': forUserId,
            },
          );
          throw Exception(
              'Not authorized to create activities for this athlete');
        }
      }

      final now = DateTime.now();
      final activity = domain.Activity(
        id: '', // Empty string - will be auto-generated by database
        userId: ownerId, // Use ownerId (athlete if coach is creating for them)
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
        // Brick-specific fields
        brickMetadata: brickMetadata,
        brickId: brickId,
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
    String? forUserId, // NEW: If provided, create activity for this user (coach creating for athlete)
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
      forUserId: forUserId,
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
    String? forUserId, // NEW: If provided, create activity for this user (coach creating for athlete)
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
      forUserId: forUserId,
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

  /// Create a brick workout from existing activities (convenience method)
  /// Delegates to the repository's createBrickFromActivities method which:
  /// 1. Creates a new brick activity with BrickMetadata
  /// 2. Archives the original activities
  /// 3. Links them together via brick_id
  Future<domain.Activity> createBrickActivity({
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

      _logger.info(
        'Creating brick activity from existing activities',
        context: 'ACTIVITIES_SERVICE',
        data: {
          'activityCount': activities.length,
          'segmentOrder': segmentOrder,
          'activityIds': activities.map((a) => a.id).toList(),
        },
      );

      return await _activitiesRepository.createBrickFromActivities(
        activities: activities,
        segmentOrder: segmentOrder,
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Error creating brick activity',
        context: 'ACTIVITIES_SERVICE',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Update an existing activity
  /// If [currentUserId] is provided and different from activity.userId, validates coach-athlete relationship
  Future<domain.Activity> updateActivity({
    required String deviceId,
    required domain.Activity activity,
    String? currentUserId, // NEW: Current user ID (for validation if coach is editing athlete's activity)
  }) async {
    try {
      // Validate coach-athlete relationship if editing for someone else
      if (currentUserId != null && currentUserId != activity.userId) {
        final hasActiveRelationship = await _coachRepository
            .isActiveCoachAthleteRelationship(
          coachUserId: currentUserId,
          athleteUserId: activity.userId,
        );

        if (!hasActiveRelationship) {
          _logger.error(
            'Coach does not have active relationship with athlete',
            context: 'ACTIVITIES_SERVICE',
            data: {
              'coachUserId': currentUserId,
              'athleteUserId': activity.userId,
            },
          );
          throw Exception(
              'Not authorized to update activities for this athlete');
        }
      }

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
  /// If [currentUserId] is provided, validates coach-athlete relationship for cross-user deletion
  Future<void> deleteActivity({
    required String deviceId,
    required String activityId,
    String? currentUserId, // NEW: Current user ID (for validation if coach is deleting athlete's activity)
    String? activityOwnerId, // NEW: Activity owner ID (for validation)
  }) async {
    try {
      // Validate coach-athlete relationship if deleting for someone else
      if (currentUserId != null && activityOwnerId != null && currentUserId != activityOwnerId) {
        final hasActiveRelationship = await _coachRepository
            .isActiveCoachAthleteRelationship(
          coachUserId: currentUserId,
          athleteUserId: activityOwnerId,
        );

        if (!hasActiveRelationship) {
          _logger.error(
            'Coach does not have active relationship with athlete',
            context: 'ACTIVITIES_SERVICE',
            data: {
              'coachUserId': currentUserId,
              'athleteUserId': activityOwnerId,
            },
          );
          throw Exception(
              'Not authorized to delete activities for this athlete');
        }
      }

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
      // Brick-specific fields (parse JSON string from database)
      brickMetadata: activity.brickMetadata != null
          ? _parseBrickMetadata(activity.brickMetadata!)
          : null,
      brickId: activity.brickId,
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

  /// Parse brick metadata from JSON string
  BrickMetadata? _parseBrickMetadata(String jsonString) {
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return BrickMetadata.fromJson(json);
    } catch (e) {
      _logger.error(
        'Failed to parse brick metadata',
        context: 'ACTIVITIES_SERVICE',
        error: e,
      );
      return null;
    }
  }
}
