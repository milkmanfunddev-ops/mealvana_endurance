import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../application/events_service.dart';
import '../../../activities/application/activities_service.dart';
import '../../domain/event.dart';
import '../../../activities/domain/activity.dart';
import '../../../../shared/services/logging_service.dart';
import '../../../../shared/providers/device_id_provider.dart';

part 'events_controller.g.dart';

/// Controller for managing events
/// Handles event CRUD operations (create, read, update, delete)
@riverpod
class EventsController extends _$EventsController {
  EventsService get _service => ref.read(eventsServiceProvider);
  AppLogger get _logger => ref.read(appLoggerProvider);

  @override
  FutureOr<List<Event>> build() async {
    // Load all events on build
    final userId = await ref.read(deviceIdProvider.future);
    return await _service.getAllEvents(userId);
  }

  /// Create a new event
  Future<String> createEvent({
    String? activityId,
    required EventType eventType,
    String? eventSubtype,
    String? eventName,
    String? location,
    String? registrationUrl,
    String? startTime,
    int? goalTimeMinutes,
    double? goalPaceMinutesPerMile,
    int? predictedFinishTimeMinutes,
    bool? hasCarbLoading,
    int? carbLoadingDays,
    DateTime? carbLoadingStartDate,
    String? bibNumber,
    String? waveStartTime,
    String? packetPickupInfo,
  }) async {
    try {
      final deviceIdValue = await ref.read(deviceIdProvider.future);

      final createdEvent = await _service.createEvent(
        deviceId: deviceIdValue,
        activityId: activityId,
        eventType: eventType,
        eventSubtype: eventSubtype,
        eventName: eventName,
        location: location,
        registrationUrl: registrationUrl,
        startTime: startTime,
        goalTimeMinutes: goalTimeMinutes,
        goalPaceMinutesPerMile: goalPaceMinutesPerMile,
        predictedFinishTimeMinutes: predictedFinishTimeMinutes,
        hasCarbLoading: hasCarbLoading,
        carbLoadingDays: carbLoadingDays,
        carbLoadingStartDate: carbLoadingStartDate,
        bibNumber: bibNumber,
        waveStartTime: waveStartTime,
        packetPickupInfo: packetPickupInfo,
      );

      // Refresh events list and upcoming event widget
      ref.invalidateSelf();
      ref.invalidate(nextUpcomingEventProvider);

      return createdEvent.id;
    } catch (e) {
      _logger.error('Error creating event', error: e);
      rethrow;
    }
  }

  /// Update an existing event
  Future<void> updateEvent(Event event) async {
    try {
      final deviceIdValue = await ref.read(deviceIdProvider.future);

      await _service.updateEvent(
        deviceId: deviceIdValue,
        event: event,
      );

      // Refresh events list and upcoming event widget
      ref.invalidateSelf();
      ref.invalidate(nextUpcomingEventProvider);
    } catch (e) {
      _logger.error('Error updating event', error: e);
      rethrow;
    }
  }

  /// Delete an event
  Future<void> deleteEvent(String eventId) async {
    try {
      final deviceIdValue = await ref.read(deviceIdProvider.future);

      await _service.deleteEvent(
        deviceId: deviceIdValue,
        eventId: eventId,
      );

      // Refresh events list and upcoming event widget
      ref.invalidateSelf();
      ref.invalidate(nextUpcomingEventProvider);
    } catch (e) {
      _logger.error('Error deleting event', error: e);
      rethrow;
    }
  }

  /// Get event by ID
  Future<Event?> getEventById(String eventId) async {
    try {
      final userId = await ref.read(deviceIdProvider.future);
      return await _service.getEventById(userId, eventId);
    } catch (e) {
      _logger.error('Error getting event by ID', error: e);
      rethrow;
    }
  }

  /// Get event for a specific activity
  Future<Event?> getEventForActivity(String activityId) async {
    try {
      return await _service.getEventForActivity(activityId);
    } catch (e) {
      _logger.error('Error getting event for activity', error: e);
      rethrow;
    }
  }

  /// Update event's nutrition plan flag
  Future<void> updateEventNutritionPlanFlag({
    required String activityId,
    required bool hasNutritionPlan,
  }) async {
    try {
      await _service.updateEventNutritionPlanFlag(
        activityId: activityId,
        hasNutritionPlan: hasNutritionPlan,
      );

      // Refresh events list
      ref.invalidateSelf();
    } catch (e) {
      _logger.error('Error updating event nutrition plan flag', error: e);
      rethrow;
    }
  }

  /// Refresh events list
  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

/// Provider for getting event detail with associated activity
@riverpod
Future<({Activity? activity, Event event})> eventDetail(Ref ref, String eventId) async {
  final userId = await ref.read(deviceIdProvider.future);
  final eventsService = ref.read(eventsServiceProvider);
  final activitiesService = ref.read(activitiesServiceProvider);

  final event = await eventsService.getEventById(userId, eventId);
  if (event == null) {
    throw Exception('Event not found: $eventId');
  }

  Activity? activity;
  if (event.activityId != null) {
    activity = await activitiesService.getActivityById(userId, event.activityId!);
  }

  return (activity: activity, event: event);
}

/// Provider for getting all events
@riverpod
Future<List<Event>> allEvents(Ref ref) async {
  final userId = await ref.read(deviceIdProvider.future);
  final service = ref.read(eventsServiceProvider);
  return await service.getAllEvents(userId);
}

/// Provider for getting next upcoming event
@riverpod
Future<({Event event, DateTime eventDate})?> nextUpcomingEvent(Ref ref) async {
  final now = DateTime.now();
  final userId = await ref.read(deviceIdProvider.future);
  final eventsService = ref.read(eventsServiceProvider);

  // Get all events
  final events = await eventsService.getAllEvents(userId);

  // Find the next upcoming event by checking the event's startTime field
  Event? nextEvent;
  DateTime? nextEventDate;

  for (final event in events) {
    // Parse the event's startTime field directly (no activityId required)
    if (event.startTime != null && event.startTime!.isNotEmpty) {
      try {
        final eventDateTime = DateTime.parse(event.startTime!);
        if (eventDateTime.isAfter(now)) {
          // Check if this is the closest upcoming event
          if (nextEventDate == null || eventDateTime.isBefore(nextEventDate)) {
            nextEvent = event;
            nextEventDate = eventDateTime;
          }
        }
      } catch (e) {
        // Skip events with invalid startTime format
        continue;
      }
    }
  }

  if (nextEvent != null && nextEventDate != null) {
    return (event: nextEvent, eventDate: nextEventDate);
  }

  return null;
}
