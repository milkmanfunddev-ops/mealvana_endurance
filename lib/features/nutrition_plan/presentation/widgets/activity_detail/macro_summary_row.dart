import 'package:flutter/material.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../domain/food_item_data.dart';
import '../../../domain/macro_targets.dart';
import '../../../domain/nutrition_plan.dart';
import '../../utils/activity_detail_helpers.dart';
import 'macro_range_indicator.dart';

// Retained ONLY for the DURING / AFTER summary rows (this widget is no longer
// composed by the BEFORE surface — `pre_workout_before_card.dart` renders the
// ratified fuel-stat family, whole oz / whole g per R-01 / M-5). The 25-ml /
// 5-g grid below is the digest-§5 rule the old BEFORE row used; it stays here
// privately so the untouched DURING / AFTER surfaces do not change (S-G1).
double round25(double ml) => (ml / 25).round() * 25.0;
double floor25(double ml) => (ml / 25).floorToDouble() * 25.0;
double ceil25(double ml) => (ml / 25).ceilToDouble() * 25.0;
double round5(double grams) => (grams / 5).round() * 5.0;
({double low, double high})? roundCarbBand(double? lowG, double? highG) {
  if (lowG == null || highG == null) return null;
  if (lowG == 0 && highG == 0) return null;
  return (low: round5(lowG), high: round5(highG));
}

/// Reusable macro summary row for nutrition plan sections
/// Shows actual/target for carbs, fluids/protein (phase-dependent), and sodium
class MacroSummaryRow extends StatelessWidget {
  const MacroSummaryRow({
    super.key,
    required this.foods,
    required this.section,
    required this.category,
    this.useImperial = false,
    this.carbsLow,
    this.carbsHigh,
    this.proteinLow,
    this.proteinHigh,
    this.sodiumLow,
    this.sodiumHigh,
    this.fluidsLow,
    this.fluidsHigh,
    this.carbsOverridden = false,
    this.proteinOverridden = false,
    this.sodiumOverridden = false,
    this.fluidsOverridden = false,
    this.carbsOverrideLabel,
    this.proteinOverrideLabel,
    this.sodiumOverrideLabel,
    this.fluidsOverrideLabel,
    this.preRun,
  });

  final List<FoodItemData> foods;
  final PlanSection section;
  final String category;
  final bool useImperial;
  final int? carbsLow;
  final int? carbsHigh;
  final int? proteinLow;
  final int? proteinHigh;
  final int? sodiumLow;
  final int? sodiumHigh;
  final int? fluidsLow;
  final int? fluidsHigh;
  final bool carbsOverridden;
  final bool proteinOverridden;
  final bool sodiumOverridden;
  final bool fluidsOverridden;

  /// Optional display labels for overrides (e.g., "120g/hr" for during carbs).
  final String? carbsOverrideLabel;
  final String? proteinOverrideLabel;
  final String? sodiumOverrideLabel;
  final String? fluidsOverrideLabel;

  /// The pre-workout targets, when this row is rendering a BEFORE section.
  ///
  /// Supplies the *absence* information the section alone can't carry: the
  /// hydration gate (no fluid target set) and the fasted flag (no carbohydrate
  /// recommendation at all). Without it the BEFORE row still suppresses the
  /// sodium band — that follows from the phase, not from the data.
  final PreRunMacros? preRun;

