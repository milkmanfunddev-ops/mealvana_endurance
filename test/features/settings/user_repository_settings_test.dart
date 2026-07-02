/// Integration tests for [UserRepository] settings-related CRUD:
/// save → load → edit → save → reload round-trips using a real in-memory
/// Drift database. Supabase is mocked (no network calls).
///
/// Focuses on:
/// - Profile persistence round-trips for all major settings fields.
/// - Partial update doesn't clobber unrelated fields.
/// - Unit system and allergy list persistence.
/// - Nutrition target overrides save/clear.
/// - The allergies-clear bug in _saveProfile guard logic.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_target_overrides.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/run_parameters.dart';
import 'package:mealvana_endurance/features/onboarding/domain/allergy.dart';
import 'package:mealvana_endurance/features/onboarding/domain/dietary_preference.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockSentryReporter extends Mock implements SentryReporter {}

// MockSupabaseQueryBuilder is kept for completeness but not actively used
// since all test paths go through saveUserProfile (Drift-only) or
// updateUserProfile with needsUpload=true (also Drift-only).
class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// authUserId must be a UUID (36 chars) — matches the column constraint.
const _testAuthUserId = '00000000-0000-0000-0000-000000000001';
const _testUserId = 'user-test-001';
const _testDeviceId = 'device-test-001';

