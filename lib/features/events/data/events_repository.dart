import 'dart:async';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/services/sentry/sentry_reporter.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/sync/sync_dependency_graph.dart';
import '../../../shared/domain/activity_type.dart';
import '../../../shared/data/syncable_repository.dart';
import '../../carb_loading/data/carb_loading_repository.dart';
import '../../calendar/domain/event_subtype.dart';
import '../domain/event.dart' as domain;

part 'events_repository.g.dart';

@riverpod
EventsRepository eventsRepository(Ref ref) {
  final deps = ref.read(appExternalDepsProvider);
  return EventsRepository(
    supabase: Supabase.instance.client,
    database: ref.read(appDatabaseProvider),
    logger: ref.read(appLoggerProvider),
    carbLoadingRepository: ref.read(carbLoadingRepositoryProvider),
    sentry: deps.sentry,
  );
}

/// Repository for managing events following FOA pattern
/// Prepares for server-authoritative sync with edge functions
class EventsRepository with SyncableRepository {
  const EventsRepository({
    required SupabaseClient supabase,
    required AppDatabase database,
    required AppLogger logger,
    required CarbLoadingRepository carbLoadingRepository,
    required SentryReporter sentry,
  }) : _supabase = supabase,
       _database = database,
       _logger = logger,
       _carbLoadingRepository = carbLoadingRepository,
       _sentry = sentry;

  final SupabaseClient _supabase;
  final AppDatabase _database;
  final AppLogger _logger;
  final CarbLoadingRepository _carbLoadingRepository;
  final SentryReporter _sentry;

  // ========================================================================
  // SyncableRepository Implementation
  // ========================================================================

  @override
  String get repositoryKey => 'events';

  @override
  List<String> get dependencies =>
      SyncDependencyGraph.dependenciesFor(repositoryKey);

