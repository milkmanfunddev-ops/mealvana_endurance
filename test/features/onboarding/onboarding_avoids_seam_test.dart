// develop-2026-10 ticket 71 (Finding 58-001): the allergy avoids and the
// diet avoids both survive, and the athlete's own rows survive them.
//
// `OnboardingController._updateFoodPreferencesForAllergies` saved one replace
// per allergy and one for the diet, so each save deleted every other local
// row: only the last set stayed and was uploaded. Since the 2026-08 redesign
// onboarding itself writes no avoids (saveAllOnboardingData defaults to
// omnivore / no allergies); the writer is reached from Settings → Allergies
// and Settings → Dietary Preference, through the same controller.
//
// Seam test (docs/test/README.md): the real [OnboardingController],
// [AuthService], [OnboardingService], [FoodRepository] and
// [FoodPreferencesRepository] through a ProviderContainer, on in-memory Drift,
// with the real postgrest builder against [FakePostgrest]. `template_foods`
// is seeded the way the server holds it (snake_case names, Postgres arrays as
// lists), never from this app's own output.
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/food_preferences/data/food_preferences_repository.dart';
import 'package:mealvana_endurance/features/onboarding/domain/allergy.dart';
import 'package:mealvana_endurance/features/onboarding/domain/dietary_preference.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/providers/onboarding_controller.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/database/database_provider.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/connectivity_checker.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes/fake_postgrest.dart';
import '../../helpers/fakes/recording_analytics_tracker.dart';
import '../../helpers/fakes/recording_report.dart';

const _user = '5b0c1d2e-3f40-4a5b-8c6d-7e8f90a1b2c3';

class _MockPrefs extends Mock implements SharedPreferences {}

class _StubConnectivity extends ConnectivityChecker {
  @override
  Future<bool> isOnline() async => true;

  @override
  Stream<bool> get onlineChanges => const Stream.empty();
}

