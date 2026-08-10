import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/domain/activity_type.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../activities/domain/activity.dart';
import '../../../../daily_macros/presentation/widgets/macro_palette.dart';
import '../../../domain/carbs_per_hour_summary.dart';
import '../../../domain/fuel_log_data.dart';
import '../../providers/carbs_per_hour_providers.dart';

/// Post-workout carbs-per-hour readout shown under "How did the carbs feel?".
///
/// Renders the session's during-effort carbs/hr against the athlete's recent
/// same-sport history. Has three states (see [CarbsHrState]): a full trend, a
/// "building baseline" progress view, and a "not tracked" excluded message.
class CarbsPerHourCard extends ConsumerWidget {
  const CarbsPerHourCard({
    super.key,
    required this.activity,
    required this.fuelLog,
    this.targetGPerH,
  });

  final Activity activity;
  final FuelLogData fuelLog;

  /// Planned during carb rate, used as the trend's target reference line.
  final double? targetGPerH;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // const service — read (not watch); it never changes.
    final service = ref.read(carbsPerHourServiceProvider);
    // Baseline is a fast local query; fall back to empty while it resolves so
    // the session number renders immediately rather than behind a spinner.
    final baseline = ref
        .watch(carbsPerHourBaselineProvider(activity.id, activity.activityType))
        .maybeWhen(data: (b) => b, orElse: () => CarbsPerHourBaseline.empty);

