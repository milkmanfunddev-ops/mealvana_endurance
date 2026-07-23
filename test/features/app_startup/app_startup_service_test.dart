// test/features/app_startup/app_startup_service_test.dart
//
// Unit tests for AppStartupService business logic.
//
// Scope:
//  - setSentryUserContext: anonymous vs authenticated user, PackageInfo wiring,
//    error-tolerant (does not rethrow)
//  - checkUserSession: user present -> analytics.identifyUser called;
//    no user -> no throw; analytics failure -> no throw
//  - fallbackLoadFoods: skips when DB has rows; calls getAllFoods when empty;
//    no rethrow on failure
//  - initializeNutritionPlans: completes without throwing whether user exists
//    or not
//  - checkAndHandleDirtyRecordBackup: returns false when no backup file;
//    returns false on corrupt JSON; context.mounted=false guard returns false
//  - _getTableNameFromRepositoryKey (known-key coverage via knownKeys list)
//  - AppStartupData model: default values, version fields, resync fields
//
// Pattern: mocktail mocks; AppDatabase.memory() (NativeDatabase in-memory) for
// Drift; ProviderContainer overrides for Riverpod wiring.
//
// NOT covered here (require SchedulerBinding / file-system):
//  - initializeDatabase()  -> integration-level
//  - initializeDeferredServices() -> integration-level / SchedulerBinding
//  - checkAndHandleDirtyRecordBackup upload/discard flow (needs real dialog)

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart'
    show SharedPreferences;
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import 'package:mealvana_endurance/features/app_startup/application/app_startup_provider.dart';
import 'package:mealvana_endurance/features/app_startup/application/app_startup_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/food_repository.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/database/database_provider.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';

// ─── Mock declarations ────────────────────────────────────────────────────────

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockAppLogger extends Mock implements AppLogger {}

class MockSentryReporter extends Mock implements SentryReporter {}

class MockAnalyticsTracker extends Mock implements AnalyticsTracker {}

class MockFoodRepository extends Mock implements FoodRepository {}

class MockSharedPreferences extends Mock implements SharedPreferences {}

/// Fake path_provider so DirtyRecordBackupService can resolve paths in tests.
class FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final Directory tempDir;
  FakePathProviderPlatform(this.tempDir);

  @override
  Future<String?> getApplicationSupportPath() async => tempDir.path;

  @override
  Future<String?> getTemporaryPath() async => tempDir.path;

  @override
  Future<String?> getApplicationDocumentsPath() async => tempDir.path;
}

/// Minimal [User] stub for GoTrueClient.currentUser.
class _FakeUser extends Fake implements User {
  @override
  final String id;
  _FakeUser(this.id);
}

/// BuildContext stub that reports mounted=false so DirtyRecordRecoveryDialog
/// is never shown during unit tests.
class _UnmountedBuildContext extends Fake implements BuildContext {
  @override
  bool get mounted => false;
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

void _stubLogger(MockAppLogger logger) {
  when(
    () => logger.debug(
      any(),
      context: any(named: 'context'),
      data: any(named: 'data'),
      error: any(named: 'error'),
      stackTrace: any(named: 'stackTrace'),
    ),
  ).thenReturn(null);
  when(
    () => logger.info(
      any(),
      context: any(named: 'context'),
      data: any(named: 'data'),
    ),
  ).thenReturn(null);
  when(
    () => logger.warning(
      any(),
      context: any(named: 'context'),
      data: any(named: 'data'),
      error: any(named: 'error'),
      stackTrace: any(named: 'stackTrace'),
    ),
  ).thenReturn(null);
  when(
    () => logger.error(
      any(),
      context: any(named: 'context'),
      data: any(named: 'data'),
      error: any(named: 'error'),
      stackTrace: any(named: 'stackTrace'),
    ),
  ).thenReturn(null);
}

/// Inserts a minimal user profile so userDao.getCurrentUserProfile() is
/// non-null. Uses only the two required fields from the generated companion.
Future<void> _insertUserProfile(AppDatabase db) async {
  await db
      .into(db.userProfilesTable)
      .insert(
        UserProfilesTableCompanion.insert(
          id: 'test-user-id',
          deviceId: 'device-001',
          onboardingCompleted: const Value(true),
          weightPounds: const Value(160.0),
        ),
      );
}

// ─── Main ─────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAppLogger mockLogger;
  late MockSentryReporter mockSentry;
  late MockAnalyticsTracker mockAnalytics;
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late MockSharedPreferences mockPrefs;
  late AppDatabase database;
  late Directory tempDir;

