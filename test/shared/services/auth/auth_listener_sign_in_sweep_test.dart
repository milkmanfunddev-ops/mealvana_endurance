/// Seam test through the real sign-in path (`AuthListenerService` on a real
/// auth-state stream and a real in-memory Drift database), ticket 102 /
/// Finding 86-001: signing in sweeps every other account on the phone by the
/// sign-out rule. Their server-held rows go, their unsynced rows stay, and
/// when that account signs in again the real repository's dirty-record
/// upload sends what stayed.
library;

import 'dart:async';

import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mealvana_endurance/features/meal_planning/data/user_memory_repository.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/database/database_provider.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/auth/auth_listener_service.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';

import '../../../helpers/fakes/fake_supabase_client.dart';

class _MockAnalytics extends Mock implements AnalyticsTracker {}

class _MockLogger extends Mock implements AppLogger {}

class _MockRemote extends Mock implements UserMemoryRemote {}

class _FakeUser extends Fake implements User {
  _FakeUser(this.id);
  @override
  final String id;
}

class _FakeSession extends Fake implements Session {
  _FakeSession(this.user);
  @override
  final User user;
}

const _a = 'aaaaaaaa-0000-4000-8000-000000000001';
const _b = 'bbbbbbbb-0000-4000-8000-000000000002';
const _c = 'cccccccc-0000-4000-8000-000000000003';

