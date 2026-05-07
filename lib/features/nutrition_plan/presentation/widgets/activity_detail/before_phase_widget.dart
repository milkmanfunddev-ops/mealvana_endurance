import 'package:flutter/material.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../application/macro_explanation_service.dart';
import '../../../domain/macro_targets.dart';
import '../../../domain/nutrition_plan.dart';
import '../macro_shortfall_card.dart';
import 'macro_summary_row.dart';
import 'dismissible_food_item.dart';
import 'phase_explanation_sheet.dart';

/// Widget for rendering the "Before" phase with expandable sub-phases.
///
/// When a V2 template-based plan is used, the before section contains
/// nested sub-phases (meal, snack, top_up). This widget renders each
/// sub-phase as an expandable tile with its own macro summary and food items.
class BeforePhaseWidget extends StatefulWidget {
  const BeforePhaseWidget({
    super.key,
    required this.section,
    required this.sectionColor,
    required this.sectionTitle,
    required this.useImperial,
    required this.onSwapFood,
    required this.onDeleteFood,
    required this.onUpdateQuantity,
    required this.onScaleSubPhase,
    required this.onAddFood,
    this.categoryPrefix = 'before_run',
    this.showSwipeHint = false,
    this.macroTargets,
    this.bodyWeightKg = 70.0,
    this.sportLabel,
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
    this.onRegenerate,
  });

  final PlanSection section;
  final Color sectionColor;
  final String sectionTitle;
  final bool useImperial;
  final void Function(String foodId, String foodName, String category)
  onSwapFood;
  final void Function(String foodId, String category) onDeleteFood;
  final void Function(String foodId, String category, double newQuantity)
  onUpdateQuantity;

  /// Proportional scaling callback: (subPhaseIndex, foodIndex, newQuantity)
  final void Function(int subPhaseIndex, int foodIndex, double newQuantity)
  onScaleSubPhase;
  final void Function(String category) onAddFood;
  final String categoryPrefix;
  final bool showSwipeHint;
  final MacroTargets? macroTargets;
  final double bodyWeightKg;
  final String? sportLabel;
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
  final String? carbsOverrideLabel;
  final String? proteinOverrideLabel;
  final String? sodiumOverrideLabel;
  final String? fluidsOverrideLabel;

  /// Called after an inline sweat-profile edit is saved so the parent can
  /// trigger a plan regen (e.g. via ActivityDetailController.forceRefresh).
  final VoidCallback? onRegenerate;

  @override
  State<BeforePhaseWidget> createState() => _BeforePhaseWidgetState();
}

class _BeforePhaseWidgetState extends State<BeforePhaseWidget> {
  /// Track which sub-phases are expanded (all start collapsed).
  late Map<int, bool> _expandedState;

  @override
  void initState() {
    super.initState();
    final subPhaseCount = widget.section.subPhases?.length ?? 0;
    _expandedState = {for (int i = 0; i < subPhaseCount; i++) i: false};
  }

