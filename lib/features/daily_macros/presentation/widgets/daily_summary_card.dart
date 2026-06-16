import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../auth/application/auth_service.dart';
import '../../../calendar/presentation/providers/calendar_selected_date_provider.dart';
import '../../../integrations/presentation/providers/integrations_providers.dart';
import '../../../meal_logging/domain/consumed_totals.dart';
import '../../../meal_logging/presentation/providers/meal_log_providers.dart';
import '../../domain/daily_macro_targets.dart';
import 'macro_comparison_table.dart';
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
                'Daily Total',
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

          // Planned vs. Eaten vs. Left comparison table. This is the always-on
          // headline: eaten + remaining are visible at a glance without a tap.
          //
          // The energy-source breakdown (RMR / NEAT / Workout) and Garmin
          // attribution — "how this target was computed" reference data — now
          // live behind the Details sheet's Plan tab so this card stays compact
          // and the day's log isn't pushed below the fold.
          MacroComparisonTable(planned: macros, consumed: consumed),
        ],
      ),
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
