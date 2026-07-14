import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../shared/domain/activity_type.dart';
import '../../application/activities_service.dart';
import '../../data/activities_repository.dart';
import '../../domain/activity.dart';
import '../../../../shared/services/analytics/analytics_tracker.dart';
import '../../../../shared/services/logging_service.dart';
import '../../../../shared/providers/user_id_provider.dart';
import '../../../../shared/services/sync/sync_coordinator.dart';
import '../../../auth/application/supabase_auth_service.dart';
import '../../../integrations/application/integration_sync_coordinator.dart';
import '../../domain/brick_metadata.dart';

part 'activities_controller.g.dart';

/// Controller for managing activities
/// Handles activity CRUD operations (create, read, update, delete)
///
/// NEW SYNC PATTERN (Phase 5.1):
/// - Uses ensureSynced() for dependency-aware, staleness-based sync
/// - Syncs activities (and users dependency) only when stale (>24h)
/// - Errors handled gracefully - user sees cached data on failure
@riverpod
class ActivitiesController extends _$ActivitiesController {
  ActivitiesService get _service => ref.read(activitiesServiceProvider);
  AppLogger get _logger => ref.read(appLoggerProvider);

  @override
  FutureOr<List<Activity>> build() async {
    // Watch auth state to trigger rebuilds on sign in/out
    ref.watch(currentUserProvider);
    final service = ref.read(activitiesServiceProvider);
    final integrationSyncCoordinator = ref.read(
      integrationSyncCoordinatorProvider.notifier,
    );

    final userId = await ref.read(userIdProvider.future);

    // Clean up any abandoned draft activities before loading
    await service.cleanupDraftActivities(userId);

    // 1. Load local data IMMEDIATELY (no blocking sync)
    final localData = await service.getAllActivities(userId);

    // 2. Background sync (fire-and-forget) - syncs if stale, then refreshes UI
    unawaited(_backgroundSync(userId));

    // 3. Background integration sync (non-blocking, fire-and-forget)
    unawaited(
      integrationSyncCoordinator
          .ensureIntegrationsSynced(userId)
          .then((anySynced) {
            if (anySynced) {
              if (!ref.mounted) return;
              ref.invalidateSelf();
            }
          })
          .catchError((_) {}),
    );

    return localData;
  }

  /// Background sync: ensures data is fresh, then refreshes UI only when data was stale
  Future<void> _backgroundSync(String userId) async {
    final repo = ref.read(activitiesRepositoryProvider);
    final syncCoordinator = ref.read(syncCoordinatorProvider.notifier);
    final logger = ref.read(appLoggerProvider);

    try {
      final wasStale = await repo.isStale();
      await syncCoordinator.ensureSynced(
        'activities',
        userId,
        repository: repo,
      );
      // Only refresh UI if data was stale AND sync actually succeeded.
      // We verify success by checking that staleness was cleared (timestamp updated).
      // Without this guard, a failed sync (e.g. dirty record upload error) leaves
      // wasStale=true forever, causing an infinite build→sync→invalidate loop.
      final stillStale = await repo.isStale();
      if (wasStale && !stillStale) {
        if (!ref.mounted) return;
        ref.invalidateSelf();
      }
    } catch (e, stackTrace) {
      logger.error(
        'Background sync failed',
        context: 'ACTIVITIES_CONTROLLER',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Create a new activity
  /// If [forUserId] is provided, creates activity for that user (coach creating for athlete)
  Future<String> createActivity({
    required String title,
    required DateTime scheduledDateTime,
    String?
    forUserId, // NEW: If provided, create activity for this user (coach creating for athlete)
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
    // Brick-specific parameters
    BrickMetadata? brickMetadata,
    String? brickId,
  }) async {
    try {
      // Read BEFORE the create — afterwards the list already contains the new
      // activity and the "was this their first?" test would never be true.
      final priorCount = state.value?.length ?? 0;
      final deviceIdValue = await ref.read(userIdProvider.future);

      final createdActivity = await _service.createActivity(
        deviceId: deviceIdValue,
        userId: deviceIdValue,
        forUserId:
            forUserId, // NEW: Pass through forUserId for coach-created activities
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
        brickMetadata: brickMetadata,
        brickId: brickId,
      );

      // The "used the core function" activation signal. Everything reaching
      // this controller is a user planning a workout by hand — provider-synced
      // workouts bypass it entirely (they go straight to the repository), so
      // `source` is always manual here.
      _track('workout_planned', {
        'sport': activityType.name,
        'duration_min': durationMinutes,
        'source': 'manual',
        'activity_id': createdActivity.id,
        'is_coach_created': forUserId != null,
      });

      // Fires only for the very first activity a user ever creates — the
      // post-onboarding activation milestone.
      if (priorCount == 0) {
        _track('first_activity_added', {
          'activity_type': activityType.name,
          'activity_id': createdActivity.id,
        });
      }

      // Refresh activities list
      ref.invalidateSelf();

      return createdActivity.id;
    } catch (e) {
      _logger.error('Error creating activity', error: e);
      rethrow;
    }
  }

  void _track(String event, Map<String, dynamic> properties) {
    try {
      ref.read(analyticsTrackerProvider).track(event, properties: properties);
    } catch (_) {
      // Analytics must never fail an activity create.
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
      final endOfDay = startOfDay
          .add(const Duration(days: 1))
          .subtract(const Duration(seconds: 1));

      return await _service.getActivitiesForDateRange(
        userId,
        startOfDay,
        endOfDay,
      );
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

  /// Refresh activities list (uses cached data, respects staleness)
  Future<void> refresh() async {
    ref.invalidateSelf();
  }

  /// Force refresh activities from Supabase and integrations (bypasses staleness).
  ///
  /// Use this for pull-to-refresh when user explicitly wants fresh data,
  /// or when athlete needs to see coach-made changes immediately.
  /// Runs Supabase sync and integration sync in parallel with a 20s timeout.
  Future<void> forceRefresh() async {
    try {
      final userId = await ref.read(userIdProvider.future);

      await Future.wait([
        ref
            .read(syncCoordinatorProvider.notifier)
            .forceSyncRepository(
              'activities',
              userId,
              repository: ref.read(activitiesRepositoryProvider),
            ),
        ref
            .read(integrationSyncCoordinatorProvider.notifier)
            .forceSyncIntegrations(userId),
      ]).timeout(const Duration(seconds: 20), onTimeout: () => [null, null]);

      ref.invalidateSelf();
    } catch (e) {
      _logger.error('Error during force refresh', error: e);
      ref.invalidateSelf();
    }
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
