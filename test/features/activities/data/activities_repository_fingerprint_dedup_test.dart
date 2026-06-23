import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/application/activity_deduplication_service.dart';
import 'package:mealvana_endurance/features/activities/data/activities_repository.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart'
    hide Activity;
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Mocks
class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockAppLogger extends Mock implements AppLogger {}

class MockSentryReporter extends Mock implements SentryReporter {}

class MockActivityDeduplicationService extends Mock
    implements ActivityDeduplicationService {}

/// Regression tests for Bug 385e3fdb: a run created in-app (no provider
/// linkage) and the same run synced back from Garmin/Final Surge produced two
/// duplicate activity rows. The cross-origin fingerprint match reconciles them
/// into one row.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late MockSupabaseClient mockSupabase;
  late MockAppLogger mockLogger;
  late MockSentryReporter mockSentry;
  late ActivitiesRepository repository;

  const userId = 'user-385e';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase.forTesting(NativeDatabase.memory());

    mockSupabase = MockSupabaseClient();
    mockLogger = MockAppLogger();
    mockSentry = MockSentryReporter();

    when(() => mockLogger.info(any(),
        context: any(named: 'context'),
        data: any(named: 'data'))).thenReturn(null);
    when(() => mockLogger.debug(any(),
        context: any(named: 'context'),
        data: any(named: 'data'))).thenReturn(null);
    when(() => mockLogger.warning(any(),
        context: any(named: 'context'),
        error: any(named: 'error'),
        stackTrace: any(named: 'stackTrace'),
        data: any(named: 'data'))).thenReturn(null);
    when(() => mockLogger.error(any(),
        context: any(named: 'context'),
        error: any(named: 'error'),
        stackTrace: any(named: 'stackTrace'),
        data: any(named: 'data'))).thenReturn(null);

    when(() => mockSentry.reportNetworkError(any(),
        url: any(named: 'url'),
        method: any(named: 'method'),
        statusCode: any(named: 'statusCode'),
        timeout: any(named: 'timeout'),
        stackTrace: any(named: 'stackTrace'))).thenAnswer((_) async {});

    repository = ActivitiesRepository(
      supabase: mockSupabase,
      database: database,
      logger: mockLogger,
      sentry: mockSentry,
      deduplicationService: MockActivityDeduplicationService(),
    );
  });

  tearDown(() async {
    await database.close();
  });

  Activity buildActivity({
    required String title,
    required DateTime scheduledDateTime,
    double? distanceMiles,
    String? syncedFromProvider,
    String? providerWorkoutId,
    String? garminDeviceName,
    Map<String, dynamic>? nutritionPlanData,
    ActivityType activityType = ActivityType.running,
  }) {
    final now = DateTime.now();
    return Activity(
      id: '',
      userId: userId,
      activityType: activityType,
      title: title,
      scheduledDateTime: scheduledDateTime,
      distanceMiles: distanceMiles,
      nutritionPlanData: nutritionPlanData,
      syncedFromProvider: syncedFromProvider,
      providerWorkoutId: providerWorkoutId,
      garminDeviceName: garminDeviceName,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('findActivityByFingerprint', () {
    test('matches a user-created run on same type, day, and distance', () async {
      await repository.insertActivity(buildActivity(
        title: 'Long Run',
        scheduledDateTime: DateTime(2026, 6, 19, 5, 0),
        distanceMiles: 14.0,
      ));

      final match = await repository.findActivityByFingerprint(
        userId: userId,
        activityType: ActivityType.running,
        scheduledDate: DateTime(2026, 6, 19, 5, 36),
        distanceMiles: 14.0,
      );

      expect(match, isNotNull);
      expect(match!.distanceMiles, 14.0);
      expect(match.providerWorkoutId, anyOf(isNull, isEmpty));
    });

    test('matches within a +/- 1 day window', () async {
      await repository.insertActivity(buildActivity(
        title: 'Long Run',
        scheduledDateTime: DateTime(2026, 6, 19, 5, 0),
        distanceMiles: 14.0,
      ));

      final nextDay = await repository.findActivityByFingerprint(
        userId: userId,
        activityType: ActivityType.running,
        scheduledDate: DateTime(2026, 6, 20, 6, 0),
        distanceMiles: 14.0,
      );
      expect(nextDay, isNotNull, reason: '+1 day should match');

      final tooFar = await repository.findActivityByFingerprint(
        userId: userId,
        activityType: ActivityType.running,
        scheduledDate: DateTime(2026, 6, 22, 6, 0),
        distanceMiles: 14.0,
      );
      expect(tooFar, isNull, reason: '+3 days is outside the window');
    });

    test('does not match when distance differs by more than 10%', () async {
      await repository.insertActivity(buildActivity(
        title: 'Long Run',
        scheduledDateTime: DateTime(2026, 6, 19, 5, 0),
        distanceMiles: 14.0,
      ));

      final match = await repository.findActivityByFingerprint(
        userId: userId,
        activityType: ActivityType.running,
        scheduledDate: DateTime(2026, 6, 19, 5, 36),
        distanceMiles: 8.0,
      );
      expect(match, isNull);
    });

    test('does not match a provider-linked row (provider-key path owns those)',
        () async {
      await repository.insertActivity(buildActivity(
        title: 'Synced Run',
        scheduledDateTime: DateTime(2026, 6, 19, 5, 0),
        distanceMiles: 14.0,
        syncedFromProvider: 'final_surge',
        providerWorkoutId: 'fs-existing',
      ));

      final match = await repository.findActivityByFingerprint(
        userId: userId,
        activityType: ActivityType.running,
        scheduledDate: DateTime(2026, 6, 19, 5, 36),
        distanceMiles: 14.0,
      );
      expect(match, isNull);
    });

    test('does not match a different activity type', () async {
      await repository.insertActivity(buildActivity(
        title: 'Ride',
        scheduledDateTime: DateTime(2026, 6, 19, 5, 0),
        distanceMiles: 14.0,
        activityType: ActivityType.cycling,
      ));

      final match = await repository.findActivityByFingerprint(
        userId: userId,
        activityType: ActivityType.running,
        scheduledDate: DateTime(2026, 6, 19, 5, 36),
        distanceMiles: 14.0,
      );
      expect(match, isNull);
    });
  });

  group('insertActivity cross-origin reconciliation', () {
    test(
        'provider import merges onto the in-app run instead of duplicating',
        () async {
      // 1. User creates a 14-mile run in-app (no provider linkage), with a
      //    nutrition plan attached.
      await repository.insertActivity(buildActivity(
        title: 'Long Run',
        scheduledDateTime: DateTime(2026, 6, 19, 5, 0),
        distanceMiles: 14.0,
        nutritionPlanData: {'carbs_g': 90},
      ));

      // 2. The same run completes and syncs back from Final Surge with the
      //    actual start time, plus a Garmin device badge.
      await repository.insertActivity(buildActivity(
        title: 'Long Run',
        scheduledDateTime: DateTime(2026, 6, 19, 5, 36),
        distanceMiles: 14.0,
        syncedFromProvider: 'final_surge',
        providerWorkoutId: 'fs-123',
        garminDeviceName: 'Forerunner',
      ));

      // 3. Exactly ONE activity row should remain.
      final rows = await database.select(database.activitiesTable).get();
      expect(rows.length, 1, reason: 'cross-origin rows must reconcile to one');

      final row = rows.single;
      // Adopted the provider linkage + device badge ...
      expect(row.providerWorkoutId, 'fs-123');
      expect(row.syncedFromProvider, 'final_surge');
      expect(row.garminDeviceName, 'Forerunner');
      // ... while preserving the locally-authored nutrition plan.
      expect(row.nutritionPlanData, isNotNull);
      expect(row.nutritionPlanData, contains('carbs_g'));
    });
  });
}
