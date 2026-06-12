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

/// Hero card for the Nutrition Diary screen.
///
/// Displays a calorie ring (progress arc), remaining/over kcal, three
/// macro progress bars (carbs/protein/fat), an expandable "How targets
/// are set" section, and Garmin attribution when applicable.
class TodayHeroCard extends ConsumerWidget {
  const TodayHeroCard({super.key, required this.macros});

  final DailyMacroTargets macros;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    // Build dateStr from selected calendar date.
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

    // Garmin attribution logic (mirrors DailySummaryCard).
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

    return BaseCard(
      key: const ValueKey('nutrition_diary.today_hero_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: ring + remaining kcal ──────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Calorie ring
              SizedBox(
                width: 100,
                height: 100,
                child: CustomPaint(
                  painter: _CalorieRingPainter(
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
                      _RemainingText(
                        consumed: consumed.calories,
                        target: targetCals.round(),
                        textColor: textColor,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'of ${NumberFormat('#,###').format(targetCals.round())} kcal target',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: textColor.withValues(alpha: 0.55),
                        ),
                      ),
                    ] else ...[
                      Text(
                        '0 kcal left',
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
                color: const Color(0xFF00C896),
              ),
              const SizedBox(height: AppSpacing.sm),
              _MacroBarRow(
                label: 'Protein',
                eaten: consumed.proteinG,
                target: macros.protG,
                color: const Color(0xFF6B4FA0),
              ),
              const SizedBox(height: AppSpacing.sm),
              _MacroBarRow(
                label: 'Fat',
                eaten: consumed.fatG,
                target: macros.fatG,
                color: const Color(0xFFFF2D55),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Expandable "How these targets are set" ───────────────────────
          _ExpandableBreakdown(macros: macros),

          // ── Garmin attribution ───────────────────────────────────────────
          if (showAttribution) ...[
            const SizedBox(height: AppSpacing.md),
            const GarminAttributionMessage(
              subject: 'Body composition and activity inputs',
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Remaining / over text widget
// ---------------------------------------------------------------------------

class _RemainingText extends StatelessWidget {
  const _RemainingText({
    required this.consumed,
    required this.target,
    required this.textColor,
  });

  final int consumed;
  final int target;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final exceeded = consumed > target;
    final amount = exceeded ? consumed - target : target - consumed;
    final label = exceeded
        ? '+$amount kcal over'
        : '$amount kcal left';
    final color = exceeded ? AppColors.dragonfruit : textColor;

    return Text(
      label,
      style: AppTextStyles.bodyLarge.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
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

    final ratio = target > 0
        ? (eaten / target).clamp(0.0, 1.0)
        : 0.0;

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
// Expandable "How these targets are set" section
// ---------------------------------------------------------------------------

class _ExpandableBreakdown extends StatefulWidget {
  const _ExpandableBreakdown({required this.macros});

  final DailyMacroTargets macros;

  @override
  State<_ExpandableBreakdown> createState() => _ExpandableBreakdownState();
}

class _ExpandableBreakdownState extends State<_ExpandableBreakdown> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Icon(
                _isExpanded
                    ? Icons.keyboard_arrow_down
                    : Icons.keyboard_arrow_right,
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
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Column(
            children: [
              const SizedBox(height: AppSpacing.sm),
              EnergySourceBreakdown(macros: widget.macros),
            ],
          ),
          crossFadeState: _isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Calorie ring painter
// ---------------------------------------------------------------------------

class _CalorieRingPainter extends CustomPainter {
  const _CalorieRingPainter({
    required this.progress,
    required this.trackColor,
    required this.arcColor,
  });

  final double progress;
  final Color trackColor;
  final Color arcColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 5;
    const strokeWidth = 8.0;

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
  bool shouldRepaint(_CalorieRingPainter old) => old.progress != progress;
}

// ---------------------------------------------------------------------------
// Garmin authoritative provider (mirrors daily_summary_card.dart)
// ---------------------------------------------------------------------------

/// True when Garmin body comp is currently authoritative for either the
/// user's weight or body fat — same staleness/precedence rules the rest of
/// the app uses. Returns false (no badge) on any error or when Garmin isn't
/// connected.
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
