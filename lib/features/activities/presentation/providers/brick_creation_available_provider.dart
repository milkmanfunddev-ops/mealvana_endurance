import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/activity.dart';
import '../../domain/brick_eligibility.dart';

part 'brick_creation_available_provider.g.dart';

/// Whether the Brick entry point should be offered for a given day.
///
/// Offered when the day holds 2+ brick-eligible workouts (swim / bike / run,
/// not already a brick) spanning 2+ sports. Adjacency is NOT required and
/// the caller's ordering is irrelevant (ruled Lee, 2026-08-26 — see
/// brick_eligibility.dart); the legs are linked in the order the athlete
/// picks them.
@riverpod
bool isBrickCreationAvailable(
  Ref ref, {
  required List<Activity> activities,
  required DateTime selectedDate,
}) {
  final onDay = activities
      .where((a) => _isSameDay(a.scheduledDateTime, selectedDate))
      .cast<Activity?>()
      .toList(growable: false);

  return hasBrickCandidates(onDay);
}

/// Helper to check if two dates are the same day
bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
