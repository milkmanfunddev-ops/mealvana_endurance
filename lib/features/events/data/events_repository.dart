import 'dart:async';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/domain/activity_type.dart';
import '../../carb_loading/data/carb_loading_repository.dart';
import '../domain/event.dart' as domain;

part 'events_repository.g.dart';

@riverpod
EventsRepository eventsRepository(Ref ref) {
  return EventsRepository(
    supabase: Supabase.instance.client,
    database: ref.read(appDatabaseProvider),
    logger: ref.read(appLoggerProvider),
    carbLoadingRepository: ref.read(carbLoadingRepositoryProvider),
  );
}

/// Repository for managing events following FOA pattern
/// Prepares for server-authoritative sync with edge functions
class EventsRepository {
  const EventsRepository({
    required SupabaseClient supabase,
    required AppDatabase database,
    required AppLogger logger,
    required CarbLoadingRepository carbLoadingRepository,
  })  : _supabase = supabase,
        _database = database,
        _logger = logger,
        _carbLoadingRepository = carbLoadingRepository;

  final SupabaseClient _supabase;
  final AppDatabase _database;
  final AppLogger _logger;
  final CarbLoadingRepository _carbLoadingRepository;

  /// Create a new event (offline-first: save to Drift first, then sync immediately if possible)
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

      // Save to Drift and get the generated ID
      final generatedId = await _saveToDrift(eventWithDirtyFlag);

      // Update event with the generated ID
      var createdEvent = eventWithDirtyFlag.copyWith(id: generatedId);

      // Attempt upload immediately so the UI gets the final server ID (auth assigns new IDs)
      final serverId = await _uploadEventToSupabase(deviceId, createdEvent, 'create');

      // If Supabase assigned a new ID, return the re-keyed event
      if (serverId != null && serverId != createdEvent.id) {
        createdEvent = createdEvent.copyWith(
          id: serverId,
          needsUpload: false,
          localUpdatedAt: DateTime.now(),
        );
      } else if (serverId != null) {
        // Upload succeeded without re-key - clear dirty flag on the returned model
        createdEvent = createdEvent.copyWith(
          needsUpload: false,
          localUpdatedAt: DateTime.now(),
        );
      }

      return createdEvent;
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

      // Save to Drift (will use existing ID for updates)
      await _saveToDrift(eventWithDirtyFlag);

