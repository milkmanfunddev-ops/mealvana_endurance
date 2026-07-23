import 'dart:async';

import 'package:mealvana_endurance/core/utils/debug_logger.dart';
import '../../activities/application/activities_service.dart';
import '../../activities/domain/activity.dart' as domain;

/// Service responsible for cleaning up draft activities when users navigate away
/// before finalizing their nutrition plans.
///
/// This service handles:
/// - Scheduling cleanup after navigation (with delay)
/// - Checking if activity is still in draft status
/// - Deleting draft activities safely
class DraftActivityCleanupService {
  DraftActivityCleanupService({required this.activitiesService});

  final ActivitiesService activitiesService;

  /// Pending cleanup timers, tracked so they can be cancelled on [dispose].
  ///
  /// Without this, the fire-and-forget `Future.delayed` left an uncancellable
  /// timer that (a) outlived widget tests — tripping "A Timer is still pending"
  /// — and (b) could never be torn down deterministically. Using real [Timer]s
  /// keeps the post-navigation cleanup behaviour while making it cancellable at
  /// scope/app teardown.
  final Set<Timer> _pending = {};
  bool _disposed = false;

  /// Schedule cleanup of a draft activity after a delay.
  ///
  /// This should be called when the user navigates away from the macro generation flow.
  /// The delay allows navigation to complete before checking if cleanup is needed.
  ///
  /// Only cleanup if the activity is still in draft status (not finalized).
  void scheduleCleanup({
    required String? activityId,
    required String userId,
    Duration delay = const Duration(seconds: 2),
  }) {
    // No-op once disposed (scope/app teardown) — and guards against scheduling
    // a new timer after dispose regardless of provider teardown order.
    if (_disposed) return;
    // Only cleanup if we have a draft activity ID
    if (activityId == null || activityId.isEmpty) return;

    // Schedule cleanup after a delay to allow navigation to complete. The
    // timer is tracked so [dispose] can cancel it (e.g. at app/scope teardown).
    late final Timer timer;
    timer = Timer(delay, () async {
      _pending.remove(timer);
      await cleanupIfNeeded(activityId: activityId, userId: userId);
    });
    _pending.add(timer);
  }

  /// Cancel any pending cleanup timers. Called when the owning provider is
  /// disposed (scope/app teardown), which also keeps widget tests timer-clean.
  void dispose() {
    _disposed = true;
    for (final timer in _pending) {
      timer.cancel();
    }
    _pending.clear();
  }

  /// Clean up draft activity if it's still in draft status.
  ///
  /// This method:
  /// 1. Fetches the activity by ID
  /// 2. Checks if status is still 'draft'
  /// 3. Deletes the activity if it's a draft
  ///
  /// Failures are logged but not thrown (cleanup failure is acceptable).
  Future<void> cleanupIfNeeded({
    required String activityId,
    required String userId,
  }) async {
    try {
      final activity = await activitiesService.getActivityById(
        userId,
        activityId,
      );

      if (activity != null && activity.status == domain.ActivityStatus.draft) {
        DebugLogger.info(
          '🗑️ CLEANUP: Deleting draft activity $activityId (status: ${activity.status.name})',
        );
        await activitiesService.deleteActivity(
          deviceId: userId,
          activityId: activityId,
        );
        DebugLogger.info('✅ CLEANUP: Draft activity deleted successfully');
      } else if (activity != null) {
        DebugLogger.info(
          '⏭️ CLEANUP: Skipping cleanup - activity status is ${activity.status.name}',
        );
      } else {
        DebugLogger.info('⏭️ CLEANUP: Skipping cleanup - activity not found');
      }
    } catch (e) {
      DebugLogger.error('❌ CLEANUP: Failed to cleanup draft activity: $e');
      // Don't rethrow - cleanup failure is acceptable
    }
  }
}