/// `template_foods` as the server answers `select name, allergens,
/// excluded_diets`.
List<Map<String, dynamic>> _templateFoods() => [
  {
    'name': 'peanut_butter_pretzels',
    'allergens': ['peanuts', 'gluten'],
    'excluded_diets': <String>[],
    'is_active': true,
  },
  {
    'name': 'peanut_butter_sandwich',
    'allergens': ['peanuts', 'gluten'],
    'excluded_diets': <String>[],
    'is_active': true,
  },
  {
    'name': 'beef_jerky',
    'allergens': <String>[],
    'excluded_diets': ['vegetarian', 'vegan', 'pescatarian'],
    'is_active': true,
  },
  {
    'name': 'greek_yogurt',
    'allergens': ['dairy'],
    'excluded_diets': ['vegan'],
    'is_active': true,
  },
  {
    'name': 'banana',
    'allergens': <String>[],
    'excluded_diets': <String>[],
    'is_active': true,
  },
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakePostgrest server;
  late RecordingReport report;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.memory();
    server = FakePostgrest();
    await server.signIn(_user);
    report = RecordingReport();
    server.tables['template_foods'] = _templateFoods();

    await db
        .into(db.userProfilesTable)
        .insert(
          UserProfilesTableCompanion.insert(
            id: _user,
            deviceId: _user,
            authUserId: const Value(_user),
            email: const Value('athlete@example.com'),
          ),
        );
    // The athlete's own Settings row: a like the avoids must not wipe.
    await db
        .into(db.foodPreferencesTable)
        .insert(
          FoodPreferencesTableCompanion.insert(
            id: '0f1e2d3c-4b5a-4968-8776-655443322110',
            userId: _user,
            foodName: 'banana',
            preference: 'like',
            preferenceLevel: const Value(4),
            createdAt: Value(DateTime.utc(2026, 10, 1, 9)),
            updatedAt: Value(DateTime.utc(2026, 10, 1, 9)),
          ),
        );

    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        reportProvider.overrideWithValue(report),
        connectivityCheckerProvider.overrideWithValue(_StubConnectivity()),
        userRepositoryProvider.overrideWith(
          (ref) async => UserRepository(
            database: db,
            supabase: server.client,
            report: report,
          ),
        ),
        appExternalDepsProvider.overrideWithValue(
          AppExternalDeps(
            analytics: RecordingAnalyticsTracker(),
            supabaseClient: server.client,
            report: report,
            sharedPreferences: _MockPrefs(),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  tearDown(() async {
    await FoodPreferencesRepository.inFlightUploadFor(_user);
    await db.close();
  });

  OnboardingController controller() =>
      container.read(onboardingControllerProvider.notifier);

  Future<void> settle() async {
    await pumpEventQueue();
    await FoodPreferencesRepository.inFlightUploadFor(_user);
  }

  /// The last row sent for each food, across every `food_preferences` upsert.
  Map<String, Map<String, dynamic>> uploaded() => {
    for (final row
        in server.writes
            .where((w) => w.table == 'food_preferences')
            .expand((w) => (w.body as List).cast<Map>())
            .map((m) => m.cast<String, dynamic>()))
      row['food_name'] as String: row,
  };

  Future<Map<String, String>> localSources() =>
      db.foodPreferencesDao.getFoodPreferenceSources(_user);

  test('an allergy then a diet: both avoid sets and the athlete\'s like stay '
      'in Drift, and both avoid sets reach the server', () async {
    expect(await controller().saveAllergies([Allergy.peanuts]), isTrue);
    await settle();
    expect(
      await controller().saveDietaryPreference(DietaryPreference.vegan),
      isTrue,
    );
    await settle();

    expect(await localSources(), {
      'banana': 'manual',
      'peanut_butter_pretzels': 'allergy:peanuts',
      'peanut_butter_sandwich': 'allergy:peanuts',
      'beef_jerky': 'dietary:vegan',
      'greek_yogurt': 'dietary:vegan',
    });
    final levels = await db.foodPreferencesDao.getUserFoodPreferenceLevels(
      _user,
    );
    expect(levels['banana'], 4, reason: 'the athlete\'s like is untouched');
    expect(levels['peanut_butter_pretzels'], 0);
    expect(levels['beef_jerky'], 0);

    final rows = uploaded();
    for (final food in [
      'peanut_butter_pretzels',
      'peanut_butter_sandwich',
      'beef_jerky',
      'greek_yogurt',
    ]) {
      expect(rows[food], isNotNull, reason: '$food reaches the server');
      expect(rows[food]!['user_id'], _user);
      expect(rows[food]!['preference'], 'dislike');
      expect(rows[food]!['preference_level'], 0);
      expect(rows[food]!['updated_at'] as String, endsWith('Z'));
    }
    expect(
      rows['peanut_butter_pretzels']!['preference_source'],
      'allergy:peanuts',
    );
    expect(rows['beef_jerky']!['preference_source'], 'dietary:vegan');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(foodPreferencesUploadPendingKey(_user)), isNull);
  });

  test('two allergies and a food in both sets: one save, every avoid kept, '
      'the shared food tagged with the first allergy', () async {
    expect(
      await controller().saveAllergies([Allergy.peanuts, Allergy.gluten]),
      isTrue,
    );
    await settle();

    expect(await localSources(), {
      'banana': 'manual',
      'peanut_butter_pretzels': 'allergy:peanuts',
      'peanut_butter_sandwich': 'allergy:peanuts',
    });
    final writes = server.writes.where((w) => w.table == 'food_preferences');
    expect(writes, hasLength(1), reason: 'one save, one upload');
  });

  test('a diet that excludes a food an allergy already avoids keeps the '
      'allergy row and its source', () async {
    await controller().saveAllergies([Allergy.dairy]);
    await settle();
    await controller().saveDietaryPreference(DietaryPreference.vegan);
    await settle();

    final sources = await localSources();
    expect(sources['greek_yogurt'], 'allergy:dairy');
    expect(sources['beef_jerky'], 'dietary:vegan');

    // Removing the diet leaves the dairy avoid in place.
    await controller().saveDietaryPreference(DietaryPreference.omnivore);
    await settle();
    final after = await localSources();
    expect(after['greek_yogurt'], 'allergy:dairy');
    expect(after.containsKey('beef_jerky'), isFalse);
    expect(after['banana'], 'manual');
  });
}
