import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../auth/application/auth_service.dart';
import '../../../calendar/presentation/providers/calendar_selected_date_provider.dart';
import '../../../integrations/presentation/providers/integrations_providers.dart';
import '../../../meal_logging/domain/consumed_totals.dart';
import '../../../meal_logging/presentation/providers/meal_log_providers.dart';
import '../../domain/daily_macro_targets.dart';
import 'macro_palette.dart';
import 'today_hero_card.dart' show showMacroDetailSheet;

/// Card showing the daily macro summary:
/// - Header eyebrow + tappable "Details" affordance
/// - Planned vs. Eaten vs. Left comparison table
/// - Energy source breakdown (RMR / NEAT / Workout)
/// - Garmin attribution when applicable
///
/// Tapping anywhere opens the "Today's Fueling" detail sheet (Eaten | Plan
/// tabs) for the per-meal drill-down.
class DailySummaryCard extends ConsumerWidget {
  const DailySummaryCard({super.key, required this.macros});

  final DailyMacroTargets macros;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final fmt = NumberFormat('#,###');

    // Eaten totals for the date currently selected in the calendar.
    final selectedDate = ref.watch(calendarSelectedDateProvider);
    final dateStr =
        '${selectedDate.year}-'
        '${selectedDate.month.toString().padLeft(2, '0')}-'
        '${selectedDate.day.toString().padLeft(2, '0')}';
    final consumed = ref.watch(consumedTotalsForDateProvider(dateStr)).maybeWhen(
          data: (v) => v,
          orElse: () => const ConsumedTotals(),
        );

    // Fresh edge calc populates `sources`; cached reads don't. For cached
    // reads, fall back to the same Garmin-authoritative check the rest of the
    // app uses so attribution doesn't disappear once the row is cached.
    final attributionFromFreshCalc = macros.sources?.anyFromGarmin ?? false;
    final attributionFromGarminHealthData =
        ref.watch(_garminAuthoritativeProvider).maybeWhen(
              data: (v) => v,
              orElse: () => false,
            );
    final showAttribution =
        attributionFromFreshCalc || attributionFromGarminHealthData;

    return BaseCard(
      key: const ValueKey('nutrition_diary.daily_total_card'),
      onTap: () => showMacroDetailSheet(
        context,
        macros: macros,
        consumed: consumed,
        showAttribution: showAttribution,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: eyebrow left, tappable "Details" affordance right.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Eaten today',
                style: AppTextStyles.sectionTitle.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Details',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.orange,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Clean "eaten today" row — calories + carbs/protein/fat consumed so
          // far, in the unified macro colours. No targets, bars, or "left" here:
          // the planned numbers and the weekly trend live behind the Details
          // sheet (Planned / Eaten / Weekly tabs).
          Row(
            children: [
              Expanded(
                child: _EatenStat(
                  label: 'Calories',
                  value: fmt.format(consumed.calories),
                  color: kMacroColorCalories,
                  textColor: textColor,
                ),
              ),
              Expanded(
                child: _EatenStat(
                  label: 'Carbs',
                  value: '${consumed.carbsG.round()}g',
                  color: kMacroColorCarbs,
                  textColor: textColor,
                ),
              ),
              Expanded(
                child: _EatenStat(
                  label: 'Protein',
                  value: '${consumed.proteinG.round()}g',
                  color: kMacroColorProtein,
                  textColor: textColor,
                ),
              ),
              Expanded(
                child: _EatenStat(
                  label: 'Fat',
                  value: '${consumed.fatG.round()}g',
                  color: kMacroColorFat,
                  textColor: textColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One eaten-macro stat: big colour-accented value over a dotted label.
/// Used in the [DailySummaryCard] "eaten today" row.
class _EatenStat extends StatelessWidget {
  const _EatenStat({
    required this.label,
    required this.value,
    required this.color,
    required this.textColor,
  });

  final String label;
  final String value;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: textColor.withValues(alpha: 0.6),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

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