  @override
  Widget build(BuildContext context) {
    // Calculate totals
    int totalCarbs = 0;
    int totalProtein = 0;
    int totalSodium = 0;
    double totalFluids = 0;

    for (final food in foods) {
      if (food.nutritionalInfo != null) {
        totalCarbs += food.nutritionalInfo!.carbs ?? 0;
        totalProtein += food.nutritionalInfo!.protein ?? 0;
        totalSodium += food.nutritionalInfo!.sodium ?? 0;
        totalFluids += food.nutritionalInfo!.fluids ?? 0;
      }
    }

    // Get targets
    int targetCarbs = section.carbsTarget?.round() ?? totalCarbs;
    int targetProtein = section.proteinTarget?.round() ?? totalProtein;
    int targetSodium = section.sodiumTarget?.round() ?? totalSodium;
    int targetFluids = section.fluidsTarget?.round() ?? totalFluids.round();

    int displayFluidsActual = totalFluids.round();
    int displayFluidsTarget = targetFluids;
    String fluidsUnit = 'mL';

    if (useImperial) {
      displayFluidsActual = (totalFluids * 0.033814).round();
      displayFluidsTarget = (targetFluids * 0.033814).round();
      fluidsUnit = 'oz';
    }

    final categoryLower = category.toLowerCase();
    final isDuringSection = categoryLower.contains('during');
    final isBeforeSection = categoryLower.contains('before');
    final showFluids = isBeforeSection || isDuringSection;

    // BEFORE-phase absences (docs/ssot/PRE-WORKOUT-BUNDLE-DIGEST.md §3 and §5).
    //
    // Sodium: Mealvana sets no pre-workout sodium target at all, so the figure
    // is reported as delivered — no band, no marker, no in-range state. This
    // follows from the phase itself, so it holds even for a legacy cached plan
    // that still carries the retired sodium band.
    final sodiumHasNoTarget = isBeforeSection;
    // Fluid: the hydration gate fired — a short, mild session gets no target.
    final fluidsHasNoTarget =
        isBeforeSection && (preRun?.isHydrationGated ?? false);
    // Carbohydrate: the athlete is fasted — no recommendation is being made.
    // Distinct from `carbsG == 0` at t−0, which *is* a recommendation.
    final carbsHasNoTarget =
        isBeforeSection && (preRun?.isCarbRecommendationAbsent ?? false);

    // Display rounding belongs here, not in the engine: fluid to the nearest
    // 25 (target) with the band widened to [floor25, ceil25], carbs to 5 g.
    if (isBeforeSection) {
      targetCarbs = round5(targetCarbs.toDouble()).round();
      targetFluids = round25(targetFluids.toDouble()).round();
      displayFluidsTarget = useImperial
          ? (targetFluids * 0.033814).round()
          : targetFluids;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      // Top-align the columns so all three values sit on the same line: the
      // sodium column has no range bar beneath it, and centering would drop
      // its value visibly below the carbs/fluids figures.
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: MacroSummaryItem(
            actual: totalCarbs,
            target: targetCarbs,
            unit: 'g',
            label: 'CARBS',
            low: isBeforeSection
                ? _beforeCarbBand(carbsLow, carbsHigh)?.$1
                : carbsLow,
            high: isBeforeSection
                ? _beforeCarbBand(carbsLow, carbsHigh)?.$2
                : carbsHigh,
            isOverridden: carbsOverridden,
            overrideLabel: carbsOverrideLabel,
            hasNoTarget: carbsHasNoTarget,
            noTargetNote: carbsHasNoTarget
                ? 'training fasted — no recommendation'
                : null,
            prominent: isBeforeSection,
          ),
        ),
        if (showFluids)
          Expanded(
            child: MacroSummaryItem(
              actual: displayFluidsActual,
              target: displayFluidsTarget,
              unit: fluidsUnit,
              label: 'FLUIDS',
              low: _fluidBandEnd(
                fluidsLow,
                isBeforeSection,
                floor25,
                useImperial,
              ),
              high: _fluidBandEnd(
                fluidsHigh,
                isBeforeSection,
                ceil25,
                useImperial,
              ),
              isOverridden: fluidsOverridden,
              overrideLabel: fluidsOverrideLabel,
              hasNoTarget: fluidsHasNoTarget,
              noTargetNote: fluidsHasNoTarget
                  ? 'no target for this session'
                  : null,
              prominent: isBeforeSection,
            ),
          )
        else
          Expanded(
            child: MacroSummaryItem(
              actual: totalProtein,
              target: targetProtein,
              unit: 'g',
              label: 'PROTEIN',
              low: proteinLow,
              high: proteinHigh,
              isOverridden: proteinOverridden,
              overrideLabel: proteinOverrideLabel,
            ),
          ),
        Expanded(
          child: MacroSummaryItem(
            actual: totalSodium,
            target: targetSodium,
            unit: 'mg',
            label: 'SODIUM',
            low: sodiumHasNoTarget ? null : sodiumLow,
            high: sodiumHasNoTarget ? null : sodiumHigh,
            isOverridden: sodiumOverridden,
            overrideLabel: sodiumOverrideLabel,
            hasNoTarget: sodiumHasNoTarget,
            // No note under the sodium figure — the ratified design shows the
            // dimmed value + "SODIUM" label only. (The fluid/carb no-target
            // notes above are distinct states and keep theirs.)
            prominent: isBeforeSection,
          ),
        ),
      ],
    );
  }

  /// Carbs v2 requires the `[0, 0]` band at t−0 be **suppressed**, not drawn
  /// as "0 – 0" — which would also make the delivered figure read as "over"
  /// against a ceiling of zero. Display rounding is to 5 g.
  (int, int)? _beforeCarbBand(int? low, int? high) {
    final band = roundCarbBand(low?.toDouble(), high?.toDouble());
    if (band == null) return null;
    return (band.low.round(), band.high.round());
  }

  /// Rounds one end of the pre-workout fluid band, widening rather than
  /// narrowing it (`floor25` for the floor, `ceil25` for the ceiling), then
  /// converts to the display unit. Non-BEFORE phases are untouched.
  int? _fluidBandEnd(
    int? ml,
    bool isBeforeSection,
    double Function(double) round,
    bool useImperial,
  ) {
    if (ml == null) return null;
    final rounded = isBeforeSection ? round(ml.toDouble()) : ml.toDouble();
    return useImperial ? (rounded * 0.033814).round() : rounded.round();
  }
}

