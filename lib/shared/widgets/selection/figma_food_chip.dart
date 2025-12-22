import 'package:flutter/material.dart';
import '../../../theme/kyle_design/app_colors.dart';

/// Food chip widget matching Figma onboarding design
///
/// Features:
/// - Cyan/green background when selected
/// - Light background when unselected
/// - 40px height, rounded corners
/// - Optional X button for removal
/// - Matches Figma design specification exactly
class FigmaFoodChip extends StatelessWidget {
  const FigmaFoodChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.onRemove,
    this.showRemoveButton = false,
  });

  /// The food name
  final String label;

  /// Whether this food is currently selected
  final bool isSelected;

  /// Called when the chip is tapped
  final VoidCallback onTap;

  /// Called when the remove button is tapped (if shown)
  final VoidCallback? onRemove;

  /// Whether to show the remove button (X)
  final bool showRemoveButton;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.electrolyte.withValues(alpha: 0.28)
              : AppColors.textDark.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.electrolyte.withValues(alpha: 0.4)
                : AppColors.textDark.withValues(alpha: 0.08),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Food name
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Apercu',
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: AppColors.textDark,
                letterSpacing: 0.192,
                height: 1.0,
              ),
            ),

            // Remove button (X icon) for selected foods section
            if (showRemoveButton && onRemove != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onRemove,
                behavior: HitTestBehavior.opaque,
                child: const Icon(
                  Icons.close,
                  size: 10,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A wrap layout of Figma-styled food chips
class FigmaFoodChipGrid extends StatelessWidget {
  const FigmaFoodChipGrid({
    super.key,
    required this.foods,
    required this.selectedFoodIds,
    required this.onFoodToggled,
  });

  /// List of foods to display
  final List<FigmaFoodChipItem> foods;

  /// Set of selected food IDs
  final Set<String> selectedFoodIds;

  /// Called when a food is toggled
  final void Function(String foodId) onFoodToggled;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: foods.map((food) {
        return FigmaFoodChip(
          label: food.name,
          isSelected: selectedFoodIds.contains(food.id),
          onTap: () => onFoodToggled(food.id),
        );
      }).toList(),
    );
  }
}

/// A section displaying selected foods with remove buttons
class FigmaSelectedFoodsSection extends StatelessWidget {
  const FigmaSelectedFoodsSection({
    super.key,
    required this.foods,
    required this.selectedFoodIds,
    required this.onFoodRemoved,
  });

  /// All available foods (to look up names)
  final List<FigmaFoodChipItem> foods;

  /// Set of selected food IDs
  final Set<String> selectedFoodIds;

  /// Called when a food is removed
  final void Function(String foodId) onFoodRemoved;

  @override
  Widget build(BuildContext context) {
    final selectedFoods = foods
        .where((f) => selectedFoodIds.contains(f.id))
        .toList();

    if (selectedFoods.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: selectedFoods.map((food) {
        return FigmaFoodChip(
          label: food.name,
          isSelected: true,
          onTap: () => onFoodRemoved(food.id),
          onRemove: () => onFoodRemoved(food.id),
          showRemoveButton: true,
        );
      }).toList(),
    );
  }
}

/// Data class for Figma food chip items
class FigmaFoodChipItem {
  const FigmaFoodChipItem({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}
