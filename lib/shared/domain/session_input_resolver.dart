/// The ONE resolution ladder from a stored activity row to the inputs F4
/// (`sessionCost`) needs.
///
/// **Why this file exists.** The formula was always shared — `sessionCost`
/// exists once in Dart and once in TS, pinned byte-equal by the cross-language
/// parity vectors. The *inputs* were not: each consumer resolved "how long was
/// this session" from the raw row for itself, and they disagreed. The provider
/// transformers deliberately write `duration_minutes = NULL` whenever a workout
/// carries distance or pace (`FinalSurgeTransformer._getFallbackDurationMinutes`:
/// "keep duration null and let the UI estimate", asserted ten times in its own
/// test), and the macro dashboard skipped the estimate entirely — pricing a
/// 3 mi, a 6.2 mi and a 15 mi run identically at the 60-minute fallback, ~47%
/// low on the long run, while the macro targets on the same screen used the
/// correct value.
/// See `ops/data/bug-reports/2026-08-22-dashboard-prices-distance-sessions-at-flat-60min.md`.
///
/// **The rule this file enforces:** a quantity derived from an activity row is
/// derived in exactly one place. A second call site calls this; it does not
/// re-implement it. If you are about to copy one of these ladders, that is the
/// bug this file was written to end.
///
/// **Authority.** This mirrors what the engine is actually fed —
/// `DailyMacroService._sessionFromActivityRow` builds the `SessionInput` that
/// is POSTed to `calculate-daily-macros-v6`, and the engine's answer drives the
/// athlete's macro targets. Any display that prices a session differently is
/// contradicting the targets it sits next to, so the engine's ladder is the
/// canonical one and display surfaces conform to it, never the reverse.
///
/// **Known third ladder, deliberately NOT folded in here yet:**
/// `TrainingInsightService._estimateMinutesFromDistance` adds a further step —
/// when a session carries no prescribed pace it estimates from distance × an
/// assumed pace rather than falling to a flat 60 — because a distance-only
/// import digesting to zero destroyed whole onboarding reveals. That is a
/// better ladder, but adopting it here would change engine inputs and therefore
/// athlete fuel targets, which needs a ruling rather than a bug fix. Queued as
/// `qa/PLAN.md` Phase 5 / `qa/intake/2026-08-22-data-ssot-producer-shapes.md`.
library;

/// Sport keys understood by `sessionCost` / the engine's `Sport` union.
const String _sportRunning = 'running';
const String _sportCycling = 'cycling';
const String _sportSwimming = 'swimming';
const String _sportStrength = 'strength';

class SessionInputResolver {
  const SessionInputResolver._();

  /// Fallback when a session carries neither an explicit duration nor a
  /// distance/pace pair to derive one from. Mirrors the engine exactly.
  static const int fallbackMinutes = 60;
  static const int fallbackOtherMinutes = 30;

  /// Zone distribution assumed when a session carries none — a representative
  /// endurance session, mostly conversational with some tempo.
  ///
  /// RULED 2026-08-22 (`qa/intake/2026-08-20-zoneless-if-default-engine-vs-display.md`):
  /// display surfaces adopt the ENGINE's default rather than keeping their own.
  /// Until this ruling the engine assumed 70/20/10 (IF 0.7715) while display
  /// surfaces used a flat IF 0.74, so a zoneless session was priced ~8% lower
  /// on screen than in the macro targets beside it — visible to an athlete as a
  /// projected burn of 2,933 against a 3,037 target on the same card.
  ///
  /// The DISTRIBUTION is the constant, not the IF: both sides feed these
  /// percentages through the one RMS derivation
  /// ([DailyBaselineCalculator.zoneDistributionToIf], F3), so there is a single
  /// place where zones become an intensity factor. Hard-coding 0.7715 would
  /// have recreated the same class of drift one level down.
  static const int defaultZ1Z2Pct = 70;
  static const int defaultZ3Z4Pct = 20;
  static const int defaultZ5Pct = 10;

