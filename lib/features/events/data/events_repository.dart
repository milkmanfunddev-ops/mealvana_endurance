import 'dart:async';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/report/report.dart';
import '../../../shared/services/sync/sync_dependency_graph.dart';
import '../../../shared/domain/activity_type.dart';
import '../../../shared/data/syncable_repository.dart';
import '../../carb_loading/data/carb_loading_repository.dart';
import '../../calendar/domain/event_subtype.dart';
import '../domain/event.dart' as domain;

part 'events_repository.g.dart';

@riverpod
EventsRepository eventsRepository(Ref ref) {
  return EventsRepository(
    supabase: Supabase.instance.client,
    database: ref.read(appDatabaseProvider),
    carbLoadingRepository: ref.read(carbLoadingRepositoryProvider),
    report: ref.read(reportProvider),
  );
}

/// Repository for managing events following FOA pattern
/// Prepares for server-authoritative sync with edge functions
class EventsRepository with SyncableRepository {
  const EventsRepository({
    required SupabaseClient supabase,
    required AppDatabase database,
    required CarbLoadingRepository carbLoadingRepository,
    required Report report,
  }) : _supabase = supabase,
       _database = database,
       _carbLoadingRepository = carbLoadingRepository,
       _report = report;

  final SupabaseClient _supabase;
  final AppDatabase _database;
  final CarbLoadingRepository _carbLoadingRepository;
  final Report _report;

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
      _report.info(
        'Syncing events from Supabase',
        area: 'events',
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

      _report.info(
        'Successfully synced events from Supabase',
        area: 'events',
        data: {'userId': userId, 'count': syncedCount},
      );

      return SyncResult.successful(syncedCount);
    } catch (e, stackTrace) {
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'events',
        extra: {'userId': userId},
        message: 'Failed to sync events from Supabase',
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
    var rederivedCount = 0;
    await _database.batch((batch) {
      for (final entry in remoteById.entries) {
        if (dirtyIds.contains(entry.key)) {
          continue;
        }

        if (_serverEventDateDisagrees(entry.value)) rederivedCount++;
        final companion = _mapSupabaseJsonToCompanion(entry.value);
        batch.insert(
          _database.eventsTable,
          companion,
          mode: InsertMode.insertOrReplace,
        );
        upsertedCount++;
      }
    });

    // D9: the download quietly corrects a stale server event_date (ticket 65);
    // say so once per batch. The row is not marked dirty: the server is healed
    // by SQL, and a coach device must never upload an athlete's row.
    if (rederivedCount > 0) {
      await _report.note(
        'Events download: event_date re-derived from start_time',
        area: 'events',
        data: {'count': rederivedCount},
      );
    }

    if (dirtyIds.isNotEmpty) {
      _report.degraded(
        LoggedFault(
          'Skipped remote event overwrite for dirty local rows',
          context: 'EVENTS_REPOSITORY',
        ),
        area: 'events',
        extra: {
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
      _report.info(
        'Uploading dirty events to Supabase',
        area: 'events',
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

      _report.debug(
        'Found dirty events to upload',
        area: 'events',
        data: {'count': dirtyRecords.length},
      );

      // One upsert per row (ticket 72): the server's unique index
      // `events_user_date_name_unique` refuses a same-name same-day row with
      // 23505, and in one batched request that row blocked every later event.
      final outcome = await _uploadDirtyRowsOneByOne(dirtyRecords);

      if (outcome.failedCount == 0) {
        _report.info(
          'Successfully uploaded dirty events',
          area: 'events',
          data: {'count': outcome.landedCount},
        );
        return UploadResult.successful(outcome.landedCount);
      }

      // Some rows stayed dirty. Not a success, so the coordinator keeps the
      // retry owed; the rows that landed are clean already.
      return UploadResult(
        success: false,
        count: outcome.landedCount,
        error:
            '${outcome.failedCount} of ${dirtyRecords.length} events failed '
            'to upload (${outcome.failureCodes.join(', ')})',
      );
    } catch (e, stackTrace) {
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'events',
        extra: {'userId': userId},
        message: 'Failed to upload dirty events',
      );
      return UploadResult.failed(e.toString());
    }
  }

  /// Upserts each dirty row on its own and clears its dirty flag when it
  /// lands. A row the server refuses (a PostgrestException: 23505 duplicate,
  /// 23503 FK, 22P02 enum, RLS) stays dirty, is written down with its id and
  /// code (D9), and the walk goes on to the next row. Any other error
  /// (network, timeout) is not about the row, so the walk stops there and the
  /// caller's catch reports it; the unsent rows stay dirty.
  ///
  /// Repeating it is safe: every write is `upsert(onConflict: 'id')`, so a
  /// resend of a row that already landed rewrites the same row.
  Future<({int landedCount, int failedCount, List<String> failureCodes})>
  _uploadDirtyRowsOneByOne(List<Event> dirtyRecords) async {
    var landedCount = 0;
    final failureCodes = <String>[];

    for (final record in dirtyRecords) {
      final json = _toSupabaseJson(_mapToEventDomain(record), record.userId);
      try {
        await _supabase.from('events').upsert(json, onConflict: 'id');
      } on PostgrestException catch (e, stackTrace) {
        final code = e.code ?? 'unknown';
        failureCodes.add(code);
        if (_isMissingUserRowFk(e)) {
          // Expected before onboarding creates the users row (see
          // createEvent); the row uploads on a later walk.
          _report.info(
            'Deferred event upload: users row not created yet; '
            'record stays dirty for retry',
            area: 'events',
            data: {'operation': 'upload_dirty', 'eventId': record.id},
          );
        } else {
          _report.degraded(
            e,
            stackTrace: stackTrace,
            area: 'events',
            tags: {'method': 'UPSERT', 'code': code},
            extra: {'eventId': record.id, 'code': code},
            message:
                'Dirty event refused by the server; it stays dirty and '
                'retries on the next upload walk',
          );
        }
        continue;
      }
      await _clearDirtyFlagIfUnchanged(record);
      landedCount++;
    }

    return (
      landedCount: landedCount,
      failedCount: failureCodes.length,
      failureCodes: failureCodes,
    );
  }

  /// Clears the dirty flag only when the row was not edited again while its
  /// upload was in flight: an edit bumps `localUpdatedAt`, and that newer
  /// version must stay dirty for the next walk.
  Future<void> _clearDirtyFlagIfUnchanged(Event uploaded) async {
    final sentVersion = uploaded.localUpdatedAt;
    await (_database.update(_database.eventsTable)..where(
          (t) =>
              t.id.equals(uploaded.id) &
              (sentVersion == null
                  ? t.localUpdatedAt.isNull()
                  : t.localUpdatedAt.equals(sentVersion)),
        ))
        .write(const EventsTableCompanion(needsUpload: Value(false)));
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
      // eventDate is derived from startTime on every write (ticket 65), so
      // no writer (service, provider import, activity link) can store a date
      // the start time disagrees with.
      // OFFLINE-FIRST: Save to Drift IMMEDIATELY with dirty flag
      final eventWithDirtyFlag = event.withDerivedEventDate().copyWith(
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
        if (_isMissingUserRowFk(e)) {
          // Expected during onboarding: the (anonymous or just-created) auth
          // user has no public.users row yet — it's created later by the
          // create-user path — so events.user_id FK-violates (23503). The
          // record already stays dirty and uploads via ensureSynced once the
          // users row lands. Queue-and-retry, not an error worth Sentry
          // (was MEALVANA-ENDURANCE-3W: 350+ noise events).
          _report.info(
            'Deferred event upload: users row not created yet; '
            'record stays dirty for retry',
            area: 'events',
            data: {'operation': 'create', 'recordId': createdEvent.id},
          );
        } else {
          _report.degraded(
            e,
            stackTrace: stackTrace,
            area: 'events',
            tags: {'method': 'INSERT'},
            extra: {
              'operation': 'create',
              'recordId': createdEvent.id,
              'url': 'supabase:events:create',
            },
            message: 'Immediate upload failed; record stays dirty for retry',
          );
        }
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
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'events',
        message: 'Failed to create event',
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
      // eventDate is derived from startTime on every write (ticket 65).
      // OFFLINE-FIRST: Save to Drift IMMEDIATELY with dirty flag
      final eventWithDirtyFlag = event.withDerivedEventDate().copyWith(
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
          _report.degraded(
            e,
            stackTrace: stackTrace,
            area: 'events',
            tags: {'method': 'UPSERT'},
            extra: {
              'operation': 'update',
              'recordId': eventWithDirtyFlag.id,
              'url': 'supabase:events:update',
            },
            message: 'Immediate upload failed; record stays dirty for retry',
          );
          rethrow;
        }
      } else {
        // Attempt background upload (non-blocking) with logging
        unawaited(() async {
          try {
            await _uploadEventToSupabase(eventWithDirtyFlag, 'update');
          } catch (e, stackTrace) {
            _report.degraded(
              e,
              stackTrace: stackTrace,
              area: 'events',
              tags: {'method': 'UPSERT'},
              extra: {
                'operation': 'update',
                'recordId': eventWithDirtyFlag.id,
                'url': 'supabase:events:update',
              },
              message: 'Immediate upload failed; record stays dirty for retry',
            );
          }
        }());
      }

      return eventWithDirtyFlag;
    } catch (e, stackTrace) {
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'events',
        message: 'Failed to update event',
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

      // CASCADE: Delete carb loading plan first (Drift doesn't enforce FK constraints)
      // This must happen BEFORE deleting the event so we can find the plan by eventId
      await _carbLoadingRepository.deleteCarbLoadingPlanByEventId(
        deviceId: deviceId,
        eventId: eventId,
      );

      // The linked activity is NOT deleted (ticket 80 Q2, Lee 2026-10-09):
      // the server keeps it (the FK runs activities -> events, not back), so
      // a local-only delete just came back on the next activities pull. A
      // linked activity is usually the provider's workout; it stays.

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
            _report.degraded(
              e,
              stackTrace: stackTrace,
              area: 'events',
              tags: {'method': 'DELETE'},
              extra: {
                'operation': 'delete',
                'recordId': eventId,
                'url': 'supabase:events:delete',
              },
              message: 'Immediate upload failed; record stays dirty for retry',
            );
          }
        }());
      }
    } catch (e, stackTrace) {
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'events',
        message: 'Failed to delete event',
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
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'events',
        message: 'Failed to get events',
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
        _report.degraded(
          LoggedFault(
            'Found duplicate events with same ID',
            context: 'EVENTS_REPOSITORY',
          ),
          area: 'events',
          extra: {'eventId': eventId, 'count': events.length},
        );
      }

      return events.isNotEmpty ? _mapToEventDomain(events.first) : null;
    } catch (e, stackTrace) {
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'events',
        message: 'Failed to get event by ID',
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
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'events',
        message: 'Failed to get event for activity',
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
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'events',
        extra: {
          'userId': userId,
          'eventName': eventName,
          'eventDate': eventDate.toIso8601String(),
        },
        message: 'Failed to find existing event',
      );
      return null; // Return null on error to allow sync to continue
    }
  }

  /// The user's event stored with the provider's own id [providerEventId],
  /// or null (ticket 80 Q3). The import's first match:
  /// unlike (name, date) it still finds an imported event after the athlete
  /// renamed or re-dated it.
  Future<domain.Event?> findEventByProviderEventId({
    required String userId,
    required String providerEventId,
  }) async {
    try {
      final query = _database.select(_database.eventsTable)
        ..where(
          (tbl) =>
              tbl.userId.lower().equals(userId.toLowerCase()) &
              tbl.providerEventId.equals(providerEventId),
        )
        ..limit(1);
      final event = await query.getSingleOrNull();
      return event != null ? _mapToEventDomain(event) : null;
    } catch (e, stackTrace) {
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'events',
        extra: {'userId': userId, 'providerEventId': providerEventId},
        message: 'Failed to find event by provider event id',
      );
      return null; // fall back to the (name, date) match
    }
  }

  /// The owner's other local event with the same trimmed name on the same
  /// calendar day, or null (develop-2026-10 ticket 72). The form guard's key:
  /// the server's `events_user_date_name_unique (user_id, event_date,
  /// event_name)` refuses that row with 23505. Names compare exactly after
  /// trimming both sides (the index is case-sensitive). [excludeEventId] is
  /// the event being edited, so saving it unchanged is not a collision.
  ///
  /// Unlike [findExistingEvent] this never swallows: a failed read must not
  /// let a duplicate through, so the error reaches the caller.
  Future<domain.Event?> findSameNameSameDayEvent({
    required String userId,
    required String eventName,
    required DateTime eventDate,
    String? excludeEventId,
  }) async {
    final name = eventName.trim();
    if (name.isEmpty) return null;
    final dateOnly = DateTime(eventDate.year, eventDate.month, eventDate.day);
    final nextDay = DateTime(dateOnly.year, dateOnly.month, dateOnly.day + 1);

    final rows =
        await (_database.select(_database.eventsTable)..where(
              (tbl) =>
                  tbl.userId.lower().equals(userId.toLowerCase()) &
                  tbl.eventDate.isBiggerOrEqualValue(dateOnly) &
                  tbl.eventDate.isSmallerThanValue(nextDay),
            ))
            .get();

    for (final row in rows) {
      if (row.id == excludeEventId) continue;
      if ((row.eventName ?? '').trim() == name) return _mapToEventDomain(row);
    }
    return null;
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
        origin: Value(event.origin),
        providerEventId: Value(event.providerEventId),
        // Metadata
        createdAt: event.createdAt,
        updatedAt: event.updatedAt,
      );

      final insertedRow = await _database
          .into(_database.eventsTable)
          .insertReturning(companion);

      _report.debug(
        'Created new event',
        area: 'events',
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
        origin: Value(event.origin),
        providerEventId: Value(event.providerEventId),
        // Metadata
        createdAt: Value(event.createdAt),
        updatedAt: Value(event.updatedAt),
      );

      await (_database.update(
        _database.eventsTable,
      )..where((tbl) => tbl.id.equals(event.id))).write(companion);

      _report.debug(
        'Updated existing event',
        area: 'events',
        data: {'eventId': event.id},
      );

      return event.id;
    }
  }

  /// True when an upload failed on the `events_user_id_fkey` FK (Postgres
  /// 23503): the auth user's `public.users` row doesn't exist yet, so any
  /// event insert before onboarding creates it FK-violates. Matched narrowly
  /// (code + user_id constraint text) so other FK/errors still surface.
  bool _isMissingUserRowFk(Object error) {
    if (error is! PostgrestException || error.code != '23503') return false;
    final text = '${error.message} ${error.details ?? ''}';
    return text.contains('events_user_id_fkey') || text.contains('user_id');
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

      _report.info(
        'Event uploaded to Supabase with UUID',
        area: 'events',
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
      'origin': event.origin,
      // Sent only when set: an absent key leaves the server value alone on
      // upsert, and a server without the v25 column still takes manual rows.
      if (event.providerEventId != null)
        'provider_event_id': event.providerEventId,
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
      origin: event.origin,
      providerEventId: event.providerEventId,
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
      // Re-derived from start_time (ticket 65): a stale server event_date
      // must not reach the calendar dot or coach surfaces. Kept as sent only
      // when start_time is missing or unparseable.
      eventDate: Value(_downloadedEventDate(json)),
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
      origin: Value(json['origin'] as String?),
      // The upsert is insertOrReplace, so an absent key (a server before the
      // column) reads NULL either way; say so rather than pretend to keep it.
      providerEventId: Value(json['provider_event_id'] as String?),
      localUpdatedAt: Value(DateTime.now()),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// The server's `event_date` as sent (null when absent).
  static DateTime? _serverEventDate(Map<String, dynamic> json) {
    final raw = json['event_date'];
    return raw != null ? DateTime.parse(raw as String) : null;
  }

  /// The `event_date` a downloaded row is stored with: derived from
  /// `start_time`, else the server's value.
  static DateTime? _downloadedEventDate(Map<String, dynamic> json) =>
      domain.Event.dateFromStartTime(json['start_time'] as String?) ??
      _serverEventDate(json);

  /// True when the download will store a different `event_date` than the
  /// server sent (the row is re-derived).
  static bool _serverEventDateDisagrees(Map<String, dynamic> json) {
    final derived = domain.Event.dateFromStartTime(
      json['start_time'] as String?,
    );
    if (derived == null) return false;
    final server = _serverEventDate(json);
    if (server == null) return true;
    return DateTime(server.year, server.month, server.day) != derived;
  }
}
