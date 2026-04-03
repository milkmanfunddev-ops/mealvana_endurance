import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../auth/domain/user_preferences.dart';
import '../../../../settings/presentation/providers/settings_controller.dart';
import '../../../application/macro_explanation_service.dart';
import '../../../application/resolved_during_target_resolver.dart';
import '../../../domain/carb_transparency_data.dart';
import '../../../domain/food_item_data.dart';
import '../../../domain/macro_targets.dart';
import '../../../domain/nutrition_target_overrides.dart';
import '../../../domain/resolved_during_target.dart';
import '../../../../../shared/domain/activity_type.dart';
import 'carb_full_story_section.dart';
import 'carb_tldr_section.dart';
import 'transparency_video_section.dart';

/// Bottom sheet that explains how nutrition targets were calculated for a given phase.
///
/// Shows personalized calculation breakdowns per macro with formula,
/// range rationale, and source citations. Follows the existing
/// HelpBottomSheetWidget DraggableScrollableSheet pattern.
///
/// The Carbohydrates card is replaced with a rich transparency UI
/// (TL;DR formula + video + Full Story Q&A). Fluids/Sodium keep the
/// existing expandable card layout.
class PhaseExplanationSheet extends ConsumerStatefulWidget {
  const PhaseExplanationSheet({
    super.key,
    required this.phase,
    required this.macroTargets,
    required this.bodyWeightKg,
    this.sportLabel,
    this.useImperial = false,
    this.foods,
    this.brickSegment,
    this.isBrick = false,
  });

  final ExplanationPhase phase;
  final MacroTargets macroTargets;
  final double bodyWeightKg;
  final String? sportLabel;
  final bool useImperial;
  final List<FoodItemData>? foods;
  final BrickSegmentMacroTarget? brickSegment;
  final bool isBrick;

  /// Show the explanation sheet as a modal bottom sheet.
  static void show(
    BuildContext context, {
    required ExplanationPhase phase,
    required MacroTargets macroTargets,
    required double bodyWeightKg,
    String? sportLabel,
    bool useImperial = false,
    List<FoodItemData>? foods,
    BrickSegmentMacroTarget? brickSegment,
    bool isBrick = false,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PhaseExplanationSheet(
        phase: phase,
        macroTargets: macroTargets,
        bodyWeightKg: bodyWeightKg,
        sportLabel: sportLabel,
        useImperial: useImperial,
        foods: foods,
        brickSegment: brickSegment,
        isBrick: isBrick,
      ),
    );
  }

  @override
  ConsumerState<PhaseExplanationSheet> createState() =>
      _PhaseExplanationSheetState();
}

class _PhaseExplanationSheetState extends ConsumerState<PhaseExplanationSheet> {
  final _service = const MacroExplanationService();
  String? _expandedMacro;

  @override
  void initState() {
    super.initState();
    // Default: first macro expanded
    final explanations = _service.getExplanations(
      phase: widget.phase,
      macroTargets: widget.macroTargets,
      bodyWeightKg: widget.bodyWeightKg,
      useImperial: widget.useImperial,
      brickSegment: widget.brickSegment,
    );
    if (explanations.isNotEmpty) {
      _expandedMacro = explanations.first.macroName;
    }
  }

  /// Compute actual food totals from the provided food items
  Map<String, int>? _computeActuals() {
    final foods = widget.foods;
    if (foods == null || foods.isEmpty) return null;

    int carbs = 0;
    int protein = 0;
    int sodium = 0;
    int fluids = 0;

    for (final food in foods) {
      final info = food.nutritionalInfo;
      if (info != null) {
        carbs += info.carbs ?? 0;
        protein += info.protein ?? 0;
        sodium += info.sodium ?? 0;
        fluids += (info.fluids ?? 0).round();
      }
    }

    return {
      'carbs': carbs,
      'protein': protein,
      'sodium': sodium,
      'fluids': fluids,
    };
  }

  CarbTransparencyData? _getCarbTransparencyData() {
    final settingsState = ref.read(settingsControllerProvider).value;
    final fallbackGutTraining =
        settingsState?.gutTrainingLevel ?? GutTraining.moderate;
    final snapshotGutMultiplier =
        widget.brickSegment?.gutMultiplier ??
        widget.macroTargets.duringRun.gutMultiplier;
    final gutMultiplier =
        snapshotGutMultiplier ??
        switch (fallbackGutTraining) {
          GutTraining.low => 0.7,
          GutTraining.moderate => 1.0,
          GutTraining.high => 1.2,
        };
    final gutTrainingLabel =
        _gutTrainingLabelFromMultiplier(snapshotGutMultiplier) ??
        fallbackGutTraining.name;
    final overrides = settingsState?.nutritionTargetOverrides;
    final sport =
        widget.brickSegment?.sport ??
        widget.sportLabel?.toLowerCase() ??
        'running';
    final resolvedDuringTarget = _resolveDuringTarget(
      overrides: overrides,
      sportLabel: sport,
    );

    return _service.getCarbTransparencyData(
      phase: widget.phase,
      macroTargets: widget.macroTargets,
      bodyWeightKg: widget.bodyWeightKg,
      gutTrainingLabel: gutTrainingLabel,
      gutMultiplier: gutMultiplier,
      personalCarbTargetGPerH: resolvedDuringTarget?.settingsOverrideRateGPerH,
      personalTargetSport: sport,
      sportLabel: widget.sportLabel,
      brickSegment: widget.brickSegment,
      isBrick: widget.isBrick,
      resolvedDuringTarget: resolvedDuringTarget,
    );
  }

