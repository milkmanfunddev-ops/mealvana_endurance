import 'package:flutter/material.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../../shared/domain/activity_type.dart';
import '../../utils/activity_detail_helpers.dart';

/// Displays scheduled date and time for an activity,
/// plus optional activity summary (distance/pace/duration)
/// and tappable date/time editing.
class ActivityScheduleInfo extends StatelessWidget {
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

  String _formatPace(double minutesPerMile) {
    final mins = minutesPerMile.floor();
    final secs = ((minutesPerMile - mins) * 60).round();
    return '$mins:${secs.toString().padLeft(2, '0')}/mi';
  }

  @override
  Widget build(BuildContext context) {
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
          _buildActivitySummary(context),
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

  Widget _buildActivitySummary(BuildContext context) {
    final parts = <String>[];

    if (distanceMiles != null) {
      final d = distanceMiles!;
      final display = d == d.roundToDouble()
          ? d.toInt().toString()
          : d.toStringAsFixed(1);
      parts.add('$display mi');
    }

    if (durationMinutes != null) {
      parts.add(ActivityDetailHelpers.formatDuration(durationMinutes!));
    }

    if (paceTargetMinutesPerMile != null) {
      parts.add(_formatPace(paceTargetMinutesPerMile!));
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
        Text(
          ActivityDetailHelpers.formatDateShort(scheduledDateTime),
          style: AppTextStyles.sectionTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 20,
          ),
        ),
      ],
    );

    if (onDateTap != null) {
      return GestureDetector(onTap: onDateTap, child: dateWidget);
    }
    return dateWidget;
  }

  Widget _buildTimeColumn(BuildContext context) {
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
        Text(
          ActivityDetailHelpers.formatTime(scheduledDateTime),
          style: AppTextStyles.sectionTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 20,
          ),
        ),
      ],
    );

    if (onTimeTap != null) {
      return GestureDetector(onTap: onTimeTap, child: timeWidget);
    }
    return timeWidget;
  }
}
