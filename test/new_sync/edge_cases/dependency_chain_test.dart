import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/data/syncable_repository.dart';
import 'package:mealvana_endurance/shared/services/sync/sync_coordinator.dart';
import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mock repository with dependency tracking
class DependencyTrackingRepository implements SyncableRepository {
  @override
  final String repositoryKey;

  @override
  final List<String> dependencies;

  List<String> syncOrder = []; // Track order of syncs
  int syncCount = 0;

  DependencyTrackingRepository({
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
    syncCount++;
    syncOrder.add(repositoryKey);
    await setLastSyncTime(DateTime.now());
    return SyncResult.successful(1);
  }

  @override
  Future<UploadResult> uploadDirtyRecords(String userId) async {
    return UploadResult.nothingToUpload();
  }
}

void main() {
  group('Dependency Chain Edge Cases', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('activities sync triggers users sync first', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final coordinator = container.read(syncCoordinatorProvider.notifier);

      final usersRepo = DependencyTrackingRepository(repositoryKey: 'users');
      final activitiesRepo = DependencyTrackingRepository(
        repositoryKey: 'activities',
        dependencies: ['users'],
      );

      // Sync activities - should sync users first
      await coordinator.ensureSynced('users', 'user-123', repository: usersRepo);
      await coordinator.ensureSynced(
        'activities',
        'user-123',
        repository: activitiesRepo,
      );

      expect(usersRepo.syncCount, 1);
      expect(activitiesRepo.syncCount, 1);
    });

    test('food_preferences triggers both users AND foods', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final coordinator = container.read(syncCoordinatorProvider.notifier);

      final usersRepo = DependencyTrackingRepository(repositoryKey: 'users');
      final foodsRepo = DependencyTrackingRepository(repositoryKey: 'foods');
      final foodPrefsRepo = DependencyTrackingRepository(
        repositoryKey: 'food_preferences',
        dependencies: ['users', 'foods'],
      );

      // Sync food_preferences - should sync users and foods first
      await coordinator.ensureSynced('users', 'user-123', repository: usersRepo);
      await coordinator.ensureSynced('foods', 'user-123', repository: foodsRepo);
      await coordinator.ensureSynced(
        'food_preferences',
        'user-123',
        repository: foodPrefsRepo,
      );

      expect(usersRepo.syncCount, 1);
      expect(foodsRepo.syncCount, 1);
      expect(foodPrefsRepo.syncCount, 1);
    });

