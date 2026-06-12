import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../auth/application/auth_service.dart';
import '../../../integrations/presentation/providers/integrations_providers.dart';
import '../../../integrations/presentation/widgets/garmin_attribution_message.dart';
import '../../../meal_logging/domain/consumed_totals.dart';
import '../../domain/daily_macro_targets.dart';
import 'energy_source_breakdown.dart';

// ---------------------------------------------------------------------------
// Public macro colour constants — reused by MacroSummaryStrip.
// ---------------------------------------------------------------------------

/// Colour used for the carbs macro indicator.
const Color kMacroColorCarbs = Color(0xFF00C896);

/// Colour used for the protein macro indicator.
const Color kMacroColorProtein = Color(0xFF6B4FA0);

/// Colour used for the fat macro indicator.
const Color kMacroColorFat = Color(0xFFFF2D55);

// ---------------------------------------------------------------------------
// Detail sheet (replaces the old card composition as the primary surface)
// ---------------------------------------------------------------------------

/// Opens the "Today's Fueling" detail bottom sheet.
///
/// Contains, top to bottom:
///   - drag handle
///   - title "Today's Fueling"
///   - big calorie ring + [_FuelingText] row (same layout as the old hero card)
///   - three full [_MacroBarRow] bars
///   - divider
///   - [EnergySourceBreakdown]
///   - Garmin attribution when applicable
///
/// Scrollable so it works on small screens.
void showMacroDetailSheet(
  BuildContext context, {
  required DailyMacroTargets macros,
  required ConsumedTotals consumed,
  required bool showAttribution,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _MacroDetailSheetContent(
      macros: macros,
      consumed: consumed,
      showAttribution: showAttribution,
    ),
  );
}

class _MacroDetailSheetContent extends StatelessWidget {
  const _MacroDetailSheetContent({
    required this.macros,
    required this.consumed,
    required this.showAttribution,
  });

  final DailyMacroTargets macros;
  final ConsumedTotals consumed;
  final bool showAttribution;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.blackberry : AppColors.cream;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    final targetCals = macros.totalCalories;
    final progress = targetCals > 0
        ? (consumed.calories / targetCals).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      // Account for keyboard + safe area bottom.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (ctx, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Title
                Text(
                  "Today's Fueling",
                  style: AppTextStyles.pageTitle.copyWith(color: textColor),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Big calorie ring + fueling text row ─────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
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
                    Expanded(
                      child: targetCals > 0
                          ? _FuelingText(
                              consumed: consumed.calories,
                              target: targetCals.round(),
                              textColor: textColor,
                            )
                          : Text(
                              'No target yet',
                              style: AppTextStyles.bodyLarge.copyWith(
                                color: textColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Three full macro bar rows ────────────────────────────
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
                const SizedBox(height: AppSpacing.lg),

                // ── Divider ──────────────────────────────────────────────
                Divider(color: textColor.withValues(alpha: 0.12)),
                const SizedBox(height: AppSpacing.lg),

                // ── Energy source breakdown ──────────────────────────────
                EnergySourceBreakdown(macros: macros),

                // ── Garmin attribution ───────────────────────────────────
                if (showAttribution) ...[
                  const SizedBox(height: AppSpacing.lg),
                  const GarminAttributionMessage(
                    subject: 'Body composition and activity inputs',
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fueling status text widget (reused in detail sheet)
// ---------------------------------------------------------------------------

/// Deliberately non-restrictive framing: shows the target and progress toward
/// it as fueling information, never "left"/"over" diet language.
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
// Individual macro bar row (reused in detail sheet)
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
// Calorie ring painter (public — reused by MacroSummaryStrip)
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
final garminAuthoritativeForMacrosProvider =
    FutureProvider.autoDispose<bool>((ref) async {
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
