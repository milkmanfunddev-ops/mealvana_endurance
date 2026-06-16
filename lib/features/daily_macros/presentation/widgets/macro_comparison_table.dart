import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../meal_logging/domain/consumed_totals.dart';
import '../../domain/daily_macro_targets.dart';
import 'macro_palette.dart';

/// At-a-glance comparison of planned vs. eaten macros.
///
/// Renders a four-column table (Calories / Carbs / Protein / Fat) with three
/// rows stacked top to bottom:
///
///   • **Planned** — the day's targets
///   • **Eaten**   — what's been logged so far
///   • **Left**    — remaining (or "over" when the eaten value exceeds plan)
///
/// Deliberately avoids progress bars / ratio fills: endurance fuelling targets
/// are a guide, not a cap, so the comparison is shown as plain aligned numbers
/// the athlete reads at a glance rather than a bar racing toward 100%.
class MacroComparisonTable extends StatelessWidget {
  const MacroComparisonTable({
    super.key,
    required this.planned,
    required this.consumed,
  });

  final DailyMacroTargets planned;
  final ConsumedTotals consumed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    final fmt = NumberFormat('#,###');

    final cols = <_MacroColumn>[
      _MacroColumn(
        label: 'CALORIES',
        accent: kMacroColorCalories,
        planned: planned.totalCalories.round().toDouble(),
        eaten: consumed.calories.toDouble(),
        format: (v) => fmt.format(v.round()),
        overFormat: (v) => '${fmt.format(v.round())} over',
      ),
      _MacroColumn(
        label: 'CARBS',
        accent: kMacroColorCarbs,
        planned: planned.carbG,
        eaten: consumed.carbsG,
        format: (v) => '${v.round()}g',
        overFormat: (v) => '${v.round()}g over',
      ),
      _MacroColumn(
        label: 'PROTEIN',
        accent: kMacroColorProtein,
        planned: planned.protG,
        eaten: consumed.proteinG,
        format: (v) => '${v.round()}g',
        overFormat: (v) => '${v.round()}g over',
      ),
      _MacroColumn(
        label: 'FAT',
        accent: kMacroColorFat,
        planned: planned.fatG,
        eaten: consumed.fatG,
        format: (v) => '${v.round()}g',
        overFormat: (v) => '${v.round()}g over',
      ),
    ];

    return Table(
      columnWidths: const {
        0: FixedColumnWidth(58),
        1: FlexColumnWidth(),
        2: FlexColumnWidth(),
        3: FlexColumnWidth(),
        4: FlexColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        _headerRow(textColor, cols),
        _dataRow(
          context,
          rowLabel: 'Planned',
          textColor: textColor,
          cols: cols,
          kind: _RowKind.planned,
        ),
        _dataRow(
          context,
          rowLabel: 'Eaten',
          textColor: textColor,
          cols: cols,
          kind: _RowKind.eaten,
        ),
        _dataRow(
          context,
          rowLabel: 'Left',
          textColor: textColor,
          cols: cols,
          kind: _RowKind.left,
        ),
      ],
    );
  }

  TableRow _headerRow(Color textColor, List<_MacroColumn> cols) {
    return TableRow(
      children: [
        // Empty corner cell.
        const SizedBox(height: 26),
        ...cols.map(
          (c) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: c.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    c.label,
                    style: AppTextStyles.macroLabel.copyWith(
                      color: textColor.withValues(alpha: 0.55),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  TableRow _dataRow(
    BuildContext context, {
    required String rowLabel,
    required Color textColor,
    required List<_MacroColumn> cols,
    required _RowKind kind,
  }) {
    final isEaten = kind == _RowKind.eaten;
    final isLeft = kind == _RowKind.left;

    final labelColor = isLeft
        ? textColor.withValues(alpha: 0.45)
        : textColor.withValues(alpha: isEaten ? 0.9 : 0.6);

    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Text(
            rowLabel,
            style: AppTextStyles.bodySmall.copyWith(
              color: labelColor,
              fontWeight: isEaten ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        ...cols.map((c) => _valueCell(c, kind, textColor)),
      ],
    );
  }

  Widget _valueCell(_MacroColumn c, _RowKind kind, Color textColor) {
    String text;
    Color color;
    FontWeight weight;

    switch (kind) {
      case _RowKind.planned:
        text = c.format(c.planned);
        color = textColor.withValues(alpha: 0.85);
        weight = FontWeight.w600;
        break;
      case _RowKind.eaten:
        text = c.format(c.eaten);
        color = textColor;
        weight = FontWeight.w800;
        break;
      case _RowKind.left:
        final remaining = c.planned - c.eaten;
        if (remaining >= 0) {
          text = c.format(remaining);
          color = textColor.withValues(alpha: 0.45);
          weight = FontWeight.w500;
        } else {
          text = c.overFormat(-remaining);
          color = AppColors.dragonfruit;
          weight = FontWeight.w600;
        }
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          maxLines: 1,
          style: AppTextStyles.bodyMedium.copyWith(
            color: color,
            fontWeight: weight,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

enum _RowKind { planned, eaten, left }

class _MacroColumn {
  const _MacroColumn({
    required this.label,
    required this.accent,
    required this.planned,
    required this.eaten,
    required this.format,
    required this.overFormat,
  });

  final String label;
  final Color accent;
  final double planned;
  final double eaten;
  final String Function(double) format;
  final String Function(double) overFormat;
}