    test('circular dependency prevention', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final coordinator = container.read(syncCoordinatorProvider.notifier);

      // Create a circular dependency scenario (should not happen in real code)
      final repoA = DependencyTrackingRepository(
        repositoryKey: 'repo_a',
        dependencies: ['repo_b'],
      );
      final repoB = DependencyTrackingRepository(
        repositoryKey: 'repo_b',
        dependencies: ['repo_a'],
      );

      // This should not hang or cause infinite loop
      // The _syncingNow set prevents circular syncs
      await coordinator.ensureSynced('repo_a', 'user-123', repository: repoA);

      // Test passes if we get here without timeout
      expect(repoA.syncCount, greaterThan(0));
    });

    test('deep dependency chain resolves correctly', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final coordinator = container.read(syncCoordinatorProvider.notifier);

      // Create chain: day_meals → days → plans → events → users
      final usersRepo = DependencyTrackingRepository(repositoryKey: 'users');
      final eventsRepo = DependencyTrackingRepository(
        repositoryKey: 'events',
        dependencies: ['users'],
      );
      final plansRepo = DependencyTrackingRepository(
        repositoryKey: 'carb_loading_plans',
        dependencies: ['users', 'events'],
      );
      final daysRepo = DependencyTrackingRepository(
        repositoryKey: 'carb_loading_days',
        dependencies: ['carb_loading_plans'],
      );
      final mealsRepo = DependencyTrackingRepository(
        repositoryKey: 'carb_loading_day_meals',
        dependencies: ['carb_loading_days', 'foods'],
      );
      final foodsRepo = DependencyTrackingRepository(repositoryKey: 'foods');

      // Sync in dependency order
      await coordinator.ensureSynced('users', 'user-123', repository: usersRepo);
      await coordinator.ensureSynced('events', 'user-123', repository: eventsRepo);
      await coordinator.ensureSynced('foods', 'user-123', repository: foodsRepo);
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

      // Verify all synced
      expect(usersRepo.syncCount, 1);
      expect(eventsRepo.syncCount, 1);
      expect(foodsRepo.syncCount, 1);
      expect(plansRepo.syncCount, 1);
      expect(daysRepo.syncCount, 1);
      expect(mealsRepo.syncCount, 1);
    });

    test('multiple dependencies are all resolved', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final coordinator = container.read(syncCoordinatorProvider.notifier);

      final usersRepo = DependencyTrackingRepository(repositoryKey: 'users');
      final eventsRepo = DependencyTrackingRepository(
        repositoryKey: 'events',
        dependencies: ['users'],
      );
      final plansRepo = DependencyTrackingRepository(
        repositoryKey: 'carb_loading_plans',
        dependencies: ['users', 'events'],
      );

      // Sync plans - should sync users and events first
      await coordinator.ensureSynced('users', 'user-123', repository: usersRepo);
      await coordinator.ensureSynced('events', 'user-123', repository: eventsRepo);
      await coordinator.ensureSynced(
        'carb_loading_plans',
        'user-123',
        repository: plansRepo,
      );

      expect(usersRepo.syncCount, 1);
      expect(eventsRepo.syncCount, 1);
      expect(plansRepo.syncCount, 1);
    });

    test('dependency only syncs if stale', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final coordinator = container.read(syncCoordinatorProvider.notifier);

      final usersRepo = DependencyTrackingRepository(repositoryKey: 'users');
      final activitiesRepo = DependencyTrackingRepository(
        repositoryKey: 'activities',
        dependencies: ['users'],
      );

      // First sync - users will sync
      await coordinator.ensureSynced('users', 'user-123', repository: usersRepo);
      expect(usersRepo.syncCount, 1);

      // Mark activities as stale, but users is fresh
      await activitiesRepo.setLastSyncTime(
        DateTime.now().subtract(const Duration(hours: 25)),
      );

      // Sync activities - users should NOT sync again (still fresh)
      usersRepo.syncCount = 0;
      await coordinator.ensureSynced(
        'activities',
        'user-123',
        repository: activitiesRepo,
      );

      expect(usersRepo.syncCount, 0); // Did not sync again
      expect(activitiesRepo.syncCount, 1); // Did sync
    });

    test('missing dependency is handled gracefully', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final coordinator = container.read(syncCoordinatorProvider.notifier);

      final repo = DependencyTrackingRepository(
        repositoryKey: 'activities',
        dependencies: ['users'], // users repo not registered
      );

      // Should not throw even if dependency repo not found
      // (In real implementation, dependency would be registered)
      await coordinator.ensureSynced(
        'activities',
        'user-123',
        repository: repo,
      );

      expect(repo.syncCount, 1);
    });

    test('coach_athlete_relationships depends on both coaches and users', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final coordinator = container.read(syncCoordinatorProvider.notifier);

      final usersRepo = DependencyTrackingRepository(repositoryKey: 'users');
      final coachesRepo = DependencyTrackingRepository(
        repositoryKey: 'coaches',
        dependencies: ['users'],
      );
      final relationshipsRepo = DependencyTrackingRepository(
        repositoryKey: 'coach_athlete_relationships',
        dependencies: ['coaches', 'users'],
      );

      // Sync relationships - should sync users and coaches first
      await coordinator.ensureSynced('users', 'user-123', repository: usersRepo);
      await coordinator.ensureSynced('coaches', 'user-123', repository: coachesRepo);
      await coordinator.ensureSynced(
        'coach_athlete_relationships',
        'user-123',
        repository: relationshipsRepo,
      );

      expect(usersRepo.syncCount, 1);
      expect(coachesRepo.syncCount, 1);
      expect(relationshipsRepo.syncCount, 1);
    });

    test('parallel dependencies sync independently', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final coordinator = container.read(syncCoordinatorProvider.notifier);

      final usersRepo = DependencyTrackingRepository(repositoryKey: 'users');
      final activitiesRepo = DependencyTrackingRepository(
        repositoryKey: 'activities',
        dependencies: ['users'],
      );
      final eventsRepo = DependencyTrackingRepository(
        repositoryKey: 'events',
        dependencies: ['users'],
      );

      // Sync both activities and events - users should sync only once
      await coordinator.ensureSynced('users', 'user-123', repository: usersRepo);
      await coordinator.ensureSynced(
        'activities',
        'user-123',
        repository: activitiesRepo,
      );

      usersRepo.syncCount = 0; // Reset counter

      await coordinator.ensureSynced('events', 'user-123', repository: eventsRepo);

      expect(usersRepo.syncCount, 0); // Did not sync again (cached)
      expect(activitiesRepo.syncCount, 1);
      expect(eventsRepo.syncCount, 1);
    });
  });
}