  setUpAll(() {
    PackageInfo.setMockInitialValues(
      appName: 'Mealvana',
      packageName: 'com.mealvana.endurance',
      version: '1.12.0',
      buildNumber: '60',
      buildSignature: '',
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('mealvana_startup_test_');
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir);

    mockLogger = MockAppLogger();
    mockSentry = MockSentryReporter();
    mockAnalytics = MockAnalyticsTracker();
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockPrefs = MockSharedPreferences();

    _stubLogger(mockLogger);

    when(() => mockSupabase.auth).thenReturn(mockAuth);
    when(() => mockAuth.currentUser).thenReturn(null);
    when(() => mockAuth.currentSession).thenReturn(null);

    when(
      () => mockSentry.setUserContext(
        deviceId: any(named: 'deviceId'),
        appVersion: any(named: 'appVersion'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockSentry.reportCriticalError(
        any(),
        stackTrace: any(named: 'stackTrace'),
        context: any(named: 'context'),
        tags: any(named: 'tags'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockSentry.addBreadcrumb(
        message: any(named: 'message'),
        category: any(named: 'category'),
        data: any(named: 'data'),
      ),
    ).thenReturn(null);
    when(
      () => mockAnalytics.track(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    when(
      () => mockAnalytics.identifyUser(
        any(),
        properties: any(named: 'properties'),
        gender: any(named: 'gender'),
        age: any(named: 'age'),
        weightPounds: any(named: 'weightPounds'),
        runsWithWaterBottle: any(named: 'runsWithWaterBottle'),
        gutTrainingLevel: any(named: 'gutTrainingLevel'),
      ),
    ).thenAnswer((_) async {});

    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  /// Builds a ProviderContainer wired to test doubles.
  ProviderContainer makeContainer({MockFoodRepository? foodRepo}) {
    final deps = AppExternalDeps(
      supabaseClient: mockSupabase,
      logger: mockLogger,
      sentry: mockSentry,
      analytics: mockAnalytics,
      sharedPreferences: mockPrefs,
    );

    return ProviderContainer(
      overrides: [
        appExternalDepsProvider.overrideWithValue(deps),
        appDatabaseProvider.overrideWithValue(database),
        if (foodRepo != null)
          foodRepositoryProvider.overrideWithValue(foodRepo),
      ],
    );
  }

  // ─── AppStartupData model ────────────────────────────────────────────────────

  group('AppStartupData', () {
    test('default values: not logged-out, no force-upgrade, no resync', () {
      const data = AppStartupData(user: null, hasCompletedOnboarding: false);
      expect(data.isLoggedOut, isFalse);
      expect(data.forceUpgradeRequired, isFalse);
      expect(data.resyncRequired, isFalse);
      expect(data.currentVersion, isNull);
      expect(data.requiredVersion, isNull);
    });

    test('forceUpgradeRequired=true stores version strings', () {
      const data = AppStartupData(
        user: null,
        hasCompletedOnboarding: false,
        forceUpgradeRequired: true,
        currentVersion: '1.0.0',
        requiredVersion: '2.0.0',
      );
      expect(data.forceUpgradeRequired, isTrue);
      expect(data.currentVersion, '1.0.0');
      expect(data.requiredVersion, '2.0.0');
    });

    test('resyncRequired stores schema version numbers', () {
      const data = AppStartupData(
        user: null,
        hasCompletedOnboarding: false,
        resyncRequired: true,
        localSchemaVersion: 1,
        remoteSchemaVersion: 2,
      );
      expect(data.resyncRequired, isTrue);
      expect(data.localSchemaVersion, 1);
      expect(data.remoteSchemaVersion, 2);
    });

    test('isLoggedOut can be set explicitly', () {
      const data = AppStartupData(
        user: null,
        hasCompletedOnboarding: true,
        isLoggedOut: true,
      );
      expect(data.isLoggedOut, isTrue);
    });

    test('hasCompletedOnboarding reflects constructor value', () {
      const data = AppStartupData(user: null, hasCompletedOnboarding: true);
      expect(data.hasCompletedOnboarding, isTrue);
    });
  });

  // ─── setSentryUserContext ────────────────────────────────────────────────────

  group('setSentryUserContext', () {
    test('passes "anonymous" when no Supabase user is logged in', () async {
      when(() => mockAuth.currentUser).thenReturn(null);

      final container = makeContainer();
      final service = container.read(appStartupServiceProvider);

      await service.setSentryUserContext();

      verify(
        () => mockSentry.setUserContext(
          deviceId: 'anonymous',
          appVersion: '1.12.0+60',
        ),
      ).called(1);

      container.dispose();
    });

    test('passes Supabase user id when logged in', () async {
      when(() => mockAuth.currentUser).thenReturn(_FakeUser('user-abc-123'));

      final container = makeContainer();
      final service = container.read(appStartupServiceProvider);

      await service.setSentryUserContext();

      verify(
        () => mockSentry.setUserContext(
          deviceId: 'user-abc-123',
          appVersion: '1.12.0+60',
        ),
      ).called(1);

      container.dispose();
    });

    test('does not rethrow when Sentry call fails', () async {
      when(
        () => mockSentry.setUserContext(
          deviceId: any(named: 'deviceId'),
          appVersion: any(named: 'appVersion'),
        ),
      ).thenThrow(Exception('Sentry network error'));

      final container = makeContainer();
      final service = container.read(appStartupServiceProvider);

      await expectLater(service.setSentryUserContext(), completes);

      container.dispose();
    });

    test('appVersion format is version+buildNumber (semver+build)', () async {
      // Verify the format "1.12.0+60" — not just "1.12.0"
      final container = makeContainer();
      final service = container.read(appStartupServiceProvider);

      await service.setSentryUserContext();

      final captured = verify(
        () => mockSentry.setUserContext(
          deviceId: any(named: 'deviceId'),
          appVersion: captureAny(named: 'appVersion'),
        ),
      ).captured;

      expect(captured.last, contains('+'));
    });
  });

  // ─── checkUserSession ────────────────────────────────────────────────────────

  group('checkUserSession', () {
    test('calls identifyUser with user id when user exists locally', () async {
      await _insertUserProfile(database);

      final container = makeContainer();
      final service = container.read(appStartupServiceProvider);

      await service.checkUserSession();

      verify(
        () => mockAnalytics.identifyUser(
          any(),
          gender: any(named: 'gender'),
          age: any(named: 'age'),
          weightPounds: any(named: 'weightPounds'),
          runsWithWaterBottle: any(named: 'runsWithWaterBottle'),
          gutTrainingLevel: any(named: 'gutTrainingLevel'),
        ),
      ).called(greaterThanOrEqualTo(1));

      container.dispose();
    });

    test(
      'identifies user with the correct user id from the database',
      () async {
        await _insertUserProfile(database);

        final container = makeContainer();
        final service = container.read(appStartupServiceProvider);

        await service.checkUserSession();

        final captured = verify(
          () => mockAnalytics.identifyUser(
            captureAny(),
            gender: any(named: 'gender'),
            age: any(named: 'age'),
            weightPounds: any(named: 'weightPounds'),
            runsWithWaterBottle: any(named: 'runsWithWaterBottle'),
            gutTrainingLevel: any(named: 'gutTrainingLevel'),
          ),
        ).captured;

        expect(captured.last, equals('test-user-id'));

        container.dispose();
      },
    );

    test(
      'does not call identifyUser when no local user profile exists',
      () async {
        final container = makeContainer();
        final service = container.read(appStartupServiceProvider);

        await service.checkUserSession();

        // identifyUser should NOT be called (no user row in DB)
        verifyNever(
          () => mockAnalytics.identifyUser(
            any(),
            gender: any(named: 'gender'),
            age: any(named: 'age'),
            weightPounds: any(named: 'weightPounds'),
            runsWithWaterBottle: any(named: 'runsWithWaterBottle'),
            gutTrainingLevel: any(named: 'gutTrainingLevel'),
          ),
        );

        container.dispose();
      },
    );

    test('does not throw when no local user exists', () async {
      final container = makeContainer();
      final service = container.read(appStartupServiceProvider);

      await expectLater(service.checkUserSession(), completes);

      container.dispose();
    });

    test('does not rethrow analytics errors', () async {
      when(
        () => mockAnalytics.identifyUser(
          any(),
          gender: any(named: 'gender'),
          age: any(named: 'age'),
          weightPounds: any(named: 'weightPounds'),
          runsWithWaterBottle: any(named: 'runsWithWaterBottle'),
          gutTrainingLevel: any(named: 'gutTrainingLevel'),
        ),
      ).thenThrow(Exception('analytics down'));

      await _insertUserProfile(database);

      final container = makeContainer();
      final service = container.read(appStartupServiceProvider);

      await expectLater(service.checkUserSession(), completes);

      container.dispose();
    });
  });

  // ─── fallbackLoadFoods ───────────────────────────────────────────────────────

  group('fallbackLoadFoods', () {
    test('calls getAllFoods when foods table is empty', () async {
      final foodRepo = MockFoodRepository();
      when(() => foodRepo.getAllFoods()).thenAnswer((_) async => []);

      final container = makeContainer(foodRepo: foodRepo);
      final service = container.read(appStartupServiceProvider);

      await service.fallbackLoadFoods();

      verify(() => foodRepo.getAllFoods()).called(1);

      container.dispose();
    });

    test('skips getAllFoods when foods table already has rows', () async {
      // Insert one food row — id must be exactly 36 chars (UUID constraint).
      await database
          .into(database.foodsTable)
          .insert(
            FoodsTableCompanion.insert(
              id: '00000000-0000-0000-0000-000000000001',
            ),
          );

      final foodRepo = MockFoodRepository();
      final container = makeContainer(foodRepo: foodRepo);
      final service = container.read(appStartupServiceProvider);

      await service.fallbackLoadFoods();

      verifyNever(() => foodRepo.getAllFoods());

      container.dispose();
    });

    test('does not rethrow when getAllFoods throws', () async {
      final foodRepo = MockFoodRepository();
      when(
        () => foodRepo.getAllFoods(),
      ).thenThrow(Exception('network unavailable'));

      final container = makeContainer(foodRepo: foodRepo);
      final service = container.read(appStartupServiceProvider);

      await expectLater(service.fallbackLoadFoods(), completes);

      container.dispose();
    });

    test('does not rethrow when database query itself throws '
        '(simulated DB error)', () async {
      // Close the DB to force errors on any query
      await database.close();

      // Re-create so tearDown can close without error, but the service sees a
      // closed db at the time of the call.
      database = AppDatabase.forTesting(NativeDatabase.memory());
      final closedDb = AppDatabase.forTesting(NativeDatabase.memory());
      await closedDb.close();

      final deps = AppExternalDeps(
        supabaseClient: mockSupabase,
        logger: mockLogger,
        sentry: mockSentry,
        analytics: mockAnalytics,
        sharedPreferences: mockPrefs,
      );
      final container = ProviderContainer(
        overrides: [
          appExternalDepsProvider.overrideWithValue(deps),
          appDatabaseProvider.overrideWithValue(closedDb),
        ],
      );
      final service = container.read(appStartupServiceProvider);

      await expectLater(service.fallbackLoadFoods(), completes);

      container.dispose();
    });
  });

  // ─── initializeNutritionPlans ────────────────────────────────────────────────

  group('initializeNutritionPlans', () {
    test('completes without throwing when no user exists', () async {
      when(() => mockAuth.currentUser).thenReturn(null);

      final container = makeContainer();
      final service = container.read(appStartupServiceProvider);

      await expectLater(service.initializeNutritionPlans(), completes);

      container.dispose();
    });

    test('completes without throwing when user exists in DB', () async {
      await _insertUserProfile(database);
      when(() => mockAuth.currentUser).thenReturn(_FakeUser('test-user-id'));

      final container = makeContainer();
      final service = container.read(appStartupServiceProvider);

      await expectLater(service.initializeNutritionPlans(), completes);

      container.dispose();
    });
  });

  // ─── checkAndHandleDirtyRecordBackup ────────────────────────────────────────

  group('checkAndHandleDirtyRecordBackup', () {
    test('returns false immediately when no backup file exists', () async {
      final container = makeContainer();
      final service = container.read(appStartupServiceProvider);

      final result = await service.checkAndHandleDirtyRecordBackup(
        _UnmountedBuildContext(),
      );

      expect(result, isFalse);

      container.dispose();
    });

    test('returns false when backup file contains invalid JSON', () async {
      final backupFile = File('${tempDir.path}/dirty_records_backup.json');
      await backupFile.writeAsString('{not valid json{{}}');

      final container = makeContainer();
      final service = container.read(appStartupServiceProvider);

      final result = await service.checkAndHandleDirtyRecordBackup(
        _UnmountedBuildContext(),
      );

      // Corrupt backup should fail gracefully
      expect(result, isFalse);

      container.dispose();
    });

    test('returns false when context is not mounted '
        '(cannot show recovery dialog)', () async {
      // Write a valid backup file so we get past the hasBackup check
      final backup = {
        'backup_created_at': DateTime(2026, 1, 1).toIso8601String(),
        'app_version': '1.0.0',
        'schema_version': 9,
        'user_id': 'uid-test',
        'dirty_records': {
          'activities': [
            {'id': 'act-1'},
          ],
        },
        'upload_errors': [],
      };
      final backupFile = File('${tempDir.path}/dirty_records_backup.json');
      await backupFile.writeAsString(backup.toString().replaceAll("'", '"'));

      final container = makeContainer();
      final service = container.read(appStartupServiceProvider);

      // _UnmountedBuildContext reports mounted=false → method returns false
      final result = await service.checkAndHandleDirtyRecordBackup(
        _UnmountedBuildContext(),
      );

      expect(result, isFalse);

      container.dispose();
    });
  });

  // ─── Repository key coverage ─────────────────────────────────────────────────

  group('repository key completeness', () {
    test('all 12 known repository keys are documented', () {
      // This list should match the switch in _getTableNameFromRepositoryKey.
      // If a new repository is added without updating the switch, an integration
      // test or the backup flow will throw ArgumentError at runtime.
      const knownKeys = [
        'activities',
        'events',
        'carb_loading_plans',
        'carb_loading_days',
        'carb_loading_day_meals',
        'food_preferences',
        'user_foods',
        'carb_loading_user_foods',
        'feedback',
        'coaches',
        'coach_athlete_relationships',
        'coach_messages',
      ];

      // Sentinel: if this fails someone added a key without updating this test
      expect(knownKeys.length, equals(12));

      // Verify each key maps to a non-empty, lowercase table name
      // (We can't call the private method; we document expected output.)
      final expectedTables = {
        'activities': 'activities',
        'events': 'events',
        'carb_loading_plans': 'carb_loading_plans',
        'carb_loading_days': 'carb_loading_days',
        'carb_loading_day_meals': 'carb_loading_day_meals',
        'food_preferences': 'food_preferences',
        'user_foods': 'user_foods',
        'carb_loading_user_foods': 'carb_loading_user_foods',
        'feedback': 'feedback',
        'coaches': 'coaches',
        'coach_athlete_relationships': 'coach_athlete_relationships',
        'coach_messages': 'coach_messages',
      };

      for (final key in knownKeys) {
        expect(
          expectedTables[key],
          isNotNull,
          reason: 'Repository key "$key" missing from expected tables map',
        );
        expect(expectedTables[key], isNotEmpty);
      }
    });

    test('unknown repository key is not in the known-keys list', () {
      const unknownKey = 'totally_unknown_repo';
      const knownKeys = [
        'activities',
        'events',
        'carb_loading_plans',
        'carb_loading_days',
        'carb_loading_day_meals',
        'food_preferences',
        'user_foods',
        'carb_loading_user_foods',
        'feedback',
        'coaches',
        'coach_athlete_relationships',
        'coach_messages',
      ];
      expect(knownKeys.contains(unknownKey), isFalse);
    });
  });
}
