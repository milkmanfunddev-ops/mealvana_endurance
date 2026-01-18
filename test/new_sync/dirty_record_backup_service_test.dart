import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/models/dirty_record_backup.dart';
import 'package:mealvana_endurance/shared/models/upload_error.dart';
import 'package:mealvana_endurance/shared/services/dirty_record_backup_service.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../helpers/mock_path_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DirtyRecordBackupService service;
  late AppLogger logger;
  late String tempDir;

  setUp(() {
    // Set up mock path provider
    tempDir = Directory.systemTemp.createTempSync('backup_test_').path;
    PathProviderPlatform.instance = MockPathProvider(tempDir);

    // Create logger (using real implementation for testing)
    logger = PrettyAppLogger();

    // Create service
    service = DirtyRecordBackupService(logger: logger);
  });

  tearDown(() async {
    // Clean up temp directory
    try {
      final dir = Directory(tempDir);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  });

  group('DirtyRecordBackupService', () {
    group('hasBackup', () {
      test('returns false when no backup exists', () async {
        final hasBackup = await service.hasBackup();
        expect(hasBackup, false);
      });

      test('returns true when backup exists', () async {
        // Create a backup first
        final backup = DirtyRecordBackup(
          backupCreatedAt: DateTime.now(),
          appVersion: '1.12.1',
          schemaVersion: 3,
          userId: 'test-user-id',
          dirtyRecords: {
            'activities': [
              {'id': '1', 'name': 'Test Activity'},
            ],
          },
          uploadErrors: [],
        );

        await service.backupDirtyRecords(backup);

        final hasBackup = await service.hasBackup();
        expect(hasBackup, true);
      });
    });

    group('backupDirtyRecords', () {
      test('creates backup file successfully', () async {
        final backup = DirtyRecordBackup(
          backupCreatedAt: DateTime(2026, 1, 18, 10, 30),
          appVersion: '1.12.1',
          schemaVersion: 3,
          userId: 'user-123',
          dirtyRecords: {
            'activities': [
              {'id': 'act-1', 'name': 'Morning Run'},
              {'id': 'act-2', 'name': 'Evening Run'},
            ],
            'events': [],
          },
          uploadErrors: [
            UploadError(
              repository: 'activities',
              error: 'Network timeout',
              timestamp: DateTime(2026, 1, 18, 10, 29),
              retryAttempts: 3,
            ),
          ],
        );

        await service.backupDirtyRecords(backup);

        final hasBackup = await service.hasBackup();
        expect(hasBackup, true);
      });

      test('overwrites existing backup', () async {
        // Create first backup
        final backup1 = DirtyRecordBackup(
          backupCreatedAt: DateTime(2026, 1, 18, 10, 0),
          appVersion: '1.12.0',
          schemaVersion: 2,
          userId: 'user-123',
          dirtyRecords: {
            'activities': [
              {'id': 'old-1'},
            ],
          },
          uploadErrors: [],
        );

        await service.backupDirtyRecords(backup1);

        // Create second backup
        final backup2 = DirtyRecordBackup(
          backupCreatedAt: DateTime(2026, 1, 18, 10, 30),
          appVersion: '1.12.1',
          schemaVersion: 3,
          userId: 'user-456',
          dirtyRecords: {
            'events': [
              {'id': 'new-1'},
            ],
          },
          uploadErrors: [],
        );

        await service.backupDirtyRecords(backup2);

        // Recover and verify it's the second backup
        final recovered = await service.recoverBackup();
        expect(recovered, isNotNull);
        expect(recovered!.userId, 'user-456');
        expect(recovered.appVersion, '1.12.1');
        expect(recovered.dirtyRecords.containsKey('events'), true);
      });
    });

    group('recoverBackup', () {
      test('returns null when no backup exists', () async {
        final recovered = await service.recoverBackup();
        expect(recovered, isNull);
      });

      test('recovers backup successfully', () async {
        final originalBackup = DirtyRecordBackup(
          backupCreatedAt: DateTime(2026, 1, 18, 10, 30),
          appVersion: '1.12.1',
          schemaVersion: 3,
          userId: 'user-123',
          dirtyRecords: {
            'activities': [
              {'id': 'act-1', 'name': 'Morning Run', 'distance': 5000},
              {'id': 'act-2', 'name': 'Evening Run', 'distance': 3000},
            ],
            'events': [
              {'id': 'evt-1', 'name': 'Marathon'},
            ],
          },
          uploadErrors: [
            UploadError(
              repository: 'activities',
              error: 'Network timeout',
              timestamp: DateTime(2026, 1, 18, 10, 29),
              retryAttempts: 3,
            ),
          ],
        );

        await service.backupDirtyRecords(originalBackup);

        final recovered = await service.recoverBackup();

        expect(recovered, isNotNull);
        expect(recovered!.appVersion, '1.12.1');
        expect(recovered.schemaVersion, 3);
        expect(recovered.userId, 'user-123');
        expect(recovered.backupCreatedAt, DateTime(2026, 1, 18, 10, 30));
        expect(recovered.dirtyRecords.length, 2);
        expect(recovered.dirtyRecords['activities']?.length, 2);
        expect(recovered.dirtyRecords['events']?.length, 1);
        expect(recovered.uploadErrors.length, 1);
        expect(recovered.uploadErrors[0].repository, 'activities');
        expect(recovered.uploadErrors[0].retryAttempts, 3);
      });

      test('returns null on corrupted backup file', () async {
        // Create corrupted backup file
        final backupPath = await service.getBackupFilePath();
        final backupFile = File(backupPath);
        await backupFile.writeAsString('{ corrupted json }');

        final recovered = await service.recoverBackup();
        expect(recovered, isNull);
      });
    });

    group('deleteBackup', () {
      test('deletes backup file successfully', () async {
        // Create a backup first
        final backup = DirtyRecordBackup(
          backupCreatedAt: DateTime.now(),
          appVersion: '1.12.1',
          schemaVersion: 3,
          userId: 'user-123',
          dirtyRecords: {
            'activities': [
              {'id': '1'},
            ],
          },
          uploadErrors: [],
        );

        await service.backupDirtyRecords(backup);
        expect(await service.hasBackup(), true);

        await service.deleteBackup();
        expect(await service.hasBackup(), false);
      });

      test('does not throw when no backup exists', () async {
        // Should not throw even if file doesn't exist
        await service.deleteBackup();
        expect(await service.hasBackup(), false);
      });
    });

    group('integration workflow', () {
      test('backup -> recover -> delete workflow', () async {
        // Step 1: Create backup
        final backup = DirtyRecordBackup(
          backupCreatedAt: DateTime(2026, 1, 18, 10, 30),
          appVersion: '1.12.1',
          schemaVersion: 3,
          userId: 'user-123',
          dirtyRecords: {
            'activities': [
              {'id': 'act-1', 'name': 'Morning Run'},
            ],
            'events': [
              {'id': 'evt-1', 'name': 'Marathon'},
            ],
          },
          uploadErrors: [
            UploadError(
              repository: 'activities',
              error: 'Network error',
              timestamp: DateTime(2026, 1, 18, 10, 29),
              retryAttempts: 3,
            ),
          ],
        );

        expect(await service.hasBackup(), false);

        await service.backupDirtyRecords(backup);
        expect(await service.hasBackup(), true);

        // Step 2: Recover backup
        final recovered = await service.recoverBackup();
        expect(recovered, isNotNull);
        expect(recovered!.totalRecordCount, 2);
        expect(recovered.hasDirtyRecords, true);

        // Step 3: Delete backup after successful upload
        await service.deleteBackup();
        expect(await service.hasBackup(), false);

        // Step 4: Verify no backup can be recovered
        final secondRecovery = await service.recoverBackup();
        expect(secondRecovery, isNull);
      });
    });
  });

  group('DirtyRecordBackup model', () {
    group('helper methods', () {
      test('hasDirtyRecords returns true when records exist', () {
        final backup = DirtyRecordBackup(
          backupCreatedAt: DateTime.now(),
          appVersion: '1.0.0',
          schemaVersion: 1,
          userId: 'user-1',
          dirtyRecords: {
            'activities': [
              {'id': '1'},
            ],
          },
          uploadErrors: [],
        );

        expect(backup.hasDirtyRecords, true);
      });

      test('hasDirtyRecords returns false when no records', () {
        final backup = DirtyRecordBackup(
          backupCreatedAt: DateTime.now(),
          appVersion: '1.0.0',
          schemaVersion: 1,
          userId: 'user-1',
          dirtyRecords: {
            'activities': [],
            'events': [],
          },
          uploadErrors: [],
        );

        expect(backup.hasDirtyRecords, false);
      });

      test('totalRecordCount sums all records', () {
        final backup = DirtyRecordBackup(
          backupCreatedAt: DateTime.now(),
          appVersion: '1.0.0',
          schemaVersion: 1,
          userId: 'user-1',
          dirtyRecords: {
            'activities': [
              {'id': '1'},
              {'id': '2'},
            ],
            'events': [
              {'id': '3'},
            ],
            'feedback': [],
          },
          uploadErrors: [],
        );

        expect(backup.totalRecordCount, 3);
      });
    });

    group('JSON serialization', () {
      test('toJson and fromJson are symmetric', () {
        final original = DirtyRecordBackup(
          backupCreatedAt: DateTime(2026, 1, 18, 10, 30),
          appVersion: '1.12.1',
          schemaVersion: 3,
          userId: 'user-123',
          dirtyRecords: {
            'activities': [
              {'id': 'act-1', 'name': 'Run'},
            ],
          },
          uploadErrors: [
            UploadError(
              repository: 'activities',
              error: 'Error',
              timestamp: DateTime(2026, 1, 18, 10, 29),
              retryAttempts: 2,
            ),
          ],
        );

        final json = original.toJson();
        final restored = DirtyRecordBackup.fromJson(json);

        expect(restored.backupCreatedAt, original.backupCreatedAt);
        expect(restored.appVersion, original.appVersion);
        expect(restored.schemaVersion, original.schemaVersion);
        expect(restored.userId, original.userId);
        expect(restored.dirtyRecords.length, original.dirtyRecords.length);
        expect(restored.uploadErrors.length, original.uploadErrors.length);
      });
    });
  });

  group('UploadError model', () {
    group('JSON serialization', () {
      test('toJson and fromJson are symmetric', () {
        final original = UploadError(
          repository: 'activities',
          error: 'Network timeout',
          timestamp: DateTime(2026, 1, 18, 10, 30),
          retryAttempts: 3,
        );

        final json = original.toJson();
        final restored = UploadError.fromJson(json);

        expect(restored.repository, original.repository);
        expect(restored.error, original.error);
        expect(restored.timestamp, original.timestamp);
        expect(restored.retryAttempts, original.retryAttempts);
      });

      test('handles missing retryAttempts gracefully', () {
        final json = {
          'repository': 'events',
          'error': 'Server error',
          'timestamp': DateTime(2026, 1, 18).toIso8601String(),
        };

        final restored = UploadError.fromJson(json);

        expect(restored.repository, 'events');
        expect(restored.error, 'Server error');
        expect(restored.retryAttempts, 0);
      });
    });
  });
}
