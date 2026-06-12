import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../auth/application/auth_service.dart';
import '../../../calendar/presentation/providers/calendar_selected_date_provider.dart';
import '../../../integrations/presentation/providers/integrations_providers.dart';
import '../../../integrations/presentation/widgets/garmin_attribution_message.dart';
import '../../../meal_logging/domain/consumed_totals.dart';
import '../../../meal_logging/presentation/providers/meal_log_providers.dart';
import '../../domain/daily_macro_targets.dart';
import 'energy_source_breakdown.dart';

// ---------------------------------------------------------------------------
// Public macro colour constants — reused by the collapsed slim bar delegate.
// ---------------------------------------------------------------------------

/// Colour used for the carbs macro indicator.
const Color kMacroColorCarbs = Color(0xFF00C896);

/// Colour used for the protein macro indicator.
const Color kMacroColorProtein = Color(0xFF6B4FA0);

/// Colour used for the fat macro indicator.
const Color kMacroColorFat = Color(0xFFFF2D55);

// ---------------------------------------------------------------------------
// Hero card
// ---------------------------------------------------------------------------

/// Hero card for the Nutrition Diary screen.
///
/// Displays a calorie ring, remaining/over kcal, three macro progress bars,
/// and a "How these targets are set" row that opens a Kyle-styled bottom
/// sheet containing [EnergySourceBreakdown] plus Garmin attribution when
/// applicable.
///
/// [onTrendsPressed] is wired to the bar-chart icon in the top-right corner.
class TodayHeroCard extends ConsumerWidget {
  const TodayHeroCard({
    super.key,
    required this.macros,
    this.onTrendsPressed,
    this.onBreakdownPressed,
  });

  final DailyMacroTargets macros;

  /// Called when the trends bar-chart icon is tapped.
  final VoidCallback? onTrendsPressed;

  /// Called when the "How these targets are set" row is tapped.
  /// When null the row opens the breakdown sheet itself.
  final VoidCallback? onBreakdownPressed;

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

    // Garmin attribution logic.
    final attributionFromFreshCalc = macros.sources?.anyFromGarmin ?? false;
    final attributionFromGarminHealthData =
        ref.watch(_garminAuthoritativeProvider).maybeWhen(
          data: (v) => v,
          orElse: () => false,
        );
    final showAttribution =
        attributionFromFreshCalc || attributionFromGarminHealthData;

    final targetCals = macros.totalCalories;
    final progress = targetCals > 0
        ? (consumed.calories / targetCals).clamp(0.0, 1.0)
        : 0.0;

    void openBreakdown() {
      if (onBreakdownPressed != null) {
        onBreakdownPressed!();
      } else {
        showBreakdownSheet(
          context,
          macros: macros,
          showAttribution: showAttribution,
        );
      }
    }

