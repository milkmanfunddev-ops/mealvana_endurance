import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../activities/domain/activity.dart';
import '../../../domain/nutrition_plan.dart';
import '../../../domain/food_item_data.dart';
import '../../utils/activity_detail_helpers.dart';
import 'expandable_food_item_widget.dart';

/// BrickNutritionSections widget - renders multi-phase nutrition sections for brick workouts
///
/// Displays nutrition sections in order: Before → During-Swim → T1 → During-Bike → T2 → During-Run → After
/// Transition sections (T1, T2) have special styling with 🔄 icon
/// During-Swim typically shows "No foods recommended - mouth rinse only"
class BrickNutritionSections extends StatelessWidget {
  const BrickNutritionSections({
    super.key,
    required this.brick,
    required this.planData,
    required this.onAddFood,
    required this.onSwapFood,
    required this.onDeleteFood,
    required this.onUpdateQuantity,
    this.showSwipeHint = false,
  });

  final Activity brick;
  final NutritionPlan planData;
  final Function(String category) onAddFood;
  final Function(String foodId, String foodName, String category) onSwapFood;
  final Function(String foodId, String category) onDeleteFood;
  final Function(String foodId, String category, double newQuantity) onUpdateQuantity;
  final bool showSwipeHint;

  @override
  Widget build(BuildContext context) {
    // Sort sections by phase order (before, during segments, transitions, after)
    final sortedSections = _sortSectionsByPhaseOrder(planData.sections);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sortedSections.map((section) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: _buildSection(context, section),
        );
      }).toList(),
    );
  }

  /// Sort sections by brick phase order
  List<PlanSection> _sortSectionsByPhaseOrder(List<PlanSection> sections) {
    final sectionMap = <String, PlanSection>{};
    for (final section in sections) {
      sectionMap[section.id] = section;
    }

    final sortedSections = <PlanSection>[];

    // Add before section
    if (sectionMap.containsKey('before')) {
      sortedSections.add(sectionMap['before']!);
    }

    // Add during segments and transitions in order
    // Expected IDs: during_segment_1, T1, during_segment_2, T2, during_segment_3
    for (int i = 1; i <= 3; i++) {
      final segmentKey = 'during_segment_$i';
      if (sectionMap.containsKey(segmentKey)) {
        sortedSections.add(sectionMap[segmentKey]!);
      }

      final transitionKey = 'T$i';
      if (sectionMap.containsKey(transitionKey)) {
        sortedSections.add(sectionMap[transitionKey]!);
      }
    }

    // Add after section
    if (sectionMap.containsKey('after')) {
      sortedSections.add(sectionMap['after']!);
    }

    return sortedSections;
  }

  /// Build individual section
  Widget _buildSection(BuildContext context, PlanSection section) {
    final isTransition = section.id.startsWith('T');
    final isSwimming = section.title.toLowerCase().contains('swim');
    final category = _getCategoryFromSectionId(section.id);
    final sectionColor = _getSectionColor(section.id);

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
          _buildSectionHeader(context, section, isTransition, sectionColor),
          if (section.subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              section.subtitle!,
              style: AppTextStyles.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          _buildMacroSummaryRow(context, section, category),
          const SizedBox(height: AppSpacing.md),
          if (isSwimming && section.foodItems.isEmpty)
            _buildNoFoodsDuringSwimMessage(context)
          else
            ...section.foodItems.asMap().entries.map((entry) {
              final index = entry.key;
              final food = entry.value;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index < section.foodItems.length - 1 ? AppSpacing.sm : 0,
                ),
                child: _buildExpandableFoodItem(
                  context,
                  food,
                  category,
                ),
              );
            }),
          const SizedBox(height: AppSpacing.md),
          KyleAddFoodButton(
            text: 'ADD FOOD',
            onPressed: () => onAddFood(category),
          ),
        ],
      ),
    );
  }

  /// Build section header with appropriate icon and styling
  Widget _buildSectionHeader(BuildContext context, PlanSection section, bool isTransition, Color sectionColor) {
    return Row(
      children: [
        if (isTransition) ...[
          Icon(
            FontAwesomeIcons.repeat,
            size: AppIconSizes.md,
            color: sectionColor,
          ),
          const SizedBox(width: AppSpacing.sm),
        ] else ...[
          _getSportIcon(section),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(
          child: Text(
            section.title.toUpperCase(),
            style: AppTextStyles.sectionTitle.copyWith(
              color: sectionColor,
              fontSize: 18,
            ),
          ),
        ),
      ],
    );
  }

  /// Get sport-specific icon for section
  Widget _getSportIcon(PlanSection section) {
    IconData iconData;
    Color iconColor;

    if (section.title.toLowerCase().contains('swim')) {
      iconData = FontAwesomeIcons.personSwimming;
      iconColor = AppColors.blueberry;
    } else if (section.title.toLowerCase().contains('bike') || section.title.toLowerCase().contains('cycle')) {
      iconData = FontAwesomeIcons.personBiking;
      iconColor = AppColors.electrolyte;
    } else if (section.title.toLowerCase().contains('run')) {
      iconData = FontAwesomeIcons.personRunning;
      iconColor = AppColors.dragonfruit;
    } else if (section.id == 'before') {
      iconData = FontAwesomeIcons.clock;
      iconColor = AppColors.orange;
    } else if (section.id == 'after') {
      iconData = FontAwesomeIcons.utensils;
      iconColor = AppColors.dragonfruit;
    } else {
      iconData = FontAwesomeIcons.utensils;
      iconColor = AppColors.orange;
    }

    return Icon(
      iconData,
      size: AppIconSizes.md,
      color: iconColor,
    );
  }

  /// Build "No foods during swim" message
  Widget _buildNoFoodsDuringSwimMessage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Text(
        'No foods recommended - mouth rinse only',
        style: AppTextStyles.bodyMedium.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  /// Build macro summary row for section
  Widget _buildMacroSummaryRow(BuildContext context, PlanSection section, String category) {
    // Calculate totals
    int totalCarbs = 0;
    int totalProtein = 0;
    int totalSodium = 0;
    double totalFluids = 0;

    for (final food in section.foodItems) {
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

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildMacroSummaryItem(
          context: context,
          actual: totalCarbs,
          target: targetCarbs,
          unit: 'g',
          label: 'CARBS',
        ),
        if (category.contains('during'))
          _buildMacroSummaryItem(
            context: context,
            actual: totalFluids.round(),
            target: targetFluids,
            unit: 'mL',
            label: 'FLUIDS',
          )
        else
          _buildMacroSummaryItem(
            context: context,
            actual: totalProtein,
            target: targetProtein,
            unit: 'g',
            label: 'PROTEIN',
          ),
        _buildMacroSummaryItem(
          context: context,
          actual: totalSodium,
          target: targetSodium,
          unit: 'mg',
          label: 'SODIUM',
        ),
      ],
    );
  }

  /// Build individual macro summary item
  Widget _buildMacroSummaryItem({
    required BuildContext context,
    required int actual,
    required int target,
    required String unit,
    required String label,
  }) {
    final actualColor = ActivityDetailHelpers.getMacroDeviationColor(context, actual, target);
    final targetColor = Theme.of(context).colorScheme.onSurface;

    return Column(
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '$actual',
                style: AppTextStyles.dataNumber.copyWith(
                  color: actualColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: '/',
                style: AppTextStyles.dataNumber.copyWith(
                  color: targetColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: '$target',
                style: AppTextStyles.dataNumber.copyWith(
                  color: targetColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: unit,
                style: AppTextStyles.dataNumber.copyWith(
                  color: targetColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
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

  /// Build expandable food item with swipe actions
  Widget _buildExpandableFoodItem(
    BuildContext context,
    FoodItemData food,
    String category,
  ) {
    return Dismissible(
      key: Key(food.id),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.dragonfruit,
          borderRadius: AppRadius.smRadius,
        ),
        child: Row(
          children: [
            Icon(
              FontAwesomeIcons.trash,
              color: Colors.white,
              size: AppIconSizes.md,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Delete',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.electrolyte,
          borderRadius: AppRadius.smRadius,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Swap',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              FontAwesomeIcons.arrowRightArrowLeft,
              color: Colors.white,
              size: AppIconSizes.md,
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Delete Food Item'),
              content: Text('Remove ${food.name} from this section?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(
                    'Delete',
                    style: TextStyle(color: AppColors.dragonfruit),
                  ),
                ),
              ],
            ),
          );

          if (confirmed == true) {
            onDeleteFood(food.id, category);
          }
          return false;
        } else if (direction == DismissDirection.endToStart) {
          onSwapFood(food.id, food.name, category);
          return false;
        }
        return false;
      },
      child: ExpandableFoodItemWidget(
        food: food,
        getFoodIcon: ActivityDetailHelpers.getFoodIcon,
        isUserImportedFood: ActivityDetailHelpers.isUserImportedFood,
        getFoodIconColor: ActivityDetailHelpers.getFoodIconColor,
        onSwap: () => onSwapFood(food.id, food.name, category),
        onRemove: () => onDeleteFood(food.id, category),
        showSwipeHint: showSwipeHint,
        onQuantityChange: (newQuantity) => onUpdateQuantity(food.id, category, newQuantity),
      ),
    );
  }

  /// Get category from section ID for food operations
  String _getCategoryFromSectionId(String sectionId) {
    if (sectionId == 'before') return 'before_run';
    if (sectionId == 'after') return 'after_run';
    if (sectionId.startsWith('T')) return 'transition';
    if (sectionId.startsWith('during_segment')) {
      // Would need to determine sport type from section title
      // For now, default to during_run
      return 'during_run';
    }
    return 'during_run';
  }

  /// Get color for section based on phase
  Color _getSectionColor(String sectionId) {
    if (sectionId == 'before') return AppColors.orange;
    if (sectionId == 'after') return AppColors.dragonfruit;
    if (sectionId.startsWith('T')) return AppColors.electrolyte;
    if (sectionId.startsWith('during_segment')) return AppColors.electrolyte;
    return AppColors.electrolyte;
  }
}
