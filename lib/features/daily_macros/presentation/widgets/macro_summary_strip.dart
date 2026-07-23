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
// Fixed-extent pinned macro summary strip — four color-tinted macro tiles
// ---------------------------------------------------------------------------

/// The permanent macro summary strip pinned at the top of the Daily Macros
/// scroll.
///
/// Four equal-width color-tinted tiles in a single row:
///
///   [kcal tile] [Carbs tile] [Protein tile] [Fat tile]
///
/// Each tile shows:
///   - Big bold eaten value (top, FittedBox-guarded)
///   - Macro label (middle)
///   - Subdued "plan …" reference caption (bottom)
///
/// The whole card taps through to the "Today's Fueling" detail sheet; the
/// bar-chart icon in the top-right corner is its own isolated tap target.
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

    final fmt = NumberFormat('#,###');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onDetailPressed,
        borderRadius: AppRadius.cardRadius,
        child: BaseCard(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Four macro tiles ─────────────────────────────────────────
              Row(
                children: [
                  // Kcal tile — orange tint
                  Expanded(
                    child: _MacroTile(
                      isDark: isDark,
                      tintColor: AppColors.orange,
                      bigText: fmt.format(consumed.calories.round()),
                      label: 'kcal',
                      planCaption:
                          'plan ${fmt.format(macros.totalCalories.round())}',
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Carbs tile
                  Expanded(
                    child: _MacroTile(
                      isDark: isDark,
                      tintColor: kMacroColorCarbs,
                      bigText: '${consumed.carbsG.toStringAsFixed(0)}g',
                      label: 'Carbs',
                      planCaption: 'plan ${macros.carbG.toStringAsFixed(0)}',
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Protein tile
                  Expanded(
                    child: _MacroTile(
                      isDark: isDark,
                      tintColor: kMacroColorProtein,
                      bigText: '${consumed.proteinG.toStringAsFixed(0)}g',
                      label: 'Protein',
                      planCaption: 'plan ${macros.protG.toStringAsFixed(0)}',
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Fat tile
                  Expanded(
                    child: _MacroTile(
                      isDark: isDark,
                      tintColor: kMacroColorFat,
                      bigText: '${consumed.fatG.toStringAsFixed(0)}g',
                      label: 'Fat',
                      planCaption: 'plan ${macros.fatG.toStringAsFixed(0)}',
                    ),
                  ),
                ],
              ),

              // ── Trends icon — isolated tap area, top-right corner ─────────
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: onTrendsPressed,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.bar_chart,
                      size: 16,
                      color: textColor.withValues(alpha: 0.30),
                    ),
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
// Single color-tinted macro tile
// ---------------------------------------------------------------------------

class _MacroTile extends StatelessWidget {
  const _MacroTile({
    required this.isDark,
    required this.tintColor,
    required this.bigText,
    required this.label,
    required this.planCaption,
  });

  final bool isDark;
  final Color tintColor;
  final String bigText;
  final String label;
  final String planCaption;

  @override
  Widget build(BuildContext context) {
    // 12–15 % alpha tint, dark/light aware.
    final tintAlpha = isDark ? 0.18 : 0.13;
    final tileTextColor = isDark ? AppColors.cream : AppColors.blackberry;

    return Container(
      // Explicit height keeps the row stable across font sizes.
      height: 68,
      decoration: BoxDecoration(
        color: tintColor.withValues(alpha: tintAlpha),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Big eaten value — FittedBox guards against wide Ahem test font.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              bigText,
              maxLines: 1,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: tileTextColor,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 2),
          // Macro label
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.clip,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: tintColor,
            ),
          ),
          const SizedBox(height: 2),
          // Plan reference caption
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              planCaption,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w400,
                color: tileTextColor.withValues(alpha: 0.45),
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
