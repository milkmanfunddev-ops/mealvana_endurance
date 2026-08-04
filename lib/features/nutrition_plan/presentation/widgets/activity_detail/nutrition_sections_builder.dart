import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../../shared/domain/activity_type.dart';
import '../../../../../shared/utils/food_display_utils.dart' as food_utils;
import '../../providers/activity_detail_controller.dart';
import '../../providers/activity_detail_state.dart';
import '../../../../settings/presentation/providers/settings_controller.dart';
import '../../../application/macro_explanation_service.dart';
import '../../../application/resolved_during_target_resolver.dart';
import '../../../domain/nutrition_plan.dart';
import '../../../domain/food_item_data.dart';
import '../../../domain/run_parameters.dart';
import '../../../domain/time_slot_assignment.dart';
import 'macro_summary_row.dart';
import 'dismissible_food_item.dart';
import 'brick_nutrition_sections.dart';
import 'before_phase_widget.dart';
import 'during_phase_section_widget.dart';
import 'phase_explanation_sheet.dart';

/// Callback signatures for food operations
typedef FoodOperationCallback = void Function(String foodId, String category);
typedef SwapFoodCallback =
    void Function(String foodId, String foodName, String category);
typedef UpdateQuantityCallback =
    Future<void> Function(String foodId, String category, double newQuantity);
typedef AddFoodCallback = void Function(String category);

/// Callback signatures for By Hour features (during sections)
typedef InitializeByHourCallback =
    void Function(String category, int durationMinutes);
typedef MoveFoodToTimeSlotCallback =
    void Function(
      String foodId,
      String category,
      TimeSlot sourceSlot,
      TimeSlot newSlot,
    );
typedef PlaceFoodInSlotCallback =
    void Function(
      String foodId,
      String category,
      TimeSlot slot,
      double qty,
      TimingCategory? timingCategory,
      bool isSipThroughout,
    );
typedef RemoveFoodFromSlotCallback =
    void Function(String foodId, String category, TimeSlot slot);
typedef AdjustSlotQuantityCallback =
    void Function(String foodId, String category, TimeSlot slot, double delta);
typedef MoveSipFoodToSlotCallback =
    void Function(
      String foodId,
      String category,
      TimeSlot slot,
      double qty,
      TimingCategory? timingCategory,
    );

/// Callback signature for sub-phase scaling (before sections with V2 template plans)
typedef ScaleSubPhaseCallback =
    void Function(int subPhaseIndex, int foodIndex, double newQuantity);

/// Widget that builds all nutrition sections (before, during, after) for single-sport activities
class NutritionSectionsBuilder extends ConsumerStatefulWidget {
  const NutritionSectionsBuilder({
    super.key,
    required this.state,
    required this.onSwapFood,
    required this.onDeleteFood,
    required this.onUpdateQuantity,
    required this.onAddFood,
    required this.onInitializeByHour,
    required this.onMoveFoodToTimeSlot,
    required this.onPlaceFoodInSlot,
    required this.onRemoveFoodFromSlot,
    required this.onAdjustSlotQuantity,
    required this.onMoveSipFoodToSlot,
    required this.onScaleSubPhase,
    required this.consumeSwipeHint,
    this.enableSectionHeroes = false,
    this.heroTagSeed,
  });

  final ActivityDetailState state;
  final SwapFoodCallback onSwapFood;
  final FoodOperationCallback onDeleteFood;
  final UpdateQuantityCallback onUpdateQuantity;
  final AddFoodCallback onAddFood;
  final InitializeByHourCallback onInitializeByHour;
  final MoveFoodToTimeSlotCallback onMoveFoodToTimeSlot;
  final PlaceFoodInSlotCallback onPlaceFoodInSlot;
  final RemoveFoodFromSlotCallback onRemoveFoodFromSlot;
  final AdjustSlotQuantityCallback onAdjustSlotQuantity;
  final MoveSipFoodToSlotCallback onMoveSipFoodToSlot;
  final ScaleSubPhaseCallback onScaleSubPhase;
  final bool Function() consumeSwipeHint;
  final bool enableSectionHeroes;
  final String? heroTagSeed;

