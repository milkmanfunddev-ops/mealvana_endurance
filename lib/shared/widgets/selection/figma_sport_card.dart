import 'package:flutter/material.dart';
import '../../../theme/kyle_design/app_colors.dart';

/// Sport selection card matching Figma onboarding design
///
/// Features:
/// - Cyan/green background when selected
/// - Checkbox indicator (no emoji/icon)
/// - White text at 20px Inter Medium
/// - Matches Figma design specification exactly
class FigmaSportCard extends StatelessWidget {
  const FigmaSportCard({
    super.key,
    required this.sportName,
    required this.isSelected,
    required this.onTap,
  });

  /// The name of the sport (e.g., "Running", "Cycling", "Swimming")
  final String sportName;

  /// Whether this card is currently selected
  final bool isSelected;

  /// Called when the card is tapped
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
            width: 1,
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
                    : Border.all(color: AppColors.textDark, width: 2),
              ),
              child: isSelected
                  ? Icon(Icons.check, size: 18, color: Colors.white)
                  : null,
            ),

            const SizedBox(width: 12),

            // Sport name
            Expanded(
              child: Text(
                sportName,
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
