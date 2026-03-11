import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../nutrition_plan/domain/food_item.dart';
import 'food_preference_slider_widget.dart';

/// A user-added food preference card with category badges and edit action
///
/// Shows:
/// - Food icon
/// - Food name (uppercase)
/// - Category badges (Before/During/After)
/// - Edit indicator icon
/// - 5-point preference slider
class UserFoodItemWidget extends ConsumerWidget {
  final FoodItem food;
  final int sliderLevel;
  final ValueChanged<int> onLevelChanged;
  final VoidCallback onEditTap;
  final KyleFoodType Function(String) mapFoodType;

  const UserFoodItemWidget({
    super.key,
    required this.food,
    required this.sliderLevel,
    required this.onLevelChanged,
    required this.onEditTap,
    required this.mapFoodType,
  });

  String _categoryToLabel(String category) {
    switch (category) {
      case 'before_run':
        return 'Before';
      case 'during_run':
        return 'During';
      case 'after_run':
        return 'After';
      default:
        return category;
    }
  }

  Color _categoryToColor(String category) {
    switch (category) {
      case 'before_run':
        return AppColors.electrolyte;
      case 'during_run':
        return AppColors.orange;
      case 'after_run':
        return AppColors.dragonfruit;
      default:
        return AppColors.cream;
    }
  }

  Widget _buildCategoryBadges(List<String> categories, bool isDark) {
    if (categories.isEmpty) {
      return Text(
        'Tap to set categories',
        style: AppTextStyles.smallLabel.copyWith(
          color: isDark ? AppColors.cream.withOpacity(0.5) : AppColors.blackberry.withOpacity(0.5),
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: categories.map((category) {
        final label = _categoryToLabel(category);
        final color = _categoryToColor(category);
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.5)),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onEditTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark ? AppColors.blackberry.withOpacity(0.3) : Theme.of(context).colorScheme.surface,
          borderRadius: AppRadius.cardRadius,
        ),
        child: Column(
          children: [
            // Food info row with edit hint
            Row(
              children: [
                // Food icon
                KyleFoodIcon(
                  foodType: mapFoodType(food.name),
                ),

                const SizedBox(width: AppSpacing.md),

                // Food name and category badges
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        food.name.toUpperCase(),
                        style: AppTextStyles.foodTitle.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      // Category badges - convert FoodCategory to strings
                      _buildCategoryBadges(food.categories.map((c) => c.dbValue).toList(), isDark),
                    ],
                  ),
                ),

                // Edit indicator
                Icon(
                  FontAwesomeIcons.penToSquare,
                  size: AppIconSizes.sm,
                  color: AppColors.electrolyte.withOpacity(0.7),
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
      ),
    );
  }
}
