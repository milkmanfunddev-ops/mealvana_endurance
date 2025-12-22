import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../application/events_service.dart';
import '../../../activities/application/activities_service.dart';
import '../../../carb_loading/presentation/providers/carb_loading_controller.dart';
import '../../domain/event.dart';
import '../../../activities/domain/activity.dart';
import '../../../../shared/services/logging_service.dart';
import '../../../../shared/providers/user_id_provider.dart';
import '../../../../shared/domain/activity_type.dart';

part 'events_controller.g.dart';

/// Controller for managing events
/// Handles event CRUD operations (create, read, update, delete)
@riverpod
class EventsController extends _$EventsController {
  @override
  FutureOr<List<Event>> build() async {
    // Cache service reference before async operations
    final service = ref.read(eventsServiceProvider);

    // Load all events on build
    final userId = await ref.read(userIdProvider.future);
    return await service.getAllEvents(userId);
  }

  /// Create a new event
  /// Note: Does NOT invalidate the provider - calling code should handle refresh
  Future<String> createEvent({
    String? activityId,
    required ActivityType eventType,
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
    // Keep provider alive during async work when invoked via ref.read (no listeners)
    final keepAliveLink = ref.keepAlive();

    // CRITICAL: Cache ALL ref-dependent values BEFORE any async operations
    // to avoid "Ref disposed" errors if provider rebuilds during async work
    final service = ref.read(eventsServiceProvider);
    final logger = ref.read(appLoggerProvider);

    try {
      // Read deviceId BEFORE async operations
      final deviceIdValue = await ref.read(userIdProvider.future);

      // Use cached service reference (no ref access after this point)
      final createdEvent = await service.createEvent(
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

      // Check if provider is still mounted before accessing ref
      if (!ref.mounted) return createdEvent.id;

      // Invalidate providers to refresh UI
      ref.invalidateSelf();
      ref.invalidate(nextUpcomingEventProvider);
      ref.invalidate(allEventsProvider);

      return createdEvent.id;
    } catch (e) {
      // Use cached logger (safe - no ref access)
      logger.error('Error creating event', error: e);
      rethrow;
    } finally {
      keepAliveLink.close();
    }
  }

  /// Update an existing event
  /// Note: Does NOT invalidate the provider - calling code should handle refresh
  Future<void> updateEvent(Event event) async {
    final keepAliveLink = ref.keepAlive();

    // CRITICAL: Cache ALL ref-dependent values BEFORE any async operations
    final service = ref.read(eventsServiceProvider);
    final logger = ref.read(appLoggerProvider);

    try {
      final deviceIdValue = await ref.read(userIdProvider.future);

      await service.updateEvent(
        deviceId: deviceIdValue,
        event: event,
      );

      // Check if provider is still mounted before accessing ref
      if (!ref.mounted) return;

      // Invalidate providers to refresh UI
      ref.invalidateSelf();
      ref.invalidate(nextUpcomingEventProvider);
      ref.invalidate(allEventsProvider);
    } catch (e) {
      logger.error('Error updating event', error: e);
      rethrow;
    } finally {
      keepAliveLink.close();
    }
  }

  /// Delete an event
  /// Also cascade deletes any associated carb loading plan and invalidates related providers
  Future<void> deleteEvent(String eventId) async {
    final keepAliveLink = ref.keepAlive();

    // CRITICAL: Cache ALL ref-dependent values BEFORE any async operations
    final service = ref.read(eventsServiceProvider);
    final logger = ref.read(appLoggerProvider);

    try {
      final deviceIdValue = await ref.read(userIdProvider.future);

      await service.deleteEvent(
        deviceId: deviceIdValue,
        eventId: eventId,
      );

      // Check if provider is still mounted before accessing ref
      if (!ref.mounted) return;

      // Invalidate event providers to refresh UI
      ref.invalidateSelf();
      ref.invalidate(nextUpcomingEventProvider);
      ref.invalidate(allEventsProvider);

      // Invalidate carb loading providers to refresh calendar UI
      // The event deletion cascades to carb loading data in the repository layer
      ref.invalidate(carbLoadingDaysForRangeProvider);
      ref.invalidate(carbLoadingPlanProvider(eventId));
    } catch (e) {
      logger.error('Error deleting event', error: e);
      rethrow;
    } finally {
      keepAliveLink.close();
    }
  }

  /// Get event by ID
  Future<Event?> getEventById(String eventId) async {
    // CRITICAL: Cache ALL ref-dependent values BEFORE any async operations
    final service = ref.read(eventsServiceProvider);
    final logger = ref.read(appLoggerProvider);

    try {
      final userId = await ref.read(userIdProvider.future);
      return await service.getEventById(userId, eventId);
    } catch (e) {
      logger.error('Error getting event by ID', error: e);
      rethrow;
    }
  }

  /// Get event for a specific activity
  Future<Event?> getEventForActivity(String activityId) async {
    // CRITICAL: Cache ALL ref-dependent values BEFORE any async operations
    final service = ref.read(eventsServiceProvider);
    final logger = ref.read(appLoggerProvider);

    try {
      return await service.getEventForActivity(activityId);
    } catch (e) {
      logger.error('Error getting event for activity', error: e);
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
  final logger = ref.read(appLoggerProvider);
  final userId = await ref.read(userIdProvider.future);

  final eventsService = ref.read(eventsServiceProvider);
  final activitiesService = ref.read(activitiesServiceProvider);
  //get all events
  final events = await eventsService.getAllEvents(userId);
  final event = await eventsService.getEventById(userId, eventId);
  if (event == null) {
    logger.error('EventDetail: Event not found', context: 'EVENT_DETAIL', data: {'eventId': eventId});
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
  final userId = await ref.read(userIdProvider.future);
  final service = ref.read(eventsServiceProvider);
  return await service.getAllEvents(userId);
}

/// Provider for getting next upcoming event
@riverpod
Future<({Event event, DateTime eventDate})?> nextUpcomingEvent(Ref ref) async {
  final now = DateTime.now();
  final userId = await ref.read(userIdProvider.future);
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
