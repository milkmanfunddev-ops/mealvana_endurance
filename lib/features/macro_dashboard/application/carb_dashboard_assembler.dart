import '../../../shared/database/app_database.dart';
import '../../carb_loading/domain/carb_loading_pace_engine.dart';
import '../../carb_loading/domain/meal_type.dart';
import '../../meal_logging/domain/meal_log.dart';
import '../../meal_logging/domain/meal_slot.dart';
import '../domain/carb_dashboard_models.dart';
import '../domain/dashboard_models.dart' show kcalStr;

/// Pure builder for the loading-day dashboard surfaces
/// (surfaces/carb-loading-dashboard.md).
///
/// Numbers: [CarbLoadingPaceEngine] against the STORED day target and the
/// day-row's STORED split fractions (CL-4a — never re-derived from the
/// protocol when edited). Eaten = ALL of the day's eaten food-log rows,
/// slot-tagged or not (CL-11/Q-CL8); slot cards sum only their tagged rows —
/// the divergence is BY DESIGN. The writer-less `logged_carbs_grams` /
/// `completed` columns are deliberately NEVER read (D-020).
class CarbDashboardAssembler {
  const CarbDashboardAssembler();

  /// CL-5 grid clock labels, slot order.
  static const List<String> slotClockLabels = <String>[
    '6:00 AM',
    '9:00 AM',
    '12:00 PM',
    '3:00 PM',
    '6:00 PM',
    '9:00 PM',
  ];

  /// The six slots, CL-5 order (no Recovery group on loading days).
  static const List<MealType> slotOrder = <MealType>[
    MealType.breakfast,
    MealType.morningSnack,
    MealType.lunch,
    MealType.afternoonSnack,
    MealType.dinner,
    MealType.eveningSnack,
  ];

  /// Which meal-log slot tags feed each card. Legacy `snack` folds into
  /// Afternoon Snack (the ruled taxonomy fold — display-time, no migration).
  static const Map<MealType, List<MealSlot>> slotSources =
      <MealType, List<MealSlot>>{
        MealType.breakfast: [MealSlot.breakfast],
        MealType.morningSnack: [MealSlot.morningSnack],
        MealType.lunch: [MealSlot.lunch],
        MealType.afternoonSnack: [MealSlot.afternoonSnack, MealSlot.snack],
        MealType.dinner: [MealSlot.dinner],
        MealType.eveningSnack: [MealSlot.eveningSnack],
      };

  /// Builds the loading-day surface data, or null when [day] is null —
  /// CD-1's negative: a regular day has NO carb surface anywhere.
  CarbDashboardData? assemble({
    required CarbLoadingDay? day,
    required int totalDays,
    required List<CarbLoadingDay> planDays,
    required List<MealLog> meals,
    required DateTime selectedDate,
    required DateTime now,
    String? eventId,
  }) {
    if (day == null) return null;

    final selected = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final today = DateTime(now.year, now.month, now.day);
    final dayRel = selected.isAfter(today)
        ? CarbDayRel.future
        : selected.isBefore(today)
        ? CarbDayRel.past
        : CarbDayRel.today;

    // CL-11: eaten = every eaten log of the day, tagged or not.
    final eatenLogs = meals
        .where((m) => !m.isDeleted && m.eatenAt != null)
        .toList(growable: false);
    final eatenCarbsG = eatenLogs.fold<double>(
      0,
      (sum, m) => sum + (m.carbsG ?? 0),
    );

    final target = day.carbTargetGrams;
    final tMin = now.hour * 60 + now.minute;
    final pace = CarbLoadingPaceEngine.evaluate(
      dayTargetG: target,
      eatenG: eatenCarbsG,
      tMin: tMin,
      dayRel: dayRel,
    );

    // CL-4 against the STORED split fractions (D-021-fixed defaults).
    final splits = <double>[
      day.breakfastPercent,
      day.morningSnackPercent,
      day.lunchPercent,
      day.afternoonSnackPercent,
      day.dinnerPercent,
      day.eveningSnackPercent,
    ];
    final slotTargets = splits
        .map((s) => (s * target).round())
        .toList(growable: false);

    final slots = <CarbSlotCardData>[];
    for (var i = 0; i < slotOrder.length; i++) {
      final slot = slotOrder[i];
      final sources = slotSources[slot]!;
      final slotLogs = eatenLogs
          .where((m) => m.slot != null && sources.contains(m.slot))
          .toList(growable: false);
      final eatenG = slotLogs
          .fold<double>(0, (sum, m) => sum + (m.carbsG ?? 0))
          .round();
      slots.add(
        CarbSlotCardData(
          slot: slot,
          label: slot.displayName,
          clockStr: slotClockLabels[i],
          eatenG: eatenG,
          targetG: slotTargets[i],
          items: [
            for (final m in slotLogs)
              CarbSlotItemData(
                id: m.id,
                name: m.name,
                gramsStr: '${(m.carbsG ?? 0).round()} g',
              ),
          ],
          summaryLine: _summaryLine(slotLogs),
          dayRel: dayRel,
        ),
      );
    }

    final face = _face(
      pace: pace,
      target: target,
      eatenCarbsG: eatenCarbsG,
      dayNumber: day.dayNumber,
      totalDays: totalDays,
      dayRel: dayRel,
    );

    final breakdown = _breakdown(
      face: face,
      day: day,
      planDays: planDays,
      slots: slots,
      eatenLogs: eatenLogs,
      eatenCarbsG: eatenCarbsG,
      target: target,
      dayRel: dayRel,
      tMin: tMin,
      totalDays: totalDays,
    );

    return CarbDashboardData(
      face: face,
      slots: slots,
      breakdown: breakdown,
      dayRel: dayRel,
      eventId: eventId,
    );
  }

