import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../../shared/providers/unit_system_provider.dart';
import '../../../../../shared/utils/unit_formatter.dart';
import '../../../../activities/domain/activity.dart';
import '../../../domain/run_parameters.dart';

/// Compact header shown during fuel log mode, replacing the hero section.
/// Displays activity type label, key stats (distance, duration, pace), and date.
class FuelLogCompactHeader extends ConsumerWidget {
  const FuelLogCompactHeader({super.key, required this.activity});

  final Activity activity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final useMetric =
        (ref.watch(unitSystemProvider).value ?? UnitSystem.imperial) ==
        UnitSystem.metric;
    final statsParts = <String>[];

    if (activity.distanceMiles != null) {
      statsParts.add(
        UnitFormatter.formatDistance(
          activity.distanceMiles!,
          unit: useMetric ? DistanceUnit.kilometers : DistanceUnit.miles,
        ),
      );
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
      statsParts.add(
        UnitFormatter.formatPace(
          activity.paceTargetMinutesPerMile!,
          unit: useMetric ? PaceUnit.minPerKm : PaceUnit.minPerMile,
        ),
      );
    }

    final dateStr = DateFormat(
      'EEEE, MMM d',
    ).format(activity.scheduledDateTime);

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
