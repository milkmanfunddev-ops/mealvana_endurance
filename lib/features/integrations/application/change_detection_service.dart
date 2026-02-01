import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../activities/domain/activity.dart';
import '../domain/sync_change_result.dart';

part 'change_detection_service.g.dart';

/// Service for detecting changes between local activities and remote provider workouts
///
/// Compares local activities with remote workouts from providers (Final Surge, Training Peaks)
/// to determine what needs to be inserted, updated, or soft-deleted.
///
/// Schedule change significance criteria:
/// - Time changed by > 30 minutes
/// - Date changed (different day)
/// - Duration changed by > 15 minutes
/// - Distance changed by > 10%
@riverpod
ChangeDetectionService changeDetectionService(Ref ref) {
  return ChangeDetectionService();
}

class ChangeDetectionService {
  /// Threshold for significant time change (in minutes)
  static const int significantTimeChangeMinutes = 30;

  /// Threshold for significant duration change (in minutes)
  static const int significantDurationChangeMinutes = 15;

  /// Threshold for significant distance change (percentage)
  static const double significantDistanceChangePercentage = 10.0;

  /// Detect changes between local activities and remote provider workouts
  ///
  /// [localActivities] - Activities currently in local database (synced from this provider)
  /// [remoteWorkouts] - Workouts fetched from provider API (as Activity objects after transformation)
  /// [provider] - Provider name ('final_surge', 'training_peaks')
  ///
  /// Returns [SyncChangeResult] with categorized changes
  SyncChangeResult detectChanges({
    required List<Activity> localActivities,
    required List<Activity> remoteWorkouts,
    required String provider,
  }) {
    final newActivities = <Activity>[];
    final updatedActivities = <ActivityChange>[];
    final deletedActivityIds = <String>[];
    int unchangedCount = 0;

    // Create lookup map for local activities by provider_workout_id
    final localByProviderId = <String, Activity>{};
    for (final activity in localActivities) {
      if (activity.providerWorkoutId != null) {
        localByProviderId[activity.providerWorkoutId!] = activity;
      }
    }

    // Create lookup set for remote provider workout IDs
    final remoteProviderIds = <String>{};
    for (final workout in remoteWorkouts) {
      if (workout.providerWorkoutId != null) {
        remoteProviderIds.add(workout.providerWorkoutId!);
      }
    }

    // Process remote workouts
    for (final remoteWorkout in remoteWorkouts) {
      final providerId = remoteWorkout.providerWorkoutId;
      if (providerId == null) continue;

      final localActivity = localByProviderId[providerId];

      if (localActivity == null) {
        // NEW: Workout exists in remote but not in local
        newActivities.add(remoteWorkout);
        if (kDebugMode) {
          debugPrint('   📥 NEW: ${remoteWorkout.title} (provider_id: $providerId)');
        }
      } else {
        // EXISTS: Check if schedule changed
        final scheduleChanged = _isScheduleChangeSignificant(
          localActivity,
          remoteWorkout,
        );

        if (scheduleChanged) {
          // UPDATED: Schedule changed significantly
          updatedActivities.add(
            ActivityChange(
              activityId: localActivity.id,
              updatedActivity: remoteWorkout,
              scheduleChanged: true,
              oldScheduledAt: localActivity.scheduledDateTime,
              newScheduledAt: remoteWorkout.scheduledDateTime,
              oldDurationMinutes: localActivity.durationMinutes,
              newDurationMinutes: remoteWorkout.durationMinutes,
              oldDistanceMiles: localActivity.distanceMiles,
              newDistanceMiles: remoteWorkout.distanceMiles,
            ),
          );
          if (kDebugMode) {
            debugPrint('   🔄 UPDATED (schedule): ${remoteWorkout.title}');
            debugPrint('      Old: ${localActivity.scheduledDateTime}, duration: ${localActivity.durationMinutes}, distance: ${localActivity.distanceMiles}');
            debugPrint('      New: ${remoteWorkout.scheduledDateTime}, duration: ${remoteWorkout.durationMinutes}, distance: ${remoteWorkout.distanceMiles}');
          }
        } else {
          // Check if any other fields changed (minor updates don't trigger nutrition refresh)
          final hasMinorChanges = _hasMinorChanges(localActivity, remoteWorkout);

          if (hasMinorChanges) {
            // UPDATED: Minor changes (title, notes, etc.) but no schedule change
            updatedActivities.add(
              ActivityChange(
                activityId: localActivity.id,
                updatedActivity: remoteWorkout,
                scheduleChanged: false,
                oldScheduledAt: localActivity.scheduledDateTime,
                newScheduledAt: remoteWorkout.scheduledDateTime,
                oldDurationMinutes: localActivity.durationMinutes,
                newDurationMinutes: remoteWorkout.durationMinutes,
                oldDistanceMiles: localActivity.distanceMiles,
                newDistanceMiles: remoteWorkout.distanceMiles,
              ),
            );
            if (kDebugMode) {
              debugPrint('   🔄 UPDATED (minor): ${remoteWorkout.title}');
            }
          } else {
            // UNCHANGED: No significant changes detected
            unchangedCount++;
            if (kDebugMode) {
              debugPrint('   ✅ UNCHANGED: ${remoteWorkout.title}');
            }
          }
        }
      }
    }

    // Process local activities to find deletions
    for (final localActivity in localActivities) {
      final providerId = localActivity.providerWorkoutId;
      if (providerId == null) continue;

      // DELETED: Workout exists in local but not in remote
      if (!remoteProviderIds.contains(providerId)) {
        deletedActivityIds.add(localActivity.id);
      }
    }

    return SyncChangeResult(
      newActivities: newActivities,
      updatedActivities: updatedActivities,
      deletedActivityIds: deletedActivityIds,
      unchangedCount: unchangedCount,
    );
  }

