import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../activities/domain/activity.dart';

/// Compact header shown during fuel log mode, replacing the hero section.
/// Displays activity type label, key stats (distance, duration, pace), and date.
class FuelLogCompactHeader extends StatelessWidget {
  const FuelLogCompactHeader({
    super.key,
    required this.activity,
  });

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statsParts = <String>[];

    if (activity.distanceMiles != null) {
      statsParts.add('${activity.distanceMiles!.toStringAsFixed(0)} mi');
    }
    if (activity.durationMinutes != null) {
      final hours = activity.durationMinutes! ~/ 60;
      final mins = activity.durationMinutes! % 60;
      if (hours > 0) {
        statsParts.add('${hours}h ${mins}m');
      } else {
        statsParts.add('${mins}m');
      }
    }
    if (activity.paceTargetMinutesPerMile != null) {
      final pace = activity.paceTargetMinutesPerMile!;
      final minutes = pace.floor();
      final seconds = ((pace - minutes) * 60).round();
      statsParts
          .add("$minutes:${seconds.toString().padLeft(2, '0')}/mi");
    }

    final dateStr = DateFormat('EEEE, MMM d').format(
      activity.scheduledDateTime,
    );

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.md,
      ),
      child: Column(
        children: [
          // Activity type label
          Text(
            activity.title.toUpperCase(),
            style: AppTextStyles.smallLabel.copyWith(
              color: AppColors.orange,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          if (statsParts.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              statsParts.join(' \u00B7 '),
              style: AppTextStyles.bodyMedium.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xxs),
          Text(
            dateStr,
            style: AppTextStyles.bodySmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
