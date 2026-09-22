/// A lapsed account cannot write a nutrition plan or an activity's detail
/// (mp-457 §4, mp-491, ticket 12).
///
/// Through the real ActivityDetailController and MacroTargetsController:
/// each write path asks the write guard first; refused, it opens the paywall
/// once and never constructs a repository or service, so nothing is written
/// or queued. The seeded state is the one the screen holds before an edit.
library;

import 'dart:async';

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/application/activities_service.dart';
import 'package:mealvana_endurance/features/activities/data/activities_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/events/data/events_repository.dart';
import 'package:mealvana_endurance/features/integrations/presentation/providers/tp_writeback_providers.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/food_operations_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/nutrition_plan_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/macro_repository.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/nutrition_plan_repository.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/template_foods_repository.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/carb_adjustment_level.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/macro_targets.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/pre_workout_hydration_check.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/run_parameters.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/time_slot_assignment.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/activity_detail_controller.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/activity_detail_state.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/macro_targets_controller.dart';

import '../../../../helpers/write_access.dart';

class _SeededDetail extends ActivityDetailController {
  @override
  FutureOr<ActivityDetailState> build({
    required String activityId,
    bool isNewActivity = false,
  }) => const ActivityDetailState();
}

/// The macro screen's state is content-heavy; a refused write never reads
/// it, so a Fake stands in.
class _FakeMacroState extends Fake implements MacroTargetsState {}

