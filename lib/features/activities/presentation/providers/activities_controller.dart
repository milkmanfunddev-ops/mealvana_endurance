import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../shared/domain/activity_type.dart';
import '../../application/activities_service.dart';
import '../../domain/activity.dart';
import '../../../../shared/services/logging_service.dart';
import '../../../../shared/providers/user_id_provider.dart';
import '../../../../shared/services/sync/sync_coordinator.dart';
import '../../../auth/application/supabase_auth_service.dart';

part 'activities_controller.g.dart';

/// Controller for managing activities
/// Handles activity CRUD operations (create, read, update, delete)
///
/// STALE-WHILE-REVALIDATE PATTERN:
/// - Loads cached Drift data immediately (0-50ms)
/// - Syncs in background without blocking UI
/// - UI refreshes when sync completes (via ref.invalidateSelf)
@riverpod
class ActivitiesController extends _$ActivitiesController {
  ActivitiesService get _service => ref.read(activitiesServiceProvider);
  AppLogger get _logger => ref.read(appLoggerProvider);

  // Flag to prevent infinite sync loop on provider invalidation
  bool _syncTriggered = false;

  @override
  FutureOr<List<Activity>> build() async {
    // Watch auth state to trigger rebuilds on sign in/out
    ref.watch(currentUserProvider);

    final userId = await ref.read(userIdProvider.future);

    // STALE-WHILE-REVALIDATE: Load cached data immediately
    final cachedActivities = await _service.getAllActivities(userId);

    // Only sync once per controller instance lifecycle
    // Prevents infinite loop: build → sync → invalidate → rebuild → (no sync)
    if (!_syncTriggered) {
      _syncTriggered = true;
      unawaited(_syncInBackground(userId));
    }

    return cachedActivities;
  }

  /// Sync in background without blocking UI
  /// Errors are logged but don't show to user (they already see cached data)
  /// On success, sync coordinator invalidates providers triggering rebuild
  Future<void> _syncInBackground(String userId) async {
    try {
      await ref.read(syncCoordinatorProvider.notifier).sync(
            userId: userId,
            trigger: SyncTrigger.pullToRefresh,
          );
    } catch (e, stackTrace) {
      _logger.error(
        'Background sync failed',
        context: 'ACTIVITIES_CONTROLLER',
        error: e,
        stackTrace: stackTrace,
      );
      // Don't show error to user - they already see cached data
    }
  }

  /// Create a new activity
  /// If [forUserId] is provided, creates activity for that user (coach creating for athlete)
  Future<String> createActivity({
    required String title,
    required DateTime scheduledDateTime,
    String? forUserId, // NEW: If provided, create activity for this user (coach creating for athlete)
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
        forUserId: forUserId, // NEW: Pass through forUserId for coach-created activities
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
  Future<void> deleteActivity(String activityId) async {
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
  Future<Activity?> getActivityById(String activityId) async {
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
Future<Activity?> activityDetail(Ref ref, String activityId) async {
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
