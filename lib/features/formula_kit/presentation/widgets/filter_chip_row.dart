import 'package:flutter/material.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';

/// A single horizontally-scrolling row of toggleable filter chips.
///
/// Used for the per-phase chip rows on the Formula Library browse screen
/// (Timing for Before; Activity / Duration for During).
class FilterChipRow<T> extends StatelessWidget {
  const FilterChipRow({
    super.key,
    required this.options,
    required this.labelOf,
    required this.isSelected,
    required this.onToggled,
    this.keyOf,
  });

  final List<T> options;
  final String Function(T value) labelOf;
  final bool Function(T value) isSelected;
  final ValueChanged<T> onToggled;

  /// Optional per-chip key, used by patrol integration tests to address
  /// individual chips without depending on label strings.
  final Key Function(T value)? keyOf;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final opt = options[i];
          return _Chip(
            key: keyOf?.call(opt),
            label: labelOf(opt),
            selected: isSelected(opt),
            onTap: () => onToggled(opt),
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = selected
        ? AppColors.electrolyte.withValues(alpha: 0.25)
        : scheme.surfaceContainerHighest;
    final border = selected ? AppColors.electrolyte : scheme.outlineVariant;
    return Material(
      color: bg,
      borderRadius: AppRadius.circularRadius,
      child: InkWell(
        borderRadius: AppRadius.circularRadius,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.circularRadius,
            border: Border.all(color: border, width: 1),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
