// CONTROLLER-LEVEL test for the hydration check — the real
// ActivityDetailController.answerHydrationCheck / clearHydrationCheckAnswer
// through a ProviderContainer, with STORED targets shaped the way the SERVER
// produces them (serverPreRun: lb→kg 0.453592, 3-decimal wire rounding) while
// the device recomputes at 0.45359237.
//
// Why (2026-08-26): every gesture / service test drove the write path through
// a test host with `mockPreRun()` on both sides, so the controller — the weight
// lookup, the frozen lead time, tempC, the atomic save — was only ever
// exercised by hand, and the one hand test was on a sub-2h plan where the
// check is suppressed. On the first real ≥2h plan the inv-8b assert threw
// inside the tap and "the hydration check was not clickable". This test would
// have failed on that build.
//
// Mutation checks: (1) restore the `assert((low - result.fluidLowMl).abs() <
// 1e-3)` in PreWorkoutHydrationCheckService → 'DARK on server-shaped targets'
// fails; (2) drop `saveMacroTargetsForActivity` from
// _commitHydrationCheckWrite → the cache assertion fails.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/application/activities_service.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/auth/application/auth_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/macro_repository.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/macro_targets.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/pre_workout_hydration_check.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/activity_detail_controller.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/activity_detail_state.dart';
import 'package:mealvana_endurance/features/settings/domain/settings_state.dart';
import 'package:mealvana_endurance/features/settings/presentation/providers/settings_controller.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../helpers/fixtures/user_fixtures.dart';
import '../../pre_workout_before_card_fixtures.dart';

class MockAuthService extends Mock implements AuthService {}

class MockAnalyticsTracker extends Mock implements AnalyticsTracker {}

class MockMacroRepository extends Mock implements MacroRepository {}

class MockActivitiesService extends Mock implements ActivitiesService {}

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockSentryReporter extends Mock implements SentryReporter {}

class MockSharedPreferences extends Mock implements SharedPreferences {}

class _FakeActivity extends Fake implements Activity {}

class _FakeMacroTargets extends Fake implements MacroTargets {}

class _SeededActivityDetailController extends ActivityDetailController {
  _SeededActivityDetailController(this._seed);
  final ActivityDetailState _seed;

  @override
  FutureOr<ActivityDetailState> build({
    required String activityId,
    bool isNewActivity = false,
  }) => _seed;
}

/// Profile weight in POUNDS, the way settings carries it (161 lb ≈ 73 kg).
class _SeededSettingsController extends SettingsController {
  _SeededSettingsController(this._weightPounds);
  final double? _weightPounds;

  @override
  FutureOr<SettingsState> build() => SettingsState(
    title: 'Settings',
    profileSectionTitle: 'Profile',
    preferenceSectionTitle: 'Preferences',
    genderLabel: 'Gender',
    birthdayLabel: 'Birthday',
    heightLabel: 'Height',
    weightLabel: 'Weight',
    waterBottleLabel: 'Water Bottle',
    distanceUnitLabel: 'Distance',
    paceUnitLabel: 'Pace',
    gutTrainingLabel: 'Gut Training',
    saveButtonText: 'Save',
    weightPounds: _weightPounds,
  );
}

