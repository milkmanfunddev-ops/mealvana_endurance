/// A lapsed account cannot write carb-loading plans or days (mp-457 §4,
/// mp-491, ticket 12).
///
/// Through the real CarbLoadingController and
/// CarbLoadingDayDetailController: each write path asks the write guard
/// first; refused, it opens the paywall once and never constructs a service
/// or repository, so nothing is written or queued.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/carb_loading/application/carb_loading_food_service.dart';
import 'package:mealvana_endurance/features/carb_loading/application/carb_loading_service.dart';
import 'package:mealvana_endurance/features/carb_loading/application/food_selection_service.dart';
import 'package:mealvana_endurance/features/carb_loading/data/carb_loading_repository.dart';
import 'package:mealvana_endurance/features/carb_loading/domain/carb_loading_day_meal.dart';
import 'package:mealvana_endurance/features/carb_loading/domain/carb_loading_food.dart';
import 'package:mealvana_endurance/features/carb_loading/domain/carb_loading_user_food.dart';
import 'package:mealvana_endurance/features/carb_loading/domain/meal_type.dart';
import 'package:mealvana_endurance/features/carb_loading/presentation/providers/carb_loading_controller.dart';
import 'package:mealvana_endurance/features/carb_loading/presentation/providers/carb_loading_day_detail_controller.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart' as db;

import '../../helpers/write_access.dart';

class _FakeDay extends Fake implements db.CarbLoadingDay {}

class _FakeFood extends Fake implements CarbLoadingFood {}

class _FakeUserFood extends Fake implements CarbLoadingUserFood {}

/// The one meal on the seeded day, so increment/decrement find it before
/// they delegate to the guarded updateQuantity.
class _FakeMeal extends Fake implements CarbLoadingDayMeal {
  @override
  String get id => 'm1';
  @override
  int get quantity => 1;
}

class _SeededPlans extends CarbLoadingController {
  @override
  FutureOr<void> build() {}
}

class _SeededDay extends CarbLoadingDayDetailController {
  @override
  Future<CarbLoadingDayDetailState> build(String carbLoadingDayId) async =>
      CarbLoadingDayDetailState(
        carbLoadingDay: _FakeDay(),
        meals: [_FakeMeal()],
        defaultFoods: const [],
        userFoods: const [],
      );
}

void main() {
  late PaywallOpens opens;
  late ProviderContainer container;

  setUp(() {
    opens = PaywallOpens();
    container = ProviderContainer(
      overrides: [
        writesRefused(),
        opens.override,
        carbLoadingServiceProvider.overrideWith(
          untouched('carbLoadingService'),
        ),
        carbLoadingFoodServiceProvider.overrideWith(
          untouched('carbLoadingFoodService'),
        ),
        foodSelectionServiceProvider.overrideWith(
          untouched('foodSelectionService'),
        ),
        carbLoadingRepositoryProvider.overrideWith(
          untouched('carbLoadingRepository'),
        ),
        carbLoadingControllerProvider.overrideWith(_SeededPlans.new),
        carbLoadingDayDetailControllerProvider.overrideWith(_SeededDay.new),
      ],
    );
    addTearDown(container.dispose);
  });

  group('CarbLoadingController, lapsed', () {
    CarbLoadingController ctrl() =>
        container.read(carbLoadingControllerProvider.notifier);
    final raceDate = DateTime(2026, 10, 4);
    final paths = <String, Future<Object?> Function()>{
      'createCarbLoadingPlan': () => ctrl().createCarbLoadingPlan(
        eventId: 'e1',
        protocolDays: 3,
        raceDate: raceDate,
        bodyWeightPounds: 160,
      ),
      'deleteCarbLoadingPlan': () => ctrl().deleteCarbLoadingPlan('e1'),
      'deleteCarbLoadingDay': () => ctrl().deleteCarbLoadingDay('d1'),
      'updateCarbLoadingProtocol': () => ctrl().updateCarbLoadingProtocol(
        eventId: 'e1',
        newProtocolDays: 2,
        raceDate: raceDate,
        bodyWeightPounds: 160,
      ),
    };
    for (final entry in paths.entries) {
      test('${entry.key} opens the paywall and writes nothing', () async {
        await expectWriteRefused(opens, entry.value);
      });
    }
  });

  group('CarbLoadingDayDetailController, lapsed', () {
    final provider = carbLoadingDayDetailControllerProvider('d1');
    CarbLoadingDayDetailController ctrl() => container.read(provider.notifier);
    final paths = <String, Future<Object?> Function()>{
      'addDefaultFood': () =>
          ctrl().addDefaultFood(MealType.breakfast, _FakeFood()),
      'addUserFood': () => ctrl().addUserFood(MealType.lunch, _FakeUserFood()),
      'updateQuantity': () => ctrl().updateQuantity('m1', 2),
      'incrementQuantity': () => ctrl().incrementQuantity('m1'),
      'decrementQuantity': () => ctrl().decrementQuantity('m1'),
      'removeMeal': () => ctrl().removeMeal('m1'),
      'clearMealType': () => ctrl().clearMealType(MealType.dinner),
      'resetDay': () => ctrl().resetDay(),
      'updateCarbTarget': () =>
          ctrl().updateCarbTarget(carbsPerKg: 10, dailyTargetG: 700),
    };
    for (final entry in paths.entries) {
      test('${entry.key} opens the paywall and writes nothing', () async {
        await container.read(provider.future);
        await expectWriteRefused(opens, entry.value);
        expect(container.read(provider).value!.meals, hasLength(1));
      });
    }
  });
}
