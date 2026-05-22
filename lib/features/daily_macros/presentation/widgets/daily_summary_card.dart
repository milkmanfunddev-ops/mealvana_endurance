import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../auth/application/auth_service.dart';
import '../../../integrations/presentation/providers/integrations_providers.dart';
import '../../../integrations/presentation/widgets/garmin_attribution_message.dart';
import '../../domain/daily_macro_targets.dart';
import 'energy_source_breakdown.dart';
import 'macro_breakdown_row.dart';

/// Card showing daily macro summary:
/// Row 1: "1,130 cal" (left) | "Daily Total" (right)
/// Row 2: colored macro breakdown (carbs/protein/fat with dot indicators)
class DailySummaryCard extends ConsumerWidget {
  const DailySummaryCard({super.key, required this.macros});

  final DailyMacroTargets macros;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    // Fresh edge calc populates `sources`; cached reads don't.
    // For cached reads, fall back to the same Garmin-authoritative check the
    // rest of the app uses (preferences/profile/onboarding), so the
    // attribution doesn't disappear once the row is cached locally.
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
      child: Column(
        children: [
          // Compact header row: calories left, "Daily Total" right
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${NumberFormat('#,###').format(macros.totalCalories.round())} cal',
                style: AppTextStyles.pageTitle.copyWith(
                  color: textColor,
                  fontSize: 28,
                ),
              ),
              Text(
                'Daily Total',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: textColor.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Macro breakdown with colored dots
          MacroBreakdownRow(
            carbG: macros.carbG,
            protG: macros.protG,
            fatG: macros.fatG,
            textColor: textColor,
          ),

          // Energy breakdown (RMR / NEAT / Workout) with Garmin attribution
          // for any line that came from Garmin Connect data.
          const SizedBox(height: AppSpacing.lg),
          EnergySourceBreakdown(macros: macros),

          // Card-level Garmin attribution (Garmin Developer API Brand
          // Guidelines require attribution on every screen surfacing
          // Garmin-derived data). Shown whenever any input — RMR, NEAT,
          // weight, body fat, or session kcal/duration — came from Garmin,
          // OR whenever Garmin body comp is currently authoritative for the
          // user's weight/body fat (covers cached macro reads where the
          // per-calc `sources` blob was dropped on persist).
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
