import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import '../screens/event_form_screen.dart';
import '../screens/event_detail_screen.dart';

/// Footer links widget for event navigation
class EventFooterLinks extends StatelessWidget {
  const EventFooterLinks({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.screenPaddingHorizontal,
      child: Column(
        children: [
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.xl,
            runSpacing: AppSpacing.xs,
            children: [
              TextButton(
                key: const ValueKey('event_details.view_events_link'),
                onPressed: () => context.push('/events'),
                child: Text(
                  'View events list',
                  style: AppTextStyles.buttonTertiary.copyWith(
                    color: AppColors.electrolyte,
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey('event_details.create_new_event_link'),
                onPressed: () async {
                  final result = await Navigator.of(context)
                      .push<Map<String, dynamic>>(
                        MaterialPageRoute(
                          builder: (_) => const EventFormScreen(),
                        ),
                      );
                  if (result != null && result['success'] == true) {
                    final newEventId = result['eventId'];
                    if (newEventId is String && context.mounted) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) =>
                              EventDetailScreen(eventId: newEventId),
                        ),
                      );
                    }
                  }
                },
                child: Text(
                  'Create new event',
                  style: AppTextStyles.buttonTertiary.copyWith(
                    color: AppColors.electrolyte,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
