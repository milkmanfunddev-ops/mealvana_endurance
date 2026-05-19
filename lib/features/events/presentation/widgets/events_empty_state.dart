import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';

/// Empty state widget displayed when no events exist.
///
/// Shows:
/// - Calendar icon
/// - "No Events Yet" title
/// - Helpful message about creating first event
class EventsEmptyState extends StatelessWidget {
  const EventsEmptyState({super.key, this.onCreateEvent});

  final VoidCallback? onCreateEvent;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.screenPaddingHorizontal,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(
              FontAwesomeIcons.calendarDay,
              size: AppIconSizes.xxl,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              key: const ValueKey('my_events.empty_title'),
              'No Events Yet',
              style: AppTextStyles.sectionTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              key: const ValueKey('my_events.empty_subtitle'),
              'Create your first race event to get started with event-specific nutrition planning!',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (onCreateEvent != null) ...[
              const SizedBox(height: AppSpacing.xl),
              KylePrimaryButton(
                key: const ValueKey('my_events.new_event_button'),
                text: 'New Event',
                icon: FontAwesomeIcons.plus.data,
                isFullWidth: false,
                onPressed: onCreateEvent,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
