import 'package:flutter/material.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';

/// A segmented selector for choosing from a set of options
///
/// Used for selecting from a small set of discrete values:
/// - Number of water bottles on bike (1, 2, 3, 4)
/// - Gut training level (Low, Moderate, High)
///
/// Features:
/// - Horizontal layout of segments
/// - Visual feedback for selected segment
/// - Supports both numeric and text options
class SegmentedSelector<T> extends StatelessWidget {
  const SegmentedSelector({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
    this.label,
    this.enabled = true,
    this.expanded = false,
  });

  /// List of options to display
  final List<SegmentedOption<T>> options;

  /// Currently selected value
  final T selectedValue;

  /// Called when an option is selected
  final void Function(T value) onSelected;

  /// Optional label above the selector
  final String? label;

  /// Whether the selector is enabled
  final bool enabled;

  /// Whether segments should expand to fill available width
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w500,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceLightSecondary,
            borderRadius: AppRadius.segmentedControlRadius,
            border: Border.all(
              color: AppColors.borderLightSecondary,
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
            children: options.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              final isSelected = option.value == selectedValue;
              final isFirst = index == 0;
              final isLast = index == options.length - 1;

              return expanded
                  ? Expanded(
                      child: _SegmentButton(
                        option: option,
                        isSelected: isSelected,
                        isFirst: isFirst,
                        isLast: isLast,
                        enabled: enabled,
                        onTap: () => onSelected(option.value),
                      ),
                    )
                  : _SegmentButton(
                      option: option,
                      isSelected: isSelected,
                      isFirst: isFirst,
                      isLast: isLast,
                      enabled: enabled,
                      onTap: () => onSelected(option.value),
                    );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _SegmentButton<T> extends StatelessWidget {
  const _SegmentButton({
    required this.option,
    required this.isSelected,
    required this.isFirst,
    required this.isLast,
    required this.enabled,
    required this.onTap,
  });

  final SegmentedOption<T> option;
  final bool isSelected;
  final bool isFirst;
  final bool isLast;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.orange : Colors.transparent,
          borderRadius: BorderRadius.horizontal(
            left: isFirst ? const Radius.circular(12) : Radius.zero,
            right: isLast ? const Radius.circular(12) : Radius.zero,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (option.icon != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                child: Icon(
                  option.icon,
                  size: 20,
                  color: isSelected ? Colors.white : AppColors.textLight,
                ),
              ),
            Text(
              option.label,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (enabled ? AppColors.textLight : AppColors.inactive),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Data class for segmented selector options
class SegmentedOption<T> {
  const SegmentedOption({
    required this.value,
    required this.label,
    this.icon,
  });

  final T value;
  final String label;
  final IconData? icon;
}

/// Convenience widget for numeric segmented selectors
class NumericSegmentedSelector extends StatelessWidget {
  const NumericSegmentedSelector({
    super.key,
    required this.min,
    required this.max,
    required this.selectedValue,
    required this.onSelected,
    this.label,
    this.enabled = true,
    this.expanded = true,
  });

  /// Minimum value
  final int min;

  /// Maximum value
  final int max;

  /// Currently selected value
  final int selectedValue;

  /// Called when a value is selected
  final void Function(int value) onSelected;

  /// Optional label above the selector
  final String? label;

  /// Whether the selector is enabled
  final bool enabled;

  /// Whether segments should expand to fill available width
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final options = List.generate(
      max - min + 1,
      (index) => SegmentedOption<int>(
        value: min + index,
        label: '${min + index}',
      ),
    );

    return SegmentedSelector<int>(
      options: options,
      selectedValue: selectedValue,
      onSelected: onSelected,
      label: label,
      enabled: enabled,
      expanded: expanded,
    );
  }
}