const _userId = 'user-63kg';

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeActivity());
    registerFallbackValue(_FakeMacroTargets());
  });

  late MockAuthService auth;
  late MockMacroRepository macroRepo;
  late MockActivitiesService activities;
  late List<Activity> savedActivities;

  setUp(() {
    auth = MockAuthService();
    macroRepo = MockMacroRepository();
    activities = MockActivitiesService();
    savedActivities = [];
    when(
      () => auth.getCurrentUser(),
    ).thenAnswer((_) async => UserFixtures.completedUser(id: _userId));
    when(
      () => macroRepo.saveMacroTargetsForActivity(any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => activities.updateActivity(
        deviceId: any(named: 'deviceId'),
        activity: any(named: 'activity'),
      ),
    ).thenAnswer((inv) async {
      final a = inv.namedArguments[#activity] as Activity;
      savedActivities.add(a);
      return a;
    });
  });

  ({ProviderContainer container, ActivityDetailController notifier}) boot(
    ActivityDetailState seed, {
    double? weightPounds = 161,
  }) {
    final activityId = seed.activity!.id;
    when(
      () => activities.getActivityById(any(), activityId),
    ).thenAnswer((_) async => seed.activity);
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        analyticsTrackerProvider.overrideWithValue(MockAnalyticsTracker()),
        macroRepositoryProvider.overrideWithValue(macroRepo),
        activitiesServiceProvider.overrideWithValue(activities),
        settingsControllerProvider.overrideWith(
          () => _SeededSettingsController(weightPounds),
        ),
        appExternalDepsProvider.overrideWithValue(
          AppExternalDeps(
            analytics: MockAnalyticsTracker(),
            supabaseClient: MockSupabaseClient(),
            sentry: MockSentryReporter(),
            logger: NoopAppLogger(),
            sharedPreferences: MockSharedPreferences(),
          ),
        ),
        activityDetailControllerProvider(
          activityId: activityId,
          isNewActivity: false,
        ).overrideWith(() => _SeededActivityDetailController(seed)),
      ],
    );
    addTearDown(container.dispose);
    final provider = activityDetailControllerProvider(
      activityId: activityId,
      isNewActivity: false,
    );
    container.read(provider); // prime the seed
    return (container: container, notifier: container.read(provider.notifier));
  }

  ActivityDetailState seed({double t = 135, double weightLb = 161}) {
    final activity = mockActivity(
      timeBeforeMinutes: t.toInt(),
      userId: _userId,
    );
    return ActivityDetailState(
      activity: activity,
      nutritionPlan: mockPlan(mockSubPhases(t)),
      macroTargets: mockMacroTargets(serverPreRun(t: t, weightLb: weightLb)),
    );
  }

  ActivityDetailState stateOf(ProviderContainer c, String id) => c
      .read(
        activityDetailControllerProvider(activityId: id, isNewActivity: false),
      )
      .requireValue;

  group('answerHydrationCheck through the real controller', () {
    test(
      'DARK on server-shaped targets: target moves, band kept, row added, one save',
      () async {
        final s = seed();
        final storedPre = s.macroTargets!.preRun;
        final b = boot(s);

        await b.notifier.answerHydrationCheck(HydrationCheckAnswer.dark);

        final after = stateOf(b.container, s.activity!.id);
        final pre = after.macroTargets!.preRun;
        // The device factor (0.45359237) ≠ the server factor (0.453592):
        // the target still moves by 4·BW, and the STORED band survives.
        expect(pre.fluidsMl, isNot(storedPre.fluidsMl));
        expect(
          pre.fluidsMl,
          closeTo(storedPre.fluidsMl! + 4 * 161 * kDeviceKgPerLb, 0.05),
        );
        expect(pre.fluidsLowMl, storedPre.fluidsLowMl);
        expect(pre.fluidsHighMl, storedPre.fluidsHighMl);
        expect(pre.hydrationCheckUsed, 'dark');

        final record = after.nutritionPlan!.preWorkoutHydrationCheck!;
        expect(record.answer, HydrationCheckAnswer.dark);
        expect(record.addedWaterFoodId, isNotNull);
        final snack = after.nutritionPlan!.sections.first.subPhases!.firstWhere(
          (sp) => sp.subPhaseType == 'snack',
        );
        expect(
          snack.foodItems.where((f) => f.origin == kHydrationCheckRowOrigin),
          hasLength(1),
        );

        // One atomic write carrying plan + record + moved targets, and the
        // activity-scoped cache refreshed (the load path reads it first).
        expect(savedActivities, hasLength(1));
        final data = savedActivities.single.nutritionPlanData!;
        expect(
          (data[PreWorkoutHydrationCheckRecord.jsonKey] as Map)['answer'],
          'dark',
        );
        expect(
          ((data['detailedMacroTargets'] as Map)['preRun'] as Map)['fluidsMl'],
          closeTo(pre.fluidsMl!, 1e-6),
        );
        verify(
          () => macroRepo.saveMacroTargetsForActivity(s.activity!.id, any()),
        ).called(1);
      },
    );

    test('PALE: recorded, target unchanged, still persisted', () async {
      final s = seed();
      final b = boot(s);
      await b.notifier.answerHydrationCheck(HydrationCheckAnswer.pale);
      final after = stateOf(b.container, s.activity!.id);
      expect(
        after.macroTargets!.preRun.fluidsMl,
        s.macroTargets!.preRun.fluidsMl,
      );
      expect(
        after.nutritionPlan!.preWorkoutHydrationCheck!.answer,
        HydrationCheckAnswer.pale,
      );
      expect(savedActivities, hasLength(1));
    });

    test(
      'clearHydrationCheckAnswer reverts exactly and persists again',
      () async {
        final s = seed();
        final b = boot(s);
        await b.notifier.answerHydrationCheck(HydrationCheckAnswer.notYet);
        await b.notifier.clearHydrationCheckAnswer();
        final after = stateOf(b.container, s.activity!.id);
        expect(
          after.macroTargets!.preRun.fluidsMl,
          s.macroTargets!.preRun.fluidsMl,
        );
        expect(after.nutritionPlan!.preWorkoutHydrationCheck, isNull);
        expect(
          after.nutritionPlan!.sections.first.subPhases!
              .expand((sp) => sp.foodItems)
              .where((f) => f.origin == kHydrationCheckRowOrigin),
          isEmpty,
        );
        expect(savedActivities, hasLength(2));
      },
    );

    test(
      'no profile weight: nothing moves, nothing is written (no 70-kg stand-in)',
      () async {
        final s = seed();
        final b = boot(s, weightPounds: null);
        await b.notifier.answerHydrationCheck(HydrationCheckAnswer.dark);
        final after = stateOf(b.container, s.activity!.id);
        expect(
          after.macroTargets!.preRun.fluidsMl,
          s.macroTargets!.preRun.fluidsMl,
        );
        expect(after.nutritionPlan!.preWorkoutHydrationCheck, isNull);
        expect(savedActivities, isEmpty);
      },
    );

    test('sub-2h plan: the controller writes nothing', () async {
      final s = seed(t: 90);
      final b = boot(s);
      await b.notifier.answerHydrationCheck(HydrationCheckAnswer.dark);
      expect(
        stateOf(
          b.container,
          s.activity!.id,
        ).nutritionPlan!.preWorkoutHydrationCheck,
        isNull,
      );
      expect(savedActivities, isEmpty);
    });
  });
}
