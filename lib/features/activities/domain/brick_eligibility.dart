import 'activity.dart';
import '../../../shared/domain/activity_type.dart';

/// Which activities may be grouped into a brick, and when the Brick entry
/// point is offered.
///
/// SSOT: `docs/ssot/spec/domain/brick.md` (RATIFIED v1, Xuan 2026-08-31).
/// This file is the published eligibility predicate the domain vectors run
/// against (`docs/ssot/vectors/domain/brick-eligibility.json`):
///   · R1 — offer iff the day holds 2+ eligible workouts; adjacency withdrawn.
///   · R2 — same-sport legs are allowed.
///   · R3 — eligible leg = swim | bike | run, not already a brick.
///   · R4 — leg count min 2, max 3 (the cap STANDS — ruled, not a TODO).
///   · R5 — a SKIPPED leg may NOT be linked (fixes D-007; platform sync can
///     write `skipped`). DONE/verified and past/future days stay linkable as
///     characterization — Q-BR1 is open, nothing here rules on them.
///   · R6 — leg order = pick order (see [evaluateBrickCreate]'s legOrder).
extension BrickEligibleActivityType on ActivityType {
  /// True only for swim / bike / run — the three triathlon disciplines (R3).
  bool get isBrickEligible => isSingleSport;
}

extension BrickEligibleActivity on Activity {
  /// True when this activity may take part in a brick: a swim, bike or run
  /// (R3) that is not already grouped (R3) and is not skipped (R5).
  bool get isBrickEligible =>
      activityType.isBrickEligible &&
      !isBrick &&
      status != ActivityStatus.skipped;
}

/// True when the day holds 2+ brick-eligible workouts — the condition under
/// which the Brick entry point is offered (brick.md R1).
bool hasBrickCandidates(Iterable<Activity?> workouts) =>
    _eligible(workouts).length >= 2;

/// The ids of every workout selectable once the user taps Brick: all
/// brick-eligible workouts on the day, whenever [hasBrickCandidates] holds.
/// Ineligible rows (strength, imported "other", an existing brick, a skipped
/// workout) stay untouchable. Iteration order is day order.
Set<String> brickCandidateIds(Iterable<Activity?> workouts) {
  if (!hasBrickCandidates(workouts)) return const {};
  return _eligible(workouts).map((a) => a.id).toSet();
}

/// The create-time gate that rejected a picked selection (brick.md R3/R4/R5).
/// Gate identity is part of the conformance contract — a rejection for the
/// wrong reason is a failure.
enum BrickCreateGate {
  /// A picked leg is not eligible (R3: sport/brick, or R5: skipped).
  ineligibleLeg('ineligible-leg'),

  /// Fewer than 2 legs picked (R4).
  minLegs('min-legs'),

  /// More than 3 legs picked (R4 — the max-3 cap stands).
  maxLegs('max-legs');

  const BrickCreateGate(this.wireName);

  /// The gate name as the domain vectors spell it.
  final String wireName;
}

/// Create-time verdict for a picked leg selection (brick.md R3–R6).
class BrickCreateVerdict {
  const BrickCreateVerdict.allowed(List<String> legOrder)
    : createAllowed = true,
      gate = null,
      legOrder = legOrder;

  const BrickCreateVerdict.rejected(BrickCreateGate this.gate)
    : createAllowed = false,
      legOrder = null;

  final bool createAllowed;
  final BrickCreateGate? gate;

  /// R6: the brick's leg order IS the pick order (never re-sorted to
  /// timeline order). Null when rejected.
  final List<String>? legOrder;
}

/// Validate a picked selection at create time.
///
/// [pickedLegs] is the athlete's pick order (R6). Checks eligibility first,
/// then the R4 count gates — matching the vectors' oracle convention
/// (subset-check then count).
BrickCreateVerdict evaluateBrickCreate(List<Activity> pickedLegs) {
  if (pickedLegs.any((a) => !a.isBrickEligible)) {
    return const BrickCreateVerdict.rejected(BrickCreateGate.ineligibleLeg);
  }
  if (pickedLegs.length < 2) {
    return const BrickCreateVerdict.rejected(BrickCreateGate.minLegs);
  }
  if (pickedLegs.length > 3) {
    return const BrickCreateVerdict.rejected(BrickCreateGate.maxLegs);
  }
  return BrickCreateVerdict.allowed([for (final a in pickedLegs) a.id]);
}

List<Activity> _eligible(Iterable<Activity?> workouts) => [
  for (final a in workouts)
    if (a != null && a.isBrickEligible) a,
];
