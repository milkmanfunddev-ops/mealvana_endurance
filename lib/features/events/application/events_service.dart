import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/event.dart' as domain;
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/domain/activity_type.dart';
import '../data/events_repository.dart';
import '../../activities/application/activities_service.dart';
import '../../coach_mode/data/coach_repository.dart';

part 'events_service.g.dart';

@riverpod
EventsService eventsService(Ref ref) {
  return EventsService(
    ref.read(appDatabaseProvider),
    ref.read(appLoggerProvider),
    ref.read(eventsRepositoryProvider),
    ref.read(activitiesServiceProvider),
    ref.read(coachRepositoryProvider),
  );
}

/// Service for managing calendar events
/// Handles all event-related operations including CRUD for race events
class EventsService {
  final AppDatabase _database;
  final AppLogger _logger;
  final EventsRepository _eventsRepository;
  final ActivitiesService _activitiesService;
  final CoachRepository _coachRepository;

  EventsService(
    this._database,
    this._logger,
    this._eventsRepository,
    this._activitiesService,
    this._coachRepository,
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
        ..where((tbl) =>
            tbl.id.equals(eventId) &
            tbl.userId.lower().equals(userId.toLowerCase()));

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
        ..where((tbl) => tbl.userId.lower().equals(userId.toLowerCase()))
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
  /// If [forUserId] is provided and different from [deviceId], validates coach-athlete relationship
  Future<domain.Event> createEvent({
    required String deviceId,
    String? forUserId, // NEW: If provided, create event for this user (coach creating for athlete)
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
    try {
      // Determine the owner of the event
      final ownerId = forUserId ?? deviceId;

      // Validate coach-athlete relationship if creating for someone else
      if (forUserId != null && forUserId != deviceId) {
        final hasActiveRelationship = await _coachRepository
            .isActiveCoachAthleteRelationship(
          coachUserId: deviceId,
          athleteUserId: forUserId,
        );

        if (!hasActiveRelationship) {
          _logger.error(
            'Coach does not have active relationship with athlete',
            context: 'EVENTS_SERVICE',
            data: {
              'coachUserId': deviceId,
              'athleteUserId': forUserId,
            },
          );
          throw Exception(
              'Not authorized to create events for this athlete');
        }
      }

      final now = DateTime.now();

      // Parse eventDate from startTime if available
      DateTime? eventDate;
      if (startTime != null && startTime.isNotEmpty) {
        try {
          final parsedDateTime = DateTime.parse(startTime);
          // Extract just the date portion (no time)
          eventDate = DateTime(
            parsedDateTime.year,
            parsedDateTime.month,
            parsedDateTime.day,
          );
        } catch (e) {
          _logger.warning('Failed to parse startTime for eventDate: $startTime', error: e);
        }
      }

      final event = domain.Event(
        id: '', // Empty string - repository will assign actual ID
        userId: ownerId, // Use ownerId (athlete if coach is creating for them)
        activityId: activityId,
        eventType: eventType,
        eventSubtype: eventSubtype,
        eventName: eventName,
        location: location,
        registrationUrl: registrationUrl,
        eventDate: eventDate, // Set the event date for calendar display
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
  /// If [currentUserId] is provided and different from event.userId, validates coach-athlete relationship
  Future<void> updateEvent({
    required String deviceId,
    required domain.Event event,
    String? currentUserId, // NEW: Current user ID (for validation if coach is editing athlete's event)
  }) async {
    try {
      // Validate coach-athlete relationship if editing for someone else
      if (currentUserId != null && currentUserId != event.userId) {
        final hasActiveRelationship = await _coachRepository
            .isActiveCoachAthleteRelationship(
          coachUserId: currentUserId,
          athleteUserId: event.userId,
        );

        if (!hasActiveRelationship) {
          _logger.error(
            'Coach does not have active relationship with athlete',
            context: 'EVENTS_SERVICE',
            data: {
              'coachUserId': currentUserId,
              'athleteUserId': event.userId,
            },
          );
          throw Exception(
              'Not authorized to update events for this athlete');
        }
      }

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
  /// If [currentUserId] is provided, validates coach-athlete relationship for cross-user deletion
  Future<void> deleteEvent({
    required String deviceId,
    required String eventId,
    String? currentUserId, // NEW: Current user ID (for validation if coach is deleting athlete's event)
    String? eventOwnerId, // NEW: Event owner ID (for validation)
  }) async {
    try {
      // Validate coach-athlete relationship if deleting for someone else
      if (currentUserId != null && eventOwnerId != null && currentUserId != eventOwnerId) {
        final hasActiveRelationship = await _coachRepository
            .isActiveCoachAthleteRelationship(
          coachUserId: currentUserId,
          athleteUserId: eventOwnerId,
        );

        if (!hasActiveRelationship) {
          _logger.error(
            'Coach does not have active relationship with athlete',
            context: 'EVENTS_SERVICE',
            data: {
              'coachUserId': currentUserId,
              'athleteUserId': eventOwnerId,
            },
          );
          throw Exception(
              'Not authorized to delete events for this athlete');
        }
      }

      await _eventsRepository.deleteEvent(
        deviceId: deviceId,
        eventId: eventId,
      );
    } catch (e, stackTrace) {
      _logger.error('Error deleting event', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Map database Event to domain Event
  domain.Event _mapToEventDomain(Event event) {
    return domain.Event(
      id: event.id,
      userId: event.userId,
      activityId: event.activityId,
      eventType: _parseActivityType(event.eventType),
      eventSubtype: event.eventSubtype,
      eventName: event.eventName,
      location: event.location,
      registrationUrl: event.registrationUrl,
      eventDate: event.eventDate, // Map the event date for calendar display
      startTime: event.startTime,
      goalTimeMinutes: event.goalTimeMinutes,
      goalPaceMinutesPerMile: event.goalPaceMinutesPerMile,
      predictedFinishTimeMinutes: event.predictedFinishTimeMinutes,
      hasCarbLoading: event.hasCarbLoading,
      carbLoadingDays: event.carbLoadingDays,
      carbLoadingStartDate: event.carbLoadingStartDate,
      hasNutritionPlan: event.hasNutritionPlan, // OBSOLETE: kept for backward compatibility
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

  /// Parse database event_type string to ActivityType enum
  ActivityType _parseActivityType(String eventType) {
    return ActivityType.fromDbValue(eventType);
  }
}
