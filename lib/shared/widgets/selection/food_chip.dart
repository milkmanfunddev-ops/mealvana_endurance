import 'package:flutter/material.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';

/// A chip widget for selecting food preferences
///
/// Used in the food preferences onboarding screen for quick selection.
/// Tap to like a food, tap again to unlike (back to neutral).
///
/// Features:
/// - Compact chip design for dense layouts
/// - Visual feedback for liked state
/// - Optional food icon/image
/// - Remove button when selected (in selected section)
class FoodChip extends StatelessWidget {
  const FoodChip({
    super.key,
    required this.label,
    required this.isLiked,
    required this.onTap,
    this.onRemove,
    this.imageUrl,
    this.showRemoveButton = false,
    this.enabled = true,
    this.isFiltered = false,
  });

  /// The food name
  final String label;

  /// Whether this food is currently liked
  final bool isLiked;

  /// Called when the chip is tapped
  final VoidCallback onTap;

  /// Called when the remove button is tapped (if shown)
  final VoidCallback? onRemove;

  /// Optional image URL for the food
  final String? imageUrl;

  /// Whether to show the remove button (X)
  final bool showRemoveButton;

  /// Whether the chip is enabled for interaction
  final bool enabled;

  /// Whether this food is filtered out due to dietary/allergy restrictions
  final bool isFiltered;

  @override
  Widget build(BuildContext context) {
    if (isFiltered) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isLiked
              ? AppColors.orange.withValues(alpha: 0.15)
              : AppColors.surfaceLight,
          borderRadius: AppRadius.circularRadius,
          border: Border.all(
            color: isLiked ? AppColors.orange : AppColors.borderLightSecondary,
            width: isLiked ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Food image or placeholder
            if (imageUrl != null)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl!,
                    width: 24,
                    height: 24,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.fastfood_outlined,
                      size: 20,
                      color: isLiked
                          ? AppColors.orange
                          : AppColors.textLightSecondary,
                    ),
                  ),
                ),
              ),

            // Like indicator when selected
            if (isLiked && !showRemoveButton)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xxs),
                child: Icon(
                  Icons.favorite,
                  size: 16,
                  color: AppColors.orange,
                ),
              ),

            // Food name
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: isLiked ? FontWeight.w600 : FontWeight.w500,
                color: enabled ? AppColors.textLight : AppColors.inactive,
              ),
            ),

            // Remove button (for selected foods section)
            if (showRemoveButton && onRemove != null) ...[
              const SizedBox(width: AppSpacing.xs),
              GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.textLightSecondary.withValues(alpha: 0.2),
                  ),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: AppColors.textLightSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A wrap layout of food chips for displaying food options
class FoodChipGrid extends StatelessWidget {
  const FoodChipGrid({
    super.key,
    required this.foods,
    required this.likedFoodIds,
    required this.onFoodToggled,
    this.filteredFoodIds = const {},
    this.spacing = AppSpacing.xs,
    this.runSpacing = AppSpacing.xs,
  });

  /// List of foods to display
  final List<FoodChipItem> foods;

  /// Set of liked food IDs
  final Set<String> likedFoodIds;

  /// Called when a food is toggled
  final void Function(String foodId) onFoodToggled;

  /// Set of food IDs that are filtered out due to dietary/allergy restrictions
  final Set<String> filteredFoodIds;

  /// Horizontal spacing between chips
  final double spacing;

  /// Vertical spacing between rows
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    // Filter out foods that should be hidden
    final visibleFoods = foods
        .where((food) => !filteredFoodIds.contains(food.id))
        .toList();

    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: visibleFoods.map((food) {
        return FoodChip(
          label: food.name,
          isLiked: likedFoodIds.contains(food.id),
          onTap: () => onFoodToggled(food.id),
          imageUrl: food.imageUrl,
          enabled: food.enabled,
          isFiltered: false,
        );
      }).toList(),
    );
  }
}

/// A section displaying selected (liked) foods with remove buttons
class SelectedFoodsSection extends StatelessWidget {
  const SelectedFoodsSection({
    super.key,
    required this.foods,
    required this.likedFoodIds,
    required this.onFoodRemoved,
    this.title = 'Your favorites',
    this.emptyMessage = 'Tap foods below to add them here',
  });

  /// All available foods (to look up names)
  final List<FoodChipItem> foods;

  /// Set of liked food IDs
  final Set<String> likedFoodIds;

  /// Called when a food is removed
  final void Function(String foodId) onFoodRemoved;

  /// Section title
  final String title;

  /// Message to show when no foods are selected
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final likedFoods = foods.where((f) => likedFoodIds.contains(f.id)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textLightSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (likedFoods.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: AppRadius.smRadius,
              border: Border.all(
                color: AppColors.borderLightSecondary,
                style: BorderStyle.solid,
              ),
            ),
            child: Text(
              emptyMessage,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textLightSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: likedFoods.map((food) {
              return FoodChip(
                label: food.name,
                isLiked: true,
                onTap: () => onFoodRemoved(food.id),
                onRemove: () => onFoodRemoved(food.id),
                imageUrl: food.imageUrl,
                showRemoveButton: true,
              );
            }).toList(),
          ),
      ],
    );
  }
}

/// Data class for food chip items
class FoodChipItem {
  const FoodChipItem({
    required this.id,
    required this.name,
    this.imageUrl,
    this.enabled = true,
  });

  final String id;
  final String name;
  final String? imageUrl;
  final bool enabled;
}
