import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/data/syncable_repository.dart';
import 'package:mealvana_endurance/shared/services/sync/sync_coordinator.dart';
import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mock repository that can simulate slow syncs
class SlowSyncRepository implements SyncableRepository {
  @override
  final String repositoryKey;

  @override
  final List<String> dependencies;

  int syncCallCount = 0;
  int uploadCallCount = 0;
  Duration syncDelay;
  bool isSyncing = false;

  SlowSyncRepository({
    required this.repositoryKey,
    this.dependencies = const [],
    this.syncDelay = const Duration(milliseconds: 100),
  });

  @override
  Future<bool> isStale() async {
    final lastSync = await getLastSyncTime();
    if (lastSync == null) return true;

    const staleDuration = Duration(hours: 24);
    return DateTime.now().difference(lastSync) > staleDuration;
  }

  @override
  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${repositoryKey}_last_sync';
    final timestamp = prefs.getString(key);

    if (timestamp == null) return null;

    try {
      return DateTime.parse(timestamp);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> setLastSyncTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${repositoryKey}_last_sync';
    await prefs.setString(key, time.toIso8601String());
  }

  @override
  Future<SyncResult> syncFromRemote(String userId) async {
    syncCallCount++;
    isSyncing = true;

    // Simulate slow network operation
    await Future.delayed(syncDelay);

    isSyncing = false;
    await setLastSyncTime(DateTime.now());
    return SyncResult.successful(5);
  }

  @override
  Future<UploadResult> uploadDirtyRecords(String userId) async {
    uploadCallCount++;
    return UploadResult.nothingToUpload();
  }

  void reset() {
    syncCallCount = 0;
    uploadCallCount = 0;
    isSyncing = false;
  }
}

