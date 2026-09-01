import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/activity.dart';
import '../../domain/brick_eligibility.dart';

part 'brick_creation_available_provider.g.dart';

/// Whether the Brick entry point should be offered for a given day.
///
/// Brick redesign (Notion 3a7e3fdb): the Brick pill only appears when 2+
/// *adjacent* brick-eligible workouts exist. Eligibility is limited to the
/// three triathlon disciplines — a strength or foam-rolling activity must not
/// be groupable.
///
/// [activities] must arrive in the order they appear on the timeline
/// (chronological); adjacency is positional over the day's *workout*
/// sequence, so the caller's ordering is load-bearing. A meal logged between
/// two workouts does not break their adjacency — an ineligible workout
/// (strength, an existing brick) does.
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

  return hasAdjacentBrickCandidates(onDay);
}

/// Helper to check if two dates are the same day
bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
