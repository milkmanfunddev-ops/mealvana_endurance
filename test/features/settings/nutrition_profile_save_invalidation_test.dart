// Q-016 behavioural chain — the Settings surface half:
//   Nutrition Profile → change an engine input → Save
//     → DailyMacroService.invalidateForManualInputChange(userId)   (today+future)
//     → dailyMacrosControllerProvider invalidated (visible day recomputes)
// and the negative half: a save that changes NO engine input triggers neither.
//
// The window itself (today + future, never past) is pinned on a real Drift DB
// in test/features/daily_macros/manual_input_invalidation_test.dart; here the
// service is a recording fake so the test pins the WIRING of the save path.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/daily_macros/application/daily_macro_service.dart';
import 'package:mealvana_endurance/features/daily_macros/domain/enums.dart';
import 'package:mealvana_endurance/features/daily_macros/presentation/providers/daily_macros_controller.dart';
import 'package:mealvana_endurance/features/integrations/presentation/providers/integrations_providers.dart';
import 'package:mealvana_endurance/features/settings/domain/settings_state.dart';
import 'package:mealvana_endurance/features/settings/presentation/providers/settings_controller.dart';
import 'package:mealvana_endurance/features/settings/presentation/screens/nutrition_profile_screen.dart';

import '../../helpers/widget_test_harness.dart';

class _MockUserRepository extends Mock implements UserRepository {}

class _RecordingMacroService extends Mock implements DailyMacroService {}

class _StubSettingsController extends SettingsController {
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
  );
}

/// Counts builds so the test can observe `ref.invalidate(...)` on the
/// daily-macros controller without running its real (network) build.
int _macroBuilds = 0;

class _CountingMacrosController extends DailyMacrosController {
  @override
  FutureOr<DailyMacrosState> build() {
    _macroBuilds++;
    return DailyMacrosState(selectedDate: DateTime(2026, 8, 19));
  }
}

UserProfile _profile() => UserProfile(
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
  lifestyle: Lifestyle.mixed,
  typicalWeeklyHours: 10,
  carbCycleOptIn: true,
  trainingPhase: TrainingPhase.build,
);

void main() {
  setUpAll(() => registerFallbackValue(_profile()));

  late _MockUserRepository repo;
  late _RecordingMacroService macros;
  late UserProfile saved;

  setUp(() {
    _macroBuilds = 0;
    repo = _MockUserRepository();
    macros = _RecordingMacroService();
    when(() => repo.getCurrentUser()).thenAnswer((_) async => _profile());
    when(
      () =>
          repo.updateUserProfile(any(), needsUpload: any(named: 'needsUpload')),
    ).thenAnswer((inv) async {
      saved = inv.positionalArguments.first as UserProfile;
    });
    when(
      () =>
          macros.invalidateForManualInputChange(any(), now: any(named: 'now')),
    ).thenAnswer((_) async {});
  });

  Future<void> pump(WidgetTester tester) async {
    await pumpSeeded(
      tester,
      const NutritionProfileScreen(),
      overrides: [
        userRepositoryProvider.overrideWith((_) async => repo),
        garminLastBodyCompProvider.overrideWith((ref, userId) async => null),
        dailyMacroServiceProvider.overrideWithValue(macros),
        dailyMacrosControllerProvider.overrideWith(
          _CountingMacrosController.new,
        ),
        settingsControllerProvider.overrideWith(_StubSettingsController.new),
      ],
      settle: true,
    );
    // Keep a listener on the (auto-dispose) controller so an invalidate
    // rebuilds it immediately — as the dashboard's watch does in the app —
    // instead of merely disposing it.
    final el = tester.element(find.byType(NutritionProfileScreen));
    final sub = ProviderScope.containerOf(
      el,
      listen: false,
    ).listen(dailyMacrosControllerProvider, (_, __) {});
    addTearDown(sub.close);
    await tester.pump();
    expect(_macroBuilds, 1);
  }

  testWidgets(
    'saving a weight change invalidates today+future macros and refreshes the day',
    (tester) async {
      await pump(tester);

      await tester.enterText(
        find.byKey(const ValueKey('body_composition.weight_field')),
        '185',
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('nutrition_profile.save_button')),
      );
      await tester.pumpAndSettle();

      expect(saved.weightPounds, 185);
      verify(
        () =>
            macros.invalidateForManualInputChange('u1', now: any(named: 'now')),
      ).called(1);
      expect(
        _macroBuilds,
        2,
        reason: 'the visible day must recompute with the new inputs',
      );
    },
  );

  testWidgets('a save that changes no engine input triggers no invalidation', (
    tester,
  ) async {
    await pump(tester);

    // Dirty the form and then land back on the SAME weight: Save appears,
    // but the profile that gets saved is engine-identical to the current one.
    final weight = find.byKey(const ValueKey('body_composition.weight_field'));
    await tester.enterText(weight, '166');
    await tester.pump();
    await tester.enterText(weight, '165');
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('nutrition_profile.save_button')),
    );
    await tester.pumpAndSettle();

    expect(saved.weightPounds, 165);
    verifyNever(
      () =>
          macros.invalidateForManualInputChange(any(), now: any(named: 'now')),
    );
    expect(_macroBuilds, 1, reason: 'no needless recompute');
  });
}
