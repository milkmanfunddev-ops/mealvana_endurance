// Carb-loading pace engine — the published entry point for the
// carb-loading@v1 conformance vectors (qa tag f809f54, handback G2/G3).
//
// Implements spec/fueling/carb-loading.md RATIFIED v1 (CL-1..CL-12 + the
// Q-CL11 anchor addendum), mirrored under docs/ssot/. Pure Dart on purpose:
// no Flutter imports, no clock reads, no persistence — callers pass
// device-local minutes-since-midnight (CL-10) and the day's eaten grams
// (Q-CL8: ALL food-log rows for the day, slot-tagged or not).
//
// Conventions pinned by the vector oracle (vectors/fueling/carb-loading.json):
// rounding is Dart .round() (half away from zero); day-variant pace fields are
// null, never 0; paceState boundaries are inclusive (behind strictly > band,
// ahead strictly < -band).

/// Which day of the protocol the surface is rendering, relative to today.
enum CarbDayRel { today, future, past }

/// Pace verdict for the LOAD face. Values match the vector oracle's
/// `paceState` strings via [name] (`on_pace` uses [CarbPaceState.wire]).
enum CarbPaceState {
  behind('behind'),
  onPace('on_pace'),
  ahead('ahead');

  const CarbPaceState(this.wire);
  final String wire;
}

/// One evaluation of the loading-day pace mechanic (CL-5..CL-11).
///
/// Nullable fields are null on non-today day variants — owed(t) is undefined
/// off-today (null means no value, NOT zero; coercing is the bug the vectors
/// exist to catch).
class CarbPaceResult {
  const CarbPaceResult({
    required this.owedG,
    required this.bandG,
    required this.deltaG,
    required this.paceState,
    required this.paceN,
    required this.loaded,
    required this.fillFrac,
    required this.tickFrac,
    required this.tickHidden,
  });

  /// Grams owed by the ramp at t — piecewise-linear through the Option-R
  /// anchors. Null off-today.
  final double? owedG;

  /// Dead band: max(5% of owed, 10 g). Null off-today.
  final double? bandG;

  /// owed − eaten (signed). Null off-today.
  final double? deltaG;

  /// behind / on_pace / ahead. Null off-today.
  final CarbPaceState? paceState;

  /// |delta| rounded to whole grams — the face's display number. Null
  /// off-today.
  final int? paceN;

  /// eaten >= day target.
  final bool loaded;

  /// Loader fill: min(1, eaten / target).
  final double fillFrac;

  /// Pace-tick position: owed / target. Null off-today.
  final double? tickFrac;

  /// The cream tick hides when nothing is owed yet, when the day is loaded,
  /// and on every non-today variant.
  final bool tickHidden;

  /// Wire shape used by the conformance harness; keys are the vector
  /// oracle's field names.
  Map<String, Object?> toWire() => <String, Object?>{
    'owedG': owedG,
    'bandG': bandG,
    'deltaG': deltaG,
    'paceState': paceState?.wire,
    'paceN': paceN,
    'loaded': loaded,
    'fillFrac': fillFrac,
    'tickFrac': tickFrac,
    'tickHidden': tickHidden,
  };
}

/// The carb-loading protocol + pace math, exactly as ratified.
class CarbLoadingPaceEngine {
  CarbLoadingPaceEngine._();

  /// lb → kg. Pinned by the repo-wide constant discipline (D-005 family):
  /// a future server twin must use this value, not 0.45359237.
  static const double kgPerLb = 0.453592;

  /// Per-day g/kg rates, first loading day first (CL-1..CL-3 + Q-CL3a):
  /// 3-Day Classic 8/8/10 · 2-Day Quick 9/11 · 1-Day 11.
  static const Map<int, List<double>> ratesByProtocol = <int, List<double>>{
    3: <double>[8.0, 8.0, 10.0],
    2: <double>[9.0, 11.0],
    1: <double>[11.0],
  };

  /// The ruled six-slot split (CL-4): Breakfast/Morning Snack/Lunch/
  /// Afternoon Snack/Dinner/Evening Snack.
  static const List<double> slotSplits = <double>[
    0.25,
    0.10,
    0.25,
    0.15,
    0.20,
    0.05,
  ];

  /// Slot anchor clocks, minutes since local midnight (CL-5 re-ruled):
  /// 6:00 · 9:00 · 12:00 · 15:00 · 18:00 · 21:00.
  static const List<int> slotTimesMin = <int>[360, 540, 720, 900, 1080, 1260];

  /// The feeding window closes at 22:00 (CL-6).
  static const int closeMin = 1320;

