import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../../shared/domain/activity_type.dart';
import '../../../../../shared/providers/unit_system_provider.dart';
import '../../../../../shared/utils/unit_formatter.dart';
import '../../../domain/run_parameters.dart';
import '../../utils/activity_detail_helpers.dart';

/// Displays scheduled date and time for an activity,
/// plus optional activity summary (distance/pace/duration)
/// and tappable date/time editing. A small pencil glyph beside each
/// tappable value is the "this is editable" affordance — matches the
/// New Activity screen's date/time section.
class ActivityScheduleInfo extends ConsumerWidget {
  const ActivityScheduleInfo({
    super.key,
    required this.scheduledDateTime,
    required this.activityType,
    this.distanceMiles,
    this.durationMinutes,
    this.paceTargetMinutesPerMile,
    this.onDateTap,
    this.onTimeTap,
  });

  final DateTime scheduledDateTime;
  final ActivityType activityType;
  final double? distanceMiles;
  final int? durationMinutes;
  final double? paceTargetMinutesPerMile;
  final VoidCallback? onDateTap;
  final VoidCallback? onTimeTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useMetric =
        (ref.watch(unitSystemProvider).value ?? UnitSystem.imperial) ==
        UnitSystem.metric;

    String activityLabel;
    switch (activityType) {
      case ActivityType.running:
        activityLabel = 'RUN';
        break;
      case ActivityType.cycling:
        activityLabel = 'BIKE';
        break;
      case ActivityType.swimming:
        activityLabel = 'SWIM';
        break;
      default:
        activityLabel = 'ACTIVITY';
    }

    return Column(
      children: [
        Text(
          key: const ValueKey('plan_detail.summary_label'),
          '$activityLabel SCHEDULED FOR',
          style: AppTextStyles.smallLabel.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        // Activity summary row (distance · duration · pace)
        if (_hasSummary) ...[
          const SizedBox(height: AppSpacing.xs),
          _buildActivitySummary(context, useMetric),
        ],
        const SizedBox(height: AppSpacing.sm),
        // FittedBox scales the date/time pair down so it never overflows a
        // narrow phone.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildDateColumn(context),
              const SizedBox(width: AppSpacing.xxl),
              _buildTimeColumn(context),
            ],
          ),
        ),
      ],
    );
  }

  bool get _hasSummary =>
      distanceMiles != null ||
      durationMinutes != null ||
      paceTargetMinutesPerMile != null;

  Widget _buildActivitySummary(BuildContext context, bool useMetric) {
    final parts = <String>[];

    if (distanceMiles != null) {
      parts.add(
        UnitFormatter.formatDistance(
          distanceMiles!,
          unit: useMetric ? DistanceUnit.kilometers : DistanceUnit.miles,
        ),
      );
    }

    if (durationMinutes != null) {
      parts.add(ActivityDetailHelpers.formatDuration(durationMinutes!));
    }

    if (paceTargetMinutesPerMile != null) {
      parts.add(
        UnitFormatter.formatPace(
          paceTargetMinutesPerMile!,
          unit: useMetric ? PaceUnit.minPerKm : PaceUnit.minPerMile,
        ),
      );
    }

    return Text(
      parts.join('  \u00B7  '),
      style: AppTextStyles.bodyMedium.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w600,
        fontSize: 15,
      ),
    );
  }

  Widget _buildDateColumn(BuildContext context) {
    final isTappable = onDateTap != null;
    final valueColor = Theme.of(context).colorScheme.onSurface;
    final dateWidget = Column(
      children: [
        Text(
          key: const ValueKey('plan_detail.date_label'),
          'DATE',
          style: AppTextStyles.smallLabel.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ActivityDetailHelpers.formatDateShort(scheduledDateTime),
              style: AppTextStyles.sectionTitle.copyWith(
                color: valueColor,
                fontSize: 20,
              ),
            ),
            if (isTappable) ...[
              const SizedBox(width: 4),
              FaIcon(
                FontAwesomeIcons.penToSquare,
                size: 12,
                color: valueColor.withValues(alpha: 0.4),
              ),
            ],
          ],
        ),
      ],
    );

    if (onDateTap != null) {
      return GestureDetector(
        onTap: onDateTap,
        behavior: HitTestBehavior.opaque,
        child: dateWidget,
      );
    }
    return dateWidget;
  }

  Widget _buildTimeColumn(BuildContext context) {
    final isTappable = onTimeTap != null;
    final valueColor = Theme.of(context).colorScheme.onSurface;
    final timeWidget = Column(
      children: [
        Text(
          key: const ValueKey('plan_detail.time_label'),
          'TIME',
          style: AppTextStyles.smallLabel.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ActivityDetailHelpers.formatTime(scheduledDateTime),
              style: AppTextStyles.sectionTitle.copyWith(
                color: valueColor,
                fontSize: 20,
              ),
            ),
            if (isTappable) ...[
              const SizedBox(width: 4),
              FaIcon(
                FontAwesomeIcons.penToSquare,
                size: 12,
                color: valueColor.withValues(alpha: 0.4),
              ),
            ],
          ],
        ),
      ],
    );

    if (onTimeTap != null) {
      return GestureDetector(
        onTap: onTimeTap,
        behavior: HitTestBehavior.opaque,
        child: timeWidget,
      );
    }
    return timeWidget;
  }
}
