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
import 'macro_palette.dart';
import 'today_hero_card.dart' show showMacroDetailSheet;

/// Card showing the daily macro summary at the top of the Daily Macros tab.
///
/// It has two faces, chosen by whether the selected day has any meal-log
/// records:
///
/// * **No logs yet → "Planned today".** Shows the planned targets in the same
///   compact stat row the eaten card uses, plus an inline expand affordance
///   that reveals the plan details (energy-source breakdown, attribution) so
///   the user can see what the plan is without leaving the page.
/// * **Has logs → "Eaten today".** Shows what's been consumed so far (the
///   original behaviour).
///
/// In both cases tapping the card (or the "Details" affordance) opens the
/// full "Today's Fueling" detail sheet (Planned | Eaten | Weekly tabs).
class DailySummaryCard extends ConsumerStatefulWidget {
  const DailySummaryCard({super.key, required this.macros});

  final DailyMacroTargets macros;

  @override
  ConsumerState<DailySummaryCard> createState() => _DailySummaryCardState();
}

class _DailySummaryCardState extends ConsumerState<DailySummaryCard> {
  /// Whether the inline plan-details section is expanded (planned face only).
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final macros = widget.macros;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final fmt = NumberFormat('#,###');

    // Eaten totals + log presence for the date currently selected in the
    // calendar. Both derive from the same Drift stream, so they stay in sync.
    final selectedDate = ref.watch(calendarSelectedDateProvider);
    final dateStr =
        '${selectedDate.year}-'
        '${selectedDate.month.toString().padLeft(2, '0')}-'
        '${selectedDate.day.toString().padLeft(2, '0')}';
    final consumed = ref.watch(consumedTotalsForDateProvider(dateStr)).maybeWhen(
          data: (v) => v,
          orElse: () => const ConsumedTotals(),
        );
    // Has the user logged anything for this day yet? Until the stream resolves
    // we treat the day as "not yet logged" and show the planned face.
    final hasLogs =
        ref.watch(mealLogsForDateProvider(dateStr)).valueOrNull?.isNotEmpty ??
            false;

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

    // Collapse any stale expansion when the day flips to "has logs" (the eaten
    // face has no inline expansion).
    if (hasLogs && _expanded) {
      _expanded = false;
    }

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
                hasLogs ? 'Eaten today' : 'Planned today',
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

          // Compact stat row — calories + carbs/protein/fat in the unified
          // macro colours. Values are the consumed totals once the user has
          // logged something, otherwise the planned targets. Same layout in
          // both faces so the card doesn't jump when the first meal is logged.
          Row(
            children: [
              Expanded(
                child: _SummaryStat(
                  label: 'Calories',
                  value: fmt.format(
                    hasLogs ? consumed.calories : macros.totalCalories.round(),
                  ),
                  color: kMacroColorCalories,
                  textColor: textColor,
                ),
              ),
              Expanded(
                child: _SummaryStat(
                  label: 'Carbs',
                  value:
                      '${(hasLogs ? consumed.carbsG : macros.carbG).round()}g',
                  color: kMacroColorCarbs,
                  textColor: textColor,
                ),
              ),
              Expanded(
                child: _SummaryStat(
                  label: 'Protein',
                  value:
                      '${(hasLogs ? consumed.proteinG : macros.protG).round()}g',
                  color: kMacroColorProtein,
                  textColor: textColor,
                ),
              ),
              Expanded(
                child: _SummaryStat(
                  label: 'Fat',
                  value: '${(hasLogs ? consumed.fatG : macros.fatG).round()}g',
                  color: kMacroColorFat,
                  textColor: textColor,
                ),
              ),
            ],
          ),

          // Planned face only: inline expand affordance + plan details. The
          // toggle has its own gesture handler so tapping it expands in place
          // rather than bubbling up to the card's "open Details sheet" tap.
          if (!hasLogs) ...[
            const SizedBox(height: AppSpacing.sm),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _expanded ? 'Hide plan' : 'Show plan',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: textColor.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 18,
                      color: textColor.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 180),
              crossFadeState: _expanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: _PlanDetails(
                macros: macros,
                showAttribution: showAttribution,
                textColor: textColor,
              ),
              secondChild: const SizedBox(width: double.infinity),
            ),
          ],
        ],
      ),
    );
  }
}

/// Inline plan-details section shown when the planned card is expanded.
///
/// Mirrors the content of the detail sheet's "Planned" tab (energy-source
/// breakdown + Garmin attribution), minus the kcal/C-P-F header which is
/// already shown in the card's stat row above.
class _PlanDetails extends StatelessWidget {
  const _PlanDetails({
    required this.macros,
    required this.showAttribution,
    required this.textColor,
  });

  final DailyMacroTargets macros;
  final bool showAttribution;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.sm),
        Divider(color: textColor.withValues(alpha: 0.12)),
        const SizedBox(height: AppSpacing.sm),
        EnergySourceBreakdown(macros: macros),
        if (showAttribution) ...[
          const SizedBox(height: AppSpacing.md),
          const GarminAttributionMessage(
            subject: 'Body composition and activity inputs',
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
      ],
    );
  }
}

/// One macro stat: big colour-accented value over a dotted label. Used for
/// both the eaten and planned faces of [DailySummaryCard].
class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
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
