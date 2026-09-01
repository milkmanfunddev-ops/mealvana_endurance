// PERSISTENCE (deferred-ledger P2 / test plan I10): the hydration answer, the
// athlete's stepper edits and the tagged water row survive a relaunch — they
// are written into `activities.nutrition_plan_data` beside the plan in ONE
// JSON, round-trip through the Drift `activities` row, and parse back through
// the same mappers the ActivityDetailController's load path uses.
//
// JSON keys under `nutrition_plan_data`:
//   preWorkoutHydrationCheck: { answer, baselineFluidMl, baselineFluidTiers,
//                               baselineHydrationCheckUsed, addedWaterFoodId }
//   sections[before].subPhases[snack].foodItems[].origin = "hydration_check"
//   detailedMacroTargets.preRun.{fluidsMl, fluidTiers, hydrationCheckUsed}
//
// This is the seam test: service → plan-data JSON (built exactly as
// ActivityDetailController._buildNutritionPlanData does) → Drift row →
// getActivityById → NutritionPlanMapper.fromJson + MacroTargets.fromJson →
// assembler. What the card renders after "relaunch" is what the athlete left.

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/application/activity_deduplication_service.dart';
import 'package:mealvana_endurance/features/activities/data/activities_repository.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/pre_workout_before_card_assembler.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/pre_workout_hydration_check_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/nutrition_plan_mapper.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food_item_data.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/macro_targets.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_plan.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/pre_workout_hydration_check.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pre_workout_before_card_fixtures.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockAppLogger extends Mock implements AppLogger {}

class MockSentryReporter extends Mock implements SentryReporter {}

class MockActivityDeduplicationService extends Mock
    implements ActivityDeduplicationService {}

