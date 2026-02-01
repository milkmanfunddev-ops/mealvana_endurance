import 'package:flutter/material.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../../../theme/kyle_design/app_colors.dart';

/// Indoor/Outdoor toggle for cycling activities.
///
/// Reusable toggle with Kyle design system styling.
/// Used in cycling tab and brick cycling segment.
class IndoorOutdoorToggle extends StatelessWidget {
  const IndoorOutdoorToggle({
    super.key,
    required this.isIndoor,
    required this.onChanged,
    required this.isDark,
  });

  final bool isIndoor;
  final ValueChanged<bool> onChanged;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: KyleToggleButton(
            label: 'Outdoor',
            isSelected: !isIndoor,
            onTap: () => onChanged(false),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: KyleToggleButton(
            label: 'Indoor',
            isSelected: isIndoor,
            onTap: () => onChanged(true),
            isDark: isDark,
          ),
        ),
      ],
    );
  }
}

/// Individual toggle button with Kyle design system styling.
///
/// Generic toggle button used in IndoorOutdoorToggle and other binary toggles.
class KyleToggleButton extends StatelessWidget {
  const KyleToggleButton({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final selectedBg = isDark ? AppColors.cream : AppColors.blackberry;
    final selectedText = isDark ? AppColors.blackberry : AppColors.cream;
    final unselectedText = isDark ? AppColors.cream : AppColors.blackberry;
    final borderColor = isDark ? AppColors.cream : AppColors.blackberry;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.descriptor.copyWith(
              color: isSelected ? selectedText : unselectedText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
