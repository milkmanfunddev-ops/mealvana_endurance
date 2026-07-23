import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import '../../../features/nutrition_plan/domain/food.dart';
import '../../../features/auth/domain/user_preferences.dart';
import 'food_item_tile.dart';

/// Widget for displaying recommended alternatives
/// Used in swap food and add food screens
/// Uses Kyle's design system for consistent styling
class RecommendedAlternatives extends StatelessWidget {
  const RecommendedAlternatives({
    super.key,
    required this.foods,
    required this.onFoodSelected,
    required this.preferences,
    this.title = 'Recommended Alternatives',
    this.maxItems = 10,
    this.userFoodIds = const {},
    this.onEditUserFood,
  });

  final List<Food> foods;
  final Function(Food) onFoodSelected;
  final Map<String, FoodPreference> preferences;
  final String title;
  final int maxItems;

  /// Set of food IDs that are user foods (editable)
  final Set<String> userFoodIds;

  /// Callback when user wants to edit a user food
  final Function(Food)? onEditUserFood;

  @override
  Widget build(BuildContext context) {
    // Limit to maxItems
    final displayFoods = foods.take(maxItems).toList();

    if (displayFoods.isEmpty) {
      return _buildEmptyState(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            title,
            style: AppTextStyles.sectionTitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // Foods list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: displayFoods.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final food = displayFoods[index];
              final preference = preferences[food.name];
              final isAvoided = preference == FoodPreference.dislike;
              final isUserFood = userFoodIds.contains(food.id);

              return FoodItemTile(
                food: food,
                onTap: () => onFoodSelected(food),
                isAvoided: isAvoided,
                showPreference:
                    false, // Don't show preference chips in recommendations
                showEditButton: isUserFood && onEditUserFood != null,
                onEdit: isUserFood && onEditUserFood != null
                    ? () => onEditUserFood!(food)
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              FaIcon(
                FontAwesomeIcons.utensils,
                size: AppIconSizes.xl,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'No recommendations available',
                textAlign: TextAlign.center,
                style: AppTextStyles.subtitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Try searching for foods or use the barcode scanner',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