/// Individual macro summary item with prominent value, label, and visual range bar
class MacroSummaryItem extends StatelessWidget {
  const MacroSummaryItem({
    super.key,
    required this.actual,
    required this.target,
    required this.unit,
    required this.label,
    this.low,
    this.high,
    this.isOverridden = false,
    this.overrideLabel,
    this.hasNoTarget = false,
    this.noTargetNote,
    this.prominent = false,
  });

  final int actual;
  final int target;
  final String unit;
  final String label;
  final int? low;
  final int? high;
  final bool isOverridden;

  /// BEFORE-phase presentation (digest §5): summary values at the design's
  /// Sansita page-title weight, and the range bar carries a second marker at
  /// the target. Defaults to false so during/post rendering is untouched.
  final bool prominent;

  /// Display label for the override value (e.g., "120g/hr").
  /// When null, falls back to showing "$target$unit".
  final String? overrideLabel;

  /// No target exists for this quantity — render what the food delivers and
  /// nothing else. Three states must never look alike (see
  /// `docs/ssot/PRE-WORKOUT-BUNDLE-DIGEST.md` §5): a real zero, *no target
  /// set* (the hydration gate), and *no recommendation at all* (fasted). The
  /// first keeps its ratio; the other two set this flag and differ by
  /// [noTargetNote].
  final bool hasNoTarget;

  /// One-line reason shown beneath the label when [hasNoTarget] is set.
  final String? noTargetNote;

  bool get _hasRange =>
      !hasNoTarget && low != null && high != null && (low! > 0 || high! > 0);

  /// Value typography: the ratified BEFORE design puts the three summary
  /// figures in Sansita bold ([AppTextStyles.pageTitle]); sized down from the
  /// mockup's 28 px to 24 px per Lee's on-device review (2026-08-05). Other
  /// phases keep the compact Apercu data number. Colour tokens are the
  /// caller's — exact-hex reconciliation with the mockup is a design-system
  /// call.
  TextStyle _valueStyle(Color color) => prominent
      ? AppTextStyles.pageTitle.copyWith(color: color, fontSize: 24)
      : AppTextStyles.dataNumber.copyWith(
          color: color,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        );

  /// Whether the target exceeds the recommended range upper bound.
  bool get _exceedsRange => _hasRange && target > high!;