  @override
  ConsumerState<NutritionSectionsBuilder> createState() =>
      _NutritionSectionsBuilderState();
}

class _NutritionSectionsBuilderState
    extends ConsumerState<NutritionSectionsBuilder> {
  final Map<String, bool> _expandedSections = {};

  @override
  Widget build(BuildContext context) {
    final plan = widget.state.nutritionPlan;
    if (plan == null) return const SizedBox.shrink();

    final activity = widget.state.activity;

    // Check if this is a brick workout - use separate widget
    if (activity != null && activity.isBrick) {
      final brickSettings = ref.watch(settingsControllerProvider).value;
      return BrickNutritionSections(
        brick: activity,
        planData: plan,
        // Default to imperial when settings have not loaded yet — that is the
        // app-wide default (users.unit_system defaults to 'imperial'). Testing
        // `== miles` on a null settings object silently yields metric.
        useImperial:
            (brickSettings?.preferredDistanceUnit ?? DistanceUnit.miles) ==
            DistanceUnit.miles,
        bodyWeightKg: _getBodyWeightKg(brickSettings?.weightPounds),
        onAddFood: widget.onAddFood,
        onSwapFood: widget.onSwapFood,
        onDeleteFood: widget.onDeleteFood,
        onUpdateQuantity: widget.onUpdateQuantity,
        onInitializeByHour: widget.onInitializeByHour,
        onMoveFoodToTimeSlot: widget.onMoveFoodToTimeSlot,
        onPlaceFoodInSlot: widget.onPlaceFoodInSlot,
        onRemoveFoodFromSlot: widget.onRemoveFoodFromSlot,
        onAdjustSlotQuantity: widget.onAdjustSlotQuantity,
        onMoveSipFoodToSlot: widget.onMoveSipFoodToSlot,
        onScaleSubPhase: widget.onScaleSubPhase,
        macroTargets: widget.state.macroTargets,
        showSwipeHint: widget.consumeSwipeHint(),
        enableSectionHeroes: widget.enableSectionHeroes,
        heroTagSeed: widget.heroTagSeed,
        onRegenerate: _buildRegenCallback(),
      );
    }

    // Get activity type for sport-specific section titles (e.g., "Before Swim", "During Ride")
    final activityType =
        widget.state.activity?.activityType ?? ActivityType.running;
    // Check unit preference and get body weight
    final settings = ref.watch(settingsControllerProvider).value;
    final useImperial =
        (settings?.preferredDistanceUnit ?? DistanceUnit.miles) ==
        DistanceUnit.miles;
    final bodyWeightKg = _getBodyWeightKg(settings?.weightPounds);
    final resolvedDuringTarget = widget.state.macroTargets != null
        ? ResolvedDuringTargetResolver.resolveForSingleSport(
            macroTargets: widget.state.macroTargets!,
            sport: activityType,
            settingsOverrides: settings?.nutritionTargetOverrides,
          )
        : null;
    final duringOverrideApplied =
        resolvedDuringTarget?.isOverrideApplied ?? false;
    final duringOverrideLabel =
        duringOverrideApplied && resolvedDuringTarget != null
        ? '${resolvedDuringTarget.rateGPerH.round()}g/hr'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: plan.sections.map((section) {
        // Determine category from section.id (preferred) or fallback to parsing title
        String category;
        Color sectionColor;

        if (section.id.contains('during')) {
          // Always use 'during_run' as the category for single-sport plans.
          // The plan data (from nutrition_plan_mapper) always stores 'during_run'
          // as the section ID regardless of sport type. Using the same category
          // ensures a direct match when adding/swapping/deleting foods.
          // The display title is generated independently via activityType.getSectionTitle().
          category = 'during_run';
          sectionColor = Theme.of(context).colorScheme.secondary;
        } else if (section.id.contains('after')) {
          category = 'after_run';
          sectionColor = AppColors.dragonfruit;
        } else {
          category = 'before_run';
          sectionColor = AppColors.orange;
        }

        // Short phase label for this page only (avoids "During Run" wrapping
        // to two lines on narrow phones). The sport-specific title returned
        // by ActivityType.getSectionTitle() is still used by other
        // consumers (e.g. templates, coach view) — intentionally not
        // changed here.
        final sectionTitle = _shortPhaseLabel(category);

        // Use BeforePhaseWidget for before sections with sub-phases (V2 template plans)
        if (category == 'before_run' && section.hasSubPhases) {
          return _wrapWithSectionHero(
            section.id,
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: BeforePhaseWidget(
                section: section,
                sectionColor: sectionColor,
                sectionTitle: sectionTitle.toUpperCase(),
                useImperial: useImperial,
                planId: widget.state.activity?.id,
                onSwapFood: widget.onSwapFood,
                onDeleteFood: widget.onDeleteFood,
                onUpdateQuantity: widget.onUpdateQuantity,
                onScaleSubPhase: widget.onScaleSubPhase,
                onAddFood: widget.onAddFood,
                showSwipeHint: widget.consumeSwipeHint(),
                macroTargets: widget.state.macroTargets,
                bodyWeightKg: bodyWeightKg,
                sportLabel: activityType.displayName,
                carbsLow: widget.state.macroTargets?.preRun.carbsLowG?.round(),
                carbsHigh: widget.state.macroTargets?.preRun.carbsHighG
                    ?.round(),
                proteinLow: widget.state.macroTargets?.preRun.proteinLowG
                    ?.round(),
                proteinHigh: widget.state.macroTargets?.preRun.proteinHighG
                    ?.round(),
                sodiumLow: widget.state.macroTargets?.preRun.sodiumLowMg
                    ?.round(),
                sodiumHigh: widget.state.macroTargets?.preRun.sodiumHighMg
                    ?.round(),
                fluidsLow: widget.state.macroTargets?.preRun.fluidsLowMl
                    ?.round(),
                fluidsHigh: widget.state.macroTargets?.preRun.fluidsHighMl
                    ?.round(),
                carbsOverridden: false,
                proteinOverridden: false,
                sodiumOverridden: false,
                fluidsOverridden: false,
                carbsOverrideLabel: null,
                proteinOverrideLabel: null,
                sodiumOverrideLabel: null,
                fluidsOverrideLabel: null,
                onRegenerate: _buildRegenCallback(),
              ),
            ),
          );
        }

        // Use DuringPhaseSectionWidget for during sections (supports By Hour toggle)
        if (category.startsWith('during_')) {
          final durationMinutes = widget.state.activity?.durationMinutes ?? 120;
          return _wrapWithSectionHero(
            section.id,
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: DuringPhaseSectionWidget(
                section: section,
                sectionColor: sectionColor,
                sectionTitle: sectionTitle.toUpperCase(),
                category: category,
                planId: widget.state.activity?.id,
                durationMinutes: durationMinutes,
                useImperial: useImperial,
                activityType: activityType,
                subtitle: section.subtitle,
                sportIcon: _getSportIcon(activityType),
                sportIconColor: sectionColor,
                onSwapFood: widget.onSwapFood,
                onDeleteFood: widget.onDeleteFood,
                onUpdateQuantity: widget.onUpdateQuantity,
                onAddFood: widget.onAddFood,
                onInitializeByHour: widget.onInitializeByHour,
                onMoveFoodToTimeSlot: widget.onMoveFoodToTimeSlot,
                onPlaceFoodInSlot: widget.onPlaceFoodInSlot,
                onRemoveFoodFromSlot: widget.onRemoveFoodFromSlot,
                onAdjustSlotQuantity: widget.onAdjustSlotQuantity,
                onMoveSipFoodToSlot: widget.onMoveSipFoodToSlot,
                showSwipeHint: widget.consumeSwipeHint(),
                macroTargets: widget.state.macroTargets,
                bodyWeightKg: bodyWeightKg,
                sportLabel: activityType.displayName,
                carbsLow: widget.state.macroTargets?.duringRun.carbsLowG
                    ?.round(),
                carbsHigh: widget.state.macroTargets?.duringRun.carbsHighG
                    ?.round(),
                sodiumLow: widget.state.macroTargets?.duringRun.sodiumLowMg
                    ?.round(),
                sodiumHigh: widget.state.macroTargets?.duringRun.sodiumHighMg
                    ?.round(),
                fluidsLow: widget.state.macroTargets?.duringRun.fluidsLowMl
                    ?.round(),
                fluidsHigh: widget.state.macroTargets?.duringRun.fluidsHighMl
                    ?.round(),
                carbsOverridden: duringOverrideApplied,
                sodiumOverridden: false,
                fluidsOverridden: false,
                carbsOverrideLabel: duringOverrideLabel,
                sodiumOverrideLabel: null,
                fluidsOverrideLabel: null,
                onRegenerate: _buildRegenCallback(),
              ),
            ),
          );
        }

        // Standard section (after_run or simple before_run)
        // Extract per-phase range params from MacroTargets
        final mt = widget.state.macroTargets;
        int? carbsLow, carbsHigh, proteinLow, proteinHigh;
        int? sodiumLow, sodiumHigh, fluidsLow, fluidsHigh;
        if (mt != null && category.toLowerCase().contains('after')) {
          carbsLow = mt.postRun.carbsLowG?.round();
          carbsHigh = mt.postRun.carbsHighG?.round();
          proteinLow = mt.postRun.proteinLowG?.round();
          proteinHigh = mt.postRun.proteinHighG?.round();
          sodiumLow = mt.postRun.sodiumLowMg?.round();
          sodiumHigh = mt.postRun.sodiumHighMg?.round();
          fluidsLow = mt.postRun.fluidsLowMl?.round();
          fluidsHigh = mt.postRun.fluidsHighMl?.round();
        } else if (mt != null && category.toLowerCase().contains('before')) {
          carbsLow = mt.preRun.carbsLowG?.round();
          carbsHigh = mt.preRun.carbsHighG?.round();
          proteinLow = mt.preRun.proteinLowG?.round();
          proteinHigh = mt.preRun.proteinHighG?.round();
          sodiumLow = mt.preRun.sodiumLowMg?.round();
          sodiumHigh = mt.preRun.sodiumHighMg?.round();
          fluidsLow = mt.preRun.fluidsLowMl?.round();
          fluidsHigh = mt.preRun.fluidsHighMl?.round();
        }

        return _wrapWithSectionHero(
          section.id,
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: _buildNutritionSection(
              context: context,
              title: sectionTitle.toUpperCase(),
              section: section,
              category: category,
              sectionColor: sectionColor,
              carbsLow: carbsLow,
              carbsHigh: carbsHigh,
              proteinLow: proteinLow,
              proteinHigh: proteinHigh,
              sodiumLow: sodiumLow,
              sodiumHigh: sodiumHigh,
              fluidsLow: fluidsLow,
              fluidsHigh: fluidsHigh,
              useImperial: useImperial,
              carbsOverridden: false,
              proteinOverridden: false,
              sodiumOverridden: false,
              fluidsOverridden: false,
              carbsOverrideLabel: null,
              proteinOverrideLabel: null,
              sodiumOverrideLabel: null,
              fluidsOverrideLabel: null,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _wrapWithSectionHero(String sectionId, Widget child) {
    // Hero animations removed — they caused RenderFlex overflow during flight
    // (section widgets are too tall for overlay constraints) which cascaded
    // into deactivated-widget and Riverpod state-modification errors.
    return child;
  }

  Widget _buildNutritionSection({
    required BuildContext context,
    required String title,
    required PlanSection section,
    required String category,
    required Color sectionColor,
    required bool useImperial,
    int? carbsLow,
    int? carbsHigh,
    int? proteinLow,
    int? proteinHigh,
    int? sodiumLow,
    int? sodiumHigh,
    int? fluidsLow,
    int? fluidsHigh,
    bool carbsOverridden = false,
    bool proteinOverridden = false,
    bool sodiumOverridden = false,
    bool fluidsOverridden = false,
    String? carbsOverrideLabel,
    String? proteinOverrideLabel,
    String? sodiumOverrideLabel,
    String? fluidsOverrideLabel,
  }) {
    final isExpanded = _expandedSections[category] ?? false;
    // Post-workout recovery is treated as a trigger, not a macro-dosing event,
    // so we hide carbs/protein/sodium/fluid targets for the after section.
    // The food list below remains the canonical portion.
    final isAfterSection = category.toLowerCase().contains('after');

    final foodSummary = section.foodItems
        .map(_buildCollapsedFoodSummaryLabel)
        .join(' + ');

    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardRadius,
        border: Border.all(
          color: sectionColor.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            context,
            title,
            category,
            sectionColor,
            useImperial,
            section,
          ),
          const SizedBox(height: AppSpacing.md),
          if (!isAfterSection) ...[
            MacroSummaryRow(
              foods: section.foodItems,
              section: section,
              category: category,
              useImperial: useImperial,
              carbsLow: carbsLow,
              carbsHigh: carbsHigh,
              proteinLow: proteinLow,
              proteinHigh: proteinHigh,
              sodiumLow: sodiumLow,
              sodiumHigh: sodiumHigh,
              fluidsLow: fluidsLow,
              fluidsHigh: fluidsHigh,
              carbsOverridden: carbsOverridden,
              proteinOverridden: proteinOverridden,
              sodiumOverridden: sodiumOverridden,
              fluidsOverridden: fluidsOverridden,
              carbsOverrideLabel: carbsOverrideLabel,
              proteinOverrideLabel: proteinOverrideLabel,
              sodiumOverrideLabel: sodiumOverrideLabel,
              fluidsOverrideLabel: fluidsOverrideLabel,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          // Food list: collapsible by default; expanded inline for the after
          // section since it has no macro summary above to scan past.
          if (isAfterSection) ...[
            ...section.foodItems.asMap().entries.map((entry) {
              final index = entry.key;
              final food = entry.value;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index < section.foodItems.length - 1
                      ? AppSpacing.sm
                      : 0,
                ),
                child: DismissibleFoodItem(
                  food: food,
                  category: category,
                  onSwap: () => widget.onSwapFood(food.id, food.name, category),
                  onDelete: () => widget.onDeleteFood(food.id, category),
                  onQuantityChange: (newQuantity) =>
                      widget.onUpdateQuantity(food.id, category, newQuantity),
                  showSwipeHint: widget.consumeSwipeHint(),
                  useImperial: useImperial,
                ),
              );
            }),
            const SizedBox(height: AppSpacing.md),
            KyleAddFoodButton(
              key: ValueKey('plan_detail.${category}_add_food_button'),
              text: 'ADD FOOD',
              onPressed: () => widget.onAddFood(category),
            ),
          ] else ...[
            InkWell(
              onTap: () {
                setState(() {
                  _expandedSections[category] = !isExpanded;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      color: sectionColor,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        foodSummary,
                        style: AppTextStyles.smallLabel.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isExpanded) ...[
              const SizedBox(height: AppSpacing.sm),
              ...section.foodItems.asMap().entries.map((entry) {
                final index = entry.key;
                final food = entry.value;
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index < section.foodItems.length - 1
                        ? AppSpacing.sm
                        : 0,
                  ),
                  child: DismissibleFoodItem(
                    food: food,
                    category: category,
                    onSwap: () =>
                        widget.onSwapFood(food.id, food.name, category),
                    onDelete: () => widget.onDeleteFood(food.id, category),
                    onQuantityChange: (newQuantity) =>
                        widget.onUpdateQuantity(food.id, category, newQuantity),
                    showSwipeHint: widget.consumeSwipeHint(),
                    useImperial: useImperial,
                  ),
                );
              }),
              const SizedBox(height: AppSpacing.md),
              KyleAddFoodButton(
                key: ValueKey('plan_detail.${category}_add_food_button'),
                text: 'ADD FOOD',
                onPressed: () => widget.onAddFood(category),
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _buildCollapsedFoodSummaryLabel(FoodItemData food) {
    final qty = food_utils.parseLeadingQuantity(food.quantity);

    // If the quantity string already has a multi-word tail (e.g. "2 cups Oatmeal"),
    // use it directly — the enrichment already built the proper label.
    final tail = food_utils.parseQuantityTail(food.quantity);
    if (qty != null && tail.contains(' ')) {
      if ((qty - 1.0).abs() < 0.01) {
        return food_utils.stripParenthetical(food.displayName ?? food.name);
      }
      return '${food_utils.formatQuantity(qty)} ${food_utils.stripParenthetical(tail)}';
    }

    final singular = food_utils.stripParenthetical(
      food.displayName ?? food.name,
    );
    // Skip naive pluralization for composite names containing '+' (e.g. "Toast + PB + Jam")
    final plural = food_utils.stripParenthetical(
      food.displayNamePlural ??
          (singular.contains('+') || singular.toLowerCase().endsWith('s')
              ? singular
              : '${singular}s'),
    );

    if (qty == null || (qty - 1.0).abs() < 0.01) return singular;
    final label = qty > 1 ? plural : singular;
    return '${food_utils.formatQuantity(qty)} $label';
  }

  FaIconData _getSportIcon(ActivityType activityType) {
    switch (activityType) {
      case ActivityType.cycling:
        return FontAwesomeIcons.personBiking;
      case ActivityType.swimming:
        return FontAwesomeIcons.personSwimming;
      case ActivityType.running:
      default:
        return FontAwesomeIcons.personRunning;
    }
  }

  Widget _buildSectionTitle(
    BuildContext context,
    String title,
    String category,
    Color sectionColor,
    bool useImperial,
    PlanSection section,
  ) {
    final mt = widget.state.macroTargets;
    final activityType =
        widget.state.activity?.activityType ?? ActivityType.running;
    final settings = ref.read(settingsControllerProvider).value;
    final bodyWeightKg = _getBodyWeightKg(settings?.weightPounds);

    return Row(
      children: [
        Expanded(
          child: Text(
            key: ValueKey('plan_detail.${category}_section'),
            title,
            style: AppTextStyles.sectionTitle.copyWith(
              color: sectionColor,
              fontSize: 18,
            ),
          ),
        ),
        if (mt != null)
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
                final phase = _categoryToPhase(category);
                PhaseExplanationSheet.show(
                  context,
                  phase: phase,
                  macroTargets: mt,
                  bodyWeightKg: bodyWeightKg,
                  sportLabel: activityType.displayName,
                  useImperial: useImperial,
                  foods: section.foodItems,
                  planId: widget.state.activity?.id,
                  onRegenerate: _buildRegenCallback(),
                );
              },
            ),
          ),
      ],
    );
  }

  /// Builds a callback that triggers a plan regen for the current activity.
  ///
  /// Passed to [PhaseExplanationSheet] so that inline sweat-profile edits can
  /// immediately refresh the plan without the user dismissing and re-opening.
  ///
  /// Uses [ActivityDetailController.regeneratePlan] which re-calls the edge
  /// function with the latest UserProfile values (including newly-saved
  /// `knownSweatRateMlPerHour` / `knownSodiumConcentrationMgPerLiter`),
  /// unlike [ActivityDetailController.forceRefresh] which only reloads the
  /// already-stored plan from the database.
  VoidCallback? _buildRegenCallback() {
    final activityId = widget.state.activity?.id;
    if (activityId == null) return null;
    return () {
      ref
          .read(
            activityDetailControllerProvider(activityId: activityId).notifier,
          )
          .regeneratePlan();
    };
  }

  double _getBodyWeightKg(double? weightPounds) {
    if (weightPounds == null || weightPounds <= 0) return 70.0;
    return weightPounds * 0.453592;
  }

  /// Short "Before"/"During"/"After" heading used only on this screen so the
  /// section title never wraps to two lines on narrow phones (e.g. "During
  /// Run"). Brick section titles are unaffected — they render via
  /// `section.title` in `BrickNutritionSections`, not this path.
  String _shortPhaseLabel(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('during')) return 'During';
    if (lower.contains('after')) return 'After';
    return 'Before';
  }

  ExplanationPhase _categoryToPhase(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('before')) return ExplanationPhase.before;
    if (lower.contains('during')) return ExplanationPhase.during;
    if (lower.contains('after')) return ExplanationPhase.after;
    return ExplanationPhase.during;
  }
}
