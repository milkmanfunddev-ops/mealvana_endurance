import '../../activities/domain/activity.dart';
import '../../activities/domain/brick_session_legs.dart';
import '../../daily_macros/domain/daily_macro_targets.dart';
import '../../daily_macros/domain/intraday_display.dart';
import '../../meal_logging/domain/consumed_totals.dart';
import '../../meal_logging/domain/meal_log.dart';
import '../../meal_logging/domain/meal_slot.dart';
import '../../nutrition_plan/application/daily_baseline_calculator.dart';
import '../../../shared/domain/session_input_resolver.dart';
import '../domain/dashboard_models.dart';
import '../domain/workout_state_resolver.dart';

/// The assembled macro-dashboard view state.
class DashboardData {
  const DashboardData({
    required this.nodes,
    required this.energy,
    required this.trackingOn,
    this.breakdown,
  });

  final List<DashboardNode> nodes;

  /// Null when no targets exist yet for the day.
  final EnergyCardData? energy;
  final bool trackingOn;

  /// Extra quantities for the Breakdown Pager; null when no targets exist.
  final BreakdownData? breakdown;
}

/// Pure builder for the macro dashboard (surfaces/macro-dashboard.md).
///
/// Every quantity maps to a documented spec field (S-3): so-far arithmetic
/// comes from [IntradayDisplay] (intraday-display.md §§1–3), session energy
/// from the F22 ladder (measured Garmin kcal when mirrored into the local
/// row, else the formula rung), and card states from the two-time model,
/// the tombstone ruling and the v2 unified-skip model (Q-D6:
/// platform-resolution.md `SKIPPED` addition, workout-card.md v2).
class MacroDashboardAssembler {
  const MacroDashboardAssembler();

  DashboardData assemble({
    required DateTime selectedDate,
    required DateTime now,
    required List<Activity> activities,
    required List<MealLog> meals,
    required DailyMacroTargets? targets,
    required ConsumedTotals consumed,
    required bool trackingOn,
    List<DailyMacroTargets?> weeklyTargets = const [],
    double? profileWeightKg,
  }) {
    // §4b: a status='deleted' tombstone never renders and contributes zero
    // to every derived quantity — identical in effect to nonexistence.
    final live =
        activities
            .where(
              (a) => a.status != ActivityStatus.deleted && a.deletedAt == null,
            )
            .toList(growable: false)
          ..sort((a, b) => a.displayTime.compareTo(b.displayTime));

    // Bug 2026-08-20-dashboard-weight-fallback-70kg: F4 session cost is
    // exactly linear in body weight (invariant I6), so a silent stand-in
    // weight is a wrong number for every athlete — the old `?? 70.0` priced
    // a 49.9-kg athlete's runs ~40% high on every surface. Resolution:
    // the caller's live profile weight first (a Settings weight edit reprices
    // the display without waiting for a recalc), then the weight the engine
    // calculated this day with (targets.weightKg, persisted in the row's
    // calculation_input). If BOTH are absent we do NOT invent a number:
    // formula-rung sessions stay unpriced (kcal null) and are surfaced as
    // absent — see [WorkoutCardData.kcal].
    final double? weightKg = profileWeightKg ?? targets?.weightKg;
    final cards = live
        .map((a) => _workoutCard(a, selectedDate, now, weightKg))
        .toList(growable: false);

    final mealNodes = _mealNodes(meals);

    // S-7: a SKIPPED card loses its timeline slot — no timestamp, tucked
    // after every timed card of the day (planned or done); several skipped
    // cards order by planned_time ascending. Unskip / G1 recovery restores
    // the time-ordered slot simply by the card no longer being skipped.
    final timed = _TimedNode.sorted([
      for (final c in cards)
        if (c.data.counts)
          _TimedNode(
            c.time,
            DashboardNode.workout(
              timeLabel: c.data.timeLabel,
              workout: c.data,
              brick: c.activity.isBrick ? c.activity : null,
            ),
            tieBreak: -1,
          ),
      ...mealNodes,
    ]);
    final tucked = <_TimedNode>[
      for (final c in cards)
        if (c.data.isSkipped)
          _TimedNode(
            c.time,
            DashboardNode.workout(
              timeLabel: '',
              workout: c.data,
              brick: c.activity.isBrick ? c.activity : null,
            ),
          ),
    ]..sort((a, b) => a.time.compareTo(b.time));
    final nodes = [...timed, ...tucked];

    final built = targets == null
        ? null
        : _energy(
            targets,
            consumed,
            cards,
            selectedDate,
            now,
            live,
            meals,
            weeklyTargets,
          );

    return DashboardData(
      nodes: nodes.map((n) => n.node).toList(growable: false),
      energy: built?.energy,
      trackingOn: trackingOn,
      breakdown: built?.breakdown,
    );
  }

