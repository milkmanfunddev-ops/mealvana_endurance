import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/providers/unit_system_provider.dart';
import '../../../../shared/utils/unit_formatter.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../auth/application/auth_service.dart';
import '../../../integrations/presentation/providers/integrations_providers.dart';
import '../../../integrations/presentation/widgets/garmin_attribution.dart';
import '../../../nutrition_plan/domain/run_parameters.dart';
import '../../domain/daily_macro_targets.dart';

/// Per-line breakdown of TDEE components (RMR, NEAT, Activity) with source
/// attribution for each. When a value comes from Garmin Connect, the row
/// shows a Garmin tag chip — fulfilling the API brand-guideline requirement
/// that Garmin-derived data is attributed wherever it surfaces.
class EnergySourceBreakdown extends ConsumerWidget {
  const EnergySourceBreakdown({super.key, required this.macros});

  final DailyMacroTargets macros;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final sources = macros.sources;
    final useMetric =
        (ref.watch(unitSystemProvider).value ?? UnitSystem.imperial) ==
        UnitSystem.metric;

    // The macro edge function returns `weight_kg`/`body_fat_pct`/`sources`
    // only on a fresh calc; cached Drift rows don't carry them. Fall back to
    // the user profile so the Body Composition row + its Garmin badge keep
    // rendering once the row is cached.
    final profile = ref.watch(currentUserProvider).asData?.value;
    final garmin = profile == null
        ? null
        : ref.watch(garminLastBodyCompProvider(profile.id)).asData?.value;

    final resolvedWeightKg =
        macros.weightKg ??
        (profile?.weightPounds != null
            ? profile!.weightPounds * 0.453592
            : null);
    final resolvedBodyFatPct = macros.bodyFatPct ?? profile?.bodyFatPct;

    // Source flag: trust the fresh calc when we have it, otherwise derive
    // from the same authoritative check the rest of the app uses.
    final weightFromGarmin =
        sources?.weightFromGarmin ??
        isGarminAuthoritativeForWeight(
          garmin: garmin,
          userWeightKg: profile != null
              ? profile.weightPounds * 0.453592
              : null,
          userUpdatedAt: profile?.weightPoundsUpdatedAt,
        );
    final bodyFatFromGarmin =
        sources?.bodyFatFromGarmin ??
        isGarminAuthoritativeForBodyFat(
          garmin: garmin,
          userBodyFatPct: profile?.bodyFatPct,
          userUpdatedAt: profile?.bodyFatPctUpdatedAt,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Body composition — shows the actual weight + body fat used in the
        // calc, with Garmin attribution when those values came from a Garmin
        // body-comp scale via the latest-wins resolver.
        if (resolvedWeightKg != null || resolvedBodyFatPct != null) ...[
          _BodyCompositionRow(
            weightKg: resolvedWeightKg,
            bodyFatPct: resolvedBodyFatPct,
            weightFromGarmin: weightFromGarmin,
            bodyFatFromGarmin: bodyFatFromGarmin,
            textColor: textColor,
            useMetric: useMetric,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Text(
          key: const ValueKey('nutrition_diary.breakdown_section'),
          'Energy Breakdown',
          style: AppTextStyles.bodySmall.copyWith(
            color: textColor.withValues(alpha: 0.5),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _BreakdownRow(
          key: const ValueKey('nutrition_diary.resting_row'),
          label: 'Resting',
          kcal: macros.rmr,
          fromGarmin: sources?.rmrFromGarmin ?? false,
          textColor: textColor,
        ),
        if (macros.neatKcal != null && macros.neatKcal! > 0) ...[
          const SizedBox(height: 6),
          _BreakdownRow(
            key: const ValueKey('nutrition_diary.daily_activity_row'),
            label: 'Daily activity',
            kcal: macros.neatKcal!,
            fromGarmin: sources?.neatFromGarmin ?? false,
            textColor: textColor,
          ),
        ],
        if (macros.sessionKcal > 0) ...[
          const SizedBox(height: 6),
          _BreakdownRow(
            key: const ValueKey('nutrition_diary.workout_row'),
            label: 'Workout',
            kcal: macros.sessionKcal,
            fromGarmin: _anySessionFromGarmin(sources),
            textColor: textColor,
          ),
        ],
        const SizedBox(height: 8),
        Divider(color: textColor.withValues(alpha: 0.1), height: 1),
        const SizedBox(height: 8),
        _BreakdownRow(
          key: const ValueKey('nutrition_diary.tdee_row'),
          label: 'Total burn (TDEE)',
          kcal: macros.tdee,
          fromGarmin: false,
          textColor: textColor,
          emphasized: true,
        ),
      ],
    );
  }

  static bool _anySessionFromGarmin(MacroSources? sources) {
    if (sources == null) return false;
    return sources.sessions.any((s) => s.kcalFromGarmin);
  }
}

class _BodyCompositionRow extends StatelessWidget {
  const _BodyCompositionRow({
    required this.weightKg,
    required this.bodyFatPct,
    required this.weightFromGarmin,
    required this.bodyFatFromGarmin,
    required this.textColor,
    required this.useMetric,
  });

  final double? weightKg;
  final double? bodyFatPct;
  final bool weightFromGarmin;
  final bool bodyFatFromGarmin;
  final Color textColor;
  final bool useMetric;

  @override
  Widget build(BuildContext context) {
    final pieces = <Widget>[];

    if (weightKg != null) {
      final pounds = UnitFormatter.kgToPounds(weightKg!);
      pieces.add(
        _ValueWithBadge(
          label: 'Weight',
          value: UnitFormatter.formatWeight(pounds, useMetric: useMetric),
          fromGarmin: weightFromGarmin,
          textColor: textColor,
        ),
      );
    }
    if (bodyFatPct != null) {
      pieces.add(
        _ValueWithBadge(
          label: 'Body fat',
          value: '${bodyFatPct!.toStringAsFixed(1)}%',
          fromGarmin: bodyFatFromGarmin,
          textColor: textColor,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Body Composition',
          style: AppTextStyles.bodySmall.copyWith(
            color: textColor.withValues(alpha: 0.5),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.sm,
          children: pieces,
        ),
      ],
    );
  }
}

class _ValueWithBadge extends StatelessWidget {
  const _ValueWithBadge({
    required this.label,
    required this.value,
    required this.fromGarmin,
    required this.textColor,
  });

  final String label;
  final String value;
  final bool fromGarmin;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: AppTextStyles.bodyMedium.copyWith(
                color: textColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (fromGarmin) ...[
              const SizedBox(width: 6),
              const GarminAttribution(style: GarminAttributionStyle.compact),
            ],
          ],
        ),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: textColor.withValues(alpha: 0.5),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    super.key,
    required this.label,
    required this.kcal,
    required this.fromGarmin,
    required this.textColor,
    this.emphasized = false,
  });

  final String label;
  final double kcal;
  final bool fromGarmin;
  final Color textColor;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final weight = emphasized ? FontWeight.w700 : FontWeight.w500;
    final alpha = emphasized ? 1.0 : 0.85;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: textColor.withValues(alpha: alpha),
              fontWeight: weight,
            ),
          ),
        ),
        if (fromGarmin) ...[
          const GarminAttribution(style: GarminAttributionStyle.compact),
          const SizedBox(width: 8),
        ],
        Text(
          '${NumberFormat('#,###').format(kcal.round())} cal',
          style: AppTextStyles.bodyMedium.copyWith(
            color: textColor.withValues(alpha: alpha),
            fontWeight: weight,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
