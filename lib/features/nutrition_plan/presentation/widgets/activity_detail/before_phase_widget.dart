import 'package:flutter/material.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../domain/nutrition_plan.dart';
import '../../utils/activity_detail_helpers.dart';
import 'macro_summary_row.dart';
import 'dismissible_food_item.dart';

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
    this.showSwipeHint = false,
  });

  final PlanSection section;
  final Color sectionColor;
  final String sectionTitle;
  final bool useImperial;
  final void Function(String foodId, String foodName, String category) onSwapFood;
  final void Function(String foodId, String category) onDeleteFood;
  final void Function(String foodId, String category, double newQuantity) onUpdateQuantity;
  /// Proportional scaling callback: (subPhaseIndex, foodIndex, newQuantity)
  final void Function(int subPhaseIndex, int foodIndex, double newQuantity) onScaleSubPhase;
  final void Function(String category) onAddFood;
  final bool showSwipeHint;

  @override
  State<BeforePhaseWidget> createState() => _BeforePhaseWidgetState();
}

class _BeforePhaseWidgetState extends State<BeforePhaseWidget> {
  /// Track which sub-phases are expanded (all start expanded)
  late Map<int, bool> _expandedState;

  @override
  void initState() {
    super.initState();
    final subPhaseCount = widget.section.subPhases?.length ?? 0;
    _expandedState = {
      for (int i = 0; i < subPhaseCount; i++) i: true,
    };
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
          // Section title
          Text(
            widget.sectionTitle,
            style: AppTextStyles.sectionTitle.copyWith(
              color: widget.sectionColor,
              fontSize: 18,
            ),
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
      category: 'before_run',
      useImperial: widget.useImperial,
    );
  }

  /// Build an expandable tile for a single sub-phase
  Widget _buildSubPhaseTile(
    BuildContext context,
    int index,
    BeforeSubPhase subPhase,
  ) {
    final isExpanded = _expandedState[index] ?? true;

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
                  Text(
                    subPhase.displayTitle,
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: widget.sectionColor,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  // Compact macro summary in header
                  _buildCompactMacros(subPhase),
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
                  // Food items
                  ...subPhase.foodItems.asMap().entries.map((entry) {
                    final foodIndex = entry.key;
                    final food = entry.value;
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: foodIndex < subPhase.foodItems.length - 1
                            ? AppSpacing.sm
                            : 0,
                      ),
                      child: DismissibleFoodItem(
                        food: food,
                        category: 'before_run',
                        onSwap: () => widget.onSwapFood(
                          food.id, food.name, 'before_run',
                        ),
                        onDelete: () => widget.onDeleteFood(
                          food.id, 'before_run',
                        ),
                        onQuantityChange: (newQuantity) =>
                            widget.onScaleSubPhase(
                          index, foodIndex, newQuantity,
                        ),
                        showSwipeHint: widget.showSwipeHint && index == 0 && foodIndex == 0,
                      ),
                    );
                  }),
                  const SizedBox(height: AppSpacing.sm),
                  KyleAddFoodButton(
                    text: 'ADD FOOD',
                    onPressed: () => widget.onAddFood('before_run'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Compact macro display for sub-phase header
  Widget _buildCompactMacros(BeforeSubPhase subPhase) {
    int totalCarbs = 0;
    double totalFluids = 0;

    for (final food in subPhase.foodItems) {
      if (food.nutritionalInfo != null) {
        totalCarbs += food.nutritionalInfo!.carbs ?? 0;
        totalFluids += food.nutritionalInfo!.fluids ?? 0;
      }
    }

    final targetCarbs = subPhase.carbsTarget?.round() ?? 0;

    int displayFluidsActual = totalFluids.round();
    int displayFluidsTarget = subPhase.fluidsTarget?.round() ?? 0;
    String fluidsUnit = 'mL';

    if (widget.useImperial) {
      displayFluidsActual = (totalFluids * 0.033814).round();
      displayFluidsTarget = ((subPhase.fluidsTarget ?? 0) * 0.033814).round();
      fluidsUnit = 'oz';
    }

    final carbsColor = ActivityDetailHelpers.getMacroDeviationColor(
      context, totalCarbs, targetCarbs,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _compactMacroChip(
          '$totalCarbs/${targetCarbs}g',
          carbsColor,
        ),
        const SizedBox(width: AppSpacing.xs),
        _compactMacroChip(
          '$displayFluidsActual/$displayFluidsTarget$fluidsUnit',
          Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }

  Widget _compactMacroChip(String text, Color color) {
    return Text(
      text,
      style: AppTextStyles.smallLabel.copyWith(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
