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
  DraftActivityCleanupService({
    required this.activitiesService,
  });

  final ActivitiesService activitiesService;

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
    // Only cleanup if we have a draft activity ID
    if (activityId != null && activityId.isNotEmpty) {
      // Schedule cleanup after a delay to allow navigation to complete
      Future.delayed(delay, () async {
        await cleanupIfNeeded(
          activityId: activityId,
          userId: userId,
        );
      });
    }
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
        DebugLogger.info(
          '⏭️ CLEANUP: Skipping cleanup - activity not found',
        );
      }
    } catch (e) {
      DebugLogger.error('❌ CLEANUP: Failed to cleanup draft activity: $e');
      // Don't rethrow - cleanup failure is acceptable
    }
  }
}
