import 'dart:math' as math;

/// Intraday display arithmetic — SSOT:
/// docs/ssot/spec/daily-macros/intraday-display.md (RATIFIED v1).
///
/// Everything here is display-layer, strictly downstream of the daily-macros
/// engine: it answers "where should I be *by now*, what have I *actually*
/// done, and what is still owed?" from the returned plan plus the day's log,
/// and never invents a quantity the engine doesn't stand behind. Pinned by
/// docs/ssot/vectors/daily-macros/intraday-display.json via
/// test/features/daily_macros/intraday_display_vectors_test.dart.
class IntradayDisplay {
  IntradayDisplay._();

  /// Assumed waking window when sleep data is absent: 07:00–23:00 `[design]`.
  static const int wakingWindowStartMin = 7 * 60;
  static const int wakingWindowEndMin = 23 * 60;
  static const int totalWakingMinutes =
      wakingWindowEndMin - wakingWindowStartMin;

  /// TEF fraction — mirrors the engine's rate so the two agree at day's end.
  static const double digestionFraction = 0.10;

  // -------------------------------------------------------------------------
  // §1 · Intraday accrual — each burned-side component accrues by the method
  // that matches its real driver and what we can actually observe live.
  // -------------------------------------------------------------------------

  /// BMR: the only term where clock proration is correct — basal burn is
  /// near-constant per minute. Since-midnight basis `[design]`.
  static double restingSoFar({
    required double rmr,
    required int minutesSinceMidnight,
  }) {
    return rmr * (minutesSinceMidnight / 1440);
  }

  /// TEF: meal-driven, never clock-prorated — exactly 0 before the first
  /// logged intake by construction.
  static double digestionSoFar({required double eatenKcal}) {
    return digestionFraction * eatenKcal;
  }

  /// EAT: atomic completed sessions. Completed counts in full; upcoming
  /// counts zero; a half-finished workout is the device's to report, never a
  /// clock fraction's. A `status='deleted'` tombstone contributes zero —
  /// identical in effect to nonexistence (§4b).
  static double workoutSoFar({required List<IntradaySession> sessions}) {
    var total = 0.0;
    for (final s in sessions) {
      if (!s.renders) continue;
      if (s.actualTimeMin == null) continue;
      total += s.kcal;
    }
    return total;
  }

  /// NEAT: measured when we can, modeled when we must.
  ///
  /// Connected path: wearable active energy through the last sync, minus
  /// ONLY wearable-recorded workout kcal through that sync (the double-count
  /// guard is asymmetric — a formula-valued session a watch never saw is not
  /// in the wearable total, and subtracting it would delete real NEAT),
  /// plus the model rate for waking minutes since the sync — never a flat
  /// freeze, never a re-smear of the whole day.
  ///
  /// Fallback path: the engine's own NEAT estimate prorated over the assumed
  /// waking window (no phantom 3 a.m. movement).
  static double movementSoFar({
    required int minutesSinceMidnight,
    required double neatKcal,
    required List<IntradaySession> sessions,
    bool wearableConnected = false,
    bool syncedToday = false,
    int? lastSyncMin,
    double? activeEnergyThroughSync,
  }) {
    final modelRatePerWakingMin = neatKcal / totalWakingMinutes;

    if (wearableConnected &&
        syncedToday &&
        lastSyncMin != null &&
        activeEnergyThroughSync != null) {
      var wearableWorkoutKcal = 0.0;
      for (final s in sessions) {
        if (!s.renders) continue;
        if (!s.wearableRecorded) continue;
        final actual = s.actualTimeMin;
        if (actual == null || actual > lastSyncMin) continue;
        wearableWorkoutKcal += s.kcal;
      }

      final measured = math.max(
        0.0,
        activeEnergyThroughSync - wearableWorkoutKcal,
      );
      final bridgeMinutes = _wakingMinutesBetween(
        lastSyncMin,
        minutesSinceMidnight,
      );
      return measured + modelRatePerWakingMin * bridgeMinutes;
    }

    final wakingElapsed = _wakingMinutesBetween(0, minutesSinceMidnight);
    return neatKcal * (wakingElapsed / totalWakingMinutes);
  }

  static int _wakingMinutesBetween(int fromMin, int toMin) {
    final from = fromMin.clamp(wakingWindowStartMin, wakingWindowEndMin);
    final to = toMin.clamp(wakingWindowStartMin, wakingWindowEndMin);
    return math.max(0, to - from);
  }

  /// The full §1 decomposition. `*_by_days_end` values are the engine's
  /// returned plan, verbatim — never derived here.
  static IntradayAccrual burnedSoFar({
    required int minutesSinceMidnight,
    required double rmr,
    required double neatKcal,
    required double eatenKcal,
    required List<IntradaySession> sessions,
    bool wearableConnected = false,
    bool syncedToday = false,
    int? lastSyncMin,
    double? activeEnergyThroughSync,
  }) {
    final resting = restingSoFar(
      rmr: rmr,
      minutesSinceMidnight: minutesSinceMidnight,
    );
    final movement = movementSoFar(
      minutesSinceMidnight: minutesSinceMidnight,
      neatKcal: neatKcal,
      sessions: sessions,
      wearableConnected: wearableConnected,
      syncedToday: syncedToday,
      lastSyncMin: lastSyncMin,
      activeEnergyThroughSync: activeEnergyThroughSync,
    );
    final workout = workoutSoFar(sessions: sessions);
    final digestion = digestionSoFar(eatenKcal: eatenKcal);

    return IntradayAccrual(
      resting: resting,
      movement: movement,
      workout: workout,
      digestion: digestion,
    );
  }

