import '../../../shared/domain/activity_type.dart';
import 'activity.dart';

/// Which activities may be grouped into a brick, and when the Brick entry
/// point is offered.
///
/// Brick redesign (Notion 3a7e3fdb, Xuan 2026-07-27): "Only the three
/// triathlon disciplines are brick-eligible — a strength or foam-rolling
/// activity must not be groupable. It currently is, which Xuan flagged as
/// wrong." Import-only `other` activities (strength/hiking/yoga/… from
/// Garmin et al.) and existing bricks are therefore excluded.
extension BrickEligibleActivityType on ActivityType {
  /// True only for swim / bike / run — the three triathlon disciplines.
  bool get isBrickEligible => isSingleSport;
}

extension BrickEligibleActivity on Activity {
  /// True when this activity may take part in a brick: a swim, bike or run
  /// that is not already grouped.
  bool get isBrickEligible => activityType.isBrickEligible && !isBrick;
}

/// True when [ordered] — a day's timeline entries in chronological order —
/// contains a run of 2 or more *adjacent* brick-eligible workouts.
///
/// "The Brick pill only appears when 2+ workouts are adjacent" (Notion
/// 3a7e3fdb). Adjacency is positional: two eligible workouts separated by a
/// meal, a race banner, or an ineligible workout are not adjacent, because
/// grouping them would reorder the day.
///
/// [ordered] carries one entry per timeline row: the activity when the row is
/// a workout, or `null` for any non-workout row.
/// A run must also contain **two different sports**. A brick is by definition
/// a change of discipline, and `BrickSelectionController.canCreateBrick`
/// rejects duplicate sports — so offering the Brick pill for two adjacent runs
/// would walk the user into a flow they cannot finish.
bool hasAdjacentBrickCandidates(List<Activity?> ordered) {
  var run = <Activity>[];
  bool viable() =>
      run.length >= 2 && run.map((a) => a.activityType).toSet().length >= 2;

  for (final activity in ordered) {
    if (activity != null && activity.isBrickEligible) {
      run.add(activity);
      if (viable()) return true;
    } else {
      run = <Activity>[];
    }
  }
  return false;
}

/// The ids of every activity in [ordered] that sits inside a run of 2+
/// adjacent brick-eligible workouts — i.e. the rows that are selectable once
/// the user taps Brick. Rows outside such a run stay untouchable so the user
/// cannot build a brick that would reorder the day.
Set<String> adjacentBrickCandidateIds(List<Activity?> ordered) {
  final ids = <String>{};
  var run = <Activity>[];
  void flush() {
    // Same viability rule as [hasAdjacentBrickCandidates]: 2+ rows AND 2+
    // distinct sports, so a run of identical sports never becomes selectable.
    if (run.length >= 2 &&
        run.map((a) => a.activityType).toSet().length >= 2) {
      ids.addAll(run.map((a) => a.id));
    }
    run = <Activity>[];
  }

  for (final activity in ordered) {
    if (activity != null && activity.isBrickEligible) {
      run.add(activity);
    } else {
      flush();
    }
  }
  flush();
  return ids;
}
