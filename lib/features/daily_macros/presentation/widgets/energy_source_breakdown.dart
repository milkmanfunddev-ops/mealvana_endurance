import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../integrations/presentation/widgets/garmin_attribution.dart';
import '../../domain/daily_macro_targets.dart';

/// Per-line breakdown of TDEE components (RMR, NEAT, Activity) with source
/// attribution for each. When a value comes from Garmin Connect, the row
/// shows a Garmin tag chip — fulfilling the API brand-guideline requirement
/// that Garmin-derived data is attributed wherever it surfaces.
class EnergySourceBreakdown extends StatelessWidget {
  const EnergySourceBreakdown({
    super.key,
    required this.macros,
  });

  final DailyMacroTargets macros;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final sources = macros.sources;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Body composition — shows the actual weight + body fat used in the
        // calc, with Garmin attribution when those values came from a Garmin
        // body-comp scale via the latest-wins resolver.
        if (macros.weightKg != null || macros.bodyFatPct != null) ...[
          _BodyCompositionRow(
            weightKg: macros.weightKg,
            bodyFatPct: macros.bodyFatPct,
            weightFromGarmin: sources?.weightFromGarmin ?? false,
            bodyFatFromGarmin: sources?.bodyFatFromGarmin ?? false,
            textColor: textColor,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Text(
          'Energy Breakdown',
          style: AppTextStyles.bodySmall.copyWith(
            color: textColor.withValues(alpha: 0.5),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _BreakdownRow(
          label: 'Resting',
          kcal: macros.rmr,
          fromGarmin: sources?.rmrFromGarmin ?? false,
          textColor: textColor,
        ),
        if (macros.neatKcal != null && macros.neatKcal! > 0) ...[
          const SizedBox(height: 6),
          _BreakdownRow(
            label: 'Daily activity',
            kcal: macros.neatKcal!,
            fromGarmin: sources?.neatFromGarmin ?? false,
            textColor: textColor,
          ),
        ],
        if (macros.sessionKcal > 0) ...[
          const SizedBox(height: 6),
          _BreakdownRow(
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
  });

  final double? weightKg;
  final double? bodyFatPct;
  final bool weightFromGarmin;
  final bool bodyFatFromGarmin;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final pieces = <Widget>[];

    if (weightKg != null) {
      // Display in lbs since the rest of the app uses imperial.
      final lbs = (weightKg! * 2.20462).round();
      pieces.add(_ValueWithBadge(
        label: 'Weight',
        value: '$lbs lbs',
        fromGarmin: weightFromGarmin,
        textColor: textColor,
      ));
    }
    if (bodyFatPct != null) {
      pieces.add(_ValueWithBadge(
        label: 'Body fat',
        value: '${bodyFatPct!.toStringAsFixed(1)}%',
        fromGarmin: bodyFatFromGarmin,
        textColor: textColor,
      ));
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
