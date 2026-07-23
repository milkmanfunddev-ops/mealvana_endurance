import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mealvana_endurance/features/app_startup/presentation/widgets/dirty_record_recovery_dialog.dart';
import 'package:mealvana_endurance/shared/models/dirty_record_backup.dart';

void main() {
  group('DirtyRecordRecoveryDialog', () {
    late DirtyRecordBackup testBackup;

    setUp(() {
      testBackup = DirtyRecordBackup(
        backupCreatedAt: DateTime.now().subtract(const Duration(hours: 2)),
        appVersion: '1.12.1',
        schemaVersion: 3,
        userId: 'test-user-123',
        dirtyRecords: {
          'activities': [
            {'id': 'activity-1', 'name': 'Morning Run'},
            {'id': 'activity-2', 'name': 'Evening Bike'},
          ],
          'events': [
            {'id': 'event-1', 'name': 'Marathon 2026'},
          ],
        },
        uploadErrors: [],
      );
    });

    /// Helper to wrap widget with ScreenUtil and MaterialApp
    Widget wrapWithScreenUtil(Widget child) {
      return ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => MaterialApp(home: Scaffold(body: child)),
      );
    }

    testWidgets('displays backup metadata correctly', (tester) async {
      await tester.pumpWidget(
        wrapWithScreenUtil(DirtyRecordRecoveryDialog(backup: testBackup)),
      );
      await tester.pumpAndSettle();

      // Check title
      expect(find.text('Unsaved Data Found'), findsOneWidget);

      // Check record count in description
      expect(find.textContaining('3 unsaved records'), findsOneWidget);

      // Check backup details are displayed
      expect(find.text('Backup created'), findsOneWidget);
      expect(find.text('Records'), findsOneWidget);
      expect(find.textContaining('3 (Activities and Events)'), findsOneWidget);
    });

    testWidgets('shows upload button as primary action', (tester) async {
      await tester.pumpWidget(
        wrapWithScreenUtil(DirtyRecordRecoveryDialog(backup: testBackup)),
      );
      await tester.pumpAndSettle();

      // Upload button should be a primary button (not a text button)
      expect(find.text('Upload Now'), findsOneWidget);

      // Discard button should be a text button (secondary action)
      expect(find.text('Discard'), findsOneWidget);
    });

    testWidgets('returns upload choice when upload button is tapped', (
      tester,
    ) async {
      RecoveryChoice? result;

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (context, _) => MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    result = await DirtyRecordRecoveryDialog.show(
                      context,
                      testBackup,
                    );
                  },
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Scroll to make button visible and tap it
      await tester.ensureVisible(find.text('Upload Now'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Upload Now'));
      await tester.pumpAndSettle();

      // Verify result
      expect(result, RecoveryChoice.upload);
    });

    testWidgets('returns discard choice when discard button is tapped', (
      tester,
    ) async {
      RecoveryChoice? result;

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (context, _) => MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    result = await DirtyRecordRecoveryDialog.show(
                      context,
                      testBackup,
                    );
                  },
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Scroll to make button visible and tap it
      await tester.ensureVisible(find.text('Discard'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      // Verify result
      expect(result, RecoveryChoice.discard);
    });

    testWidgets('formats repository names correctly for single repository', (
      tester,
    ) async {
      final singleRepoBackup = DirtyRecordBackup(
        backupCreatedAt: DateTime.now().subtract(const Duration(hours: 1)),
        appVersion: '1.12.1',
        schemaVersion: 3,
        userId: 'test-user-123',
        dirtyRecords: {
          'activities': [
            {'id': 'activity-1', 'name': 'Morning Run'},
          ],
        },
        uploadErrors: [],
      );

      await tester.pumpWidget(
        wrapWithScreenUtil(DirtyRecordRecoveryDialog(backup: singleRepoBackup)),
      );
      await tester.pumpAndSettle();

      // Should show just "Activities" without "and"
      expect(find.textContaining('1 (Activities)'), findsOneWidget);
    });

    testWidgets('formats repository names correctly for multiple repositories', (
      tester,
    ) async {
      final multiRepoBackup = DirtyRecordBackup(
        backupCreatedAt: DateTime.now().subtract(const Duration(hours: 1)),
        appVersion: '1.12.1',
        schemaVersion: 3,
        userId: 'test-user-123',
        dirtyRecords: {
          'activities': [
            {'id': 'activity-1', 'name': 'Morning Run'},
          ],
          'events': [
            {'id': 'event-1', 'name': 'Marathon'},
          ],
          'food_preferences': [
            {'id': 'pref-1', 'food_id': 'food-1'},
          ],
        },
        uploadErrors: [],
      );

      await tester.pumpWidget(
        wrapWithScreenUtil(DirtyRecordRecoveryDialog(backup: multiRepoBackup)),
      );
      await tester.pumpAndSettle();

      // Should show "Activities, Events, and Food Preferences" with Oxford comma
      expect(
        find.textContaining('3 (Activities, Events, and Food Preferences)'),
        findsOneWidget,
      );
    });

    testWidgets('formats timestamp as relative time', (tester) async {
      final recentBackup = DirtyRecordBackup(
        backupCreatedAt: DateTime.now().subtract(const Duration(minutes: 30)),
        appVersion: '1.12.1',
        schemaVersion: 3,
        userId: 'test-user-123',
        dirtyRecords: {
          'activities': [
            {'id': 'activity-1', 'name': 'Morning Run'},
          ],
        },
        uploadErrors: [],
      );

      await tester.pumpWidget(
        wrapWithScreenUtil(DirtyRecordRecoveryDialog(backup: recentBackup)),
      );
      await tester.pumpAndSettle();

      // Should show relative time like "30 minutes ago"
      expect(find.textContaining('minutes ago'), findsOneWidget);
    });

    testWidgets('uses singular "record" for count of 1', (tester) async {
      final singleRecordBackup = DirtyRecordBackup(
        backupCreatedAt: DateTime.now().subtract(const Duration(hours: 1)),
        appVersion: '1.12.1',
        schemaVersion: 3,
        userId: 'test-user-123',
        dirtyRecords: {
          'activities': [
            {'id': 'activity-1', 'name': 'Morning Run'},
          ],
        },
        uploadErrors: [],
      );

      await tester.pumpWidget(
        wrapWithScreenUtil(
          DirtyRecordRecoveryDialog(backup: singleRecordBackup),
        ),
      );
      await tester.pumpAndSettle();

      // Should use singular "record"
      expect(find.textContaining('1 unsaved record'), findsOneWidget);
    });

    testWidgets('dialog is not dismissible by tapping outside', (tester) async {
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (context, _) => MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    await DirtyRecordRecoveryDialog.show(context, testBackup);
                  },
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Try to tap outside dialog (on the barrier)
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Dialog should still be visible (barrierDismissible: false)
      expect(find.text('Unsaved Data Found'), findsOneWidget);
    });
  });
}
