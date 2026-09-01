import '../domain/nutrition_plan.dart';

/// Result of evaluating a nutrition plan for under-fueling risk.
class FuelRiskStatus {
  const FuelRiskStatus({
    required this.isLowFuel,
    required this.actualCarbs,
    required this.targetCarbs,
    this.lowestSection,
  });

  /// Whether the plan is at low-fuel risk (overall or in any single section).
  final bool isLowFuel;

  /// Total planned carbs across all sections (grams).
  final int actualCarbs;

  /// Total carb target across all sections (grams).
  final int targetCarbs;

  /// User-friendly name of the worst-fueled section, only set when
  /// [isLowFuel] is true (e.g. 'before', 'during', 'after').
  final String? lowestSection;
}

/// Pure evaluation of under-fueling risk for a nutrition plan.
///
/// Lives in the application layer so the computation is testable and shared;
/// presentation (LowFuelRiskBadge) only renders the result. Because it is a
/// pure function of the plan, it recomputes automatically whenever the
/// controller publishes an edited plan (manual food edits included).
class FuelRiskService {
  const FuelRiskService._();

  /// Default threshold ratio below which warning fires (0.67 = 33% below).
  static const double defaultThreshold = 0.67;

  /// Evaluate [plan] for under-fueling.
  ///
  /// Fires when overall planned carbs fall below [threshold] of the overall
  /// target, OR when any individual section with a carb target falls below
  /// [threshold] of its own target (bug 3b1e3fdb: emptying the BEFORE window
  /// to 0 g must warn even when during/after remain fully fueled).
  static FuelRiskStatus evaluate(
    NutritionPlan plan, {
    double threshold = defaultThreshold,
  }) {
    int totalActualCarbs = 0;
    int totalTargetCarbs = 0;
    String? lowestSection;
    double lowestRatio = double.infinity;
    bool anySectionLow = false;

    for (final section in plan.sections) {
      // Actual carbs: V2 template plans store foods in subPhases, not
      // directly in section.foodItems.
      int sectionActualCarbs = 0;
      if (section.hasSubPhases) {
        for (final subPhase in section.subPhases!) {
          for (final food in subPhase.foodItems) {
            sectionActualCarbs += food.nutritionalInfo?.carbs ?? 0;
          }
        }
      } else {
        for (final food in section.foodItems) {
          sectionActualCarbs += food.nutritionalInfo?.carbs ?? 0;
        }
      }

      // Target carbs: V2 before sections carry no section-level target —
      // the targets live on the sub-phases, so fall back to their sum
      // (bug 3b1e3fdb: a null section target made BEFORE invisible here).
      double? sectionTarget = section.carbsTarget;
      if (sectionTarget == null && section.hasSubPhases) {
        double subPhaseTargetSum = 0;
        bool hasAnyTarget = false;
        for (final subPhase in section.subPhases!) {
          if (subPhase.carbsTarget != null) {
            hasAnyTarget = true;
            subPhaseTargetSum += subPhase.carbsTarget!;
          }
        }
        if (hasAnyTarget) sectionTarget = subPhaseTargetSum;
      }
      final sectionTargetCarbs = sectionTarget?.round() ?? 0;

      totalActualCarbs += sectionActualCarbs;
      totalTargetCarbs += sectionTargetCarbs;

      if (sectionTargetCarbs > 0) {
        final ratio = sectionActualCarbs / sectionTargetCarbs;
        if (ratio < threshold) anySectionLow = true;
        if (ratio < lowestRatio) {
          lowestRatio = ratio;
          lowestSection = _sectionName(section.id);
        }
      }
    }

    final overallLow =
        totalTargetCarbs > 0 &&
        (totalActualCarbs / totalTargetCarbs) < threshold;
    final isLowFuel = overallLow || anySectionLow;

    return FuelRiskStatus(
      isLowFuel: isLowFuel,
      actualCarbs: totalActualCarbs,
      targetCarbs: totalTargetCarbs,
      lowestSection: isLowFuel ? lowestSection : null,
    );
  }

  /// Get user-friendly section name from section ID.
  static String _sectionName(String sectionId) {
    if (sectionId.contains('before')) return 'before';
    if (sectionId.contains('during')) return 'during';
    if (sectionId.contains('after')) return 'after';
    return sectionId;
  }
}
