import 'package:flutter/material.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/inputs/kyle_switch.dart';
import '../../../theme/kyle_design/app_colors.dart';

/// Toggle card widget matching Figma onboarding design
///
/// Features:
/// - Light purple background (rgba(248,246,235,0.08))
/// - Toggle switch on the right (cyan when on)
/// - 16px horizontal padding, 4px vertical padding
/// - 16px border radius
/// - 20px Inter Regular text in cream
/// - Matches Figma design specification exactly
class FigmaToggleCard extends StatelessWidget {
  const FigmaToggleCard({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  /// The label text
  final String label;

  /// Current toggle value
  final bool value;

  /// Called when the toggle value changes
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.textDark.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.textDark.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Label text
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.w400,
                color: AppColors.textDark,
                letterSpacing: 0.24,
                height: 1.0,
              ),
            ),
          ),

          // Toggle switch (48x48 touch target)
          SizedBox(
            width: 48,
            height: 48,
            child: FittedBox(
              fit: BoxFit.contain,
              child: KyleSwitch(
                value: value,
                onChanged: onChanged,
                activeTrackColor: AppColors.electrolyte,
                inactiveTrackColor: AppColors.textDark.withValues(alpha: 0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
