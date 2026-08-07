// Widget tests for the nutrition settings step (onboarding step 6, 2026-08
// redesign).
//
// Pins the phase-5 contract: Moderate/Medium are preselected (matching the
// draft defaults, so the step never blocks), selections mirror into the
// draft, and the plain-language caption tracks the selection.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/providers/onboarding_controller.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/nutrition_settings_screen.dart';

import '../../helpers/widget_test_harness.dart';

void main() {
  Future<ProviderContainer> pumpScreen(
    WidgetTester tester, {
    VoidCallback? onContinue,
  }) async {
    tester.view.physicalSize = standardPhoneSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [mockAppExternalDeps(), mockSharedPreferences()],
        child: wrapForTest(
          NutritionSettingsScreen(onContinue: onContinue, stepIndex: 6),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(NutritionSettingsScreen)),
    );
  }

  testWidgets('defaults Moderate/Medium preselected, Continue enabled', (
    tester,
  ) async {
    var continued = 0;
    final container = await pumpScreen(tester, onContinue: () => continued++);
    final controller = container.read(onboardingControllerProvider.notifier);

    expect(controller.draft.gutTraining, GutTraining.moderate);
    expect(controller.draft.sweatRate, SweatRateCat.medium);

    // Default captions render.
    expect(
      find.text("I'M REGULARLY FUELING MY LONG WORKOUTS."),
      findsOneWidget,
    );
    expect(
      find.text('A NORMAL AMOUNT — DAMP AFTER A HARD SESSION.'),
      findsOneWidget,
    );

    // Non-blocking: Continue works with the defaults.
    await tester.tap(
      find.byKey(const ValueKey('nutrition_settings.continue_button')),
    );
    await tester.pumpAndSettle();
    expect(continued, 1);
    expectNoRenderOverflow(tester);
  });

  testWidgets('selecting gut/sweat segments updates the draft + caption', (
    tester,
  ) async {
    final container = await pumpScreen(tester);
    final controller = container.read(onboardingControllerProvider.notifier);

    await tester.tap(find.byKey(const ValueKey('nutrition_settings.gut_high')));
    await tester.pumpAndSettle();
    expect(controller.draft.gutTraining, GutTraining.high);
    expect(
      find.text("I'VE TRAINED MY GUT TO HANDLE HIGH CARB INTAKE."),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('nutrition_settings.sweat_heavy')),
    );
    await tester.pumpAndSettle();
    expect(controller.draft.sweatRate, SweatRateCat.heavy);
    expect(
      find.text("I'M DRENCHED — KIT SOAKED AFTER HARD SESSIONS."),
      findsOneWidget,
    );

    // Switching back restores the default selection.
    await tester.tap(
      find.byKey(const ValueKey('nutrition_settings.gut_moderate')),
    );
    await tester.pumpAndSettle();
    expect(controller.draft.gutTraining, GutTraining.moderate);
  });
}
