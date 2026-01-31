import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../activities/domain/activity.dart';
import '../../../domain/nutrition_plan.dart';
import 'dismissible_food_item.dart';
import 'macro_summary_row.dart';

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
    this.useImperial = false,
  });

  final Activity brick;
  final NutritionPlan planData;
  final Function(String category) onAddFood;
  final Function(String foodId, String foodName, String category) onSwapFood;
  final Function(String foodId, String category) onDeleteFood;
  final Function(String foodId, String category, double newQuantity) onUpdateQuantity;
  final bool showSwipeHint;
  final bool useImperial;

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
    final category = _getCategoryFromSection(section.id, section.title);
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
          MacroSummaryRow(
            foods: section.foodItems,
            section: section,
            category: category,
            useImperial: useImperial,
          ),
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
                child: DismissibleFoodItem(
                  food: food,
                  category: category,
                  onSwap: () => onSwapFood(food.id, food.name, category),
                  onDelete: () => onDeleteFood(food.id, category),
                  onQuantityChange: (newQuantity) => onUpdateQuantity(food.id, category, newQuantity),
                  showSwipeHint: showSwipeHint,
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
      iconColor = AppColors.electrolyte;
    } else if (section.title.toLowerCase().contains('bike') || section.title.toLowerCase().contains('cycle')) {
      iconData = FontAwesomeIcons.personBiking;
      iconColor = AppColors.orange;
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

  /// Get category from section ID and title for food operations
  ///
  /// For brick during segments, extracts sport type from section title:
  /// - "During Swim" -> 'during_swim'
  /// - "During Bike" / "During Cycle" -> 'during_cycling'
  /// - "During Run" -> 'during_run'
  String _getCategoryFromSection(String sectionId, String sectionTitle) {
    if (sectionId == 'before') return 'before_run';
    if (sectionId == 'after') return 'after_run';
    if (sectionId.startsWith('T')) return 'transition';

    if (sectionId.startsWith('during_segment')) {
      final titleLower = sectionTitle.toLowerCase();
      if (titleLower.contains('swim')) {
        return 'during_swim';
      }
      if (titleLower.contains('bike') || titleLower.contains('cycle') || titleLower.contains('ride')) {
        return 'during_cycling';
      }
      // Default to during_run for running segments
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