UserProfile _baseProfile({
  String id = _testUserId,
  String authUserId = _testAuthUserId,
}) {
  return UserProfile(
    id: id,
    deviceId: _testDeviceId,
    authUserId: authUserId,
    authProvider: 'email',
    isAnonymous: false,
    gender: Gender.male,
    birthday: DateTime(1990, 6, 15),
    heightFeet: 5,
    heightInches: 10,
    weightPounds: 175.0,
    runsWithWaterBottle: false,
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
    gutTraining: GutTraining.moderate,
    sweatRate: SweatRateCat.medium,
    onboardingCompleted: true,
    appVersion: '1.0.0',
    unitSystem: UnitSystem.imperial,
    dietaryPreference: DietaryPreference.none,
    allergies: const [],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockGoTrue;
  late MockSentryReporter mockSentry;
  late UserRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    mockSupabase = MockSupabaseClient();
    mockGoTrue = MockGoTrueClient();
    mockSentry = MockSentryReporter();

    // Supabase auth is consulted by getCurrentUser to scope the query.
    when(() => mockSupabase.auth).thenReturn(mockGoTrue);
    when(() => mockGoTrue.currentUser).thenReturn(null);

    // Note: saveUserProfile() only writes to Drift and never touches Supabase.
    // All updateUserProfile() calls in these tests use needsUpload=true, which
    // skips the immediate Supabase upsert path in the repository. Therefore no
    // Supabase from()/upsert() stubs are needed here.

    // Sentry stubs
    when(
      () => mockSentry.reportNetworkError(
        any(),
        url: any(named: 'url'),
        method: any(named: 'method'),
        stackTrace: any(named: 'stackTrace'),
        statusCode: any(named: 'statusCode'),
        timeout: any(named: 'timeout'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockSentry.reportDatabaseError(
        any(),
        operation: any(named: 'operation'),
        table: any(named: 'table'),
        stackTrace: any(named: 'stackTrace'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockSentry.addBreadcrumb(
        message: any(named: 'message'),
        category: any(named: 'category'),
        data: any(named: 'data'),
      ),
    ).thenReturn(null);

    repository = UserRepository(
      database: database,
      supabase: mockSupabase,
      sentry: mockSentry,
    );
  });

  tearDown(() async {
    await database.close();
  });

  // ---------------------------------------------------------------------------
  // Helper: save a profile and wire auth so getCurrentUser finds it.
  // ---------------------------------------------------------------------------
  Future<void> _seedProfile(UserProfile profile) async {
    await repository.saveUserProfile(profile, needsUpload: false);
    when(() => mockGoTrue.currentUser).thenReturn(
      null, // getCurrentUser uses auth.currentUser?.id; test via getUserProfileByAuthUserId
    );
  }

  // Directly retrieve by authUserId to bypass Supabase auth mock complexity.
  Future<UserProfile?> _getByAuthUserId(String authUserId) async {
    return database.userDao.getUserProfileByAuthUserId(authUserId);
  }

  Future<UserProfile?> _getById(String userId) async {
    return database.userDao.getUserProfileById(userId);
  }

  // ---------------------------------------------------------------------------
  // Group 1: Basic save → load round-trips
  // ---------------------------------------------------------------------------

  group('save → load round-trip', () {
    test('saveUserProfile persists all base fields and loads them back', () async {
      final profile = _baseProfile();
      await repository.saveUserProfile(profile);

      final loaded = await _getByAuthUserId(_testAuthUserId);

      expect(loaded, isNotNull);
      expect(loaded!.id, _testUserId);
      expect(loaded.gender, Gender.male);
      expect(loaded.heightFeet, 5);
      expect(loaded.heightInches, 10);
      expect(loaded.weightPounds, 175.0);
      expect(loaded.runsWithWaterBottle, isFalse);
      expect(loaded.unitSystem, UnitSystem.imperial);
      expect(loaded.gutTraining, GutTraining.moderate);
      expect(loaded.sweatRate, SweatRateCat.medium);
      expect(loaded.onboardingCompleted, isTrue);
    });

    test('saveUserProfile persists gender female correctly', () async {
      final profile = _baseProfile().copyWith(gender: Gender.female);
      await repository.saveUserProfile(profile);

      final loaded = await _getByAuthUserId(_testAuthUserId);
      expect(loaded!.gender, Gender.female);
    });

    test('saveUserProfile persists metric unit system', () async {
      final profile = _baseProfile().copyWith(unitSystem: UnitSystem.metric);
      await repository.saveUserProfile(profile);

      final loaded = await _getByAuthUserId(_testAuthUserId);
      expect(loaded!.unitSystem, UnitSystem.metric);
      expect(loaded.preferredDistanceUnit, DistanceUnit.kilometers);
    });

    test('saveUserProfile persists runsWithWaterBottle = true', () async {
      final profile = _baseProfile().copyWith(runsWithWaterBottle: true);
      await repository.saveUserProfile(profile);

      final loaded = await _getByAuthUserId(_testAuthUserId);
      expect(loaded!.runsWithWaterBottle, isTrue);
    });

    // NOTE: giSensitivity, ftpWatts, cssPacePer100mSeconds, and typicalBikeBottles
    // are Supabase-only fields — they are NOT stored in the local Drift schema.
    // Tests for those fields are replaced with fields that ARE persisted locally.

    test('saveUserProfile persists carbCycleOptIn = true', () async {
      final profile = _baseProfile().copyWith(carbCycleOptIn: true);
      await repository.saveUserProfile(profile);

      final loaded = await _getByAuthUserId(_testAuthUserId);
      expect(loaded!.carbCycleOptIn, isTrue);
    });

    test('saveUserProfile persists defaultSwimmingPacePer100Sec', () async {
      // copyWith does not expose defaultSwimmingPacePer100Sec — construct directly.
      final base = _baseProfile();
      final profile = UserProfile(
        id: base.id,
        deviceId: base.deviceId,
        authUserId: base.authUserId,
        authProvider: base.authProvider,
        isAnonymous: base.isAnonymous,
        gender: base.gender,
        birthday: base.birthday,
        heightFeet: base.heightFeet,
        heightInches: base.heightInches,
        weightPounds: base.weightPounds,
        runsWithWaterBottle: base.runsWithWaterBottle,
        createdAt: base.createdAt,
        updatedAt: base.updatedAt,
        gutTraining: base.gutTraining,
        sweatRate: base.sweatRate,
        onboardingCompleted: base.onboardingCompleted,
        appVersion: base.appVersion,
        unitSystem: base.unitSystem,
        dietaryPreference: base.dietaryPreference,
        allergies: base.allergies,
        defaultSwimmingPacePer100Sec: 90,
      );
      await repository.saveUserProfile(profile);

      final loaded = await _getByAuthUserId(_testAuthUserId);
      expect(loaded!.defaultSwimmingPacePer100Sec, 90);
    });

    test('saveUserProfile persists defaultCyclingSpeedMph', () async {
      // copyWith does not expose defaultCyclingSpeedMph — construct directly.
      final base = _baseProfile();
      final profile = UserProfile(
        id: base.id,
        deviceId: base.deviceId,
        authUserId: base.authUserId,
        authProvider: base.authProvider,
        isAnonymous: base.isAnonymous,
        gender: base.gender,
        birthday: base.birthday,
        heightFeet: base.heightFeet,
        heightInches: base.heightInches,
        weightPounds: base.weightPounds,
        runsWithWaterBottle: base.runsWithWaterBottle,
        createdAt: base.createdAt,
        updatedAt: base.updatedAt,
        gutTraining: base.gutTraining,
        sweatRate: base.sweatRate,
        onboardingCompleted: base.onboardingCompleted,
        appVersion: base.appVersion,
        unitSystem: base.unitSystem,
        dietaryPreference: base.dietaryPreference,
        allergies: base.allergies,
        defaultCyclingSpeedMph: 18.5,
      );
      await repository.saveUserProfile(profile);

      final loaded = await _getByAuthUserId(_testAuthUserId);
      expect(loaded!.defaultCyclingSpeedMph, closeTo(18.5, 0.01));
    });

    test('saveUserProfile persists sweat rate HIGH', () async {
      final profile = _baseProfile().copyWith(sweatRate: SweatRateCat.heavy);
      await repository.saveUserProfile(profile);

      final loaded = await _getByAuthUserId(_testAuthUserId);
      expect(loaded!.sweatRate, SweatRateCat.heavy);
    });

    test('saveUserProfile persists gut training HIGH', () async {
      final profile = _baseProfile().copyWith(gutTraining: GutTraining.high);
      await repository.saveUserProfile(profile);

      final loaded = await _getByAuthUserId(_testAuthUserId);
      expect(loaded!.gutTraining, GutTraining.high);
    });

    test('saveUserProfile persists firstName, lastName, email', () async {
      final profile = _baseProfile().copyWith(
        firstName: 'Alice',
        lastName: 'Runner',
        email: 'alice@example.com',
      );
      await repository.saveUserProfile(profile);

      final loaded = await _getByAuthUserId(_testAuthUserId);
      expect(loaded!.firstName, 'Alice');
      expect(loaded.lastName, 'Runner');
      expect(loaded.email, 'alice@example.com');
    });
  });

  // ---------------------------------------------------------------------------
  // Group 2: Dietary preferences and allergies
  // ---------------------------------------------------------------------------

  group('dietary preferences and allergies', () {
    test('allergies list persists and loads correctly', () async {
      final profile = _baseProfile().copyWith(
        allergies: [Allergy.dairy, Allergy.gluten],
      );
      await repository.saveUserProfile(profile);

      final loaded = await _getByAuthUserId(_testAuthUserId);
      expect(loaded!.allergies, containsAll([Allergy.dairy, Allergy.gluten]));
      expect(loaded.allergies, hasLength(2));
    });

    test('dietary preference persists', () async {
      final profile = _baseProfile().copyWith(
        dietaryPreference: DietaryPreference.vegetarian,
      );
      await repository.saveUserProfile(profile);

      final loaded = await _getByAuthUserId(_testAuthUserId);
      expect(loaded!.dietaryPreference, DietaryPreference.vegetarian);
    });

    test('empty allergies persist as empty', () async {
      // First save with allergies, then update to empty.
      final initial = _baseProfile().copyWith(
        allergies: [Allergy.dairy],
      );
      await repository.saveUserProfile(initial);

      // Now update to empty allergies via updateUserProfile.
      final updated = initial.copyWith(allergies: []);
      await repository.updateUserProfile(updated, needsUpload: true);

      final loaded = await _getByAuthUserId(_testAuthUserId);
      // The database itself correctly stores empty, which proves the
      // bug is in _saveProfile's guard logic (not the DAO).
      expect(loaded!.allergies, isEmpty,
          reason: 'DAO correctly stores empty allergies list');
    });
  });

  // ---------------------------------------------------------------------------
  // Group 3: Partial update doesn't clobber other fields
  // ---------------------------------------------------------------------------

  group('partial update isolation', () {
    test('updating weight does not clobber height or gender', () async {
      final initial = _baseProfile().copyWith(
        gender: Gender.female,
        heightFeet: 5,
        heightInches: 6,
        weightPounds: 140.0,
      );
      await repository.saveUserProfile(initial);

      // Update only weight
      final updated = initial.copyWith(weightPounds: 145.0);
      await repository.updateUserProfile(updated, needsUpload: true);

      final loaded = await _getByAuthUserId(_testAuthUserId);
      expect(loaded!.gender, Gender.female);
      expect(loaded.heightFeet, 5);
      expect(loaded.heightInches, 6);
      expect(loaded.weightPounds, 145.0);
    });

    test('updating unitSystem does not clobber cycling speed or sweat rate', () async {
      // ftpWatts and typicalBikeBottles are NOT in the local Drift schema
      // (they are Supabase-only fields).  Use defaultCyclingSpeedMph and
      // sweatRate instead — both ARE persisted locally.
      // copyWith does not expose defaultCyclingSpeedMph — construct directly.
      final base = _baseProfile();
      final initial = UserProfile(
        id: base.id,
        deviceId: base.deviceId,
        authUserId: base.authUserId,
        authProvider: base.authProvider,
        isAnonymous: base.isAnonymous,
        gender: base.gender,
        birthday: base.birthday,
        heightFeet: base.heightFeet,
        heightInches: base.heightInches,
        weightPounds: base.weightPounds,
        runsWithWaterBottle: base.runsWithWaterBottle,
        createdAt: base.createdAt,
        updatedAt: base.updatedAt,
        gutTraining: base.gutTraining,
        sweatRate: SweatRateCat.heavy,
        onboardingCompleted: base.onboardingCompleted,
        appVersion: base.appVersion,
        unitSystem: UnitSystem.imperial,
        dietaryPreference: base.dietaryPreference,
        allergies: base.allergies,
        defaultCyclingSpeedMph: 18.0,
      );
      await repository.saveUserProfile(initial);

      // copyWith does not propagate defaultCyclingSpeedMph — construct directly.
      final updated = UserProfile(
        id: initial.id,
        deviceId: initial.deviceId,
        authUserId: initial.authUserId,
        authProvider: initial.authProvider,
        isAnonymous: initial.isAnonymous,
        gender: initial.gender,
        birthday: initial.birthday,
        heightFeet: initial.heightFeet,
        heightInches: initial.heightInches,
        weightPounds: initial.weightPounds,
        runsWithWaterBottle: initial.runsWithWaterBottle,
        createdAt: initial.createdAt,
        updatedAt: DateTime.now(),
        gutTraining: initial.gutTraining,
        sweatRate: initial.sweatRate,
        onboardingCompleted: initial.onboardingCompleted,
        appVersion: initial.appVersion,
        unitSystem: UnitSystem.metric,
        dietaryPreference: initial.dietaryPreference,
        allergies: initial.allergies,
        defaultCyclingSpeedMph: initial.defaultCyclingSpeedMph,
      );
      await repository.updateUserProfile(updated, needsUpload: true);

      final loaded = await _getByAuthUserId(_testAuthUserId);
      expect(loaded!.unitSystem, UnitSystem.metric);
      expect(loaded.defaultCyclingSpeedMph, closeTo(18.0, 0.01));
      expect(loaded.sweatRate, SweatRateCat.heavy);
    });

    test('updating gut training does not clobber dietary preference', () async {
      final initial = _baseProfile().copyWith(
        gutTraining: GutTraining.low,
        dietaryPreference: DietaryPreference.vegan,
      );
      await repository.saveUserProfile(initial);

      final updated = initial.copyWith(gutTraining: GutTraining.high);
      await repository.updateUserProfile(updated, needsUpload: true);

      final loaded = await _getByAuthUserId(_testAuthUserId);
      expect(loaded!.gutTraining, GutTraining.high);
      expect(loaded.dietaryPreference, DietaryPreference.vegan);
    });

    test('updating swim pace does not clobber cycling speed', () async {
      // cssPacePer100mSeconds, ftpWatts, typicalBikeBottles are NOT in the
      // local Drift schema.  Use defaultSwimmingPacePer100Sec and
      // defaultCyclingSpeedMph instead — both ARE persisted locally.
      // copyWith does not expose these fields — construct directly.
      final base = _baseProfile();
      final initial = UserProfile(
        id: base.id,
        deviceId: base.deviceId,
        authUserId: base.authUserId,
        authProvider: base.authProvider,
        isAnonymous: base.isAnonymous,
        gender: base.gender,
        birthday: base.birthday,
        heightFeet: base.heightFeet,
        heightInches: base.heightInches,
        weightPounds: base.weightPounds,
        runsWithWaterBottle: base.runsWithWaterBottle,
        createdAt: base.createdAt,
        updatedAt: base.updatedAt,
        gutTraining: base.gutTraining,
        sweatRate: base.sweatRate,
        onboardingCompleted: base.onboardingCompleted,
        appVersion: base.appVersion,
        unitSystem: base.unitSystem,
        dietaryPreference: base.dietaryPreference,
        allergies: base.allergies,
        defaultCyclingSpeedMph: 20.0,
        defaultSwimmingPacePer100Sec: 95,
      );
      await repository.saveUserProfile(initial);

      final updated = UserProfile(
        id: initial.id,
        deviceId: initial.deviceId,
        authUserId: initial.authUserId,
        authProvider: initial.authProvider,
        isAnonymous: initial.isAnonymous,
        gender: initial.gender,
        birthday: initial.birthday,
        heightFeet: initial.heightFeet,
        heightInches: initial.heightInches,
        weightPounds: initial.weightPounds,
        runsWithWaterBottle: initial.runsWithWaterBottle,
        createdAt: initial.createdAt,
        updatedAt: DateTime.now(),
        gutTraining: initial.gutTraining,
        sweatRate: initial.sweatRate,
        onboardingCompleted: initial.onboardingCompleted,
        appVersion: initial.appVersion,
        unitSystem: initial.unitSystem,
        dietaryPreference: initial.dietaryPreference,
        allergies: initial.allergies,
        defaultCyclingSpeedMph: initial.defaultCyclingSpeedMph,
        defaultSwimmingPacePer100Sec: 85,
      );
      await repository.updateUserProfile(updated, needsUpload: true);

      final loaded = await _getByAuthUserId(_testAuthUserId);
      expect(loaded!.defaultSwimmingPacePer100Sec, 85);
      expect(loaded.defaultCyclingSpeedMph, closeTo(20.0, 0.01));
    });
  });

  // ---------------------------------------------------------------------------
  // Group 4: Nutrition target overrides round-trip
  // ---------------------------------------------------------------------------

  group('nutrition target overrides', () {
    test('saves and loads nutrition target overrides', () async {
      final overrides = const NutritionTargetOverrides(
        duringRun: DuringActivityOverrides(
          carbRateGPerH: 60.0,
          fluidRateMlPerH: 500.0,
        ),
        post: PostActivityOverrides(
          carbsG: 80.0,
          proteinG: 25.0,
        ),
      );

      final profile = _baseProfile().copyWith(
        nutritionTargetOverrides: overrides,
      );
      await repository.saveUserProfile(profile);

      final loaded = await _getByAuthUserId(_testAuthUserId);
      expect(loaded!.nutritionTargetOverrides, isNotNull);
      expect(
        loaded.nutritionTargetOverrides!.duringRun?.carbRateGPerH,
        60.0,
      );
      expect(
        loaded.nutritionTargetOverrides!.duringRun?.fluidRateMlPerH,
        500.0,
      );
      expect(
        loaded.nutritionTargetOverrides!.post?.carbsG,
        80.0,
      );
      expect(
        loaded.nutritionTargetOverrides!.post?.proteinG,
        25.0,
      );
    });

    test('updates nutrition target overrides without clobbering other fields', () async {
      final initial = _baseProfile().copyWith(
        weightPounds: 170.0,
        unitSystem: UnitSystem.metric,
        nutritionTargetOverrides: const NutritionTargetOverrides(
          duringCycling: DuringActivityOverrides(carbRateGPerH: 90.0),
        ),
      );
      await repository.saveUserProfile(initial);

      final updatedOverrides = const NutritionTargetOverrides(
        duringCycling: DuringActivityOverrides(carbRateGPerH: 100.0),
      );
      final updated = initial.copyWith(
        nutritionTargetOverrides: updatedOverrides,
      );
      await repository.updateUserProfile(updated, needsUpload: true);

      final loaded = await _getByAuthUserId(_testAuthUserId);
      expect(loaded!.weightPounds, 170.0);
      expect(loaded.unitSystem, UnitSystem.metric);
      expect(
        loaded.nutritionTargetOverrides?.duringCycling?.carbRateGPerH,
        100.0,
      );
    });

    test('clearing nutrition target overrides (null) saves null', () async {
      final initial = _baseProfile().copyWith(
        nutritionTargetOverrides: const NutritionTargetOverrides(
          pre: PreActivityOverrides(carbsG: 50.0),
        ),
      );
      await repository.saveUserProfile(initial);

      // saveNutritionTargetOverrides(null) in the controller explicitly
      // sets nutritionTargetOverrides: null. Verify the DAO can persist null.
      // We test by calling updateUserProfile with a profile where
      // nutritionTargetOverrides is forced to null by constructing directly.
      final cleared = UserProfile(
        id: initial.id,
        deviceId: initial.deviceId,
        authUserId: initial.authUserId,
        authProvider: initial.authProvider,
        isAnonymous: initial.isAnonymous,
        gender: initial.gender,
        birthday: initial.birthday,
        heightFeet: initial.heightFeet,
        heightInches: initial.heightInches,
        weightPounds: initial.weightPounds,
        runsWithWaterBottle: initial.runsWithWaterBottle,
        createdAt: initial.createdAt,
        updatedAt: DateTime.now(),
        gutTraining: initial.gutTraining,
        sweatRate: initial.sweatRate,
        onboardingCompleted: initial.onboardingCompleted,
        appVersion: initial.appVersion,
        // nutritionTargetOverrides: null (explicitly)
      );

      await repository.updateUserProfile(cleared, needsUpload: true);

      final loaded = await _getByAuthUserId(_testAuthUserId);
      expect(loaded!.nutritionTargetOverrides, isNull,
          reason: 'Cleared overrides must persist as null');
    });
  });

  // ---------------------------------------------------------------------------
  // Group 5: Multiple profiles isolation
  // ---------------------------------------------------------------------------

  group('multiple user profiles isolation', () {
    test('two profiles do not share or overwrite each other', () async {
      // authUserId must be exactly 36 chars (UUID format) to satisfy the
      // column constraint.  Different deviceIds are required to prevent the
      // DAO's "delete existing user with same device_id" guard from removing
      // user1 when user2 is saved.
      const auth1 = '11111111-1111-1111-1111-111111111111';
      const auth2 = '22222222-2222-2222-2222-222222222222';
      final user1 = _baseProfile(id: 'user-001', authUserId: auth1).copyWith(
        weightPounds: 150.0,
        gender: Gender.female,
        deviceId: 'device-001',
      );
      final user2 = _baseProfile(id: 'user-002', authUserId: auth2).copyWith(
        weightPounds: 200.0,
        gender: Gender.male,
        deviceId: 'device-002',
      );

      await repository.saveUserProfile(user1);
      await repository.saveUserProfile(user2);

      final loaded1 = await _getByAuthUserId(auth1);
      final loaded2 = await _getByAuthUserId(auth2);

      expect(loaded1!.weightPounds, 150.0);
      expect(loaded1.gender, Gender.female);
      expect(loaded2!.weightPounds, 200.0);
      expect(loaded2.gender, Gender.male);
    });
  });

  // ---------------------------------------------------------------------------
  // Group 6: needsUpload dirty flag
  // ---------------------------------------------------------------------------

  group('needsUpload dirty flag', () {
    test('saveUserProfile with needsUpload=true marks the row dirty', () async {
      final profile = _baseProfile();
      await repository.saveUserProfile(profile, needsUpload: true);

      // Query the raw entry to check the dirty flag.
      final entry = await database.userDao.getUserProfileById(_testUserId);
      // entry is returned as domain; we check via raw table query.
      final rawRows = await database.select(database.userProfilesTable).get();
      final row = rawRows.firstWhere((r) => r.id == _testUserId);
      expect(row.needsUpload, isTrue);
    });

    test('saveUserProfile with needsUpload=false does not mark dirty', () async {
      final profile = _baseProfile();
      await repository.saveUserProfile(profile, needsUpload: false);

      final rawRows = await database.select(database.userProfilesTable).get();
      final row = rawRows.firstWhere((r) => r.id == _testUserId);
      expect(row.needsUpload, isFalse);
    });
  });
}