void main() {
  late AppDatabase db;
  late StreamController<AuthState> authStates;
  late ProviderContainer container;
  late _MockLogger logger;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.memory();
    addTearDown(db.close);
    authStates = StreamController<AuthState>.broadcast();
    addTearDown(authStates.close);

    final auth = MockGoTrueClient();
    when(() => auth.currentUser).thenReturn(null);
    when(() => auth.currentSession).thenReturn(null);
    when(() => auth.onAuthStateChange).thenAnswer((_) => authStates.stream);

    final analytics = _MockAnalytics();
    when(
      () => analytics.track(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    logger = _MockLogger();

    container = ProviderContainer(
      overrides: [
        appExternalDepsProvider.overrideWithValue(
          AppExternalDeps(
            analytics: analytics,
            supabaseClient: fakeSupabaseClient(auth: auth),
            sentry: const NoopSentryReporter(),
            logger: logger,
            sharedPreferences: prefs,
          ),
        ),
        appDatabaseProvider.overrideWithValue(db),
      ],
    );
    addTearDown(container.dispose);

    await _seed(db, _a);
    await _seed(db, _b);
    container.read(authListenerServiceProvider).initialize();
  });

  Future<void> emit(AuthChangeEvent event, String userId) async {
    authStates.add(AuthState(event, _FakeSession(_FakeUser(userId))));
    // Let the listener's async handler run to completion.
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  test(
    "signing in sweeps the other account's synced rows and keeps its unsynced "
    'ones; the signed-in account is untouched',
    () async {
      await emit(AuthChangeEvent.signedIn, _b);

      // A's synced rows are gone; its offline ones stay, with its profile.
      expect(await _count(db, 'activities', _a), 0);
      expect(await _count(db, 'user_memories', _a, 'AND needs_upload = 0'), 0);
      expect(await _count(db, 'user_memories', _a, 'AND needs_upload = 1'), 1);
      expect(await _countUsers(db, _a), 1);
      // B keeps everything.
      expect(await _count(db, 'activities', _b), 1);
      expect(await _count(db, 'user_memories', _b), 2);
      expect(await _countUsers(db, _b), 1);
      verifyNever(
        () => logger.error(
          any(),
          context: any(named: 'context'),
          error: any(named: 'error'),
          stackTrace: any(named: 'stackTrace'),
          data: any(named: 'data'),
        ),
      );
    },
  );

  test('a restored session sweeps too', () async {
    await emit(AuthChangeEvent.initialSession, _b);

    expect(await _count(db, 'activities', _a), 0);
    expect(await _count(db, 'user_memories', _a, 'AND needs_upload = 1'), 1);
    expect(await _count(db, 'activities', _b), 1);
  });

  test(
    "when the swept account signs in again, its unsynced row is what the real "
    'repository uploads',
    () async {
      await emit(AuthChangeEvent.signedIn, _b);
      await emit(AuthChangeEvent.signedIn, _a);

      final remote = _MockRemote();
      when(() => remote.upsertMemories(any())).thenAnswer((_) async {});
      final repo = UserMemoryRepository(
        database: db,
        logger: logger,
        remote: remote,
      );

      final result = await repo.uploadDirtyRecords(_a);

      expect(result.success, isTrue);
      expect(result.count, 1);
      final uploaded =
          verify(() => remote.upsertMemories(captureAny())).captured.single
              as List<Map<String, dynamic>>;
      expect(uploaded.single['id'], 'memory-offline-$_a');
      expect(uploaded.single['user_id'], _a);
      expect(await _count(db, 'user_memories', _a, 'AND needs_upload = 1'), 0);
      // The second sign-in swept B's synced rows and kept its offline one.
      expect(await _count(db, 'activities', _b), 0);
      expect(await _count(db, 'user_memories', _b, 'AND needs_upload = 1'), 1);
    },
  );
  group('coach mode (wave 27 review)', () {
    test("a coach's phone keeps its cached athlete and their shared rows; an "
        'unrelated account still goes', () async {
      // Coach B's phone caches athlete C's profile the way
      // syncAthleteProfilesFromSupabase writes it: device id = user id,
      // no auth id.
      await _seedAthleteProfile(db, _c);
      await _seedCoachRow(db, _b);
      await _seedCoachLinks(db, coach: _b, athlete: _c);

      await emit(AuthChangeEvent.signedIn, _b);

      expect(await _countUsers(db, _c), 1);
      expect(await _countWhere(db, 'coach_athlete_relationships'), 1);
      expect(await _countWhere(db, 'coach_messages'), 1);
      expect(await _countWhere(db, 'coach_pairing_codes'), 1);
      expect(await _countWhere(db, 'coaches'), 1);
      // A, who has no link to B, is swept as before.
      expect(await _count(db, 'activities', _a), 0);
    });

    test("an athlete's phone keeps its coach's cached profile and their shared "
        'rows', () async {
      await _seedAthleteProfile(db, _c);
      await _seedCoachRow(db, _c);
      await _seedCoachLinks(db, coach: _c, athlete: _b);

      await emit(AuthChangeEvent.initialSession, _b);

      expect(await _countUsers(db, _c), 1);
      expect(await _countWhere(db, 'coaches'), 1);
      expect(await _countWhere(db, 'coach_athlete_relationships'), 1);
      expect(await _countWhere(db, 'coach_messages'), 1);
      expect(await _countWhere(db, 'coach_pairing_codes'), 1);
    });

    test('coach-mode rows between two other accounts still go', () async {
      await _seedAthleteProfile(db, _c);
      await _seedCoachRow(db, _c);
      await _seedCoachLinks(db, coach: _c, athlete: _a);

      await emit(AuthChangeEvent.signedIn, _b);

      expect(await _countWhere(db, 'coach_athlete_relationships'), 0);
      expect(await _countWhere(db, 'coach_messages'), 0);
      expect(await _countWhere(db, 'coach_pairing_codes'), 0);
      expect(await _countWhere(db, 'coaches'), 0);
      expect(await _countUsers(db, _c), 0);
    });
  });

  group('food preferences (wave 27 review)', () {
    test("another account's unsent food-preference edits stay when its upload "
        'marker is set, with its profile', () async {
      // A edited only food preferences offline and signed out: the upload
      // failed, so the marker is set and nothing carries needs_upload.
      await db.customStatement(
        'UPDATE user_memories SET needs_upload = 0 WHERE user_id = ?',
        [_a],
      );
      await _seedFoodPreference(db, _a);
      await prefs.setBool('food_preferences_upload_pending_$_a', true);

      await emit(AuthChangeEvent.signedIn, _b);

      expect(await _count(db, 'food_preferences_table', _a), 1);
      expect(await _countUsers(db, _a), 1);
      expect(await _count(db, 'activities', _a), 0);
    });

    test('without the marker and with nothing unsynced they go', () async {
      await db.customStatement(
        'UPDATE user_memories SET needs_upload = 0 WHERE user_id = ?',
        [_a],
      );
      await _seedFoodPreference(db, _a);

      await emit(AuthChangeEvent.signedIn, _b);

      expect(await _count(db, 'food_preferences_table', _a), 0);
      expect(await _countUsers(db, _a), 0);
    });
  });

  test(
    'onboarding rows under the temp id waiting to be re-keyed are not swept',
    () async {
      const temp = 'dddddddd-0000-4000-8000-000000000004';
      await prefs.setString('onboarding_temp_user_id', temp);
      await _seed(db, temp);

      await emit(AuthChangeEvent.signedIn, _b);

      expect(await _count(db, 'activities', temp), 1);
      expect(await _count(db, 'user_memories', temp), 2);
      expect(await _countUsers(db, temp), 1);
      // Others still go.
      expect(await _count(db, 'activities', _a), 0);
    },
  );
}

/// A profile as the coach repository caches one for display.
Future<void> _seedAthleteProfile(AppDatabase db, String userId) async {
  await db
      .into(db.userProfilesTable)
      .insert(
        UserProfilesTableCompanion.insert(
          id: userId,
          deviceId: userId,
          firstName: const Value('Cached'),
        ),
      );
}

Future<void> _seedCoachRow(AppDatabase db, String userId) async {
  await db
      .into(db.coachesTable)
      .insert(
        CoachesTableCompanion.insert(
          id: 'coach-row-$userId',
          userId: userId,
          firstName: 'Kim',
          lastName: 'Coach',
          email: 'coach@example.com',
        ),
      );
}

Future<void> _seedCoachLinks(
  AppDatabase db, {
  required String coach,
  required String athlete,
}) async {
  await db
      .into(db.coachAthleteRelationshipsTable)
      .insert(
        CoachAthleteRelationshipsTableCompanion.insert(
          id: 'rel-$coach-$athlete',
          coachUserId: coach,
          athleteUserId: athlete,
          requestedBy: 'coach',
          status: const Value('active'),
        ),
      );
  await db
      .into(db.coachMessagesTable)
      .insert(
        CoachMessagesTableCompanion.insert(
          id: 'msg-$coach-$athlete',
          coachUserId: coach,
          athleteUserId: athlete,
          senderUserId: athlete,
          messageText: 'Long run done',
        ),
      );
  await db
      .into(db.coachPairingCodesTable)
      .insert(
        CoachPairingCodesTableCompanion.insert(
          id: 'code-$coach-$athlete',
          coachUserId: coach,
          code: 'ABC123',
          expiresAt: DateTime.utc(2026, 10, 1),
          usedByAthleteId: Value(athlete),
        ),
      );
}

Future<void> _seedFoodPreference(AppDatabase db, String userId) async {
  await db
      .into(db.foodPreferencesTable)
      .insert(
        FoodPreferencesTableCompanion.insert(
          id: 'f${userId.substring(1)}',
          userId: userId,
          foodName: 'cilantro',
          preference: 'dislike',
        ),
      );
}

Future<int> _countWhere(AppDatabase db, String table) async {
  final rows = await db.customSelect('SELECT COUNT(*) AS n FROM $table').get();
  return rows.single.read<int>('n');
}

/// One account: a profile, a synced activity, a synced memory and a memory
/// written offline (`needs_upload = 1`).
Future<void> _seed(AppDatabase db, String userId) async {
  final now = DateTime.utc(2026, 9, 25, 12);
  await db
      .into(db.userProfilesTable)
      .insert(
        UserProfilesTableCompanion.insert(
          id: userId,
          deviceId: 'device-$userId',
          authUserId: Value(userId),
        ),
      );
  await db
      .into(db.activitiesTable)
      .insert(
        ActivitiesTableCompanion.insert(
          userId: userId,
          activityType: 'running',
          title: 'Easy run',
          scheduledDateTime: now,
          createdAt: now,
          updatedAt: now,
          needsUpload: const Value(false),
        ),
      );
  for (final offline in [false, true]) {
    await db
        .into(db.userMemoriesTable)
        .insert(
          UserMemoriesTableCompanion.insert(
            id: Value(offline ? 'memory-offline-$userId' : 'memory-$userId'),
            userId: userId,
            kind: 'preference',
            fact: offline ? 'Likes oats' : 'Likes rice',
            createdAt: now,
            lastConfirmedAt: now,
            needsUpload: Value(offline),
          ),
        );
  }
}

Future<int> _count(
  AppDatabase db,
  String table,
  String userId, [
  String where = '',
]) async {
  final rows = await db
      .customSelect(
        'SELECT COUNT(*) AS n FROM $table WHERE user_id = ? $where',
        variables: [Variable<String>(userId)],
      )
      .get();
  return rows.single.read<int>('n');
}

Future<int> _countUsers(AppDatabase db, String userId) async {
  final rows = await db
      .customSelect(
        'SELECT COUNT(*) AS n FROM users WHERE id = ? OR auth_user_id = ?',
        variables: [Variable<String>(userId), Variable<String>(userId)],
      )
      .get();
  return rows.single.read<int>('n');
}
