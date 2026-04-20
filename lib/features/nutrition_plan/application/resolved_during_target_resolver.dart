import '../../../shared/domain/activity_type.dart';
import '../domain/macro_targets.dart';
import '../domain/nutrition_target_overrides.dart';
import '../domain/resolved_during_target.dart';

class ResolvedDuringTargetResolver {
  const ResolvedDuringTargetResolver._();

  static const double defaultToleranceGPerH = 0.5;

  static ResolvedDuringTarget resolveForSingleSport({
    required MacroTargets macroTargets,
    required ActivityType sport,
    NutritionTargetOverrides? settingsOverrides,
    double toleranceGPerH = defaultToleranceGPerH,
  }) {
    final during = macroTargets.duringRun;
    final settingsRate = settingsOverrides?.getDuring(sport)?.carbRateGPerH;
    final isEligible = macroTargets.metrics.durationMin >= 90;

    final isOverrideApplied = settingsRate != null &&
        settingsRate > 0 &&
        isEligible &&
        (during.carbRateGPerH - settingsRate).abs() <= toleranceGPerH;
    final isStaleVsSettings = settingsRate != null &&
        settingsRate > 0 &&
        isEligible &&
        !isOverrideApplied;

    return ResolvedDuringTarget(
      sport: sport,
      rateGPerH: during.carbRateGPerH,
      totalG: during.carbTotalG,
      rangeLowG: during.carbsLowG,
      rangeHighG: during.carbsHighG,
      source: isOverrideApplied
          ? ResolvedDuringTargetSource.snapshotOverrideApplied
          : ResolvedDuringTargetSource.snapshot,
      isOverrideApplied: isOverrideApplied,
      isStaleVsSettings: isStaleVsSettings,
      settingsOverrideRateGPerH: settingsRate,
    );
  }

  static ResolvedDuringTarget resolveForBrickSegment({
    required MacroTargets macroTargets,
    required BrickSegmentMacroTarget segment,
    NutritionTargetOverrides? settingsOverrides,
    double toleranceGPerH = defaultToleranceGPerH,
  }) {
    final sport = _sportFromSegment(segment.sport);
    final settingsRate = settingsOverrides?.getDuring(sport)?.carbRateGPerH;
    final isEligible = macroTargets.metrics.durationMin >= 90;

    final segmentDurationH = segment.durationMinutes > 0
        ? segment.durationMinutes / 60.0
        : 0.0;
    final snapshotRate = segment.carbsRateGPerH ??
        (segmentDurationH > 0 ? segment.carbsG / segmentDurationH : 0.0);

    final isOverrideApplied = settingsRate != null &&
        settingsRate > 0 &&
        isEligible &&
        (snapshotRate - settingsRate).abs() <= toleranceGPerH;
    final isStaleVsSettings = settingsRate != null &&
        settingsRate > 0 &&
        isEligible &&
        !isOverrideApplied;

    return ResolvedDuringTarget(
      sport: sport,
      rateGPerH: snapshotRate,
      totalG: segment.carbsG,
      rangeLowG: segment.carbsLowG,
      rangeHighG: segment.carbsHighG,
      source: isOverrideApplied
          ? ResolvedDuringTargetSource.snapshotOverrideApplied
          : ResolvedDuringTargetSource.snapshot,
      isOverrideApplied: isOverrideApplied,
      isStaleVsSettings: isStaleVsSettings,
      settingsOverrideRateGPerH: settingsRate,
    );
  }

  static ActivityType _sportFromSegment(String sport) {
    final normalized = sport.toLowerCase();
    if (normalized.contains('run')) return ActivityType.running;
    if (normalized.contains('cycl') || normalized.contains('bike')) {
      return ActivityType.cycling;
    }
    if (normalized.contains('swim')) return ActivityType.swimming;
    return ActivityType.running;
  }
}
