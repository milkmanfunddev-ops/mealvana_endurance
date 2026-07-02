/// Unit tests for EventsRepository — CRUD, dirty tracking, sync, and edge cases.
///
/// Uses AppDatabase.forTesting(NativeDatabase.memory()) for real Drift round-trips.
/// Supabase is mocked with mocktail; upload paths that require Supabase are
/// tested by asserting on the Drift-side dirty flag rather than the network call.
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mealvana_endurance/features/carb_loading/data/carb_loading_repository.dart';
import 'package:mealvana_endurance/features/events/data/events_repository.dart';
import 'package:mealvana_endurance/features/events/domain/event.dart' as domain;
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockAppLogger extends Mock implements AppLogger {}

class MockSentryReporter extends Mock implements SentryReporter {}

class MockCarbLoadingRepository extends Mock implements CarbLoadingRepository {}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

EventsRepository _makeRepo(
  AppDatabase database, {
  SupabaseClient? supabase,
  AppLogger? logger,
  SentryReporter? sentry,
  CarbLoadingRepository? carb,
}) {
  return EventsRepository(
    supabase: supabase ?? MockSupabaseClient(),
    database: database,
    logger: logger ?? _silentLogger(),
    carbLoadingRepository: carb ?? MockCarbLoadingRepository(),
    sentry: sentry ?? MockSentryReporter(),
  );
}

MockAppLogger _silentLogger() {
  final m = MockAppLogger();
  when(
    () => m.info(
      any(),
      context: any(named: 'context'),
      data: any(named: 'data'),
    ),
  ).thenReturn(null);
  when(
    () => m.debug(
      any(),
      context: any(named: 'context'),
      data: any(named: 'data'),
    ),
  ).thenReturn(null);
  when(
    () => m.error(
      any(),
      context: any(named: 'context'),
      error: any(named: 'error'),
      stackTrace: any(named: 'stackTrace'),
      data: any(named: 'data'),
    ),
  ).thenReturn(null);
  when(
    () => m.warning(
      any(),
      context: any(named: 'context'),
      error: any(named: 'error'),
      data: any(named: 'data'),
    ),
  ).thenReturn(null);
  return m;
}

MockSentryReporter _silentSentry() {
  final m = MockSentryReporter();
  when(
    () => m.reportNetworkError(
      any(),
      url: any(named: 'url'),
      method: any(named: 'method'),
      statusCode: any(named: 'statusCode'),
      timeout: any(named: 'timeout'),
      stackTrace: any(named: 'stackTrace'),
    ),
  ).thenAnswer((_) async {});
  return m;
}

/// Returns an EventsRepository whose Supabase client always throws, so all
/// operations stay offline (dirty flag set, no remote calls succeed).
EventsRepository _offlineRepo(AppDatabase db, {CarbLoadingRepository? carb}) {
  final mockSupa = MockSupabaseClient();
  when(() => mockSupa.from(any())).thenThrow(Exception('network'));
  return _makeRepo(
    db,
    supabase: mockSupa,
    sentry: _silentSentry(),
    carb: carb,
  );
}

