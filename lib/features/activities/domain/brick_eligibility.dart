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

/// True when the day's workouts contain 2+ brick-eligible workouts of at
/// least two different sports — the condition under which the Brick entry
/// point is offered.
///
/// Ruled (Lee, 2026-08-26, resurrecting the brick flow on the macro
/// dashboard): **adjacency is NOT required.** Any swim / bike / run on the
/// day may be linked, in whatever order the athlete picks them, regardless
/// of where they sit on the dashboard or what lies between them. The earlier
/// "2+ positionally adjacent workouts" gate (Notion 3a7e3fdb) is withdrawn.
/// Pending the logic-SSOT ruling that records this:
/// qa/intake/2026-08-26-brick-eligibility-logic-ssot.md.
///
/// The two-different-sports floor remains because
/// `BrickSelectionController.canCreateBrick` rejects duplicate sports — so
/// offering the pill for two runs alone would walk the user into a flow they
/// cannot finish.
bool hasBrickCandidates(Iterable<Activity?> workouts) {
  final eligible = _eligible(workouts);
  return eligible.length >= 2 &&
      eligible.map((a) => a.activityType).toSet().length >= 2;
}

/// The ids of every workout selectable once the user taps Brick: all
/// brick-eligible workouts on the day, whenever [hasBrickCandidates] holds.
/// Ineligible rows (strength, imported "other", an existing brick) stay
/// untouchable.
Set<String> brickCandidateIds(Iterable<Activity?> workouts) {
  if (!hasBrickCandidates(workouts)) return const {};
  return _eligible(workouts).map((a) => a.id).toSet();
}

List<Activity> _eligible(Iterable<Activity?> workouts) => [
  for (final a in workouts)
    if (a != null && a.isBrickEligible) a,
];
