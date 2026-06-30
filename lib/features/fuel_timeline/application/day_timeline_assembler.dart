import '../../activities/domain/activity.dart';
import '../../daily_macros/domain/daily_macro_targets.dart';
import '../../meal_logging/domain/consumed_totals.dart';
import '../../meal_logging/domain/meal_log.dart';
import '../domain/day_energy_summary.dart';
import '../domain/fuel_timeline_filter.dart';
import '../domain/timeline_node.dart';

/// The output of [DayTimelineAssembler]: the ordered, filtered timeline plus the
/// energy-balance summary for the day.
class DayTimelineResult {
  const DayTimelineResult({required this.nodes, required this.summary});

  /// Timeline entries in chronological order, after applying the filter.
  final List<TimelineNode> nodes;

  /// Day energy-balance summary (unaffected by the filter).
  final DayEnergySummary summary;
}

/// Pure builder for the Fuel Timeline day view.
///
/// Takes the day's raw inputs (already loaded by the controller) and produces a
/// chronological, interleaved list of meal + workout nodes plus a
/// [DayEnergySummary]. No I/O, no Riverpod — trivially unit-testable. [now] is
/// injected so proration and "workout done" logic are deterministic in tests.
class DayTimelineAssembler {
  const DayTimelineAssembler();

  DayTimelineResult assemble({
    required DateTime selectedDate,
    required DateTime now,
    required List<MealLog> meals,
    required List<Activity> activities,
    required DailyMacroTargets? targets,
    required ConsumedTotals consumed,
    Map<String, double> burnByActivityId = const {},
    FuelTimelineFilter filter = FuelTimelineFilter.all,
  }) {
    // Drop tombstones / deleted rows defensively (callers usually pre-filter).
    final activeMeals = meals.where((m) => !m.isDeleted);
    final activeActivities = activities
        .where((a) => a.deletedAt == null)
        .toList(growable: false);

    final mealNodes = activeMeals.map(MealNode.new);
    final workoutNodes = activeActivities.map(
      (a) => WorkoutNode(a, burnKcal: burnByActivityId[a.id]),
    );

    // Interleave by time; tie-break on id for stable, deterministic ordering.
    final ordered = <TimelineNode>[...mealNodes, ...workoutNodes]
      ..sort((a, b) {
        final byTime = a.time.compareTo(b.time);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });

    final nodes = ordered.where(filter.matches).toList(growable: false);

    final summary = DayEnergySummary.compute(
      selectedDate: selectedDate,
      now: now,
      targets: targets,
      consumed: consumed,
      workoutBurnedKcal: _workoutBurned(
        activeActivities,
        burnByActivityId,
        selectedDate,
        now,
      ),
    );

    return DayTimelineResult(nodes: nodes, summary: summary);
  }

  /// Sum the session energy of workouts considered "done" for the selected day:
  /// past days count everything; today counts workouts already started
  /// (`scheduled <= now`); future days count nothing.
  double _workoutBurned(
    List<Activity> activities,
    Map<String, double> burnByActivityId,
    DateTime selectedDate,
    DateTime now,
  ) {
    if (activities.isEmpty) return 0;
    final kind = DayKind.of(selectedDate, now);
    var total = 0.0;
    for (final a in activities) {
      final done = switch (kind) {
        DayKind.past => true,
        DayKind.today => !a.scheduledDateTime.isAfter(now),
        DayKind.future => false,
      };
      if (done) total += burnByActivityId[a.id] ?? 0;
    }
    return total;
  }
}
