/// Domain models for integration sync change detection
///
/// Used by ChangeDetectionService to represent the result of comparing
/// local activities with remote provider workouts.

import '../../activities/domain/activity.dart';

/// Result of comparing local activities with remote provider workouts
class SyncChangeResult {
  const SyncChangeResult({
    required this.newActivities,
    required this.updatedActivities,
    required this.deletedActivityIds,
    required this.unchangedCount,
  });

  /// Activities that exist in remote but not in local (need to be inserted)
  final List<Activity> newActivities;

  /// Activities that exist in both but have schedule changes
  final List<ActivityChange> updatedActivities;

  /// Activity IDs that exist in local but not in remote (soft-delete)
  final List<String> deletedActivityIds;

  /// Count of activities that exist in both and are unchanged
  final int unchangedCount;

  /// Total number of changes detected (new + updated + deleted)
  int get totalChanges =>
      newActivities.length +
      updatedActivities.length +
      deletedActivityIds.length;

  /// Whether any changes were detected
  bool get hasChanges => totalChanges > 0;

  /// Whether there are schedule changes that might need nutrition refresh
  bool get hasScheduleChanges =>
      updatedActivities.any((change) => change.scheduleChanged);

  @override
  String toString() {
    return 'SyncChangeResult('
        'new: ${newActivities.length}, '
        'updated: ${updatedActivities.length}, '
        'deleted: ${deletedActivityIds.length}, '
        'unchanged: $unchangedCount'
        ')';
  }
}

/// Represents a change detected in an existing activity
class ActivityChange {
  const ActivityChange({
    required this.activityId,
    required this.updatedActivity,
    required this.scheduleChanged,
    this.oldScheduledAt,
    this.newScheduledAt,
    this.oldDurationMinutes,
    this.newDurationMinutes,
    this.oldDistanceMiles,
    this.newDistanceMiles,
  });

  /// ID of the activity that changed
  final String activityId;

  /// Updated activity data from provider
  final Activity updatedActivity;

  /// Whether the schedule changed significantly (triggers nutrition refresh)
  ///
  /// Significant changes:
  /// - Time change > 30 minutes
  /// - Different day
  /// - Duration change > 15 minutes
  /// - Distance change > 10%
  final bool scheduleChanged;

  /// Old scheduled date/time (for comparison)
  final DateTime? oldScheduledAt;

  /// New scheduled date/time
  final DateTime? newScheduledAt;

  /// Old duration in minutes
  final int? oldDurationMinutes;

  /// New duration in minutes
  final int? newDurationMinutes;

  /// Old distance in miles
  final double? oldDistanceMiles;

  /// New distance in miles
  final double? newDistanceMiles;

  /// Time difference in minutes (absolute value)
  int? get timeDifferenceMinutes {
    if (oldScheduledAt == null || newScheduledAt == null) return null;
    return oldScheduledAt!.difference(newScheduledAt!).inMinutes.abs();
  }

  /// Duration difference in minutes (absolute value)
  int? get durationDifferenceMinutes {
    if (oldDurationMinutes == null || newDurationMinutes == null) return null;
    return (oldDurationMinutes! - newDurationMinutes!).abs();
  }

  /// Distance change percentage (absolute value)
  double? get distanceChangePercentage {
    if (oldDistanceMiles == null || newDistanceMiles == null) return null;
    if (oldDistanceMiles == 0) return 100.0;
    return ((newDistanceMiles! - oldDistanceMiles!).abs() / oldDistanceMiles!) *
        100;
  }

  @override
  String toString() {
    return 'ActivityChange('
        'id: $activityId, '
        'scheduleChanged: $scheduleChanged, '
        'timeDiff: ${timeDifferenceMinutes ?? 0}min, '
        'durationDiff: ${durationDifferenceMinutes ?? 0}min'
        ')';
  }
}
