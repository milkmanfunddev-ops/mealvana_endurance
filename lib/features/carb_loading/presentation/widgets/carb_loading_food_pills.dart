import 'package:flutter/material.dart';
import '../../domain/carb_foods_list.dart';

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

  const CarbLoadingFoodPill({
    super.key,
    required this.foodName,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final food = CarbFoodsList.getFoodByName(foodName);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF4285F4),
        borderRadius: BorderRadius.circular(25),
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
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              margin: const EdgeInsets.all(4),
              child: const Icon(
                Icons.remove,
                color: Color(0xFF4285F4),
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
                  '${food?.displayName ?? foodName} x $quantity',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
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
                      color: Colors.white.withValues(alpha: 0.8),
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
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              margin: const EdgeInsets.all(4),
              child: const Icon(
                Icons.add,
                color: Color(0xFF4285F4),
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}