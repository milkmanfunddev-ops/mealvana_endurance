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
  });

  final List<DashboardNode> nodes;

  /// Null when no targets exist yet for the day.
  final EnergyCardData? energy;
  final bool trackingOn;
}

/// Pure builder for the macro dashboard (surfaces/macro-dashboard.md).
///
/// Every quantity maps to a documented spec field (S-3): so-far arithmetic
/// comes from [IntradayDisplay] (intraday-display.md §§1–3), session energy
/// from the F22 ladder's formula rung (measured Garmin kcal is not yet
/// mirrored into the local row — follow-up), and card states from the
/// two-time model + tombstone rulings (platform-resolution.md).
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

    final workoutNodes = <DashboardNode>[
      for (final c in cards)
        DashboardNode.workout(timeLabel: c.data.timeLabel, workout: c.data),
    ];

    final mealNodes = _mealNodes(meals);

    final nodes = <_TimedNode>[
      for (var i = 0; i < cards.length; i++)
        _TimedNode(cards[i].time, workoutNodes[i]),
      ...mealNodes,
    ]..sort((a, b) => a.time.compareTo(b.time));

    final energy = targets == null
        ? null
        : _energy(targets, consumed, cards, selectedDate, now);

    return DashboardData(
      nodes: nodes.map((n) => n.node).toList(growable: false),
      energy: energy,
      trackingOn: trackingOn,
    );
  }

  _TimedCard _workoutCard(
    Activity a,
    DateTime selectedDate,
    DateTime now,
    double weightKg,
  ) {
    final displayTime = a.displayTime;
    final done = a.status == ActivityStatus.completed || a.actualTime != null;
    final verified = done && a.garminSummaryId != null;

    // End-of-day skipped prompt: still planned with neither sync nor
    // confirmation once the day is effectively over ([design]: a past day,
    // or after 22:00 on the day itself).
    final dayOver =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day)
                .isBefore(DateTime(now.year, now.month, now.day)) ||
            (now.hour >= 22 && _sameDay(selectedDate, now));

    final state = verified
        ? WorkoutCardState.doneVerified
        : done
            ? WorkoutCardState.doneConfirmed
            : dayOver
                ? WorkoutCardState.skippedPrompt
                : WorkoutCardState.planned;

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
                ),
            ],
          ),
        ),
      );
    });
    return nodes;
  }

  EnergyCardData _energy(
    DailyMacroTargets targets,
    ConsumedTotals consumed,
    List<_TimedCard> cards,
    DateTime selectedDate,
    DateTime now,
  ) {
    final isToday = _sameDay(selectedDate, now);
    final minutesSinceMidnight =
        isToday ? now.hour * 60 + now.minute : 1440;

    final sessions = [
      for (final c in cards)
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
    for (final c in cards) {
      if (c.data.isDone) {
        doneKcal += c.data.kcal.roundToDouble();
      } else {
        plannedKcal += c.data.kcal.roundToDouble();
      }
    }

    return EnergyCardData(
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
        for (final c in cards)
          EnergyWorkoutRow(
            name: c.data.name,
            note: c.data.isDone
                ? '${c.data.timeLabel} · ${c.data.metaLabel}'
                : 'planned · ${c.data.timeLabel} · ${c.data.metaLabel}',
            kcal: c.data.kcal,
            planned: !c.data.isDone,
          ),
      ],
      carbTargetG: targets.carbG,
      proteinTargetG: targets.protG,
      fatTargetG: targets.fatG,
      carbEatenG: consumed.carbsG,
      proteinEatenG: consumed.proteinG,
      fatEatenG: consumed.fatG,
    );
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
