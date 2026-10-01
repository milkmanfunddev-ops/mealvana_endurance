import '../../../shared/domain/activity_type.dart';

/// Where a usual-pace figure came from. Visible to consumers on purpose: a
/// duration derived from a fallback is a guess about a stranger, while one
/// derived from history is a guess about this athlete, and a surface that
/// shows "EST." should be able to tell the difference later.
enum UsualPaceSource { history, fallback }

class UsualPace {
  const UsualPace(this.minutesPerMile, this.source, {this.sampleCount = 0});

  /// Minutes per mile — one currency for every sport, so a duration estimate
  /// is always `distanceMiles * minutesPerMile`. Bike speeds and swim
  /// per-100yd paces are converted in, not carried as separate units.
  final double minutesPerMile;
  final UsualPaceSource source;
  final int sampleCount;

  bool get fromHistory => source == UsualPaceSource.history;

  Duration durationFor(double distanceMiles) =>
      Duration(seconds: (distanceMiles * minutesPerMile * 60).round());
}

/// One completed session, reduced to the only two numbers that matter.
typedef CompletedSample = ({double distanceMiles, int durationMinutes});

/// The athlete's usual pace per sport, derived from what they have actually
/// done (RULED 2026-09-30, Xuan).
///
/// WHY THE SLOWEST QUARTILE AND NOT THE MEDIAN. The service is consumed by the
/// importer to estimate a duration for a PLANNED workout, and the planned
/// workouts that need estimating are the long ones. An athlete's median
/// completed pace is pulled down by short fast sessions — intervals, tempo,
/// parkruns — so a long run estimated at median pace comes out materially
/// SHORT. That matters because the estimate then decides whether the workout
/// clears the 90-minute LONG threshold, and a genuinely long workout estimated
/// under it gets no nudge at all — a silent miss indistinguishable from the
/// bug this exists to fix.
///
/// So the figure is the typical pace WITHIN the slowest quarter of sessions
/// (see [_slowestQuartilePace] — the boundary reading was tried first and was
/// measurably not enough). It fails toward OVER-estimating duration, which
/// nudges someone who may not have needed it — recoverable — instead of
/// silently dropping the athlete the feature is for.
///
/// NEVER TrainingPeaks zones. That source carries the known-bad pace-chip
/// defect, and deriving from it would spread a known-wrong number into a
/// second surface.
class UsualPaceEngine {
  const UsualPaceEngine._();

  /// Sessions older than this are not evidence about current fitness.
  static const Duration window = Duration(days: 90);

  /// Below this, history is not trusted and the fallback is used instead.
  static const int minimumSamples = 3;

  /// Ruled fallbacks, expressed in the common currency.
  ///   run  10:00 / mile
  ///   bike 15 mph        -> 60/15 =  4.00 min/mile
  ///   swim 2:00 / 100 yd -> 1 mile is 17.6 x 100yd -> 35.2 min/mile
  static double fallbackMinutesPerMile(ActivityType? sport) {
    switch (sport) {
      case ActivityType.cycling:
        return 4.0;
      case ActivityType.swimming:
        return 35.2;
      case ActivityType.running:
      case ActivityType.brick:
      case ActivityType.multisport:
      case ActivityType.triathlon:
      case ActivityType.duathlon:
      case ActivityType.other:
      case null:
        // Running's fallback also covers mixed and unknown sports: it is the
        // slowest of the three, so it over-estimates rather than under.
        return 10.0;
    }
  }

  /// The usual pace for [sport] given [samples] already filtered to that sport
  /// and to the window.
  static UsualPace from(List<CompletedSample> samples, ActivityType? sport) {
    final paces = <double>[];
    for (final s in samples) {
      // A zero or negative on either side is not a session, it is a bad row.
      if (s.distanceMiles <= 0 || s.durationMinutes <= 0) continue;
      paces.add(s.durationMinutes / s.distanceMiles);
    }

    if (paces.length < minimumSamples) {
      return UsualPace(
        fallbackMinutesPerMile(sport),
        UsualPaceSource.fallback,
        sampleCount: paces.length,
      );
    }

    paces.sort();
    return UsualPace(
      _slowestQuartilePace(paces),
      UsualPaceSource.history,
      sampleCount: paces.length,
    );
  }

  /// The typical pace WITHIN the slowest quarter of sessions — not the
  /// boundary between the third and fourth quartiles.
  ///
  /// Both readings of "slowest quartile" are defensible in English; this one
  /// is right for the job. Measured against a realistic fast-skewed week
  /// (7:00 intervals, 7:30 tempo, 8:00 steady, 10:30 long run) the BOUNDARY
  /// reading returns 8.6 min/mile, which estimates a 10-mile long run at 86
  /// minutes — under the 90-minute LONG threshold, so the nudge silently never
  /// fires. That is the exact failure the ruling chose a quartile to avoid.
  /// Taking the median of the slowest quarter returns the long-run pace itself
  /// and clears the threshold.
  ///
  /// [sorted] is ascending, so the slowest sessions are at the end.
  static double _slowestQuartilePace(List<double> sorted) {
    final start = (sorted.length * 0.75).floor().clamp(0, sorted.length - 1);
    final slowest = sorted.sublist(start);
    final mid = slowest.length ~/ 2;
    return slowest.length.isOdd
        ? slowest[mid]
        : (slowest[mid - 1] + slowest[mid]) / 2;
  }
}
