// Ticket 103 (testing-wave; Finding 86-012): a rejected upload no longer
// stops the repository from pulling.
//
// `ensureSynced` threw when `uploadDirtyRecords` failed, before the pull, so
// one row the server rejects every time stopped that repository, and every
// repository depending on it, from ever downloading. Now the failure is
// logged and rate-limited, the rows stay dirty, and the pull still runs.
//
// The repositories fail the way the real ones do: `uploadDirtyRecords`
// swallows the PostgREST error into `UploadResult.failed()` (never throws),
// and `syncFromRemote` upserts the server's rows while keeping the ids that
// are still `needs_upload`.

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/data/activities_repository.dart';
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/shared/data/syncable_repository.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';
import 'package:mealvana_endurance/shared/services/sync/sync_coordinator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes/recording_report.dart';

const _user = '607f9dd5-6fa7-48ee-a628-720d4a0506a1';

/// The PostgREST error a row refused by RLS comes back with, as the real
/// repositories pass it into `UploadResult.failed()`.
const _rlsError =
    'PostgrestException(message: new row violates row-level security policy '
    'for table "meal_logs", code: 42501, details: Forbidden, hint: null)';

/// A local table of `id -> (name, needsUpload)` behind a repository whose
/// server refuses every upload (or accepts them once [serverAccepts] is set).
class _LocalTableRepository with SyncableRepository {
  _LocalTableRepository(this.repositoryKey, {required this.serverRows});

  @override
  final String repositoryKey;

  /// What the server answers the pull with.
  final Map<String, String> serverRows;

  final Map<String, ({String name, bool needsUpload})> local = {};

  bool serverAccepts = false;
  int uploadCalls = 0;
  int pullCalls = 0;

  @override
  Future<UploadResult> uploadDirtyRecords(String userId) async {
    uploadCalls++;
    final dirty = local.entries.where((e) => e.value.needsUpload).toList();
    if (dirty.isEmpty) return UploadResult.nothingToUpload();
    if (!serverAccepts) return UploadResult.failed(_rlsError);
    for (final e in dirty) {
      serverRows[e.key] = e.value.name;
      local[e.key] = (name: e.value.name, needsUpload: false);
    }
    return UploadResult.successful(dirty.length);
  }

  @override
  Future<SyncResult> syncFromRemote(String userId) async {
    pullCalls++;
    for (final row in serverRows.entries) {
      if (local[row.key]?.needsUpload ?? false) continue;
      local[row.key] = (name: row.value, needsUpload: false);
    }
    await setLastSyncTime(DateTime.now());
    return SyncResult.successful(serverRows.length);
  }
}

class _MockUserRepository extends Mock implements UserRepository {}

class _MockActivitiesRepository extends Mock implements ActivitiesRepository {}

