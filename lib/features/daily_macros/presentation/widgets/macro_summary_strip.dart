import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../calendar/presentation/providers/calendar_selected_date_provider.dart';
import '../../../meal_logging/domain/consumed_totals.dart';
import '../../../meal_logging/presentation/providers/meal_log_providers.dart';
import '../../domain/daily_macro_targets.dart';
import 'today_hero_card.dart' show kMacroColorCarbs, kMacroColorProtein, kMacroColorFat, CalorieRingPainter, showMacroDetailSheet;

// ---------------------------------------------------------------------------
// Fixed-extent pinned macro summary strip (~88-96 px)
// ---------------------------------------------------------------------------

/// The permanent two-line macro summary strip that lives as a pinned
/// [SliverPersistentHeader] in the Daily Macros screen.
///
/// Line 1: 32 px calorie ring + "X,XXX / Y,YYY kcal" (bold, neutral) +
///         trends icon on the right (separate tap target).
///
/// Line 2: Three inline micro-bars — C / P / F, each with a letter label,
///         thin 4 px coloured progress bar, and "eaten/target" gram text.
///
/// The whole card tap opens [showMacroDetailSheet].
/// The trends icon tap opens the trends sheet via [onTrendsPressed].
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
    final progress = targetCals > 0
        ? (consumed.calories / targetCals).clamp(0.0, 1.0)
        : 0.0;

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Line 1: ring + kcal text + trends icon ─────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 32 px calorie ring, no center text
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: CustomPaint(
                      painter: CalorieRingPainter(
                        progress: progress,
                        trackColor: AppColors.orange.withValues(alpha: 0.2),
                        arcColor: AppColors.orange,
                        strokeWidth: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // "X,XXX / Y,YYY kcal" — neutral, no left/over language
                  Expanded(
                    child: Text(
                      targetCals > 0
                          ? '${NumberFormat('#,###').format(consumed.calories)} / '
                              '${NumberFormat('#,###').format(targetCals.round())} kcal'
                          : 'No target yet',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Trends icon — isolated tap area that does NOT bubble up
                  // to the card's InkWell.
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
              const SizedBox(height: 8),

              // ── Line 2: three inline macro micro-bars ──────────────────
              Row(
                children: [
                  _MicroMacroBar(
                    letter: 'C',
                    eatenG: consumed.carbsG,
                    targetG: macros.carbG,
                    color: kMacroColorCarbs,
                    textColor: textColor,
                  ),
                  const SizedBox(width: 8),
                  _MicroMacroBar(
                    letter: 'P',
                    eatenG: consumed.proteinG,
                    targetG: macros.protG,
                    color: kMacroColorProtein,
                    textColor: textColor,
                  ),
                  const SizedBox(width: 8),
                  _MicroMacroBar(
                    letter: 'F',
                    eatenG: consumed.fatG,
                    targetG: macros.fatG,
                    color: kMacroColorFat,
                    textColor: textColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single inline macro micro-bar
// ---------------------------------------------------------------------------

/// One third of Line 2: letter label + thin coloured progress bar + gram text.
///
/// Layout (Expanded so the three bars share row width equally):
///   [C] [═════░░░] 144/305g
class _MicroMacroBar extends StatelessWidget {
  const _MicroMacroBar({
    required this.letter,
    required this.eatenG,
    required this.targetG,
    required this.color,
    required this.textColor,
  });

  final String letter;
  final double eatenG;
  final double targetG;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final ratio = targetG > 0 ? (eatenG / targetG).clamp(0.0, 1.0) : 0.0;
    final gramText = targetG > 0
        ? '${eatenG.toStringAsFixed(0)}/${targetG.toStringAsFixed(0)}g'
        : '${eatenG.toStringAsFixed(0)}g';

    return Expanded(
      child: Row(
        children: [
          // Macro letter in its macro colour
          Text(
            letter,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          // Thin 4 px rounded progress bar
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: ratio,
                backgroundColor: color.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 4,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Gram text (subdued)
          Text(
            gramText,
            style: TextStyle(
              fontSize: 10,
              color: textColor.withValues(alpha: 0.55),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
