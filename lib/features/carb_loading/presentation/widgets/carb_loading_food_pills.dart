import 'package:flutter/material.dart';
import '../../domain/carb_foods_list.dart';
import '../../../../theme/kyle_design/app_colors.dart';

/// Interactive blue food pills widget matching screenshot design
/// Shows selected foods with quantities and +/- controls
class CarbLoadingFoodPills extends StatelessWidget {
  final Map<String, int> selectedFoods;
  final Function(String) onRemoveFood;
  final Function(String, int) onUpdateQuantity;

  const CarbLoadingFoodPills({
    super.key,
    required this.selectedFoods,
    required this.onRemoveFood,
    required this.onUpdateQuantity,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedFoods.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: selectedFoods.entries.map((entry) {
        final foodName = entry.key;
        final quantity = entry.value;

        return CarbLoadingFoodPill(
          foodName: foodName,
          quantity: quantity,
          onIncrement: () {
            onUpdateQuantity(foodName, quantity + 1);
          },
          onDecrement: () {
            if (quantity > 1) {
              onUpdateQuantity(foodName, quantity - 1);
            } else {
              onRemoveFood(foodName);
            }
          },
        );
      }).toList(),
    );
  }
}

/// Individual food pill widget with +/- controls
class CarbLoadingFoodPill extends StatelessWidget {
  final String foodName;
  final int quantity;
  final Function() onIncrement;
  final Function() onDecrement;
  final double? carbsPerServing; // Optional carbs for customized foods

  const CarbLoadingFoodPill({
    super.key,
    required this.foodName,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    this.carbsPerServing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final food = CarbFoodsList.getFoodByName(foodName);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        // Semi-transparent dark background with teal outline
        color: isDark
            ? AppColors.blackberryLight.withValues(alpha: 0.3)
            : AppColors.cream.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(25),
        // Teal border (outlined style)
        border: Border.all(
          color: isDark
              ? AppColors.electrolyte.withValues(alpha: 0.6)
              : AppColors.blackberry.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Decrement button
          GestureDetector(
            onTap: onDecrement,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              margin: const EdgeInsets.all(4),
              child: Icon(
                Icons.remove,
                color: AppColors.electrolyte,
                size: 18,
              ),
            ),
          ),

          // Food name, quantity and description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Food name and quantity (top line)
                Text(
                  '${food?.displayName ?? foodName}${carbsPerServing != null ? ' ${carbsPerServing!.toInt()}g carbs' : ''} x $quantity',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? AppColors.cream : AppColors.blackberry,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),

                // Description (bottom line)
                if (food?.description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    food!.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.cream.withValues(alpha: 0.7)
                          : AppColors.blackberry.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Increment button
          GestureDetector(
            onTap: onIncrement,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              margin: const EdgeInsets.all(4),
              child: Icon(
                Icons.add,
                color: AppColors.electrolyte,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}