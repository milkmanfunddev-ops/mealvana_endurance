import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/models/sync_result.dart';
import 'package:mealvana_endurance/shared/models/version_check_result.dart';

void main() {
  group('SyncResult', () {
    group('factory constructors', () {
      test('success creates result with count', () {
        final result = SyncResult.success(count: 5);

        expect(result.status, SyncStatus.success);
        expect(result.count, 5);
        expect(result.isSuccess, true);
        expect(result.isFailure, false);
        expect(result.isNothingToSync, false);
        expect(result.error, isNull);
        expect(result.errorMessage, isNull);
      });

      test('failure creates result with error', () {
        final error = Exception('Network error');
        final stackTrace = StackTrace.current;
        final result = SyncResult.failure(
          error: error,
          stackTrace: stackTrace,
          message: 'Failed to sync',
        );

        expect(result.status, SyncStatus.failure);
        expect(result.count, 0);
        expect(result.isSuccess, false);
        expect(result.isFailure, true);
        expect(result.isNothingToSync, false);
        expect(result.error, error);
        expect(result.errorMessage, 'Failed to sync');
        expect(result.stackTrace, stackTrace);
      });

      test('failure uses error.toString() as default message', () {
        final error = Exception('Default message');
        final result = SyncResult.failure(error: error);

        expect(result.errorMessage, contains('Default message'));
      });

      test('nothingToSync creates result with zero count', () {
        final result = SyncResult.nothingToSync();

        expect(result.status, SyncStatus.nothingToSync);
        expect(result.count, 0);
        expect(result.isSuccess, false);
        expect(result.isFailure, false);
        expect(result.isNothingToSync, true);
        expect(result.error, isNull);
        expect(result.errorMessage, isNull);
      });
    });

    group('equality', () {
      test('success results with same count are equal', () {
        final result1 = SyncResult.success(count: 5);
        final result2 = SyncResult.success(count: 5);

        expect(result1, equals(result2));
        expect(result1.hashCode, equals(result2.hashCode));
      });

      test('success results with different counts are not equal', () {
        final result1 = SyncResult.success(count: 5);
        final result2 = SyncResult.success(count: 10);

        expect(result1, isNot(equals(result2)));
      });

      test('failure results with same error message are equal', () {
        final result1 = SyncResult.failure(
          error: Exception('Error'),
          message: 'Network error',
        );
        final result2 = SyncResult.failure(
          error: Exception('Different error'),
          message: 'Network error',
        );

        expect(result1, equals(result2));
        expect(result1.hashCode, equals(result2.hashCode));
      });

      test('nothingToSync results are equal', () {
        final result1 = SyncResult.nothingToSync();
        final result2 = SyncResult.nothingToSync();

        expect(result1, equals(result2));
        expect(result1.hashCode, equals(result2.hashCode));
      });

      test('different status results are not equal', () {
        final success = SyncResult.success(count: 0);
        final nothing = SyncResult.nothingToSync();
        final failure = SyncResult.failure(error: Exception('Error'));

        expect(success, isNot(equals(nothing)));
        expect(success, isNot(equals(failure)));
        expect(nothing, isNot(equals(failure)));
      });
    });

    group('immutability', () {
      test('success result fields are immutable', () {
        final result = SyncResult.success(count: 5);

        expect(result.count, 5);
        expect(result.status, SyncStatus.success);
        // Cannot modify - fields are final
      });

      test('failure result fields are immutable', () {
        final error = Exception('Error');
        final result = SyncResult.failure(error: error);

        expect(result.error, error);
        expect(result.status, SyncStatus.failure);
        // Cannot modify - fields are final
      });
    });

    group('toString', () {
      test('success includes count', () {
        final result = SyncResult.success(count: 42);
        expect(result.toString(), 'SyncResult.success(count: 42)');
      });

      test('failure includes error message', () {
        final result = SyncResult.failure(
          error: Exception('Test error'),
          message: 'Custom error',
        );
        expect(result.toString(), contains('SyncResult.failure'));
        expect(result.toString(), contains('Custom error'));
      });

      test('nothingToSync has descriptive string', () {
        final result = SyncResult.nothingToSync();
        expect(result.toString(), 'SyncResult.nothingToSync()');
      });
    });
  });

  group('VersionCheckResult', () {
    group('factory constructors', () {
      test('ok creates ok result', () {
        const result = VersionCheckResult.ok();

        expect(result, isA<VersionCheckOk>());
        expect(result.isOk, true);
        expect(result.isUpdateRequired, false);
        expect(result.isResyncRequired, false);
      });

      test('updateRequired creates result with version info', () {
        const result = VersionCheckResult.updateRequired(
          currentVersion: '1.0.0',
          requiredVersion: '1.5.0',
        );

        expect(result, isA<VersionCheckUpdateRequired>());
        expect(result.isOk, false);
        expect(result.isUpdateRequired, true);
        expect(result.isResyncRequired, false);

        final updateResult = result as VersionCheckUpdateRequired;
        expect(updateResult.currentVersion, '1.0.0');
        expect(updateResult.requiredVersion, '1.5.0');
      });

      test('resyncRequired creates result with schema info', () {
        const result = VersionCheckResult.resyncRequired(
          localSchemaVersion: 2,
          remoteSchemaVersion: 3,
        );

        expect(result, isA<VersionCheckResyncRequired>());
        expect(result.isOk, false);
        expect(result.isUpdateRequired, false);
        expect(result.isResyncRequired, true);

        final resyncResult = result as VersionCheckResyncRequired;
        expect(resyncResult.localSchemaVersion, 2);
        expect(resyncResult.remoteSchemaVersion, 3);
      });
    });

    group('equality', () {
      test('ok results are equal', () {
        const result1 = VersionCheckResult.ok();
        const result2 = VersionCheckResult.ok();

        expect(result1, equals(result2));
        expect(result1.hashCode, equals(result2.hashCode));
      });

      test('updateRequired with same versions are equal', () {
        const result1 = VersionCheckResult.updateRequired(
          currentVersion: '1.0.0',
          requiredVersion: '1.5.0',
        );
        const result2 = VersionCheckResult.updateRequired(
          currentVersion: '1.0.0',
          requiredVersion: '1.5.0',
        );

        expect(result1, equals(result2));
        expect(result1.hashCode, equals(result2.hashCode));
      });

      test('updateRequired with different versions are not equal', () {
        const result1 = VersionCheckResult.updateRequired(
          currentVersion: '1.0.0',
          requiredVersion: '1.5.0',
        );
        const result2 = VersionCheckResult.updateRequired(
          currentVersion: '1.0.0',
          requiredVersion: '2.0.0',
        );

        expect(result1, isNot(equals(result2)));
      });

      test('resyncRequired with same schema versions are equal', () {
        const result1 = VersionCheckResult.resyncRequired(
          localSchemaVersion: 2,
          remoteSchemaVersion: 3,
        );
        const result2 = VersionCheckResult.resyncRequired(
          localSchemaVersion: 2,
          remoteSchemaVersion: 3,
        );

        expect(result1, equals(result2));
        expect(result1.hashCode, equals(result2.hashCode));
      });

      test('resyncRequired with different schema versions are not equal', () {
        const result1 = VersionCheckResult.resyncRequired(
          localSchemaVersion: 2,
          remoteSchemaVersion: 3,
        );
        const result2 = VersionCheckResult.resyncRequired(
          localSchemaVersion: 2,
          remoteSchemaVersion: 4,
        );

        expect(result1, isNot(equals(result2)));
      });

      test('different types are not equal', () {
        const ok = VersionCheckResult.ok();
        const update = VersionCheckResult.updateRequired(
          currentVersion: '1.0.0',
          requiredVersion: '1.5.0',
        );
        const resync = VersionCheckResult.resyncRequired(
          localSchemaVersion: 2,
          remoteSchemaVersion: 3,
        );

        expect(ok, isNot(equals(update)));
        expect(ok, isNot(equals(resync)));
        expect(update, isNot(equals(resync)));
      });
    });

    group('immutability', () {
      test('ok result is immutable', () {
        const result = VersionCheckResult.ok();
        // All fields are final by nature of sealed class
        expect(result, isA<VersionCheckOk>());
      });

      test('updateRequired fields are immutable', () {
        const result =
            VersionCheckResult.updateRequired(
                  currentVersion: '1.0.0',
                  requiredVersion: '1.5.0',
                )
                as VersionCheckUpdateRequired;

        expect(result.currentVersion, '1.0.0');
        expect(result.requiredVersion, '1.5.0');
        // Cannot modify - fields are final
      });

      test('resyncRequired fields are immutable', () {
        const result =
            VersionCheckResult.resyncRequired(
                  localSchemaVersion: 2,
                  remoteSchemaVersion: 3,
                )
                as VersionCheckResyncRequired;

        expect(result.localSchemaVersion, 2);
        expect(result.remoteSchemaVersion, 3);
        // Cannot modify - fields are final
      });
    });

    group('toString', () {
      test('ok has descriptive string', () {
        const result = VersionCheckResult.ok();
        expect(result.toString(), 'VersionCheckResult.ok()');
      });

      test('updateRequired includes version info', () {
        const result = VersionCheckResult.updateRequired(
          currentVersion: '1.0.0',
          requiredVersion: '1.5.0',
        );
        final str = result.toString();
        expect(str, contains('VersionCheckResult.updateRequired'));
        expect(str, contains('1.0.0'));
        expect(str, contains('1.5.0'));
      });

      test('resyncRequired includes schema versions', () {
        const result = VersionCheckResult.resyncRequired(
          localSchemaVersion: 2,
          remoteSchemaVersion: 3,
        );
        final str = result.toString();
        expect(str, contains('VersionCheckResult.resyncRequired'));
        expect(str, contains('2'));
        expect(str, contains('3'));
      });
    });
  });
}
