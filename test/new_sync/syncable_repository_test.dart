import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/data/syncable_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mock implementation of SyncableRepository for testing
class MockSyncableRepository with SyncableRepository {
  final String _repositoryKey;

  MockSyncableRepository({String repositoryKey = 'test_repo'})
    : _repositoryKey = repositoryKey;

  @override
  String get repositoryKey => _repositoryKey;

  @override
  List<String> get dependencies => ['users'];

  int syncCallCount = 0;
  int uploadCallCount = 0;
  bool shouldFailSync = false;
  bool shouldFailUpload = false;

  @override
  Future<SyncResult> syncFromRemote(String userId) async {
    syncCallCount++;

    if (shouldFailSync) {
      return SyncResult.failed('Sync failed');
    }

    // Simulate successful sync
    await setLastSyncTime(DateTime.now());
    return SyncResult.successful(10);
  }

  @override
  Future<UploadResult> uploadDirtyRecords(String userId) async {
    uploadCallCount++;

    if (shouldFailUpload) {
      return UploadResult.failed('Upload failed');
    }

    return UploadResult.successful(5);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncableRepository', () {
    late MockSyncableRepository repository;

    setUp(() async {
      // Clear SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});
      repository = MockSyncableRepository();
    });

    group('Staleness Tracking', () {
      test('isStale returns true when never synced', () async {
        final isStale = await repository.isStale();
        expect(isStale, isTrue);
      });

      test('isStale returns false when recently synced', () async {
        // Set last sync to comfortably under stale threshold
        final recentSync = DateTime.now().subtract(
          SyncableRepository.staleDuration - const Duration(minutes: 10),
        );
        await repository.setLastSyncTime(recentSync);

        final isStale = await repository.isStale();
        expect(isStale, isFalse);
      });

      test('isStale returns false when synced 50 minutes ago', () async {
        final almostStale = DateTime.now().subtract(
          const Duration(minutes: 50),
        );
        await repository.setLastSyncTime(almostStale);

        final isStale = await repository.isStale();
        expect(isStale, isFalse);
      });

      test('isStale returns true when synced well past threshold', () async {
        final staleSync = DateTime.now().subtract(
          SyncableRepository.staleDuration + const Duration(minutes: 10),
        );
        await repository.setLastSyncTime(staleSync);

        final isStale = await repository.isStale();
        expect(isStale, isTrue);
      });
    });

    group('Timestamp Storage', () {
      test('getLastSyncTime returns null when never synced', () async {
        final timestamp = await repository.getLastSyncTime();
        expect(timestamp, isNull);
      });

      test('setLastSyncTime stores timestamp correctly', () async {
        final now = DateTime.now();
        await repository.setLastSyncTime(now);

        final stored = await repository.getLastSyncTime();
        expect(stored, isNotNull);

        // Compare with 1-second tolerance for test execution time
        expect(stored!.difference(now).inSeconds.abs(), lessThan(2));
      });

      test('timestamp persists across repository instances', () async {
        final now = DateTime.now();
        await repository.setLastSyncTime(now);

        // Create new repository instance
        final newRepository = MockSyncableRepository();
        final stored = await newRepository.getLastSyncTime();

        expect(stored, isNotNull);
        expect(stored!.difference(now).inSeconds.abs(), lessThan(2));
      });

      test('handles invalid timestamp gracefully', () async {
        // Manually set invalid timestamp
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('test_repo_last_sync', 'invalid-date');

        final timestamp = await repository.getLastSyncTime();
        expect(timestamp, isNull);
      });

      test('uses correct SharedPreferences key pattern', () async {
        final now = DateTime.now();
        await repository.setLastSyncTime(now);

        final prefs = await SharedPreferences.getInstance();
        final key = '${repository.repositoryKey}_last_sync';
        final stored = prefs.getString(key);

        expect(stored, isNotNull);
        expect(stored, equals(now.toIso8601String()));
      });
    });

    group('Repository Interface', () {
      test('repositoryKey is accessible', () {
        expect(repository.repositoryKey, equals('test_repo'));
      });

      test('dependencies is accessible', () {
        expect(repository.dependencies, equals(['users']));
      });

      test('syncFromRemote can be called', () async {
        final result = await repository.syncFromRemote('user-123');
        expect(result.success, isTrue);
        expect(result.count, equals(10));
        expect(repository.syncCallCount, equals(1));
      });

      test('uploadDirtyRecords can be called', () async {
        final result = await repository.uploadDirtyRecords('user-123');
        expect(result.success, isTrue);
        expect(result.count, equals(5));
        expect(repository.uploadCallCount, equals(1));
      });

      test('syncFromRemote updates last sync time on success', () async {
        expect(await repository.getLastSyncTime(), isNull);

        await repository.syncFromRemote('user-123');

        final lastSync = await repository.getLastSyncTime();
        expect(lastSync, isNotNull);

        // Should be very recent (within last 2 seconds)
        final now = DateTime.now();
        expect(now.difference(lastSync!).inSeconds, lessThan(2));
      });
    });

    group('SyncResult', () {
      test('successful creates success result', () {
        final result = SyncResult.successful(15);
        expect(result.success, isTrue);
        expect(result.count, equals(15));
        expect(result.error, isNull);
      });

      test('failed creates error result', () {
        final result = SyncResult.failed('Network error');
        expect(result.success, isFalse);
        expect(result.count, equals(0));
        expect(result.error, equals('Network error'));
      });
    });

    group('UploadResult', () {
      test('successful creates success result', () {
        final result = UploadResult.successful(8);
        expect(result.success, isTrue);
        expect(result.count, equals(8));
        expect(result.error, isNull);
      });

      test('nothingToUpload creates zero-count success', () {
        final result = UploadResult.nothingToUpload();
        expect(result.success, isTrue);
        expect(result.count, equals(0));
        expect(result.error, isNull);
      });

      test('failed creates error result', () {
        final result = UploadResult.failed('Timeout');
        expect(result.success, isFalse);
        expect(result.count, equals(0));
        expect(result.error, equals('Timeout'));
      });
    });

    group('Edge Cases', () {
      test('staleDuration constant is 1 hour', () {
        expect(
          SyncableRepository.staleDuration,
          equals(const Duration(hours: 1)),
        );
      });

      test(
        'multiple repositories use different SharedPreferences keys',
        () async {
          final repo1 = MockSyncableRepository(repositoryKey: 'repo1');
          final repo2 = MockSyncableRepository(repositoryKey: 'repo2');

          final time1 = DateTime.now();
          final time2 = time1.add(const Duration(hours: 5));

          await repo1.setLastSyncTime(time1);
          await repo2.setLastSyncTime(time2);

          final stored1 = await repo1.getLastSyncTime();
          final stored2 = await repo2.getLastSyncTime();

          expect(stored1!.difference(time1).inSeconds.abs(), lessThan(2));
          expect(stored2!.difference(time2).inSeconds.abs(), lessThan(2));
        },
      );
    });
  });
}
