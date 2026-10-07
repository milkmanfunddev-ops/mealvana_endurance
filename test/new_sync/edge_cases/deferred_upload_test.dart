// DEV-A2 (round-up 2026-10), coordinator half. A repository that DEFERS its
// upload (rows that belong to a user other than the session; ticket 16's
// integrations guard and the users guard) has already left a promoted sync
// Note. SyncCoordinator used to turn the deferral into
// `StateError('Upload failed for users: deferred: …')` and report it as a
// Fault, so the guard traded one Fault group for another. A deferral is not a
// failure: no Fault, no download for a user the session cannot read, no
// failure cooldown, and no "synced" stamp, so the next call tries again.
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/data/syncable_repository.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';
import 'package:mealvana_endurance/shared/services/sync/sync_coordinator.dart';
import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes/recording_report.dart';

class _DeferringRepository with SyncableRepository {
  @override
  String get repositoryKey => 'users';

  bool defer = true;
  int uploads = 0;
  int downloads = 0;

  @override
  Future<UploadResult> uploadDirtyRecords(String userId) async {
    uploads++;
    return defer
        ? UploadResult.deferred('1 users row awaits its own session')
        : UploadResult.successful(1);
  }

  @override
  Future<SyncResult> syncFromRemote(String userId) async {
    downloads++;
    return SyncResult.successful(0);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a deferred upload is not a Fault, downloads nothing, and leaves the '
      'repository stale so the next call retries', () async {
    final report = RecordingReport();
    final container = ProviderContainer(
      overrides: [reportProvider.overrideWithValue(report)],
    );
    addTearDown(container.dispose);
    final coordinator = container.read(syncCoordinatorProvider.notifier);
    final repo = _DeferringRepository();

    await coordinator.ensureSynced('users', 'user-a2', repository: repo);

    expect(report.faults, isEmpty, reason: 'a deferral is not a failure');
    expect(repo.uploads, 1);
    expect(repo.downloads, 0, reason: 'nothing to read for that user');
    expect(await repo.getLastSyncTime(), isNull, reason: 'not stamped fresh');

    // The owner's session is back: the very next call (no cooldown) uploads,
    // downloads and stamps.
    repo.defer = false;
    await coordinator.ensureSynced('users', 'user-a2', repository: repo);
    expect(repo.uploads, 2);
    expect(repo.downloads, 1);
    expect(report.faults, isEmpty);
  });

  test('only a real failure reads as failed: a deferral and a success do '
      'not', () {
    // Every caller that checks an upload result (CLAUDE.md: always check it)
    // asks one question, so a deferral can never be mistaken for a failure
    // in a path the coordinator test above does not cover (force sync,
    // upload-all, pre-logout, version-check backup).
    expect(UploadResult.deferred('awaits its session').failed, isFalse);
    expect(UploadResult.failed('boom').failed, isTrue);
    expect(UploadResult.successful(1).failed, isFalse);
    expect(UploadResult.nothingToUpload().failed, isFalse);
  });

  test('a real upload failure is still a Fault', () async {
    final report = RecordingReport();
    final container = ProviderContainer(
      overrides: [reportProvider.overrideWithValue(report)],
    );
    addTearDown(container.dispose);
    final coordinator = container.read(syncCoordinatorProvider.notifier);

    final failing = _FailingRepository();
    await coordinator.ensureSynced('users', 'user-a2', repository: failing);

    expect(report.faults.single.error.toString(), contains('Upload failed'));
  });
}

class _FailingRepository with SyncableRepository {
  @override
  String get repositoryKey => 'users';

  @override
  Future<UploadResult> uploadDirtyRecords(String userId) async =>
      UploadResult.failed('PostgrestException(code: 23505)');

  @override
  Future<SyncResult> syncFromRemote(String userId) async =>
      SyncResult.successful(0);
}
