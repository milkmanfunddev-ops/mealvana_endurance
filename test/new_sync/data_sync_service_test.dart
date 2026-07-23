// Unit tests for DataSyncService (lib/shared/services/sync/data_sync_service.dart)
// — the full-sync DOWNLOAD orchestrator behind the sync-all-data edge function.
//
// Scope note: DataSyncService owns no upload path. Uploads (uploadDirtyRecords
// and its silent UploadResult.failed() trap) live in SyncCoordinator + the
// syncable repositories and are covered by sync_coordinator_v2_test.dart and
// the per-repository *_sync_test.dart files. What this suite pins down instead
// is the orchestration contract of the download side:
//
//  • STEP 0 ordering: the user profile syncs BEFORE anything else (FK guard),
//    and a STEP-0 failure aborts the whole sync with `false` — no edge call,
//    no fallback, no timestamp.
//  • Edge-function happy path: every payload slice is routed to its entity
//    handler and the server timestamp is persisted.
//  • Edge apply failure: a handler exception rolls back the edge apply (the
//    server timestamp must NOT be persisted) and falls back to client-side
//    download rather than reporting success from a half-applied payload.
//  • Client-side fallback: per-entity isolation (one entity failing does not
//    stop the others) and soft-deleted activities are filtered out.
//  • DOCUMENTED HAZARD: every per-entity download failure is swallowed, so a
//    fallback where *everything* failed still returns true and stamps
//    last_sync_timestamp. The test asserting this exists to make the behavior
//    visible — if it ever starts failing, the hazard was fixed and the test
//    should be inverted, not deleted.
//  • needsFullSync fresh-device heuristics (no profile / never synced /
//    stale > 30 days / recent).

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mealvana_endurance/features/carb_loading/application/carb_loading_food_sync_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/food_repository.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/database/database_provider.dart';
import 'package:mealvana_endurance/shared/services/prefs_provider.dart';
import 'package:mealvana_endurance/shared/services/sync/data_sync_service.dart';
import 'package:mealvana_endurance/shared/services/sync/entity_sync/entity_sync.dart';

import '../helpers/fakes/recording_app_logger.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockFunctionsClient extends Mock implements FunctionsClient {}

class MockFoodRepository extends Mock implements FoodRepository {}

class MockCarbLoadingFoodSyncService extends Mock
    implements CarbLoadingFoodSyncService {}

class MockActivitySyncHandler extends Mock implements ActivitySyncHandler {}

class MockEventSyncHandler extends Mock implements EventSyncHandler {}

class MockCarbLoadingSyncHandler extends Mock
    implements CarbLoadingSyncHandler {}

class MockCoachSyncHandler extends Mock implements CoachSyncHandler {}

class MockUserSyncHandler extends Mock implements UserSyncHandler {}

class MockFoodPreferenceSyncHandler extends Mock
    implements FoodPreferenceSyncHandler {}

// ---------------------------------------------------------------------------
// Fake PostgREST query chain for the client-side fallback path.
//
// _clientSideDownload awaits chains like from(t).select(...).eq(...).order(...)
// — PostgrestBuilder implements Future, so faking `then` is enough to resolve
// the await with canned rows. eq/order return `this` so any chain shape works.
// ---------------------------------------------------------------------------

class _FakeQueryBuilder extends Fake implements SupabaseQueryBuilder {
  _FakeQueryBuilder(this._rows);

  final List<Map<String, dynamic>> _rows;

  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) =>
      _FakeFilterBuilder(_rows);
}

/// A query builder whose select() throws — simulates a network failure for a
/// single table in the client-side fallback.
class _ThrowingQueryBuilder extends Fake implements SupabaseQueryBuilder {
  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) =>
      throw Exception('network down');
}

class _FakeFilterBuilder extends Fake
    implements PostgrestFilterBuilder<PostgrestList> {
  _FakeFilterBuilder(this._rows);

  final List<Map<String, dynamic>> _rows;

  @override
  PostgrestFilterBuilder<PostgrestList> eq(String column, Object value) => this;

  @override
  PostgrestTransformBuilder<PostgrestList> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) => this;

  @override
  Future<U> then<U>(
    FutureOr<U> Function(PostgrestList value) onValue, {
    Function? onError,
  }) => Future<PostgrestList>.value(_rows).then(onValue, onError: onError);
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