  _TimedCard _workoutCard(
    Activity a,
    DateTime selectedDate,
    DateTime now,
    double? weightKg,
  ) {
    // The state derivation (two-time model, Q-D5/Q-D6 skip triggers, G6
    // sync-beats-skip) lives in resolveWorkoutCardState — extracted for the
    // home-shell calendar sheet's dot channel; the rulings are documented
    // there.
    final state = resolveWorkoutCardState(a, day: selectedDate, now: now);
    final done = a.status == ActivityStatus.completed || a.actualTime != null;
    final skipActive = !done && a.status == ActivityStatus.skipped;
    final selectedDay = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final today = DateTime(now.year, now.month, now.day);
    final dayFuture = selectedDay.isAfter(today);

    // A skipped card has no displayed time (S-7); its sort key for the tucked
    // group is planned_time. Everything else displays actual ?? planned.
    final displayTime = state == WorkoutCardState.skipped
        ? (a.plannedTime ?? a.scheduledDateTime)
        : a.displayTime;

    return _TimedCard(
      displayTime,
      a,
      WorkoutCardData(
        activityId: a.id,
        name: a.title,
        timeLabel: _timeLabel(displayTime),
        metaLabel: _meta(a, verified: state == WorkoutCardState.doneVerified),
        kcal: _sessionKcal(a, weightKg),
        state: state,
        sport: a.activityType.name,
        verifiedSourceName: verifiedSourceNameFor(a),
        skipActive: skipActive,
        // A future day's workout hasn't happened: no mark-done (ruled
        // 2026-08-18). Mark-UNDONE on a (legacy) confirmed future card stays
        // available so it can be corrected.
        markDoneAllowed: !dayFuture,
      ),
    );
  }

