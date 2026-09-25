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

class _MockPrefs extends Mock implements SharedPreferences {}

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

void main() {
  late AppDatabase db;
  late StreamController<AuthState> authStates;
  late ProviderContainer container;
  late _MockLogger logger;

  setUp(() async {
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
            sharedPreferences: _MockPrefs(),
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