class _SeededMacros extends MacroTargetsController {
  @override
  FutureOr<MacroTargetsState> build() => _FakeMacroState();
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
        activitiesRepositoryProvider.overrideWith(
          untouched('activitiesRepository'),
        ),
        activitiesServiceProvider.overrideWith(untouched('activitiesService')),
        macroRepositoryProvider.overrideWith(untouched('macroRepository')),
        nutritionPlanRepositoryProvider.overrideWith(
          untouched('nutritionPlanRepository'),
        ),
        nutritionPlanServiceProvider.overrideWith(
          untouched('nutritionPlanService'),
        ),
        foodOperationsServiceProvider.overrideWith(
          untouched('foodOperationsService'),
        ),
        templateFoodsRepositoryProvider.overrideWith(
          untouched('templateFoodsRepository'),
        ),
        tpWritebackServiceProvider.overrideWith(
          untouched('tpWritebackService'),
        ),
        eventsRepositoryProvider.overrideWith(untouched('eventsRepository')),
        activityDetailControllerProvider.overrideWith(_SeededDetail.new),
        macroTargetsControllerProvider.overrideWith(_SeededMacros.new),
      ],
    );
    addTearDown(container.dispose);
  });

  group('ActivityDetailController, lapsed', () {
    final provider = activityDetailControllerProvider(activityId: 'a1');
    ActivityDetailController ctrl() => container.read(provider.notifier);
    const slot = TimeSlot(hourIndex: 0, slotIndex: 0);
    const other = TimeSlot(hourIndex: 1, slotIndex: 2);
    final paths = <String, Future<Object?> Function()>{
      'regeneratePlan': () => ctrl().regeneratePlan(),
      'saveActivity': () => ctrl().saveActivity(),
      'answerHydrationCheck': () =>
          ctrl().answerHydrationCheck(HydrationCheckAnswer.none),
      'clearHydrationCheckAnswer': () => ctrl().clearHydrationCheckAnswer(),
      'completeActivity': () => ctrl().completeActivity(overallSatisfaction: 4),
      'applyCarbFeedbackAdjustment': () =>
          ctrl().applyCarbFeedbackAdjustment(CarbAdjustmentLevel.muchLess),
      'updateWorkoutNotes': () => ctrl().updateWorkoutNotes('felt good'),
      'updateCompletionRating': () => ctrl().updateCompletionRating(4),
      'updateCompletionFeedback': () =>
          ctrl().updateCompletionFeedback(rating: 4),
      'updateScheduledDateTime': () =>
          ctrl().updateScheduledDateTime(DateTime(2026, 9, 23, 7)),
      'updateReminder': () => ctrl().updateReminder(null),
      'swapFoodItem': () => ctrl().swapFoodItem('f1', null, 'preRun'),
      'addFoodItem': () => ctrl().addFoodItem(null, 'preRun'),
      'deleteFoodItem': () => ctrl().deleteFoodItem('f1', 'preRun'),
      'updateFoodQuantity': () => ctrl().updateFoodQuantity('f1', 'preRun', 2),
      'updateSubPhaseQuantityWithScaling': () =>
          ctrl().updateSubPhaseQuantityWithScaling(0, 0, 2),
      'moveFoodToTimeSlot': () =>
          ctrl().moveFoodToTimeSlot('f1', 'duringRun', slot, other),
      'placeFoodInSlot': () =>
          ctrl().placeFoodInSlot('f1', 'duringRun', slot, 1),
      'removeFoodFromSlot': () =>
          ctrl().removeFoodFromSlot('f1', 'duringRun', slot),
      'moveSipFoodToSlot': () =>
          ctrl().moveSipFoodToSlot('f1', 'duringRun', slot, 1),
      'adjustSlotQuantity': () =>
          ctrl().adjustSlotQuantity('f1', 'duringRun', slot, 1),
      'deleteActivity': () => ctrl().deleteActivity(),
      'saveFuelLogAndComplete': () =>
          ctrl().saveFuelLogAndComplete(overallSatisfaction: 4),
      'updateExistingFuelLog': () => ctrl().updateExistingFuelLog(),
    };
    for (final entry in paths.entries) {
      test('${entry.key} opens the paywall and writes nothing', () async {
        await container.read(provider.future);
        await expectWriteRefused(opens, entry.value);
        final state = container.read(provider).value!;
        expect(state.isSaving, isFalse);
        expect(state.error, isNull);
      });
    }
  });

  group('MacroTargetsController, lapsed', () {
    MacroTargetsController ctrl() =>
        container.read(macroTargetsControllerProvider.notifier);
    final date = DateTime(2026, 9, 23);
    const time = TimeOfDay(hour: 7, minute: 0);
    final paths = <String, Future<Object?> Function()>{
      'generateMacros': () => ctrl().generateMacros(
        distanceText: '5',
        paceText: '8:00',
        timeBeforeRunMinutes: 60,
        gutTraining: GutTraining.low,
        distanceUnit: DistanceUnit.miles,
        paceUnit: PaceUnit.minPerMile,
        scheduledDate: date,
        scheduledTime: time,
      ),
      'generateRunningMacros': () => ctrl().generateRunningMacros(
        distanceText: '5',
        paceText: '8:00',
        timeBeforeRunMinutes: 60,
        gutTraining: GutTraining.low,
        distanceUnit: DistanceUnit.miles,
        paceUnit: PaceUnit.minPerMile,
        scheduledDate: date,
        scheduledTime: time,
      ),
      'generateCyclingMacros': () => ctrl().generateCyclingMacros(
        distanceMiles: 20,
        speedMph: 15,
        terrain: 'flat',
        indoorOutdoor: 'outdoor',
        elevationGainFt: 100,
        sessionGoal: 'endurance',
        intensityTarget: 'zone2',
        timeBeforeMinutes: 60,
        scheduledDate: date,
        scheduledTime: time,
        temperatureC: 20,
        humidityPct: 50,
      ),
      'generateSwimmingMacros': () => ctrl().generateSwimmingMacros(
        distanceMeters: 1500,
        paceSecondsper100m: 120,
        poolOrOpenWater: 'pool',
        waterTempC: 26,
        intensityTarget: 'zone2',
        sessionGoal: 'endurance',
        timeBeforeMinutes: 60,
        scheduledDate: date,
        scheduledTime: time,
      ),
      'generateBrickMacros': () => ctrl().generateBrickMacros(
        segments: const [],
        segmentOrder: const [],
        scheduledDate: date,
        scheduledTime: time,
        preActivityMinutes: 60,
      ),
      'updateMacroValue': () => ctrl().updateMacroValue(
        section: MacroSection.preRun,
        field: MacroField.preRunCarbs,
        newValue: 50,
      ),
      'resetToRecommended': () => ctrl().resetToRecommended(),
      'saveAllMacroChanges': () => ctrl().saveAllMacroChanges(
        preRunCarbs: 1,
        preRunProtein: 1,
        preRunFluids: 1,
        preRunSodium: 1,
        duringRunCarbs: 1,
        duringRunFluids: 1,
        duringRunSodium: 1,
        postRunCarbs: 1,
        postRunProtein: 1,
        postRunFluids: 1,
        postRunSodium: 1,
      ),
      'createNutritionPlan': () => ctrl().createNutritionPlan(),
    };
    for (final entry in paths.entries) {
      test('${entry.key} opens the paywall and writes nothing', () async {
        await container.read(macroTargetsControllerProvider.future);
        await expectWriteRefused(opens, entry.value);
      });
    }
  });
}
