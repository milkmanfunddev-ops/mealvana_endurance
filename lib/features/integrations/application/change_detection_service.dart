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
    final archivedBrickByFingerprint = <String, Activity>{};
    for (final activity in localActivities) {
      if (activity.providerWorkoutId != null) {
        localByProviderId[activity.providerWorkoutId!] = activity;
      }
      if (activity.status == ActivityStatus.archivedForBrick) {
        archivedBrickByFingerprint[_fingerprint(activity)] = activity;
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
        // BRICK FALLBACK: Keep provider workouts grouped in brick state.
        // If an archived brick segment matches this remote workout by fingerprint,
        // treat it as an update/unchanged rather than re-inserting a new workout.
        final brickMatch =
            archivedBrickByFingerprint[_fingerprint(remoteWorkout)];
        if (brickMatch != null) {
          final scheduleChanged = _isScheduleChangeSignificant(
            brickMatch,
            remoteWorkout,
          );
          final hasMinorChanges = _hasMinorChanges(brickMatch, remoteWorkout);
          final needsProviderLinkUpdate =
              brickMatch.providerWorkoutId != providerId;

          if (scheduleChanged || hasMinorChanges || needsProviderLinkUpdate) {
            updatedActivities.add(
              ActivityChange(
                activityId: brickMatch.id,
                updatedActivity: remoteWorkout,
                scheduleChanged: scheduleChanged,
                oldScheduledAt: brickMatch.scheduledDateTime,
                newScheduledAt: remoteWorkout.scheduledDateTime,
                oldDurationMinutes: brickMatch.durationMinutes,
                newDurationMinutes: remoteWorkout.durationMinutes,
                oldDistanceMiles: brickMatch.distanceMiles,
                newDistanceMiles: remoteWorkout.distanceMiles,
              ),
            );
            if (kDebugMode) {
              debugPrint(
                '   🔗 BRICK MATCH UPDATED: ${remoteWorkout.title} '
                '(provider_id: $providerId -> activity_id: ${brickMatch.id})',
              );
            }
          } else {
            unchangedCount++;
            if (kDebugMode) {
              debugPrint(
                '   🧱 BRICK MATCH UNCHANGED: ${remoteWorkout.title} '
                '(provider_id: $providerId)',
              );
            }
          }
          continue;
        }

        // NEW: Workout exists in remote but not in local
        newActivities.add(remoteWorkout);
        if (kDebugMode) {
          debugPrint(
            '   📥 NEW: ${remoteWorkout.title} (provider_id: $providerId)',
          );
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
            debugPrint(
              '      Old: ${localActivity.scheduledDateTime}, duration: ${localActivity.durationMinutes}, distance: ${localActivity.distanceMiles}',
            );
            debugPrint(
              '      New: ${remoteWorkout.scheduledDateTime}, duration: ${remoteWorkout.durationMinutes}, distance: ${remoteWorkout.distanceMiles}',
            );
          }
        } else {
          // Check if any other fields changed (minor updates don't trigger nutrition refresh)
          final hasMinorChanges = _hasMinorChanges(
            localActivity,
            remoteWorkout,
          );

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

      // Skip activities already soft-deleted from the provider. The local load
      // (getActivitiesByUserAndProvider -> _loadLocalProviderActivities) filters
      // only `deletedAt`, NOT `providerDeletedAt`, so rows already soft-deleted
      // from the provider are still returned here. Without this guard they get
      // re-flagged for deletion on EVERY sync — re-setting needs_upload,
      // re-queuing uploads, and re-invalidating the calendar/activities
      // providers even when nothing changed (symptom: a constant non-zero
      // "deleted: N" on no-op syncs, e.g. after switching the connected
      // provider account). The soft-delete is meant to be idempotent.
      if (localActivity.providerDeletedAt != null) continue;

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
        newActivity.paceTargetMinutesPerMile) {
      return true;
    }
    if (oldActivity.durationMinutes != newActivity.durationMinutes) return true;
    if (oldActivity.distanceMiles != newActivity.distanceMiles) return true;
    if (oldActivity.intensityLevel != newActivity.intensityLevel) return true;
    if (oldActivity.workoutSubtype != newActivity.workoutSubtype) return true;

    // Cycling-specific fields
    if (oldActivity.cyclingSpeedMph != newActivity.cyclingSpeedMph) return true;
    if (oldActivity.cyclingTerrain != newActivity.cyclingTerrain) return true;
    if (oldActivity.cyclingIndoorOutdoor != newActivity.cyclingIndoorOutdoor) {
      return true;
    }
    if (oldActivity.cyclingElevationGainFt !=
        newActivity.cyclingElevationGainFt) {
      return true;
    }

    // Swimming-specific fields
    if (oldActivity.swimmingPacePer100mSeconds !=
        newActivity.swimmingPacePer100mSeconds) {
      return true;
    }
    if (oldActivity.swimmingPoolOrOpenWater !=
        newActivity.swimmingPoolOrOpenWater) {
      return true;
    }

    return false;
  }

  String _fingerprint(Activity activity) {
    final title = activity.title.trim().toLowerCase();
    final scheduledAt = activity.scheduledDateTime.toUtc().toIso8601String();
    final duration = activity.durationMinutes ?? -1;
    final distance = activity.distanceMiles?.toStringAsFixed(3) ?? 'na';
    return '${activity.activityType.name}|$title|$scheduledAt|$duration|$distance';
  }
}