  /// F22 kcal ladder (intraday-display.md §1): measured (Garmin
  /// ActiveKilocalories, mirrored into calories_burned) beats the formula;
  /// the formula rung is F4 at the session's IF and duration.
  ///
  /// This ONE function prices every display surface — the workout card, the
  /// Active Energy face rows and the Full Breakdown sheet all read its
  /// result, so they cannot disagree with each other by construction
  /// (bug 2026-08-20-session-kcal-three-surfaces-disagree, invariant I4).
  ///
  /// Input conventions (each safe to combine, because none can silently
  /// stack onto a wrong weight — an unresolvable weight aborts the formula
  /// rung entirely instead of estimating):
  ///  * IF — zones when present (RMS over the planned distribution, the same
  ///    derivation the engine uses), else the ENGINE's default 70/20/10
  ///    distribution through that same derivation (IF 0.7715). Superseding
  ///    the 2026-08-20 flat-0.74 fallback, which made a zoneless session cost
  ///    ~8% less on screen than in the targets beside it.
  ///  * duration — [SessionInputResolver.durationMinutes], the SAME ladder
  ///    that builds the engine's `SessionInput`: actual beats planned, then
  ///    distance × the session's own prescribed pace, then the flat fallback.
  ///    Sharing the ladder is the point — this surface previously kept only
  ///    the last rung (`?? 60`) and so priced a 3 mi and a 15 mi run alike,
  ///    contradicting the macro targets beside it by 649 kcal on a real
  ///    account (bug 2026-08-22-dashboard-prices-distance-sessions-at-flat-
  ///    60min).
  ///  * weight — required; null means the formula rung is unpriceable and
  ///    this returns null (never a stand-in constant — see
  ///    [WorkoutCardData.kcal]).
  double? _sessionKcal(Activity a, double? weightKg) {
    final measured = a.caloriesBurned;
    if (measured != null && measured > 0) return measured;
    if (weightKg == null) return null;
    final durationHr =
        SessionInputResolver.durationMinutes(
          activityType: a.activityType.name,
          // Display precedence: what it actually took beats what was planned.
          explicitMinutes: a.actualDurationMinutes ?? a.durationMinutes,
          distanceMiles: a.distanceMiles,
          paceTargetMinutesPerMile: a.paceTargetMinutesPerMile,
          cyclingSpeedMph: a.cyclingSpeedMph,
          swimmingPacePer100mSeconds: a.swimmingPacePer100mSeconds,
        ) /
        60.0;
    final dist = a.intensityDistribution;
    final intensityFactor = dist != null
        ? DailyBaselineCalculator.zoneDistributionToIf(
            pctConversational: dist.conversationalPct / 100,
            pctTempo: dist.tempoPct / 100,
            pctAllout: dist.allOutPct / 100,
          )
        // RULED 2026-08-22: a zoneless session takes the ENGINE's default
        // distribution, through the same RMS derivation — not a separate flat
        // IF. See SessionInputResolver.defaultZ1Z2Pct.
        : DailyBaselineCalculator.zoneDistributionToIf(
            pctConversational: SessionInputResolver.defaultZ1Z2Pct / 100,
            pctTempo: SessionInputResolver.defaultZ3Z4Pct / 100,
            pctAllout: SessionInputResolver.defaultZ5Pct / 100,
          );
    // A brick with legs prices as the SUM of its legs, each at its own
    // sport's ratified rate over its own duration — the same decomposition
    // the engine feed sends (`DailyMacroService._sessionsFromActivityRow`),
    // so the two surfaces reconcile. INTERIM pending
    // qa/intake/2026-09-04-brick-per-leg-pricing-ratification.md; the parent
    // session's IF applies to every leg (per-leg IF is one of the open
    // ratification questions). A brick with NO segment metadata falls through
    // to the single-session path below.
    // Bug: ops/data/bug-reports/2026-09-04-brick-priced-as-one-conservative-session.md
    final legs = a.isBrick
        ? (a.brickMetadata?.sessionLegs ?? const <BrickSessionLeg>[])
        : const <BrickSessionLeg>[];
    if (legs.isNotEmpty) {
      var sum = 0.0;
      for (final leg in legs) {
        sum += DailyBaselineCalculator.sessionCost(
          sport: leg.sport,
          durationHr: leg.durationMinutes / 60.0,
          intensityFactor: intensityFactor,
          weightKg: weightKg,
        );
      }
      return sum;
    }
    return DailyBaselineCalculator.sessionCost(
      // `other` → strength, as the engine prices it: same rate either way, but
      // it also carries the engine's 30-minute default instead of 60. The
      // composite types stay on the interim conservative rate pending
      // qa/intake/2026-08-20-session-cost-unknown-activity-types.md — that is
      // a rate question, out of scope for this duration fix.
      sport: SessionInputResolver.displaySport(a.activityType.name),
      durationHr: durationHr,
      intensityFactor: intensityFactor,
      weightKg: weightKg,
    );
  }

  /// How far after a card's first meal a same-type meal may be eaten and
  /// still join that card (finding 27-001). Later than this, it opens its own
  /// card at its own time.
  static const _mealCardWindow = Duration(minutes: 30);

