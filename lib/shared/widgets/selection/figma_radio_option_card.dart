import 'package:flutter/material.dart';
import '../../../theme/kyle_design/app_colors.dart';

/// Radio option card widget matching Figma onboarding design
///
/// Features:
/// - Cyan/green background with checkmark when selected
/// - Light purple background with radio circle when unselected
/// - 16px padding, 16px border radius
/// - 20px Apercu text in cream
/// - Matches Figma design specification exactly
class FigmaRadioOptionCard extends StatelessWidget {
  const FigmaRadioOptionCard({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  /// The option label text
  final String label;

  /// Whether this option is currently selected
  final bool isSelected;

  /// Called when the card is tapped
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.electrolyte.withValues(alpha: 0.28)
              : AppColors.textDark.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.electrolyte.withValues(alpha: 0.2)
                : AppColors.textDark.withValues(alpha: 0.08),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Icon indicator (checkmark when selected, radio when unselected)
            SizedBox(
              width: 24,
              height: 24,
              child: isSelected
                  ? Icon(
                      Icons.check_circle,
                      size: 24,
                      color: AppColors.electrolyte,
                    )
                  : Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.textDark,
                          width: 2,
                        ),
                      ),
                    ),
            ),

            const SizedBox(width: 12),

            // Label text
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Apercu',
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textDark,
                  letterSpacing: 0.24,
                  height: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A list of Figma-styled radio option cards
class FigmaRadioOptionList<T> extends StatelessWidget {
  const FigmaRadioOptionList({
    super.key,
    required this.items,
    required this.selectedValue,
    required this.onSelected,
  });

  /// List of items to display
  final List<FigmaRadioOptionItem<T>> items;

  /// Currently selected value (null if none selected)
  final T? selectedValue;

  /// Called when an item is selected
  final void Function(T value) onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.map((item) {
        final index = items.indexOf(item);
        return Padding(
          padding: EdgeInsets.only(
            bottom: index < items.length - 1 ? 12 : 0,
          ),
          child: FigmaRadioOptionCard(
            label: item.label,
            isSelected: selectedValue == item.value,
            onTap: () => onSelected(item.value),
          ),
        );
      }).toList(),
    );
  }
}

/// Data class for Figma radio option items
class FigmaRadioOptionItem<T> {
  const FigmaRadioOptionItem({
    required this.value,
    required this.label,
  });

  final T value;
  final String label;
}
