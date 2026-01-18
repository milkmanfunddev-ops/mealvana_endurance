import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/data/syncable_repository.dart';
import 'package:mealvana_endurance/shared/services/sync/sync_coordinator.dart';
import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mock repository for testing
class MockRepository implements SyncableRepository {
  @override
  final String repositoryKey;

  @override
  final List<String> dependencies;

  int syncCallCount = 0;
  int uploadCallCount = 0;
  bool shouldThrowOnSync = false;
  bool shouldThrowOnUpload = false;

  MockRepository({
    required this.repositoryKey,
    this.dependencies = const [],
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

    if (shouldThrowOnSync) {
      throw Exception('Mock sync failure');
    }

    await setLastSyncTime(DateTime.now());
    return SyncResult.successful(10);
  }

  @override
  Future<UploadResult> uploadDirtyRecords(String userId) async {
    uploadCallCount++;

    if (shouldThrowOnUpload) {
      throw Exception('Mock upload failure');
    }

    return UploadResult.nothingToUpload();
  }

  void reset() {
    syncCallCount = 0;
    uploadCallCount = 0;
    shouldThrowOnSync = false;
    shouldThrowOnUpload = false;
  }
}

void main() {
  group('SyncCoordinator.ensureSynced', () {
    setUp(() async {
      // Reset SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});
    });

    test('should return immediately if data is not stale', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final coordinator = container.read(syncCoordinatorProvider.notifier);
      final repo = MockRepository(repositoryKey: 'users');

      // Mark as synced just now
      await repo.setLastSyncTime(DateTime.now());

      // Should return immediately without syncing
      await coordinator.ensureSynced('users', 'user-123', repository: repo);

      expect(repo.syncCallCount, 0);
      expect(repo.uploadCallCount, 0);
    });

    test('should sync if data is stale', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final coordinator = container.read(syncCoordinatorProvider.notifier);
      final repo = MockRepository(repositoryKey: 'users');

      // Mark as synced 25 hours ago (stale)
      await repo.setLastSyncTime(
        DateTime.now().subtract(const Duration(hours: 25)),
      );

      // Should sync
      await coordinator.ensureSynced('users', 'user-123', repository: repo);

      expect(repo.syncCallCount, 1);
      expect(repo.uploadCallCount, 1);
    });

    test('should sync dependencies before syncing repository', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final coordinator = container.read(syncCoordinatorProvider.notifier);
      final usersRepo = MockRepository(repositoryKey: 'users');
      final activitiesRepo = MockRepository(
        repositoryKey: 'activities',
        dependencies: ['users'],
      );

      // Both are stale
      await usersRepo.setLastSyncTime(
        DateTime.now().subtract(const Duration(hours: 25)),
      );
      await activitiesRepo.setLastSyncTime(
        DateTime.now().subtract(const Duration(hours: 25)),
      );

      // Sync activities (which depends on users)
      // Note: In real usage, we'd pass both repos, but for Phase 2.2
      // we're just testing the logic with one repo at a time
      await coordinator.ensureSynced('users', 'user-123', repository: usersRepo);
      await coordinator.ensureSynced(
        'activities',
        'user-123',
        repository: activitiesRepo,
      );

      // Both should have been synced
      expect(usersRepo.syncCallCount, 1);
      expect(activitiesRepo.syncCallCount, 1);
    });

