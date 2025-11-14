import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import '../../../features/nutrition_plan/domain/food.dart';
import '../../../features/auth/domain/user_preferences.dart';
import '../food_preference_widget.dart';

/// Unified food item display tile
/// Configurable for different contexts (preferences, swap, recommendations)
class FoodItemTile extends StatelessWidget {
  const FoodItemTile({
    super.key,
    required this.food,
    required this.onTap,
    this.showPreference = false,
    this.selectedPreference,
    this.onPreferenceChanged,
    this.isAvoided = false,
    this.showDeleteButton = false,
    this.onDelete,
    this.likeLabel = 'Love',
    this.willingLabel = 'Willing to Try',
    this.dislikeLabel = 'Avoid',
  });

  final Food food;
  final VoidCallback onTap;
  final bool showPreference;
  final FoodPreference? selectedPreference;
  final Function(FoodPreference)? onPreferenceChanged;
  final bool isAvoided;
  final bool showDeleteButton;
  final VoidCallback? onDelete;
  final String likeLabel;
  final String willingLabel;
  final String dislikeLabel;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isAvoided ? 0.5 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: showPreference ? _buildPreferenceItem() : _buildSimpleItem(context),
    );
  }

  /// Build item with preference selection (for preferences screen)
  Widget _buildPreferenceItem() {
    return FoodPreferenceChipItem(
      food: _convertToFoodItem(),
      selected: selectedPreference ?? FoodPreference.willingToTry,
      likeLabel: likeLabel,
      willingLabel: willingLabel,
      dislikeLabel: dislikeLabel,
      showDeleteButton: showDeleteButton,
      onChanged: onPreferenceChanged ?? (_) {},
      onDelete: onDelete,
    );
  }

  /// Build simple item (for swap/add screens)
  Widget _buildSimpleItem(BuildContext context) {
    return BaseCard(
      child: InkWell(
        onTap: onTap,
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

              // Food name and details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.displayName ?? food.name,
                      style: AppTextStyles.foodTitle.copyWith(
                        color: isAvoided
                          ? AppColors.dragonfruit
                          : Theme.of(context).colorScheme.onSurface,
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
                    if (isAvoided) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Marked as Avoid',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.dragonfruit,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Action indicator
              Icon(
                FontAwesomeIcons.circlePlus,
                color: isAvoided ? AppColors.dragonfruit : AppColors.orange,
                size: AppIconSizes.md,
              ),
            ],
          ),
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

  /// Convert Food to FoodItem for compatibility with existing widgets
  /// TODO: Refactor FoodPreferenceChipItem to use Food directly
  dynamic _convertToFoodItem() {
    return FoodItemMock(
      id: food.id,
      name: food.name,
      displayName: food.displayName,
      imageAddress: food.imageUrl,
    );
  }
}

/// Temporary mock class to satisfy FoodPreferenceChipItem interface
/// TODO: Refactor FoodPreferenceChipItem to use Food domain object
class FoodItemMock {
  const FoodItemMock({
    required this.id,
    required this.name,
    this.displayName,
    this.imageAddress,
  });

  final String id;
  final String name;
  final String? displayName;
  final String? imageAddress;
}