  /// Determine if schedule change is significant enough to flag nutrition plan as stale
  bool _isScheduleChangeSignificant(
    Activity oldActivity,
    Activity newActivity,
  ) {
    // Check time change (> 30 minutes)
    final timeDiff = oldActivity.scheduledDateTime
        .difference(newActivity.scheduledDateTime)
        .inMinutes
        .abs();

    if (timeDiff > significantTimeChangeMinutes) {
      return true;
    }

    // Check date change (different day)
    final oldDate = oldActivity.scheduledDateTime;
    final newDate = newActivity.scheduledDateTime;

    if (oldDate.year != newDate.year ||
        oldDate.month != newDate.month ||
        oldDate.day != newDate.day) {
      return true;
    }

    // Check duration change (> 15 minutes)
    if (oldActivity.durationMinutes != null &&
        newActivity.durationMinutes != null) {
      final durationDiff =
          (oldActivity.durationMinutes! - newActivity.durationMinutes!).abs();

      if (durationDiff > significantDurationChangeMinutes) {
        return true;
      }
    }

    // Check distance change (> 10%)
    if (oldActivity.distanceMiles != null &&
        newActivity.distanceMiles != null &&
        oldActivity.distanceMiles! > 0) {
      final distanceChangePercent =
          ((newActivity.distanceMiles! - oldActivity.distanceMiles!).abs() /
                  oldActivity.distanceMiles!) *
              100;

      if (distanceChangePercent > significantDistanceChangePercentage) {
        return true;
      }
    }

    return false;
  }

  /// Check if activity has minor changes (title, notes, pace, etc.)
  bool _hasMinorChanges(Activity oldActivity, Activity newActivity) {
    // Compare key fields that might change without affecting schedule
    if (oldActivity.title != newActivity.title) return true;
    if (oldActivity.notes != newActivity.notes) return true;
    if (oldActivity.paceTargetMinutesPerMile !=
        newActivity.paceTargetMinutesPerMile) return true;
    if (oldActivity.intensityLevel != newActivity.intensityLevel) return true;
    if (oldActivity.workoutSubtype != newActivity.workoutSubtype) return true;

    // Cycling-specific fields
    if (oldActivity.cyclingSpeedMph != newActivity.cyclingSpeedMph) return true;
    if (oldActivity.cyclingTerrain != newActivity.cyclingTerrain) return true;
    if (oldActivity.cyclingIndoorOutdoor != newActivity.cyclingIndoorOutdoor) {
      return true;
    }
    if (oldActivity.cyclingElevationGainFt !=
        newActivity.cyclingElevationGainFt) return true;

    // Swimming-specific fields
    if (oldActivity.swimmingPacePer100mSeconds !=
        newActivity.swimmingPacePer100mSeconds) return true;
    if (oldActivity.swimmingPoolOrOpenWater !=
        newActivity.swimmingPoolOrOpenWater) return true;

    return false;
  }
}
