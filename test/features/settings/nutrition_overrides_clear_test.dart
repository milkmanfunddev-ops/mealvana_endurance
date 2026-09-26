// The Settings surface's "clear my plan-reveal overrides" path, through the
// real notifier.
//
// It is the one profile write that cannot be expressed with `??` — null means
// "leave them alone", not "clear them" — so it used to rebuild UserProfile
// field by field. That hand-rolled list silently reset every field it did not
// mention: body fat, lifestyle, training phase, the sweat test, and (as of
// v21) home location. copyWith owns the clear now; this pins that clearing
// the overrides touches nothing else.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:mealvana_endurance/features/activities/data/activities_repository.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/daily_macros/domain/enums.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/macro_repository.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/macro_targets.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_target_overrides.dart';
import 'package:mealvana_endurance/features/settings/domain/settings_state.dart';
import 'package:mealvana_endurance/features/settings/presentation/providers/settings_controller.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/providers/user_id_provider.dart';

class _MockUserRepository extends Mock implements UserRepository {}

class _MockActivitiesRepository extends Mock implements ActivitiesRepository {}

class _MockMacroRepository extends Mock implements MacroRepository {}

class _MockMacroTargets extends Mock implements MacroTargets {}

class _MockDuringRunMacros extends Mock implements DuringRunMacros {}

/// The real controller with a canned build(), so the save path under test is
/// the production one without dragging in content, coach and auth lookups.
class _StubbedBuildController extends SettingsController {
  @override
  FutureOr<SettingsState> build() => const SettingsState(
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
    nutritionTargetOverrides: NutritionTargetOverrides(
      pre: PreActivityOverrides(carbsG: 50.0),
    ),
  );
}

/// Everything the old hand-rolled reconstruction forgot, plus the overrides
/// being cleared.
UserProfile _profile({NutritionTargetOverrides? overrides}) => UserProfile(
  id: 'u1',
  deviceId: 'd1',
  gender: Gender.male,
  birthday: DateTime(1985, 3, 20),
  heightFeet: 5,
  heightInches: 11,
  weightPounds: 165,
  runsWithWaterBottle: false,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  appVersion: '1.0.0',
  bodyFatPct: 18.5,
  lifestyle: Lifestyle.active,
  typicalWeeklyHours: 10,
  carbCycleOptIn: true,
  trainingPhase: TrainingPhase.build,
  sweatSodium: SweatSodiumCat.high,
  knownSweatRateMlPerHour: 1200,
  sweatTestSource: 'gatorade_gx',
  homeCity: 'Birmingham, Alabama',
  homeLat: 33.5186,
  homeLon: -86.8104,
  homeTimezone: 'America/Chicago',
  nutritionTargetOverrides:
      overrides ??
      const NutritionTargetOverrides(pre: PreActivityOverrides(carbsG: 50.0)),
);

Activity _activity(
  String id, {
  ActivityStatus status = ActivityStatus.planned,
  ActivityType type = ActivityType.running,
  bool withPlan = true,
}) {
  final day = DateTime(2026, 9, 28, 7);
  return Activity(
    id: id,
    userId: 'u1',
    activityType: type,
    title: id,
    scheduledDateTime: day,
    plannedTime: day,
    status: status,
    nutritionPlanData: withPlan ? const {'sections': []} : null,
    durationMinutes: 108,
    createdAt: day,
    updatedAt: day,
  );
}

MacroTargets _planAt(double carbRateGPerH) {
  final during = _MockDuringRunMacros();
  when(() => during.carbRateGPerH).thenReturn(carbRateGPerH);
  final targets = _MockMacroTargets();
  when(() => targets.duringRun).thenReturn(during);
  return targets;
}

