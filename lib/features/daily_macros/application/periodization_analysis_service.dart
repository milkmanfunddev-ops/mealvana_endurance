import '../domain/daily_macro_targets.dart';

/// Pure business logic service that analyzes a 7-day macro week
/// and generates dynamic periodization insight text for the bottom sheet.
///
/// No async, no dependencies — operates entirely on [DailyMacroTargets] data.
class PeriodizationAnalysisService {
  const PeriodizationAnalysisService();

  static const _dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  /// Analyze a Sunday-start week and return structured insight groups
  /// plus a protein summary. Returns null if insufficient data.
  PeriodizationAnalysis? analyze(List<DailyMacroTargets?> weeklyMacros) {
    final nonNull = weeklyMacros.where((m) => m != null).toList();
    if (nonNull.length < 3) return null;

    // Step 1: Classify each day
    final classified = <int, _ClassifiedDay>{};
    for (int i = 0; i < 7; i++) {
      final m = weeklyMacros[i];
      if (m == null) continue;
      classified[i] = _classifyDay(m, weeklyMacros);
    }

    // Step 2: Group consecutive days with same pattern
    final groups = _groupConsecutive(classified, weeklyMacros);

    // Step 3: Detect carb trajectory in multi-day groups
    _detectTrajectories(groups, weeklyMacros);

    // Step 4: Generate text for each group
    final insights = groups
        .map((g) => _generateInsight(g, weeklyMacros))
        .toList();

    // Step 5: Protein summary
    final protValues = nonNull.map((m) => m!.protG).toList()..sort();
    final protMin = protValues.first.round();
    final protMax = protValues.last.round();
    final proteinSummary = (protMax - protMin) < 20
        ? 'Protein stays steady (~$protMin-${protMax}g) throughout the week to maintain muscle synthesis regardless of training intensity.'
        : 'Protein ranges from ${protMin}g on rest days to ${protMax}g on hard training days, tracking your recovery needs.';

    return PeriodizationAnalysis(
      insights: insights,
      proteinSummary: proteinSummary,
    );
  }

  _ClassifiedDay _classifyDay(
    DailyMacroTargets m,
    List<DailyMacroTargets?> week,
  ) {
    // Training context
    final TrainingContext context;
    if (m.mode == 'race_week') {
      context = TrainingContext.raceWeek;
    } else if (m.sessionKcal > 600) {
      context = TrainingContext.hard;
    } else if (m.sessionKcal > 300) {
      context = TrainingContext.moderate;
    } else if (m.sessionKcal > 0) {
      context = TrainingContext.easy;
    } else {
      context = TrainingContext.rest;
    }

    // Carb level relative to the week
    final carbValues =
        week.where((d) => d != null).map((d) => d!.carbG).toList()..sort();
    final min = carbValues.first;
    final max = carbValues.last;
    final median = carbValues[carbValues.length ~/ 2];
    final range = max - min;

    final CarbLevel carbLevel;
    if (range < 10) {
      carbLevel = CarbLevel.moderate; // Flat week — everything moderate
    } else if (m.carbG >= median + 0.2 * range) {
      carbLevel = CarbLevel.high;
    } else if (m.carbG <= median - 0.2 * range) {
      carbLevel = CarbLevel.low;
    } else {
      carbLevel = CarbLevel.moderate;
    }

    return _ClassifiedDay(context: context, carbLevel: carbLevel);
  }

  List<_DayGroup> _groupConsecutive(
    Map<int, _ClassifiedDay> classified,
    List<DailyMacroTargets?> week,
  ) {
    final groups = <_DayGroup>[];
    _DayGroup? current;

    for (int i = 0; i < 7; i++) {
      final day = classified[i];
      if (day == null) {
        current = null;
        continue;
      }

      if (current != null &&
          current.context == day.context &&
          current.carbLevel == day.carbLevel &&
          current.endIndex == i - 1) {
        current.endIndex = i;
      } else {
        current = _DayGroup(
          startIndex: i,
          endIndex: i,
          context: day.context,
          carbLevel: day.carbLevel,
        );
        groups.add(current);
      }
    }
    return groups;
  }

  void _detectTrajectories(
    List<_DayGroup> groups,
    List<DailyMacroTargets?> week,
  ) {
    for (final group in groups) {
      final span = group.endIndex - group.startIndex + 1;
      if (span < 3) continue;

      // Check if carbs trend upward day-over-day
      bool trending = true;
      double? prev;
      for (int i = group.startIndex; i <= group.endIndex; i++) {
        final m = week[i];
        if (m == null) {
          trending = false;
          break;
        }
        if (prev != null && m.carbG <= prev) {
          trending = false;
          break;
        }
        prev = m.carbG;
      }
      if (trending) {
        group.hasCarbTrajectoryUp = true;
      }
    }
  }

