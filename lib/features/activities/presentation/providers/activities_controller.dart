import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../shared/domain/activity_type.dart';
import '../../application/activities_service.dart';
import '../../domain/activity.dart';
import '../../../../shared/services/logging_service.dart';
import '../../../../shared/providers/user_id_provider.dart';
import '../../../auth/application/supabase_auth_service.dart';

part 'activities_controller.g.dart';

/// Controller for managing activities
/// Handles activity CRUD operations (create, read, update, delete)
@riverpod
class ActivitiesController extends _$ActivitiesController {
  ActivitiesService get _service => ref.read(activitiesServiceProvider);
  AppLogger get _logger => ref.read(appLoggerProvider);

  @override
  FutureOr<List<Activity>> build() async {
    // Watch auth state to trigger rebuilds on sign in/out
    ref.watch(currentUserProvider);
    
    // Load all activities on build
    final userId = await ref.read(userIdProvider.future);
    return await _service.getAllActivities(userId);
  }

  /// Create a new activity
  Future<int> createActivity({
    required String title,
    required DateTime scheduledDateTime,
    ActivityType activityType = ActivityType.running,
    double? distanceMiles,
    int? durationMinutes,
    double? paceTargetMinutesPerMile,
    IntensityLevel? intensityLevel,
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
      final deviceIdValue = await ref.read(userIdProvider.future);

      final createdActivity = await _service.createActivity(
        deviceId: deviceIdValue,
        userId: deviceIdValue,
        activityType: activityType,
        title: title,
        scheduledDateTime: scheduledDateTime,
        distanceMiles: distanceMiles,
        durationMinutes: durationMinutes,
        paceTargetMinutesPerMile: paceTargetMinutesPerMile,
        intensityLevel: intensityLevel,
        notes: notes,
        cyclingSpeedMph: cyclingSpeedMph,
        cyclingTerrain: cyclingTerrain,
        cyclingIndoorOutdoor: cyclingIndoorOutdoor,
        cyclingElevationGainFt: cyclingElevationGainFt,
        cyclingSessionGoal: cyclingSessionGoal,
        swimmingPacePer100mSeconds: swimmingPacePer100mSeconds,
        swimmingPoolOrOpenWater: swimmingPoolOrOpenWater,
        swimmingWaterTempC: swimmingWaterTempC,
        intensityTarget: intensityTarget,
        timeBeforeMinutes: timeBeforeMinutes,
        nutritionPlanData: nutritionPlanData,
      );

      // Refresh activities list
      ref.invalidateSelf();

      return createdActivity.id;
    } catch (e) {
      _logger.error('Error creating activity', error: e);
      rethrow;
    }
  }

  /// Update an existing activity
  Future<void> updateActivity(Activity activity) async {
    try {
      final deviceIdValue = await ref.read(userIdProvider.future);

      await _service.updateActivity(
        deviceId: deviceIdValue,
        activity: activity,
      );

      // Refresh activities list
      ref.invalidateSelf();
    } catch (e) {
      _logger.error('Error updating activity', error: e);
      rethrow;
    }
  }

  /// Delete an activity (soft delete)
  Future<void> deleteActivity(int activityId) async {
    try {
      final deviceIdValue = await ref.read(userIdProvider.future);

      await _service.deleteActivity(
        deviceId: deviceIdValue,
        activityId: activityId,
      );

      // Refresh activities list
      ref.invalidateSelf();
    } catch (e) {
      _logger.error('Error deleting activity', error: e);
      rethrow;
    }
  }

  /// Get activities for a specific date
  Future<List<Activity>> getActivitiesForDate(DateTime date) async {
    try {
      final userId = await ref.read(userIdProvider.future);
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));

      return await _service.getActivitiesForDateRange(userId, startOfDay, endOfDay);
    } catch (e) {
      _logger.error('Error getting activities for date', error: e);
      rethrow;
    }
  }

  /// Get activity by ID
  Future<Activity?> getActivityById(int activityId) async {
    try {
      final userId = await ref.read(userIdProvider.future);
      return await _service.getActivityById(userId, activityId);
    } catch (e) {
      _logger.error('Error getting activity by ID', error: e);
      rethrow;
    }
  }

  /// Refresh activities list
  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

/// Provider for getting a specific activity by ID
@riverpod
Future<Activity?> activityDetail(Ref ref, int activityId) async {
  final userId = await ref.read(userIdProvider.future);
  final service = ref.read(activitiesServiceProvider);
  return await service.getActivityById(userId, activityId);
}

/// Provider for getting all activities
@riverpod
Future<List<Activity>> allActivities(Ref ref) async {
  final userId = await ref.read(userIdProvider.future);
  final service = ref.read(activitiesServiceProvider);
  return await service.getAllActivities(userId);
}