  /// Planned/actual duration in whole minutes.
  ///
  /// Ladder: an explicit duration wins; otherwise derive from the session's own
  /// prescribed pace (distance × pace for a run, distance ÷ speed for a ride,
  /// pace-per-100m for a swim); otherwise the flat fallback. Distance without a
  /// prescribed pace does not derive here — see the library note on the third
  /// ladder.
  ///
  /// [explicitMinutes] is the caller's precedence choice, not this function's:
  /// the engine passes planned duration only, while display surfaces pass
  /// `actual ?? planned` so a finished session is priced at what it actually
  /// took. Both are correct for their surface; only the derivation below has to
  /// be shared.
  static int durationMinutes({
    required String activityType,
    int? explicitMinutes,
    double? distanceMiles,
    double? paceTargetMinutesPerMile,
    double? cyclingSpeedMph,
    int? swimmingPacePer100mSeconds,
  }) {
    var minutes = explicitMinutes ?? 0;
    if (minutes > 0) return minutes;

    if (activityType == _sportRunning) {
      if (distanceMiles != null &&
          paceTargetMinutesPerMile != null &&
          paceTargetMinutesPerMile > 0) {
        minutes = (distanceMiles * paceTargetMinutesPerMile).round();
      }
    } else if (activityType == _sportCycling) {
      if (distanceMiles != null && cyclingSpeedMph != null && cyclingSpeedMph > 0) {
        minutes = ((distanceMiles / cyclingSpeedMph) * 60).round();
      }
    } else if (activityType == _sportSwimming) {
      if (distanceMiles != null &&
          swimmingPacePer100mSeconds != null &&
          swimmingPacePer100mSeconds > 0) {
        final distanceMeters = distanceMiles * 1609.34;
        minutes = ((distanceMeters / 100) * swimmingPacePer100mSeconds / 60)
            .round();
      }
    }

    if (minutes == 0) {
      minutes = activityType == 'other' ? fallbackOtherMinutes : fallbackMinutes;
    }
    return minutes;
  }

  /// DI-7 pair rule (lifecycle.md L-2 split, RULED Xuan 2026-09-10):
  /// measured and planned metrics are separate FAMILIES. A row with any
  /// measured data resolves to the measured pair; otherwise the planned
  /// pair. Consumers must never mix families — a measured duration beside
  /// a planned distance is exactly the DI-DEV-1 mixed-pair prod bug
  /// (verified card rendering planned 8 mi with measured 44 min).
  static ({int? durationMinutes, double? distanceMiles, bool measured})
      resolveMetricsPair({
    required int? actualDurationMinutes,
    required double? actualDistanceMiles,
    required int? durationMinutes,
    required double? distanceMiles,
  }) {
    final measured =
        actualDurationMinutes != null || actualDistanceMiles != null;
    if (measured) {
      return (
        durationMinutes: actualDurationMinutes,
        distanceMiles: actualDistanceMiles,
        measured: true,
      );
    }
    return (
      durationMinutes: durationMinutes,
      distanceMiles: distanceMiles,
      measured: false,
    );
  }

  /// Activity type → the sport key the ENGINE prices it as. This is the
  /// mapping that decides the athlete's macro targets.
  ///
  /// F4a (session-demand.md, RULED Xuan 2026-09-10): the historical
  /// `_ => running` fallback and the `other → strength` interim are GONE.
  /// Known endurance sports map to themselves; composites pass through (the
  /// engine decomposes by legs or dominant leg); everything else passes
  /// through untouched and the engine prices it 0 kcal with the estimate
  /// flag — never a hidden fallback rate.
  static String engineSport(String activityType) => switch (activityType) {
        _sportRunning => _sportRunning,
        _sportCycling => _sportCycling,
        _sportSwimming => _sportSwimming,
        _sportStrength => _sportStrength,
        _ => activityType,
      };

  /// Activity type → the sport key a DISPLAY surface prices it as.
  ///
  /// The 2026-08-20 intake that held these two apart is RULED (F4a), so
  /// display and engine pricing collapsed into one mapping — the divergence
  /// this alias used to pin cannot exist anymore. Kept as an alias so call
  /// sites read as intent.
  static String displaySport(String activityType) =>
      engineSport(activityType);
}