/// Captures a [Ref] usable by DataSyncService (sharedPreferencesProvider reads
/// + calendar provider invalidation).
final _refCaptor = Provider<Ref>((ref) => ref);

class _Harness {
  late AppDatabase db;
  late SharedPreferences prefs;
  late ProviderContainer container;
  late MockSupabaseClient supabase;
  late MockFunctionsClient functions;
  late MockFoodRepository foodRepository;
  late MockCarbLoadingFoodSyncService carbFoodSync;
  late MockActivitySyncHandler activityHandler;
  late MockEventSyncHandler eventHandler;
  late MockCarbLoadingSyncHandler carbLoadingHandler;
  late MockCoachSyncHandler coachHandler;
  late MockUserSyncHandler userHandler;
  late MockFoodPreferenceSyncHandler foodPrefHandler;
  late RecordingAppLogger logger;
  late DataSyncService service;
}

Future<_Harness> _buildHarness() async {
  final h = _Harness();

  SharedPreferences.setMockInitialValues({});
  h.prefs = await SharedPreferences.getInstance();

  h.db = AppDatabase.memory();
  h.container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(h.db),
      sharedPreferencesProvider.overrideWithValue(h.prefs),
    ],
  );

  h.supabase = MockSupabaseClient();
  h.functions = MockFunctionsClient();
  h.foodRepository = MockFoodRepository();
  h.carbFoodSync = MockCarbLoadingFoodSyncService();
  h.activityHandler = MockActivitySyncHandler();
  h.eventHandler = MockEventSyncHandler();
  h.carbLoadingHandler = MockCarbLoadingSyncHandler();
  h.coachHandler = MockCoachSyncHandler();
  h.userHandler = MockUserSyncHandler();
  h.foodPrefHandler = MockFoodPreferenceSyncHandler();
  h.logger = RecordingAppLogger();

  when(() => h.supabase.functions).thenReturn(h.functions);

  // Default: every handler write succeeds. Individual tests override.
  when(() => h.userHandler.syncUsers(any())).thenAnswer((_) async {});
  when(
    () => h.foodRepository.syncFromDownloadedData(foods: any(named: 'foods')),
  ).thenAnswer((_) async {});
  when(
    () => h.carbFoodSync.syncFromDownloadedData(
      carbLoadingFoods: any(named: 'carbLoadingFoods'),
    ),
  ).thenAnswer((_) async {});
  when(() => h.activityHandler.upsertActivity(any())).thenAnswer((_) async {});
  when(
    () => h.activityHandler.syncAthleteActivities(any()),
  ).thenAnswer((_) async {});
  when(() => h.eventHandler.upsertEvent(any(), any())).thenAnswer((_) async {});
  when(() => h.eventHandler.syncAthleteEvents(any())).thenAnswer((_) async {});
  when(
    () => h.carbLoadingHandler.upsertCarbLoadingPlan(any()),
  ).thenAnswer((_) async {});
  when(
    () => h.carbLoadingHandler.upsertCarbLoadingDay(any()),
  ).thenAnswer((_) async {});
  when(
    () => h.carbLoadingHandler.syncAthleteCarbLoadingPlans(any()),
  ).thenAnswer((_) async {});
  when(() => h.coachHandler.syncCoachRecord(any())).thenAnswer((_) async {});
  when(
    () => h.coachHandler.syncCoachAthleteRelationships(any()),
  ).thenAnswer((_) async {});
  when(
    () => h.coachHandler.syncAthleteProfiles(any()),
  ).thenAnswer((_) async {});
  when(() => h.coachHandler.syncCoachProfiles(any())).thenAnswer((_) async {});
  when(
    () => h.coachHandler.syncCoachMessagesForActivity(any()),
  ).thenAnswer((_) async {});
  when(() => h.coachHandler.syncAthleteData(any())).thenAnswer((_) async {});
  when(
    () => h.foodPrefHandler.syncFoodPreferencesFromEdgeFunction(any()),
  ).thenAnswer((_) async {});

  h.service = DataSyncService(
    ref: h.container.read(_refCaptor),
    supabase: h.supabase,
    database: h.db,
    logger: h.logger,
    foodRepository: h.foodRepository,
    carbLoadingFoodSyncService: h.carbFoodSync,
    activitySyncHandler: h.activityHandler,
    eventSyncHandler: h.eventHandler,
    carbLoadingSyncHandler: h.carbLoadingHandler,
    coachSyncHandler: h.coachHandler,
    userSyncHandler: h.userHandler,
    foodPreferenceSyncHandler: h.foodPrefHandler,
  );

  addTearDown(h.container.dispose);
  addTearDown(h.db.close);
  return h;
}