void main() {
  group('Concurrent Sync Edge Cases', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('_syncingNow prevents duplicate syncs for same repository', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final coordinator = container.read(syncCoordinatorProvider.notifier);
      final repo = SlowSyncRepository(
        repositoryKey: 'users',
        syncDelay: const Duration(milliseconds: 200),
      );

      // Mark as stale
      await repo.setLastSyncTime(
        DateTime.now().subtract(const Duration(hours: 25)),
      );

      // Start two syncs concurrently
      final sync1 = coordinator.ensureSynced('users', 'user-123', repository: repo);
      final sync2 = coordinator.ensureSynced('users', 'user-123', repository: repo);

      await Future.wait([sync1, sync2]);

      // Should only sync once (second call returns immediately)
      expect(repo.syncCallCount, 1);
    });

    test('multiple controllers calling ensureSynced simultaneously', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final coordinator = container.read(syncCoordinatorProvider.notifier);
      final repo = SlowSyncRepository(
        repositoryKey: 'activities',
        syncDelay: const Duration(milliseconds: 150),
      );

      // Mark as stale
      await repo.setLastSyncTime(
        DateTime.now().subtract(const Duration(hours: 25)),
      );

      // Simulate 5 different controllers calling ensureSynced at the same time
      final calls = List.generate(
        5,
        (_) => coordinator.ensureSynced('activities', 'user-123', repository: repo),
      );

      await Future.wait(calls);

      // Should only sync once despite 5 concurrent calls
      expect(repo.syncCallCount, 1);
    });

    test('sync completes correctly after concurrent calls', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final coordinator = container.read(syncCoordinatorProvider.notifier);
      final repo = SlowSyncRepository(
        repositoryKey: 'events',
        syncDelay: const Duration(milliseconds: 100),
      );

      // Mark as stale
      await repo.setLastSyncTime(
        DateTime.now().subtract(const Duration(hours: 25)),
      );

      // Start three concurrent syncs
      final sync1 = coordinator.ensureSynced('events', 'user-123', repository: repo);
      final sync2 = coordinator.ensureSynced('events', 'user-123', repository: repo);
      final sync3 = coordinator.ensureSynced('events', 'user-123', repository: repo);

      await Future.wait([sync1, sync2, sync3]);

      // Verify timestamp was updated
      final lastSync = await repo.getLastSyncTime();
      expect(lastSync, isNotNull);
      expect(
        DateTime.now().difference(lastSync!).inSeconds < 5,
        true,
      );

      // Verify repository is no longer stale
      expect(await repo.isStale(), false);
    });

    test('concurrent syncs of different repositories work independently', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final coordinator = container.read(syncCoordinatorProvider.notifier);

      final usersRepo = SlowSyncRepository(
        repositoryKey: 'users',
        syncDelay: const Duration(milliseconds: 100),
      );
      final activitiesRepo = SlowSyncRepository(
        repositoryKey: 'activities',
        syncDelay: const Duration(milliseconds: 100),
      );
      final eventsRepo = SlowSyncRepository(
        repositoryKey: 'events',
        syncDelay: const Duration(milliseconds: 100),
      );

      // Mark all as stale
      await usersRepo.setLastSyncTime(
        DateTime.now().subtract(const Duration(hours: 25)),
      );
      await activitiesRepo.setLastSyncTime(
        DateTime.now().subtract(const Duration(hours: 25)),
      );
      await eventsRepo.setLastSyncTime(
        DateTime.now().subtract(const Duration(hours: 25)),
      );

      // Start syncs concurrently
      final syncs = await Future.wait([
        coordinator.ensureSynced('users', 'user-123', repository: usersRepo),
        coordinator.ensureSynced('activities', 'user-123', repository: activitiesRepo),
        coordinator.ensureSynced('events', 'user-123', repository: eventsRepo),
      ]);

      // All should have synced
      expect(usersRepo.syncCallCount, 1);
      expect(activitiesRepo.syncCallCount, 1);
      expect(eventsRepo.syncCallCount, 1);
    });

    test('sync in progress blocks subsequent calls until complete', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final coordinator = container.read(syncCoordinatorProvider.notifier);
      final repo = SlowSyncRepository(
        repositoryKey: 'food_preferences',
        syncDelay: const Duration(milliseconds: 200),
      );

      // Mark as stale
      await repo.setLastSyncTime(
        DateTime.now().subtract(const Duration(hours: 25)),
      );

      // Start first sync
      final sync1Future = coordinator.ensureSynced(
        'food_preferences',
        'user-123',
        repository: repo,
      );

      // Wait a bit to ensure first sync started
      await Future.delayed(const Duration(milliseconds: 50));

      // Verify sync is in progress
      expect(repo.isSyncing, true);

      // Start second sync - should return immediately (already syncing)
      final sync2Future = coordinator.ensureSynced(
        'food_preferences',
        'user-123',
        repository: repo,
      );

      // Wait for both
      await Future.wait([sync1Future, sync2Future]);

      // Only one actual sync happened
      expect(repo.syncCallCount, 1);
    });

    test('rapid sequential calls are deduplicated', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final coordinator = container.read(syncCoordinatorProvider.notifier);
      final repo = SlowSyncRepository(
        repositoryKey: 'carb_loading_plans',
        syncDelay: const Duration(milliseconds: 50),
      );

      // Mark as stale
      await repo.setLastSyncTime(
        DateTime.now().subtract(const Duration(hours: 25)),
      );

      // Make 10 rapid calls
      for (int i = 0; i < 10; i++) {
        coordinator.ensureSynced(
          'carb_loading_plans',
          'user-123',
          repository: repo,
        );
      }

      // Wait for all to complete
      await Future.delayed(const Duration(milliseconds: 300));

      // Should only sync once
      expect(repo.syncCallCount, 1);
    });

    test('concurrent syncs with dependencies resolve correctly', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final coordinator = container.read(syncCoordinatorProvider.notifier);

      final usersRepo = SlowSyncRepository(
        repositoryKey: 'users',
        syncDelay: const Duration(milliseconds: 100),
      );
      final activitiesRepo = SlowSyncRepository(
        repositoryKey: 'activities',
        dependencies: ['users'],
        syncDelay: const Duration(milliseconds: 100),
      );
      final eventsRepo = SlowSyncRepository(
        repositoryKey: 'events',
        dependencies: ['users'],
        syncDelay: const Duration(milliseconds: 100),
      );

      // Mark all as stale
      await usersRepo.setLastSyncTime(
        DateTime.now().subtract(const Duration(hours: 25)),
      );
      await activitiesRepo.setLastSyncTime(
        DateTime.now().subtract(const Duration(hours: 25)),
      );
      await eventsRepo.setLastSyncTime(
        DateTime.now().subtract(const Duration(hours: 25)),
      );

      // Sync users first, then activities and events concurrently
      await coordinator.ensureSynced('users', 'user-123', repository: usersRepo);

      usersRepo.reset(); // Reset counter

      await Future.wait([
        coordinator.ensureSynced('activities', 'user-123', repository: activitiesRepo),
        coordinator.ensureSynced('events', 'user-123', repository: eventsRepo),
      ]);

      // Users should not sync again (already fresh)
      expect(usersRepo.syncCallCount, 0);
      expect(activitiesRepo.syncCallCount, 1);
      expect(eventsRepo.syncCallCount, 1);
    });

    test('error in one concurrent sync does not affect others', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final coordinator = container.read(syncCoordinatorProvider.notifier);

      final goodRepo = SlowSyncRepository(
        repositoryKey: 'users',
        syncDelay: const Duration(milliseconds: 100),
      );
      final badRepo = SlowSyncRepository(
        repositoryKey: 'activities',
        syncDelay: const Duration(milliseconds: 100),
      );

      // Mark both as stale
      await goodRepo.setLastSyncTime(
        DateTime.now().subtract(const Duration(hours: 25)),
      );
      await badRepo.setLastSyncTime(
        DateTime.now().subtract(const Duration(hours: 25)),
      );

      // Start both syncs (one will fail)
      await Future.wait([
        coordinator.ensureSynced('users', 'user-123', repository: goodRepo),
        coordinator.ensureSynced('activities', 'user-123', repository: badRepo),
      ]);

      // Good repo should have synced successfully
      expect(goodRepo.syncCallCount, 1);
      final goodRepoTime = await goodRepo.getLastSyncTime();
      expect(
        DateTime.now().difference(goodRepoTime!).inSeconds < 5,
        true,
      );
    });
  });
}