  @override
  Future<SyncResult> syncFromRemote(String userId) async {
    try {
      _logger.info(
        'Syncing events from Supabase',
        context: 'EVENTS_REPOSITORY',
        data: {'userId': userId},
      );

      // Direct Supabase query - get all events for this user
      final response = await _supabase
          .from('events')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      // Cast response to List<Map<String, dynamic>>
      final events = response as List<dynamic>;

      final syncedCount = await _upsertRemoteEventsPreservingDirty(events);

      await setLastSyncTime(DateTime.now());

      _logger.info(
        'Successfully synced events from Supabase',
        context: 'EVENTS_REPOSITORY',
        data: {'userId': userId, 'count': syncedCount},
      );

      return SyncResult.successful(syncedCount);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to sync events from Supabase',
        context: 'EVENTS_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {'userId': userId},
      );
      return SyncResult.failed(e.toString());
    }
  }

  Future<int> _upsertRemoteEventsPreservingDirty(
    List<dynamic> remoteEvents,
  ) async {
    final remoteById = <String, Map<String, dynamic>>{};

    for (final item in remoteEvents) {
      if (item is! Map) continue;
      final mapped = Map<String, dynamic>.from(item);
      final id = mapped['id']?.toString();
      if (id == null || id.isEmpty) continue;
      remoteById[id] = mapped;
    }

    if (remoteById.isEmpty) {
      return 0;
    }

    final remoteIds = remoteById.keys.toList(growable: false);
    final dirtyRows =
        await (_database.select(_database.eventsTable)..where(
              (tbl) => tbl.id.isIn(remoteIds) & tbl.needsUpload.equals(true),
            ))
            .get();
    final dirtyIds = dirtyRows.map((row) => row.id).toSet();

    var upsertedCount = 0;
    await _database.batch((batch) {
      for (final entry in remoteById.entries) {
        if (dirtyIds.contains(entry.key)) {
          continue;
        }

        final companion = _mapSupabaseJsonToCompanion(entry.value);
        batch.insert(
          _database.eventsTable,
          companion,
          mode: InsertMode.insertOrReplace,
        );
        upsertedCount++;
      }
    });

    if (dirtyIds.isNotEmpty) {
      _logger.warning(
        'Skipped remote event overwrite for dirty local rows',
        context: 'EVENTS_REPOSITORY',
        data: {
          'skippedCount': dirtyIds.length,
          'totalRemote': remoteById.length,
        },
      );
    }

    return upsertedCount;
  }

  @override
  Future<UploadResult> uploadDirtyRecords(String userId) async {
    try {
      _logger.info(
        'Uploading dirty events to Supabase',
        context: 'EVENTS_REPOSITORY',
        data: {'userId': userId},
      );

      // Query Drift for dirty records
      final dirtyRecords =
          await (_database.select(_database.eventsTable)..where(
                (t) => t.needsUpload.equals(true) & t.userId.equals(userId),
              ))
              .get();

      if (dirtyRecords.isEmpty) {
        return UploadResult.nothingToUpload();
      }

      _logger.debug(
        'Found dirty events to upload',
        context: 'EVENTS_REPOSITORY',
        data: {'count': dirtyRecords.length},
      );

      // Upload to Supabase
      final eventsToUpload = dirtyRecords.map((record) {
        return _toSupabaseJson(_mapToEventDomain(record), record.userId);
      }).toList();

      await _supabase.from('events').upsert(eventsToUpload, onConflict: 'id');

      // Clear dirty flags
      await _database.batch((batch) {
        for (final record in dirtyRecords) {
          batch.update(
            _database.eventsTable,
            const EventsTableCompanion(needsUpload: Value(false)),
            where: (t) => t.id.equals(record.id),
          );
        }
      });

      _logger.info(
        'Successfully uploaded dirty events',
        context: 'EVENTS_REPOSITORY',
        data: {'count': dirtyRecords.length},
      );

      return UploadResult.successful(dirtyRecords.length);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to upload dirty events',
        context: 'EVENTS_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {'userId': userId},
      );
      return UploadResult.failed(e.toString());
    }
  }

  // ========================================================================
  // Existing Methods
  // ========================================================================

  /// Create a new event (offline-first: save to Drift first, then sync immediately if possible)
  Future<domain.Event> createEvent({
    required String deviceId,
    required domain.Event event,
    bool requireRemoteAck = false,
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
      var uploaded = false;
      try {
        await _uploadEventToSupabase(createdEvent, 'create');
        uploaded = true;
      } catch (e, stackTrace) {
        _logger.warning(
          'Immediate upload failed; record stays dirty for retry',
          context: 'EVENTS_REPOSITORY',
          error: e,
          stackTrace: stackTrace,
          data: {'operation': 'create', 'recordId': createdEvent.id},
        );
        _sentry.reportNetworkError(
          e,
          url: 'supabase:events:create',
          method: 'INSERT',
          stackTrace: stackTrace,
        );
        if (requireRemoteAck) {
          rethrow;
        }
      }
      if (uploaded) {
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
    bool requireRemoteAck = false,
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

      if (requireRemoteAck) {
        try {
          await _uploadEventToSupabase(eventWithDirtyFlag, 'update');
        } catch (e, stackTrace) {
          _logger.warning(
            'Immediate upload failed; record stays dirty for retry',
            context: 'EVENTS_REPOSITORY',
            error: e,
            stackTrace: stackTrace,
            data: {'operation': 'update', 'recordId': eventWithDirtyFlag.id},
          );
          _sentry.reportNetworkError(
            e,
            url: 'supabase:events:update',
            method: 'UPSERT',
            stackTrace: stackTrace,
          );
          rethrow;
        }
      } else {
        // Attempt background upload (non-blocking) with logging
        unawaited(() async {
          try {
            await _uploadEventToSupabase(eventWithDirtyFlag, 'update');
          } catch (e, stackTrace) {
            _logger.warning(
              'Immediate upload failed; record stays dirty for retry',
              context: 'EVENTS_REPOSITORY',
              error: e,
              stackTrace: stackTrace,
              data: {'operation': 'update', 'recordId': eventWithDirtyFlag.id},
            );
            _sentry.reportNetworkError(
              e,
              url: 'supabase:events:update',
              method: 'UPSERT',
              stackTrace: stackTrace,
            );
          }
        }());
      }

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
    bool requireRemoteAck = false,
    String? remoteUserId,
  }) async {
    try {
      final userIdForRemoteDelete = remoteUserId ?? deviceId;

      if (requireRemoteAck) {
        await _uploadEventDeletion(userIdForRemoteDelete, eventId);
      }

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
        await (_database.delete(
          _database.activitiesTable,
        )..where((tbl) => tbl.id.equals(activityId))).go();
        _logger.info(
          'CASCADE deleted activity $activityId for event $eventId',
          context: 'EVENTS_REPOSITORY',
        );
      }

      // OFFLINE-FIRST: Hard delete event from Drift IMMEDIATELY
      await (_database.delete(
        _database.eventsTable,
      )..where((tbl) => tbl.id.equals(eventId))).go();

      if (!requireRemoteAck) {
        // Attempt background upload (non-blocking)
        // Note: Supabase CASCADE will also delete the carb_loading_plan on the server
        unawaited(() async {
          try {
            await _uploadEventDeletion(userIdForRemoteDelete, eventId);
          } catch (e, stackTrace) {
            _logger.warning(
              'Immediate upload failed; record stays dirty for retry',
              context: 'EVENTS_REPOSITORY',
              error: e,
              stackTrace: stackTrace,
              data: {'operation': 'delete', 'recordId': eventId},
            );
            _sentry.reportNetworkError(
              e,
              url: 'supabase:events:delete',
              method: 'DELETE',
              stackTrace: stackTrace,
            );
          }
        }());
      }
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
        ..where(
          (tbl) =>
              tbl.id.equals(eventId) &
              tbl.userId.lower().equals(userId.toLowerCase()),
        );

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
        ..where(
          (tbl) =>
              tbl.userId.lower().equals(userId.toLowerCase()) &
              tbl.eventName.equals(eventName) &
              tbl.eventDate.isBiggerOrEqualValue(dateOnly) &
              tbl.eventDate.isSmallerThanValue(nextDay),
        );

      final event = await query.getSingleOrNull();
      return event != null ? _mapToEventDomain(event) : null;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to find existing event',
        context: 'EVENTS_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {
          'userId': userId,
          'eventName': eventName,
          'eventDate': eventDate.toIso8601String(),
        },
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
        hasNutritionPlan: Value(
          event.hasNutritionPlan,
        ), // OBSOLETE: kept for backward compatibility
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
        hasNutritionPlan: Value(
          event.hasNutritionPlan,
        ), // OBSOLETE: kept for backward compatibility
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

      await (_database.update(
        _database.eventsTable,
      )..where((tbl) => tbl.id.equals(event.id))).write(companion);

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
    domain.Event event,
    String operation,
  ) async {
    // Use userId from event directly
    final userUuid = event.userId;

    // Prepare data with explicit UUID from Drift
    final eventData = _toSupabaseJson(event, userUuid);
    eventData['id'] = event.id; // Use same UUID from Drift

    if (operation == 'create') {
      // Insert with explicit UUID from Drift
      await _supabase.from('events').insert(eventData);

      _logger.info(
        'Event uploaded to Supabase with UUID',
        context: 'EVENTS_REPOSITORY',
        data: {'eventId': event.id},
      );

      await _clearDirtyFlag(event.id);
    } else {
      // Update existing record by UUID
      await _supabase.from('events').upsert(eventData);

      await _clearDirtyFlag(event.id);
    }
  }

  /// Upload event deletion to Supabase directly (non-blocking)
  Future<void> _uploadEventDeletion(
    String deviceId, // acts as userId
    String eventId,
  ) async {
    await _supabase
        .from('events')
        .delete()
        .eq('id', eventId)
        .eq('user_id', deviceId); // Scope by user for safety
  }

  /// Helper to map domain Event to Supabase JSON (snake_case columns)
  Map<String, dynamic> _toSupabaseJson(domain.Event event, String userUuid) {
    // Validate event_subtype against DB enum — invalid values (e.g. raw TP
    // event types like "RoadCycling") would cause a PostgreSQL 22P02 error.
    final subtype = event.eventSubtype;
    final validSubtype =
        subtype != null &&
            EventSubtype.findByName(event.eventType.dbValue, subtype) != null
        ? subtype
        : null;

    return {
      // Production events.id has no server default; always send the local UUID.
      'id': event.id,
      'user_id': userUuid,
      'activity_id': event.activityId,
      'event_type': event.eventType.dbValue,
      'event_subtype': validSubtype,
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
      'has_nutrition_plan':
          event.hasNutritionPlan, // OBSOLETE: kept for backward compatibility
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
      hasNutritionPlan:
          event.hasNutritionPlan, // OBSOLETE: kept for backward compatibility
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

  /// Map Supabase JSON (snake_case) to Drift EventsTableCompanion
  EventsTableCompanion _mapSupabaseJsonToCompanion(Map<String, dynamic> json) {
    return EventsTableCompanion.insert(
      id: Value(json['id'] as String),
      userId: json['user_id'] as String,
      activityId: Value(json['activity_id'] as String?),
      eventType: json['event_type'] as String,
      eventSubtype: Value(json['event_subtype'] as String?),
      eventName: Value(json['event_name'] as String?),
      location: Value(json['location'] as String?),
      registrationUrl: Value(json['registration_url'] as String?),
      eventDate: Value(
        json['event_date'] != null
            ? DateTime.parse(json['event_date'] as String)
            : null,
      ),
      startTime: Value(json['start_time'] as String?),
      goalTimeMinutes: Value(json['goal_time_minutes'] as int?),
      goalPaceMinutesPerMile: Value(
        json['goal_pace_minutes_per_mile'] as double?,
      ),
      predictedFinishTimeMinutes: Value(
        json['predicted_finish_time_minutes'] as int?,
      ),
      hasCarbLoading: Value(json['has_carb_loading'] as bool? ?? false),
      carbLoadingDays: Value(json['carb_loading_days'] as int?),
      carbLoadingStartDate: Value(
        json['carb_loading_start_date'] != null
            ? DateTime.parse(json['carb_loading_start_date'] as String)
            : null,
      ),
      hasNutritionPlan: Value(json['has_nutrition_plan'] as bool? ?? false),
      bibNumber: Value(json['bib_number'] as String?),
      waveStartTime: Value(json['wave_start_time'] as String?),
      packetPickupInfo: Value(json['packet_pickup_info'] as String?),
      actualFinishTimeMinutes: Value(
        json['actual_finish_time_minutes'] as int?,
      ),
      finalPlacement: Value(json['final_placement'] as int?),
      ageGroupPlacement: Value(json['age_group_placement'] as int?),
      needsUpload: const Value(false), // Coming from server, so not dirty
      localUpdatedAt: Value(DateTime.now()),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
