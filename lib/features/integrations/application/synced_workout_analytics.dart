import '../../../shared/services/analytics/analytics_events.dart';
import '../../../shared/services/analytics/analytics_tracker.dart';
import '../../activities/domain/activity.dart';

/// Fires `workout_planned` for a workout that arrived from a training platform
/// rather than being planned by hand in the app.
///
/// Provider-synced workouts never pass through ActivitiesController — the sync
/// services write straight to the repository — so without this the event could
/// only ever report `source: 'manual'` and the manual-vs-synced split would be
/// unmeasurable. Shared by the TrainingPeaks, Final Surge and V.O2 services so
/// the three cannot drift apart.
///
/// Analytics is never allowed to break a sync: all failures are swallowed.
void trackSyncedWorkoutPlanned(
  AnalyticsTracker? analytics,
  Activity activity, {
  required String provider,
}) {
  try {
    analytics?.trackWorkoutPlanned(
      sport: activity.activityType.name,
      source: 'synced',
      durationMinutes: activity.durationMinutes,
      activityId: activity.id,
      provider: provider,
    );
  } catch (_) {}
}
