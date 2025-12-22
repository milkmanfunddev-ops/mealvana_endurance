import 'package:flutter/material.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';

/// A selectable card widget for multi-select options (checkbox style)
///
/// Used for screens where users can select multiple options, such as:
/// - Sports selection (Running, Cycling, Swimming)
/// - Allergy selection (Dairy, Gluten, etc.)
///
/// Features:
/// - Visual checkbox indicator
/// - Selected/unselected states with animation
/// - Optional icon or emoji
/// - Optional description text
class SelectableCard extends StatelessWidget {
  const SelectableCard({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.description,
    this.icon,
    this.emoji,
    this.enabled = true,
  });

  /// The main label text
  final String label;

  /// Whether this card is currently selected
  final bool isSelected;

  /// Called when the card is tapped
  final VoidCallback onTap;

  /// Optional description text below the label
  final String? description;

  /// Optional icon to display
  final IconData? icon;

  /// Optional emoji to display (takes precedence over icon)
  final String? emoji;

  /// Whether the card is enabled for interaction
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final effectiveEnabled = enabled;

    return GestureDetector(
      onTap: effectiveEnabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.orange.withValues(alpha: 0.1)
              : AppColors.surfaceLight,
          borderRadius: AppRadius.cardRadius,
          border: Border.all(
            color: isSelected
                ? AppColors.orange
                : AppColors.borderLightSecondary,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Icon or emoji
            if (emoji != null || icon != null)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: emoji != null
                    ? Text(
                        emoji!,
                        style: const TextStyle(fontSize: 24),
                      )
                    : Icon(
                        icon,
                        size: 24,
                        color: isSelected
                            ? AppColors.orange
                            : AppColors.textLightSecondary,
                      ),
              ),

            // Label and description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: effectiveEnabled
                          ? AppColors.textLight
                          : AppColors.inactive,
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      description!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textLightSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Checkbox indicator
            _CheckboxIndicator(isSelected: isSelected, enabled: effectiveEnabled),
          ],
        ),
      ),
    );
  }
}

class _CheckboxIndicator extends StatelessWidget {
  const _CheckboxIndicator({
    required this.isSelected,
    required this.enabled,
  });

  final bool isSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.orange : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSelected
              ? AppColors.orange
              : (enabled ? AppColors.borderLight : AppColors.inactive),
          width: 2,
        ),
      ),
      child: isSelected
          ? const Icon(
              Icons.check,
              size: 16,
              color: Colors.white,
            )
          : null,
    );
  }
}

/// A grid of selectable cards for displaying options in rows
class SelectableCardGrid extends StatelessWidget {
  const SelectableCardGrid({
    super.key,
    required this.items,
    required this.selectedItems,
    required this.onItemToggled,
    this.crossAxisCount = 2,
    this.mainAxisSpacing = AppSpacing.sm,
    this.crossAxisSpacing = AppSpacing.sm,
    this.childAspectRatio = 2.5,
  });

  /// List of items to display
  final List<SelectableCardItem> items;

  /// Currently selected item keys
  final Set<String> selectedItems;

  /// Called when an item is toggled
  final void Function(String key) onItemToggled;

  /// Number of columns
  final int crossAxisCount;

  /// Vertical spacing between items
  final double mainAxisSpacing;

  /// Horizontal spacing between items
  final double crossAxisSpacing;

  /// Aspect ratio of each card
  final double childAspectRatio;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return SelectableCard(
          label: item.label,
          isSelected: selectedItems.contains(item.key),
          onTap: () => onItemToggled(item.key),
          description: item.description,
          icon: item.icon,
          emoji: item.emoji,
          enabled: item.enabled,
        );
      },
    );
  }
}

/// Data class for selectable card items
class SelectableCardItem {
  const SelectableCardItem({
    required this.key,
    required this.label,
    this.description,
    this.icon,
    this.emoji,
    this.enabled = true,
  });

  final String key;
  final String label;
  final String? description;
  final IconData? icon;
  final String? emoji;
  final bool enabled;
}
