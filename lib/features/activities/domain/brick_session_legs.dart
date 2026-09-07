/// Brick → per-leg session decomposition — the ONE place a brick's metadata
/// becomes the `(sport, duration)` inputs `sessionCost` (F4) prices.
///
/// A brick is stored as a single activity row whose `brick_metadata` carries
/// the ordered legs. Until 2026-09-04 no pricing surface read the legs: the
/// engine feed priced the whole brick as `running` over the summed duration
/// (`engineSport`'s `_ =>` default) while display surfaces priced it at the
/// interim conservative strength rate — a ~2× disagreement that put a 9,486
/// kcal intake target next to a 1,980 kcal projected workout burn on the same
/// dashboard (bug 2026-09-04-brick-priced-as-one-conservative-session).
///
/// INTERIM (pending `qa/intake/2026-09-04-brick-per-leg-pricing-ratification.md`):
/// a brick prices as the plain sum of its legs, each leg at its own sport's
/// already-ratified rate over its own duration. Nothing new is invented — the
/// rates, the RMS IF derivation and the duration ladder are all the ratified
/// ones; only the decomposition is interim. The open ratification questions
/// (per-leg IF from segment intensity, transition cost, measured-whole-brick
/// allocation across formula legs) live in that intake file.
///
/// Both consumers — `MacroDashboardAssembler._sessionKcal` and
/// `DailyMacroService._sessionsFromActivityRow` — call this; per the
/// `SessionInputResolver` rule, a second call site calls it rather than
/// re-implementing it, so the two sides cannot drift apart.
library;

import '../../../shared/domain/session_input_resolver.dart';
import 'brick_metadata.dart';

/// One brick leg resolved to exactly the inputs `sessionCost` needs.
class BrickSessionLeg {
  const BrickSessionLeg({required this.sport, required this.durationMinutes});

  /// Engine sport key (`running`/`cycling`/`swimming`/`strength`) — mapped via
  /// [SessionInputResolver.engineSport], the same mapping every single-sport
  /// session gets, so a leg prices exactly like the equivalent standalone
  /// workout.
  final String sport;

  /// Leg duration through the shared [SessionInputResolver.durationMinutes]
  /// ladder: the segment's explicit minutes win, else the leg's own
  /// distance × prescribed pace, else the flat fallback.
  final int durationMinutes;
}

extension BrickSessionLegs on BrickMetadata {
  /// The legs of this brick as priceable sessions, in segment order.
  /// Empty when the metadata carries no segments — callers fall back to the
  /// single-session path in that case.
  List<BrickSessionLeg> get sessionLegs {
    return [
      for (final seg in segments)
        BrickSessionLeg(
          sport: SessionInputResolver.engineSport(seg.sport.toLowerCase()),
          durationMinutes: SessionInputResolver.durationMinutes(
            activityType: seg.sport.toLowerCase(),
            explicitMinutes: seg.durationMinutes,
            // A swim segment carries meters; the shared ladder speaks miles.
            distanceMiles:
                seg.distanceMiles ??
                (seg.distanceMeters != null
                    ? seg.distanceMeters! / 1609.34
                    : null),
            paceTargetMinutesPerMile: seg.paceMinutesPerMile,
            cyclingSpeedMph: seg.speedMph,
            swimmingPacePer100mSeconds: seg.pacePer100mSeconds,
          ),
        ),
    ];
  }
}