/// Exactly what ActivityDetailController._buildNutritionPlanData writes.
Map<String, dynamic> _planData(NutritionPlan plan, MacroTargets targets) => {
  ...plan.toJson(),
  'detailedMacroTargets': targets.toJson(),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late ActivitiesRepository repository;
  late MockAppLogger logger;
  late MockSentryReporter sentry;

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    logger = MockAppLogger();
    sentry = MockSentryReporter();
    when(
      () => logger.info(
        any(),
        context: any(named: 'context'),
        data: any(named: 'data'),
      ),
    ).thenReturn(null);
    when(
      () => logger.debug(
        any(),
        context: any(named: 'context'),
        data: any(named: 'data'),
      ),
    ).thenReturn(null);
    when(
      () => logger.warning(
        any(),
        context: any(named: 'context'),
        error: any(named: 'error'),
        stackTrace: any(named: 'stackTrace'),
        data: any(named: 'data'),
      ),
    ).thenReturn(null);
    when(
      () => logger.error(
        any(),
        context: any(named: 'context'),
        error: any(named: 'error'),
        stackTrace: any(named: 'stackTrace'),
        data: any(named: 'data'),
      ),
    ).thenReturn(null);
    when(
      () => sentry.reportNetworkError(
        any(),
        url: any(named: 'url'),
        method: any(named: 'method'),
        statusCode: any(named: 'statusCode'),
        timeout: any(named: 'timeout'),
        stackTrace: any(named: 'stackTrace'),
      ),
    ).thenAnswer((_) async {});
    repository = ActivitiesRepository(
      supabase: MockSupabaseClient(),
      database: database,
      logger: logger,
      sentry: sentry,
      deduplicationService: MockActivityDeduplicationService(),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'answer + edited tagged row + stepper edit survive the Drift round-trip and re-assemble',
    () async {
      const t = 180.0;
      // --- session 1: the athlete answers DARK, edits the added row to 2 cups
      // and steps the RXBAR to 2.
      final dark = PreWorkoutHydrationCheckService.answer(
        plan: mockPlan(mockSubPhases(t)),
        targets: mockMacroTargets(mockPreRun(t: t)),
        answer: HydrationCheckAnswer.dark,
        bodyWeightKg: kMockBodyWeightKg,
        workoutDurationMin: kMockDurationMin,
        timeBeforeWorkoutMin: t,
        tempC: 22,
        newFoodId: () => 'hydration-check-water-1',
      );
      final edited = dark.plan.copyWith(
        sections: dark.plan.sections.map((s) {
          if (!s.hasSubPhases) return s;
          return s.copyWith(
            subPhases: s.subPhases!.map((sp) {
              return sp.copyWith(
                foodItems: sp.foodItems.map((f) {
                  if (f.id == 'hydration-check-water-1') {
                    return FoodItemData(
                      id: f.id,
                      name: f.name,
                      quantity: '2 cups Water',
                      displayName: f.displayName,
                      isDrink: true,
                      origin: f.origin,
                      nutritionalInfo: const NutritionalInfo(
                        fluids: kCupMl * 2,
                      ),
                    );
                  }
                  if (f.id == 'rx') return rxbar(qty: 2);
                  return f;
                }).toList(),
              );
            }).toList(),
          );
        }).toList(),
      );

      // One atomic write: plan (answer record + rows) + targets in one JSON.
      final planData = _planData(edited, dark.targets);
      expect(planData[PreWorkoutHydrationCheckRecord.jsonKey], isNotNull);
      // insertActivity clears the id and lets Drift generate one (the
      // offline-first create path); the row carries the whole JSON.
      final saved = await repository.insertActivity(
        mockActivity(timeBeforeMinutes: 180, nutritionPlanData: planData),
      );
      expect(saved.nutritionPlanData, isNotNull);

      // --- "relaunch": a fresh read through the repository.
      final reloaded = await repository.getActivityById('user-63kg', saved.id);
      expect(reloaded, isNotNull);
      final stored = reloaded!.nutritionPlanData!;

      // The keys, as persisted.
      final record = Map<String, dynamic>.from(
        stored[PreWorkoutHydrationCheckRecord.jsonKey] as Map,
      );
      expect(record['answer'], 'dark');
      expect(
        (record['baselineFluidMl'] as num).toDouble(),
        closeTo(472.5, 1e-6),
      );
      expect(record['addedWaterFoodId'], 'hydration-check-water-1');
      expect(record['baselineHydrationCheckUsed'], 'pale');
      expect(record['baselineFluidTiers'], isA<List>());
      final preJson = Map<String, dynamic>.from(
        (stored['detailedMacroTargets'] as Map)['preRun'] as Map,
      );
      expect((preJson['fluidsMl'] as num).toDouble(), closeTo(724.5, 1e-6));
      expect(preJson['hydrationCheckUsed'], 'dark');

      // The controller's load path: plan from the mapper, targets from the
      // embedded snapshot.
      final plan = NutritionPlanMapper.fromJson(
        Map<String, dynamic>.from(stored),
      );
      final targets = MacroTargets.fromJson(
        Map<String, dynamic>.from(stored['detailedMacroTargets'] as Map),
      );
      expect(plan.preWorkoutHydrationCheck!.answer, HydrationCheckAnswer.dark);
      expect(targets.preRun.fluidsMl, closeTo(724.5, 1e-6));
      expect(targets.preRun.fluidsLowMl, closeTo(315, 1e-6));
      expect(targets.preRun.fluidsHighMl, closeTo(756, 1e-6));

      final snack = plan.sections.first.subPhases!.firstWhere(
        (sp) => sp.subPhaseType == 'snack',
      );
      final waterRow = snack.foodItems.firstWhere(
        (f) => f.id == 'hydration-check-water-1',
      );
      expect(waterRow.origin, kHydrationCheckRowOrigin);
      expect(waterRow.quantity, '2 cups Water'); // the athlete's edit survived
      expect(waterRow.nutritionalInfo!.fluids, closeTo(kCupMl * 2, 1e-6));
      expect(
        snack.foodItems.firstWhere((f) => f.id == 'rx').quantity,
        startsWith('2 '),
      );

      // What the card renders after relaunch.
      final data = PreWorkoutBeforeCardAssembler.assemble(
        preRun: targets.preRun,
        subPhases: plan.sections.first.subPhases!,
        timeBeforeWorkoutMin: reloaded.timeBeforeMinutes!.toDouble(),
        bodyWeightKg: kMockBodyWeightKg,
        hydrationCheck: plan.preWorkoutHydrationCheck,
      );
      expect(data.hydrationCheck!.answer, HydrationCheckAnswer.dark);
      expect(data.hydrationCheck!.targetOz, 24);
      expect(data.fluids.target, 24);
      expect(data.fluids.bandLow, 10);
      expect(data.fluids.bandHigh, 26);
      expect(
        data.feedings[1].rows
            .where((r) => r.isHydrationCheckRow)
            .single
            .quantity,
        2,
      );

      // ...and Change answer after relaunch still reverts exactly (H-3).
      final reverted = PreWorkoutHydrationCheckService.revert(
        plan: plan,
        targets: targets,
      );
      expect(reverted.targets.preRun.fluidsMl, closeTo(472.5, 1e-6));
      expect(
        reverted.plan.sections.first.subPhases!
            .firstWhere((sp) => sp.subPhaseType == 'snack')
            .foodItems
            .map((f) => f.id),
        ['rx'],
      );
      expect(reverted.plan.preWorkoutHydrationCheck, isNull);
    },
  );

  test(
    'a plan with NO answer round-trips without the key (TO-DO on relaunch)',
    () async {
      final planData = _planData(
        mockPlan(mockSubPhases(180)),
        mockMacroTargets(mockPreRun(t: 180)),
      );
      expect(
        planData.containsKey(PreWorkoutHydrationCheckRecord.jsonKey),
        isFalse,
      );
      final saved = await repository.insertActivity(
        mockActivity(timeBeforeMinutes: 180, nutritionPlanData: planData),
      );
      final reloaded = await repository.getActivityById('user-63kg', saved.id);
      final plan = NutritionPlanMapper.fromJson(
        Map<String, dynamic>.from(reloaded!.nutritionPlanData!),
      );
      expect(plan.preWorkoutHydrationCheck, isNull);
    },
  );

  test('the record JSON is stable and self-describing', () {
    final record = PreWorkoutHydrationCheckRecord(
      answer: HydrationCheckAnswer.notYet,
      baselineFluidMl: 472.5,
      baselineFluidTiers: const [
        PreRunFluidTier(tier: 'meal', fluidMl: 472.5),
        PreRunFluidTier(tier: 'snack', fluidMl: 0),
        PreRunFluidTier(tier: 'top_off', fluidMl: 0),
      ],
      baselineHydrationCheckUsed: 'pale',
      addedWaterFoodId: null,
    );
    final json =
        jsonDecode(jsonEncode(record.toJson())) as Map<String, dynamic>;
    expect(json.keys.toSet(), {
      'answer',
      'baselineFluidMl',
      'baselineFluidTiers',
      'baselineHydrationCheckUsed',
      'addedWaterFoodId',
    });
    expect(json['answer'], 'not_yet');
    final back = PreWorkoutHydrationCheckRecord.fromJson(json)!;
    expect(back.answer, HydrationCheckAnswer.notYet);
    expect(back.alreadyCovered, isTrue);
    expect(back.baselineFluidTiers!.length, 3);
    // Unknown / missing → null (never a phantom answer).
    expect(PreWorkoutHydrationCheckRecord.fromJson(null), isNull);
    expect(
      PreWorkoutHydrationCheckRecord.fromJson({'answer': 'purple'}),
      isNull,
    );
  });
}