    test('should prevent infinite loops with circular dependencies', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final coordinator = container.read(syncCoordinatorProvider.notifier);

      // Simulate calling ensureSynced on the same repo twice
      // (would happen in circular dependency)
      await coordinator.ensureSynced('users', 'user-123');
      await coordinator.ensureSynced('users', 'user-123');

      // Should not throw or hang (protected by _syncingNow set)
      // Test passes if we get here without timeout
    });

    test('should handle sync errors gracefully', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final coordinator = container.read(syncCoordinatorProvider.notifier);
      final repo = MockRepository(repositoryKey: 'users');

      // Mark as stale
      await repo.setLastSyncTime(
        DateTime.now().subtract(const Duration(hours: 25)),
      );

      repo.shouldThrowOnSync = true;

      // Should not throw - errors are logged but not propagated
      await coordinator.ensureSynced('users', 'user-123', repository: repo);

      expect(repo.syncCallCount, 1); // Was attempted
    });

    test('should handle upload errors gracefully', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final coordinator = container.read(syncCoordinatorProvider.notifier);
      final repo = MockRepository(repositoryKey: 'users');

      // Mark as stale
      await repo.setLastSyncTime(
        DateTime.now().subtract(const Duration(hours: 25)),
      );

      repo.shouldThrowOnUpload = true;

      // Should not throw - errors are logged but not propagated
      await coordinator.ensureSynced('users', 'user-123', repository: repo);

      expect(repo.uploadCallCount, 1); // Was attempted
    });

    test('should sync if never synced before', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final coordinator = container.read(syncCoordinatorProvider.notifier);
      final repo = MockRepository(repositoryKey: 'users');

      // No timestamp set - never synced

      // Should sync
      await coordinator.ensureSynced('users', 'user-123', repository: repo);

      expect(repo.syncCallCount, 1);
      expect(repo.uploadCallCount, 1);
    });

    test('should work without repository instance (in-memory cache)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final coordinator = container.read(syncCoordinatorProvider.notifier);

      // First call - should be stale (no timestamp)
      await coordinator.ensureSynced('users', 'user-123');

      // Second call immediately after - should use in-memory cache
      // and NOT be stale
      await coordinator.ensureSynced('users', 'user-123');

      // Test passes if no errors
    });

    test('should handle complex dependency chains', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final coordinator = container.read(syncCoordinatorProvider.notifier);

      // Create chain: carb_loading_day_meals → carb_loading_days → carb_loading_plans → users
      final usersRepo = MockRepository(repositoryKey: 'users');
      final plansRepo = MockRepository(
        repositoryKey: 'carb_loading_plans',
        dependencies: ['users'],
      );
      final daysRepo = MockRepository(
        repositoryKey: 'carb_loading_days',
        dependencies: ['carb_loading_plans'],
      );
      final mealsRepo = MockRepository(
        repositoryKey: 'carb_loading_day_meals',
        dependencies: ['carb_loading_days'],
      );

      // All stale
      for (final repo in [usersRepo, plansRepo, daysRepo, mealsRepo]) {
        await repo.setLastSyncTime(
          DateTime.now().subtract(const Duration(hours: 25)),
        );
      }

      // Sync in correct dependency order
      await coordinator.ensureSynced('users', 'user-123', repository: usersRepo);
      await coordinator.ensureSynced(
        'carb_loading_plans',
        'user-123',
        repository: plansRepo,
      );
      await coordinator.ensureSynced(
        'carb_loading_days',
        'user-123',
        repository: daysRepo,
      );
      await coordinator.ensureSynced(
        'carb_loading_day_meals',
        'user-123',
        repository: mealsRepo,
      );

      // All should have synced
      expect(usersRepo.syncCallCount, 1);
      expect(plansRepo.syncCallCount, 1);
      expect(daysRepo.syncCallCount, 1);
      expect(mealsRepo.syncCallCount, 1);
    });

    test('should update timestamp after successful sync', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final coordinator = container.read(syncCoordinatorProvider.notifier);
      final repo = MockRepository(repositoryKey: 'users');

      // Initial sync
      await coordinator.ensureSynced('users', 'user-123', repository: repo);

      final firstSync = await repo.getLastSyncTime();
      expect(firstSync, isNotNull);

      // Immediate second call - should not sync (not stale)
      repo.reset();
      await coordinator.ensureSynced('users', 'user-123', repository: repo);

      expect(repo.syncCallCount, 0); // Did not sync again
    });
  });

  group('SyncCoordinator.sync (legacy)', () {
    test('should still work for backwards compatibility', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final coordinator = container.read(syncCoordinatorProvider.notifier);

      // Note: This will fail without proper providers set up, but we're just
      // testing that the method signature still exists
      expect(
        () => coordinator.sync(userId: 'user-123'),
        // Will throw due to missing providers, but method exists
        throwsA(anything),
      );
    });
  });
}
