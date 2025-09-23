import 'package:flutter/material.dart';
import 'package:mealvana_endurance/theme/app_theme.dart';
import '../../domain/carb_loading_plan_simple.dart';
import '../../domain/carb_foods_list.dart';
import 'carb_loading_food_pills.dart';

/// Meal section widget matching screenshot design
/// Shows meal name, calories, large carb number, Quick Add buttons, and selected food pills
class CarbLoadingMealSection extends StatelessWidget {
  final String mealName;
  final MealFoods mealFoods;
  final int targetCarbs;
  final Function(String) onAddFood;
  final Function(String) onRemoveFood;
  final Function(String, int) onUpdateFoodQuantity;

  const CarbLoadingMealSection({
    super.key,
    required this.mealName,
    required this.mealFoods,
    required this.targetCarbs,
    required this.onAddFood,
    required this.onRemoveFood,
    required this.onUpdateFoodQuantity,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with meal name and calories
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _getMealDisplayName(mealName),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4285F4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${mealFoods.totalCarbs}/${targetCarbs}g',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                
              ],
            ),

            // const SizedBox(height: 16),

            // Large carb number display
            // Column(
            //   crossAxisAlignment: CrossAxisAlignment.start,
            //   children: [
            //     Text(
            //       // '${mealFoods.totalCarbs}g',
            //       'Target: ${targetCarbs}g',
            //       style: theme.textTheme.displaySmall?.copyWith(
            //         fontWeight: FontWeight.bold,
            //       ),
            //     ),
            //     Text(
            //       'Carbs',
            //       style: theme.textTheme.bodyMedium?.copyWith(
            //         fontWeight: FontWeight.w500,
            //       ),
            //     ),
            //   ],
            // ),

            // const SizedBox(height: 20),

            // Target and selected carbs row
            // Row(
            //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //   children: [
            //     Text(
            //       'Target: ${targetCarbs}g',
            //       style: theme.textTheme.displaySmall?.copyWith(
            //         color: AppTheme.primary900,
            //         fontSize: 22,
            //       ),
            //     ),
            //     Text(
            //       'Selected: ${mealFoods.totalCarbs}g',
            //       style: theme.textTheme.displaySmall?.copyWith(
            //         color: const Color(0xFF4285F4),
            //         fontSize: 22,
            //       ),
            //     ),
            //   ],
            // ),

            const SizedBox(height: 12),

            // Quick Add section
            Text(
              'Quick Add (+50g carbs each):',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 12),

            // Quick Add food buttons and selected pills
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: CarbFoodsList.quickAddFoods.map((food) {
                final isSelected = mealFoods.selectedFoods.containsKey(food.name);
                final quantity = mealFoods.selectedFoods[food.name] ?? 0;

                if (isSelected) {
                  // Show as blue pill with +/- controls
                  return CarbLoadingFoodPill(
                    foodName: food.name,
                    quantity: quantity,
                    onIncrement: () {
                      onUpdateFoodQuantity(food.name, quantity + 1);
                    },
                    onDecrement: () {
                      if (quantity > 1) {
                        onUpdateFoodQuantity(food.name, quantity - 1);
                      } else {
                        onRemoveFood(food.name);
                      }
                    },
                  );
                } else {
                  // Show as gray button
                  return _QuickAddFoodButton(
                    food: food,
                    onTap: () => onAddFood(food.name),
                  );
                }
              }).toList(),
            ),

            // Show added carbs summary if any foods are selected
            // if (mealFoods.selectedFoods.isNotEmpty) ...[
            //   const SizedBox(height: 16),
            //   Container(
            //     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            //     decoration: BoxDecoration(
            //       color: Colors.blue[50],
            //       borderRadius: BorderRadius.circular(8),
            //     ),
            //     child: Row(
            //       children: [
            //         Text(
            //           'Added: +${mealFoods.totalCarbs}g carbs',
            //           style: theme.textTheme.bodyMedium?.copyWith(
            //             color: const Color(0xFF4285F4),
            //             fontWeight: FontWeight.w500,
            //           ),
            //         ),
            //       ],
            //     ),
            //   ),
            // ],
          ],
        ),
      ),
    );
  }

  /// Get display name for meal
  String _getMealDisplayName(String mealName) {
    switch (mealName.toLowerCase()) {
      case 'breakfast':
        return 'Breakfast';
      case 'lunch':
        return 'Lunch';
      case 'dinner':
        return 'Dinner';
      case 'snack1':
        return 'Snack';
      case 'snack2':
        return 'Snack';
      default:
        return mealName;
    }
  }

}

/// Quick Add food button widget
class _QuickAddFoodButton extends StatelessWidget {
  final CarbFood food;
  final VoidCallback onTap;

  const _QuickAddFoodButton({
    required this.food,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Text(
          food.displayName,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.grey[700],
          ),
        ),
      ),
    );
  }
}