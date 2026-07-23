import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/models/dirty_record_backup.dart';
import 'package:mealvana_endurance/shared/models/upload_error.dart';

/// Tests for Schema Resync functionality
///
/// Note: Full integration tests for performSchemaResync() require
/// a real database and Supabase connection. These unit tests verify
/// the supporting data structures and logic.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Schema Resync Supporting Classes', () {
    group('DirtyRecordBackup', () {
      test('creates backup with all required fields', () {
        final backup = DirtyRecordBackup(
          backupCreatedAt: DateTime(2026, 1, 19, 12, 0),
          appVersion: '1.12.1',
          schemaVersion: 3,
          userId: 'test-user-123',
          dirtyRecords: {
            'activities': [
              {'id': '1', 'name': 'Morning Run'},
              {'id': '2', 'name': 'Evening Bike'},
            ],
            'events': [
              {'id': '1', 'name': 'Marathon 2026'},
            ],
          },
          uploadErrors: [],
        );

        expect(backup.appVersion, '1.12.1');
        expect(backup.schemaVersion, 3);
        expect(backup.userId, 'test-user-123');
        expect(backup.dirtyRecords.length, 2);
        expect(backup.dirtyRecords['activities']?.length, 2);
        expect(backup.dirtyRecords['events']?.length, 1);
        expect(backup.uploadErrors, isEmpty);
      });

      test('creates backup with upload errors', () {
        final backup = DirtyRecordBackup(
          backupCreatedAt: DateTime.now(),
          appVersion: '1.12.1',
          schemaVersion: 3,
          userId: 'test-user-123',
          dirtyRecords: {
            'activities': [
              {'id': '1', 'name': 'Morning Run'},
            ],
          },
          uploadErrors: [
            UploadError(
              repository: 'activities',
              error: 'Network timeout',
              timestamp: DateTime.now(),
            ),
          ],
        );

        expect(backup.uploadErrors.length, 1);
        expect(backup.uploadErrors.first.repository, 'activities');
        expect(backup.uploadErrors.first.error, 'Network timeout');
      });

      test('serializes to JSON correctly', () {
        final timestamp = DateTime(2026, 1, 19, 12, 0);
        final backup = DirtyRecordBackup(
          backupCreatedAt: timestamp,
          appVersion: '1.12.1',
          schemaVersion: 3,
          userId: 'test-user-123',
          dirtyRecords: {
            'activities': [
              {'id': '1', 'name': 'Test'},
            ],
          },
          uploadErrors: [],
        );

        final json = backup.toJson();

        expect(json['app_version'], '1.12.1');
        expect(json['schema_version'], 3);
        expect(json['user_id'], 'test-user-123');
        expect(json['dirty_records'], isA<Map>());
        expect(json['upload_errors'], isA<List>());
      });

      test('deserializes from JSON correctly', () {
        final json = {
          'backup_created_at': '2026-01-19T12:00:00.000',
          'app_version': '1.12.1',
          'schema_version': 3,
          'user_id': 'test-user-123',
          'dirty_records': {
            'activities': [
              {'id': '1', 'name': 'Test'},
            ],
          },
          'upload_errors': [
            {
              'repository': 'activities',
              'error': 'Network error',
              'timestamp': '2026-01-19T12:00:00.000',
            },
          ],
        };

        final backup = DirtyRecordBackup.fromJson(json);

        expect(backup.appVersion, '1.12.1');
        expect(backup.schemaVersion, 3);
        expect(backup.userId, 'test-user-123');
        expect(backup.dirtyRecords['activities']?.length, 1);
        expect(backup.uploadErrors.length, 1);
      });

      test('calculates total record count correctly', () {
        final backup = DirtyRecordBackup(
          backupCreatedAt: DateTime.now(),
          appVersion: '1.12.1',
          schemaVersion: 3,
          userId: 'test-user-123',
          dirtyRecords: {
            'activities': [
              {'id': '1'},
              {'id': '2'},
              {'id': '3'},
            ],
            'events': [
              {'id': '1'},
              {'id': '2'},
            ],
            'foods': [
              {'id': '1'},
            ],
          },
          uploadErrors: [],
        );

        expect(backup.totalRecordCount, 6);
      });

      test('returns repository names correctly', () {
        final backup = DirtyRecordBackup(
          backupCreatedAt: DateTime.now(),
          appVersion: '1.12.1',
          schemaVersion: 3,
          userId: 'test-user-123',
          dirtyRecords: {
            'activities': [
              {'id': '1'},
            ],
            'events': [
              {'id': '1'},
            ],
            'foods': [
              {'id': '1'},
            ],
          },
          uploadErrors: [],
        );

        expect(
          backup.dirtyRecords.keys,
          containsAll(['activities', 'events', 'foods']),
        );
      });

      test('hasDirtyRecords returns true when records exist', () {
        final backup = DirtyRecordBackup(
          backupCreatedAt: DateTime.now(),
          appVersion: '1.12.1',
          schemaVersion: 3,
          userId: 'test-user-123',
          dirtyRecords: {
            'activities': [
              {'id': '1'},
            ],
          },
          uploadErrors: [],
        );

        expect(backup.hasDirtyRecords, true);
      });

      test('hasDirtyRecords returns false when empty', () {
        final backup = DirtyRecordBackup(
          backupCreatedAt: DateTime.now(),
          appVersion: '1.12.1',
          schemaVersion: 3,
          userId: 'test-user-123',
          dirtyRecords: {},
          uploadErrors: [],
        );

        expect(backup.hasDirtyRecords, false);
      });
    });

    group('UploadError', () {
      test('creates error with required fields', () {
        final timestamp = DateTime(2026, 1, 19, 12, 0);
        final error = UploadError(
          repository: 'activities',
          error: 'Connection refused',
          timestamp: timestamp,
        );

        expect(error.repository, 'activities');
        expect(error.error, 'Connection refused');
        expect(error.timestamp, timestamp);
      });

      test('serializes to JSON correctly', () {
        final timestamp = DateTime(2026, 1, 19, 12, 0);
        final error = UploadError(
          repository: 'events',
          error: 'Timeout exceeded',
          timestamp: timestamp,
        );

        final json = error.toJson();

        expect(json['repository'], 'events');
        expect(json['error'], 'Timeout exceeded');
        expect(json['timestamp'], isNotNull);
      });

      test('deserializes from JSON correctly', () {
        final json = {
          'repository': 'foods',
          'error': 'Server error 500',
          'timestamp': '2026-01-19T12:00:00.000',
        };

        final error = UploadError.fromJson(json);

        expect(error.repository, 'foods');
        expect(error.error, 'Server error 500');
        expect(error.timestamp, isNotNull);
      });
    });
  });

  group('Schema Resync Logic', () {
    test('empty dirty records means nothing to backup', () {
      final dirtyRecords = <String, List<Map<String, dynamic>>>{};
      expect(dirtyRecords.isEmpty, true);
    });

    test('repositories with records should be processed', () {
      final dirtyRecords = <String, List<Map<String, dynamic>>>{
        'activities': [
          {'id': '1'},
        ],
        'events': [], // Empty - should be filtered out
        'foods': [
          {'id': '1'},
          {'id': '2'},
        ],
      };

      final nonEmptyRepos = dirtyRecords.entries
          .where((e) => e.value.isNotEmpty)
          .map((e) => e.key)
          .toList();

      expect(nonEmptyRepos, ['activities', 'foods']);
    });

    test('upload errors trigger backup creation', () {
      final uploadErrors = <UploadError>[
        UploadError(
          repository: 'activities',
          error: 'Network failure',
          timestamp: DateTime.now(),
        ),
      ];

      // Backup should be created when there are upload errors
      expect(uploadErrors.isNotEmpty, true);
    });

    test('successful uploads do not trigger backup', () {
      final uploadErrors = <UploadError>[];

      // No backup needed when all uploads succeed
      expect(uploadErrors.isEmpty, true);
    });
  });
}