void main() {
  late RecordingReport logger;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    logger = RecordingReport();
  });

  ProviderContainer containerWith([List overrides = const []]) {
    // Every repository here depends on `users`, synced at sign-in.
    final freshUsers = _MockUserRepository();
    when(() => freshUsers.isStale()).thenAnswer((_) async => false);
    final container = ProviderContainer(
      overrides: [
        reportProvider.overrideWithValue(logger),
        if (overrides.isEmpty)
          userRepositoryProvider.overrideWith((_) async => freshUsers),
        ...overrides.cast(),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  _LocalTableRepository repoWithRejectedRow() {
    final repo = _LocalTableRepository(
      'meal_logs',
      serverRows: {'log-from-other-phone': 'Rice cake and Almond butter'},
    );
    repo.local['rejected-log'] = (name: 'Oats', needsUpload: true);
    return repo;
  }

  group('ensureSynced after a failed upload', () {
    test(
      'still pulls, keeps the row dirty and logs the repo and error',
      () async {
        final coordinator = containerWith().read(
          syncCoordinatorProvider.notifier,
        );
        final repo = repoWithRejectedRow();

        await coordinator.ensureSynced('meal_logs', _user, repository: repo);

        expect(repo.uploadCalls, 1);
        expect(
          repo.pullCalls,
          1,
          reason: 'the pull runs after a failed upload',
        );
        expect(
          repo.local['log-from-other-phone'],
          (name: 'Rice cake and Almond butter', needsUpload: false),
          reason: 'the other phone\'s row arrived',
        );
        expect(repo.local['rejected-log'], (name: 'Oats', needsUpload: true));

        final uploadErrors = logger.faults.where(
          (e) => e.extra?['repoKey'] == 'meal_logs',
        );
        expect(uploadErrors, hasLength(1));
        expect(uploadErrors.single.extra?['error'], contains('42501'));
      },
    );

    test(
      'keeps the rate limit: no second upload inside the cooldown',
      () async {
        final coordinator = containerWith().read(
          syncCoordinatorProvider.notifier,
        );
        final repo = repoWithRejectedRow();

        await coordinator.ensureSynced('meal_logs', _user, repository: repo);
        await coordinator.ensureSynced('meal_logs', _user, repository: repo);

        expect(repo.uploadCalls, 1);
        expect(repo.pullCalls, 1);
      },
    );

    test('retries the upload after the cooldown although the pull made the '
        'repository fresh, and clears the failure once it lands', () async {
      final coordinator = containerWith().read(
        syncCoordinatorProvider.notifier,
      );
      var clock = DateTime(2026, 9, 25, 12);
      coordinator.now = () => clock;
      final repo = repoWithRejectedRow();

      await coordinator.ensureSynced('meal_logs', _user, repository: repo);
      expect(await repo.isStale(), isFalse, reason: 'the pull stamped it');

      clock = clock.add(const Duration(minutes: 3));
      repo.serverAccepts = true;
      await coordinator.ensureSynced('meal_logs', _user, repository: repo);

      expect(repo.uploadCalls, 2);
      expect(repo.local['rejected-log'], (name: 'Oats', needsUpload: false));

      // Uploaded and fresh: the next call is a no-op again.
      clock = clock.add(const Duration(minutes: 3));
      await coordinator.ensureSynced('meal_logs', _user, repository: repo);
      expect(repo.uploadCalls, 2);
    });

    test('offline, the pull fails as before and the failure is kept', () async {
      final coordinator = containerWith().read(
        syncCoordinatorProvider.notifier,
      );
      final repo = _OfflineRepository();

      await coordinator.ensureSynced('meal_logs', _user, repository: repo);

      expect(repo.uploadCalls, 1);
      expect(repo.pullCalls, 1);
      expect(await repo.getLastSyncTime(), isNull, reason: 'nothing pulled');
      // Still rate-limited.
      await coordinator.ensureSynced('meal_logs', _user, repository: repo);
      expect(repo.uploadCalls, 1);
    });
  });

  group('a dependency whose upload fails', () {
    test('does not stop the dependent repository\'s pull', () async {
      // events depends on users and activities. activities holds a row the
      // server rejects.
      final users = _MockUserRepository();
      when(() => users.isStale()).thenAnswer((_) async => false);
      final activities = _MockActivitiesRepository();
      when(() => activities.isStale()).thenAnswer((_) async => true);
      when(
        () => activities.uploadDirtyRecords(_user),
      ).thenAnswer((_) async => UploadResult.failed(_rlsError));
      when(
        () => activities.syncFromRemote(_user),
      ).thenAnswer((_) async => SyncResult.successful(1));

      final coordinator = containerWith([
        userRepositoryProvider.overrideWith((_) async => users),
        activitiesRepositoryProvider.overrideWithValue(activities),
      ]).read(syncCoordinatorProvider.notifier);

      final events = _LocalTableRepository(
        'events',
        serverRows: {'evt-chicago': 'Chicago Marathon'},
      );

      await coordinator.ensureSynced('events', _user, repository: events);

      verify(() => activities.uploadDirtyRecords(_user)).called(1);
      verify(() => activities.syncFromRemote(_user)).called(1);
      expect(events.pullCalls, 1);
      expect(events.local['evt-chicago'], (
        name: 'Chicago Marathon',
        needsUpload: false,
      ));
      expect(
        logger.faults.where((e) => e.extra?['repoKey'] == 'activities'),
        hasLength(1),
      );
    });
  });
}

/// No network: the upload swallows the socket error, the pull throws it.
class _OfflineRepository with SyncableRepository {
  int uploadCalls = 0;
  int pullCalls = 0;

  @override
  String get repositoryKey => 'meal_logs';

  @override
  Future<UploadResult> uploadDirtyRecords(String userId) async {
    uploadCalls++;
    return UploadResult.failed(
      'ClientException with SocketException: Failed host lookup',
    );
  }

  @override
  Future<SyncResult> syncFromRemote(String userId) async {
    pullCalls++;
    throw Exception('ClientException with SocketException: Failed host lookup');
  }
}
