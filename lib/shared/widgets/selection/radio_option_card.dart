import 'package:flutter/material.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';

/// A radio-style option card for single-select scenarios
///
/// Used for screens where users select exactly one option, such as:
/// - Dietary preference (Omnivore, Vegetarian, Vegan, etc.)
/// - Swim cap type (None, Silicone, Latex, Neoprene)
///
/// Features:
/// - Visual radio indicator
/// - Selected/unselected states with animation
/// - Optional icon or emoji
/// - Optional description text
class RadioOptionCard extends StatelessWidget {
  const RadioOptionCard({
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
            // Radio indicator
            _RadioIndicator(isSelected: isSelected, enabled: effectiveEnabled),

            const SizedBox(width: AppSpacing.sm),

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
          ],
        ),
      ),
    );
  }
}

class _RadioIndicator extends StatelessWidget {
  const _RadioIndicator({
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
        shape: BoxShape.circle,
        color: Colors.transparent,
        border: Border.all(
          color: isSelected
              ? AppColors.orange
              : (enabled ? AppColors.borderLight : AppColors.inactive),
          width: 2,
        ),
      ),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: isSelected ? 12 : 0,
          height: isSelected ? 12 : 0,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected ? AppColors.orange : Colors.transparent,
          ),
        ),
      ),
    );
  }
}

/// A list of radio option cards for displaying single-select options
class RadioOptionList<T> extends StatelessWidget {
  const RadioOptionList({
    super.key,
    required this.items,
    required this.selectedValue,
    required this.onSelected,
    this.spacing = AppSpacing.sm,
  });

  /// List of items to display
  final List<RadioOptionItem<T>> items;

  /// Currently selected value (null if none selected)
  final T? selectedValue;

  /// Called when an item is selected
  final void Function(T value) onSelected;

  /// Vertical spacing between items
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.map((item) {
        final index = items.indexOf(item);
        return Padding(
          padding: EdgeInsets.only(
            bottom: index < items.length - 1 ? spacing : 0,
          ),
          child: RadioOptionCard(
            label: item.label,
            isSelected: selectedValue == item.value,
            onTap: () => onSelected(item.value),
            description: item.description,
            icon: item.icon,
            emoji: item.emoji,
            enabled: item.enabled,
          ),
        );
      }).toList(),
    );
  }
}

/// Data class for radio option items
class RadioOptionItem<T> {
  const RadioOptionItem({
    required this.value,
    required this.label,
    this.description,
    this.icon,
    this.emoji,
    this.enabled = true,
  });

  final T value;
  final String label;
  final String? description;
  final IconData? icon;
  final String? emoji;
  final bool enabled;
}
