import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../buttons/add_food_button.dart';

/// Nutrition section card for Kyle's design system
/// Card with macro summary header and food items list
class NutritionSectionCard extends ConsumerWidget {
  const NutritionSectionCard({
    super.key,
    required this.title,
    required this.macroTargets,
    this.foodItems = const [],
    this.onAddFood,
    this.backgroundColor,
    this.isExpanded = true,
    this.onToggleExpanded,
  });

  final String title;
  final DisplayMacroTargets macroTargets;
  final List<DisplayFoodItem> foodItems;
  final VoidCallback? onAddFood;
  final Color? backgroundColor;
  final bool isExpanded;
  final VoidCallback? onToggleExpanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Material(
        color: backgroundColor ?? Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.cardRadius,
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title and macro summary
              _buildHeader(context),
              
              // Food items list
              if (isExpanded) ...[
                const SizedBox(height: AppSpacing.md),
                ...foodItems.map((food) => _buildFoodItem(context, food)),
                
                // Add food button
                if (onAddFood != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  KyleAddFoodButton(
                    onPressed: onAddFood!,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return InkWell(
      onTap: onToggleExpanded,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(15),
        topRight: Radius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.activityTitle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                Icon(
                  isExpanded ? FontAwesomeIcons.chevronUp : FontAwesomeIcons.chevronDown,
                  size: AppIconSizes.controlIcon,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.sm),

            // Macro summary
            _buildMacroSummary(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroSummary(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.electrolyte.withOpacity(0.1),
        borderRadius: AppRadius.inputRadius,
      ),
      child: Row(
        children: [
          // Carbs
          Expanded(
            child: _MacroItem(
              label: 'CARBS',
              value: '${macroTargets.carbs}g',
              target: '${macroTargets.carbsTarget}g',
            ),
          ),
          
          // Protein
          Expanded(
            child: _MacroItem(
              label: 'PROTEIN',
              value: '${macroTargets.protein}g',
              target: '${macroTargets.proteinTarget}g',
            ),
          ),
          
          // Fat or Fluids
          Expanded(
            child: _MacroItem(
              label: macroTargets.isFluids ? 'FLUIDS' : 'FAT',
              value: macroTargets.isFluids 
                  ? '${macroTargets.fluids}mL'
                  : '${macroTargets.fat}g',
              target: macroTargets.isFluids
                  ? '${macroTargets.fluidsTarget}mL'
                  : '${macroTargets.fatTarget}g',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodItem(BuildContext context, DisplayFoodItem food) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: food.onTap,
          borderRadius: AppRadius.inputRadius,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              borderRadius: AppRadius.inputRadius,
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
              ),
            ),
            child: Row(
              children: [
                // Food icon
                Container(
                  width: AppIconSizes.foodIcon,
                  height: AppIconSizes.foodIcon,
                  decoration: BoxDecoration(
                    color: AppColors.electrolyte,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    food.icon,
                    size: AppIconSizes.foodIcon * 0.5,
                    color: AppColors.textLight,
                  ),
                ),

                const SizedBox(width: AppSpacing.sm),

                // Food details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        food.name,
                        style: AppTextStyles.foodTitle.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        food.quantity,
                        style: AppTextStyles.smallLabel.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Action buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (food.onEdit != null)
                      IconButton(
                        icon: Icon(
                          FontAwesomeIcons.pen,
                          size: AppIconSizes.controlIcon,
                          color: Colors.orange,
                        ),
                        onPressed: food.onEdit,
                      ),
                    if (food.onRemove != null)
                      IconButton(
                        icon: Icon(
                          FontAwesomeIcons.trash,
                          size: AppIconSizes.controlIcon,
                          color: AppColors.dragonfruit,
                        ),
                        onPressed: food.onRemove,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Macro item widget for nutrition summary
class _MacroItem extends StatelessWidget {
  const _MacroItem({
    required this.label,
    required this.value,
    required this.target,
  });

  final String label;
  final String value;
  final String target;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: AppTextStyles.smallLabel.copyWith(
            color: AppColors.electrolyte,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          value,
          style: AppTextStyles.dataNumber.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 20,
          ),
        ),
        Text(
          target,
          style: AppTextStyles.smallLabel.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Display macro targets data class (current vs target values)
class DisplayMacroTargets {
  const DisplayMacroTargets({
    required this.carbs,
    required this.carbsTarget,
    required this.protein,
    required this.proteinTarget,
    required this.fat,
    required this.fatTarget,
    this.fluids,
    this.fluidsTarget,
    this.isFluids = false,
  });

  final int carbs;
  final int carbsTarget;
  final int protein;
  final int proteinTarget;
  final int fat;
  final int fatTarget;
  final int? fluids;
  final int? fluidsTarget;
  final bool isFluids;
}

/// Food item data class
class DisplayFoodItem {
  const DisplayFoodItem({
    required this.name,
    required this.quantity,
    required this.icon,
    this.onTap,
    this.onEdit,
    this.onRemove,
  });

  final String name;
  final String quantity;
  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;
}