  @override
  Widget build(BuildContext context) {
    final actualColor = ActivityDetailHelpers.getMacroRangeColor(
      context,
      actual,
      target,
      low: low,
      high: high,
    );
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;

    if (hasNoTarget) {
      // Delivered figure only: no ratio, no bar, no marker, and deliberately
      // the neutral on-surface colour rather than an in-range/out-of-range
      // one. There is nothing to be in range of.
      return Column(
        children: [
          Text(
            '$actual$unit',
            // Deliberately the neutral on-surface tone at the same size as
            // the teal figures — "dimmed, not diminished".
            style: _valueStyle(Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            style: AppTextStyles.smallLabel.copyWith(
              color: mutedColor,
              fontSize: 10,
            ),
          ),
          if (noTargetNote != null) ...[
            const SizedBox(height: 2),
            Text(
              noTargetNote!,
              textAlign: TextAlign.center,
              style: AppTextStyles.smallLabel.copyWith(
                color: mutedColor,
                fontSize: 9,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      );
    }

    if (!_hasRange) {
      // No range provided. When target is 0 (spec says "no recommendation"),
      // showing "actual/0 unit" reads as broken data — render just `actual unit`.
      // Otherwise keep the compact "actual/target unit" format.
      final showFlat = target == 0;
      return Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(text: '$actual', style: _valueStyle(actualColor)),
                    TextSpan(
                      text: showFlat ? unit : '/$target$unit',
                      style: _valueStyle(
                        Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              if (isOverridden) _buildOverrideIcon(context),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            style: AppTextStyles.smallLabel.copyWith(
              color: mutedColor,
              fontSize: 10,
            ),
          ),
        ],
      );
    }

    // Range mode: prominent value + label + range bar + min/max
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          // Large value with unit + override icon
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$actual$unit',
                style: prominent
                    ? _valueStyle(actualColor)
                    : AppTextStyles.dataNumber.copyWith(
                        color: actualColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
              ),
              if (isOverridden) _buildOverrideIcon(context),
            ],
          ),
          const SizedBox(height: 2),
          // Label
          Text(
            label,
            style: AppTextStyles.smallLabel.copyWith(
              color: mutedColor,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          // Range bar. In prominent (BEFORE) mode it carries both markers:
          // the triangle is the target, the diamond is what the food delivers.
          MacroRangeIndicator(
            value: actual,
            min: low!,
            max: high!,
            color: actualColor,
            target: prominent ? target : null,
            // Ratified design: the target marker is orange, the delivered
            // diamond keeps the in/out-of-range colour.
            targetColor: prominent ? AppColors.orange : null,
          ),
          const SizedBox(height: 2),
          // Min / Max labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                // Design (BEFORE): band end labels carry the unit ("30g").
                prominent ? '$low$unit' : '$low',
                style: AppTextStyles.smallLabel.copyWith(
                  color: mutedColor,
                  fontSize: 9,
                ),
              ),
              Text(
                prominent ? '$high$unit' : '$high',
                style: AppTextStyles.smallLabel.copyWith(
                  color: mutedColor,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverrideIcon(BuildContext context) {
    final iconColor = _exceedsRange
        ? Colors.amber.shade700
        : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6);

    return GestureDetector(
      onTap: () => _showOverrideSheet(context),
      child: Padding(
        padding: const EdgeInsets.only(left: 2, top: 1),
        child: Icon(Icons.info_outline_rounded, size: 14, color: iconColor),
      ),
    );
  }

  void _showOverrideSheet(BuildContext context) {
    final theme = Theme.of(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Custom ${label[0]}${label.substring(1).toLowerCase()} Target',
              style: AppTextStyles.sectionTitle.copyWith(
                color: theme.colorScheme.onSurface,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (overrideLabel != null) ...[
              Text(
                'Your override: $overrideLabel',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Calculated target: $target$unit for this activity',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 15,
                ),
              ),
            ] else
              Text(
                'Your target: $target$unit',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontSize: 15,
                ),
              ),
            if (_hasRange) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Recommended range: $low\u2013$high$unit',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 15,
                ),
              ),
            ],
            if (_exceedsRange) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: Colors.amber.shade700,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'This target exceeds the recommended range. '
                        'High intake may cause GI distress \u2014 consider '
                        'training your gut if targeting above $high$unit.',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text(
              'This target was set in your nutrition settings and overrides '
              'the algorithm\u2019s default calculation.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}