void main() {
  late _MockUserRepository repo;
  late _MockActivitiesRepository activities;
  late _MockMacroRepository macros;
  late UserProfile saved;
  late List<Activity> updated;

  setUpAll(() {
    registerFallbackValue(_profile());
    registerFallbackValue(_activity('fallback'));
    registerFallbackValue(ActivityType.running);
  });

  setUp(() {
    repo = _MockUserRepository();
    when(() => repo.getCurrentUser()).thenAnswer((_) async => _profile());
    when(
      () =>
          repo.updateUserProfile(any(), needsUpload: any(named: 'needsUpload')),
    ).thenAnswer((inv) async {
      saved = inv.positionalArguments.first as UserProfile;
    });
    activities = _MockActivitiesRepository();
    updated = [];
    when(
      () => activities.getActivitiesForDateRange(any(), any(), any()),
    ).thenAnswer((_) async => const []);
    when(
      () => activities.updateActivity(
        deviceId: any(named: 'deviceId'),
        activity: any(named: 'activity'),
        requireRemoteAck: any(named: 'requireRemoteAck'),
      ),
    ).thenAnswer((inv) async {
      final a = inv.namedArguments[#activity] as Activity;
      updated.add(a);
      return a;
    });
    macros = _MockMacroRepository();
    when(
      () => macros.getCachedMacroTargetsForActivity(
        any(),
        expectedActivityType: any(named: 'expectedActivityType'),
      ),
    ).thenAnswer((_) async => null);
  });

  Future<SettingsController> controller() async {
    final container = ProviderContainer(
      overrides: [
        userRepositoryProvider.overrideWith((_) async => repo),
        activitiesRepositoryProvider.overrideWith((_) => activities),
        macroRepositoryProvider.overrideWith((_) => macros),
        userIdProvider.overrideWith((_) async => 'u1'),
        settingsControllerProvider.overrideWith(_StubbedBuildController.new),
      ],
    );
    addTearDown(container.dispose);
    await container.read(settingsControllerProvider.future);
    return container.read(settingsControllerProvider.notifier);
  }

  group('finding 116-003: clearing a during override re-plans', () {
    const legacyDuring = NutritionTargetOverrides(
      during: DuringActivityOverrides(carbRateGPerH: 50.4),
    );

    setUp(() {
      when(
        () => repo.getCurrentUser(),
      ).thenAnswer((_) async => _profile(overrides: legacyDuring));
    });

    test('a planned run whose stored plan used 50.4 g/h is flagged', () async {
      when(
        () => activities.getActivitiesForDateRange(any(), any(), any()),
      ).thenAnswer((_) async => [_activity('12mi-run')]);
      when(
        () => macros.getCachedMacroTargetsForActivity(
          '12mi-run',
          expectedActivityType: any(named: 'expectedActivityType'),
        ),
      ).thenAnswer((_) async => _planAt(50.4));

      await (await controller()).saveNutritionTargetOverrides(null);

      expect(saved.nutritionTargetOverrides, isNull);
      expect(updated.map((a) => a.id), ['12mi-run']);
      expect(updated.single.needsNutritionRefresh, isTrue);
    });

    test('a plan not built on the override, a done workout and a plan-less '
        'activity stay untouched', () async {
      when(
        () => activities.getActivitiesForDateRange(any(), any(), any()),
      ).thenAnswer(
        (_) async => [
          _activity('fresh-plan'),
          _activity('done', status: ActivityStatus.completed),
          _activity('no-plan', withPlan: false),
        ],
      );
      when(
        () => macros.getCachedMacroTargetsForActivity(
          any(),
          expectedActivityType: any(named: 'expectedActivityType'),
        ),
      ).thenAnswer((inv) async {
        final id = inv.positionalArguments.first as String;
        return id == 'fresh-plan' ? _planAt(63.0) : _planAt(50.4);
      });

      await (await controller()).saveNutritionTargetOverrides(null);

      expect(updated, isEmpty);
    });

    test('the plan JSON is read when no cached targets exist', () async {
      final a = Activity(
        id: 'json-plan',
        userId: 'u1',
        activityType: ActivityType.running,
        title: 'json-plan',
        scheduledDateTime: DateTime(2026, 9, 28, 7),
        status: ActivityStatus.planned,
        nutritionPlanData: const {
          'detailedMacroTargets': {
            'duringRun': {'carbRateGPerH': 50.4},
          },
        },
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 1),
      );
      when(
        () => activities.getActivitiesForDateRange(any(), any(), any()),
      ).thenAnswer((_) async => [a]);

      await (await controller()).saveNutritionTargetOverrides(null);

      expect(updated.map((x) => x.id), ['json-plan']);
    });

    test(
      'changing the rate instead of clearing it flags the old plans too',
      () async {
        when(
          () => activities.getActivitiesForDateRange(any(), any(), any()),
        ).thenAnswer((_) async => [_activity('12mi-run')]);
        when(
          () => macros.getCachedMacroTargetsForActivity(
            any(),
            expectedActivityType: any(named: 'expectedActivityType'),
          ),
        ).thenAnswer((_) async => _planAt(50.4));

        await (await controller()).saveNutritionTargetOverrides(
          const NutritionTargetOverrides(
            duringRun: DuringActivityOverrides(carbRateGPerH: 70),
          ),
        );

        expect(updated.map((a) => a.id), ['12mi-run']);
      },
    );

    test('a flagging failure never fails the settings save', () async {
      when(
        () => activities.getActivitiesForDateRange(any(), any(), any()),
      ).thenThrow(Exception('drift closed'));

      final c = await controller();
      await c.saveNutritionTargetOverrides(null);

      expect(saved.nutritionTargetOverrides, isNull);
      expect(c.state.hasError, isFalse);
    });
  });

  test('removedDuringRates: only rates that left or changed', () {
    final removed = SettingsController.removedDuringRates(
      const NutritionTargetOverrides(
        duringRun: DuringActivityOverrides(carbRateGPerH: 50.4),
        duringCycling: DuringActivityOverrides(carbRateGPerH: 80),
      ),
      const NutritionTargetOverrides(
        duringCycling: DuringActivityOverrides(carbRateGPerH: 80.2),
      ),
    );
    expect(removed, {ActivityType.running: 50.4});
  });

  test('clearing the overrides keeps every other profile field', () async {
    await (await controller()).saveNutritionTargetOverrides(null);

    expect(saved.nutritionTargetOverrides, isNull);
    // The fields the hand-rolled reconstruction used to wipe.
    expect(saved.bodyFatPct, 18.5);
    expect(saved.lifestyle, Lifestyle.active);
    expect(saved.typicalWeeklyHours, 10);
    expect(saved.carbCycleOptIn, isTrue);
    expect(saved.trainingPhase, TrainingPhase.build);
    expect(saved.sweatSodium, SweatSodiumCat.high);
    expect(saved.knownSweatRateMlPerHour, 1200);
    expect(saved.sweatTestSource, 'gatorade_gx');
    expect(saved.homeCity, 'Birmingham, Alabama');
    expect(saved.homeLat, 33.5186);
    expect(saved.homeLon, -86.8104);
    expect(saved.homeTimezone, 'America/Chicago');
  });

  test('setting new overrides replaces them and keeps the rest', () async {
    const replacement = NutritionTargetOverrides(
      pre: PreActivityOverrides(carbsG: 75.0),
    );

    await (await controller()).saveNutritionTargetOverrides(replacement);

    expect(saved.nutritionTargetOverrides?.pre?.carbsG, 75.0);
    expect(saved.bodyFatPct, 18.5);
    expect(saved.homeCity, 'Birmingham, Alabama');
  });
}
