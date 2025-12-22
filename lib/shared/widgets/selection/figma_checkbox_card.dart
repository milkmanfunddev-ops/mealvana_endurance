import 'package:flutter/material.dart';
import '../../../theme/kyle_design/app_colors.dart';

/// Checkbox card widget matching Figma onboarding design
///
/// Features:
/// - Cyan/green background when selected
/// - Checkbox indicator (square with checkmark when selected)
/// - White/cream text at 20px
/// - Matches Figma design specification exactly
///
/// Used in: Sports selection, allergies, and other multi-select screens
class FigmaCheckboxCard extends StatelessWidget {
  const FigmaCheckboxCard({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  /// The label text to display
  final String label;

  /// Whether this card is currently selected
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
            // Checkbox indicator
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.electrolyte : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: isSelected
                    ? null
                    : Border.all(
                        color: AppColors.textDark,
                        width: 2,
                      ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 18,
                      color: Colors.black,
                    )
                  : null,
            ),

            const SizedBox(width: 12),

            // Label text
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
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
