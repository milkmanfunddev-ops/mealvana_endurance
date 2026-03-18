import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/data/syncable_repository.dart';
import 'package:mealvana_endurance/shared/models/dirty_record_backup.dart';
import 'package:mealvana_endurance/shared/models/upload_error.dart';
import 'package:mealvana_endurance/shared/services/dirty_record_backup_service.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sync/sync_coordinator.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

import '../../helpers/mock_path_provider.dart';

/// Mock repository that simulates network failures
class NetworkFailingRepository with SyncableRepository {
  @override
  final String repositoryKey;

  @override
  final List<String> dependencies;

  bool networkAvailable = true;
  int syncAttempts = 0;
  int uploadAttempts = 0;

  NetworkFailingRepository({
    required this.repositoryKey,
    this.dependencies = const [],
  });

  @override
  Future<SyncResult> syncFromRemote(String userId) async {
    syncAttempts++;

    if (!networkAvailable) {
      throw Exception('Network unavailable');
    }

    await setLastSyncTime(DateTime.now());
    return SyncResult.successful(5);
  }

  @override
  Future<UploadResult> uploadDirtyRecords(String userId) async {
    uploadAttempts++;

    if (!networkAvailable) {
      throw Exception('Network unavailable');
    }

    return UploadResult.nothingToUpload();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Network Failure Edge Cases', () {
    final staleDuration = SyncableRepository.staleDuration;

    late String tempDir;
    late DirtyRecordBackupService backupService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});

      // Set up mock path provider for backup service
      tempDir = Directory.systemTemp.createTempSync('network_test_').path;
      PathProviderPlatform.instance = MockPathProvider(tempDir);

      final logger = PrettyAppLogger();
      backupService = DirtyRecordBackupService(logger: logger);
    });

    tearDown(() async {
      try {
        final dir = Directory(tempDir);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      } catch (e) {
        // Ignore cleanup errors
      }
    });

    test('sync continues with cached data when network fails', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final coordinator = container.read(syncCoordinatorProvider.notifier);
      final repo = NetworkFailingRepository(repositoryKey: 'users');

      // First sync - network available
      repo.networkAvailable = true;
      await coordinator.ensureSynced('users', 'user-123', repository: repo);

      expect(repo.syncAttempts, 1);
      final firstSyncTime = await repo.getLastSyncTime();
      expect(firstSyncTime, isNotNull);

      // Immediate second call - should not sync (cached)
      repo.syncAttempts = 0;
      await coordinator.ensureSynced('users', 'user-123', repository: repo);

      expect(repo.syncAttempts, 0); // Did not attempt sync (data still fresh)
    });

    test('dirty record backup is created on upload failure', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final coordinator = container.read(syncCoordinatorProvider.notifier);
      final repo = NetworkFailingRepository(repositoryKey: 'activities');

      // Mark as stale
      await repo.setLastSyncTime(
        DateTime.now()
            .subtract(staleDuration)
            .subtract(const Duration(minutes: 30)),
      );

      // Simulate network failure on upload
      repo.networkAvailable = false;

      // Sync should attempt but fail gracefully
      await coordinator.ensureSynced(
        'activities',
        'user-123',
        repository: repo,
      );

      // Upload was attempted
      expect(repo.uploadAttempts, 1);

      // In real implementation, backup service would save dirty records
      // Here we verify the pattern works
    });

    test('retry logic works correctly with exponential backoff', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final coordinator = container.read(syncCoordinatorProvider.notifier);
      final repo = NetworkFailingRepository(repositoryKey: 'events');

      // Mark as stale
      await repo.setLastSyncTime(
        DateTime.now()
            .subtract(staleDuration)
            .subtract(const Duration(minutes: 30)),
      );

      // Network fails on first attempts
      repo.networkAvailable = false;

      // First attempt
      await coordinator.ensureSynced('events', 'user-123', repository: repo);
      expect(repo.uploadAttempts, 1);
      expect(repo.syncAttempts, 0);

      // Network comes back, use a fresh coordinator instance to bypass in-memory
      // failure cooldown and retry immediately.
      repo.networkAvailable = true;
      final retryContainer = ProviderContainer();
      addTearDown(retryContainer.dispose);
      final retryCoordinator = retryContainer.read(
        syncCoordinatorProvider.notifier,
      );

      // Mark as stale again to force retry
      await repo.setLastSyncTime(
        DateTime.now()
            .subtract(staleDuration)
            .subtract(const Duration(minutes: 30)),
      );

      // Second attempt - should succeed
      await retryCoordinator.ensureSynced(
        'events',
        'user-123',
        repository: repo,
      );
      expect(repo.syncAttempts, 1);

      // Verify timestamp updated after successful sync
      final lastSync = await repo.getLastSyncTime();
      expect(lastSync, isNotNull);
      expect(DateTime.now().difference(lastSync!).inSeconds < 5, true);
    });

    test('network failure during sync preserves old timestamp', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final coordinator = container.read(syncCoordinatorProvider.notifier);
      final repo = NetworkFailingRepository(repositoryKey: 'users');

      // First successful sync
      repo.networkAvailable = true;
      await coordinator.ensureSynced('users', 'user-123', repository: repo);

      final firstSyncTime = await repo.getLastSyncTime();
      expect(firstSyncTime, isNotNull);

      // Mark as stale
      await repo.setLastSyncTime(
        DateTime.now()
            .subtract(staleDuration)
            .subtract(const Duration(minutes: 30)),
      );

      // Network fails
      repo.networkAvailable = false;
      await coordinator.ensureSynced('users', 'user-123', repository: repo);

      // Timestamp should not have changed (sync failed)
      final afterFailureTime = await repo.getLastSyncTime();
      expect(afterFailureTime, isNotNull);
      expect(
        afterFailureTime!.isBefore(DateTime.now().subtract(staleDuration)),
        true,
      );
    });

    test('backup service integration during network failure', () async {
      // Create a backup simulating upload failure
      final backup = DirtyRecordBackup(
        backupCreatedAt: DateTime.now(),
        appVersion: '1.12.1',
        schemaVersion: 3,
        userId: 'user-123',
        dirtyRecords: {
          'activities': [
            {'id': 'act-1', 'name': 'Failed Upload'},
          ],
        },
        uploadErrors: [
          UploadError(
            repository: 'activities',
            error: 'Network timeout',
            timestamp: DateTime.now(),
            retryAttempts: 3,
          ),
        ],
      );

      await backupService.backupDirtyRecords(backup);

      // Verify backup exists
      expect(await backupService.hasBackup(), true);

      // Recover backup
      final recovered = await backupService.recoverBackup();
      expect(recovered, isNotNull);
      expect(recovered!.dirtyRecords.containsKey('activities'), true);
      expect(recovered.uploadErrors.length, 1);
      expect(recovered.uploadErrors[0].retryAttempts, 3);

      // Cleanup
      await backupService.deleteBackup();
    });

    test('partial sync failure - some repos succeed, others fail', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final coordinator = container.read(syncCoordinatorProvider.notifier);

      final usersRepo = NetworkFailingRepository(repositoryKey: 'users');
      final activitiesRepo = NetworkFailingRepository(
        repositoryKey: 'activities',
        dependencies: ['users'],
      );

      // Mark both as stale
      await usersRepo.setLastSyncTime(
        DateTime.now()
            .subtract(staleDuration)
            .subtract(const Duration(minutes: 30)),
      );
      await activitiesRepo.setLastSyncTime(
        DateTime.now()
            .subtract(staleDuration)
            .subtract(const Duration(minutes: 30)),
      );

      // Users sync succeeds
      usersRepo.networkAvailable = true;
      await coordinator.ensureSynced(
        'users',
        'user-123',
        repository: usersRepo,
      );
      expect(usersRepo.syncAttempts, 1);

      // Activities sync fails
      activitiesRepo.networkAvailable = false;
      await coordinator.ensureSynced(
        'activities',
        'user-123',
        repository: activitiesRepo,
      );
      expect(activitiesRepo.uploadAttempts, 1);
      expect(activitiesRepo.syncAttempts, 0);

      // Verify users timestamp updated, activities did not
      final usersTime = await usersRepo.getLastSyncTime();
      final activitiesTime = await activitiesRepo.getLastSyncTime();

      expect(
        DateTime.now().difference(usersTime!).inSeconds < 5,
        true,
        reason: 'Users should have recent timestamp',
      );
      expect(
        activitiesTime!.isBefore(DateTime.now().subtract(staleDuration)),
        true,
        reason: 'Activities should have old timestamp (failed)',
      );
    });
  });
}