    return BaseCard(
      key: const ValueKey('nutrition_diary.today_hero_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: ring + remaining kcal + trends icon ────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Calorie ring
              SizedBox(
                width: 100,
                height: 100,
                child: CustomPaint(
                  painter: CalorieRingPainter(
                    progress: progress,
                    trackColor: AppColors.orange.withValues(alpha: 0.15),
                    arcColor: AppColors.orange,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          consumed.calories.toString(),
                          style: const TextStyle(
                            fontFamily: 'Sansita',
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ).copyWith(color: textColor),
                        ),
                        Text(
                          'kcal',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: textColor.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Remaining / over text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (targetCals > 0) ...[
                      _FuelingText(
                        consumed: consumed.calories,
                        target: targetCals.round(),
                        textColor: textColor,
                      ),
                    ] else ...[
                      Text(
                        'No target yet',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Set up targets in Settings',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: textColor.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Trends icon — top-right of the expanded card.
              if (onTrendsPressed != null)
                IconButton(
                  key: const ValueKey('nutrition_diary.trends_button'),
                  icon: Icon(
                    Icons.bar_chart,
                    size: 20,
                    color: textColor.withValues(alpha: 0.45),
                  ),
                  onPressed: onTrendsPressed,
                  tooltip: 'Weekly Trends',
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Three macro bar rows ─────────────────────────────────────────
          Column(
            children: [
              _MacroBarRow(
                label: 'Carbs',
                eaten: consumed.carbsG,
                target: macros.carbG,
                color: kMacroColorCarbs,
              ),
              const SizedBox(height: AppSpacing.sm),
              _MacroBarRow(
                label: 'Protein',
                eaten: consumed.proteinG,
                target: macros.protG,
                color: kMacroColorProtein,
              ),
              const SizedBox(height: AppSpacing.sm),
              _MacroBarRow(
                label: 'Fat',
                eaten: consumed.fatG,
                target: macros.fatG,
                color: kMacroColorFat,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── "How these targets are set" trigger row ─────────────────────
          _BreakdownTriggerRow(
            onTap: openBreakdown,
            textColor: textColor,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Breakdown bottom-sheet helper (public so the persistent header can call it)
// ---------------------------------------------------------------------------

/// Opens the "How these targets are set" bottom sheet containing
/// [EnergySourceBreakdown] and, when applicable, Garmin attribution.
void showBreakdownSheet(
  BuildContext context, {
  required DailyMacroTargets macros,
  required bool showAttribution,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      final bg = isDark ? AppColors.blackberry : AppColors.cream;
      final textColor = isDark ? AppColors.cream : AppColors.blackberry;
      return Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.md,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'How These Targets Are Set',
                style: AppTextStyles.pageTitle.copyWith(color: textColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              EnergySourceBreakdown(macros: macros),
              if (showAttribution) ...[
                const SizedBox(height: AppSpacing.lg),
                const GarminAttributionMessage(
                  subject: 'Body composition and activity inputs',
                ),
              ],
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// "How these targets are set" trigger row
// ---------------------------------------------------------------------------

class _BreakdownTriggerRow extends StatelessWidget {
  const _BreakdownTriggerRow({
    required this.onTap,
    required this.textColor,
  });

  final VoidCallback onTap;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Icon(
            Icons.keyboard_arrow_right,
            size: 16,
            color: textColor.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 6),
          Text(
            'How these targets are set',
            style: AppTextStyles.bodySmall.copyWith(
              color: textColor.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fueling status text widget
// ---------------------------------------------------------------------------

/// Deliberately non-restrictive framing: shows the target and progress toward
/// it as fueling information, never "left"/"over" diet language. Reaching the
/// target reads as success (Electrolyte), not a warning.
class _FuelingText extends StatelessWidget {
  const _FuelingText({
    required this.consumed,
    required this.target,
    required this.textColor,
  });

  final int consumed;
  final int target;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final reached = consumed >= target;
    final pct = target > 0 ? ((consumed / target) * 100).round() : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Target ${NumberFormat('#,###').format(target)} kcal',
          style: AppTextStyles.bodyLarge.copyWith(
            color: textColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          reached ? 'Target reached' : '$pct% fueled so far',
          style: AppTextStyles.bodySmall.copyWith(
            color: reached
                ? AppColors.electrolyte
                : textColor.withValues(alpha: 0.55),
            fontWeight: reached ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Individual macro bar row
// ---------------------------------------------------------------------------

class _MacroBarRow extends StatelessWidget {
  const _MacroBarRow({
    required this.label,
    required this.eaten,
    required this.target,
    required this.color,
  });

  final String label;
  final double eaten;
  final double target;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    final ratio = target > 0 ? (eaten / target).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(color: textColor),
            ),
            Text(
              '${eaten.toStringAsFixed(0)} / ${target > 0 ? target.toStringAsFixed(0) : '—'}g',
              style: AppTextStyles.bodySmall.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 5,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Calorie ring painter (public — reused by the collapsed slim-bar delegate)
// ---------------------------------------------------------------------------

class CalorieRingPainter extends CustomPainter {
  const CalorieRingPainter({
    required this.progress,
    required this.trackColor,
    required this.arcColor,
    this.strokeWidth = 8.0,
  });

  final double progress;
  final Color trackColor;
  final Color arcColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - strokeWidth / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Track
    paint.color = trackColor;
    canvas.drawCircle(center, radius, paint);

    // Arc
    if (progress > 0) {
      paint.color = arcColor;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, // start at top
        2 * math.pi * progress,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CalorieRingPainter old) =>
      old.progress != progress ||
      old.trackColor != trackColor ||
      old.arcColor != arcColor;
}

// ---------------------------------------------------------------------------
// Garmin authoritative provider (mirrors daily_summary_card.dart)
// ---------------------------------------------------------------------------

/// True when Garmin body comp is currently authoritative for either the
/// user's weight or body fat.
final _garminAuthoritativeProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  final profile = await ref.watch(currentUserProvider.future);
  if (profile == null) return false;

  final garmin = await ref.watch(
    garminLastBodyCompProvider(profile.id).future,
  );
  if (garmin == null) return false;

  final userWeightKg = profile.weightPounds * 0.453592;
  final weightAuthoritative = isGarminAuthoritativeForWeight(
    garmin: garmin,
    userWeightKg: userWeightKg,
    userUpdatedAt: profile.weightPoundsUpdatedAt,
  );
  final bodyFatAuthoritative = isGarminAuthoritativeForBodyFat(
    garmin: garmin,
    userBodyFatPct: profile.bodyFatPct,
    userUpdatedAt: profile.bodyFatPctUpdatedAt,
  );
  return weightAuthoritative || bodyFatAuthoritative;
});
