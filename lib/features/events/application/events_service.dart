import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/event.dart' as domain;
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/logging_service.dart';
import '../data/events_repository.dart';
import '../../activities/application/activities_service.dart';

part 'events_service.g.dart';

@riverpod
EventsService eventsService(Ref ref) {
  return EventsService(
    ref.read(appDatabaseProvider),
    ref.read(appLoggerProvider),
    ref.read(eventsRepositoryProvider),
    ref.read(activitiesServiceProvider),
  );
}

/// Service for managing calendar events
/// Handles all event-related operations including CRUD for race events
class EventsService {
  final AppDatabase _database;
  final AppLogger _logger;
  final EventsRepository _eventsRepository;
  final ActivitiesService _activitiesService;

  EventsService(
    this._database,
    this._logger,
    this._eventsRepository,
    this._activitiesService,
  );

  /// Get event for a specific activity
  Future<domain.Event?> getEventForActivity(String activityId) async {
    try {
      final query = _database.select(_database.eventsTable)
            ..where((tbl) => tbl.activityId.equals(activityId));

      final event = await query.getSingleOrNull();

      return event != null ? _mapToEventDomain(event) : null;
    } catch (e, stackTrace) {
      _logger.error(
        'Error getting event for activity: $activityId',
        context: 'EVENTS_SERVICE',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get a specific event by ID
  Future<domain.Event?> getEventById(String userId, String eventId) async {
    try {
      final query = _database.select(_database.eventsTable)
            ..where((tbl) => tbl.id.equals(eventId));

      final event = await query.getSingleOrNull();

      return event != null ? _mapToEventDomain(event) : null;
    } catch (e) {
      _logger.error('Error getting event by ID: $eventId', error: e);
      rethrow;
    }
  }

  /// Get all events for a user
  Future<List<domain.Event>> getAllEvents(String userId) async {
    try {
      final query = _database.select(_database.eventsTable)
            ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]);

      final events = await query.get();

      return events.map(_mapToEventDomain).toList();
    } catch (e) {
      _logger.error('Error getting all events', error: e);
      rethrow;
    }
  }

  /// Get events for a specific week
  Future<List<domain.Event>> getEventsForWeek(String userId, DateTime weekStart) async {
    try {
      final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

      // Get all events
      final allEvents = await getAllEvents(userId);

      // Filter events that have activities in this week
      final eventsInWeek = <domain.Event>[];
      for (final event in allEvents) {
        if (event.activityId != null) {
          final activity = await _activitiesService.getActivityById(userId, event.activityId!);
          if (activity != null &&
              activity.scheduledDateTime.isAfter(weekStart) &&
              activity.scheduledDateTime.isBefore(weekEnd)) {
            eventsInWeek.add(event);
          }
        }
      }

      return eventsInWeek;
    } catch (e) {
      _logger.error('Error getting events for week', error: e);
      rethrow;
    }
  }

  /// Create an event (optionally linked to an activity)
  Future<domain.Event> createEvent({
    required String deviceId,
    String? activityId,
    required domain.EventType eventType,
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
      final id = _generateId();
      final now = DateTime.now();

      final event = domain.Event(
        id: id,
        userId: deviceId,
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
        hasCarbLoading: hasCarbLoading ?? false,
        carbLoadingDays: carbLoadingDays,
        carbLoadingStartDate: carbLoadingStartDate,
        bibNumber: bibNumber,
        waveStartTime: waveStartTime,
        packetPickupInfo: packetPickupInfo,
        createdAt: now,
        updatedAt: now,
      );

      return await _eventsRepository.createEvent(
        deviceId: deviceId,
        event: event,
      );
    } catch (e) {
      _logger.error('Error creating event', error: e);
      rethrow;
    }
  }

  /// Update an existing event
  Future<void> updateEvent({
    required String deviceId,
    required domain.Event event,
  }) async {
    try {
      final updatedEvent = event.copyWith(updatedAt: DateTime.now());

      await _eventsRepository.updateEvent(
        deviceId: deviceId,
        event: updatedEvent,
      );
    } catch (e, stackTrace) {
      _logger.error('Error updating event', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Delete an event
  Future<void> deleteEvent({
    required String deviceId,
    required String eventId,
  }) async {
    try {
      await _eventsRepository.deleteEvent(
        deviceId: deviceId,
        eventId: eventId,
      );
    } catch (e, stackTrace) {
      _logger.error('Error deleting event', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Update event's nutrition plan flag
  Future<void> updateEventNutritionPlanFlag({
    required String activityId,
    required bool hasNutritionPlan,
  }) async {
    try {
      await _eventsRepository.updateEventNutritionPlanFlag(
        activityId: activityId,
        hasNutritionPlan: hasNutritionPlan,
      );

    } catch (e) {
      _logger.error('Error updating event nutrition plan flag', error: e);
      rethrow;
    }
  }

  /// Generate a unique ID for events
  String _generateId() {
    return 'event_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Map database Event to domain Event
  domain.Event _mapToEventDomain(Event event) {
    return domain.Event(
      id: event.id,
      userId: event.userId,
      activityId: event.activityId,
      eventType: domain.EventTypeExtension.fromDbValue(event.eventType),
      eventSubtype: event.eventSubtype,
      eventName: event.eventName,
      location: event.location,
      registrationUrl: event.registrationUrl,
      startTime: event.startTime,
      goalTimeMinutes: event.goalTimeMinutes,
      goalPaceMinutesPerMile: event.goalPaceMinutesPerMile,
      predictedFinishTimeMinutes: event.predictedFinishTimeMinutes,
      hasCarbLoading: event.hasCarbLoading,
      carbLoadingDays: event.carbLoadingDays,
      carbLoadingStartDate: event.carbLoadingStartDate,
      hasNutritionPlan: event.hasNutritionPlan,
      bibNumber: event.bibNumber,
      waveStartTime: event.waveStartTime,
      packetPickupInfo: event.packetPickupInfo,
      actualFinishTimeMinutes: event.actualFinishTimeMinutes,
      finalPlacement: event.finalPlacement,
      ageGroupPlacement: event.ageGroupPlacement,
      createdAt: event.createdAt,
      updatedAt: event.updatedAt,
    );
  }
}