  // -------------------------------------------------------------------------
  // §2 · Net energy balance and its copy
  // -------------------------------------------------------------------------

  /// Band copy for `net_so_far = eaten − burned`. Bounds are inclusive at
  /// ±200/±500 (oracle convention). Two safety-derived rules:
  ///  1. Under `energy_basis == 'pre_override'` surplus copy is suppressed
  ///     entirely (returns null) — the EA gate deliberately set intake above
  ///     burn; calling a safety floor a "surplus" tells an under-fueled
  ///     athlete to eat less. Deficit copy still renders.
  ///  2. Deficit copy is never congratulatory — it always points toward
  ///     food. Do not edit these strings without the register
  ///     (intraday-display.md §2).
  static String? netBandCopy({
    required double netKcal,
    required String energyBasis,
  }) {
    final band = _band(netKcal);
    if (energyBasis == 'pre_override' &&
        (band == _NetBand.slightSurplus || band == _NetBand.surplus)) {
      return null;
    }
    switch (band) {
      case _NetBand.onTrack:
        return 'on track';
      case _NetBand.slightSurplus:
        return 'slight surplus';
      case _NetBand.surplus:
        return 'surplus';
      case _NetBand.slightDeficit:
        return 'slight deficit';
      case _NetBand.deficit:
        return 'deficit — time to eat';
    }
  }

  static _NetBand _band(double netKcal) {
    if (netKcal >= -200 && netKcal <= 200) return _NetBand.onTrack;
    if (netKcal > 200 && netKcal <= 500) return _NetBand.slightSurplus;
    if (netKcal > 500) return _NetBand.surplus;
    if (netKcal >= -500) return _NetBand.slightDeficit;
    return _NetBand.deficit;
  }

  // -------------------------------------------------------------------------
  // §3 · Planned-but-uneaten intake — three definitions, never blurred
  // -------------------------------------------------------------------------

  /// `remaining` subtracts LOGGED only — a scheduled dinner reduces nothing
  /// until eaten. `projected` may drive copy and ring overlays; it may never
  /// drive remaining, EA, or net balance (those are actuals-only).
  static IntakeSummary intakeSummary({
    required double targetKcal,
    required List<IntakeEntry> entries,
  }) {
    var logged = 0.0;
    var planned = 0.0;
    for (final e in entries) {
      if (e.consumed) {
        logged += e.kcal;
      } else {
        planned += e.kcal;
      }
    }
    return IntakeSummary(
      logged: logged,
      planned: planned,
      remaining: targetKcal - logged,
      projected: logged + planned,
    );
  }

  // -------------------------------------------------------------------------
  // §5 · Tracking-off is a display mode, never an engine mode
  // -------------------------------------------------------------------------

  /// What tracking-off hides: every §1–§3 quantity. What it never
  /// suppresses: BLOCK and HARD_WARNING's raised-target state — the athlete
  /// who hides numbers is disproportionately the athlete the EA gate exists
  /// to protect.
  static TrackingVisibility trackingVisibility({
    required bool trackingOff,
    required String? eaStatus,
  }) {
    final safetySurfaces = eaStatus == 'BLOCK' || eaStatus == 'HARD_WARNING';
    return TrackingVisibility(
      quantitiesRendered: !trackingOff,
      blockRendered: safetySurfaces,
    );
  }
}

enum _NetBand { onTrack, slightSurplus, surplus, slightDeficit, deficit }

/// One session of the day, as the display layer sees it.
class IntradaySession {
  const IntradaySession({
    required this.kcal,
    this.actualTimeMin,
    this.status,
    this.wearableRecorded = false,
  });

  /// Resolved session energy (F22 ladder: GARMIN → TP_ACTUAL → FORMULA).
  final double kcal;

  /// Minutes since midnight the session actually happened; null = not done.
  /// Keys off `actual_time` presence, never off `planned_time` having passed.
  final int? actualTimeMin;

  /// Row status; 'deleted' tombstones never render and contribute zero to
  /// every derived quantity (§4b).
  final String? status;

  /// Whether a wearable recorded this session (drives the NEAT
  /// double-count guard — only wearable-recorded kcal are subtracted from
  /// wearable active energy).
  final bool wearableRecorded;

  bool get renders => status != 'deleted';
}

/// §1 decomposition (the Today's Energy modal rows).
class IntradayAccrual {
  const IntradayAccrual({
    required this.resting,
    required this.movement,
    required this.workout,
    required this.digestion,
  });

  final double resting;
  final double movement;
  final double workout;
  final double digestion;

  double get burned => resting + movement + workout + digestion;
}

/// §3 quantities.
class IntakeSummary {
  const IntakeSummary({
    required this.logged,
    required this.planned,
    required this.remaining,
    required this.projected,
  });

  final double logged;
  final double planned;
  final double remaining;

  /// Forecast total — COPY ONLY; never feeds remaining, EA, or net balance.
  final double projected;
}

class IntakeEntry {
  const IntakeEntry({required this.kcal, required this.consumed});
  final double kcal;
  final bool consumed;
}

class TrackingVisibility {
  const TrackingVisibility({
    required this.quantitiesRendered,
    required this.blockRendered,
  });

  final bool quantitiesRendered;
  final bool blockRendered;
}