  // §2a copy register v1 — verbatim strings only.
  CarbLoadFaceData _face({
    required CarbPaceResult pace,
    required int target,
    required double eatenCarbsG,
    required int dayNumber,
    required int totalDays,
    required CarbDayRel dayRel,
  }) {
    final eaten = eatenCarbsG.round();
    final String main;
    final String sub;
    var isWord = false;

    switch (dayRel) {
      case CarbDayRel.future:
        main = '$target g';
        sub = 'planned';
      case CarbDayRel.past:
        main = '$eaten g';
        sub = 'of $target g';
      case CarbDayRel.today:
        if (pace.loaded) {
          main = 'Loaded';
          sub = '$eaten of $target g';
          isWord = true;
        } else if (pace.paceState == CarbPaceState.behind) {
          main = '${pace.paceN} g';
          sub = 'behind pace';
        } else if (pace.paceState == CarbPaceState.ahead) {
          main = '${pace.paceN} g';
          sub = 'ahead of pace';
        } else {
          main = 'On pace';
          sub = '$eaten of $target g';
          isWord = true;
        }
    }

    final label =
        '${pace.loaded && dayRel == CarbDayRel.today ? 'LOADED' : 'CARB LOAD'}'
        ' · DAY $dayNumber OF $totalDays';
    final toGo = (target - eaten) < 0 ? 0 : target - eaten;
    final owed = pace.owedG;

    return CarbLoadFaceData(
      labelLine: label,
      paceMainStr: main,
      paceSubStr: sub,
      paceMainIsWord: isWord,
      fillFrac: pace.fillFrac,
      tickFrac: pace.tickHidden ? null : pace.tickFrac,
      tickHidden: pace.tickHidden,
      loaded: pace.loaded,
      dayRel: dayRel,
      eatenOfTargetStr: '$eaten of $target g',
      toGoStr: '$toGo g to go',
      paceByNowStr: owed == null || owed <= 0 || pace.loaded
          ? null
          : 'pace ${owed.round()} g by now',
    );
  }

  CarbBreakdownData _breakdown({
    required CarbLoadFaceData face,
    required CarbLoadingDay day,
    required List<CarbLoadingDay> planDays,
    required List<CarbSlotCardData> slots,
    required List<MealLog> eatenLogs,
    required double eatenCarbsG,
    required int target,
    required CarbDayRel dayRel,
    required int tMin,
    required int totalDays,
  }) {
    final proteinG = eatenLogs.fold<double>(0, (s, m) => s + (m.proteinG ?? 0));
    final fatG = eatenLogs.fold<double>(0, (s, m) => s + (m.fatG ?? 0));
    final kcal = eatenLogs.fold<double>(
      0,
      (s, m) => s + (m.calories?.toDouble() ?? 0),
    );

    final mealRows = <CarbBreakdownMealRow>[];
    for (var i = 0; i < slots.length; i++) {
      final s = slots[i];
      final windowStart = CarbLoadingPaceEngine.slotTimesMin[i];
      final windowEnd = i + 1 < CarbLoadingPaceEngine.slotTimesMin.length
          ? CarbLoadingPaceEngine.slotTimesMin[i + 1]
          : CarbLoadingPaceEngine.closeMin + 120;
      mealRows.add(
        CarbBreakdownMealRow(
          label: s.label,
          clockStr: s.clockStr,
          eatenG: s.eatenG,
          targetG: s.targetG,
          fillFrac: s.targetG <= 0
              ? 0
              : (s.eatenG / s.targetG).clamp(0.0, 1.0).toDouble(),
          isCurrentWindow:
              dayRel == CarbDayRel.today &&
              tMin >= windowStart &&
              tMin < windowEnd,
        ),
      );
    }

    final sorted = List<CarbLoadingDay>.of(planDays)
      ..sort((a, b) => a.planDate.compareTo(b.planDate));
    final chips = <CarbBreakdownDayChip>[
      for (final d in sorted)
        CarbBreakdownDayChip(
          label: 'Day ${d.dayNumber}',
          targetStr: '${d.carbTargetGrams} g',
          date: d.planDate,
          isViewed: d.id == day.id,
        ),
    ];

    return CarbBreakdownData(
      titleLine: 'Carb Load · Day ${day.dayNumber} of $totalDays',
      face: face,
      eatenOfTargetStr: '${eatenCarbsG.round()} of $target g carbs',
      carbsStr: '${eatenCarbsG.round()}g',
      proteinStr: '${proteinG.round()}g',
      fatStr: '${fatG.round()}g',
      kcalStr: kcalStr(kcal),
      mealRows: mealRows,
      dayChips: chips,
    );
  }

  /// Summary-line register (carb-slot-card.md): 1 → `<Name>` ·
  /// 2 → `<A> + <B>` · ≥3 → `<First> +N more`.
  String _summaryLine(List<MealLog> logs) {
    if (logs.isEmpty) return '';
    if (logs.length == 1) return logs.first.name;
    if (logs.length == 2) return '${logs[0].name} + ${logs[1].name}';
    return '${logs.first.name} +${logs.length - 1} more';
  }
}
