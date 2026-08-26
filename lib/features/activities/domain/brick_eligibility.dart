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

/// True when the day holds 2+ brick-eligible workouts — the condition under
/// which the Brick entry point is offered.
///
/// Ruled (Lee, 2026-08-26, resurrecting the brick flow on the macro
/// dashboard): the ONLY filter is the sport — swim / bike / run, not already
/// a brick. **Adjacency is not required**, **same-sport legs are allowed**
/// (run + run + ride is a brick), and the legs are linked in whatever order
/// the athlete picks them. The earlier "2+ positionally adjacent workouts of
/// 2+ sports" gate (Notion 3a7e3fdb) is withdrawn. Pending the logic-SSOT
/// record: qa/intake/2026-08-26-brick-eligibility-logic-ssot.md.
bool hasBrickCandidates(Iterable<Activity?> workouts) =>
    _eligible(workouts).length >= 2;

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
