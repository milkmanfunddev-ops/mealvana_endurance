import 'package:flutter/material.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../../../theme/kyle_design/app_colors.dart';

/// Kyle-styled dropdown component
///
/// Reusable dropdown with Kyle design system styling.
/// Used in cycling, swimming, and brick tabs for session goals, terrain, etc.
class KyleDropdown extends StatelessWidget {
  const KyleDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.descriptor.copyWith(
            color: isDark ? AppColors.cream : AppColors.blackberry,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppColors.blackberry.withValues(alpha: 0.3) : AppColors.cream,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: isDark ? AppColors.cream : AppColors.blackberry,
              width: 2,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              onChanged: (newValue) {
                if (newValue != null) onChanged(newValue);
              },
              style: AppTextStyles.dataNumber.copyWith(
                color: isDark ? AppColors.cream : AppColors.blackberry,
              ),
              dropdownColor: isDark ? AppColors.blackberry : AppColors.cream,
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: isDark ? AppColors.cream : AppColors.blackberry,
                size: 24,
              ),
              items: items.entries.map<DropdownMenuItem<String>>((entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(
                    entry.value,
                    style: AppTextStyles.dataNumber.copyWith(
                      color: isDark ? AppColors.cream : AppColors.blackberry,
                      fontSize: 14,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