  /// Meal cards follow the clock (testing-wave ticket 59, finding 27-001):
  /// each card sits at its first meal's time, and a same-type meal joins it
  /// only when eaten within [_mealCardWindow] of that first meal. Grouping by
  /// type alone filed a 3:43 PM snack under a 2:08 PM card.
  List<_TimedNode> _mealNodes(List<MealLog> meals) {
    DateTime timeOf(MealLog m) => m.eatenAt ?? m.createdAt;

    final byType = <MealSlot?, List<MealLog>>{};
    for (final m in meals.where((m) => !m.isDeleted)) {
      byType.putIfAbsent(m.slot, () => []).add(m);
    }

    final nodes = <_TimedNode>[];
    byType.forEach((slot, entries) {
      entries.sort((a, b) {
        final byTime = timeOf(a).compareTo(timeOf(b));
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
      var card = <MealLog>[];
      void close() {
        if (card.isEmpty) return;
        final time = timeOf(card.first);
        nodes.add(
          _TimedNode(
            time,
            DashboardNode.meals(
              timeLabel: _timeLabel(time),
              mealGroupLabel: slot?.label ?? 'Logged',
              meals: [
                for (final m in card)
                  MealItemData(
                    id: m.id,
                    name: m.name,
                    kcal: m.calories?.toDouble() ?? 0,
                    carbsG: m.carbsG ?? 0,
                    proteinG: m.proteinG ?? 0,
                    fatG: m.fatG ?? 0,
                    planned: m.eatenAt == null,
                  ),
              ],
            ),
            // Same-minute cards order by meal type (breakfast → snack, then
            // untagged), never by which type holds the newest meal — that
            // arrival order swapped two 2:08 PM cards after a delete.
            tieBreak: slot?.index ?? MealSlot.values.length,
          ),
        );
        card = <MealLog>[];
      }

      for (final m in entries) {
        if (card.isNotEmpty &&
            timeOf(m).difference(timeOf(card.first)) > _mealCardWindow) {
          close();
        }
        card.add(m);
      }
      close();
    });
    return nodes;
  }

  _BuiltEnergy _energy(
    DailyMacroTargets targets,
    ConsumedTotals consumed,
    List<_TimedCard> cards,
    DateTime selectedDate,
    DateTime now,
    List<Activity> liveActivities,
    List<MealLog> meals,
    List<DailyMacroTargets?> weeklyTargets,
  ) {
    // Elapsed minutes of the SELECTED day — the denominator every "so far"
    // quantity is prorated against (intraday-display.md §1:
    // `neat_so_far = neat_kcal × (waking_minutes_elapsed / total_waking_minutes)`).
    // It is a fact about the day, not a product choice: a past day is over
    // (1440), today has run as far as the clock says, and a FUTURE day has not
    // started (0).
    //
    // The `: 1440` that used to cover both non-today cases claimed a day a week
    // away was fully elapsed, so the sheet showed a full day's resting + NEAT
    // under "so far" while workout and digestion — which key off completed
    // items — stayed at 0. That is self-contradictory (I4) in two directions at
    // once: it read "100% of the day done" while so-far ≠ by-day's-end, and it
    // published a −1,339 kcal net balance with "deficit — time to eat" for a day
    // that had not begun.
    // Bug: ops/data/bug-reports/2026-08-22-breakdown-sheet-future-day-claims-day-is-over.md
    //
    // NOT decided here: whether a future day should show the net-balance card
    // at all, and in which copy register. That is genuinely unspecified and is
    // open as qa/intake/2026-08-20-future-day-net-balance-copy.md. This change
    // only stops the surface from asserting elapsed time it does not have.
    final selected = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final todayDay = DateTime(now.year, now.month, now.day);
    final isToday = _sameDay(selectedDate, now);
    final minutesSinceMidnight = isToday
        ? now.hour * 60 + now.minute
        : (selected.isBefore(todayDay) ? 1440 : 0);

    // S-2 (skip scope): a SKIPPED workout's kcal and fuel leave EVERY
    // surface figure — net balance, band copy, Active Energy sheet,
    // by-end-of-day burn — in the same frame; passive and active alike.
    final counted = cards.where((c) => c.data.counts).toList(growable: false);

    // An unpriceable session (kcal null — no measured value, no resolvable
    // weight) is surfaced as ABSENT: it enters no accrual, no done/planned
    // sum and gets no receipt row, so every figure and every row the sheet
    // shows still reconcile exactly. A fabricated 0-kcal row would be a
    // false statement about the workout; omission states "not included",
    // which is the least-lying representation available
    // (bug 2026-08-20-dashboard-weight-fallback-70kg).
    final priced = counted
        .where((c) => c.data.kcal != null)
        .toList(growable: false);

    final sessions = [
      for (final c in priced)
        IntradaySession(
          kcal: c.data.kcal!,
          actualTimeMin: c.data.isDone
              ? c.time.hour * 60 + c.time.minute
              : null,
        ),
    ];

    final accrual = IntradayDisplay.burnedSoFar(
      minutesSinceMidnight: minutesSinceMidnight,
      rmr: targets.rmr,
      neatKcal: targets.neatKcal ?? 0,
      eatenKcal: consumed.calories.toDouble(),
      sessions: sessions,
    );

    // Display convention (pinned by the canonical mock day: burned 1783.65
    // "displays 1,783", net −133, done-swipe example −1,338): clock-prorated
    // accrual terms TRUNCATE — burn that hasn't happened yet is never
    // credited — while session kcal are engine boundary values rounded
    // half-up PER SESSION before summing (229 + 1,205, not round(1,433.4)).
    // The displayed net is eaten − displayed burned so the equation row
    // always reconciles.
    var displayedWorkout = 0.0;
    for (final s in sessions) {
      if (s.actualTimeMin != null && s.renders) {
        displayedWorkout += s.kcal.roundToDouble();
      }
    }
    final displayedBurned =
        accrual.resting.floorToDouble() +
        accrual.movement.floorToDouble() +
        displayedWorkout +
        accrual.digestion.floorToDouble();

    final net = consumed.calories - displayedBurned;
    // Band copy keys off the UNROUNDED net (intraday-display §2).
    final bandCopy = IntradayDisplay.netBandCopy(
      netKcal: consumed.calories - accrual.burned,
      energyBasis: targets.energyBasis,
    );

    // Same per-session rounding as the burn display, so 229 + 1,205
    // projects 1,434 exactly as the reference rendering shows.
    var doneKcal = 0.0;
    var plannedKcal = 0.0;
    for (final c in priced) {
      if (c.data.isDone) {
        doneKcal += c.data.kcal!.roundToDouble();
      } else {
        plannedKcal += c.data.kcal!.roundToDouble();
      }
    }

    final energy = EnergyCardData(
      netKcal: net,
      bandCopy: bandCopy,
      eatenKcal: consumed.calories.toDouble(),
      burnedKcal: displayedBurned,
      targetKcal: targets.totalCalories,
      remainingKcal: targets.totalCalories - consumed.calories,
      workoutDoneKcal: doneKcal,
      workoutPlannedKcal: plannedKcal,
      workoutProjectedKcal: doneKcal + plannedKcal,
      workoutRows: [
        // Same _sessionKcal result as the card (I4: one number per session
        // across every surface); unpriced sessions are omitted so the rows
        // shown always sum to the totals shown.
        for (final c in priced)
          EnergyWorkoutRow(
            name: c.data.name,
            note: c.data.isDone
                ? '${c.data.timeLabel} · ${c.data.metaLabel}'
                : 'planned · ${c.data.timeLabel} · ${c.data.metaLabel}',
            kcal: c.data.kcal!,
            planned: !c.data.isDone,
            activityId: c.data.activityId,
            sport: c.data.sport,
            verified: c.data.isVerified,
            timeLabel: c.data.timeLabel,
            metaLabel: c.data.metaLabel,
          ),
      ],
      carbTargetG: targets.carbG,
      proteinTargetG: targets.protG,
      fatTargetG: targets.fatG,
      carbEatenG: consumed.carbsG,
      proteinEatenG: consumed.proteinG,
      fatEatenG: consumed.fatG,
    );

    // ---- Breakdown Pager quantities ----

    // Provenance marks for the burn receipt. Resting & digestion are always
    // estimated; the workout row is verified when every done session was
    // device-recorded, self-reported when any mark-done session exists,
    // estimated with nothing done yet; daily movement is verified only when
    // a wearable recorded today (approximated by any Garmin-linked session).
    final doneActs = liveActivities
        .where(
          (a) => a.status == ActivityStatus.completed || a.actualTime != null,
        )
        .toList(growable: false);
    final BurnMark workoutMark;
    if (doneActs.isEmpty) {
      workoutMark = BurnMark.estimated;
    } else if (doneActs.every((a) => a.garminSummaryId != null)) {
      workoutMark = BurnMark.verified;
    } else {
      workoutMark = BurnMark.selfReported;
    }
    final movementMark = liveActivities.any((a) => a.garminSummaryId != null)
        ? BurnMark.verified
        : BurnMark.estimated;

    // Per-meal rows: logged first (chronological), then planned dimmed.
    // Each row carries the meal's own name so it can be matched to the
    // timeline (27-006); the slot's label stands in only for a nameless one.
    final activeMeals = meals.where((m) => !m.isDeleted).toList(growable: false)
      ..sort(
        (a, b) =>
            (a.eatenAt ?? a.createdAt).compareTo(b.eatenAt ?? b.createdAt),
      );
    final mealRows = <BreakdownMealRow>[
      for (final m in activeMeals)
        BreakdownMealRow(
          name: m.name.trim().isNotEmpty ? m.name : (m.slot?.label ?? m.name),
          timeLabel: m.eatenAt == null
              ? '~${_timeLabel(m.createdAt)}'
              : _timeLabel(m.eatenAt!),
          kcal: m.calories?.toDouble() ?? 0,
          carbsG: m.carbsG ?? 0,
          proteinG: m.proteinG ?? 0,
          fatG: m.fatG ?? 0,
          planned: m.eatenAt == null,
        ),
    ]..sort((a, b) => (a.planned ? 1 : 0).compareTo(b.planned ? 1 : 0));

    var plannedC = 0.0, plannedP = 0.0, plannedF = 0.0;
    for (final r in mealRows.where((r) => r.planned)) {
      plannedC += r.carbsG;
      plannedP += r.proteinG;
      plannedF += r.fatG;
    }

    // Weekly carb periodization: this week's cached targets + training load
    // (session kcal normalized against the week's hardest day).
    final weeklyCarbs = [for (final t in weeklyTargets) t?.carbG];
    final weeklyKcal = [for (final t in weeklyTargets) t?.sessionKcal ?? 0.0];
    final maxKcal = weeklyKcal.fold<double>(0, (m, v) => v > m ? v : m);
    final weeklyLoad = [
      for (final v in weeklyKcal) maxKcal > 0 ? v / maxKcal : 0.0,
    ];

    final breakdown = BreakdownData(
      minutesSinceMidnight: minutesSinceMidnight,
      restingSoFar: accrual.resting,
      movementSoFar: accrual.movement,
      workoutSoFar: displayedWorkout,
      digestionSoFar: accrual.digestion,
      restingByEnd: targets.rmr,
      movementByEnd: targets.neatKcal ?? 0,
      workoutByEnd: doneKcal + plannedKcal,
      digestionByEnd: 0.10 * targets.totalCalories,
      workoutMark: workoutMark,
      movementMark: movementMark,
      mealRows: mealRows,
      plannedCarbsG: plannedC,
      plannedProteinG: plannedP,
      plannedFatG: plannedF,
      weeklyCarbTargets: weeklyCarbs,
      weeklyLoad: weeklyLoad,
    );

    return _BuiltEnergy(energy, breakdown);
  }

  /// D-1 card numbers (integrations-data-display.md, RATIFIED 2026-09-11):
  /// a VERIFIED card shows the measured pair (actual_*); every other state
  /// shows the planned pair — never a mixed pair (DI-DEV-1, the live prod
  /// specimen: a verified card rendering planned 8 mi with measured 44 min).
  String _meta(Activity a, {required bool verified}) {
    final double? miles;
    final int? minutes;
    // D-1: one value family per row, `actual ?? planned` AS A PAIR. A
    // platform can report a workout done without measurements (FinalSurge
    // `WorkoutCompleted` alone); that card keeps the planned pair.
    final hasMeasured =
        a.actualDistanceMiles != null || a.actualDurationMinutes != null;
    if (verified && hasMeasured) {
      miles = a.actualDistanceMiles;
      minutes = a.actualDurationMinutes;
    } else {
      miles = a.distanceMiles;
      minutes = a.durationMinutes;
    }
    final parts = <String>[
      if (miles != null) '${_trim(miles)} mi',
      if (minutes != null) '$minutes min',
    ];
    return parts.isEmpty ? a.activityType.name : parts.join(' · ');
  }

  String _trim(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  String _timeLabel(DateTime t) {
    final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    final suffix = t.hour < 12 ? 'AM' : 'PM';
    return '$hour12:$minute $suffix';
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _TimedNode {
  const _TimedNode(this.time, this.node, {this.tieBreak = 0});
  final DateTime time;
  final DashboardNode node;

  /// Orders nodes that share [time]: workouts (-1) before meal cards, meal
  /// cards by their meal type's rank, so a delete elsewhere never reorders
  /// them.
  final int tieBreak;

  /// Sorts [nodes] by time, then [tieBreak], then incoming position. The last
  /// key keeps same-time workouts in the order they arrived (Dart's
  /// [List.sort] is not stable).
  static List<_TimedNode> sorted(List<_TimedNode> nodes) {
    final indexed = nodes.indexed.toList()
      ..sort((a, b) {
        final byTime = a.$2.time.compareTo(b.$2.time);
        if (byTime != 0) return byTime;
        final byTie = a.$2.tieBreak.compareTo(b.$2.tieBreak);
        return byTie != 0 ? byTie : a.$1.compareTo(b.$1);
      });
    return [for (final (_, n) in indexed) n];
  }
}

class _TimedCard {
  const _TimedCard(this.time, this.activity, this.data);
  final DateTime time;
  final WorkoutCardData data;
  final Activity activity;
}

class _BuiltEnergy {
  const _BuiltEnergy(this.energy, this.breakdown);
  final EnergyCardData energy;
  final BreakdownData breakdown;
}
