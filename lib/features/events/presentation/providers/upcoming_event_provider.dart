import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/event.dart';
import '../../../activities/domain/activity.dart';
import '../../../activities/application/activities_service.dart';
import '../../application/events_service.dart';
import '../../../../shared/providers/device_id_provider.dart';

part 'upcoming_event_provider.g.dart';

/// Provider for next upcoming event from a specific date
@riverpod
Future<({Event event, DateTime eventDate})?> nextUpcomingEventFromDate(
  Ref ref,
  DateTime fromDate,
) async {
  final userId = await ref.read(deviceIdProvider.future);
  final eventsService = ref.read(eventsServiceProvider);
  final activitiesService = ref.read(activitiesServiceProvider);

  final events = await eventsService.getAllEvents(userId);

  Event? nextEvent;
  DateTime? nextEventDate;

  for (final event in events) {
    if (event.activityId != null) {
      final activity = await activitiesService.getActivityById(userId, event.activityId!);
      if (activity != null && activity.scheduledDateTime.isAfter(fromDate)) {
        if (nextEventDate == null || activity.scheduledDateTime.isBefore(nextEventDate)) {
          nextEvent = event;
          nextEventDate = activity.scheduledDateTime;
        }
      }
    }
  }

  if (nextEvent != null && nextEventDate != null) {
    return (event: nextEvent, eventDate: nextEventDate);
  }

  return null;
}
