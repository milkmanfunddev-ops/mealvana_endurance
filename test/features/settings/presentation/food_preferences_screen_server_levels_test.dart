// develop-2026-10 ticket 58 (Finding 49-010): after a fresh sign-in the
// Food Preferences screen showed default levels although the server held the
// athlete's. The screen never synced `food_preferences`, and it looked rows up
// by display name while the server keys them by `template_foods.name`.
//
// The server row is producer-shaped (snake_case key, Postgres `+00` stamps);
// Drift starts empty; the real controller, repository and SyncCoordinator run
// against FakePostgrest.
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/application/auth_service.dart'
    show currentUserProvider;
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/food_repository.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food_item.dart';
import 'package:mealvana_endurance/features/settings/presentation/screens/food_preferences_screen.dart';
import 'package:mealvana_endurance/features/settings/presentation/widgets/food_preferences/food_preference_item_widget.dart';
import 'package:mealvana_endurance/features/user_foods/data/user_foods_repository.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';
import 'package:mealvana_endurance/shared/services/preferences_service.dart';
import 'package:mealvana_endurance/shared/services/connectivity_checker.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/fakes/fake_postgrest.dart';
import '../../../helpers/fakes/recording_report.dart';
import '../../../helpers/widget_test_harness.dart';

const _user = '607f9dd5-1c2b-4e3d-8f4a-5b6c7d8e9f01';

class _MockFoodRepository extends Mock implements FoodRepository {}

class _StubConnectivity extends ConnectivityChecker {
  @override
  Future<bool> isOnline() async => true;

  @override
  Stream<bool> get onlineChanges => const Stream.empty();
}

void main() {
  testWidgets('the screen shows the server level for a catalog food, not the '
      'default', (tester) async {
    final server = FakePostgrest();
    final db = AppDatabase.memory();
    await tester.runAsync(() => server.signIn(_user));
    server.tables['users'] = [];
    server.tables['food_preferences'] = [
      {
        'id': '0f0e0d0c-0b0a-4908-8706-050403020100',
        'user_id': _user,
        'food_name': 'sports_drink',
        'preference': 'like',
        'preference_level': 4,
        'preference_source': 'manual',
        'created_at': '2026-10-08 14:02:11.123+00',
        'updated_at': '2026-10-08 14:02:11.123+00',
      },
    ];

    final foodRepository = _MockFoodRepository();
    when(() => foodRepository.getPrimaryFoodsForPreferences()).thenAnswer(
      (_) async => [
        FoodItem(
          id: 'tf-1',
          name: 'Sports Drink',
          displayName: 'Sports Drink',
          catalogName: 'sports_drink',
          productTypeId: 'sports_drink',
        ),
      ],
    );
    when(
      () => foodRepository.getAdditionalFoodsForPreferences(),
    ).thenAnswer((_) async => <FoodItem>[]);

    final report = RecordingReport();
    // pumpSeeded's environment, with the fake server's client in the deps.
    SharedPreferences.setMockInitialValues({});
    final prefs = await tester.runAsync(SharedPreferences.getInstance);
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockAppExternalDeps(supabaseClient: server.client),
          appConfigProvider.overrideWithValue(AppConfig.forTesting()),
          inMemoryDatabaseOverride(db),
          preferencesServiceProvider.overrideWith(
            (ref) => PreferencesService(prefs!),
          ),
          currentUserProvider.overrideWith((ref) async => null),
          reportProvider.overrideWithValue(report),
          connectivityCheckerProvider.overrideWithValue(_StubConnectivity()),
          foodRepositoryProvider.overrideWithValue(foodRepository),
          userRepositoryProvider.overrideWith(
            (ref) async => UserRepository(
              database: db,
              supabase: server.client,
              report: report,
            ),
          ),
          // No user_foods remote here: that sync degrades, as on a flaky
          // network.
          userFoodsRepositoryProvider.overrideWith(
            (ref) async => throw StateError('no remote in test'),
          ),
        ],
        child: wrapForTest(const FoodPreferencesScreen()),
      ),
    );
    await tester.pump();

    // Drift and the fake HTTP run real async work; let them finish.
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      if (find.byType(FoodPreferenceItemWidget).evaluate().isNotEmpty) break;
    }

    final item = tester.widget<FoodPreferenceItemWidget>(
      find.byType(FoodPreferenceItemWidget),
    );
    expect(item.food.name, 'Sports Drink');
    expect(item.sliderLevel, 4, reason: 'the server level, not the default 2');
    expect(
      report.faults,
      isEmpty,
      reason: report.faults.map((f) => '${f.message}: ${f.error}').join('\n'),
    );
  });
}
