import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/services/logging_service.dart';

part 'activity_deduplication_service.g.dart';

/// Result of deduplication analysis containing keepers and duplicates.
class DeduplicationResult {
  const DeduplicationResult({required this.keepers, required this.duplicates});

  /// Activities to keep (one per unique key)
  final List<Activity> keepers;

  /// Activities identified as duplicates to be removed
  final List<Activity> duplicates;
}

@riverpod
ActivityDeduplicationService activityDeduplicationService(Ref ref) {
  return ActivityDeduplicationService(logger: ref.read(appLoggerProvider));
}

/// Service for detecting and removing duplicate provider-synced activities.
/// Implements scoring logic to select the most valuable record when duplicates exist.
///
/// This service is stateless and works with data provided by the repository layer.
/// It does not access the database or Supabase directly.
class ActivityDeduplicationService {
  ActivityDeduplicationService({required AppLogger logger}) : _logger = logger;

  final AppLogger _logger;

  /// Identify duplicate activities from the provided list.
  /// Returns a DeduplicationResult containing keepers and duplicates to remove.
  DeduplicationResult identifyDuplicates(List<Activity> activities) {
    if (activities.length < 2) {
      return DeduplicationResult(keepers: activities, duplicates: []);
    }

    final keeperByKey = <String, Activity>{};
    final duplicates = <Activity>[];

    for (final row in activities) {
      final key = _buildDuplicateKey(row);
      final existing = keeperByKey[key];

      if (existing == null) {
        keeperByKey[key] = row;
        continue;
      }

      final preferred = selectPreferredDuplicate(existing, row);
      if (preferred.id == row.id) {
        duplicates.add(existing);
        keeperByKey[key] = row;
      } else {
        duplicates.add(row);
      }
    }

    _logger.debug(
      'Identified duplicate activities',
      context: 'ACTIVITY_DEDUPLICATION_SERVICE',
      data: {
        'totalActivities': activities.length,
        'duplicatesFound': duplicates.length,
      },
    );

    return DeduplicationResult(
      keepers: keeperByKey.values.toList(),
      duplicates: duplicates,
    );
  }

  /// Build a unique key for duplicate detection.
  /// Uses provider workout ID if available, otherwise creates fingerprint
  /// from title, scheduled time, duration, and distance.
  String _buildDuplicateKey(Activity activity) {
    final providerWorkoutId = activity.providerWorkoutId?.trim();
    if (providerWorkoutId != null && providerWorkoutId.isNotEmpty) {
      return 'id:$providerWorkoutId';
    }

    final normalizedTitle = activity.title.trim().toLowerCase();
    final scheduledAt = activity.scheduledDateTime.toUtc().toIso8601String();
    final duration = activity.durationMinutes ?? -1;
    final distance = activity.distanceMiles?.toStringAsFixed(3) ?? 'na';
    return 'fp:${activity.activityType}|$normalizedTitle|$scheduledAt|$duration|$distance';
  }

  /// Select the preferred duplicate based on scoring algorithm.
  /// Higher score wins. If scores are equal, most recently updated wins.
  Activity selectPreferredDuplicate(Activity a, Activity b) {
    final scoreA = _calculateScore(a);
    final scoreB = _calculateScore(b);

    if (scoreA != scoreB) {
      return scoreA > scoreB ? a : b;
    }

    return b.updatedAt.isAfter(a.updatedAt) ? b : a;
  }

  /// Calculate quality score for an activity record.
  /// Higher scores indicate more valuable data:
  /// - 100 points: Has nutrition plan data
  /// - 50 points: Has completion data (completed_at, actual distance/duration)
  /// - 10 points: Has notes
  /// - 5 points: Not marked as deleted by provider
  int _calculateScore(Activity activity) {
    var score = 0;

    if (activity.nutritionPlanData != null &&
        activity.nutritionPlanData!.isNotEmpty) {
      score += 100;
    }

    if (activity.completedAt != null ||
        activity.actualDistanceMiles != null ||
        activity.actualDurationMinutes != null) {
      score += 50;
    }

    if ((activity.notes ?? '').trim().isNotEmpty) {
      score += 10;
    }

    if (activity.providerDeletedAt == null) {
      score += 5;
    }

    return score;
  }
}
