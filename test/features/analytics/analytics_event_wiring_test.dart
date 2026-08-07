/// Tests for the analytics event wiring added for the activation/consumption
/// funnels (Notion 39ce3fdb — "Analytics event wiring + app_version fix").
///
/// Covers the two pieces whose correctness is not obvious by inspection:
///  - the onboarding funnel's duration/step-name helper
///  - `carb_loading_food_added`, which is fired from the *service* precisely
///    because two independent controllers can add food and instrumenting
///    either one alone would undercount.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:mealvana_endurance/features/carb_loading/application/carb_loading_food_service.dart';
import 'package:mealvana_endurance/features/carb_loading/application/food_selection_service.dart';
import 'package:mealvana_endurance/features/carb_loading/data/carb_loading_day_meal_repository.dart';
import 'package:mealvana_endurance/features/carb_loading/domain/carb_loading_day_meal.dart';
import 'package:mealvana_endurance/features/carb_loading/domain/carb_loading_food.dart';
import 'package:mealvana_endurance/features/carb_loading/domain/meal_type.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/providers/onboarding_analytics.dart';

import '../../helpers/fakes/recording_analytics_tracker.dart';

class _MockDayMealRepository extends Mock
    implements CarbLoadingDayMealRepository {}

class _MockFoodService extends Mock implements CarbLoadingFoodService {}

const _bagel = CarbLoadingFood(
  id: 'food-1',
  name: 'bagel',
  displayName: 'Bagel',
  carbsPerServing: 50,
  mealTypes: [MealType.breakfast],
);

CarbLoadingDayMeal _makeMeal() => const CarbLoadingDayMeal(
  id: 'meal-1',
  carbLoadingDayId: 'day-1',
  mealType: MealType.breakfast,
  foodDisplayName: 'Bagel',
  quantity: 2,
  carbsConsumed: 100,
);

void main() {
  group('OnboardingAnalytics', () {
    setUp(OnboardingAnalytics.reset);

    test('durationSec is null when onboarding was never started', () {
      // A resumed session or a deep link straight into a step. The caller must
      // omit `duration_sec` entirely rather than report a bogus 0, which would
      // drag the median completion time down.
      expect(OnboardingAnalytics.durationSec(), isNull);
    });

    test('durationSec returns elapsed seconds once started', () {
      OnboardingAnalytics.markStarted();
      final duration = OnboardingAnalytics.durationSec();

      expect(duration, isNotNull);
      expect(duration, greaterThanOrEqualTo(0));
    });
  });

  group('onboardingStepName', () {
    test('maps each live onboarding page index to its funnel name', () {
      // These strings are the analytics contract — Mixpanel funnels key off
      // them, so a silent reorder would break every historical report.
      // 2026-08 redesign: deliberate clean break to the 9-step list; the
      // funnel is rebuilt on these names and the old one archived.
      expect(onboardingStepName(0), 'sports_selection');
      expect(onboardingStepName(1), 'goals');
      expect(onboardingStepName(2), 'pitfalls');
      expect(onboardingStepName(3), 'connect_training');
      expect(onboardingStepName(4), 'personal_info');
      expect(onboardingStepName(5), 'body_composition');
      expect(onboardingStepName(6), 'nutrition_settings');
      expect(onboardingStepName(7), 'plan_reveal');
      expect(onboardingStepName(8), 'daily_plan_preview');
      expect(kOnboardingStepNames, hasLength(9));
    });

    test('degrades to a positional name if a page is added without a name', () {
      // Should not throw: a name/page mismatch must produce a usable event
      // rather than crash onboarding.
      expect(onboardingStepName(9), 'step_9');
      expect(onboardingStepName(-1), 'step_-1');
    });
  });

  group('carb_loading_food_added', () {
    late RecordingAnalyticsTracker analytics;
    late _MockDayMealRepository repo;
    late FoodSelectionService service;

    setUp(() {
      analytics = RecordingAnalyticsTracker();
      repo = _MockDayMealRepository();
      service = FoodSelectionService(
        dayMealRepository: repo,
        foodService: _MockFoodService(),
        analytics: analytics,
      );
    });

    test('fires when a default food is added to a meal', () async {
      when(
        () => repo.addDefaultFoodToMeal(
          carbLoadingDayId: any(named: 'carbLoadingDayId'),
          mealTypeId: any(named: 'mealTypeId'),
          carbLoadingFoodId: any(named: 'carbLoadingFoodId'),
          foodDisplayName: any(named: 'foodDisplayName'),
          quantity: any(named: 'quantity'),
          carbsPerServing: any(named: 'carbsPerServing'),
        ),
      ).thenAnswer((_) async => _makeMeal());

      await service.addDefaultFoodToMeal(
        carbLoadingDayId: 'day-1',
        mealType: MealType.breakfast,
        food: _bagel,
        quantity: 2,
      );

      final events = analytics.findEvents('carb_loading_food_added');
      expect(events, hasLength(1));
      expect(events.first.properties?['day_id'], 'day-1');
      expect(events.first.properties?['food_name'], 'Bagel');
      expect(events.first.properties?['quantity'], 2);
      expect(events.first.properties?['is_user_food'], isFalse);
    });

    test('does NOT fire when the underlying write throws', () async {
      // The event is emitted after the repository write, so a failed add must
      // not report as a successful one.
      when(
        () => repo.addDefaultFoodToMeal(
          carbLoadingDayId: any(named: 'carbLoadingDayId'),
          mealTypeId: any(named: 'mealTypeId'),
          carbLoadingFoodId: any(named: 'carbLoadingFoodId'),
          foodDisplayName: any(named: 'foodDisplayName'),
          quantity: any(named: 'quantity'),
          carbsPerServing: any(named: 'carbsPerServing'),
        ),
      ).thenThrow(Exception('db down'));

      await expectLater(
        service.addDefaultFoodToMeal(
          carbLoadingDayId: 'day-1',
          mealType: MealType.breakfast,
          food: _bagel,
        ),
        throwsA(isA<Exception>()),
      );

      expect(analytics.hasEvent('carb_loading_food_added'), isFalse);
    });
  });
}