  /// g/kg for one loading day. [daysBeforeRace] counts down to race morning
  /// (the first loading day of an n-day protocol has daysBeforeRace == n).
  static double gPerKg({
    required int protocolDays,
    required int daysBeforeRace,
  }) {
    final rates = ratesByProtocol[protocolDays];
    if (rates == null) {
      throw ArgumentError.value(protocolDays, 'protocolDays', 'must be 1..3');
    }
    final index = protocolDays - daysBeforeRace;
    if (index < 0 || index >= rates.length) {
      throw ArgumentError.value(
        daysBeforeRace,
        'daysBeforeRace',
        'must be 1..$protocolDays for a $protocolDays-day protocol',
      );
    }
    return rates[index];
  }

  /// CL-1..CL-3: day target = round(rate × weight-in-kg).
  static int dayTargetG({
    required double bodyWeightLb,
    required int protocolDays,
    required int daysBeforeRace,
  }) {
    final rate = gPerKg(
      protocolDays: protocolDays,
      daysBeforeRace: daysBeforeRace,
    );
    return (rate * bodyWeightLb * kgPerLb).round();
  }

  /// CL-4: slot target = round(split × stored day target). The STORED value
  /// drives this — never re-derive from the protocol when the athlete edited
  /// the day (CL-4a).
  static List<int> slotTargetsG(int dayTargetG) =>
      slotSplits.map((s) => (s * dayTargetG).round()).toList(growable: false);

  /// Q-CL11 Option-R ramp anchors: [t, cumulative grams] — the running sum of
  /// the ROUNDED slot targets at each slot clock, with the 22:00 anchor
  /// FORCED to the stored day target (the final window absorbs rounding
  /// drift on edited targets).
  static List<List<num>> rampAnchors(int dayTargetG) {
    final slots = slotTargetsG(dayTargetG);
    final anchors = <List<num>>[
      <num>[slotTimesMin.first, 0],
    ];
    var cum = 0;
    for (var i = 1; i < slotTimesMin.length; i++) {
      cum += slots[i - 1];
      anchors.add(<num>[slotTimesMin[i], cum]);
    }
    anchors.add(<num>[closeMin, dayTargetG]);
    return anchors;
  }

  /// CL-6/CL-7: grams owed at [tMin] — 0 before the first anchor, the day
  /// target after close, linear between anchors. Fractional mid-window; the
  /// display rounds, the math never does.
  static double owedG({required int dayTargetG, required int tMin}) {
    final anchors = rampAnchors(dayTargetG);
    if (tMin <= anchors.first[0]) return 0;
    for (var i = 1; i < anchors.length; i++) {
      if (tMin <= anchors[i][0]) {
        final t0 = anchors[i - 1][0].toDouble();
        final g0 = anchors[i - 1][1].toDouble();
        final t1 = anchors[i][0].toDouble();
        final g1 = anchors[i][1].toDouble();
        return g0 + (tMin - t0) / (t1 - t0) * (g1 - g0);
      }
    }
    return dayTargetG.toDouble();
  }

  /// CL-8..CL-11: the full pace evaluation for one render of the LOAD face.
  static CarbPaceResult evaluate({
    required int dayTargetG,
    required double eatenG,
    required int tMin,
    CarbDayRel dayRel = CarbDayRel.today,
  }) {
    final loaded = eatenG >= dayTargetG;
    final fillFrac = dayTargetG <= 0
        ? 0.0
        : (eatenG / dayTargetG).clamp(0.0, 1.0).toDouble();

    if (dayRel != CarbDayRel.today) {
      return CarbPaceResult(
        owedG: null,
        bandG: null,
        deltaG: null,
        paceState: null,
        paceN: null,
        loaded: loaded,
        fillFrac: fillFrac,
        tickFrac: null,
        tickHidden: true,
      );
    }

    final owed = owedG(dayTargetG: dayTargetG, tMin: tMin);
    final band = (0.05 * owed) < 10.0 ? 10.0 : 0.05 * owed;
    final delta = owed - eatenG;
    final CarbPaceState state;
    if (delta > band) {
      state = CarbPaceState.behind;
    } else if (delta < -band) {
      state = CarbPaceState.ahead;
    } else {
      state = CarbPaceState.onPace;
    }
    return CarbPaceResult(
      owedG: owed,
      bandG: band,
      deltaG: delta,
      paceState: state,
      paceN: delta.abs().round(),
      loaded: loaded,
      fillFrac: fillFrac,
      tickFrac: dayTargetG <= 0 ? 0.0 : owed / dayTargetG,
      tickHidden: owed <= 0 || loaded,
    );
  }
}
