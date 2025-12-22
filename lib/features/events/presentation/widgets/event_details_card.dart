import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import 'package:mealvana_endurance/shared/utils/location_formatter.dart';
import '../../../activities/domain/activity.dart';
import '../../domain/event.dart';

/// Event details card showing event information
class EventDetailsCard extends StatelessWidget {
  final Activity? activity;
  final Event event;

  const EventDetailsCard({
    super.key,
    required this.activity,
    required this.event,
  });

  @override
  Widget build(BuildContext context) {
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
              icon: FontAwesomeIcons.ruler,
              label: 'Distance',
              value: '${activity!.distanceMiles} miles',
            ),

          if (event.location != null) ...[
            const Divider(height: AppSpacing.xl),
            _buildDetailRow(
              context,
              icon: FontAwesomeIcons.locationDot,
              label: 'Location',
              value: LocationFormatter.parseAndFormatCityState(event.location),
            ),
          ],

          if (event.formattedGoalTime != null) ...[
            const Divider(height: AppSpacing.xl),
            _buildDetailRow(
              context,
              icon: FontAwesomeIcons.clock,
              label: 'Goal Time',
              value: event.formattedGoalTime!,
            ),
          ],

          if (event.formattedGoalPace != null) ...[
            const Divider(height: AppSpacing.xl),
            _buildDetailRow(
              context,
              icon: FontAwesomeIcons.gaugeHigh,
              label: 'Goal Pace',
              value: event.formattedGoalPace!,
            ),
          ],

          if (event.registrationUrl != null) ...[
            const Divider(height: AppSpacing.xl),
            _buildDetailRow(
              context,
              icon: FontAwesomeIcons.link,
              label: 'Registration',
              value: 'View registration',
              isLink: true,
            ),
          ],

          if (event.bibNumber != null) ...[
            const Divider(height: AppSpacing.xl),
            _buildDetailRow(
              context,
              icon: FontAwesomeIcons.hashtag,
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
