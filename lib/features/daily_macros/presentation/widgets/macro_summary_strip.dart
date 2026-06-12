import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../calendar/presentation/providers/calendar_selected_date_provider.dart';
import '../../../meal_logging/domain/consumed_totals.dart';
import '../../../meal_logging/presentation/providers/meal_log_providers.dart';
import '../../domain/daily_macro_targets.dart';
import 'today_hero_card.dart'
    show kMacroColorCarbs, kMacroColorProtein, kMacroColorFat;

// ---------------------------------------------------------------------------
// Fixed-extent pinned macro summary strip — "Eaten / Plan" parallel rows
// ---------------------------------------------------------------------------

/// The permanent macro summary strip pinned at the top of the Daily Macros
/// scroll.
///
/// Two parallel facts, deliberately NOT framed as a quota — no bars, no
/// rings, no "x / y" fractions, no remaining/over language:
///
///   Eaten   1,389 kcal   C 144 · P 89 · F 53
///   Plan    2,530 kcal   C 305 · P 107 · F 98
///
/// "Eaten" is what the athlete logged (bold); "Plan" is what today's training
/// calls for (subdued reference). The whole card taps through to the
/// "Today's Fueling" detail sheet; the trends icon is its own tap target.
class MacroSummaryStrip extends ConsumerWidget {
  const MacroSummaryStrip({
    super.key,
    required this.macros,
    required this.onTrendsPressed,
    required this.onDetailPressed,
  });

  final DailyMacroTargets macros;
  final VoidCallback onTrendsPressed;
  final VoidCallback onDetailPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    final selectedDate = ref.watch(calendarSelectedDateProvider);
    final dateStr =
        '${selectedDate.year}-'
        '${selectedDate.month.toString().padLeft(2, '0')}-'
        '${selectedDate.day.toString().padLeft(2, '0')}';

    final totalsAsync = ref.watch(consumedTotalsForDateProvider(dateStr));
    final consumed = totalsAsync.maybeWhen(
      data: (v) => v,
      orElse: () => const ConsumedTotals(),
    );

    final targetCals = macros.totalCalories;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onDetailPressed,
        borderRadius: AppRadius.cardRadius,
        child: BaseCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _FactRow(
                      label: 'Eaten',
                      kcal: consumed.calories.toDouble(),
                      carbsG: consumed.carbsG,
                      proteinG: consumed.proteinG,
                      fatG: consumed.fatG,
                      emphasized: true,
                      textColor: textColor,
                    ),
                    const SizedBox(height: 6),
                    _FactRow(
                      label: 'Plan',
                      kcal: targetCals,
                      carbsG: macros.carbG,
                      proteinG: macros.protG,
                      fatG: macros.fatG,
                      emphasized: false,
                      textColor: textColor,
                    ),
                  ],
                ),
              ),
              // Trends icon — isolated tap area that does NOT bubble up to
              // the card's InkWell.
              GestureDetector(
                onTap: onTrendsPressed,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.bar_chart,
                    size: 18,
                    color: textColor.withValues(alpha: 0.40),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// One fact row: label · kcal · macro grams
// ---------------------------------------------------------------------------

class _FactRow extends StatelessWidget {
  const _FactRow({
    required this.label,
    required this.kcal,
    required this.carbsG,
    required this.proteinG,
    required this.fatG,
    required this.emphasized,
    required this.textColor,
  });

  final String label;
  final double kcal;
  final double carbsG;
  final double proteinG;
  final double fatG;
  final bool emphasized;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    // The Plan row reads as a subdued reference, never a quota.
    final valueColor =
        emphasized ? textColor : textColor.withValues(alpha: 0.55);
    final macroAlpha = emphasized ? 1.0 : 0.55;

    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: textColor.withValues(alpha: 0.5),
            ),
          ),
        ),
        SizedBox(
          width: 86,
          child: Text(
            '${NumberFormat('#,###').format(kcal.round())} kcal',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
              color: valueColor,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                _macroSpan('C', carbsG, kMacroColorCarbs, macroAlpha),
                TextSpan(
                  text: ' · ',
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.3),
                  ),
                ),
                _macroSpan('P', proteinG, kMacroColorProtein, macroAlpha),
                TextSpan(
                  text: ' · ',
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.3),
                  ),
                ),
                _macroSpan('F', fatG, kMacroColorFat, macroAlpha),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  TextSpan _macroSpan(String letter, double grams, Color color, double alpha) {
    return TextSpan(
      children: [
        TextSpan(
          text: letter,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color.withValues(alpha: alpha),
          ),
        ),
        TextSpan(
          text: ' ${grams.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: emphasized ? FontWeight.w600 : FontWeight.w500,
            color: textColor.withValues(alpha: alpha == 1.0 ? 0.85 : 0.55),
          ),
        ),
      ],
    );
  }
}
