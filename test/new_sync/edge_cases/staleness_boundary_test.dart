import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/data/syncable_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple test repository for staleness testing
class StaleTestRepository implements SyncableRepository {
  @override
  final String repositoryKey;

  @override
  final List<String> dependencies;

  StaleTestRepository({
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
    await setLastSyncTime(DateTime.now());
    return SyncResult.successful(1);
  }

  @override
  Future<UploadResult> uploadDirtyRecords(String userId) async {
    return UploadResult.nothingToUpload();
  }
}

void main() {
  group('Staleness Boundary Edge Cases', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('exactly 24 hours is NOT stale', () async {
      final repo = StaleTestRepository(repositoryKey: 'users');

      // Set timestamp to exactly 24 hours ago
      final exactly24HoursAgo = DateTime.now().subtract(const Duration(hours: 24));
      await repo.setLastSyncTime(exactly24HoursAgo);

      // Should NOT be stale (24 hours is the threshold, not past it)
      final isStale = await repo.isStale();
      expect(isStale, false);
    });

    test('24 hours + 1 second is stale', () async {
      final repo = StaleTestRepository(repositoryKey: 'users');

      // Set timestamp to 24 hours + 1 second ago
      final justPast24Hours = DateTime.now().subtract(
        const Duration(hours: 24, seconds: 1),
      );
      await repo.setLastSyncTime(justPast24Hours);

      // Should be stale
      final isStale = await repo.isStale();
      expect(isStale, true);
    });

    test('23 hours 59 minutes is NOT stale', () async {
      final repo = StaleTestRepository(repositoryKey: 'activities');

      // Set timestamp to 23:59:00 ago
      final almostStale = DateTime.now().subtract(
        const Duration(hours: 23, minutes: 59),
      );
      await repo.setLastSyncTime(almostStale);

      // Should NOT be stale
      final isStale = await repo.isStale();
      expect(isStale, false);
    });

    test('25 hours is stale', () async {
      final repo = StaleTestRepository(repositoryKey: 'events');

      // Set timestamp to 25 hours ago
      final wellPastStale = DateTime.now().subtract(const Duration(hours: 25));
      await repo.setLastSyncTime(wellPastStale);

      // Should be stale
      final isStale = await repo.isStale();
      expect(isStale, true);
    });

    test('1 second ago is NOT stale', () async {
      final repo = StaleTestRepository(repositoryKey: 'food_preferences');

      // Set timestamp to 1 second ago
      final justNow = DateTime.now().subtract(const Duration(seconds: 1));
      await repo.setLastSyncTime(justNow);

      // Should NOT be stale
      final isStale = await repo.isStale();
      expect(isStale, false);
    });

    test('null timestamp is stale', () async {
      final repo = StaleTestRepository(repositoryKey: 'never_synced');

      // No timestamp set (never synced)

      // Should be stale
      final isStale = await repo.isStale();
      expect(isStale, true);
    });

    test('corrupted timestamp (invalid ISO8601) is stale', () async {
      final repo = StaleTestRepository(repositoryKey: 'corrupted');

      // Manually set a corrupted timestamp
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('corrupted_last_sync', 'not-a-valid-timestamp');

      // Should be stale (parsing fails, returns null)
      final isStale = await repo.isStale();
      expect(isStale, true);
    });

    test('future timestamp is NOT stale', () async {
      final repo = StaleTestRepository(repositoryKey: 'future');

      // Set timestamp to 1 hour in the future (clock skew scenario)
      final futureTime = DateTime.now().add(const Duration(hours: 1));
      await repo.setLastSyncTime(futureTime);

      // Should NOT be stale (difference is negative)
      final isStale = await repo.isStale();
      expect(isStale, false);
    });

    test('timestamp parsing edge cases', () async {
      final repo = StaleTestRepository(repositoryKey: 'edge_case');

      // Test various ISO8601 formats
      final testCases = [
        DateTime(2026, 1, 18, 10, 30, 0), // Standard datetime
        DateTime.utc(2026, 1, 18, 10, 30, 0), // UTC datetime
        DateTime(2026, 1, 1), // Start of year
        DateTime(2025, 12, 31, 23, 59, 59), // End of year
      ];

      for (final testTime in testCases) {
        await repo.setLastSyncTime(testTime);

        final recovered = await repo.getLastSyncTime();
        expect(recovered, isNotNull);
        expect(recovered!.isAtSameMomentAs(testTime), true);
      }
    });

    test('empty string timestamp is stale', () async {
      final repo = StaleTestRepository(repositoryKey: 'empty');

      // Manually set empty string
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('empty_last_sync', '');

      // Should be stale (empty string means null)
      final lastSync = await repo.getLastSyncTime();
      expect(lastSync, isNull);

      final isStale = await repo.isStale();
      expect(isStale, true);
    });

    test('very old timestamp (years ago) is stale', () async {
      final repo = StaleTestRepository(repositoryKey: 'ancient');

      // Set timestamp to 1 year ago
      final veryOld = DateTime.now().subtract(const Duration(days: 365));
      await repo.setLastSyncTime(veryOld);

      // Should be stale
      final isStale = await repo.isStale();
      expect(isStale, true);
    });

    test('staleness check is consistent across multiple calls', () async {
      final repo = StaleTestRepository(repositoryKey: 'consistent');

      // Set timestamp to 25 hours ago
      final staleTime = DateTime.now().subtract(const Duration(hours: 25));
      await repo.setLastSyncTime(staleTime);

      // Call isStale multiple times - should always be true
      expect(await repo.isStale(), true);
      expect(await repo.isStale(), true);
      expect(await repo.isStale(), true);
    });

    test('timestamp update makes data fresh', () async {
      final repo = StaleTestRepository(repositoryKey: 'refreshed');

      // Set timestamp to 25 hours ago (stale)
      final oldTime = DateTime.now().subtract(const Duration(hours: 25));
      await repo.setLastSyncTime(oldTime);
      expect(await repo.isStale(), true);

      // Update timestamp to now (fresh)
      await repo.setLastSyncTime(DateTime.now());
      expect(await repo.isStale(), false);
    });

    test('staleness boundary with milliseconds precision', () async {
      final repo = StaleTestRepository(repositoryKey: 'milliseconds');

      // Test exact boundary with milliseconds
      final exactBoundary = DateTime.now().subtract(
        const Duration(hours: 24, milliseconds: 1),
      );
      await repo.setLastSyncTime(exactBoundary);

      // Should be stale (1 millisecond past threshold)
      final isStale = await repo.isStale();
      expect(isStale, true);
    });

    test('different repositories have independent timestamps', () async {
      final repo1 = StaleTestRepository(repositoryKey: 'repo_1');
      final repo2 = StaleTestRepository(repositoryKey: 'repo_2');

      // Set different timestamps
      await repo1.setLastSyncTime(DateTime.now());
      await repo2.setLastSyncTime(
        DateTime.now().subtract(const Duration(hours: 25)),
      );

      // repo1 should be fresh, repo2 should be stale
      expect(await repo1.isStale(), false);
      expect(await repo2.isStale(), true);
    });
  });
}
