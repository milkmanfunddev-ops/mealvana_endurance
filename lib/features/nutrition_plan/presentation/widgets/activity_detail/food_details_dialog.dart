import 'package:flutter/material.dart';
import '../../../domain/food_item_data.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';

/// Food Details Dialog
/// Shows detailed nutrition information for a food item
class FoodDetailsDialog extends StatelessWidget {
  const FoodDetailsDialog({
    super.key,
    required this.food,
    required this.onSwap,
    required this.onDelete,
    required this.getFoodType,
  });

  final FoodItemData food;
  final VoidCallback onSwap;
  final VoidCallback onDelete;
  final KyleFoodType Function(String) getFoodType;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: AppRadius.lgRadius,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Food icon and name
            Row(
              children: [
                KyleFoodIcon(
                  foodType: getFoodType(food.name),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        food.name,
                        style: AppTextStyles.subtitle.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        food.quantity,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // Nutrition facts
            if (food.nutritionalInfo != null)
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: AppRadius.cardRadius,
                ),
                child: Column(
                  children: [
                    _buildNutritionRow(
                      context,
                      'Calories',
                      '${food.nutritionalInfo!.calories ?? 0} kcal',
                      AppColors.orange,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildNutritionRow(
                      context,
                      'Carbohydrates',
                      '${food.nutritionalInfo!.carbs ?? 0}g',
                      AppColors.electrolyte,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildNutritionRow(
                      context,
                      'Protein',
                      '${food.nutritionalInfo!.protein ?? 0}g',
                      AppColors.dragonfruit,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildNutritionRow(
                      context,
                      'Fat',
                      '${food.nutritionalInfo!.fat ?? 0}g',
                      Theme.of(context).colorScheme.onSurface,
                    ),
                  ],
                ),
              ),

            const SizedBox(height: AppSpacing.lg),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: KyleSecondaryButton(
                    text: 'Swap',
                    onPressed: onSwap,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: KyleSecondaryButton(
                    text: 'Remove',
                    onPressed: onDelete,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.sm),

            // Close button
            KyleTertiaryButton(
              text: 'Close',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionRow(BuildContext context, String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.dataNumber.copyWith(
            color: color,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
