import 'package:flutter/material.dart';
import '../../../../../shared/domain/activity_type.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../domain/macro_targets.dart';
import '../../../domain/nutrition_plan.dart';
import '../../../domain/pre_workout_display_rounding.dart';
import '../../../domain/pre_workout_feeding_labels.dart';
import '../macro_shortfall_card.dart';
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
    this.categoryPrefix = 'before_run',
    this.showSwipeHint = false,
    this.planId,
    this.macroTargets,
    this.bodyWeightKg = 70.0,
    this.sportLabel,
    this.activityType,
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

  /// Activity id, forwarded to the explanation sheet so transparency views
  /// can be attributed to a plan.
  final String? planId;

  final MacroTargets? macroTargets;
  final double bodyWeightKg;
  final String? sportLabel;

  /// Sport for the feeding-card titles ("Pre-Run Meal" / "Pre-Ride Meal").
  /// Null (e.g. the brick path) falls back to the generic "Pre-Workout Meal".
  final ActivityType? activityType;
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
                    // Deliberate no-op: the BEFORE explanation copy in
                    // PhaseExplanationSheet is stale pending a rewrite for
                    // the v3 pre-workout model. Keep the button visually
                    // unchanged (not greyed out) but inert until then.
                    // During/post info buttons are unaffected.
                    onPressed: () {},
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),

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
      // Carries the BEFORE-phase absences the section alone can't express:
      // the hydration gate (no fluid target set) and the fasted flag (no
      // carbohydrate recommendation at all). Sodium needs nothing here — v3
      // means the BEFORE phase never has a sodium target.
      preRun: widget.macroTargets?.preRun,
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
                          subPhase.displayTitleFor(widget.activityType),
                          // Deliberately NOT Compadre despite the mockup: the
                          // in-app Compadre is a 66-glyph demo cut whose
                          // lowercase codepoints carry full-cap outlines with
                          // very wide advances (and no hyphen glyph), so
                          // "Pre-Run Meal" renders as giant spaced capitals
                          // and truncates. Use the app-bar Sansita instead
                          // (sectionTitle family/weight) at 16 px, orange,
                          // title case, single line.
                          style: AppTextStyles.sectionTitle.copyWith(
                            color: AppColors.orange,
                            fontSize: 16,
                            letterSpacing: 0,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Window label — derived client-side per the SSOT
                        // reference implementation; the engine emits none.
                        if (_windowLabel(subPhase) != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            _windowLabel(subPhase)!,
                            // Design: 9 px uppercase, cream at 50% — the
                            // dimmest line in the header hierarchy.
                            style: AppTextStyles.smallLabel.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.5),
                              fontSize: 9,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                        // Collapsed: always show the summary line. Expanded:
                        // keep the curated template name visible so the
                        // ingredient rows below read as one item
                        // (bug 3abe3fdb754c8153).
                        if ((!isExpanded ||
                                (subPhase.templateName?.isNotEmpty ?? false)) &&
                            subPhase.templateSummary.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subPhase.templateSummary,
                            // Design: 12 px at 75% cream — deliberately
                            // brighter than the window label above it.
                            style: AppTextStyles.smallLabel.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.75),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Per-feeding figures, always visible in the header (both
                  // collapsed and expanded — these chips are the only
                  // per-feeding numbers): big value over a tiny uppercase
                  // label. Values are DELIVERED — summed from the card's
                  // foods, so add/remove/quantity edits move them. A carbs
                  // chip whenever the foods deliver carbs, a fluids chip
                  // whenever they deliver fluids, sodium never (digest §5).
                  // Zero-valued figures render no chip at all.
                  ..._buildCollapsedChips(subPhase),
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
                  // No per-feeding macro summary here — the header chips are
                  // the only per-feeding numbers (ratified design).
                  // Food items
                  ...subPhase.foodItems.asMap().entries.map((entry) {
                    final foodIndex = entry.key;
                    final food = entry.value;
                    // Use sub-phase-specific category to target the correct sub-phase
                    final subCategory =
                        '${widget.categoryPrefix}:${subPhase.subPhaseType}';
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
                        onQuantityChange: (newQuantity) =>
                            widget.onUpdateQuantity(
                              food.id,
                              subCategory,
                              newQuantity,
                            ),
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
                    onPressed: () => widget.onAddFood(
                      '${widget.categoryPrefix}:${subPhase.subPhaseType}',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Window label for a feeding card. The snack window's near edge depends on
  /// whether the plan carries a meal tier at all.
  String? _windowLabel(BeforeSubPhase subPhase) {
    final hasMealTier =
        widget.section.subPhases?.any((sp) => sp.subPhaseType == 'meal') ??
        false;
    return preWorkoutWindowLabel(
      subPhase.subPhaseType,
      hasMealTier: hasMealTier,
    );
  }

  /// Right-aligned per-feeding **delivered** figures for the collapsed header,
  /// summed from the card's foods so add/remove and the quantity stepper move
  /// them (the controller rewrites each food's `nutritionalInfo` on edit and
  /// the rebuilt plan state flows back down through `widget.section`).
  ///
  /// Display rounding per digest §5: carbs to 5 g, fluid to 25 ml, converted
  /// to the user's unit. A card whose foods deliver nothing (or no foods at
  /// all) produces no chip — never a "0g". Sodium never gets a chip.
  List<Widget> _buildCollapsedChips(BeforeSubPhase subPhase) {
    final chips = <Widget>[];

    double deliveredCarbs = 0;
    double deliveredFluidsMl = 0;
    for (final food in subPhase.foodItems) {
      final info = food.nutritionalInfo;
      if (info == null) continue;
      deliveredCarbs += info.carbs ?? 0;
      deliveredFluidsMl += info.fluids ?? 0;
    }

    final carbs = round5(deliveredCarbs).round();
    if (carbs > 0) {
      chips.add(_feedingChip('${carbs}g', 'CARBS'));
    }

    // Any card that delivers fluids shows the chip — the old meal-card-only
    // rule was an artifact of which card happened to carry a fluid target.
    final ml = round25(deliveredFluidsMl).round();
    if (ml > 0) {
      final value = widget.useImperial
          ? '${(ml * 0.033814).round()}oz'
          : '${ml}ml';
      chips.add(_feedingChip(value, 'FLUIDS'));
    }

    return [
      for (int i = 0; i < chips.length; i++) ...[
        if (i > 0) const SizedBox(width: AppSpacing.md),
        chips[i],
      ],
    ];
  }

  Widget _feedingChip(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          value,
          // Per-feeding values are Sansita 16 px in the ratified design.
          style: AppTextStyles.sectionTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.smallLabel.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 9,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  /// Optional diet hint passed to MacroShortfallCard for diet-aware
  /// suggestions. Returns null when no diet context is available — the card
  /// then uses the generic suggestion list.
  String? get _dietHint => null; // Wire user diet here when threaded through
}
