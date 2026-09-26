// Ticket 138 (Findings 119-001, 116-002, 125-004): a profile save or an
// allergy change that did not reach the server is uploaded at the next
// online moment instead of waiting out the 1-hour `users` staleness window,
// and the notification answer is written to `users.notifications_enabled`.
//
// Seam test (docs/test/README.md): the writes run through the real
// [AuthService.updateAllergies] path's repository call and the real
// [UserRepository] on in-memory Drift, the retry through the real
// [SyncCoordinator], and the wire is the real postgrest builder against an
// in-memory PostgREST ([FakePostgrest]) that records every write and can
// refuse them the way an unreachable server does.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/onboarding/domain/allergy.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/providers/user_id_provider.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/connectivity_checker.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:mealvana_endurance/shared/services/sync/sync_coordinator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes/fake_postgrest.dart';
import '../../helpers/fakes/recording_analytics_tracker.dart';

const _user = '3d1d1a0e-8a5b-4d1e-9d21-4f6b1a2c3d4e';

class _MockPrefs extends Mock implements SharedPreferences {}

class _StubConnectivity extends ConnectivityChecker {
  final changes = StreamController<bool>.broadcast();

  @override
  Future<bool> isOnline() async => true;

  @override
  Stream<bool> get onlineChanges => changes.stream;
}

UserProfile _profile() => UserProfile(
  id: _user,
  deviceId: 'device-138',
  authUserId: _user,
  authProvider: 'email',
  isAnonymous: false,
  gender: Gender.female,
  birthday: DateTime(1992, 5, 5),
  heightFeet: 5,
  heightInches: 6,
  weightPounds: 140,
  runsWithWaterBottle: true,
  onboardingCompleted: true,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 9, 1),
  appVersion: '1.0.0',
);

/// The immediate upload and the owed retry are fire-and-forget; let them run.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakePostgrest server;
  late UserRepository repo;
  late _StubConnectivity network;
  late ProviderContainer container;

  setUp(() async {
    // The table was pulled a moment ago: fresh, so a plain ensureSynced
    // would skip `users` for the next hour.
    SharedPreferences.setMockInitialValues({
      'users_last_sync': DateTime.now().toIso8601String(),
    });
    db = AppDatabase.memory();
    server = FakePostgrest();
    network = _StubConnectivity();
    await db.userDao.saveUserProfile(_profile());

    container = ProviderContainer(
      overrides: [
        // The same wiring the real provider does.
        userRepositoryProvider.overrideWith((ref) async {
          final sync = ref.read(syncCoordinatorProvider.notifier);
          return repo = UserRepository(
            database: db,
            supabase: server.client,
            sentry: const NoopSentryReporter(),
            onUploadOwed: () {
              sync.markUploadRetryOwed('users');
              unawaited(sync.retryOwedUploads());
            },
          );
        }),
        userIdProvider.overrideWith((_) async => _user),
        connectivityCheckerProvider.overrideWithValue(network),
        appExternalDepsProvider.overrideWithValue(
          AppExternalDeps(
            analytics: RecordingAnalyticsTracker(),
            supabaseClient: server.client,
            sentry: const NoopSentryReporter(),
            logger: const NoopAppLogger(),
            sharedPreferences: _MockPrefs(),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(userRepositoryProvider.future);
  });

  tearDown(() async {
    await _settle();
    await network.changes.close();
    await db.close();
  });

  SyncCoordinator sync() => container.read(syncCoordinatorProvider.notifier);

  Future<UserProfileEntry> theRow() async =>
      (await db.select(db.userProfilesTable).get()).single;

  List<Map<String, dynamic>> userWrites() => server.writes
      .where((w) => w.table == 'users')
      .map((w) => (w.body is List ? (w.body as List).single : w.body) as Map)
      .map((m) => m.cast<String, dynamic>())
      .toList();

  test('an allergy save while offline is uploaded once the network is back',
      () async {
    server.rejectWrites.add('users');

    // AuthService.updateAllergies: local first, marked for background upload.
    await repo.updateUserProfile(
      _profile().copyWith(allergies: [Allergy.peanuts]),
      needsUpload: true,
    );
    await _settle();

    expect((await theRow()).needsUpload, isTrue);
    expect(sync().uploadRetryOwedForTesting, contains('users'));
    expect(
      userWrites(),
      isNotEmpty,
      reason: 'the upload was tried right away and refused',
    );
    final refusedAttempts = userWrites().length;

    // Still offline: another ensureSynced fails and keeps the retry owed
    // (UploadResult.failed is read, not swallowed).
    await sync().ensureSynced('users', _user, repository: repo);
    expect((await theRow()).needsUpload, isTrue);
    expect(sync().uploadRetryOwedForTesting, contains('users'));

    // The network comes back.
    server.rejectWrites.clear();
    network.changes.add(true);
    await _settle();

    expect(userWrites().length, greaterThan(refusedAttempts));
    expect(userWrites().last['allergies'], ['peanuts']);
    expect((await theRow()).needsUpload, isFalse);
    expect(sync().uploadRetryOwedForTesting, isNot(contains('users')));
  });

  test('a save marked for background upload goes out right away when online',
      () async {
    await repo.updateUserProfile(
      _profile().copyWith(firstName: 'Ada'),
      needsUpload: true,
    );
    await _settle();

    expect(userWrites().last['first_name'], 'Ada');
    expect((await theRow()).needsUpload, isFalse);
    expect(sync().uploadRetryOwedForTesting, isEmpty);
  });

  test('a write-through that fails is owed a retry and lands later',
      () async {
    server.rejectWrites.add('users');
    await repo.updateUserProfile(_profile().copyWith(lastName: 'Lovelace'));
    await _settle();
    expect((await theRow()).needsUpload, isTrue);
    expect(sync().uploadRetryOwedForTesting, contains('users'));

    server.rejectWrites.clear();
    network.changes.add(true);
    await _settle();

    expect(userWrites().last['last_name'], 'Lovelace');
    expect((await theRow()).needsUpload, isFalse);
  });

  test('the notification answer is written to users.notifications_enabled',
      () async {
    await repo.setNotificationsEnabled(_user, true);
    await _settle();

    expect((await theRow()).notificationsEnabled, isTrue);
    expect(userWrites().last['notifications_enabled'], isTrue);

    // The same answer again writes nothing new.
    final before = userWrites().length;
    await repo.setNotificationsEnabled(_user, true);
    await _settle();
    expect(userWrites().length, before);

    // Turned off in iOS Settings, seen on resume.
    await repo.setNotificationsEnabled(_user, false);
    await _settle();
    expect((await theRow()).notificationsEnabled, isFalse);
    expect(userWrites().last['notifications_enabled'], isFalse);
  });
}
