import 'dart:async';
import 'dart:math';

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

      // Attempt upload immediately to sync with Supabase
      try {
        await _uploadEventToSupabase(deviceId, createdEvent, 'create');
        // Upload succeeded - clear dirty flag on the returned model
        createdEvent = createdEvent.copyWith(
          needsUpload: false,
          localUpdatedAt: DateTime.now(),
        );
      } catch (uploadError) {
        // Upload failed but local save succeeded - event will sync later
        _logger.warning(
          'Supabase upload failed during create, event will sync later',
          context: 'EVENTS_REPOSITORY',
          data: {'eventId': createdEvent.id, 'error': uploadError.toString()},
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
      unawaited(_uploadEventToSupabase(deviceId, eventWithDirtyFlag, 'update'));

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
  /// Also cascade deletes any associated carb loading plan and activity
  Future<void> deleteEvent({
    required String deviceId,
    required String eventId,
  }) async {
    try {
      // Get the event first to check for associated activity
      final event = await getEventById(deviceId, eventId);

      // CASCADE: Delete carb loading plan first (Drift doesn't enforce FK constraints)
      // This must happen BEFORE deleting the event so we can find the plan by eventId
      await _carbLoadingRepository.deleteCarbLoadingPlanByEventId(
        deviceId: deviceId,
        eventId: eventId,
      );

      // CASCADE: Delete associated activity if exists
      if (event != null && event.activityId != null) {
        final activityId = event.activityId!;
        await (_database.delete(_database.activitiesTable)
              ..where((tbl) => tbl.id.equals(activityId)))
            .go();
        _logger.info(
          'CASCADE deleted activity $activityId for event $eventId',
          context: 'EVENTS_REPOSITORY',
        );
      }

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

  /// Get all events for a user (local-first, returns cached data)
  Future<List<domain.Event>> getEvents(String userId) async {
    try {
      final query = _database.select(_database.eventsTable)
        ..where((tbl) => tbl.userId.lower().equals(userId.toLowerCase()))
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

  /// Get a specific event by ID for a user
  /// Note: If duplicate events exist with the same ID, returns the first one
  Future<domain.Event?> getEventById(String userId, String eventId) async {
    try {
      final query = _database.select(_database.eventsTable)
        ..where((tbl) =>
            tbl.id.equals(eventId) &
            tbl.userId.lower().equals(userId.toLowerCase()));

      final events = await query.get();

      if (events.length > 1) {
        _logger.warning(
          'Found duplicate events with same ID',
          context: 'EVENTS_REPOSITORY',
          data: {'eventId': eventId, 'count': events.length},
        );
      }

      return events.isNotEmpty ? _mapToEventDomain(events.first) : null;
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

  /// Find existing event by user_id + event_name + event_date for deduplication
  ///
  /// Used during sync to prevent creating duplicate events when syncing
  /// from external providers like TrainingPeaks.
  /// IMPORTANT: This is user-scoped to allow different users to have events
  /// with the same name on the same date.
  Future<domain.Event?> findExistingEvent({
    required String userId,
    required String eventName,
    required DateTime eventDate,
  }) async {
    try {
      // Normalize the date to just the date part (no time)
      final dateOnly = DateTime(eventDate.year, eventDate.month, eventDate.day);
      final nextDay = dateOnly.add(const Duration(days: 1));

      final query = _database.select(_database.eventsTable)
        ..where((tbl) =>
            tbl.userId.lower().equals(userId.toLowerCase()) &
            tbl.eventName.equals(eventName) &
            tbl.eventDate.isBiggerOrEqualValue(dateOnly) &
            tbl.eventDate.isSmallerThanValue(nextDay));

      final event = await query.getSingleOrNull();
      return event != null ? _mapToEventDomain(event) : null;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to find existing event',
        context: 'EVENTS_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {'userId': userId, 'eventName': eventName, 'eventDate': eventDate.toIso8601String()},
      );
      return null; // Return null on error to allow sync to continue
    }
  }

  /// Save event to Drift database (offline-first pattern)
  Future<String> _saveToDrift(domain.Event event) async {
    if (event.id.isEmpty) {
      // CREATE: New event - let database generate UUID
      final companion = EventsTableCompanion.insert(
        id: const Value.absent(), // Trigger auto-generation
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
        hasNutritionPlan: Value(event.hasNutritionPlan), // OBSOLETE: kept for backward compatibility
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

      final insertedRow = await _database
          .into(_database.eventsTable)
          .insertReturning(companion);

      _logger.debug(
        'Created new event',
        context: 'EVENTS_REPOSITORY',
        data: {'eventId': insertedRow.id},
      );

      return insertedRow.id;
    } else {
      // UPDATE: Existing event - update by ID
      final companion = EventsTableCompanion(
        id: Value(event.id), // Preserve existing ID
        userId: Value(event.userId),
        activityId: Value(event.activityId),
        eventType: Value(event.eventType.dbValue),
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
        hasNutritionPlan: Value(event.hasNutritionPlan), // OBSOLETE: kept for backward compatibility
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
        createdAt: Value(event.createdAt),
        updatedAt: Value(event.updatedAt),
      );

      await (_database.update(_database.eventsTable)
            ..where((tbl) => tbl.id.equals(event.id)))
          .write(companion);

      _logger.debug(
        'Updated existing event',
        context: 'EVENTS_REPOSITORY',
        data: {'eventId': event.id},
      );

      return event.id;
    }
  }

  /// Upload event to Supabase directly
  Future<void> _uploadEventToSupabase(
    String deviceId, // acts as userId
    domain.Event event,
    String operation,
  ) async {
    try {
      // Use userId from event directly
      final userUuid = event.userId;

      // Prepare data with explicit UUID from Drift
      final eventData = _toSupabaseJson(event, userUuid);
      eventData['id'] = event.id; // Use same UUID from Drift

      if (operation == 'create') {
        // Insert with explicit UUID from Drift
        await _supabase
            .from('events')
            .insert(eventData);

        _logger.info(
          'Event uploaded to Supabase with UUID',
          context: 'EVENTS_REPOSITORY',
          data: {'eventId': event.id},
        );

        await _clearDirtyFlag(event.id);
      } else {
        // Update existing record by UUID
        await _supabase
            .from('events')
            .upsert(eventData);

        await _clearDirtyFlag(event.id);
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

  /// Upload event deletion to Supabase directly (non-blocking)
  Future<void> _uploadEventDeletion(
    String deviceId, // acts as userId
    String eventId,
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
      'has_nutrition_plan': event.hasNutritionPlan, // OBSOLETE: kept for backward compatibility
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

}