    final summary = service.buildSummary(
      activity: activity,
      fuelLog: fuelLog,
      baseline: baseline,
      targetGPerH: targetGPerH,
    );

    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardRadius,
        color: onSurface.withValues(alpha: 0.04),
        border: Border.all(color: onSurface.withValues(alpha: 0.09)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, summary),
          const SizedBox(height: AppSpacing.sm),
          _buildBody(context, summary),
          const SizedBox(height: AppSpacing.sm),
          Divider(height: 1, color: onSurface.withValues(alpha: 0.07)),
          const SizedBox(height: AppSpacing.xs),
          _buildFooter(context, summary),
        ],
      ),
    );
  }

  // --- Header: sport + duration, plus the tracked/not-tracked pill ---

  String _pillLabel(CarbsHrState state) {
    switch (state) {
      case CarbsHrState.inBaseline:
        return 'In Baseline';
      case CarbsHrState.buildingBaseline:
        return 'Tracked';
      case CarbsHrState.excluded:
        return 'Not Tracked';
    }
  }

  Widget _buildHeader(BuildContext context, CarbsPerHourSummary summary) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final tracked = summary.state != CarbsHrState.excluded;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _sportIcon(summary.activityType),
                size: 15,
                color: tracked
                    ? kMacroColorCarbs
                    : onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  summary.activityType.displayName.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.smallLabel.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: onSurface.withValues(alpha: 0.9),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                _durationLabel(summary.durationMinutes),
                style: AppTextStyles.smallLabel.copyWith(
                  color: onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
        _trackedPill(context, tracked, _pillLabel(summary.state)),
      ],
    );
  }

  Widget _trackedPill(BuildContext context, bool tracked, String label) {
    final color = tracked
        ? AppColors.electrolyte
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: AppTextStyles.smallLabel.copyWith(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // --- Body: switches on state ---

  Widget _buildBody(BuildContext context, CarbsPerHourSummary summary) {
    switch (summary.state) {
      case CarbsHrState.excluded:
        return _buildExcluded(context, summary);
      case CarbsHrState.buildingBaseline:
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildReadout(context, summary),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _buildBuildingBaseline(context, summary)),
            ],
          ),
        );
      case CarbsHrState.inBaseline:
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildReadout(context, summary),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _buildTrend(context, summary)),
            ],
          ),
        );
    }
  }

  /// The big "54g" number + label + delta chip.
  Widget _buildReadout(BuildContext context, CarbsPerHourSummary summary) {
    final showDelta =
        summary.state == CarbsHrState.inBaseline &&
        summary.deltaVsAverage != null;
    final showFirstEffort =
        summary.state == CarbsHrState.buildingBaseline &&
        summary.baselineCount == 0;
    return SizedBox(
      width: 96,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CARBS / HR',
            style: AppTextStyles.smallLabel.copyWith(
              fontSize: 10,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              color: kMacroColorCarbs,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${summary.carbsPerHour.round()}',
                style: AppTextStyles.dataNumberLarge.copyWith(
                  color: kMacroColorCarbs,
                  height: 0.95,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                'g',
                style: AppTextStyles.dataNumber.copyWith(
                  fontSize: 20,
                  color: kMacroColorCarbs.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
          if (showDelta) ...[
            const SizedBox(height: AppSpacing.xs),
            _deltaChip(context, summary.deltaVsAverage!),
          ] else if (showFirstEffort) ...[
            const SizedBox(height: AppSpacing.xs),
            _firstEffortChip(context),
          ],
        ],
      ),
    );
  }

  Widget _deltaChip(BuildContext context, double delta) {
    final up = delta >= 0;
    final color = up ? AppColors.electrolyte : AppColors.dragonfruit;
    final rounded = delta.abs().round();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            up ? Icons.arrow_drop_up : Icons.arrow_drop_down,
            size: 16,
            color: color,
          ),
          Text(
            '${up ? '+' : '−'}$rounded vs avg',
            style: AppTextStyles.smallLabel.copyWith(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _firstEffortChip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.28)),
      ),
      child: Text(
        'First effort',
        style: AppTextStyles.smallLabel.copyWith(
          fontSize: 11,
          color: AppColors.orange,
        ),
      ),
    );
  }

  /// Sparkline of the last few same-sport efforts ending with today, with
  /// dashed average + target reference lines.
  Widget _buildTrend(BuildContext context, CarbsPerHourSummary summary) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final sportShort = '${summary.activityType.displayName}s';
    final values = summary.trend;
    final candidates = <double>[
      ...values,
      if (summary.baselineAverage != null) summary.baselineAverage!,
      if (summary.targetGPerH != null) summary.targetGPerH!,
    ];
    // Defensive: inBaseline always has a non-empty trend, but never let a
    // contract violation crash the reduce below.
    if (candidates.isEmpty) return const SizedBox.shrink();
    final lo = candidates.reduce((a, b) => a < b ? a : b) - 4;
    final hi = candidates.reduce((a, b) => a > b ? a : b) + 4;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Last ${values.length} $sportShort',
              style: _trendLabel(onSurface),
            ),
            if (summary.targetGPerH != null)
              Text(
                'Target ${summary.targetGPerH!.round()}g',
                style: _trendLabel(onSurface),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          height: 56,
          child: LineChart(
            LineChartData(
              minY: lo,
              maxY: hi,
              minX: 0,
              maxX: (values.length - 1).toDouble(),
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineTouchData: const LineTouchData(enabled: false),
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  if (summary.baselineAverage != null)
                    HorizontalLine(
                      y: summary.baselineAverage!,
                      color: onSurface.withValues(alpha: 0.22),
                      strokeWidth: 1,
                      dashArray: [2, 3],
                    ),
                  if (summary.targetGPerH != null)
                    HorizontalLine(
                      y: summary.targetGPerH!,
                      color: AppColors.electrolyte.withValues(alpha: 0.3),
                      strokeWidth: 1,
                      dashArray: [3, 3],
                    ),
                ],
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    for (var i = 0; i < values.length; i++)
                      FlSpot(i.toDouble(), values[i]),
                  ],
                  isCurved: true,
                  curveSmoothness: 0.25,
                  color: kMacroColorCarbs,
                  barWidth: 2,
                  dotData: FlDotData(
                    show: true,
                    checkToShowDot: (spot, bar) =>
                        spot.x == (values.length - 1).toDouble(),
                    getDotPainter: (spot, percent, bar, index) =>
                        FlDotCirclePainter(
                          radius: 3.2,
                          color: kMacroColorCarbs,
                          strokeWidth: 1.5,
                          strokeColor: Theme.of(context).colorScheme.surface,
                        ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: kMacroColorCarbs.withValues(alpha: 0.12),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Earlier', style: _trendLabel(onSurface, faint: true)),
            Text(
              'Today',
              style: _trendLabel(
                onSurface,
              ).copyWith(color: kMacroColorCarbs.withValues(alpha: 0.85)),
            ),
          ],
        ),
      ],
    );
  }

  TextStyle _trendLabel(Color onSurface, {bool faint = false}) {
    return AppTextStyles.smallLabel.copyWith(
      fontSize: 9,
      letterSpacing: 0.6,
      color: onSurface.withValues(alpha: faint ? 0.35 : 0.4),
    );
  }

  /// Progress dots while the athlete is still establishing a baseline.
  Widget _buildBuildingBaseline(
    BuildContext context,
    CarbsPerHourSummary summary,
  ) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final sportShort = '${summary.activityType.displayName}s';
    // This session counts toward the baseline.
    final filled = (summary.baselineCount + 1).clamp(
      0,
      summary.unlockThreshold,
    );
    final remaining = (summary.unlockThreshold - filled).clamp(0, 99);
    final lower = sportShort.toLowerCase();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Building baseline', style: _trendLabel(onSurface)),
            Text(
              '$filled / ${summary.unlockThreshold} $sportShort',
              style: _trendLabel(
                onSurface,
              ).copyWith(color: kMacroColorCarbs.withValues(alpha: 0.85)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            for (var i = 0; i < summary.unlockThreshold; i++) ...[
              _baselineDot(context, filled: i < filled),
              if (i < summary.unlockThreshold - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    color: onSurface.withValues(alpha: 0.18),
                  ),
                ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          remaining == 0
              ? 'Your carb trend is ready.'
              // Only completed sessions WITH a fuel log advance the baseline —
              // an imported run that stays "planned" never will, which is
              // exactly what confused testers ("I logged runs and it still
              // says 3 of 4"). Say the real rule.
              : 'Log fuel on $remaining more completed '
                    '${summary.minimumDurationMinutes}+ min $lower to unlock '
                    'your carb trend. Imported workouts count once you '
                    'complete them and log your fuel.',
          style: AppTextStyles.smallLabel.copyWith(
            fontSize: 10.5,
            height: 1.35,
            color: onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _baselineDot(BuildContext context, {required bool filled}) {
    if (filled) {
      return Container(
        width: 13,
        height: 13,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: kMacroColorCarbs,
          boxShadow: [
            BoxShadow(
              color: kMacroColorCarbs.withValues(alpha: 0.25),
              blurRadius: 0,
              spreadRadius: 3,
            ),
          ],
        ),
      );
    }
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
    );
  }

  /// Excluded state — speed work, swim, or too-short effort.
  Widget _buildExcluded(BuildContext context, CarbsPerHourSummary summary) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: onSurface.withValues(alpha: 0.06),
            border: Border.all(color: onSurface.withValues(alpha: 0.12)),
          ),
          child: Icon(
            Icons.bolt_outlined,
            size: 18,
            color: onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Carbs/hr not tracked',
                style: AppTextStyles.sectionTitle.copyWith(
                  fontSize: 16,
                  color: onSurface.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _exclusionMessage(summary),
                style: AppTextStyles.smallLabel.copyWith(
                  fontSize: 11.5,
                  height: 1.45,
                  color: onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Footer: basis + contextual note ---

  Widget _buildFooter(BuildContext context, CarbsPerHourSummary summary) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            summary.state == CarbsHrState.excluded
                ? '${summary.totalDuringCarbsG}g carbs consumed'
                : '${summary.totalDuringCarbsG}g carbs ÷ ${_durationLabel(summary.durationMinutes)}',
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.smallLabel.copyWith(
              fontSize: 11,
              color: onSurface.withValues(alpha: 0.55),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          _footerNote(summary),
          style: AppTextStyles.smallLabel.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  String _footerNote(CarbsPerHourSummary summary) {
    switch (summary.state) {
      case CarbsHrState.excluded:
        return 'Excluded from baseline';
      case CarbsHrState.buildingBaseline:
        final n = (summary.baselineCount + 1).clamp(0, summary.unlockThreshold);
        return '$n of ${summary.unlockThreshold} baseline efforts';
      case CarbsHrState.inBaseline:
        if (summary.isHighestYet) return 'Highest intake yet';
        final delta = summary.deltaVsAverage;
        if (delta != null && delta >= 0) return 'Above baseline avg';
        return 'Below baseline avg';
    }
  }

  String _exclusionMessage(CarbsPerHourSummary summary) {
    switch (summary.exclusionReason) {
      case CarbsHrExclusionReason.speedWork:
        return 'Speed sessions aren\'t compared against your fueling baseline. '
            'Carbs/hr is tracked only on long efforts — '
            '${summary.minimumDurationMinutes} minutes or more.';
      case CarbsHrExclusionReason.tooShort:
        return 'Carbs/hr is tracked only on long efforts — '
            '${summary.minimumDurationMinutes} minutes or more.';
      case CarbsHrExclusionReason.swim:
        return 'Carbs/hr isn\'t tracked for swims.';
      case CarbsHrExclusionReason.none:
        return '';
    }
  }

  IconData _sportIcon(ActivityType type) {
    switch (type) {
      case ActivityType.cycling:
        return Icons.directions_bike;
      case ActivityType.swimming:
        return Icons.pool;
      case ActivityType.running:
      default:
        return Icons.directions_run;
    }
  }

  String _durationLabel(int minutes) {
    if (minutes <= 0) return '—';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m}m';
  }
}
