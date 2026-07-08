import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../shared/domain/activity_type.dart';
import '../../application/activities_service.dart';
import '../../data/activities_repository.dart';
import '../../domain/activity.dart';
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

    // 2. Background sync (fire-and-forget) - syncs if stale, then refreshes
    //    state IN PLACE (no invalidateSelf) so dependents don't see a second
    //    build/spinner and don't re-trigger these background syncs again.
    unawaited(_backgroundSync(userId));

    // 3. Background integration sync (non-blocking, fire-and-forget) - also
    //    refreshes state in place, sharing the same dedupe path as #2 so a
    //    sync that changes nothing never ripples into a rebuild.
    unawaited(
      integrationSyncCoordinator
          .ensureIntegrationsSynced(userId)
          .then((anySynced) async {
            if (anySynced) {
              await _refreshInPlace(userId);
            }
          })
          .catchError((_) {}),
    );

    return localData;
  }

  /// Re-fetch local activities and update [state] in place, but only if the
  /// data actually changed.
  ///
  /// This is the single dedupe path shared by both background sync
  /// mechanisms (`_backgroundSync` and integration sync). Using a direct
  /// `state = AsyncData(...)` assignment instead of `invalidateSelf()` means:
  /// - No second build()/spinner (AsyncNotifier doesn't re-run build() for a
  ///   direct state assignment).
  /// - No chained re-invocation of the background syncs kicked off in
  ///   build() (which is what caused the double/triple dashboard load, since
  ///   invalidateSelf() re-ran build() which re-fired both syncs).
  /// - Watchers (fuel_timeline, daily_macros) only see a new emission when
  ///   the activity list genuinely differs, since `Activity` has value
  ///   equality and `listEquals` does an element-wise compare.
  Future<void> _refreshInPlace(String userId) async {
    if (!ref.mounted) return;
    final fresh = await _service.getAllActivities(userId);
    if (!ref.mounted) return;

    final current = state.value;
    if (current != null && listEquals(current, fresh)) {
      return; // No real change - don't emit, don't ripple to watchers.
    }
    state = AsyncData(fresh);
  }

  /// Background sync: ensures data is fresh, then refreshes state in place
  /// only when data was stale AND the sync actually produced different data.
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
        await _refreshInPlace(userId);
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
  ///
  /// Removes the activity from the current list state IN PLACE rather than
  /// calling `invalidateSelf()`. invalidateSelf forces a full re-fetch, which
  /// pushes dependents (the fuel-timeline dashboard) through a loading
  /// transition — that rebuilds the Scaffold hosting the "Activity deleted"
  /// snackbar and orphans its auto-dismiss timer (the snackbar sticks), and
  /// also flashes the card instead of removing it cleanly. Optimistic
  /// removal disappears the card instantly, keeps the snackbar timer intact,
  /// and rolls back if the persist fails.
  Future<void> deleteActivity(String activityId) async {
    final previous = state.value ?? const <Activity>[];
    // Optimistically drop the card so the UI updates immediately with no
    // loading flash.
    state = AsyncData(
      previous.where((a) => a.id != activityId).toList(growable: false),
    );
    try {
      final deviceIdValue = await ref.read(userIdProvider.future);

      await _service.deleteActivity(
        deviceId: deviceIdValue,
        activityId: activityId,
      );
    } catch (e) {
      _logger.error('Error deleting activity', error: e);
      // Roll back the optimistic removal so the card reappears on failure.
      if (ref.mounted) state = AsyncData(previous);
      rethrow;
    }
  }

  /// Restore a just-deleted activity — the "Undo" affordance on the fuel
  /// timeline's swipe-delete.
  ///
  /// Optimistically re-inserts [activity] into list state (ordered by schedule)
  /// and persists WITHOUT `invalidateSelf()`, exactly mirroring [deleteActivity].
  /// Using the general [updateActivity] here would call `invalidateSelf()`,
  /// pushing dependents (the fuel-timeline dashboard) through a loading
  /// transition that rebuilds the Scaffold hosting the "Activity deleted"
  /// snackbar and orphans its auto-dismiss timer. Writing the pre-delete
  /// [Activity] back clears the soft-delete because its `deletedAt` is null.
  Future<void> restoreActivity(Activity activity) async {
    final previous = state.value ?? const <Activity>[];
    // Optimistically re-add (guard against a duplicate) and keep the list
    // ordered by scheduled time so the card reappears in its original slot.
    final next = [
      ...previous.where((a) => a.id != activity.id),
      activity,
    ]..sort((a, b) => a.scheduledDateTime.compareTo(b.scheduledDateTime));
    state = AsyncData(List.unmodifiable(next));
    try {
      final deviceIdValue = await ref.read(userIdProvider.future);
      await _service.updateActivity(
        deviceId: deviceIdValue,
        activity: activity,
      );
    } catch (e) {
      _logger.error('Error restoring activity', error: e);
      // Roll back the optimistic restore so the card disappears again.
      if (ref.mounted) state = AsyncData(previous);
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