      // Attempt background upload (non-blocking)
      unawaited(_uploadEventToSupabase(deviceId, eventWithDirtyFlag, 'update').then((_) {}));

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
  /// Also cascade deletes any associated carb loading plan
  Future<void> deleteEvent({
    required String deviceId,
    required int eventId,
  }) async {
    try {
      // CASCADE: Delete carb loading plan first (Drift doesn't enforce FK constraints)
      // This must happen BEFORE deleting the event so we can find the plan by eventId
      await _carbLoadingRepository.deleteCarbLoadingPlanByEventId(
        deviceId: deviceId,
        eventId: eventId,
      );

      // OFFLINE-FIRST: Hard delete event from Drift IMMEDIATELY
      await (_database.delete(_database.eventsTable)
            ..where((tbl) => tbl.id.equals(eventId)))
          .go();

      // Attempt background upload (non-blocking)
      // Note: Supabase CASCADE will also delete the carb_loading_plan on the server
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
  Future<domain.Event?> getEventById(int eventId) async {
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
  Future<domain.Event?> getEventForActivity(int activityId) async {
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
    required int activityId,
    required bool hasNutritionPlan,
  }) async{
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
  Future<int> _saveToDrift(domain.Event event) async {
    final companion = EventsTableCompanion.insert(
      // Use Value.absent() for new events (id = 0) to let auto-increment work
      // Use Value(event.id) for existing events (id > 0) to preserve the ID
      id: event.id == 0 ? const Value.absent() : Value(event.id),
      userId: event.userId,
      activityId: Value(event.activityId),
      eventType: event.eventType.dbValue,
      eventSubtype: Value(event.eventSubtype),
      eventName: Value(event.eventName),
      location: Value(event.location),
      registrationUrl: Value(event.registrationUrl),
      eventDate: Value(event.eventDate),
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

    // Insert and return the generated ID
    return await _database
        .into(_database.eventsTable)
        .insert(companion, mode: InsertMode.insertOrReplace);
  }

  /// Upload event to Supabase directly (returns server ID if it changed)
  Future<int?> _uploadEventToSupabase(
    String deviceId, // acts as userId
    domain.Event event,
    String operation,
  ) async {
    try {
      // DIRECT FIX: Use userId from event directly (unified with deviceId)
      // Skip unnecessary and fragile user lookup
      final userUuid = event.userId;

      // 2. Prepare data
      final eventData = _toSupabaseJson(event, userUuid);

      if (operation == 'create') {
        // Create: Insert and return ID
        // Ensure we don't send the local ID (0 or temporary)
        final response = await _supabase
            .from('events')
            .insert(eventData)
            .select('id')
            .single();
        
        final serverId = response['id'];
        if (serverId is int && serverId != event.id) {
          await _updateLocalId(event.id, serverId);
          // Clear dirty flag for the NEW ID
          await _clearDirtyFlag(serverId);
          return serverId;
        } else if (serverId is int) {
          await _clearDirtyFlag(event.id);
          return serverId;
        }

      } else {
        // Update: Update by ID
        // We assume event.id is already the server ID if it was synced
        // If it's still a local ID that hasn't synced, this might fail/update wrong row if collision
        // Ideally we rely on create succeeding first. 
        // If this is a retry, upsert might be safer but 'id' is serial.
        
        // If we have a valid server ID (sync previously succeeded)
        await _supabase
            .from('events')
            .update(eventData)
            .eq('id', event.id);
            
        await _clearDirtyFlag(event.id);
        return event.id;
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
    return null;
  }

  /// Upload event deletion to Supabase directly (non-blocking)
  Future<void> _uploadEventDeletion(
    String deviceId, // acts as userId
    int eventId,
  ) async {
    try {
      await _supabase
          .from('events')
          .delete()
          .eq('id', eventId)
          .eq('user_id', deviceId); // Scope by user for safety

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

  /// Helper to map domain Event to Supabase JSON (snake_case columns)
  Map<String, dynamic> _toSupabaseJson(domain.Event event, String userUuid) {
    return {
      'user_id': userUuid,
      'activity_id': event.activityId,
      'event_type': event.eventType.dbValue,
      'event_subtype': event.eventSubtype,
      'event_name': event.eventName,
      'location': event.location,
      'registration_url': event.registrationUrl,
      'event_date': event.eventDate?.toIso8601String(),
      'start_time': event.startTime,
      'goal_time_minutes': event.goalTimeMinutes,
      'goal_pace_minutes_per_mile': event.goalPaceMinutesPerMile,
      'predicted_finish_time_minutes': event.predictedFinishTimeMinutes,
      'has_carb_loading': event.hasCarbLoading,
      'carb_loading_days': event.carbLoadingDays,
      'carb_loading_start_date': event.carbLoadingStartDate?.toIso8601String(),
      'has_nutrition_plan': event.hasNutritionPlan,
      'bib_number': event.bibNumber,
      'wave_start_time': event.waveStartTime,
      'packet_pickup_info': event.packetPickupInfo,
      'actual_finish_time_minutes': event.actualFinishTimeMinutes,
      'final_placement': event.finalPlacement,
      'age_group_placement': event.ageGroupPlacement,
      'created_at': event.createdAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      // 'needs_upload': false, // Local-only field, do not send to Supabase
      // 'local_updated_at': DateTime.now().toIso8601String(), // Local-only field
    };
  }

  /// Clear dirty flag after successful upload
  Future<void> _clearDirtyFlag(int eventId) async {
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
      eventType: _parseActivityType(event.eventType),
      eventSubtype: event.eventSubtype,
      eventName: event.eventName,
      location: event.location,
      registrationUrl: event.registrationUrl,
      eventDate: event.eventDate,
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

  /// Parse database event_type string to ActivityType enum
  ActivityType _parseActivityType(String eventType) {
    switch (eventType.toLowerCase()) {
      case 'running':
        return ActivityType.running;
      case 'cycling':
        return ActivityType.cycling;
      case 'swimming':
        return ActivityType.swimming;
      case 'triathlon':
      case 'duathlon':
      case 'multisport':
        // For multi-sport events, default to running for now
        // TODO: Consider adding multi-sport types to ActivityType enum
        return ActivityType.running;
      default:
        return ActivityType.running;
    }
  }

  /// Update local event ID to match server ID
  Future<void> _updateLocalId(int localId, int serverId) async {
    await _database.transaction(() async {
      // Update carb_loading_plans referencing this event
      await _database.customStatement(
        'UPDATE carb_loading_plans SET event_id = ? WHERE event_id = ?',
        [serverId, localId],
      );

      // Update the event ID itself
      await _database.customStatement(
        'UPDATE events SET id = ? WHERE id = ?',
        [serverId, localId],
      );
    });
  }
}