/// Stubs the edge function to return [data] with HTTP 200.
void _stubEdgeResponse(_Harness h, dynamic data) {
  when(
    () => h.functions.invoke('sync-all-data', body: any(named: 'body')),
  ).thenAnswer((_) async => FunctionResponse(status: 200, data: data));
}

/// Stubs every table used by the client-side fallback to return empty rows.
void _stubEmptyFallbackTables(_Harness h) {
  for (final table in [
    'foods',
    'carb_loading_foods',
    'activities',
    'events',
    'carb_loading_plans',
    'carb_loading_days',
  ]) {
    when(
      () => h.supabase.from(table),
    ).thenAnswer((_) => _FakeQueryBuilder(const []));
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const userId = 'user-1';
  const tsKey = 'last_sync_timestamp_$userId';

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(<dynamic>[]);
  });

  group('DataSyncService.syncAllData — edge function path', () {
    test('happy path routes every payload slice to its handler, persists the '
        'server timestamp, and returns true', () async {
      final h = await _buildHarness();

      // Same map instances are used in the payload and in verify() —
      // mocktail matches arguments by equality and Map == is identity.
      final food = {'id': 'food-1'};
      final carbFood = {'id': 'carb-food-1'};
      final activity1 = {'id': 'activity-1'};
      final activity2 = {'id': 'activity-2'};
      final event = {'id': 'event-1', 'user_id': userId};
      final plan = {'id': 'plan-1'};
      final day = {'id': 'day-1'};
      final foodPref = {'id': 'pref-1'};
      final coachRecord = {'id': 'coach-1'};
      final relationship = {'id': 'rel-1'};
      final athleteEvents = [
        {'id': 'athlete-event-1'},
      ];
      final athleteActivities = [
        {'id': 'athlete-activity-1'},
      ];
      final athleteProfiles = [
        {'id': 'athlete-profile-1'},
      ];
      final athletePlans = [
        {'id': 'athlete-plan-1'},
      ];
      final coachProfiles = [
        {'id': 'coach-profile-1'},
      ];

      _stubEdgeResponse(h, {
        'success': true,
        'timestamp': '2026-07-21T10:00:00.000Z',
        'data': {
          'nutrition_foods': [food],
          'carb_loading_foods': [carbFood],
          'activities': [activity1, activity2],
          'events': [event],
          'carb_loading_plans': [plan],
          'carb_loading_days': [day],
          'food_preferences': [foodPref],
          'coach_record': coachRecord,
          'coach_athlete_relationships': [relationship],
          'athlete_events': athleteEvents,
          'athlete_activities': athleteActivities,
          'athlete_profiles': athleteProfiles,
          'athlete_carb_loading_plans': athletePlans,
          'coach_profiles': coachProfiles,
        },
      });

      final result = await h.service.syncAllData(userId);

      expect(result, isTrue);

      // STEP 0 (user profile, FK guard) must run before the edge call.
      verifyInOrder([
        () => h.userHandler.syncUsers(userId),
        () => h.functions.invoke('sync-all-data', body: any(named: 'body')),
      ]);

      verify(
        () => h.foodRepository.syncFromDownloadedData(foods: [food]),
      ).called(1);
      verify(
        () =>
            h.carbFoodSync.syncFromDownloadedData(carbLoadingFoods: [carbFood]),
      ).called(1);
      verify(() => h.activityHandler.upsertActivity(activity1)).called(1);
      verify(() => h.activityHandler.upsertActivity(activity2)).called(1);
      verify(() => h.eventHandler.upsertEvent(event, userId)).called(1);
      verify(() => h.carbLoadingHandler.upsertCarbLoadingPlan(plan)).called(1);
      verify(() => h.carbLoadingHandler.upsertCarbLoadingDay(day)).called(1);
      verify(
        () => h.foodPrefHandler.syncFoodPreferencesFromEdgeFunction([foodPref]),
      ).called(1);
      verify(() => h.coachHandler.syncCoachRecord(coachRecord)).called(1);
      verify(
        () => h.coachHandler.syncCoachAthleteRelationships([relationship]),
      ).called(1);
      verify(() => h.eventHandler.syncAthleteEvents(athleteEvents)).called(1);
      verify(
        () => h.activityHandler.syncAthleteActivities(athleteActivities),
      ).called(1);
      verify(
        () => h.coachHandler.syncAthleteProfiles(athleteProfiles),
      ).called(1);
      verify(
        () => h.carbLoadingHandler.syncAthleteCarbLoadingPlans(athletePlans),
      ).called(1);
      verify(() => h.coachHandler.syncCoachProfiles(coachProfiles)).called(1);

      // Server timestamp persisted for delta syncs.
      expect(h.prefs.getString(tsKey), '2026-07-21T10:00:00.000Z');

      // The edge path succeeded — the client-side fallback must not run.
      verifyNever(() => h.supabase.from(any()));
    });

    test('no-op payload (empty data) touches no entity handler', () async {
      final h = await _buildHarness();
      _stubEdgeResponse(h, {
        'success': true,
        'timestamp': '2026-07-21T10:00:00.000Z',
        'data': <String, dynamic>{},
      });

      final result = await h.service.syncAllData(userId);

      expect(result, isTrue);
      verify(() => h.userHandler.syncUsers(userId)).called(1);
      verifyNever(
        () =>
            h.foodRepository.syncFromDownloadedData(foods: any(named: 'foods')),
      );
      verifyNever(() => h.activityHandler.upsertActivity(any()));
      verifyNever(() => h.eventHandler.upsertEvent(any(), any()));
      verifyNever(() => h.carbLoadingHandler.upsertCarbLoadingPlan(any()));
      verifyNever(() => h.coachHandler.syncCoachRecord(any()));
      verifyNever(
        () => h.foodPrefHandler.syncFoodPreferencesFromEdgeFunction(any()),
      );
      expect(h.prefs.getString(tsKey), '2026-07-21T10:00:00.000Z');
    });

    test('STEP 0 failure (user sync) aborts everything: returns false, no edge '
        'call, no fallback, no timestamp', () async {
      final h = await _buildHarness();
      when(
        () => h.userHandler.syncUsers(any()),
      ).thenThrow(Exception('users table unreachable'));

      final result = await h.service.syncAllData(userId);

      expect(result, isFalse);
      verifyNever(() => h.functions.invoke(any(), body: any(named: 'body')));
      verifyNever(() => h.supabase.from(any()));
      expect(h.prefs.getString(tsKey), isNull);
      expect(
        h.logger.records.any(
          (r) => r.level == 'error' && r.context == 'DATA_SYNC',
        ),
        isTrue,
        reason: 'top-level sync failure must be logged',
      );
    });

    test('handler failure during edge apply does NOT persist the server '
        'timestamp and falls back to client-side download', () async {
      final h = await _buildHarness();
      final activity = {'id': 'activity-1'};
      _stubEdgeResponse(h, {
        'success': true,
        'timestamp': 'EDGE-TS-MUST-NOT-BE-WRITTEN',
        'data': {
          'activities': [activity],
        },
      });
      // The edge apply AND the fallback activity download both fail for
      // this activity; the fallback swallows its own error per-entity.
      when(
        () => h.activityHandler.upsertActivity(any()),
      ).thenThrow(Exception('constraint violation'));
      _stubEmptyFallbackTables(h);
      when(
        () => h.supabase.from('activities'),
      ).thenAnswer((_) => _FakeQueryBuilder([activity]));

      final result = await h.service.syncAllData(userId);

      // The half-applied edge payload was rolled back and the fallback ran.
      expect(result, isTrue);
      verify(() => h.supabase.from('foods')).called(1);
      final ts = h.prefs.getString(tsKey);
      expect(ts, isNotNull);
      expect(
        ts,
        isNot('EDGE-TS-MUST-NOT-BE-WRITTEN'),
        reason:
            'the edge timestamp must not be persisted when applying the '
            'edge payload failed — otherwise the next delta sync would '
            'skip everything the failed apply dropped',
      );
      expect(
        h.logger.records.any((r) => r.context == 'EDGE_SYNC'),
        isTrue,
        reason: 'edge apply failure must be logged',
      );
    });

    test('edge function rejection (success: false) falls back and still '
        'syncs client-side', () async {
      final h = await _buildHarness();
      _stubEdgeResponse(h, {'success': false});
      _stubEmptyFallbackTables(h);

      final result = await h.service.syncAllData(userId);

      expect(result, isTrue);
      verify(() => h.supabase.from('foods')).called(1);
      expect(h.prefs.getString(tsKey), isNotNull);
    });
  });

  group('DataSyncService.syncAllData — client-side fallback path', () {
    test('downloads every entity, filters soft-deleted activities, stamps the '
        'timestamp, and returns true', () async {
      final h = await _buildHarness();
      when(
        () => h.functions.invoke(any(), body: any(named: 'body')),
      ).thenThrow(Exception('edge function unreachable'));

      final food = {'id': 'food-1'};
      final carbFood = {'id': 'carb-food-1'};
      final liveActivity = {'id': 'activity-live', 'deleted_at': null};
      final deletedActivity = {
        'id': 'activity-deleted',
        'deleted_at': '2026-01-01T00:00:00Z',
      };
      final event = {'id': 'event-1'};
      final plan = {'id': 'plan-1'};
      final day = {'id': 'day-1'};

      when(
        () => h.supabase.from('foods'),
      ).thenAnswer((_) => _FakeQueryBuilder([food]));
      when(
        () => h.supabase.from('carb_loading_foods'),
      ).thenAnswer((_) => _FakeQueryBuilder([carbFood]));
      when(
        () => h.supabase.from('activities'),
      ).thenAnswer((_) => _FakeQueryBuilder([liveActivity, deletedActivity]));
      when(
        () => h.supabase.from('events'),
      ).thenAnswer((_) => _FakeQueryBuilder([event]));
      when(
        () => h.supabase.from('carb_loading_plans'),
      ).thenAnswer((_) => _FakeQueryBuilder([plan]));
      when(
        () => h.supabase.from('carb_loading_days'),
      ).thenAnswer((_) => _FakeQueryBuilder([day]));

      final result = await h.service.syncAllData(userId);

      expect(result, isTrue);
      verify(
        () => h.foodRepository.syncFromDownloadedData(foods: [food]),
      ).called(1);
      verify(
        () =>
            h.carbFoodSync.syncFromDownloadedData(carbLoadingFoods: [carbFood]),
      ).called(1);
      verify(() => h.activityHandler.upsertActivity(liveActivity)).called(1);
      verifyNever(() => h.activityHandler.upsertActivity(deletedActivity));
      verify(() => h.eventHandler.upsertEvent(event, userId)).called(1);
      verify(() => h.carbLoadingHandler.upsertCarbLoadingPlan(plan)).called(1);
      verify(() => h.carbLoadingHandler.upsertCarbLoadingDay(day)).called(1);
      expect(h.prefs.getString(tsKey), isNotNull);
    });

    test('one entity failing does not stop the others', () async {
      final h = await _buildHarness();
      when(
        () => h.functions.invoke(any(), body: any(named: 'body')),
      ).thenThrow(Exception('edge function unreachable'));

      final liveActivity = {'id': 'activity-live', 'deleted_at': null};
      final event = {'id': 'event-1'};

      _stubEmptyFallbackTables(h);
      // foods download blows up…
      when(
        () => h.supabase.from('foods'),
      ).thenAnswer((_) => _ThrowingQueryBuilder());
      // …but activities/events still come through.
      when(
        () => h.supabase.from('activities'),
      ).thenAnswer((_) => _FakeQueryBuilder([liveActivity]));
      when(
        () => h.supabase.from('events'),
      ).thenAnswer((_) => _FakeQueryBuilder([event]));

      final result = await h.service.syncAllData(userId);

      expect(result, isTrue);
      verifyNever(
        () =>
            h.foodRepository.syncFromDownloadedData(foods: any(named: 'foods')),
      );
      verify(() => h.activityHandler.upsertActivity(liveActivity)).called(1);
      verify(() => h.eventHandler.upsertEvent(event, userId)).called(1);
      expect(
        h.logger.records.any(
          (r) => r.level == 'error' && r.context == 'FOOD_SYNC',
        ),
        isTrue,
        reason: 'the swallowed per-entity failure must at least be logged',
      );
    });

    test(
      'DOCUMENTED HAZARD: every entity download failing still returns true '
      'and stamps last_sync_timestamp (silent-failure trap of the fallback)',
      () async {
        final h = await _buildHarness();
        when(
          () => h.functions.invoke(any(), body: any(named: 'body')),
        ).thenThrow(Exception('edge function unreachable'));
        for (final table in [
          'foods',
          'carb_loading_foods',
          'activities',
          'events',
          'carb_loading_plans',
          'carb_loading_days',
        ]) {
          when(
            () => h.supabase.from(table),
          ).thenAnswer((_) => _ThrowingQueryBuilder());
        }

        final result = await h.service.syncAllData(userId);

        // Every per-entity catch in _download* swallows its error, so
        // _clientSideDownload "succeeds", the timestamp is stamped, and the
        // caller is told the sync worked. If this test starts failing because
        // result is false / the timestamp is absent, the hazard was fixed —
        // invert these expectations rather than deleting the test.
        expect(result, isTrue);
        expect(h.prefs.getString(tsKey), isNotNull);
        expect(
          h.logger.records.where((r) => r.level == 'error').length,
          greaterThanOrEqualTo(5),
          reason: 'each entity failure is logged even though all are swallowed',
        );
      },
    );
  });

  group('DataSyncService.needsFullSync', () {
    test('returns true on a fresh device (no local user profile)', () async {
      final h = await _buildHarness();
      expect(await h.service.needsFullSync(userId), isTrue);
    });

    test('returns true when profile exists but no sync timestamp', () async {
      final h = await _buildHarness();
      await h.db
          .into(h.db.userProfilesTable)
          .insert(
            UserProfilesTableCompanion.insert(id: userId, deviceId: 'dev-1'),
          );
      expect(await h.service.needsFullSync(userId), isTrue);
    });

    test('returns true when the last sync is older than 30 days', () async {
      final h = await _buildHarness();
      await h.db
          .into(h.db.userProfilesTable)
          .insert(
            UserProfilesTableCompanion.insert(id: userId, deviceId: 'dev-1'),
          );
      await h.prefs.setString(
        tsKey,
        DateTime.now().subtract(const Duration(days: 31)).toIso8601String(),
      );
      expect(await h.service.needsFullSync(userId), isTrue);
    });

    test('returns true when the stored timestamp is unparseable', () async {
      final h = await _buildHarness();
      await h.db
          .into(h.db.userProfilesTable)
          .insert(
            UserProfilesTableCompanion.insert(id: userId, deviceId: 'dev-1'),
          );
      await h.prefs.setString(tsKey, 'not-a-date');
      expect(await h.service.needsFullSync(userId), isTrue);
    });

    test('returns false when profile exists and sync is recent', () async {
      final h = await _buildHarness();
      await h.db
          .into(h.db.userProfilesTable)
          .insert(
            UserProfilesTableCompanion.insert(id: userId, deviceId: 'dev-1'),
          );
      await h.prefs.setString(
        tsKey,
        DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
      );
      expect(await h.service.needsFullSync(userId), isFalse);
    });
  });

  group('DataSyncService — thin delegation methods', () {
    test(
      'syncCoachMessagesForActivity delegates to the coach handler',
      () async {
        final h = await _buildHarness();
        await h.service.syncCoachMessagesForActivity('activity-9');
        verify(
          () => h.coachHandler.syncCoachMessagesForActivity('activity-9'),
        ).called(1);
      },
    );

    test('syncAthleteData delegates to the coach handler', () async {
      final h = await _buildHarness();
      await h.service.syncAthleteData('athlete-9');
      verify(() => h.coachHandler.syncAthleteData('athlete-9')).called(1);
    });

    test('syncUsers delegates to the user handler', () async {
      final h = await _buildHarness();
      await h.service.syncUsers(userId);
      verify(() => h.userHandler.syncUsers(userId)).called(1);
    });
  });
}
