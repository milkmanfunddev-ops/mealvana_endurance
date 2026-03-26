import 'package:flutter/material.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';

/// Displays macro breakdown with colored dot indicators matching the weekly chart:
/// Carbs = electrolyte, Protein = orange, Fat = dragonfruit
class MacroBreakdownRow extends StatelessWidget {
  const MacroBreakdownRow({
    super.key,
    required this.carbG,
    required this.protG,
    required this.fatG,
    this.textColor,
  });

  final double carbG;
  final double protG;
  final double fatG;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final color = textColor ?? Theme.of(context).colorScheme.onSurface;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _MacroChip(
          label: 'Carbs',
          value: '${carbG.round()}g',
          dotColor: AppColors.electrolyte,
          textColor: color,
        ),
        _MacroChip(
          label: 'Protein',
          value: '${protG.round()}g',
          dotColor: AppColors.orange,
          textColor: color,
        ),
        _MacroChip(
          label: 'Fat',
          value: '${fatG.round()}g',
          dotColor: AppColors.dragonfruit,
          textColor: color,
        ),
      ],
    );
  }
}

class _MacroChip extends StatelessWidget {
  const _MacroChip({
    required this.label,
    required this.value,
    required this.dotColor,
    required this.textColor,
  });

  final String label;
  final String value;
  final Color dotColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: AppTextStyles.bodySmall.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: textColor.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
