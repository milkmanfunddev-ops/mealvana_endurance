import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import '../../../domain/food.dart';

/// Widget for displaying the selected food with quantity controls
/// Shows food details, nutrition info, and quantity selector
class SelectedFoodDisplayWidget extends StatelessWidget {
  final Food food;
  final double quantity;
  final ValueChanged<double> onQuantityChanged;
  final VoidCallback onClear;

  const SelectedFoodDisplayWidget({
    super.key,
    required this.food,
    required this.quantity,
    required this.onQuantityChanged,
    required this.onClear,
  });

  String _capitalize(String text) =>
      text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';

  @override
  Widget build(BuildContext context) {
    final totalCarbs = (food.carbsPerServing ?? 0) * quantity;
    final totalProtein = (food.proteinPerServing ?? 0) * quantity;
    final totalFat = (food.fatPerServing ?? 0) * quantity;
    final totalCalories = ((food.caloriesPerServing ?? 0) * quantity).toInt();

    return BaseCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Food header
            Row(
              children: [
                // Food icon with colored circular background
                Container(
                  width: AppIconSizes.foodIcon,
                  height: AppIconSizes.foodIcon,
                  decoration: BoxDecoration(
                    color: _getFoodIconColor(food.name),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getFoodIcon(food.name),
                    size: AppIconSizes.controlIcon,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _capitalize(food.displayName ?? food.name),
                        style: AppTextStyles.foodTitle.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      if (food.description?.isNotEmpty == true) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          food.description!,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    FontAwesomeIcons.xmark,
                    size: AppIconSizes.controlIcon,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  onPressed: onClear,
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // Quantity control
            KylePlusMinusDecimalControl(
              value: quantity,
              onChanged: onQuantityChanged,
              min: 0.5,
              max: 10.0,
              step: 0.5,
              decimalPlaces: 1,
              label: 'QUANTITY',
            ),

            const SizedBox(height: AppSpacing.lg),

            // Nutrition info
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.electrolyte.withValues(alpha: 0.1),
                borderRadius: AppRadius.smRadius,
              ),
              child: Column(
                children: [
                  _NutrientRow(label: 'Carbohydrates', value: '${totalCarbs.toStringAsFixed(1)} g'),
                  const SizedBox(height: AppSpacing.sm),
                  _NutrientRow(label: 'Protein', value: '${totalProtein.toStringAsFixed(1)} g'),
                  const SizedBox(height: AppSpacing.sm),
                  _NutrientRow(label: 'Fat', value: '${totalFat.toStringAsFixed(1)} g'),
                  const SizedBox(height: AppSpacing.sm),
                  _NutrientRow(label: 'Calories', value: '$totalCalories kcal'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get the appropriate icon for a food based on its name
  IconData _getFoodIcon(String foodName) {
    final name = foodName.toLowerCase();

    // Map generic foods to specific icons
    if (name.contains('apple') && !name.contains('applesauce')) {
      return FontAwesomeIcons.appleWhole;
    } else if (name.contains('applesauce') || name.contains('purée')) {
      return FontAwesomeIcons.bottleDroplet;
    } else if (name.contains('bagel')) {
      return FontAwesomeIcons.breadSlice;
    } else if (name.contains('banana')) {
      return FontAwesomeIcons.appleWhole;
    } else if (name.contains('berr')) {
      return FontAwesomeIcons.bowlFood;
    } else if (name.contains('chocolate milk')) {
      return FontAwesomeIcons.bottleWater;
    } else if (name.contains('coconut water')) {
      return FontAwesomeIcons.bottleWater;
    } else if (name.contains('coffee')) {
      return FontAwesomeIcons.mugHot;
    } else if (name.contains('date')) {
      return FontAwesomeIcons.appleWhole;
    } else if (name.contains('electrolyte drink mix')) {
      return FontAwesomeIcons.flask;
    } else if (name.contains('electrolyte tablet')) {
      return FontAwesomeIcons.pills;
    } else if (name.contains('energy bar')) {
      return FontAwesomeIcons.bars;
    } else if (name.contains('energy chew')) {
      return FontAwesomeIcons.candyCane;
    } else if (name.contains('energy waffle') || name.contains('stroopwafel')) {
      return FontAwesomeIcons.cookie;
    } else if (name.contains('fig bar')) {
      return FontAwesomeIcons.bars;
    } else if (name.contains('gel')) {
      return FontAwesomeIcons.droplet;
    } else if (name.contains('oatmeal')) {
      return FontAwesomeIcons.bowlFood;
    } else if (name.contains('orange juice')) {
      return FontAwesomeIcons.glassWater;
    } else if (name.contains('peanut butter')) {
      return FontAwesomeIcons.jar;
    } else if (name.contains('pickle juice')) {
      return FontAwesomeIcons.vial;
    } else if (name.contains('pretzel')) {
      return FontAwesomeIcons.bowlFood;
    } else if (name.contains('protein bar')) {
      return FontAwesomeIcons.bars;
    } else if (name.contains('protein powder')) {
      return FontAwesomeIcons.jar;
    } else if (name.contains('protein shake')) {
      return FontAwesomeIcons.bottleWater;
    } else if (name.contains('salt packet')) {
      return FontAwesomeIcons.bagShopping;
    } else if (name.contains('sports drink mix')) {
      return FontAwesomeIcons.flask;
    } else if (name.contains('sports drink')) {
      return FontAwesomeIcons.bottleWater;
    } else if (name.contains('toast')) {
      return FontAwesomeIcons.breadSlice;
    } else if (name.contains('trail mix')) {
      return FontAwesomeIcons.bowlFood;
    } else if (name.contains('water')) {
      return FontAwesomeIcons.bottleWater;
    } else if (name.contains('yogurt')) {
      return FontAwesomeIcons.bowlFood;
    }

    // Check if this is likely a user-imported food
    final knownGenericFoods = [
      'apple', 'applesauce', 'purée', 'bagel', 'banana', 'berr',
      'chocolate milk', 'coconut water', 'coffee', 'date',
      'electrolyte drink', 'electrolyte tablet', 'energy bar',
      'energy chew', 'energy waffle', 'stroopwafel', 'fig bar',
      'gel', 'oatmeal', 'orange juice', 'peanut butter',
      'pickle juice', 'pretzel', 'protein bar', 'protein powder',
      'protein shake', 'salt packet', 'sports drink', 'toast',
      'trail mix', 'water', 'yogurt',
    ];

    // If none of the generic food keywords match, it's likely user-imported
    if (!knownGenericFoods.any((keyword) => name.contains(keyword))) {
      return FontAwesomeIcons.userPen;
    }

    // Default fallback icon
    return FontAwesomeIcons.utensils;
  }

  /// Get the background color for the food icon
  Color _getFoodIconColor(String foodName) {
    final name = foodName.toLowerCase();

    final knownGenericFoods = [
      'apple', 'applesauce', 'purée', 'bagel', 'banana', 'berr',
      'chocolate milk', 'coconut water', 'coffee', 'date',
      'electrolyte drink', 'electrolyte tablet', 'energy bar',
      'energy chew', 'energy waffle', 'stroopwafel', 'fig bar',
      'gel', 'oatmeal', 'orange juice', 'peanut butter',
      'pickle juice', 'pretzel', 'protein bar', 'protein powder',
      'protein shake', 'salt packet', 'sports drink', 'toast',
      'trail mix', 'water', 'yogurt',
    ];

    // User-imported foods get orange color
    if (!knownGenericFoods.any((keyword) => name.contains(keyword))) {
      return AppColors.orange;
    }

    // Generic foods get electrolyte color
    return AppColors.electrolyte;
  }
}

/// Internal widget for displaying a nutrient row
class _NutrientRow extends StatelessWidget {
  final String label;
  final String value;

  const _NutrientRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
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
            color: AppColors.electrolyte,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
