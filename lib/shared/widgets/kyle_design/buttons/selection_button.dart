import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';

/// A reusable selection button widget following Kyle's design system.
///
/// Supports both horizontal and vertical layouts, optional icons,
/// and full dark/light theme support.
///
/// Example usage:
/// ```dart
/// KyleSelectionButton<int>(
///   value: 1,
///   isSelected: selectedValue == 1,
///   onTap: () => setState(() => selectedValue = 1),
///   label: '1',
/// )
/// ```
class KyleSelectionButton<T> extends ConsumerWidget {
  const KyleSelectionButton({
    super.key,
    required this.value,
    required this.isSelected,
    required this.onTap,
    required this.label,
    this.icon,
    this.width,
    this.height,
    this.margin,
  });

  /// The value this button represents
  final T value;

  /// Whether this button is currently selected
  final bool isSelected;

  /// Callback when button is tapped
  final VoidCallback onTap;

  /// The text label to display
  final String label;

  /// Optional icon to display above the label
  final IconData? icon;

  /// Optional width override (defaults to flexible or full width based on context)
  final double? width;

  /// Optional height override
  final double? height;

  /// Optional margin around the button
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        margin: margin,
        padding: icon != null
            ? const EdgeInsets.symmetric(
                vertical: AppSpacing.sm,
                horizontal: AppSpacing.xs,
              )
            : const EdgeInsets.symmetric(
                vertical: AppSpacing.md,
                horizontal: AppSpacing.sm,
              ),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.cream : AppColors.blackberry)
              : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? (isDark ? AppColors.cream : AppColors.blackberry)
                : (isDark
                    ? AppColors.cream.withValues(alpha: 0.3)
                    : AppColors.blackberry.withValues(alpha: 0.3)),
            width: 2,
          ),
          borderRadius: AppRadius.inputRadius,
        ),
        child: icon != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 28,
                    color: isSelected
                        ? (isDark ? AppColors.blackberry : AppColors.cream)
                        : (isDark
                            ? AppColors.cream.withValues(alpha: 0.5)
                            : AppColors.blackberry.withValues(alpha: 0.5)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.smallLabel.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? (isDark ? AppColors.blackberry : AppColors.cream)
                          : (isDark
                              ? AppColors.cream.withValues(alpha: 0.5)
                              : AppColors.blackberry.withValues(alpha: 0.5)),
                    ),
                  ),
                ],
              )
            : Text(
                label,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isSelected
                      ? (isDark ? AppColors.blackberry : AppColors.cream)
                      : (isDark
                          ? AppColors.cream.withValues(alpha: 0.7)
                          : AppColors.blackberry.withValues(alpha: 0.7)),
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

/// A helper widget for creating a group of selection buttons in a row.
///
/// Example usage:
/// ```dart
/// KyleSelectionButtonGroup<int>(
///   values: [1, 2, 3],
///   selectedValue: selectedValue,
///   onChanged: (value) => setState(() => selectedValue = value),
///   labelBuilder: (value) => value == 3 ? '3+' : '$value',
/// )
/// ```
class KyleSelectionButtonGroup<T> extends StatelessWidget {
  const KyleSelectionButtonGroup({
    super.key,
    required this.values,
    required this.selectedValue,
    required this.onChanged,
    required this.labelBuilder,
    this.iconBuilder,
    this.spacing = AppSpacing.xs,
  });

  /// List of values for the buttons
  final List<T> values;

  /// Currently selected value
  final T selectedValue;

  /// Callback when selection changes
  final ValueChanged<T> onChanged;

  /// Builder function to create label for each value
  final String Function(T value) labelBuilder;

  /// Optional builder function to create icon for each value
  final IconData? Function(T value)? iconBuilder;

  /// Spacing between buttons
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: values.asMap().entries.map((entry) {
        final index = entry.key;
        final value = entry.value;
        final isLast = index == values.length - 1;

        return Expanded(
          child: KyleSelectionButton<T>(
            value: value,
            isSelected: selectedValue == value,
            onTap: () => onChanged(value),
            label: labelBuilder(value),
            icon: iconBuilder?.call(value),
            margin: EdgeInsets.only(right: isLast ? 0 : spacing),
          ),
        );
      }).toList(),
    );
  }
}
