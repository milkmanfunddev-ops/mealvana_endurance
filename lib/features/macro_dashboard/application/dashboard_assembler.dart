import '../../activities/domain/activity.dart';
import '../../daily_macros/domain/daily_macro_targets.dart';
import '../../daily_macros/domain/intraday_display.dart';
import '../../meal_logging/domain/consumed_totals.dart';
import '../../meal_logging/domain/meal_log.dart';
import '../../nutrition_plan/application/daily_baseline_calculator.dart';
import '../domain/dashboard_models.dart';

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
  }) {
    // §4b: a status='deleted' tombstone never renders and contributes zero
    // to every derived quantity — identical in effect to nonexistence.
    final live = activities
        .where((a) => a.status != ActivityStatus.deleted && a.deletedAt == null)
        .toList(growable: false)
      ..sort((a, b) => a.displayTime.compareTo(b.displayTime));

    final weightKg = targets?.weightKg ?? 70.0;
    final cards = live
        .map((a) => _workoutCard(a, selectedDate, now, weightKg))
        .toList(growable: false);

    final mealNodes = _mealNodes(meals);

    // S-7: a SKIPPED card loses its timeline slot — no timestamp, tucked
    // after every timed card of the day (planned or done); several skipped
    // cards order by planned_time ascending. Unskip / G1 recovery restores
    // the time-ordered slot simply by the card no longer being skipped.
    final timed = <_TimedNode>[
      for (final c in cards)
        if (c.data.counts)
          _TimedNode(
            c.time,
            DashboardNode.workout(timeLabel: c.data.timeLabel, workout: c.data),
          ),
      ...mealNodes,
    ]..sort((a, b) => a.time.compareTo(b.time));
    final tucked = <_TimedNode>[
      for (final c in cards)
        if (c.data.isSkipped)
          _TimedNode(
            c.time,
            DashboardNode.workout(timeLabel: '', workout: c.data),
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
    double weightKg,
  ) {
    // Two-time model: a card is done when the athlete confirmed it or a
    // sync stamped actual_time; verified when a platform stamped it. Sync
    // beats skip (G6): a matching sync writes actual_time + the summary id,
    // so a skipped row that syncs reads as DONE_VERIFIED here regardless of
    // what `status` says.
    final done = a.status == ActivityStatus.completed || a.actualTime != null;
    final verified = done && a.garminSummaryId != null;

    // SKIPPED — two triggers (Q-D6):
    //  ACTIVE  — status = 'skipped', written by the Skip press (allowed on
    //            the current day). Unskip / mark-done clear it.
    //  PASSIVE — the workout's day is past and it has neither sync nor
    //            confirmation. Derived, never written; the CURRENT day never
    //            shows a passive SKIPPED (the rejected same-day-22:00
    //            trigger must not exist — Q-D5).
    final skipActive = !done && a.status == ActivityStatus.skipped;
    final selectedDay =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final today = DateTime(now.year, now.month, now.day);
    final dayPast = selectedDay.isBefore(today);
    final dayFuture = selectedDay.isAfter(today);
    final skipPassive = !done && !skipActive && dayPast;

    final state = verified
        ? WorkoutCardState.doneVerified
        : done
            ? WorkoutCardState.doneConfirmed
            : (skipActive || skipPassive)
                ? WorkoutCardState.skipped
                : WorkoutCardState.planned;

    // A skipped card has no displayed time (S-7); its sort key for the tucked
    // group is planned_time. Everything else displays actual ?? planned.
    final displayTime = state == WorkoutCardState.skipped
        ? (a.plannedTime ?? a.scheduledDateTime)
        : a.displayTime;

    return _TimedCard(
      displayTime,
      WorkoutCardData(
        activityId: a.id,
        name: a.title,
        timeLabel: _timeLabel(displayTime),
        metaLabel: _meta(a),
        kcal: _sessionKcal(a, weightKg),
        state: state,
        sport: a.activityType.name,
        skipActive: skipActive,
        // A future day's workout hasn't happened: no mark-done (ruled
        // 2026-08-18). Mark-UNDONE on a (legacy) confirmed future card stays
        // available so it can be corrected.
        markDoneAllowed: !dayFuture,
      ),
    );
  }

  /// F22 kcal ladder: measured (Garmin ActiveKilocalories, mirrored into
  /// calories_burned) beats the formula; the formula rung is F4 at the
  /// session's IF and duration.
  double _sessionKcal(Activity a, double weightKg) {
    final measured = a.caloriesBurned;
    if (measured != null && measured > 0) return measured;
    final durationHr =
        (a.actualDurationMinutes ?? a.durationMinutes ?? 60) / 60.0;
    final dist = a.intensityDistribution;
    final intensityFactor = dist != null
        ? DailyBaselineCalculator.zoneDistributionToIf(
            pctConversational: dist.conversationalPct / 100,
            pctTempo: dist.tempoPct / 100,
            pctAllout: dist.allOutPct / 100,
          )
        : 0.74; // representative endurance IF when zones are absent
    return DailyBaselineCalculator.sessionCost(
      sport: a.activityType.name,
      durationHr: durationHr,
      intensityFactor: intensityFactor,
      weightKg: weightKg,
    );
  }

  List<_TimedNode> _mealNodes(List<MealLog> meals) {
    final active = meals.where((m) => !m.isDeleted);
    final groups = <String, List<MealLog>>{};
    for (final m in active) {
      groups.putIfAbsent(m.slot?.label ?? 'Logged', () => []).add(m);
    }
    final nodes = <_TimedNode>[];
    groups.forEach((slot, entries) {
      entries.sort(
        (a, b) => (a.eatenAt ?? a.createdAt).compareTo(b.eatenAt ?? b.createdAt),
      );
      final time = entries.first.eatenAt ?? entries.first.createdAt;
      nodes.add(
        _TimedNode(
          time,
          DashboardNode.meals(
            timeLabel: _timeLabel(time),
            mealGroupLabel: slot,
            meals: [
              for (final m in entries)
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
        ),
      );
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
    final isToday = _sameDay(selectedDate, now);
    final minutesSinceMidnight =
        isToday ? now.hour * 60 + now.minute : 1440;

    // S-2 (skip scope): a SKIPPED workout's kcal and fuel leave EVERY
    // surface figure — net balance, band copy, Active Energy sheet,
    // by-end-of-day burn — in the same frame; passive and active alike.
    final counted = cards.where((c) => c.data.counts).toList(growable: false);

    final sessions = [
      for (final c in counted)
        IntradaySession(
          kcal: c.data.kcal,
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
    final displayedBurned = accrual.resting.floorToDouble() +
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
    for (final c in counted) {
      if (c.data.isDone) {
        doneKcal += c.data.kcal.roundToDouble();
      } else {
        plannedKcal += c.data.kcal.roundToDouble();
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
        for (final c in counted)
          EnergyWorkoutRow(
            name: c.data.name,
            note: c.data.isDone
                ? '${c.data.timeLabel} · ${c.data.metaLabel}'
                : 'planned · ${c.data.timeLabel} · ${c.data.metaLabel}',
            kcal: c.data.kcal,
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
          (a) =>
              a.status == ActivityStatus.completed || a.actualTime != null,
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
    final activeMeals = meals.where((m) => !m.isDeleted).toList(growable: false)
      ..sort(
        (a, b) =>
            (a.eatenAt ?? a.createdAt).compareTo(b.eatenAt ?? b.createdAt),
      );
    final mealRows = <BreakdownMealRow>[
      for (final m in activeMeals)
        BreakdownMealRow(
          name: m.slot?.label ?? m.name,
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
    final weeklyCarbs = [
      for (final t in weeklyTargets) t?.carbG,
    ];
    final weeklyKcal = [
      for (final t in weeklyTargets) t?.sessionKcal ?? 0.0,
    ];
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

  String _meta(Activity a) {
    final minutes = a.actualDurationMinutes ?? a.durationMinutes;
    final parts = <String>[
      if (a.distanceMiles != null) '${_trim(a.distanceMiles!)} mi',
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
  const _TimedNode(this.time, this.node);
  final DateTime time;
  final DashboardNode node;
}

class _TimedCard {
  const _TimedCard(this.time, this.data);
  final DateTime time;
  final WorkoutCardData data;
}

class _BuiltEnergy {
  const _BuiltEnergy(this.energy, this.breakdown);
  final EnergyCardData energy;
  final BreakdownData breakdown;
}