  PeriodizationInsight _generateInsight(
    _DayGroup group,
    List<DailyMacroTargets?> week,
  ) {
    // Collect macro data for this group
    final carbs = <double>[];
    final prots = <double>[];
    for (int i = group.startIndex; i <= group.endIndex; i++) {
      final m = week[i];
      if (m != null) {
        carbs.add(m.carbG);
        prots.add(m.protG);
      }
    }
    final carbMin = carbs.reduce((a, b) => a < b ? a : b).round();
    final carbMax = carbs.reduce((a, b) => a > b ? a : b).round();
    final avgProt = (prots.reduce((a, b) => a + b) / prots.length).round();

    // Day range label
    final dayLabel = group.startIndex == group.endIndex
        ? _dayNames[group.startIndex]
        : '${_dayNames[group.startIndex]}-${_dayNames[group.endIndex]}';

    final carbRange = carbMin == carbMax
        ? '${carbMin}g'
        : '$carbMin-${carbMax}g';

    // Pattern match for category label + explanation
    String categoryLabel;
    String explanation;
    InsightTier tier;

    if (group.context == TrainingContext.raceWeek) {
      categoryLabel = 'Race week fueling';
      explanation =
          'Taper nutrition with elevated carbs at $carbRange for glycogen super-compensation ahead of race day.';
      tier = InsightTier.high;
    } else if (group.hasCarbTrajectoryUp) {
      categoryLabel = 'Build phase';
      explanation =
          'As weekly volume accumulates, carbs gradually rebuild to $carbRange to keep energy available for back-to-back training days.';
      tier = InsightTier.moderate;
    } else if (group.context == TrainingContext.hard &&
        group.carbLevel == CarbLevel.high) {
      categoryLabel = 'High carb';
      explanation =
          'Intense sessions require fast-burning fuel. Carbs are increased to $carbRange to maximize glycogen stores before hard efforts.';
      tier = InsightTier.high;
    } else if (group.context == TrainingContext.moderate &&
        (group.carbLevel == CarbLevel.high ||
            group.carbLevel == CarbLevel.moderate)) {
      categoryLabel = 'Training fuel';
      explanation =
          'Steady training sessions call for sustained fueling. Carbs at $carbRange to meet energy demand and support quality work.';
      tier = InsightTier.moderate;
    } else if ((group.context == TrainingContext.easy ||
            group.context == TrainingContext.rest) &&
        group.carbLevel == CarbLevel.low) {
      categoryLabel = group.context == TrainingContext.rest
          ? 'Rest day'
          : 'Recovery + lower carbs';
      explanation = group.context == TrainingContext.rest
          ? 'No training scheduled. Carbs at $carbRange \u2014 protein remains elevated at ${avgProt}g for ongoing muscle recovery.'
          : 'Lighter load means lower energy demand. Carbs drop to $carbRange and protein stays elevated at ${avgProt}g to support muscle repair.';
      tier = InsightTier.low;
    } else {
      // Generic fallback
      categoryLabel = _contextLabel(group.context);
      explanation =
          'Carbs at $carbRange with protein at ${avgProt}g, adjusted for your ${_contextLabel(group.context).toLowerCase()} schedule.';
      tier = group.carbLevel == CarbLevel.high
          ? InsightTier.high
          : group.carbLevel == CarbLevel.low
          ? InsightTier.low
          : InsightTier.moderate;
    }

    return PeriodizationInsight(
      dayLabel: dayLabel,
      categoryLabel: categoryLabel,
      explanation: explanation,
      tier: tier,
    );
  }

  String _contextLabel(TrainingContext context) {
    switch (context) {
      case TrainingContext.hard:
        return 'Hard training';
      case TrainingContext.moderate:
        return 'Moderate training';
      case TrainingContext.easy:
        return 'Easy training';
      case TrainingContext.rest:
        return 'Rest';
      case TrainingContext.raceWeek:
        return 'Race week';
    }
  }
}

// ── Internal classification types ──

enum TrainingContext { hard, moderate, easy, rest, raceWeek }

enum CarbLevel { high, moderate, low }

class _ClassifiedDay {
  final TrainingContext context;
  final CarbLevel carbLevel;
  const _ClassifiedDay({required this.context, required this.carbLevel});
}

class _DayGroup {
  final int startIndex;
  int endIndex;
  final TrainingContext context;
  final CarbLevel carbLevel;
  bool hasCarbTrajectoryUp = false;

  _DayGroup({
    required this.startIndex,
    required this.endIndex,
    required this.context,
    required this.carbLevel,
  });
}

// ── Public result types ──

enum InsightTier { high, moderate, low }

class PeriodizationInsight {
  final String dayLabel;
  final String categoryLabel;
  final String explanation;
  final InsightTier tier;

  const PeriodizationInsight({
    required this.dayLabel,
    required this.categoryLabel,
    required this.explanation,
    required this.tier,
  });
}

class PeriodizationAnalysis {
  final List<PeriodizationInsight> insights;
  final String proteinSummary;

  const PeriodizationAnalysis({
    required this.insights,
    required this.proteinSummary,
  });
}
