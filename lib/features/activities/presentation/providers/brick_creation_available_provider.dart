import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/activity.dart';

part 'brick_creation_available_provider.g.dart';

/// Provider to check if brick creation is available for a given date
///
/// Returns true if:
/// - 2+ activities exist on the selected date
/// - Activities are of different sport types (not all the same sport)
///
/// Used to show/hide the "Create Brick" button in activities list
@riverpod
bool isBrickCreationAvailable(
  Ref ref, {
  required List<Activity> activities,
  required DateTime selectedDate,
}) {
  // Filter activities for the selected date
  final selectedDateActivities = activities.where((activity) {
    return _isSameDay(activity.scheduledDateTime, selectedDate);
  }).toList();

  // Need at least 2 activities
  if (selectedDateActivities.length < 2) {
    return false;
  }

  // Get unique sport types (excluding brick activities)
  final sportTypes = selectedDateActivities
      .where((activity) => !activity.activityType.isBrick)
      .map((activity) => activity.activityType)
      .toSet();

  // Need at least 2 different sports
  return sportTypes.length >= 2;
}

/// Helper to check if two dates are the same day
bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
