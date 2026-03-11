import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../nutrition_plan/domain/food_item.dart';
import 'food_preference_slider_widget.dart';

/// A food preference card displaying food name, icon, and slider
///
/// Shows:
/// - Food icon (via KyleFoodIcon)
/// - Food name in uppercase
/// - 5-point preference slider
class FoodPreferenceItemWidget extends ConsumerWidget {
  final FoodItem food;
  final int sliderLevel;
  final ValueChanged<int> onLevelChanged;
  final KyleFoodType Function(String) mapFoodType;

  const FoodPreferenceItemWidget({
    super.key,
    required this.food,
    required this.sliderLevel,
    required this.onLevelChanged,
    required this.mapFoodType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.blackberry.withOpacity(0.3) : Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Column(
        children: [
          // Food info row
          Row(
            children: [
              // Food icon
              KyleFoodIcon(
                foodType: mapFoodType(food.name),
              ),

              const SizedBox(width: AppSpacing.md),

              // Food name
              Expanded(
                child: Text(
                  food.name.toUpperCase(),
                  style: AppTextStyles.foodTitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Preference slider
          FoodPreferenceSliderWidget(
            sliderLevel: sliderLevel,
            onLevelChanged: onLevelChanged,
          ),
        ],
      ),
    );
  }
}
