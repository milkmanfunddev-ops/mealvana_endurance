import 'dart:async';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/logging_service.dart';
import '../domain/event.dart' as domain;

part 'events_repository.g.dart';

@riverpod
EventsRepository eventsRepository(Ref ref) {
  return EventsRepository(
    supabase: Supabase.instance.client,
    database: ref.read(appDatabaseProvider),
    logger: ref.read(appLoggerProvider),
  );
}

/// Repository for managing events following FOA pattern
/// Prepares for server-authoritative sync with edge functions
class EventsRepository {
  const EventsRepository({
    required SupabaseClient supabase,
    required AppDatabase database,
    required AppLogger logger,
  })  : _supabase = supabase,
        _database = database,
        _logger = logger;

  final SupabaseClient _supabase;
  final AppDatabase _database;
  final AppLogger _logger;

  /// Create a new event (offline-first: save to Drift first, background upload)
  Future<domain.Event> createEvent({
    required String deviceId,
    required domain.Event event,
  }) async {
    try {
      // OFFLINE-FIRST: Save to Drift IMMEDIATELY with dirty flag
      final eventWithDirtyFlag = event.copyWith(
        needsUpload: true,
        localUpdatedAt: DateTime.now(),
      );

      await _saveToDrift(eventWithDirtyFlag);


      // Attempt background upload (non-blocking)
      unawaited(_uploadEventToSupabase(deviceId, event, 'create'));

      return eventWithDirtyFlag;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to create event',
        context: 'EVENTS_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Update an existing event (offline-first: save to Drift first, background upload)
  Future<domain.Event> updateEvent({
    required String deviceId,
    required domain.Event event,
  }) async {
    try {
      // OFFLINE-FIRST: Save to Drift IMMEDIATELY with dirty flag
      final eventWithDirtyFlag = event.copyWith(
        needsUpload: true,
        localUpdatedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _saveToDrift(eventWithDirtyFlag);


      // Attempt background upload (non-blocking)
      unawaited(_uploadEventToSupabase(deviceId, event, 'update'));

      return eventWithDirtyFlag;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to update event',
        context: 'EVENTS_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Delete an event (offline-first: hard delete from Drift first, background upload)
  Future<void> deleteEvent({
    required String deviceId,
    required String eventId,
  }) async {
    try {
      // OFFLINE-FIRST: Hard delete from Drift IMMEDIATELY
      await (_database.delete(_database.eventsTable)
            ..where((tbl) => tbl.id.equals(eventId)))
          .go();


      // Attempt background upload (non-blocking)
      unawaited(_uploadEventDeletion(deviceId, eventId));
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to delete event',
        context: 'EVENTS_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get all events (local-first, returns cached data)
  Future<List<domain.Event>> getEvents() async {
    try {
      final query = _database.select(_database.eventsTable)
        ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]);

      final events = await query.get();
      return events.map(_mapToEventDomain).toList();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get events',
        context: 'EVENTS_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get a specific event by ID
  Future<domain.Event?> getEventById(String eventId) async {
    try {
      final query = _database.select(_database.eventsTable)
        ..where((tbl) => tbl.id.equals(eventId));

      final event = await query.getSingleOrNull();
      return event != null ? _mapToEventDomain(event) : null;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get event by ID',
        context: 'EVENTS_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
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
        'Failed to get event for activity',
        context: 'EVENTS_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Update event's nutrition plan flag
  Future<void> updateEventNutritionPlanFlag({
    required String activityId,
    required bool hasNutritionPlan,
  }) async {
    try {
      // Get the event for this activity
      final event = await getEventForActivity(activityId);

      if (event == null) {
        return;
      }

      // Update the event with the new nutrition plan flag
      final companion = EventsTableCompanion(
        hasNutritionPlan: Value(hasNutritionPlan),
        updatedAt: Value(DateTime.now()),
      );

      await (_database.update(_database.eventsTable)
            ..where((tbl) => tbl.id.equals(event.id)))
          .write(companion);

    } catch (e, stackTrace) {
      _logger.error(
        'Failed to update event nutrition plan flag',
        context: 'EVENTS_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Save event to Drift database (offline-first pattern)
  Future<void> _saveToDrift(domain.Event event) async {
    final companion = EventsTableCompanion.insert(
      id: event.id,
      userId: event.userId,
      activityId: Value(event.activityId),
      eventType: event.eventType.dbValue,
      eventSubtype: Value(event.eventSubtype),
      eventName: Value(event.eventName),
      location: Value(event.location),
      registrationUrl: Value(event.registrationUrl),
      startTime: Value(event.startTime),
      goalTimeMinutes: Value(event.goalTimeMinutes),
      goalPaceMinutesPerMile: Value(event.goalPaceMinutesPerMile),
      predictedFinishTimeMinutes: Value(event.predictedFinishTimeMinutes),
      hasCarbLoading: Value(event.hasCarbLoading),
      carbLoadingDays: Value(event.carbLoadingDays),
      carbLoadingStartDate: Value(event.carbLoadingStartDate),
      hasNutritionPlan: Value(event.hasNutritionPlan),
      bibNumber: Value(event.bibNumber),
      waveStartTime: Value(event.waveStartTime),
      packetPickupInfo: Value(event.packetPickupInfo),
      actualFinishTimeMinutes: Value(event.actualFinishTimeMinutes),
      finalPlacement: Value(event.finalPlacement),
      ageGroupPlacement: Value(event.ageGroupPlacement),
      // Sync tracking
      needsUpload: Value(event.needsUpload ?? false),
      localUpdatedAt: Value(event.localUpdatedAt ?? DateTime.now()),
      // Metadata
      createdAt: event.createdAt,
      updatedAt: event.updatedAt,
    );

    await _database
        .into(_database.eventsTable)
        .insert(companion, mode: InsertMode.insertOrReplace);
  }

  /// Upload event to Supabase in background (non-blocking)
  Future<void> _uploadEventToSupabase(
    String deviceId,
    domain.Event event,
    String operation,
  ) async {
    try {
      final response = await _supabase.functions.invoke(
        'save-calendar-event',
        body: {
          'device_id': deviceId,
          'event': event.toJson(),
          'operation': operation,
        },
      );

      if (response.status >= 200 && response.status < 300) {
        // Upload successful - clear dirty flag
        await _clearDirtyFlag(event.id);

      } else {
        throw Exception('Edge function failed: ${response.data}');
      }
    } catch (e) {
      _logger.warning(
        'Failed to upload event (will retry on next sync)',
        context: 'EVENTS_REPOSITORY',
        error: e,
        data: {'eventId': event.id},
      );
      // Don't rethrow - keep dirty flag, will retry on next sync
    }
  }

  /// Upload event deletion to Supabase in background (non-blocking)
  Future<void> _uploadEventDeletion(
    String deviceId,
    String eventId,
  ) async {
    try {
      final response = await _supabase.functions.invoke(
        'save-calendar-event',
        body: {
          'device_id': deviceId,
          'event_id': eventId,
          'operation': 'delete',
        },
      );

      if (response.status >= 200 && response.status < 300) {
      } else {
        throw Exception('Edge function failed: ${response.data}');
      }
    } catch (e) {
      _logger.warning(
        'Failed to upload event deletion (will retry on next sync)',
        context: 'EVENTS_REPOSITORY',
        error: e,
        data: {'eventId': eventId},
      );
      // Don't rethrow - will retry on next sync
    }
  }

  /// Clear dirty flag after successful upload
  Future<void> _clearDirtyFlag(String eventId) async {
    await (_database.update(_database.eventsTable)
          ..where((tbl) => tbl.id.equals(eventId)))
        .write(const EventsTableCompanion(needsUpload: Value(false)));
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