  ResolvedDuringTarget? _resolveDuringTarget({
    required NutritionTargetOverrides? overrides,
    required String sportLabel,
  }) {
    if (widget.phase != ExplanationPhase.during) return null;

    if (widget.isBrick && widget.brickSegment != null) {
      return ResolvedDuringTargetResolver.resolveForBrickSegment(
        macroTargets: widget.macroTargets,
        segment: widget.brickSegment!,
        settingsOverrides: overrides,
      );
    }

    return ResolvedDuringTargetResolver.resolveForSingleSport(
      macroTargets: widget.macroTargets,
      sport: _sportFromLabel(sportLabel),
      settingsOverrides: overrides,
    );
  }

  ActivityType _sportFromLabel(String value) {
    final sport = value.toLowerCase();
    if (sport.contains('run')) return ActivityType.running;
    if (sport.contains('cycl') || sport.contains('bike')) {
      return ActivityType.cycling;
    }
    if (sport.contains('swim')) return ActivityType.swimming;
    return ActivityType.running;
  }

  String? _gutTrainingLabelFromMultiplier(double? value) {
    if (value == null) return null;
    if ((value - 0.7).abs() <= 0.05) return GutTraining.low.name;
    if ((value - 1.0).abs() <= 0.05) return GutTraining.moderate.name;
    if ((value - 1.2).abs() <= 0.05) return GutTraining.high.name;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Watch settings for live updates after inline edits
    ref.watch(settingsControllerProvider);

    final title = _service.getSheetTitle(widget.phase, widget.sportLabel);
    final actuals = _computeActuals();
    final explanations = _service.getExplanations(
      phase: widget.phase,
      macroTargets: widget.macroTargets,
      bodyWeightKg: widget.bodyWeightKg,
      useImperial: widget.useImperial,
      actuals: actuals,
      brickSegment: widget.brickSegment,
    );

    final carbTransparency = _getCarbTransparencyData();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              title,
              style: AppTextStyles.sectionTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...explanations.map((explanation) {
                      // Replace carbs card with transparency UI
                      if (explanation.macroName == 'Carbohydrates' &&
                          carbTransparency != null) {
                        return _buildCarbTransparencyCard(
                          context,
                          explanation,
                          carbTransparency,
                        );
                      }
                      return _buildExplanationCard(context, explanation);
                    }),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarbTransparencyCard(
    BuildContext context,
    MacroExplanation explanation,
    CarbTransparencyData transparency,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.electrolyte.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: "Carbohydrates" + planned/target badge (HTML design)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Accent bar + title
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Container(
                    width: 3,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.electrolyte,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    'Carbohydrates',
                    style: AppTextStyles.sectionTitle.copyWith(
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                const Spacer(),
                // Target badge: planned / target + range
                _buildTargetBadge(context, explanation, transparency),
              ],
            ),
            const SizedBox(height: 14),

            // TL;DR formula (always visible)
            CarbTldrSection(data: transparency),
            const SizedBox(height: 4),

            // Video accordion
            if (transparency.videoTitle != null)
              TransparencyVideoSection(
                title: transparency.videoTitle!,
                videoUrl: transparency.videoUrl,
              ),

            // Full Story accordion
            if (transparency.storySections.isNotEmpty)
              CarbFullStorySection(
                data: transparency,
                onSettingsChanged: () => setState(() {}),
              ),
          ],
        ),
      ),
    );
  }

  /// Builds the planned/target badge matching the HTML design.
  ///
  /// Shows: "52g planned / 48g target" with range badge below.
  Widget _buildTargetBadge(
    BuildContext context,
    MacroExplanation explanation,
    CarbTransparencyData transparency,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dimColor = isDark
        ? Colors.white.withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.4);
    final secondaryText = isDark
        ? AppColors.textDarkSecondary
        : AppColors.textLightSecondary;

    final planned = explanation.actualValue;
    final target = transparency.targetGrams != null
        ? transparency.targetGrams!.round().toString()
        : explanation.value;
    final unit = explanation.unit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Main row: planned / target
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (planned != null) ...[
              Text(
                '$planned$unit',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                  letterSpacing: -0.8,
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              Text('planned', style: TextStyle(fontSize: 11, color: dimColor)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Text(
                  '/',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w300,
                    color: dimColor,
                  ),
                ),
              ),
              Text(
                '$target$unit',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: secondaryText,
                  letterSpacing: -0.4,
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              Text('target', style: TextStyle(fontSize: 11, color: dimColor)),
            ] else ...[
              // No planned food — just show target
              Text(
                '$target$unit',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                  letterSpacing: -0.8,
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              Text('target', style: TextStyle(fontSize: 11, color: dimColor)),
            ],
          ],
        ),
        // Range badge
        if (transparency.rangeLow != null && transparency.rangeHigh != null)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.electrolyte.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: AppColors.electrolyte.withValues(alpha: 0.22),
              ),
            ),
            child: Text(
              'Recommended range: ${transparency.rangeLow!.round()}\u2013${transparency.rangeHigh!.round()}${explanation.unit}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.electrolyte,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildExplanationCard(
    BuildContext context,
    MacroExplanation explanation,
  ) {
    final isExpanded = _expandedMacro == explanation.macroName;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpanded
              ? AppColors.electrolyte.withValues(alpha: 0.3)
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _expandedMacro = _expandedMacro == explanation.macroName
                ? null
                : explanation.macroName;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          explanation.displayHeader,
                          style: AppTextStyles.sectionTitle.copyWith(
                            fontSize: 15,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        if (explanation.displaySubHeader != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            explanation.displaySubHeader!,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontSize: 13,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),

              // Expanded content
              if (isExpanded) ...[
                const SizedBox(height: 12),
                // Formula / explanation
                Text(
                  explanation.formulaText,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                // Range rationale in a subtle container
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.electrolyte.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    explanation.rangeRationale,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.electrolyte,
                      height: 1.4,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