  @override
  Widget build(BuildContext context) {
    final subPhases = widget.section.subPhases!;

    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardRadius,
        border: Border.all(
          color: widget.sectionColor.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title with info button
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.sectionTitle,
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: widget.sectionColor,
                    fontSize: 18,
                  ),
                ),
              ),
              if (widget.macroTargets != null)
                SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 20,
                    icon: Icon(
                      Icons.help_outline_rounded,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    onPressed: () {
                      PhaseExplanationSheet.show(
                        context,
                        phase: ExplanationPhase.before,
                        macroTargets: widget.macroTargets!,
                        bodyWeightKg: widget.bodyWeightKg,
                        sportLabel: widget.sportLabel,
                        useImperial: widget.useImperial,
                        foods: widget.section.subPhases
                                ?.expand((sp) => sp.foodItems)
                                .toList() ??
                            widget.section.foodItems,
                        onRegenerate: widget.onRegenerate,
                      );
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Overall macro summary for the entire before phase
          _buildOverallMacroSummary(subPhases),

          const SizedBox(height: AppSpacing.md),

          // Expandable sub-phase tiles
          ...subPhases.asMap().entries.map((entry) {
            final index = entry.key;
            final subPhase = entry.value;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index < subPhases.length - 1 ? AppSpacing.sm : 0,
              ),
              child: _buildSubPhaseTile(context, index, subPhase),
            );
          }),
        ],
      ),
    );
  }

  /// Build the overall macro summary by aggregating all sub-phases
  Widget _buildOverallMacroSummary(List<BeforeSubPhase> subPhases) {
    // Aggregate all food items across sub-phases for actuals
    final allFoods = subPhases.expand((sp) => sp.foodItems).toList();

    // Aggregate targets across sub-phases
    double totalCarbsTarget = 0;
    double totalProteinTarget = 0;
    double totalSodiumTarget = 0;
    double totalFluidsTarget = 0;

    for (final sp in subPhases) {
      totalCarbsTarget += sp.carbsTarget ?? 0;
      totalProteinTarget += sp.proteinTarget ?? 0;
      totalSodiumTarget += sp.sodiumTarget ?? 0;
      totalFluidsTarget += sp.fluidsTarget ?? 0;
    }

    // Create a synthetic PlanSection with aggregated targets for MacroSummaryRow
    final aggregatedSection = widget.section.copyWith(
      carbsTarget: totalCarbsTarget,
      proteinTarget: totalProteinTarget,
      sodiumTarget: totalSodiumTarget,
      fluidsTarget: totalFluidsTarget,
    );

    return MacroSummaryRow(
      foods: allFoods,
      section: aggregatedSection,
      category: widget.categoryPrefix,
      useImperial: widget.useImperial,
      carbsLow: widget.carbsLow,
      carbsHigh: widget.carbsHigh,
      proteinLow: widget.proteinLow,
      proteinHigh: widget.proteinHigh,
      sodiumLow: widget.sodiumLow,
      sodiumHigh: widget.sodiumHigh,
      fluidsLow: widget.fluidsLow,
      fluidsHigh: widget.fluidsHigh,
      carbsOverridden: widget.carbsOverridden,
      proteinOverridden: widget.proteinOverridden,
      sodiumOverridden: widget.sodiumOverridden,
      fluidsOverridden: widget.fluidsOverridden,
      carbsOverrideLabel: widget.carbsOverrideLabel,
      proteinOverrideLabel: widget.proteinOverrideLabel,
      sodiumOverrideLabel: widget.sodiumOverrideLabel,
      fluidsOverrideLabel: widget.fluidsOverrideLabel,
    );
  }

  /// Build an expandable tile for a single sub-phase
  Widget _buildSubPhaseTile(
    BuildContext context,
    int index,
    BeforeSubPhase subPhase,
  ) {
    final isExpanded = _expandedState[index] ?? false;

    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardRadius,
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        border: Border.all(
          color: widget.sectionColor.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sub-phase header (tap to expand/collapse)
          InkWell(
            onTap: () {
              setState(() {
                _expandedState[index] = !isExpanded;
              });
            },
            borderRadius: AppRadius.cardRadius,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_right,
                    color: widget.sectionColor,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subPhase.displayTitle,
                          style: AppTextStyles.sectionTitle.copyWith(
                            color: widget.sectionColor,
                            fontSize: 16,
                          ),
                        ),
                        if (!isExpanded &&
                            subPhase.templateSummary.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subPhase.templateSummary,
                            style: AppTextStyles.smallLabel.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanded content
          if (isExpanded) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Divider(
                color: widget.sectionColor.withValues(alpha: 0.15),
                height: 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                children: [
                  // Centered macro summary
                  _buildCenteredMacroSummary(subPhase),
                  const SizedBox(height: AppSpacing.sm),
                  // Food items
                  ...subPhase.foodItems.asMap().entries.map((entry) {
                    final foodIndex = entry.key;
                    final food = entry.value;
                    // Use sub-phase-specific category to target the correct sub-phase
                    final subCategory = '${widget.categoryPrefix}:${subPhase.subPhaseType}';
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: foodIndex < subPhase.foodItems.length - 1
                            ? AppSpacing.sm
                            : 0,
                      ),
                      child: DismissibleFoodItem(
                        food: food,
                        category: subCategory,
                        onSwap: () =>
                            widget.onSwapFood(food.id, food.name, subCategory),
                        onDelete: () =>
                            widget.onDeleteFood(food.id, subCategory),
                        onQuantityChange: (newQuantity) => widget
                            .onUpdateQuantity(food.id, subCategory, newQuantity),
                        showSwipeHint:
                            widget.showSwipeHint &&
                            index == 0 &&
                            foodIndex == 0,
                        useImperial: widget.useImperial,
                      ),
                    );
                  }),
                  const SizedBox(height: AppSpacing.sm),
                  if (subPhase.shortfalls.isNotEmpty) ...[
                    MacroShortfallCard(
                      shortfalls: subPhase.shortfalls,
                      dietHint: _dietHint,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  KyleAddFoodButton(
                    text: 'ADD FOOD',
                    onPressed: () => widget.onAddFood('${widget.categoryPrefix}:${subPhase.subPhaseType}'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Optional diet hint passed to MacroShortfallCard for diet-aware
  /// suggestions. Returns null when no diet context is available — the card
  /// then uses the generic suggestion list.
  String? get _dietHint => null; // Wire user diet here when threaded through

  /// Centered macro summary displayed inside expanded sub-phase content.
  /// Shows CARBS/FLUIDS/SODIUM to match the parent card header.
  Widget _buildCenteredMacroSummary(BeforeSubPhase subPhase) {
    int totalCarbs = 0;
    double totalFluidsMl = 0;
    int totalSodium = 0;

    for (final food in subPhase.foodItems) {
      if (food.nutritionalInfo != null) {
        totalCarbs += food.nutritionalInfo!.carbs ?? 0;
        totalFluidsMl += food.nutritionalInfo!.fluids ?? 0;
        totalSodium += food.nutritionalInfo!.sodium ?? 0;
      }
    }

    // Convert fluids to display unit (ml or oz)
    final String fluidsValue;
    final String fluidsUnit;
    if (widget.useImperial) {
      fluidsValue = (totalFluidsMl * 0.033814).round().toString();
      fluidsUnit = 'oz';
    } else {
      fluidsValue = totalFluidsMl.round().toString();
      fluidsUnit = 'ml';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _macroLabel('${totalCarbs}g', 'CARBS'),
        const SizedBox(width: AppSpacing.lg),
        _macroLabel('$fluidsValue$fluidsUnit', 'FLUIDS'),
        const SizedBox(width: AppSpacing.lg),
        _macroLabel('${totalSodium}mg', 'SODIUM'),
      ],
    );
  }

  Widget _macroLabel(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.smallLabel.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.smallLabel.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
