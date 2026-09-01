// Widget tests for the goals step (onboarding step 1, 2026-08 redesign).
//
// Pins the phase-4 contract: toggles mirror into the controller draft
// immediately, zero selections is valid (Continue always enabled), and the
// screen lays out without overflow at a phone viewport.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/onboarding/domain/onboarding_draft.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/providers/onboarding_controller.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/goals_screen.dart';

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
        child: wrapForTest(GoalsScreen(onContinue: onContinue, stepIndex: 1)),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(GoalsScreen)));
  }

  testWidgets('renders all goals, none pre-selected, without overflow', (
    tester,
  ) async {
    final container = await pumpScreen(tester);

    for (final goal in OnboardingGoal.values) {
      expect(
        find.byKey(ValueKey('goals.${goal.dbValue}_chip')),
        findsOneWidget,
      );
    }
    expect(
      container.read(onboardingControllerProvider.notifier).draft.goals,
      isEmpty,
    );
    expectNoRenderOverflow(tester);
  });

  testWidgets('toggling options updates the draft', (tester) async {
    final container = await pumpScreen(tester);
    final controller = container.read(onboardingControllerProvider.notifier);

    await tester.tap(find.byKey(const ValueKey('goals.performance_chip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('goals.eat_healthier_chip')));
    await tester.pumpAndSettle();

    expect(controller.draft.goals, {
      OnboardingGoal.performance,
      OnboardingGoal.eatHealthier,
    });

    await tester.tap(find.byKey(const ValueKey('goals.performance_chip')));
    await tester.pumpAndSettle();
    expect(controller.draft.goals, {OnboardingGoal.eatHealthier});
  });

  testWidgets('Continue is enabled with zero selections (non-blocking)', (
    tester,
  ) async {
    var continued = 0;
    await pumpScreen(tester, onContinue: () => continued++);

    await tester.tap(find.byKey(const ValueKey('goals.continue_button')));
    await tester.pumpAndSettle();
    expect(continued, 1);
  });
}
