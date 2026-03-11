import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../../shared/domain/activity_type.dart';
import '../../../../../shared/utils/food_display_utils.dart' as food_utils;
import '../../providers/activity_detail_state.dart';
import '../../../../settings/presentation/providers/settings_controller.dart';
import '../../../domain/nutrition_plan.dart';
import '../../../domain/food_item_data.dart';
import '../../../domain/run_parameters.dart';
import '../../../domain/time_slot_assignment.dart';
import 'macro_summary_row.dart';
import 'dismissible_food_item.dart';
import 'brick_nutrition_sections.dart';
import 'before_phase_widget.dart';
import 'during_phase_section_widget.dart';

/// Callback signatures for food operations
typedef FoodOperationCallback = void Function(String foodId, String category);
typedef SwapFoodCallback = void Function(String foodId, String foodName, String category);
typedef UpdateQuantityCallback = Future<void> Function(String foodId, String category, double newQuantity);
typedef AddFoodCallback = void Function(String category);

/// Callback signatures for By Hour features (during sections)
typedef InitializeByHourCallback = void Function(String category, int durationMinutes);
typedef MoveFoodToTimeSlotCallback = void Function(String foodId, String category, TimeSlot sourceSlot, TimeSlot newSlot);
typedef PlaceFoodInSlotCallback = void Function(String foodId, String category, TimeSlot slot, double qty, TimingCategory? timingCategory, bool isSipThroughout);
typedef RemoveFoodFromSlotCallback = void Function(String foodId, String category, TimeSlot slot);
typedef AdjustSlotQuantityCallback = void Function(String foodId, String category, TimeSlot slot, double delta);
typedef MoveSipFoodToSlotCallback = void Function(String foodId, String category, TimeSlot slot, double qty, TimingCategory? timingCategory);

/// Callback signature for sub-phase scaling (before sections with V2 template plans)
typedef ScaleSubPhaseCallback = void Function(int subPhaseIndex, int foodIndex, double newQuantity);

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

  @override
  ConsumerState<NutritionSectionsBuilder> createState() => _NutritionSectionsBuilderState();
}

class _NutritionSectionsBuilderState extends ConsumerState<NutritionSectionsBuilder> {
  final Map<String, bool> _expandedSections = {};

  @override
  Widget build(BuildContext context) {
    final plan = widget.state.nutritionPlan;
    if (plan == null) return const SizedBox.shrink();

    final activity = widget.state.activity;

    // Check if this is a brick workout - use separate widget
    if (activity != null && activity.isBrick) {
      return BrickNutritionSections(
        brick: activity,
        planData: plan,
        useImperial:
            ref
                .watch(settingsControllerProvider)
                .value
                ?.preferredDistanceUnit ==
            DistanceUnit.miles,
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
        showSwipeHint: widget.consumeSwipeHint(),
      );
    }

    // Get activity type for sport-specific section titles (e.g., "Before Swim", "During Ride")
    final activityType = widget.state.activity?.activityType ?? ActivityType.running;

    // Check unit preference
    final settings = ref.watch(settingsControllerProvider).value;
    final useImperial = settings?.preferredDistanceUnit == DistanceUnit.miles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: plan.sections.map((section) {
        // Determine category from section.id (preferred) or fallback to parsing title
        String category;
        Color sectionColor;

        if (section.id.contains('during')) {
          switch (activityType) {
            case ActivityType.cycling:
              category = 'during_cycling';
            case ActivityType.swimming:
              category = 'during_swim';
            default:
              category = 'during_run';
          }
          sectionColor = AppColors.electrolyte;
        } else if (section.id.contains('after')) {
          category = 'after_run';
          sectionColor = AppColors.dragonfruit;
        } else {
          category = 'before_run';
          sectionColor = AppColors.orange;
        }

        // Generate sport-specific title using ActivityType
        final sectionTitle = activityType.getSectionTitle(category);

        // Use BeforePhaseWidget for before sections with sub-phases (V2 template plans)
        if (category == 'before_run' && section.hasSubPhases) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: BeforePhaseWidget(
              section: section,
              sectionColor: sectionColor,
              sectionTitle: sectionTitle.toUpperCase(),
              useImperial: useImperial,
              onSwapFood: widget.onSwapFood,
              onDeleteFood: widget.onDeleteFood,
              onUpdateQuantity: widget.onUpdateQuantity,
              onScaleSubPhase: widget.onScaleSubPhase,
              onAddFood: widget.onAddFood,
              showSwipeHint: widget.consumeSwipeHint(),
            ),
          );
        }

        // Use DuringPhaseSectionWidget for during sections (supports By Hour toggle)
        if (category.startsWith('during_')) {
          final durationMinutes = widget.state.activity?.durationMinutes ?? 120;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: DuringPhaseSectionWidget(
              section: section,
              sectionColor: sectionColor,
              sectionTitle: sectionTitle.toUpperCase(),
              category: category,
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
            ),
          );
        }

        // Standard section (after_run or simple before_run)
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: _buildNutritionSection(
            context: context,
            title: sectionTitle.toUpperCase(),
            section: section,
            category: category,
            sectionColor: sectionColor,
            useImperial: useImperial,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNutritionSection({
    required BuildContext context,
    required String title,
    required PlanSection section,
    required String category,
    required Color sectionColor,
    required bool useImperial,
  }) {
    final isExpanded = _expandedSections[category] ?? false;

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
          Text(
            title,
            style: AppTextStyles.sectionTitle.copyWith(
              color: sectionColor,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          MacroSummaryRow(
            foods: section.foodItems,
            section: section,
            category: category,
            useImperial: useImperial,
          ),
          const SizedBox(height: AppSpacing.md),
          // Collapsible food list
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
                  onDelete: () =>
                      widget.onDeleteFood(food.id, category),
                  onQuantityChange: (newQuantity) => widget.onUpdateQuantity(
                    food.id,
                    category,
                    newQuantity,
                  ),
                  showSwipeHint: widget.consumeSwipeHint(),
                  useImperial: useImperial,
                ),
              );
            }),
            const SizedBox(height: AppSpacing.md),
            KyleAddFoodButton(
              text: 'ADD FOOD',
              onPressed: () => widget.onAddFood(category),
            ),
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

    final singular = food_utils.stripParenthetical(food.displayName ?? food.name);
    final plural = food_utils.stripParenthetical(
      food.displayNamePlural ??
          (singular.toLowerCase().endsWith('s') ? singular : '${singular}s'),
    );

    if (qty == null || (qty - 1.0).abs() < 0.01) return singular;
    final label = qty > 1 ? plural : singular;
    return '${food_utils.formatQuantity(qty)} $label';
  }

  IconData _getSportIcon(ActivityType activityType) {
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
}
