import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/event.dart' as domain;
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/domain/activity_type.dart';
import '../../../shared/domain/write_consistency.dart';
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

  /// The calendar `eventDate` is ALWAYS the date portion of `startTime`, so the
  /// two can never drift. Both [createEvent] and [updateEvent] derive it here —
  /// previously only create derived it and update passed the stale
  /// `event.eventDate` straight through, so editing an event's date saved
  /// `startTime` but not `eventDate`, and the calendar kept the old date
  /// (Claudia, 2026-09-10: "shows correct… but it's not saving").
  static DateTime? eventDateFromStartTime(String? startTime) {
    if (startTime == null || startTime.isEmpty) return null;
    try {
      final parsed = DateTime.parse(startTime);
      return DateTime(parsed.year, parsed.month, parsed.day);
    } catch (_) {
      return null;
    }
  }

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
        ..where(
          (tbl) =>
              tbl.id.equals(eventId) &
              tbl.userId.lower().equals(userId.toLowerCase()),
        );

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
  Future<List<domain.Event>> getEventsForWeek(
    String userId,
    DateTime weekStart,
  ) async {
    try {
      final weekEnd = weekStart.add(
        const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
      );

      // Get all events
      final allEvents = await getAllEvents(userId);

      // Filter events that have activities in this week
      final eventsInWeek = <domain.Event>[];
      for (final event in allEvents) {
        if (event.activityId != null) {
          final activity = await _activitiesService.getActivityById(
            userId,
            event.activityId!,
          );
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
    String?
    forUserId, // NEW: If provided, create event for this user (coach creating for athlete)
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
    WriteConsistency? consistency,
  }) async {
    try {
      // Determine the owner of the event
      final ownerId = forUserId ?? deviceId;
      final resolvedConsistency =
          consistency ??
          WriteConsistencyResolver.forActorAndOwner(
            actorUserId: deviceId,
            ownerUserId: ownerId,
          );

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
            data: {'coachUserId': deviceId, 'athleteUserId': forUserId},
          );
          throw Exception('Not authorized to create events for this athlete');
        }
      }

      final now = DateTime.now();

      // Parse eventDate from startTime (single derivation, shared with update).
      final eventDate = eventDateFromStartTime(startTime);

      final event = domain.Event(
        id: '', // Empty string - repository will assign actual ID
        userId: ownerId, // Use ownerId (athlete if coach is creating for them)
        origin: 'manual', // D-2c: athlete-created rows are manual-origin
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

      _logger.info(
        'Resolved write consistency',
        context: 'EVENTS_SERVICE',
        data: {
          'entity': 'event',
          'operation': 'create',
          'actorUserId': deviceId,
          'ownerUserId': ownerId,
          'consistencyMode': resolvedConsistency.value,
        },
      );

      return await _eventsRepository.createEvent(
        deviceId: deviceId,
        event: event,
        requireRemoteAck:
            resolvedConsistency == WriteConsistency.remoteAckRequired,
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
    String?
    currentUserId, // NEW: Current user ID (for validation if coach is editing athlete's event)
    WriteConsistency? consistency,
  }) async {
    try {
      final actorUserId = currentUserId ?? event.userId;
      final resolvedConsistency =
          consistency ??
          WriteConsistencyResolver.forActorAndOwner(
            actorUserId: actorUserId,
            ownerUserId: event.userId,
          );

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
            data: {'coachUserId': currentUserId, 'athleteUserId': event.userId},
          );
          throw Exception('Not authorized to update events for this athlete');
        }
      }

      // D-2c (RATIFIED 2026-09-11): a local edit of a provider-origin event
      // flips it 'manual' — the athlete now owns the row, and it becomes
      // exempt from re-sync overwrite (the import's dedupe-flip skips
      // 'manual' rows). Manual/legacy rows keep their origin.
      final flippedOrigin =
          (event.origin == 'training_peaks' || event.origin == 'final_surge')
          ? 'manual'
          : event.origin;
      final updatedEvent = event.copyWith(
        updatedAt: DateTime.now(),
        origin: flippedOrigin,
        // Re-derive the calendar date from the (possibly edited) startTime so
        // an edited date actually persists — copyWith otherwise keeps the
        // stale eventDate. Falls back to the stored date only when there is no
        // startTime to derive from (e.g. an imported event without a time).
        eventDate: eventDateFromStartTime(event.startTime) ?? event.eventDate,
      );

      _logger.info(
        'Resolved write consistency',
        context: 'EVENTS_SERVICE',
        data: {
          'entity': 'event',
          'operation': 'update',
          'actorUserId': actorUserId,
          'ownerUserId': event.userId,
          'consistencyMode': resolvedConsistency.value,
          'eventId': event.id,
        },
      );

      await _eventsRepository.updateEvent(
        deviceId: deviceId,
        event: updatedEvent,
        requireRemoteAck:
            resolvedConsistency == WriteConsistency.remoteAckRequired,
      );

      await _moveLinkedActivityToEventDate(
        deviceId: deviceId,
        event: updatedEvent,
        currentUserId: currentUserId,
        consistency: resolvedConsistency,
      );
    } catch (e, stackTrace) {
      _logger.error('Error updating event', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Moves an event's linked activity to the event's (possibly edited) date.
  ///
  /// The events list renders `activity.scheduledDateTime` in preference to the
  /// event's own date (`events_list_screen.dart`), and the linked activity is
  /// the FUELING unit — so an event that moves without its activity shows the
  /// old date on screen AND leaves race-day fuel a day behind the race
  /// (bug 2026-09-16-event-date-edit-leaves-linked-activity-behind; the
  /// second half of Claudia's 2026-09-10 report, whose first half is e8ccda76).
  ///
  /// Deliberately narrow — two rows are left alone:
  /// - **provider-synced** (`syncedFromProvider != null`): a local move could be
  ///   reverted or duplicated by the next sync. D-2c (RATIFIED 2026-09-11) gives
  ///   the local-edit-wins rule for provider-origin EVENTS; the activity-side
  ///   analogue is NOT ruled, so we log and skip rather than decide it here.
  /// - **already happened** (`actualTime != null`): rescheduling a session that
  ///   was actually performed would falsify a measurement.
  ///
  /// `plannedTime` moves with `scheduledDateTime` when it is set, because
  /// `Activity.displayTime` prefers it — moving only the scheduled time would
  /// leave every display surface on the old day.
  Future<void> _moveLinkedActivityToEventDate({
    required String deviceId,
    required domain.Event event,
    String? currentUserId,
    required WriteConsistency consistency,
  }) async {
    final activityId = event.activityId;
    final newStart = event.startTime == null
        ? null
        : DateTime.tryParse(event.startTime!);
    if (activityId == null || newStart == null) return;

    try {
      final activity = await _activitiesService.getActivityById(
        event.userId,
        activityId,
      );
      if (activity == null) return;

      if (activity.syncedFromProvider != null) {
        _logger.info(
          'Linked activity left in place: provider-synced (unruled)',
          context: 'EVENTS_SERVICE',
          data: {
            'eventId': event.id,
            'activityId': activityId,
            'provider': activity.syncedFromProvider,
          },
        );
        return;
      }
      if (activity.actualTime != null) {
        _logger.info(
          'Linked activity left in place: already performed',
          context: 'EVENTS_SERVICE',
          data: {'eventId': event.id, 'activityId': activityId},
        );
        return;
      }
      if (activity.scheduledDateTime == newStart &&
          (activity.plannedTime == null || activity.plannedTime == newStart)) {
        return; // nothing moved
      }

      await _activitiesService.updateActivity(
        deviceId: deviceId,
        activity: activity.copyWith(
          scheduledDateTime: newStart,
          plannedTime: activity.plannedTime == null ? null : newStart,
        ),
        currentUserId: currentUserId,
        consistency: consistency,
      );
    } catch (e, stackTrace) {
      // The event's own move already succeeded and is the athlete's edit;
      // failing the whole save because its activity could not follow would
      // lose that edit. Log loudly instead — the split is visible in the list.
      _logger.error(
        'Event moved but linked activity did not follow',
        error: e,
        stackTrace: stackTrace,
        context: 'EVENTS_SERVICE',
        data: {'eventId': event.id, 'activityId': activityId},
      );
    }
  }

  /// Delete an event
  /// If [currentUserId] is provided, validates coach-athlete relationship for cross-user deletion
  Future<void> deleteEvent({
    required String deviceId,
    required String eventId,
    String?
    currentUserId, // NEW: Current user ID (for validation if coach is deleting athlete's event)
    String? eventOwnerId, // NEW: Event owner ID (for validation)
    WriteConsistency? consistency,
  }) async {
    try {
      final actorUserId = currentUserId ?? deviceId;
      final ownerUserId = eventOwnerId ?? actorUserId;
      final resolvedConsistency =
          consistency ??
          WriteConsistencyResolver.forActorAndOwner(
            actorUserId: actorUserId,
            ownerUserId: ownerUserId,
          );

      // Validate coach-athlete relationship if deleting for someone else
      if (currentUserId != null &&
          eventOwnerId != null &&
          currentUserId != eventOwnerId) {
        final hasActiveRelationship = await _coachRepository
            .isActiveCoachAthleteRelationship(
              coachUserId: currentUserId,
              athleteUserId: eventOwnerId,
            );

        if (!hasActiveRelationship) {
          _logger.error(
            'Coach does not have active relationship with athlete',
            context: 'EVENTS_SERVICE',
            data: {'coachUserId': currentUserId, 'athleteUserId': eventOwnerId},
          );
          throw Exception('Not authorized to delete events for this athlete');
        }
      }

      _logger.info(
        'Resolved write consistency',
        context: 'EVENTS_SERVICE',
        data: {
          'entity': 'event',
          'operation': 'delete',
          'actorUserId': actorUserId,
          'ownerUserId': ownerUserId,
          'consistencyMode': resolvedConsistency.value,
          'eventId': eventId,
        },
      );

      await _eventsRepository.deleteEvent(
        deviceId: deviceId,
        eventId: eventId,
        requireRemoteAck:
            resolvedConsistency == WriteConsistency.remoteAckRequired,
        remoteUserId: ownerUserId,
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
      hasNutritionPlan:
          event.hasNutritionPlan, // OBSOLETE: kept for backward compatibility
      bibNumber: event.bibNumber,
      waveStartTime: event.waveStartTime,
      packetPickupInfo: event.packetPickupInfo,
      actualFinishTimeMinutes: event.actualFinishTimeMinutes,
      finalPlacement: event.finalPlacement,
      ageGroupPlacement: event.ageGroupPlacement,
      // D-2c: origin must survive every mapper — the list card's chip
      // reads it (a dropped origin renders every row as legacy).
      origin: event.origin,
      createdAt: event.createdAt,
      updatedAt: event.updatedAt,
    );
  }

  /// Parse database event_type string to ActivityType enum
  ActivityType _parseActivityType(String eventType) {
    return ActivityType.fromDbValue(eventType);
  }
}
