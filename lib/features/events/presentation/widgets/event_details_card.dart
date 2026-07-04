import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import 'package:mealvana_endurance/shared/utils/location_formatter.dart';
import 'package:mealvana_endurance/shared/providers/unit_system_provider.dart';
import 'package:mealvana_endurance/shared/utils/unit_formatter.dart';
import '../../../activities/domain/activity.dart';
import '../../../nutrition_plan/domain/run_parameters.dart';
import '../../domain/event.dart';

/// Event details card showing event information
class EventDetailsCard extends ConsumerWidget {
  final Activity? activity;
  final Event event;

  const EventDetailsCard({
    super.key,
    required this.activity,
    required this.event,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useMetric =
        (ref.watch(unitSystemProvider).value ?? UnitSystem.imperial) ==
        UnitSystem.metric;

    return BaseCard(
      margin: AppSpacing.screenPaddingHorizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Event Information',
            style: AppTextStyles.subtitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Distance
          if (activity?.distanceMiles != null)
            _buildDetailRow(
              context,
              icon: FontAwesomeIcons.ruler.data,
              label: 'Distance',
              value: UnitFormatter.formatDistance(
                activity!.distanceMiles!,
                unit: useMetric ? DistanceUnit.kilometers : DistanceUnit.miles,
              ),
            ),

          if (event.location != null) ...[
            const Divider(height: AppSpacing.xl),
            _buildDetailRow(
              context,
              icon: FontAwesomeIcons.locationDot.data,
              label: 'Location',
              value: LocationFormatter.parseAndFormatCityState(event.location),
            ),
          ],

          if (event.formattedGoalTime != null) ...[
            const Divider(height: AppSpacing.xl),
            _buildDetailRow(
              context,
              icon: FontAwesomeIcons.clock.data,
              label: 'Goal Time',
              value: event.formattedGoalTime!,
            ),
          ],

          if (event.formattedGoalPace != null) ...[
            const Divider(height: AppSpacing.xl),
            _buildDetailRow(
              context,
              icon: FontAwesomeIcons.gaugeHigh.data,
              label: 'Goal Pace',
              value: event.formattedGoalPace!,
            ),
          ],

          if (event.registrationUrl != null) ...[
            const Divider(height: AppSpacing.xl),
            _buildDetailRow(
              context,
              icon: FontAwesomeIcons.link.data,
              label: 'Registration',
              value: 'View registration',
              isLink: true,
            ),
          ],

          if (event.bibNumber != null) ...[
            const Divider(height: AppSpacing.xl),
            _buildDetailRow(
              context,
              icon: FontAwesomeIcons.hashtag.data,
              label: 'Bib Number',
              value: event.bibNumber!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    bool isLink = false,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: AppIconSizes.sm,
          color: AppColors.electrolyte,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.smallLabel.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                value,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: isLink
                      ? AppColors.electrolyte
                      : Theme.of(context).colorScheme.onSurface,
                  decoration: isLink ? TextDecoration.underline : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
