import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import '../../../domain/food.dart';

/// Reusable food card widget for displaying food items
/// Shows food icon, name, carbs, and category badges
class FoodCardWidget extends StatelessWidget {
  final Food food;
  final bool isUserFood;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onEdit;

  const FoodCardWidget({
    super.key,
    required this.food,
    required this.isUserFood,
    required this.onTap,
    this.onLongPress,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: AppRadius.cardRadius,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
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
                    if (food.carbsPerServing != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        '${food.carbsPerServing!.toInt()}g carbs per serving',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    // Show category badges for user foods
                    if (isUserFood && food.categories.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      _CategoryBadges(categories: food.categories),
                    ],
                  ],
                ),
              ),
              // Show edit button for user foods, plus for others
              if (isUserFood)
                IconButton(
                  icon: FaIcon(
                    FontAwesomeIcons.penToSquare,
                    color: AppColors.electrolyte.withValues(alpha: 0.7),
                    size: AppIconSizes.sm,
                  ),
                  onPressed: onEdit,
                  tooltip: 'Edit food',
                )
              else
                FaIcon(
                  FontAwesomeIcons.circlePlus,
                  color: AppColors.orange,
                  size: AppIconSizes.md,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _capitalize(String text) =>
      text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';

  /// Get the appropriate icon for a food based on its name
  IconData _getFoodIcon(String foodName) {
    final name = foodName.toLowerCase();

    // Map generic foods to specific icons
    if (name.contains('apple') && !name.contains('applesauce')) {
      return FontAwesomeIcons.appleWhole.data;
    } else if (name.contains('applesauce') || name.contains('purée')) {
      return FontAwesomeIcons.bottleDroplet.data;
    } else if (name.contains('bagel')) {
      return FontAwesomeIcons.breadSlice.data;
    } else if (name.contains('banana')) {
      return FontAwesomeIcons.appleWhole.data;
    } else if (name.contains('berr')) {
      return FontAwesomeIcons.bowlFood.data;
    } else if (name.contains('chocolate milk')) {
      return FontAwesomeIcons.bottleWater.data;
    } else if (name.contains('coconut water')) {
      return FontAwesomeIcons.bottleWater.data;
    } else if (name.contains('coffee')) {
      return FontAwesomeIcons.mugHot.data;
    } else if (name.contains('date')) {
      return FontAwesomeIcons.appleWhole.data;
    } else if (name.contains('electrolyte drink mix')) {
      return FontAwesomeIcons.flask.data;
    } else if (name.contains('electrolyte tablet')) {
      return FontAwesomeIcons.pills.data;
    } else if (name.contains('energy bar')) {
      return FontAwesomeIcons.bars.data;
    } else if (name.contains('energy chew')) {
      return FontAwesomeIcons.candyCane.data;
    } else if (name.contains('energy waffle') || name.contains('stroopwafel')) {
      return FontAwesomeIcons.cookie.data;
    } else if (name.contains('fig bar')) {
      return FontAwesomeIcons.bars.data;
    } else if (name.contains('gel')) {
      return FontAwesomeIcons.droplet.data;
    } else if (name.contains('oatmeal')) {
      return FontAwesomeIcons.bowlFood.data;
    } else if (name.contains('orange juice')) {
      return FontAwesomeIcons.glassWater.data;
    } else if (name.contains('peanut butter')) {
      return FontAwesomeIcons.jar.data;
    } else if (name.contains('pickle juice')) {
      return FontAwesomeIcons.vial.data;
    } else if (name.contains('pretzel')) {
      return FontAwesomeIcons.bowlFood.data;
    } else if (name.contains('protein bar')) {
      return FontAwesomeIcons.bars.data;
    } else if (name.contains('protein powder')) {
      return FontAwesomeIcons.jar.data;
    } else if (name.contains('protein shake')) {
      return FontAwesomeIcons.bottleWater.data;
    } else if (name.contains('salt packet')) {
      return FontAwesomeIcons.bagShopping.data;
    } else if (name.contains('sports drink mix')) {
      return FontAwesomeIcons.flask.data;
    } else if (name.contains('sports drink')) {
      return FontAwesomeIcons.bottleWater.data;
    } else if (name.contains('toast')) {
      return FontAwesomeIcons.breadSlice.data;
    } else if (name.contains('trail mix')) {
      return FontAwesomeIcons.bowlFood.data;
    } else if (name.contains('water')) {
      return FontAwesomeIcons.bottleWater.data;
    } else if (name.contains('yogurt')) {
      return FontAwesomeIcons.bowlFood.data;
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
      return FontAwesomeIcons.userPen.data;
    }

    // Default fallback icon
    return FontAwesomeIcons.utensils.data;
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

/// Build category badges for user foods
class _CategoryBadges extends StatelessWidget {
  final List<String> categories;

  const _CategoryBadges({required this.categories});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: categories.map((category) {
        final label = _categoryToLabel(category);
        final color = _getCategoryColor(category);
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Text(
            label,
            style: AppTextStyles.smallLabel.copyWith(
              color: color,
              fontSize: 10,
            ),
          ),
        );
      }).toList(),
    );
  }

  String _categoryToLabel(String category) {
    if (category.startsWith('before')) return 'Before';
    if (category.startsWith('during')) return 'During';
    if (category.startsWith('after')) return 'After';
    return category;
  }

  Color _getCategoryColor(String category) {
    if (category.startsWith('before')) return AppColors.electrolyte;
    if (category.startsWith('during')) return AppColors.orange;
    if (category.startsWith('after')) return AppColors.dragonfruit;
    return AppColors.cream;
  }
}