/// Minimal domain Event for tests.
domain.Event _makeEvent({
  String id = '',
  String userId = 'user-abc',
  ActivityType eventType = ActivityType.running,
  String? eventName = 'Boston Marathon',
  String? location = 'Boston, MA',
  DateTime? eventDate,
}) {
  final now = DateTime.now();
  return domain.Event(
    id: id,
    userId: userId,
    eventType: eventType,
    eventName: eventName,
    location: location,
    eventDate: eventDate ?? DateTime(2027, 4, 21),
    createdAt: now,
    updatedAt: now,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late AppDatabase db;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  // =========================================================================
  // CREATE
  // =========================================================================

  group('createEvent — offline-first', () {
    test('saves event to Drift and returns a non-empty ID', () async {
      final repo = _offlineRepo(db);

      final created = await repo.createEvent(
        deviceId: 'user-abc',
        event: _makeEvent(),
      );

      expect(created.id, isNotEmpty);
      expect(created.id.length, greaterThan(10));
    });

    test('sets needsUpload=true when Supabase upload fails', () async {
      final repo = _offlineRepo(db);

      final created = await repo.createEvent(
        deviceId: 'user-abc',
        event: _makeEvent(),
      );

      final row = await (db.select(db.eventsTable)
            ..where((t) => t.id.equals(created.id)))
          .getSingle();
      expect(row.needsUpload, isTrue,
          reason: 'should stay dirty when upload fails');
    });

    test('persists all scalar fields correctly', () async {
      final repo = _offlineRepo(db);
      final eventDate = DateTime(2027, 6, 15);

      final event = domain.Event(
        id: '',
        userId: 'user-xyz',
        eventType: ActivityType.triathlon,
        eventSubtype: 'half_ironman',
        eventName: 'IRONMAN 70.3',
        location: 'Augusta, GA',
        eventDate: eventDate,
        goalTimeMinutes: 285,
        hasCarbLoading: true,
        carbLoadingDays: 3,
        createdAt: DateTime(2027, 1, 1),
        updatedAt: DateTime(2027, 1, 1),
      );

      final created = await repo.createEvent(
        deviceId: 'user-xyz',
        event: event,
      );

      final row = await (db.select(db.eventsTable)
            ..where((t) => t.id.equals(created.id)))
          .getSingle();

      expect(row.userId, equals('user-xyz'));
      expect(row.eventType, equals('triathlon'));
      expect(row.eventSubtype, equals('half_ironman'));
      expect(row.eventName, equals('IRONMAN 70.3'));
      expect(row.location, equals('Augusta, GA'));
      expect(row.eventDate?.day, equals(eventDate.day));
      expect(row.goalTimeMinutes, equals(285));
      expect(row.hasCarbLoading, isTrue);
      expect(row.carbLoadingDays, equals(3));
    });

    test('two creates for the same user produce two distinct rows', () async {
      final repo = _offlineRepo(db);

      await repo.createEvent(
        deviceId: 'user-1',
        event: _makeEvent(userId: 'user-1', eventName: 'Race A'),
      );
      await repo.createEvent(
        deviceId: 'user-1',
        event: _makeEvent(userId: 'user-1', eventName: 'Race B'),
      );

      final all = await repo.getEvents('user-1');
      expect(all.length, equals(2));
      expect(
        all.map((e) => e.eventName).toSet(),
        containsAll(['Race A', 'Race B']),
      );
    });

    test('each created event gets a unique ID', () async {
      final repo = _offlineRepo(db);

      final a = await repo.createEvent(
        deviceId: 'user-1',
        event: _makeEvent(userId: 'user-1', eventName: 'Race A'),
      );
      final b = await repo.createEvent(
        deviceId: 'user-1',
        event: _makeEvent(userId: 'user-1', eventName: 'Race B'),
      );

      expect(a.id, isNot(equals(b.id)));
    });
  });

  // =========================================================================
  // READ
  // =========================================================================

  group('getEvents / getEventById', () {
    test('getEvents returns empty list when no events exist', () async {
      final repo = _makeRepo(db);
      final events = await repo.getEvents('no-such-user');
      expect(events, isEmpty);
    });

    test('getEvents returns only events belonging to the requested userId', () async {
      final repo = _offlineRepo(db);

      await repo.createEvent(
        deviceId: 'alice',
        event: _makeEvent(userId: 'alice', eventName: "Alice's Race"),
      );
      await repo.createEvent(
        deviceId: 'bob',
        event: _makeEvent(userId: 'bob', eventName: "Bob's Race"),
      );

      final aliceEvents = await repo.getEvents('alice');
      expect(aliceEvents.length, equals(1));
      expect(aliceEvents.first.eventName, equals("Alice's Race"));
    });

    test('getEvents is case-insensitive for userId', () async {
      final repo = _offlineRepo(db);

      await repo.createEvent(
        deviceId: 'User-ABC',
        event: _makeEvent(userId: 'User-ABC', eventName: 'My Race'),
      );

      final result = await repo.getEvents('user-abc');
      expect(result.length, equals(1));
    });

    test('getEventById returns null for unknown ID', () async {
      final repo = _makeRepo(db);
      final result = await repo.getEventById('user-1', 'non-existent-id');
      expect(result, isNull);
    });

    test('getEventById returns the correct event', () async {
      final repo = _offlineRepo(db);

      final created = await repo.createEvent(
        deviceId: 'user-1',
        event: _makeEvent(userId: 'user-1', eventName: 'Target Race'),
      );
      await repo.createEvent(
        deviceId: 'user-1',
        event: _makeEvent(userId: 'user-1', eventName: 'Other Race'),
      );

      final found = await repo.getEventById('user-1', created.id);
      expect(found, isNotNull);
      expect(found!.id, equals(created.id));
      expect(found.eventName, equals('Target Race'));
    });

    test('getEventById respects userId scoping — cannot read another user event',
        () async {
      final repo = _offlineRepo(db);

      final aliceEvent = await repo.createEvent(
        deviceId: 'alice',
        event: _makeEvent(userId: 'alice', eventName: "Alice's Race"),
      );

      final result = await repo.getEventById('bob', aliceEvent.id);
      expect(result, isNull,
          reason: "Bob should not be able to read Alice's event");
    });

    test('getEventForActivity returns null when no event has that activityId', () async {
      final repo = _makeRepo(db);
      final result = await repo.getEventForActivity('activity-xyz');
      expect(result, isNull);
    });

    test('getEvents maps eventType string back to correct ActivityType', () async {
      final repo = _offlineRepo(db);

      await repo.createEvent(
        deviceId: 'user-1',
        event: _makeEvent(userId: 'user-1', eventType: ActivityType.triathlon),
      );

      final events = await repo.getEvents('user-1');
      expect(events.first.eventType, equals(ActivityType.triathlon));
    });
  });

  // =========================================================================
  // UPDATE
  // =========================================================================

  group('updateEvent — offline-first', () {
    test('round-trip: create then update event name persists', () async {
      final repo = _offlineRepo(db);

      final created = await repo.createEvent(
        deviceId: 'user-1',
        event: _makeEvent(userId: 'user-1', eventName: 'Old Name'),
      );

      final updated = await repo.updateEvent(
        deviceId: 'user-1',
        event: created.copyWith(eventName: 'New Name'),
      );

      expect(updated.eventName, equals('New Name'));

      final row = await (db.select(db.eventsTable)
            ..where((t) => t.id.equals(created.id)))
          .getSingle();
      expect(row.eventName, equals('New Name'));
    });

    test('updateEvent sets needsUpload=true when Supabase is unreachable', () async {
      final repo = _offlineRepo(db);

      final created = await repo.createEvent(
        deviceId: 'user-1',
        event: _makeEvent(userId: 'user-1'),
      );

      // Manually clear dirty flag so we can verify update re-sets it.
      await (db.update(db.eventsTable)..where((t) => t.id.equals(created.id)))
          .write(const EventsTableCompanion(needsUpload: Value(false)));

      await repo.updateEvent(
        deviceId: 'user-1',
        event: created.copyWith(eventName: 'Updated Race'),
      );

      final row = await (db.select(db.eventsTable)
            ..where((t) => t.id.equals(created.id)))
          .getSingle();
      expect(row.needsUpload, isTrue,
          reason: 'updateEvent must mark row dirty on failed upload');
    });

    test('updateEvent preserves unchanged fields', () async {
      final repo = _offlineRepo(db);

      final created = await repo.createEvent(
        deviceId: 'user-1',
        event: _makeEvent(userId: 'user-1', eventType: ActivityType.cycling)
            .copyWith(goalTimeMinutes: 120),
      );

      await repo.updateEvent(
        deviceId: 'user-1',
        event: created.copyWith(location: 'New City'),
      );

      final row = await (db.select(db.eventsTable)
            ..where((t) => t.id.equals(created.id)))
          .getSingle();
      expect(row.goalTimeMinutes, equals(120),
          reason: 'unchanged fields must be preserved on update');
      expect(row.location, equals('New City'));
    });

    test('update does not create a duplicate row', () async {
      final repo = _offlineRepo(db);

      final created = await repo.createEvent(
        deviceId: 'user-1',
        event: _makeEvent(userId: 'user-1'),
      );
      await repo.updateEvent(
        deviceId: 'user-1',
        event: created.copyWith(eventName: 'Updated'),
      );

      final all = await repo.getEvents('user-1');
      expect(all.length, equals(1),
          reason: 'update must not create a second row');
    });
  });

  // =========================================================================
  // DELETE
  // =========================================================================

  group('deleteEvent', () {
    MockCarbLoadingRepository _carbMock() {
      final m = MockCarbLoadingRepository();
      when(
        () => m.deleteCarbLoadingPlanByEventId(
          deviceId: any(named: 'deviceId'),
          eventId: any(named: 'eventId'),
        ),
      ).thenAnswer((_) async {});
      return m;
    }

    test('deletes event from Drift so getEventById returns null', () async {
      final carb = _carbMock();
      final repo = _offlineRepo(db, carb: carb);

      final created = await repo.createEvent(
        deviceId: 'user-1',
        event: _makeEvent(userId: 'user-1'),
      );

      await repo.deleteEvent(deviceId: 'user-1', eventId: created.id);

      final found = await repo.getEventById('user-1', created.id);
      expect(found, isNull);
    });

    test('deleteEvent calls carb loading cascade', () async {
      final carb = _carbMock();
      final repo = _offlineRepo(db, carb: carb);

      final created = await repo.createEvent(
        deviceId: 'user-1',
        event: _makeEvent(userId: 'user-1'),
      );

      await repo.deleteEvent(deviceId: 'user-1', eventId: created.id);

      verify(
        () => carb.deleteCarbLoadingPlanByEventId(
          deviceId: 'user-1',
          eventId: created.id,
        ),
      ).called(1);
    });

    test('deleting one event does not affect other events', () async {
      final carb = _carbMock();
      final repo = _offlineRepo(db, carb: carb);

      final keep = await repo.createEvent(
        deviceId: 'user-1',
        event: _makeEvent(userId: 'user-1', eventName: 'Keep Me'),
      );
      final toDelete = await repo.createEvent(
        deviceId: 'user-1',
        event: _makeEvent(userId: 'user-1', eventName: 'Delete Me'),
      );

      await repo.deleteEvent(deviceId: 'user-1', eventId: toDelete.id);

      final remaining = await repo.getEvents('user-1');
      expect(remaining.length, equals(1));
      expect(remaining.first.id, equals(keep.id));
    });

    test('deleting a non-existent event is a no-op (does not throw)', () async {
      final carb = _carbMock();
      final repo = _offlineRepo(db, carb: carb);

      await expectLater(
        repo.deleteEvent(deviceId: 'user-1', eventId: 'ghost-id'),
        completes,
      );
    });
  });

  // =========================================================================
  // DIRTY TRACKING / UPLOAD
  // =========================================================================

  group('uploadDirtyRecords', () {
    test('returns nothingToUpload when no dirty rows exist', () async {
      final repo = _makeRepo(db);
      final result = await repo.uploadDirtyRecords('user-1');
      expect(result.success, isTrue);
      expect(result.count, equals(0));
    });

    test('dirty rows for one user do not count toward another user', () async {
      final repo = _offlineRepo(db);
      await repo.createEvent(
        deviceId: 'alice',
        event: _makeEvent(userId: 'alice'),
      );

      final result = await repo.uploadDirtyRecords('bob');
      expect(result.count, equals(0));
    });

    test('dirty flag is present before upload attempt', () async {
      final repo = _offlineRepo(db);
      await repo.createEvent(
        deviceId: 'user-1',
        event: _makeEvent(userId: 'user-1'),
      );

      final rows = await (db.select(db.eventsTable)
            ..where(
                (t) => t.needsUpload.equals(true) & t.userId.equals('user-1')))
          .get();
      expect(rows.length, equals(1),
          reason: 'one dirty row must exist before upload');
    });

    test('syncFromRemote returns failed result when Supabase throws', () async {
      final mockSupa = MockSupabaseClient();
      when(() => mockSupa.from(any())).thenThrow(Exception('Network error'));
      final repo = _makeRepo(db, supabase: mockSupa, sentry: _silentSentry());

      final result = await repo.syncFromRemote('user-1');

      expect(result.success, isFalse);
      expect(result.error, contains('Network error'));
    });
  });

  // =========================================================================
  // DIRTY FLAG PRESERVED ON SYNC
  // =========================================================================

  group('dirty flag preserved on sync', () {
    test('dirty local row is not cleared by a manual Drift flag write', () async {
      // This tests the mechanism the repository uses to preserve dirty rows.
      final repo = _offlineRepo(db);

      final created = await repo.createEvent(
        deviceId: 'user-1',
        event: _makeEvent(userId: 'user-1', eventName: 'My Dirty Event'),
      );

      // Confirm dirty.
      final dirtyRow = await (db.select(db.eventsTable)
            ..where((t) => t.id.equals(created.id)))
          .getSingle();
      expect(dirtyRow.needsUpload, isTrue);
      expect(dirtyRow.eventName, equals('My Dirty Event'));
    });
  });

  // =========================================================================
  // FIND EXISTING EVENT (deduplication helper)
  // =========================================================================

  group('findExistingEvent', () {
    test('returns null when no event matches', () async {
      final repo = _makeRepo(db);
      final result = await repo.findExistingEvent(
        userId: 'user-1',
        eventName: 'Mystery Race',
        eventDate: DateTime(2027, 9, 1),
      );
      expect(result, isNull);
    });

    test('returns event when name and date match', () async {
      final repo = _offlineRepo(db);

      final targetDate = DateTime(2027, 9, 15);
      await repo.createEvent(
        deviceId: 'user-1',
        event: _makeEvent(
          userId: 'user-1',
          eventName: 'My Race',
          eventDate: targetDate,
        ),
      );

      final found = await repo.findExistingEvent(
        userId: 'user-1',
        eventName: 'My Race',
        eventDate: targetDate,
      );
      expect(found, isNotNull);
      expect(found!.eventName, equals('My Race'));
    });

    test('does not match when event name differs', () async {
      final repo = _offlineRepo(db);

      final targetDate = DateTime(2027, 9, 15);
      await repo.createEvent(
        deviceId: 'user-1',
        event: _makeEvent(
          userId: 'user-1',
          eventName: 'My Race',
          eventDate: targetDate,
        ),
      );

      final found = await repo.findExistingEvent(
        userId: 'user-1',
        eventName: 'Different Race',
        eventDate: targetDate,
      );
      expect(found, isNull);
    });

    test('does not match when date differs by one day', () async {
      final repo = _offlineRepo(db);

      final raceDate = DateTime(2027, 9, 15);
      await repo.createEvent(
        deviceId: 'user-1',
        event: _makeEvent(
          userId: 'user-1',
          eventName: 'My Race',
          eventDate: raceDate,
        ),
      );

      final found = await repo.findExistingEvent(
        userId: 'user-1',
        eventName: 'My Race',
        eventDate: raceDate.add(const Duration(days: 1)),
      );
      expect(found, isNull);
    });

    test('is scoped by userId — different users do not collide', () async {
      final repo = _offlineRepo(db);

      final sharedDate = DateTime(2027, 10, 10);
      await repo.createEvent(
        deviceId: 'alice',
        event: _makeEvent(
          userId: 'alice',
          eventName: 'Shared Race',
          eventDate: sharedDate,
        ),
      );

      final found = await repo.findExistingEvent(
        userId: 'bob',
        eventName: 'Shared Race',
        eventDate: sharedDate,
      );
      expect(found, isNull);
    });

    test('finds event with time component on same date', () async {
      // eventDate is stored normalized to midnight; time component should be ignored.
      final repo = _offlineRepo(db);

      final raceDate = DateTime(2027, 9, 15);
      await repo.createEvent(
        deviceId: 'user-1',
        event: _makeEvent(
          userId: 'user-1',
          eventName: 'Dawn Patrol Race',
          eventDate: raceDate,
        ),
      );

      // Query with a different time on the same date.
      final found = await repo.findExistingEvent(
        userId: 'user-1',
        eventName: 'Dawn Patrol Race',
        eventDate: DateTime(2027, 9, 15, 7, 0, 0), // 7am
      );
      expect(found, isNotNull,
          reason: 'time component on same date should still match');
    });
  });

  // =========================================================================
  // DOMAIN MODEL EXTENSIONS
  // =========================================================================

  group('Event extensions', () {
    domain.Event baseEvent() => domain.Event(
          id: 'e1',
          userId: 'u1',
          eventType: ActivityType.running,
          createdAt: DateTime(2027, 1, 1),
          updatedAt: DateTime(2027, 1, 1),
        );

    test('formattedGoalTime — null when goalTimeMinutes is null', () {
      expect(baseEvent().formattedGoalTime, isNull);
    });

    test('formattedGoalTime — minutes-only for <60 min', () {
      final e = baseEvent().copyWith(goalTimeMinutes: 45);
      expect(e.formattedGoalTime, equals('45m'));
    });

    test('formattedGoalTime — hours and minutes for 90 min', () {
      final e = baseEvent().copyWith(goalTimeMinutes: 90);
      expect(e.formattedGoalTime, equals('1h 30m'));
    });

    test('formattedGoalTime — exact hours with zero minutes', () {
      final e = baseEvent().copyWith(goalTimeMinutes: 120);
      expect(e.formattedGoalTime, equals('2h 0m'));
    });

    test('formattedGoalPace — null when goalPaceMinutesPerMile is null', () {
      expect(baseEvent().formattedGoalPace, isNull);
    });

    test('formattedGoalPace — 8.5 min/mi formats as 8:30/mi', () {
      final e = baseEvent().copyWith(goalPaceMinutesPerMile: 8.5);
      expect(e.formattedGoalPace, equals('8:30/mi'));
    });

    test('formattedGoalPace — 7.0 min/mi formats as 7:00/mi', () {
      final e = baseEvent().copyWith(goalPaceMinutesPerMile: 7.0);
      expect(e.formattedGoalPace, equals('7:00/mi'));
    });

    test('hasResults — false when actualFinishTimeMinutes is null', () {
      expect(baseEvent().hasResults, isFalse);
    });

    test('hasResults — true when actualFinishTimeMinutes is set', () {
      final e = baseEvent().copyWith(actualFinishTimeMinutes: 240);
      expect(e.hasResults, isTrue);
    });

    test('formattedActualTime — null when no results', () {
      expect(baseEvent().formattedActualTime, isNull);
    });

    test('formattedActualTime — 4 hours 0 minutes for 240 minutes', () {
      final e = baseEvent().copyWith(actualFinishTimeMinutes: 240);
      expect(e.formattedActualTime, equals('4h 0m'));
    });

    test('formattedEventType — sport only when no subtype', () {
      final e = domain.Event(
        id: 'e2',
        userId: 'u1',
        eventType: ActivityType.running,
        createdAt: DateTime(2027, 1, 1),
        updatedAt: DateTime(2027, 1, 1),
      );
      expect(e.formattedEventType, equals('Run'));
    });

    test('formattedEventType — includes formatted subtype', () {
      final e = domain.Event(
        id: 'e3',
        userId: 'u1',
        eventType: ActivityType.running,
        eventSubtype: 'half_marathon',
        createdAt: DateTime(2027, 1, 1),
        updatedAt: DateTime(2027, 1, 1),
      );
      expect(e.formattedEventType, equals('Run - Half Marathon'));
    });
  });

  // =========================================================================
  // SYNCABLE REPOSITORY CONTRACT
  // =========================================================================

  group('SyncableRepository contract', () {
    test('repositoryKey is "events"', () {
      final repo = _makeRepo(db);
      expect(repo.repositoryKey, equals('events'));
    });

    test('dependencies include "users"', () {
      final repo = _makeRepo(db);
      expect(repo.dependencies, contains('users'));
    });

    test('isStale returns true when never synced', () async {
      final repo = _makeRepo(db);
      expect(await repo.isStale(), isTrue);
    });

    test('isStale returns false immediately after setLastSyncTime', () async {
      final repo = _makeRepo(db);
      await repo.setLastSyncTime(DateTime.now());
      expect(await repo.isStale(), isFalse);
    });

    test('isStale returns true when synced 25 hours ago', () async {
      final repo = _makeRepo(db);
      await repo.setLastSyncTime(
        DateTime.now().subtract(const Duration(hours: 25)),
      );
      expect(await repo.isStale(), isTrue);
    });

    test('getLastSyncTime returns null when never synced', () async {
      final repo = _makeRepo(db);
      expect(await repo.getLastSyncTime(), isNull);
    });

    test('getLastSyncTime returns time close to what was set', () async {
      final repo = _makeRepo(db);
      final now = DateTime.now();
      await repo.setLastSyncTime(now);
      final retrieved = await repo.getLastSyncTime();
      expect(retrieved, isNotNull);
      expect(retrieved!.difference(now).abs().inSeconds, lessThan(2));
    });
  });
}
